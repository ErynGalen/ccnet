# Connecting a cart to a server
You can run a cart amd connect it to a server with the utility in [`connect`](connect):
* in the `connect` directory, run `npm install` to install dependencies (only do it the first time)
* still in the `connect` directory, run `node connect.js <args>`, where `<args>` is the following:

`<server address> <command> <command arguments>`

`<command>` is the command that will run the cart.

Additionally, you can specify the working directory of the command by passing the argument `--cd <directory>`.

For example:
```bash
node connect.js ws://localhost:8080 --cd ~/picolove love . carts/evercore.p8
```

# The PICO-8 side
This code manages network in the PICO-8 cart.

## Global IO code
```lua
chars=" !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
s2c={} c2s={}
for i=1,95 do
  c=i+31
  s=sub(chars,i,i)
  c2s[c]=s
  s2c[s]=c
end

function poll_input()
  output_msg("f")
   while true do
      local msg = read_input_msg()
      if msg == "" then
         return
      end
      -- process message
      local parts = split(msg, ";")
      if parts[1] == 4 then -- AssignGlobalID
         for o in all(objects) do
            if o.type == player then
               o.global_id = parts[3]
            end
         end
      elseif parts[1] == 5 then -- PlayerInRoom
        local o = init_object(extern_player, 5, 5)
        o.global_id = parts[3]
        o.name = parts[5]
      elseif parts[1] == 6 then -- PlayerLeft
        for o in all(objects) do
          if o.global_id == parts[3] then
            del(objects, o)
          end
        end
      elseif parts[1] == 7 then -- PlayerUpdate
        for o in all(objects) do
          if o.global_id == parts[3] then
            o.x = parts[4]
            o.y = parts[5]
            o.spr = parts[6]
            o.flip.x = parts[7] == 1
            o.flip.y = parts[8] == 1
            o.djump = parts[9]
          end
        end
      end
   end
end

function read_input_msg()
   local msg = ""

   while true do
      serial(0x804, 0x5300, 1)
      if peek(0x5300) == 0x0a then -- LF
         return msg
      end
      msg = msg .. c2s[peek(0x5300)]
   end
end

function output_msg(str)
   poke(0x4300, s2c[":"])
   serial(0x805, 0x4300, 1)
   for i = 1, #str do
      poke(0x4300, s2c[str:sub(i, i)])
      serial(0x805, 0x4300, 1)
   end
   poke(0x4300, 0x0a) -- LF
   serial(0x805, 0x4300, 1)
end

```

## Extern player code
```lua
extern_player={
  init=function (this)
    this.dash_time=0
    create_hair(this)
  end,
  update=function(this)
    if this.dash_time > 0 then
      this.init_smoke()
    end
  end,
  draw=function(this)
    set_hair_color(this.djump)
    draw_hair(this)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    pal()
    print(this.name, this.x+4-(#(this.name)*2), this.y-6, 7)
  end
}
```

## Additions to the code
### `_init()`
```lua
output_msg("1;name;") -- RequestID with name "name"
```
### `_update()`
```lua
poll_input()
```
### `player.init()`
```lua
output_msg("3;1;evercore_"..lvl_id..";") -- Join
```
### `player.update()`
```lua
output_msg("7;1;"..(this.global_id or 0)..";"..(this.x or 0)..";"..(this.y or 0)..";"..(this.spr or 0)..";"..(this.flip.x and 1 or 0)..";"..(this.flip.y and 1 or 0)..";"..(this.djump or 0)..";") -- PlayerUpdate
```
### `kill_player()`
```lua
output_msg("3;1;;") -- leave room
```
