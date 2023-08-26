def get_message_code(message):
    code = ""
    code += "-- " + str(message.uid) + " = " + message.name + "("
    for f in message.fields:
        ty_str = ""
        if f.ty == "...":
            ty_str = "..."
        code += f.name + ty_str + ", "
    if len(message.fields) > 0:
        code = code[:-2] # remove last `, `
    code += ")\n"
    return code

def get_enum_code(enum):
    code = ""
    code += "-- " + enum.name + ": "
    for v in enum.variants:
        code += str(v.uid) + " = " + v.name + ", "
    if len(enum.variants) > 0:
        code = code[:-2] # remove last `, `
    code += "\n"
    return code
