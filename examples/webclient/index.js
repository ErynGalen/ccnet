import * as m from "./message.js";

let players = [];
let current_room = null;

let state_element = document.getElementById("state");
let log_element = document.getElementById("log");
let socket = new WebSocket("ws://localhost:7878");

let local_id = 0;

socket.onopen = function open() {
    log_element.innerHTML += "<div>Connected</div>";
    socket.send(new m.RequestID("Me!; I'm me; did you know?").serialize());
}
socket.onclose = function close() {
    log_element.innerHTML += "<div>Disconnected</div>";
}
socket.onerror = function error(err) {
    console.log(err);
}
socket.onmessage = function message(event) {
    let str_message = event.data;
    log_element.innerHTML += "<div><pre>" + str_message + "</div></pre>";
    let message = m.decode(str_message);
    switch (message.id()) {
        case m.AssignID.ID:
            log_element.innerHTML += "<div>Local ID: " + message.local_id + "</div>";
            local_id = message.local_id;
            socket.send(new m.Join(local_id, "test room").serialize());
            break;
        case m.AssignGlobalID.ID:
            log_element.innerHTML += "<div>Global ID: " + message.global_id + "</div>";
            current_room = "test room";
            break;
        case m.PlayerInRoom.ID:
            if (message.is_new) {
                log_element.innerHTML += "<div>Player " + message.global_id + " has joined room</div>";
            } else {
                log_element.innerHTML += "<div>Player " + message.global_id + " is present in room</div>";
            }
            players.push({ id: message.global_id, name: message.player_name });
            break;
        case m.PlayerLeft.ID:
            log_element.innerHTML += "<div>Player " + message.global_id + " has left</div>";
            players = players.filter(function (p) {
                return p.id != message.global_id;
            });
    }

    if (current_room) {
        state_element.innerHTML = "<div>In room " + current_room + "</div>";
    } else {
        state_element.innerHTML = "<div>Nowhere</div>";
    }
    state_element.innerHTML += "<div>Players:</div>";
    for (let p = 0; p < players.length; p++) {
        state_element.innerHTML += "<div> Player " + players[p].id + ": " + players[p].name + "</div>";
    }
}
