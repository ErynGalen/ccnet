import { WebSocket, WebSocketServer } from "ws";
import http from 'http';
import fs from 'fs/promises';
import mime from 'mime';
import * as m from "./message.js";
import { Room, getRoom } from "./db.js";

// HTTP

const port = Number(process.env.PORT);
const http_server = http.createServer(async function (req: http.IncomingMessage, res: http.ServerResponse) {
    if (req.url) {
        let url;
        try {
            url = new URL("../web" + req.url, import.meta.url);
        } catch (e) {
            res.statusCode = 404;
            res.end("Couldn't creat URL for " + req.url);
            return
        }
        console.log("request: " + url.pathname);
        if (url.pathname == '/' || url.pathname == '') {
            url.pathname = "/index.html";
        }
        let file: Buffer;
        try {
            // console.log("Request for", file_url.pathname);
            file = await fs.readFile(url.pathname);
        } catch (e) {
            // console.error("Can't serve request for", req.url, ":", e);
            res.statusCode = 404;
            res.end();
            return;
        }
        let mime_ty = mime.getType(url.pathname);
        if (!mime_ty) {
            mime_ty = "application/octet-stream";
            console.log("Couldn't get mime type for", url.pathname);
        }
        res.setHeader('Content-Type', mime_ty);

        res.end(file);
    }
    res.statusCode = 501;
    res.end();
});

http_server.listen(port, '0.0.0.0', function () {
    console.log(`Listening on port ${port}`);
});

// Websocket

const ws_server = new WebSocketServer({ noServer: true });

http_server.on('upgrade', (req, socket, head) => {
    ws_server.handleUpgrade(req, socket, head, function (client, req) {
        ws_server.emit('connection', client, req);
    });
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
