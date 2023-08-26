import { WebSocket } from "ws";
import * as m from "./message.js"

export class Room {
    name: string;
    players: PlayerRef[] = [];
    last_global_id: number = 0;
    free_global_ids: number[] = [];
    constructor(name: string) {
        this.name = name;
    }

    addPlayer(socket: WebSocket, local_id: number, name: string) {
        let global_id = this.free_global_ids.pop();
        if (!global_id) {
            this.last_global_id += 1;
            global_id = this.last_global_id;
        }
        this.players.push(new PlayerRef(global_id, local_id, socket, name));
        socket.send(new m.AssignGlobalID(local_id, global_id).serialize());

        for (let p = 0; p < this.players.length; p++) {
            if (this.players[p].global_id != global_id) {
                // inform other player
                this.players[p].socket.send(new m.PlayerInRoom(this.players[p].local_id,
                    global_id, 1, name).serialize());
                // inform new player
                socket.send(new m.PlayerInRoom(local_id,
                    this.players[p].global_id, 0, this.players[p].name).serialize());
            }
        }

        return global_id;
    }

    removePlayer(global_id: number) {
        this.players = this.players.filter((p) => {
            if (p.global_id == global_id) {
                this.free_global_ids.push(global_id);
                return false;
            }
            // inform other player that `global_id` has left
            if (p.socket.readyState == WebSocket.OPEN) {
                p.socket.send(new m.PlayerEvent(p.local_id, global_id, m.player_event.PlayerLeft, "").serialize());
            }
            return true;
        });
        if (this.players.length == 0) {
            let this_name = this.name;
            // remove this room from the ROOMS list
            console.log("Removing " + this_name);
            ROOMS = ROOMS.filter((room) => {
                return room.name != this_name;
            });
        }
    }

    forEachPlayer(cb: (local_id: number, global_id: number, socket: WebSocket) => any) {
        for (let p = 0; p < this.players.length; p++) {
            cb(this.players[p].local_id, this.players[p].global_id, this.players[p].socket);
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
