def get_global_code():
    code = ""
    code += "export abstract class Message {\n"
    code += "    abstract toHex(): string;\n"
    code += "    abstract id(): number;\n"
    code += "}\n"
    code += "function hexFromRaw(n: number): string {\n"
    code += "    n = n & 0xF;\n"
    code += "    if (n < 10) {\n"
    code += "        return String.fromCharCode(n + \"0\".charCodeAt(0));\n"
    code += "    } else {\n"
    code += "        return String.fromCharCode(n - 10 + \"a\".charCodeAt(0));\n"
    code += "    }\n"
    code += "}\n"
    code += "function hexFromUint(n: number): string {\n"
    code += "    return hexFromRaw((n & 0xF000) >> 12) + hexFromRaw((n & 0xF00) >> 8)\n"
    code += "         + hexFromRaw((n & 0xF0) >> 4) + hexFromRaw(n & 0xF);\n"
    code += "}\n"
    code += "function hexFromInt(n: number): string  {\n"
    code += "    if (n >= 0) {\n"
    code += "        return hexFromUint(n & 0x7FFF);\n"
    code += "    } else {\n"
    code += "        return hexFromUint(n & 0xFFFF);\n"
    code += "    }\n"
    code += "}\n"
    code += "function hexFromStr(s: string): string {\n"
    code += "    let hex = hexFromUint(s.length);\n"
    code += "    for (let i = 0; i < s.length; i++) {\n"
    code += "        let charCode = s[i].charCodeAt(0);\n"
    code += "        hex += hexFromRaw((charCode & 0xF0) >> 4) + hexFromRaw(charCode & 0xF);\n"
    code += "    }\n"
    code += "    return hex;\n"
    code += "}\n"
    code += "function hexFromUint8Array(a: Uint8Array): string {\n"
    code += "    let hex = hexFromUint(a.length);\n"
    code += "    for (let i = 0; i < a.length; i++) {\n"
    code += "        let byte = a[i];\n"
    code += "        hex += hexFromRaw((byte & 0xF0) >> 4) + hexFromRaw(byte & 0xF);\n"
    code += "    }\n"
    code += "    return hex;\n"
    code += "}\n"
    return code

def real_type(ty):
    if ty == "uint" or ty == "int" or ty == "bool":
        return "number"
    elif ty == "str":
        return "string"
    elif ty == "[...]":
        return "Uint8Array"
    else:
        print("Warning: unknown type: " + ty)
        return "<unknown>"

def size_of_field(field):
    if field.ty == "uint" or field.ty == "int" or field.ty == "bool":
        return "2"
    elif field.ty == "str" or field.ty == "[...]":
        return "this." + field.name + ".length + 2" # add 2 to store the length of the data
    else:
        print("Warning: unknown type: " + ty)
        return "<unknown>"

def hex_for_field(field):
    if field.ty == "uint" or field.ty == "bool":
        return "hexFromUint(this." + field.name + ")"
    elif field.ty == "int":
        return "hexFromInt(this." + field.name + ")"
    elif field.ty == "str":
        return "hexFromStr(this." + field.name + ")"
    elif field.ty == "[...]":
        return "hexFromUint8Array(this." + field.name + ")"
    else:
        print("Warning: unknown type: " + field.ty)
        return "<unknown>"
    
def get_message_code(message):
    code = ""
    code += "export class " + message.name + " extends Message {\n"
    for f in message.fields:
        code += "    " + f.name + ": " + real_type(f.ty) + ";\n"
    code += "    static ID = " + str(message.uid) + ";\n"
    code += "    id() { return " + message.name + ".ID; }\n"
    code += "    constructor("
    for f in message.fields:
        code += f.name + ": " + real_type(f.ty) + ", "
    if len(message.fields) > 0:
        code = code[:-2] # remove last `, `
    code += ") {\n        super();\n"
    for f in message.fields:
        code += "        this." + f.name + " = " + f.name + ";\n"
    code += "    }\n"
    # toHex
    code += "    toHex(): string {\n"
    code += "        let message_size = 4; // header\n"
    for f in message.fields:
        code += "        message_size += " + size_of_field(f) + "; // " + f.name + "\n"
    code += "        let hex = hexFromUint(message_size); // header\n"
    code += "        hex += hexFromUint(" + message.name + ".ID);\n"
    for f in message.fields:
        code += "        hex += " + hex_for_field(f) + "; // " + f.name + "\n"
    code += "        return hex;\n"
    code += "    }\n"
    code += "}\n"
    
    return code


def decode_for_type(ty):
    if ty == "uint" or ty == "bool":
        return "uintFromHex(hex, length_so_far)"
    elif ty == "int":
        return "intFromHex(hex, length_so_far)"
    elif ty == "str":
        return "strFromHex(hex, length_so_far)"
    elif ty == "[...]":
        return "uint8ArrayFromHex(hex, length_so_far)"
    else:
        print("Warning: unknown type: " + ty)
        return "<unknown>"

def get_decode_code(messages):
    code = ""
    code += "function numFromSingleHex(s: string, index: number): number {\n"
    code += "    let code = s.charCodeAt(index);\n"
    code += "    if (code >= \"0\".charCodeAt(0) && code <= \"9\".charCodeAt(0)) {\n"
    code += "        return code - \"0\".charCodeAt(0);\n"
    code += "    } else if (code >= \"a\".charCodeAt(0) && code <= \"f\".charCodeAt(0)) {\n"
    code += "        return code + 10 - \"a\".charCodeAt(0);\n"
    code += "    }\n"
    code += "    throw new Error(\"Not a valid hex: \" + String.fromCharCode(code));\n"
    code += "}\n"
    code += "function uintFromHex(s: string, index: number): [number, number] {\n"
    code += "    return [4, (numFromSingleHex(s, index) << 12) + (numFromSingleHex(s, index + 1) << 8)\n"
    code += "             + (numFromSingleHex(s, index + 2) << 4) + numFromSingleHex(s, index + 3)];\n"
    code += "}\n"
    code += "function intfromHex(s: string, index: number): [number, number] {\n"
    code += "    let [length, raw] = uintFromHex(s, index);\n"
    code += "    if (raw & 0x8000) { // negative\n"
    code += "        return [length, (~0xFFFF) | raw];\n"
    code += "    } else { // positive\n"
    code += "        return [length, 0x7FFF & raw];\n"
    code += "    }\n"
    code += "}\n"
    code += "function strFromHex(s: string, index: number): [number, string] {\n"
    code += "    let result = \"\";\n"
    code += "    let [total_length, str_length] = uintFromHex(s, index);\n"
    code += "    if (s.length < total_length + 2 * str_length) throw new Error(\"Can't parse str: not enough hex digits\");\n"
    code += "    for (let _c = 0; _c < str_length; _c++) {\n"
    code += "        result += String.fromCharCode((numFromSingleHex(s, index + total_length) << 4)\n"
    code += "                                    + numFromSingleHex(s, index + total_length + 1));\n"
    code += "        total_length += 2\n"
    code += "    }\n"
    code += "    return [total_length, result];\n"
    code += "}\n"
    code += "function uint8ArrayFromHex(s: string, index: number): [number, Uint8Array] {\n"
    code += "    let result: number[] = [];\n"
    code += "    let [total_length, array_length] = uintFromHex(s, index);\n"
    code += "    if (s.length < total_length + 2 * array_length) throw new Error(\"Can't parse [...]: not enough hex digits\");\n"
    code += "    for (let _c = 0; _c < array_length; _c++) {\n"
    code += "        result.push((numFromSingleHex(s, index + total_length) << 4)\n"
    code += "                   + numFromSingleHex(s, index + total_length + 1));\n"
    code += "        total_length += 2\n"
    code += "    }\n"
    code += "    return [total_length, new Uint8Array(result)];\n"
    code += "}\n"

    # decode(hex)
    code += "/** `decode()` return the length decoded and the decoded class\n"
    code += " * \n"
    code += " * A length of 0 means that there aren't enough bytes to build the type\n"
    code += " * \n"
    code += " * A length of -1 indicates an error\n"
    code += " */\n"
    code += "export function decode(hex: string): [number, Message | null] {\n"
    code += "    if (hex.length < 8) return [0, null]; // not enough data\n"
    code += "    let [l_size, size] = uintFromHex(hex, 0);\n"
    code += "    let [l_id, id] = uintFromHex(hex, 4);\n"
    code += "    let length_so_far = l_size + l_id;\n"
    for m in messages:
        code += "    if (id == " + m.name + ".ID) {\n"
        for f in m.fields:
            code += "        let [l_" + f.name + ", " + f.name + "] = " + decode_for_type(f.ty) + ";\n"
            code += "        length_so_far += l_" + f.name + ";\n"
        code += "        if (length_so_far != 2 * size) {\n"
        code += "            console.error(\"Size mismatch! returning announced size, got \" + length_so_far);\n"
        code += "        }\n"
        code += "        return [size, new " + m.name + "("
        for f in m.fields:
            code += f.name + ", "
        if len(m.fields) > 0:
            code = code[:-2] # remove last `, `
        code += ")];\n"
        code += "    }\n"
    code += "    return [-1, null];\n"
    code += "}\n"

    return code
