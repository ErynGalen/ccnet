export abstract class Message {
    abstract toHex(): string;
    abstract id(): number;
}
function hexFromRaw(n: number): string {
    n = n & 0xF;
    if (n < 10) {
        return String.fromCharCode(n + "0".charCodeAt(0));
    } else {
        return String.fromCharCode(n - 10 + "a".charCodeAt(0));
    }
}
function hexFromUint(n: number): string {
    return hexFromRaw((n & 0xF000) >> 12) + hexFromRaw((n & 0xF00) >> 8)
         + hexFromRaw((n & 0xF0) >> 4) + hexFromRaw(n & 0xF);
}
function hexFromInt(n: number): string  {
    if (n >= 0) {
        return hexFromUint(n & 0x7FFF);
    } else {
        return hexFromUint(n & 0xFFFF);
    }
}
function hexFromStr(s: string): string {
    let hex = hexFromUint(s.length);
    for (let i = 0; i < s.length; i++) {
        let charCode = s[i].charCodeAt(0);
        hex += hexFromRaw((charCode & 0xF0) >> 4) + hexFromRaw(charCode & 0xF);
    }
    return hex;
}
function hexFromUint8Array(a: Uint8Array): string {
    let hex = hexFromUint(a.length);
    for (let i = 0; i < a.length; i++) {
        let byte = a[i];
        hex += hexFromRaw((byte & 0xF0) >> 4) + hexFromRaw(byte & 0xF);
    }
    return hex;
}
export class RequestID extends Message {
    player_name: string;
    static ID = 1;
    id() { return RequestID.ID; }
    constructor(player_name: string) {
        super();
        this.player_name = player_name;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += this.player_name.length + 2; // player_name
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(RequestID.ID);
        hex += hexFromStr(this.player_name); // player_name
        return hex;
    }
}
export class AssignID extends Message {
    local_id: number;
    static ID = 2;
    id() { return AssignID.ID; }
    constructor(local_id: number) {
        super();
        this.local_id = local_id;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(AssignID.ID);
        hex += hexFromUint(this.local_id); // local_id
        return hex;
    }
}
export class Join extends Message {
    local_id: number;
    room_name: string;
    static ID = 3;
    id() { return Join.ID; }
    constructor(local_id: number, room_name: string) {
        super();
        this.local_id = local_id;
        this.room_name = room_name;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        message_size += this.room_name.length + 2; // room_name
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(Join.ID);
        hex += hexFromUint(this.local_id); // local_id
        hex += hexFromStr(this.room_name); // room_name
        return hex;
    }
}
export class AssignGlobalID extends Message {
    local_id: number;
    global_id: number;
    static ID = 4;
    id() { return AssignGlobalID.ID; }
    constructor(local_id: number, global_id: number) {
        super();
        this.local_id = local_id;
        this.global_id = global_id;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        message_size += 2; // global_id
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(AssignGlobalID.ID);
        hex += hexFromUint(this.local_id); // local_id
        hex += hexFromUint(this.global_id); // global_id
        return hex;
    }
}
export class PlayerInRoom extends Message {
    local_id: number;
    global_id: number;
    is_new: number;
    player_name: string;
    static ID = 5;
    id() { return PlayerInRoom.ID; }
    constructor(local_id: number, global_id: number, is_new: number, player_name: string) {
        super();
        this.local_id = local_id;
        this.global_id = global_id;
        this.is_new = is_new;
        this.player_name = player_name;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        message_size += 2; // global_id
        message_size += 2; // is_new
        message_size += this.player_name.length + 2; // player_name
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(PlayerInRoom.ID);
        hex += hexFromUint(this.local_id); // local_id
        hex += hexFromUint(this.global_id); // global_id
        hex += hexFromUint(this.is_new); // is_new
        hex += hexFromStr(this.player_name); // player_name
        return hex;
    }
}
export class PlayerLeft extends Message {
    local_id: number;
    global_id: number;
    static ID = 6;
    id() { return PlayerLeft.ID; }
    constructor(local_id: number, global_id: number) {
        super();
        this.local_id = local_id;
        this.global_id = global_id;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        message_size += 2; // global_id
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(PlayerLeft.ID);
        hex += hexFromUint(this.local_id); // local_id
        hex += hexFromUint(this.global_id); // global_id
        return hex;
    }
}
export class PlayerUpdate extends Message {
    local_id: number;
    global_id: number;
    data: Uint8Array;
    static ID = 7;
    id() { return PlayerUpdate.ID; }
    constructor(local_id: number, global_id: number, data: Uint8Array) {
        super();
        this.local_id = local_id;
        this.global_id = global_id;
        this.data = data;
    }
    toHex(): string {
        let message_size = 4; // header
        message_size += 2; // local_id
        message_size += 2; // global_id
        message_size += this.data.length + 2; // data
        let hex = hexFromUint(message_size); // header
        hex += hexFromUint(PlayerUpdate.ID);
        hex += hexFromUint(this.local_id); // local_id
        hex += hexFromUint(this.global_id); // global_id
        hex += hexFromUint8Array(this.data); // data
        return hex;
    }
}
function numFromSingleHex(s: string, index: number): number {
    let code = s.charCodeAt(index);
    if (code >= "0".charCodeAt(0) && code <= "9".charCodeAt(0)) {
        return code - "0".charCodeAt(0);
    } else if (code >= "a".charCodeAt(0) && code <= "f".charCodeAt(0)) {
        return code + 10 - "a".charCodeAt(0);
    }
    throw new Error("Not a valid hex: " + String.fromCharCode(code));
}
function uintFromHex(s: string, index: number): [number, number] {
    return [4, (numFromSingleHex(s, index) << 12) + (numFromSingleHex(s, index + 1) << 8)
             + (numFromSingleHex(s, index + 2) << 4) + numFromSingleHex(s, index + 3)];
}
function intfromHex(s: string, index: number): [number, number] {
    let [length, raw] = uintFromHex(s, index);
    if (raw & 0x8000) { // negative
        return [length, (~0xFFFF) | raw];
    } else { // positive
        return [length, 0x7FFF & raw];
    }
}
function strFromHex(s: string, index: number): [number, string] {
    let result = "";
    let [total_length, str_length] = uintFromHex(s, index);
    if (s.length < total_length + 2 * str_length) throw new Error("Can't parse str: not enough hex digits");
    for (let _c = 0; _c < str_length; _c++) {
        result += String.fromCharCode((numFromSingleHex(s, index + total_length) << 4)
                                    + numFromSingleHex(s, index + total_length + 1));
        total_length += 2
    }
    return [total_length, result];
}
function uint8ArrayFromHex(s: string, index: number): [number, Uint8Array] {
    let result: number[] = [];
    let [total_length, array_length] = uintFromHex(s, index);
    if (s.length < total_length + 2 * array_length) throw new Error("Can't parse [...]: not enough hex digits");
    for (let _c = 0; _c < array_length; _c++) {
        result.push((numFromSingleHex(s, index + total_length) << 4)
                   + numFromSingleHex(s, index + total_length + 1));
        total_length += 2
    }
    return [total_length, new Uint8Array(result)];
}
/** `decode()` return the length decoded and the decoded class
 * 
 * A length of 0 means that there aren't enough bytes to build the type
 * 
 * A length of -1 indicates an error
 */
export function decode(hex: string): [number, Message | null] {
    if (hex.length < 8) return [0, null]; // not enough data
    let [l_size, size] = uintFromHex(hex, 0);
    let [l_id, id] = uintFromHex(hex, 4);
    let length_so_far = l_size + l_id;
    if (id == RequestID.ID) {
        let [l_player_name, player_name] = strFromHex(hex, length_so_far);
        length_so_far += l_player_name;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new RequestID(player_name)];
    }
    if (id == AssignID.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new AssignID(local_id)];
    }
    if (id == Join.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        let [l_room_name, room_name] = strFromHex(hex, length_so_far);
        length_so_far += l_room_name;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new Join(local_id, room_name)];
    }
    if (id == AssignGlobalID.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        let [l_global_id, global_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_global_id;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new AssignGlobalID(local_id, global_id)];
    }
    if (id == PlayerInRoom.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        let [l_global_id, global_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_global_id;
        let [l_is_new, is_new] = uintFromHex(hex, length_so_far);
        length_so_far += l_is_new;
        let [l_player_name, player_name] = strFromHex(hex, length_so_far);
        length_so_far += l_player_name;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new PlayerInRoom(local_id, global_id, is_new, player_name)];
    }
    if (id == PlayerLeft.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        let [l_global_id, global_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_global_id;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new PlayerLeft(local_id, global_id)];
    }
    if (id == PlayerUpdate.ID) {
        let [l_local_id, local_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_local_id;
        let [l_global_id, global_id] = uintFromHex(hex, length_so_far);
        length_so_far += l_global_id;
        let [l_data, data] = uint8ArrayFromHex(hex, length_so_far);
        length_so_far += l_data;
        if (length_so_far != 2 * size) {
            console.error("Size mismatch! returning announced size, got " + length_so_far);
        }
        return [size, new PlayerUpdate(local_id, global_id, data)];
    }
    return [-1, null];
}

