var conn = new signalR.HubConnectionBuilder().withUrl("/message").build();
conn.on("ReceiveMessage", function (message) {
    var li = document.createElement("li");
    document.getElementById("messages").appendChild(li);
    li.textContent = message;
});
conn.start();