# Define the region and resource group name to deploy
region="japaneast"
resourceGroupName="rg-sample-iot-env"
bicepFileName="deploy.bicep"

# Create a resource group
az group create --location $region --resource-group $resourceGroupName

# Deploy the Bicep template
az deployment group create --resource-group $resourceGroupName --template-file $bicepFileName

# Get outputs of the deploy
webAppsName=`az deployment group show --resource-group $resourceGroupName --name "deploy" --query "properties.outputs.webAppName.value" --output tsv`
iotHubName=`az deployment group show --resource-group $resourceGroupName --name "deploy" --query "properties.outputs.iotHubName.value" --output tsv`

# Deploy a web application to Azure Web Apps
az webapp deploy --resource-group $resourceGroupName --name $webAppsName --src-path "./DisplayEventHubMessage/webapps_package.zip"

# Create a device on Azure IoT Hub
deviceId="sample-device"
deviceKey=`az iot hub device-identity create -n $iotHubName -d $deviceId --ee --query "authentication.symmetricKey.primaryKey" --output tsv`
echo "{
   \"iotHubName\": \"$iotHubName\",
   \"deviceId\": \"$deviceId\",
   \"deviceKey\": \"$deviceKey\"
}" > device-settings.json

# Show web application information
echo "Please access to https://$webAppsName.azurewebsites.net/index.html to watch messages Azure IoT Hub received."
