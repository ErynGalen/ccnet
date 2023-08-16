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
    code += "        return String.fromCharCode(n + \"a\".charCodeAt(0));\n"
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
