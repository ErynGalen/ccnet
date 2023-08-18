const child_process = require('child_process');
const ws = require('ws');

const socket = new ws.WebSocket("ws://localhost:7878");

//let child = child_process.spawn("pico8", ["carts/evercore.p8"]);
let child = child_process.spawn("love", [".", "carts/evercore.p8"],
    { cwd: process.env.HOME + "/projects/Celeste/picolove" });

let input_queue = [];

child.stdout.on('data', function (chunk) {
    let lines = chunk.toString().split("\n");
    for (let l = 0; l < lines.length; l++) {
        if (lines[l] == ":f") {
            writeAll();
        } else if (lines[l][0] == ":") {
            if (socket.readyState == ws.OPEN) {
                socket.send(lines[l].slice(1));
            } else {
                console.error("Socket isn't open");
            }
        }
    }

});

child.stderr.on('data', function (chunk) {
    console.error("Stderr:", chunk.toString());
})

child.on('error', function (err) {
    console.error("Error:", err.toString());
});

function writeAll() {
    for (let m = 0; m < input_queue.length; m++) {
        child.stdin.write(input_queue[m] + "\n");
    }
    input_queue = [];
    child.stdin.write("\n");
}

child.on('close', function (code) {
    console.log("Child terminated:", code);
    socket.close();
});

console.log("Created child");


socket.on('error', function (err) {
    console.error("Connection error:", err);
});

socket.on('message', function (data, isBinary) {
    input_queue.push(data.toString());
});

socket.on('close', function () {
    console.log("Connection closed");
});

console.log("Connected");
