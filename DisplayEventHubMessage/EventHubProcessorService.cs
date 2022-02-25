using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Processor;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace DisplayEventHubMessage
{
    public class EventHubProcessorService : IHostedService, IDisposable
    {
        readonly string _eventHubConnectionString = Environment.GetEnvironmentVariable("AZURE_EVENTHUB_CONNECTIONSTRING");
        readonly string _eventHubName = Environment.GetEnvironmentVariable("AZURE_EVENTHUB_NAME");
        readonly string _eventHubConsumerGroup = Environment.GetEnvironmentVariable("AZURE_EVENTHUB_CONSUMERGROUP");
        readonly string _blobStorageConnectionString = Environment.GetEnvironmentVariable("AZURE_STORAGE_CONNECTIONSTRING");
        readonly string _blobContainerName = Environment.GetEnvironmentVariable("AZURE_STORAGE_CONTAINERNAME");

        private readonly ILogger<EventHubProcessorService> _logger;
        private IHubContext<MessageHub> _hub;
        EventProcessorClient _processor;

        public EventHubProcessorService(ILogger<EventHubProcessorService> logger, IHubContext<MessageHub> hubContext)
        {
            _logger = logger;
            _hub = hubContext;
        }

        public async Task StartAsync(CancellationToken cancellationToken)
        {
            var storageClient = new BlobContainerClient(_blobStorageConnectionString, _blobContainerName);
            await storageClient.CreateIfNotExistsAsync();
            _processor = new EventProcessorClient(storageClient, _eventHubConsumerGroup, _eventHubConnectionString, _eventHubName);
            _processor.ProcessEventAsync += ProcessEventHandler;
            _processor.ProcessErrorAsync += ProcessErrorHandler;
            await _processor.StartProcessingAsync();
        }

        async Task ProcessEventHandler(ProcessEventArgs eventArgs)
        {
            var message = Encoding.UTF8.GetString(eventArgs.Data.Body.ToArray());
            await _hub.Clients.All.SendAsync("ReceiveMessage", message);
            await eventArgs.UpdateCheckpointAsync(eventArgs.CancellationToken);
        }

        Task ProcessErrorHandler(ProcessErrorEventArgs eventArgs)
        {
            _logger.LogError($"\tPartition '{ eventArgs.PartitionId}': an unhandled exception was encountered. This was not expected to happen.");
            _logger.LogError(eventArgs.Exception.Message);
            return Task.CompletedTask;
        }

        public async Task StopAsync(CancellationToken cancellationToken)
        {
            await _processor?.StopProcessingAsync();
        }

        public void Dispose() { }
    }
}
