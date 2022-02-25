// Following services will be deployed:
//  - Azure IoT Hub
//  - Azure Storage
//  - Azure Event Hubs
//  - Azure Web Apps

// Parameters
param location string = resourceGroup().location
param resourceNameSuffix string = uniqueString(resourceGroup().id)

// Azure IoT Hub
resource iotHub 'Microsoft.Devices/IotHubs@2021-03-31' = {
  name: 'iot-${resourceNameSuffix}'
  location: location
  sku: {
    capacity: 1
    name: 'S1'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    eventHubEndpoints: {}
    routing: {
      endpoints: {
        eventHubs: [
          {
            authenticationType: 'keyBased'
            connectionString: eventHubPolicyForSend.listKeys().primaryConnectionString
            name: 'eventhub'
            resourceGroup: resourceGroup().name
          }
        ]
      }
      routes: [
        {
          name: 'route1'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: [
            'eventhub'
          ]
          isEnabled: true
        }
      ]
    }
  }
}

// Azure Storage
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'str${resourceNameSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Azure Event Hubs Namespaces
resource eventHubNameSpace 'Microsoft.EventHub/namespaces@2017-04-01' = {
  name: 'evhns-${resourceNameSuffix}'
  location: location
  sku: {
    capacity: 1
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    isAutoInflateEnabled: false
    kafkaEnabled: false
    maximumThroughputUnits: 0
  }
}

// Azure Event Hubs Namespaces - Shared Access Policy (Listen)
resource eventHubNameSpacePolicyForListen 'Microsoft.EventHub/namespaces/authorizationRules@2017-04-01' = {
  name: 'ForWebApps'
  parent: eventHubNameSpace
  properties: {
    rights: [
      'Listen'
    ]
  }
}

// Azure Event Hubs
resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: 'hub1'
  parent: eventHubNameSpace
  properties: {
    messageRetentionInDays: 7
    partitionCount: 4
  }
}

// Azure Event Hubs - Consumer Group
resource eventHubConsumerGroup 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2017-04-01' = {
  name: 'webapp'
  parent: eventHub
}

// Azure Event Hubs - Shared Access Policy (Send)
resource eventHubPolicyForSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-11-01' = {
  name: 'ForIoTHub'
  parent: eventHub
  properties: {
    rights: [
      'Send'
    ]
  }
}

// Azure App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: 'plan-${resourceNameSuffix}'
  location: location
  sku: {
    name: 'S1'
    capacity: 1
  }
}

// Azure Web Apps
resource appService 'Microsoft.Web/sites@2020-06-01' = {
  name: 'web-${resourceNameSuffix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AZURE_EVENTHUB_CONNECTIONSTRING'
          value: eventHubNameSpacePolicyForListen.listKeys().primaryConnectionString
        }
        {
          name: 'AZURE_EVENTHUB_NAME'
          value: eventHub.name
        }
        {
          name: 'AZURE_EVENTHUB_CONSUMERGROUP'
          value: eventHubConsumerGroup.name
        }
        {
          name: 'AZURE_STORAGE_CONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'AZURE_STORAGE_CONTAINERNAME'
          value: 'event-processor-host'
        }
      ]
    }
  }
}

// Outputs
output webAppName string = appService.name
output iotHubName string = iotHub.name
