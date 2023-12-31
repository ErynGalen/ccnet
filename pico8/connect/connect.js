const child_process = require('child_process');
const ws = require('ws');

let cwd = null;
let command = null;
let args = [];

let address = null;
let name = null;

let next_is_cwd = false;
let next_is_name = false;
for (let i = 2; i < process.argv.length; i++) {
    if (next_is_cwd) {
        cwd = process.argv[i];
        next_is_cwd = false;
    } else if (next_is_name) {
        name = process.argv[i];
        next_is_name = false;
    } else if (process.argv[i] == "--cd") {
        next_is_cwd = true;
    } else if (process.argv[i] == "--name") {
        next_is_name = true;
    } else if (address == null) {
        address = process.argv[i];
    } else if (command == null) {
        command = process.argv[i];
    } else {
        args.push(process.argv[i]);
    }
}
if (name) {
    for (let c = 0; c < name.length; c++) {
        if (name.charCodeAt(c) >= 'A'.charCodeAt(0) && name.charCodeAt(c) <= 'Z'.charCodeAt(0)) {
            console.log("Player name cannot contain uppercase letters");
            process.exit();
        }
    }
    name = name.replaceAll(';', ',');
}

function patchOutput(str) {
    let parts = str.split(';');
    if (parts[0] == 1) { // RequestID
        if (name) {
            parts[1] = name // replace name
        }
    }
    return parts.join(';');
}

const socket = new ws.WebSocket(address);

let child = child_process.spawn(command, args,
    { cwd: cwd });

let input_queue = [];

child.stdout.on('data', function (chunk) {
    let lines = chunk.toString().split("\n");
    for (let l = 0; l < lines.length; l++) {
        if (lines[l][0] == '=') {
            console.log(lines[l]);
        } else if (lines[l] == ":f") {
            writeAll();
        } else if (lines[l][0] == ":") {
            if (socket.readyState == ws.OPEN) {
                socket.send(patchOutput(lines[l].slice(1)));
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
