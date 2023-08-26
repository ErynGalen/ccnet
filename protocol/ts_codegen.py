def get_global_code():
    code = ""
    code += "export abstract class Message {\n"
    code += "    abstract serialize(): string;\n"
    code += "    abstract id(): number;\n"
    code += "}\n"
    code += "function checkedString(str: string): string {\n"
    code += "    let result = \"\";\n"
    code += "    for (let c = 0; c < str.length; c++) {\n"
    code += "        if (str[c] == ';') {\n"
    code += "            result += ',';\n"
    code += "        } else {\n"
    code += "            result += str[c];\n"
    code += "        }\n"
    code += "    }\n"
    code += "    return result;\n"
    code += "}\n"
    return code

def real_type(ty):
    if ty == "number" or ty == "bool":
        return "number"
    elif ty == "string" or ty == "...":
        return "string"
    else:
        print("Warning: unknown type: " + ty)
        return "<unknown>"

def str_for_field(field):
    if field.ty == "number" or field.ty == "bool":
        return "this." + field.name + ".toString() + ';'"
    elif field.ty == "string":
        return "checkedString(this." + field.name + ") + ';'"
    elif field.ty == "...":
        return "this." + field.name
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
    # serialize
    code += "    serialize(): string {\n"
    code += "        let result = " + message.name + ".ID.toString() + ';';\n"
    for f in message.fields:
        code += "        result += " + str_for_field(f) + "; // " + f.name + "\n"
    code += "        return result;\n"
    code += "    }\n"
    code += "}\n"
    
    return code


def get_decode_code(messages):
    code = ""
    # decode(str)
    code += "export function decode(str: string): Message | null {\n"
    code += "    let parts = str.split(';');\n"
    code += "    let id = Number(parts[0]);\n"
    for m in messages:
        code += "    if (id == " + m.name + ".ID) {\n"
        field_n = 0
        for f in m.fields:
            field_n += 1
            if f.ty == "number" or f.ty == "bool":
                code += "        let " + f.name + " = Number(parts[" + str(field_n) + "]);\n"
            elif f.ty == "string":
                code += "        let " + f.name + " = parts[" + str(field_n) + "];\n"
            elif f.ty == "...":
                code += "        let " + f.name + " = parts.slice(" + str(field_n) + ").join(';');\n"
                break # '...' is always the last field
            else:
                print("Warning: unknown type: " + field.ty)
                code += "        <unknown>"
        code += "        return new " + m.name + "("
        for f in m.fields:
            code += f.name + ", "
        if len(m.fields) > 0:
            code = code[:-2] # remove last `, `
        code += ");\n"
        code += "    }\n"
    code += "    return null;\n"
    code += "}\n"

    return code

def get_enum_code(enum):
    code = ""
    code += "export const " + enum.name + " = {\n"
    for v in enum.variants:
        code += "    " + v.name + ": " + str(v.uid) + ",\n"
    code += "};\n"
    return code
