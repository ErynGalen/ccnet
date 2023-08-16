#!/usr/bin/env python

class Field:
    def __init__(self):
        self.name = ""
        self.ty = ""

class Message:
    def __init__(self):
        self.name = ""
        self.fields = []
        self.uid = -1


# main
protocol_def = open("protocol.scm", "r")

messages = []

current_message = None
current_field = None
in_field_type = False

in_comment = False

line = 1
col = 0
while True:
    char = protocol_def.read(1)
    if not char:
        break
    col += 1

    if in_comment:
        if char == '\n':
            in_comment = False
            line += 1
            col = 0
    elif char == ';':
        in_comment = True
    elif char == '(':
        if current_message != None or current_field != None:
            print("protocol.def:" + str(line) + ":" + str(col) + ": unexpected '('")
            exit()
        current_message = Message()
    elif char == ')':
        if current_message == None:
            print("protocol.def:" + str(line) + ":" + str(col) + ": unexpected ')'")
            exit()
        if current_field != None:
            current_message.fields.append(current_field)
            current_field = None
        messages.append(current_message)
        current_message = None
    elif char == ' ' or char == '\n':
        if current_message != None:
            if current_field != None:
                if in_field_type:
                    current_message.fields.append(current_field)
                    current_field = None
                else:
                    in_field_type = True
        if char == '\n':
            line += 1
            col = 0
    elif char == ':':
        if current_message == None or current_field != None:
            print("protocol.def:" + str(line) + ":" + str(col) + ": unexpected ':'")
            exit()
        current_field = Field()
        in_field_type = False
    else:
        if current_message == None:
            print("protocol.def:" + str(line) + ":" + str(col) + ": unexpected '" + char + "'")
            exit()
        if current_field != None:
            if in_field_type:
                current_field.ty += char
            else:
                current_field.name += char
        else:
            current_message.name += char


message_id = 1
for m in messages:
    m.uid = message_id
    message_id += 1


ts_code = ""
import ts_codegen as ts

ts_code += ts.get_global_code()
for m in messages:
    ts_code += ts.get_message_code(m)
ts_code += ts.get_decode_code(messages)

print(ts_code)
