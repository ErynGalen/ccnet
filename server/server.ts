import { WebSocket, WebSocketServer } from "ws";
import * as m from "./message.js";
import { Room, getRoom } from "./db.js";

const ws_server = new WebSocketServer({ port: 7878 });

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

    socket.on('error', function (err) {
        console.error("Error on connection:", err);
    });

    socket.on('close', function (_code, _reason) {
        players.forEach(function (p, _index, _array) {
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
        let length: number;
        let message = m.decode(str_message);
        if (!message) {
            console.error("Error decoding message");
            return;
        }
        switch (message.id()) {
            case m.RequestID.ID:
                let req_id_message = message as m.RequestID;
                socket.send(new m.AssignID(next_local_id).serialize());
                players.push(new PlayerInfo(req_id_message.player_name, next_local_id))
                next_local_id += 1;
                break;

            case m.Join.ID:
                let join_message = message as m.Join;
                let player: PlayerInfo | null = null;
                for (let p = 0; p < players.length; p++) {
                    if (players[p].local_id == join_message.local_id) {
                        player = players[p];
                    }
                }
                if (!player) {
                    console.error("Unknown local_id:", join_message.local_id);
                    break;
                }
                if (player.current_room) {
                    // leave previous room
                    player.current_room[0].removePlayer(player.current_room[1]);
                    player.current_room = null;
                }
                if (join_message.room_name == "") {
                    // it just means 'leave current room'
                    break;
                }
                let room = getRoom(join_message.room_name);
                let global_id = room.addPlayer(socket, player.local_id, player.name);
                player.current_room = [room, global_id];
                break;

            default:
                break;
        }
    });
});

console.log("Connected!");
