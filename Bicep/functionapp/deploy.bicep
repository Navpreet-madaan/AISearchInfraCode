param location string
param functionWorkerRuntime string
param functionAppName string
param hostingPlanName string
param storageAccountName string
param functionApplinuxFxVersion string = 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
param VnetForResourcesRgName string
param VnetForResourcesName string 
param FunctionAppSubnetName string

param UseManualPrivateLinkServiceConnections string = 'False'
param VnetforPrivateEndpointsRgName string
param VnetforPrivateEndpointsName string
param PrivateEndpointSubnetName string
param PrivateEndpointId string

param DNS_ZONE_SUBSCRIPTION_ID string
param PrivateDNSZoneRgName string

param dockerRegistryUrl string
param dockerRegistryUsername string

var functionContentShareName = toLower(functionAppName)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}

resource hostingPlan 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: hostingPlanName
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  name: '${storageAccountName}/default/${functionContentShareName}'
  dependsOn: [
    storageAccount
  ]
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  dependsOn: [
    fileService
  ]
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionContentShareName
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: dockerRegistryUrl
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: dockerRegistryUsername
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionWorkerRuntime
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
      ]
      minTlsVersion: '1.2'
      linuxFxVersion: functionApplinuxFxVersion
      numberOfWorkers: 1
      acrUseManagedIdentityCreds: true
    }
    httpsOnly: true
  }
}

resource functionAppName_virtualNetwork 'Microsoft.Web/sites/networkConfig@2022-03-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId(VnetForResourcesRgName,'Microsoft.Network/virtualNetworks/subnets', VnetForResourcesName, FunctionAppSubnetName)
    swiftSupported: true
  }
}

var privateDnsZoneName = 'privatelink.azurewebsites.net'
module m_functionapp_private_endpoint '../private_endpoint/deploy.bicep' = {
  name: 'functionapp_private_endpoint'
  scope: resourceGroup(VnetforPrivateEndpointsRgName)
  params: {
    location:location
    VnetforPrivateEndpointsRgName: VnetforPrivateEndpointsRgName
    VnetforPrivateEndpointsName: VnetforPrivateEndpointsName
    PrivateEndpointSubnetName: PrivateEndpointSubnetName
    UseManualPrivateLinkServiceConnections: UseManualPrivateLinkServiceConnections
    DNS_ZONE_SUBSCRIPTION_ID: DNS_ZONE_SUBSCRIPTION_ID
    PrivateDNSZoneRgName: PrivateDNSZoneRgName
    privateDnsZoneName:privateDnsZoneName
    privateDnsZoneConfigsName:replace(privateDnsZoneName,'.','-')
    resourceName: functionAppName
    resourceID: functionApp.id
    privateEndpointgroupIds: [
      'sites'
    ]
    PrivateEndpointId: PrivateEndpointId
  }
}

