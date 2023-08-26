#!/usr/bin/env python

# main
import sys

if len(sys.argv) != 2:
    print("Usage:")
    print(sys.argv[0] + " [language]")
    print("languages:")
    print("  ts = Typescript")
    print("  lua = Lua")
    print("  _ = debug output")
    exit()

language = sys.argv[1]


protocol_def = open("protocol.scm", "r")

class Token:
    def __init__(self, value, is_special, line, col):
        self.value = value
        self.is_special = is_special
        self.line = line
        self.col = col

tokens = []

# parse tokens
in_comment = False
line = 1
col = 0
current_token = ""
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
    elif char == '(' or char == ')' or char == '[' or char == ']':
        if current_token != "":
            tokens.append(Token(current_token, False, line, col))
            current_token = ""
        tokens.append(Token(char, True, line, col))
    elif char == ' ' or char == '\n':
        if current_token != "":
            tokens.append(Token(current_token, False, line, col))
            current_token = ""
        if char == '\n':
            line += 1
            col = 0
    else:
        current_token += char

token_n = 0
def next_token():
    global token_n
    if token_n >= len(tokens):
        return None
    t = tokens[token_n]
    token_n += 1
    return t



class Field:
    def __init__(self):
        self.name = ""
        self.ty = ""

class Message:
    def __init__(self):
        self.name = ""
        self.fields = []
        self.uid = -1

def parse_message():
    message = Message()
    name = next_token()
    if name == None:
        print("protocol.scm: Unexpected EOF")
        exit()
    elif name.is_special:
        print("protocol.scm:" + str(name.line) + ":" + str(name.col) + ": unexpected '" + name.value + "'")
        exit()
    message.name = name.value

    current_field = None
    while True:
        t = next_token()
        if t == None:
            print("protocol.scm: Unexpected EOF")
            exit()
        if t.is_special:
            if t.value == ')':
                # reached end of message
                if current_field != None:
                    print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": unexpected '" + t.value + "'")
                    exit()
                return message
            else:
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": unexpected '" + t.value + "'")
                exit()
        if current_field == None:
            if t.value[0] != ':':
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": field name must start with ':'")
                exit()
            current_field = Field()
            current_field.name = t.value[1:]
        else:
            if t.value[0] == ':':
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": expected type, got field name")
                exit()
            current_field.ty = t.value
            message.fields.append(current_field)
            current_field = None

class Variant:
    def __init__(self):
        self.name = ""
        self.uid = -1

class Enum:
    def __init__(self):
        self.name = ""
        self.variants = []

def parse_enum():
    enum = Enum()
    while True:
        t = next_token()
        if t.is_special:
            if t.value == ']':
                return enum # reached end of enum
            else:
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": unexpected '" + t.value + "'")
                exit()
        if enum.name == "":
            if t.value[0] == ':':
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": expected enum name, got variant name")
                exit()
            enum.name = t.value
        else:
            if t.value[0] != ':':
                print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": variant names must start with ':'")
                exit()
            variant = Variant()
            variant.name = t.value[1:]
            enum.variants.append(variant)


# main parsing loop
messages = []
enums = []

while True:
    t = next_token()
    if t == None:
        break # EOF
    if t.is_special and t.value == '(':
        messages.append(parse_message())
    elif t.is_special and t.value == '[':
        enums.append(parse_enum())
    else:
        print("protocol.scm:" + str(t.line) + ":" + str(t.col) + ": unexpected '" + t.value + "'")
        exit()


message_id = 1
for m in messages:
    m.uid = message_id
    message_id += 1
    last_field_seen = False
    for f in m.fields:
        if last_field_seen:
            print("protocol.def:")
            print(" in message " + m.name + ": only the last field of a message can have type '...'")
            exit()
        if f.ty == "...":
            last_field_seen = True

for e in enums:
    variant_id = 0
    for v in e.variants:
        v.uid = variant_id
        variant_id += 1

# codegen
if language == "ts":
    ts_code = ""
    import ts_codegen as ts

    ts_code += ts.get_global_code()
    for m in messages:
        ts_code += ts.get_message_code(m)
    ts_code += ts.get_decode_code(messages)
    for e in enums:
        ts_code += ts.get_enum_code(e)
    print(ts_code)
elif language == "lua":
    lua_code = ""
    import lua_codegen as lua

    for m in messages:
        lua_code += lua.get_message_code(m)
    for e in enums:
        lua_code += lua.get_enum_code(e)
    print(lua_code)
elif language == "_":
    for m in messages:
        print(m.name, ':', m.uid)
        for f in m.fields:
            print("   ", f.name, ':', f.ty)
    for e in enums:
        print("enum", e.name)
        for v in e.variants:
            print("   ", v.name, ':', v.uid)
else:
    print("Unsupported language:", language)
