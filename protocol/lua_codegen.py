def get_message_code(message):
    code = ""
    code += "-- " + str(message.uid) + " = " + message.name + "("
    for f in message.fields:
        code += f.name + ", "
    if len(message.fields) > 0:
        code = code[:-2] # remove last `, `
    code += ")\n"
    return code
