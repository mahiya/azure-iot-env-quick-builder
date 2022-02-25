using Microsoft.Azure.Devices.Client;
using System;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace IoTDeviceApp
{
    class Program
    {
        static async Task Main()
        {
            const string settingFilePath = @"../device-settings.json";
            var deviceSettingsJson = await File.ReadAllTextAsync(settingFilePath);
            var deviceSettings = JsonSerializer.Deserialize<DeviceSettings>(deviceSettingsJson);

            var client = DeviceClient.CreateFromConnectionString(deviceSettings.ConnectionString);
            while (true)
            {
                var message = new Message(Encoding.UTF8.GetBytes("Hello Azure IoT Hub !!"));
                await client.SendEventAsync(message);
                Console.Write(".");
                Thread.Sleep(1000);
            }
        }
    }

    public class DeviceSettings
    {
        [JsonPropertyName("iotHubName")]
        public string IotHubName { get; set; }

        [JsonPropertyName("deviceId")]
        public string DeviceId { get; set; }

        [JsonPropertyName("deviceKey")]
        public string DeviceKey { get; set; }

        public string ConnectionString
        {
            get
            {
                return $"HostName={IotHubName}.azure-devices.net;DeviceId={DeviceId};SharedAccessKey={DeviceKey}";
            }
        }
    }
}
