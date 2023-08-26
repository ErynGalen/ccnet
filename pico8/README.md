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

It is adapted for Evercore-based carts, so it is given as a mere example of how the protocol can be implemented.

## Global IO code
### Web
> **Note** TODO: the web version isn't done yet.

### Standalone
```lua
chars=" !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
s2c={} c2s={}
for i=1,95 do
  c=i+31
  s=sub(chars,i,i)
  c2s[c]=s
  s2c[s]=c
end

connected = false

function poll_input()
  output_msg("f")
   while true do
      local msg = read_input_msg()
      if msg == "" then
         return
      end
      -- process message
      local parts = split(msg, ";")
      if parts[1] == 2 then -- AssignID
        connected = true
      elseif parts[1] == 4 then -- AssignGlobalID
         for o in all(objects) do
            if o.type == player then
               o.global_id = parts[3]
            end
         end
      elseif parts[1] == 5 then -- PlayerInRoom
        local o = init_object(extern_player, 5, 5)
        o.global_id = parts[3]
        if parts[4] == 0 then -- player was already there
          o.show = true
        end
        o.name = parts[5]
      elseif parts[1] == 6 then -- PlayerEvent
        if parts[4] == 0 then -- PlayerLeft
          for o in all(objects) do
            if o.global_id == parts[3] then
              del(objects, o)
            end
          end
        elseif parts[4] == 1 then -- PlayerSpawn
          for o in all(objects) do
            if o.global_id == parts[3] then
              o.x = parts[5]
              o.y = parts[6]
              o.show = true
              create_hair(o)
            end
          end
        elseif parts[4] == 2 then -- PlayerDeath
          for o in all(objects) do
            if o.global_id == parts[3] then
              o.show = false
              -- death animation
              for dir=0,0.875,0.125 do
                add(dead_particles,{
                  x=o.x+4,
                  y=o.y+4,
                  t=5,
                  dx=sin(dir)*3,
                  dy=cos(dir)*3
                })
              end
            end
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
            o.dash_time = parts[10]
            if not o.hair then
              create_hair(o)
            end
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
    this.show = false
    this.persist = true
  end,
  update=function(this)
    if this.dash_time > 0 then
      this.init_smoke()
    end
  end,
  draw=function(this)
    if not this.show then return end
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
Replace `name` with your player name

```lua
output_msg("1;name;") -- RequestID with name "name"
```
### `_update()`
```lua
poll_input()
```
### `_draw()`
```lua
if not connected then
  ?"not connected",3,120,8
end
```
### `load_level()`
At the beginning of the function:
```lua
if id ~= lvl_id then
  foreach(objects,function(o)
    o.persist = nil
  end)
end
```
Replace `cartname` with a name identifying uniquely a cart.
```lua
output_msg("3;1;cartname_"..id..";") -- Join
```
Also, replace
```lua
foreach(objects,destroy_object)
```
by
```lua
foreach(objects,function(o)
  if not o.persist then
    destroy_object(o)
  end
end)
```
### `player.init()`
```lua
output_msg("6;1;0;1;"..(this.x or 0)..";"..(this.y or 0)..";") -- PlayerEvent::PlayerSpawn
```
### `player.update()`
```lua
output_msg("7;1;0;"..(this.x or 0)..";"..(this.y or 0)..";"..(this.spr or 0)..";"..(this.flip.x and 1 or 0)..";"..(this.flip.y and 1 or 0)..";"..(this.djump or 0)..";"..(this.dash_time or 0)..";") -- PlayerUpdate
```
### `kill_player()`
```lua
output_msg("6;1;0;2;") -- PlayerEvent::PlayerDeath
```
