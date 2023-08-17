import { WebSocket } from "ws";
import * as m from "./message.js"

export class Room {
    name: string;
    players: PlayerRef[] = [];
    last_global_id: number = 0;
    constructor(name: string) {
        this.name = name;
    }

    addPlayer(socket: WebSocket, local_id: number, name: string) {
        this.last_global_id += 1;
        this.players.push(new PlayerRef(this.last_global_id, local_id, socket, name));
        socket.send(new m.AssignGlobalID(local_id, this.last_global_id).serialize());

        for (let p = 0; p < this.players.length; p++) {
            if (this.players[p].global_id != this.last_global_id) {
                // inform other player
                this.players[p].socket.send(new m.PlayerInRoom(this.players[p].local_id,
                    this.last_global_id, 1, name).serialize());
                // inform new player
                socket.send(new m.PlayerInRoom(local_id,
                    this.players[p].global_id, 0, this.players[p].name).serialize());
            }
        }

        return this.last_global_id;
    }

    removePlayer(global_id: number) {
        this.players = this.players.filter(function (p) {
            if (p.global_id == global_id) {
                return false;
            }
            // inform other player that `global_id` has left
            if (p.socket.readyState == WebSocket.OPEN) {
                p.socket.send(new m.PlayerLeft(p.local_id, global_id).serialize());
            }
            return true;
        });
        if (this.players.length == 0) {
            let this_name = this.name;
            // remove this room from the ROOMS list
            console.log("Removing " + this_name);
            ROOMS = ROOMS.filter(function (room) {
                return room.name != this_name;
            });
        }
    }
}

class PlayerRef {
    global_id: number;
    local_id: number;
    name: string;
    socket: WebSocket;
    constructor(global_id: number, local_id: number, socket: WebSocket, name: string) {
        this.global_id = global_id;
        this.local_id = local_id;
        this.socket = socket;
        this.name = name;
    }
}

let ROOMS: Room[] = [];

export function getRoom(name: string) {
    for (let r = 0; r < ROOMS.length; r++) {
        if (ROOMS[r].name == name) {
            return ROOMS[r];
        }
    }
    // create new room with specified name
    console.log("Adding " + name);
    let len = ROOMS.push(new Room(name));
    return ROOMS[len - 1];
}
