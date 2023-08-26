import { WebSocket, WebSocketServer } from "ws";
import * as m from "./message.js";
import { Room, getRoom } from "./db.js";

const port = Number(process.env.PORT);
const ws_server = new WebSocketServer({ port: port }, function () {
    console.log(`Server running on port ${port}.`);
});

class PlayerInfo {
    name: string;
    local_id: number;
    current_room: [Room, number] | null = null; // room, global_id
    constructor(name: string, local_id: number) {
        this.name = name;
        this.local_id = local_id;
    }
}

ws_server.on('connection', function (socket, _request) {
    let players: PlayerInfo[] = [];
    let next_local_id = 1;
    function player_from_local_id(id: number): PlayerInfo | null {
        for (let p = 0; p < players.length; p++) {
            if (players[p].local_id == id) {
                return players[p];
            }
        }
        console.log("Unknown local_id:", id);
        return null;
    }

    socket.on('error', function (err) {
        console.error("Error on connection:", err);
    });

    socket.on('close', function (_code, _reason) {
        players.forEach((p, _index, _array) => {
            if (p.current_room) {
                p.current_room[0].removePlayer(p.current_room[1])
            }
        });
    });
    socket.on('message', function (data, _isBinary) {
        let str_message: string;
        if (typeof (data) == "string") {
            str_message = data;
        } else {
            str_message = data.toString();
        }
        let message = m.decode(str_message);
        if (!message) {
            console.error("Error decoding message", str_message);
            return;
        }
        let mid = message.id();
        if (mid == m.RequestID.ID) {
            let req_id_message = message as m.RequestID;
            socket.send(new m.AssignID(next_local_id).serialize());
            players.push(new PlayerInfo(req_id_message.player_name, next_local_id))
            next_local_id += 1;
            return;
        }
        if (mid == m.Join.ID) {
            let join_message = message as m.Join;
            let player = player_from_local_id(join_message.local_id);
            if (!player) {
                return;
            }
            if (player.current_room) {
                // leave previous room
                player.current_room[0].removePlayer(player.current_room[1]);
                player.current_room = null;
            }
            if (join_message.room_name == "") {
                // it just means 'leave current room'
                return;
            }
            let room = getRoom(join_message.room_name);
            let global_id = room.addPlayer(socket, player.local_id, player.name);
            player.current_room = [room, global_id];
            return;
        }
        if (mid == m.PlayerUpdate.ID) {
            let update_message = message as m.PlayerUpdate;
            let player = player_from_local_id(update_message.local_id);
            if (!player) {
                return;
            }
            if (player.current_room) {
                let [room, global_id] = player.current_room;
                room.forEachPlayer((other_local_id, other_global_id, socket) => {
                    if (other_global_id == global_id) {
                        return;
                    }
                    socket.send(new m.PlayerUpdate(other_local_id, global_id, update_message.data).serialize());
                });
            }
            return;
        }
        // TODO: merge with PlayerUpdate code?
        if (mid == m.PlayerEvent.ID) {
            let event_message = message as m.PlayerEvent;
            let player = player_from_local_id(event_message.local_id);
            if (!player) {
                return;
            }
            if (player.current_room) {
                let [room, global_id] = player.current_room;
                room.forEachPlayer((other_local_id, other_global_id, socket) => {
                    if (other_global_id == global_id) {
                        return;
                    }
                    socket.send(new m.PlayerEvent(other_local_id, global_id,
                        event_message.event,
                        event_message.data).serialize());
                });
            }
            return;
        }
    });
});

console.log("Connected!");
