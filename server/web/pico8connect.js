const url_params = new URLSearchParams(window.location.search);
const server_address = url_params.get('server');
const raw_name = url_params.get('name');
let name = "";
if (raw_name) {
    for (let i = 0; i < raw_name.length && i < 50; i++) {
        let s = raw_name[i];
        if (s == ';') {
            name += ',';
        } else {
            name += s.toLowerCase();
        } 
    }
}
console.log("Name:", name);

let queue;

if (server_address) {
    console.log("Connecting to " + server_address);
    const connection = new WebSocket(server_address);
    connection.onopen = function () {
        console.log("connection open");
        queue = new Worker("../pico8queue.js");
        queue.onmessage = function (event) {
            let data = even.data;
            connection.send(data);
        }
    };
    connection.onerror = function (err) {
        console.error("Error on connection:", err);
    };
    connection.onmessage = function (event) {
        const data = event.data.toString();
        console.log("(message):", data);
        queue.postMessage(data);
    };
    connection.onclose = function () {
        queue.postMessage("2;0;"); // disconnect
        console.log("Connection closed");
    };
    console.log("Connected!");
}
