pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- celeste classic procgen
-- mod by kris de asis

-- "data structures"

function vector(x,y)
  return {x=x,y=y}
end

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

-- [network]

chars=" !\"#$%&'()*+,-./0123456789:;<=>?@abcdefghijklmnopqrstuvwxyz[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
s2c={} c2s={}
for i=1,95 do
  c=i+31
  s=sub(chars,i,i)
  c2s[c]=s
  s2c[s]=c
end

connected = false

function process_msg(msg)
  local parts = split(msg, ";")
  if parts[1] == 2 then -- AssignID
    connected = parts[2] ~= 0
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

function poll_input() end
function ___poll_input()
  while true do
    poke(0x5f80, 1) -- WAITING
    local msg = read_input_msg()
    if msg == "" then
      return
    end
    process_msg(msg)
  end
end
function read_input_msg()
  local msg = ""
  while peek(0x5f80) ~= 2 do end -- wait for IN_MSG
  for i = 1, 127 do
    local char = peek(0x5f80 + i)
    if char == 0 then
      poke(0x5f80, 0)
      return msg
    end
    msg = msg..(c2s[char])
  end
  poke(0x5f80, 0)
  return msg
end

function output_msg(str)
  while peek(0x5f80) ~= 0 do end -- wait until there is nothing on the bus
  poke(0x5f80, 10) -- BUSY
  local i = 1
  while i < min(#str, 128) do
    poke(0x5f80 + i, s2c[sub(str, i, i)])
    i += 1
  end
  if i < 128 then
    poke(0x5f80 + i, 0)
  end
  poke(0x5f80, 3) -- OUT_MSG
end

-- extern player

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

-- [globals]

room,
objects,got_fruit,
freeze,shake,delay_restart,sfx_timer,music_timer,
screenshake=
vector(0,0),
{},{},
0,0,0,0,0,
true
level_index=-1

-- [entry point]

function _init()
  title_screen()
  output_msg("1;pgleste;") -- RequestID
end

function title_screen()
  hours,minutes,seconds,frames,start_game_flash=0,0,0,0,0
  music(40,0,7)
  load_room(7,3)
end

function begin_game()
  max_djump,deaths,frames,seconds,minutes,music_timer=1,0,0,0,0,0
  music(0,0,7)
  level_index=0
  load_room(0,0)
end

function is_title()
  return level_index==-1
end

-- [effects]

clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd(128),
    y=rnd(128),
    spd=1+rnd(4),
    w=32+rnd(32)
  })
end

particles={}
for i=0,24 do
  add(particles,{
    x=rnd(128),
    y=rnd(128),
    s=flr(rnd(1.25)),
    spd=0.25+rnd(5),
    off=rnd(1),
    c=6+rnd(2),
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(this) 
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.solids=true
    create_hair(this)
    output_msg("6;1;0;1;"..(this.x or 0)..";"..(this.y or 0)..";") -- PlayerEvent::PlayerSpawnx
  end,
  update=function(this)
    if pause_player then
      return
    end
    
    -- horizontal input
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0
    
    -- spike collision / bottom death
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) or 
      this.y>128 then
      kill_player(this)
    end

    -- on ground checks
    local on_ground=this.is_solid(0,1)
    
    -- landing smoke
    if on_ground and not this.was_on_ground then
      this.init_smoke(0,4)
    end

    -- jump and dash input
    local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
    this.p_jump,this.p_dash=btn(🅾️),btn(❎)

    -- jump buffer
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end
    
    -- grace frames and dash restoration
    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(54)
        this.djump=max_djump
      end
    elseif this.grace>0 then
      this.grace-=1
    end

    -- dash effect timer (for dash-triggered events, e.g., berry blocks)
    this.dash_effect_time-=1

    -- dash startup period, accel toward dash target speed
    if this.dash_time>0 then
      this.init_smoke()
      this.dash_time-=1
      this.spd=vector(
        appr(this.spd.x,this.dash_target_x,this.dash_accel_x),
        appr(this.spd.y,this.dash_target_y,this.dash_accel_y)
      )
    else
      -- x movement
      local maxrun=1
      local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
      local deccel=0.15
    
      -- set x speed
      this.spd.x=abs(this.spd.x)<=1 and 
        appr(this.spd.x,h_input*maxrun,accel) or 
        appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      
      -- facing direction
      if this.spd.x~=0 then
        this.flip.x=this.spd.x<0
      end

      -- y movement
      local maxfall=2
    
      -- wall slide
      if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
          this.init_smoke(h_input*6)
        end
      end

      -- apply gravity
      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
      end

      -- jump
      if this.jbuffer>0 then
        if this.grace>0 then
          -- normal jump
          psfx(1)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          this.init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx(2)
            this.jbuffer=0
            this.spd=vector(-wall_dir*(maxrun+1),-2)
            if not this.is_ice(wall_dir*3,0) then
              -- wall jump smoke
              this.init_smoke(wall_dir*6)
            end
          end
        end
      end
    
      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)
    
      if this.djump>0 and dash then
        this.init_smoke()
        this.djump-=1   
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10
        -- vertical input
        local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
        -- calculate dash speeds
        this.spd=vector(
          h_input~=0 and h_input*(v_input~=0 and d_half or d_full) or (v_input~=0 and 0 or this.flip.x and -1 or 1),
          v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0
        )
        -- effects
        psfx(3)
        freeze=2
        shake=6
        -- dash target speeds and accels
        this.dash_target_x=2*sign(this.spd.x)
        this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
        this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(9)
        this.init_smoke()
      end
    end
    
    -- animation
    this.spr_off+=0.25
    this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or  -- wall slide or mid air
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      1+(this.spd.x~=0 and h_input~=0 and this.spr_off%4 or 0) -- walk or stand
    
    -- exit level off the top (except summit)
    if this.y<-4 and level_index<32000 then
      next_room()
    end
    
    -- was on the ground
    this.was_on_ground=on_ground

    output_msg("7;1;0;"..(this.x or 0)..";"..(this.y or 0)..";"..(this.spr or 0)..";"..(this.flip.x and 1 or 0)..";"..(this.flip.y and 1 or 0)..";"..(this.djump or 0)..";"..(this.dash_time or 0)..";") -- PlayerUpdate
  end,
  
  draw=function(this)
    -- clamp in screen
    if this.x<-1 or this.x>121 then 
      this.x=clamp(this.x,-1,121)
      this.spd.x=0
    end
    -- draw player hair and sprite
    set_hair_color(this.djump)
    draw_hair(this,this.flip.x and -1 or 1)
    draw_obj_sprite(this)
    --spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)   
    unset_hair_color()
  end
}

function create_hair(obj)
  obj.hair={}
  for i=1,5 do
    add(obj.hair,vector(obj.x,obj.y))
  end
end

function set_hair_color(djump)
  pal(8,djump==1 and 8 or djump==2 and 7+(frames\3)%2*4 or 12)
end

function draw_hair(obj,facing)
  local last=vector(obj.x+4-facing*2,obj.y+(btn(⬇️) and 4 or 3))
  for i,h in pairs(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    circfill(h.x,h.y,clamp(4-i,1,2),8)
    last=h
  end
end

function unset_hair_color()
  pal(8,8)
end

-- [other entities]

player_spawn={
  init=function(this)
    sfx(4)
    this.spr=3
    this.target=this.y
    this.y=128
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y<this.target+16 then
        this.state=1
        this.delay=3
      end
    -- falling
    elseif this.state==1 then
      this.spd.y+=0.5
      if this.spd.y>0 then
        if this.delay>0 then
          -- stall at peak
          this.spd.y=0
          this.delay-=1
        elseif this.y>this.target then
          -- clamp at target y
          this.y=this.target
          this.spd=vector(0,0)
          this.state=2
          this.delay=5
          shake=5
          this.init_smoke(0,4)
          sfx(5)
        end
      end
    -- landing and spawning player object
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        init_object(player,this.x,this.y)
      end
    end
  end,
  draw=function(this)
    set_hair_color(max_djump)
    draw_hair(this,1)
    draw_obj_sprite(this)
    --spr(this.spr,this.x,this.y)
    unset_hair_color()
  end
}

spring={
  init=function(this)
    this.hide_in=0
    this.hide_for=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=18
        this.delay=0
      end
    elseif this.spr==18 then
      local hit=this.player_here()
      if hit and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        this.init_smoke()
        -- crumble below spring
        local below=this.check(fall_floor,0,1)
        if below then
          break_fall_floor(below)
        end
        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then 
        this.spr=18 
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end
}

function break_spring(obj)
  obj.hide_in=15
end

balloon={
  init=function(this) 
    this.offset=rnd(1)
    this.start=this.y
    this.timer=0
    this.hitbox=rectangle(-1,-1,10,10)
  end,
  update=function(this) 
    if this.spr==22 then
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
      local hit=this.player_here()
      if hit and hit.djump<max_djump then
        psfx(6)
        this.init_smoke()
        hit.djump=max_djump
        this.spr=0
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else 
      psfx(7)
      this.init_smoke()
      this.spr=22 
    end
  end,
  draw=function(this)
    if this.spr==22 then
      spr(13+(this.offset*8)%3,this.x,this.y+6)
      draw_obj_sprite(this)
      --spr(this.spr,this.x,this.y)
    end
  end
}

fall_floor={
  init=function(this)
    this.state=0
  end,
  update=function(this)
    -- idling
    if this.state==0 then
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        break_fall_floor(this)
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60--how long it hides for
        this.collideable=false
      end
    -- invisible, waiting to reset
    elseif this.state==2 then
      this.delay-=1
      if this.delay<=0 and not this.player_here() then
        psfx(7)
        this.state=0
        this.collideable=true
        this.init_smoke()
      end
    end
  end,
  draw=function(this)
    if this.state~=2 then
      if this.state~=1 then
        spr(23,this.x,this.y)
      else
        spr(23+(15-this.delay)/5,this.x,this.y)
      end
    end
  end
}

function break_fall_floor(obj)
 if obj.state==0 then
  psfx(15)
    obj.state=1
    obj.delay=15--how long until it falls
    obj.init_smoke()
    local hit=obj.check(spring,0,-1)
    if hit then
      break_spring(hit)
    end
  end
end

smoke={
  init=function(this)
    this.spd=vector(0.3+rnd(0.2),-0.1)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip=vector(maybe(),maybe())
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
      destroy_object(this)
    end
  end
}

fruit={
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.off=0
  end,
  update=function(this)
    check_fruit(this)
    this.off+=0.025
    this.y=this.start+sin(this.off)*2.5
  end
}

fly_fruit={
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.off=0.5
    this.sfx_delay=8
  end,
  update=function(this)
    --fly away
    if has_dashed then
     if this.sfx_delay>0 then
      this.sfx_delay-=1
      if this.sfx_delay<=0 then
        sfx_timer=20
        sfx(14)
      end
     end
      this.spd.y=appr(this.spd.y,-3.5,0.25)
      if this.y<-16 then
        destroy_object(this)
      end
    -- wait
    else
      this.off+=0.05
      this.spd.y=sin(this.off)*0.5
    end
    -- collect
    check_fruit(this)
  end,
  draw=function(this)
    draw_obj_sprite(this)
    --spr(this.spr,this.x,this.y)
    for ox=-6,6,12 do
      spr(has_dashed or sin(this.off)>=0 and 45 or (this.y>this.start and 47 or 46),this.x+ox,this.y-2,1,1,ox==-6)
    end
  end
}

function check_fruit(this)
  local hit=this.player_here()
  if hit then
    hit.djump=max_djump
    sfx_timer=20
    sfx(13)
    got_fruit[level_index]=true
    init_object(lifeup,this.x,this.y)
    destroy_object(this)
  end
end

lifeup={
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    ?"1000",this.x-2,this.y,7+this.flash%2
  end
}

fake_wall={
  if_not_fruit=true,
  update=function(this)
    this.hitbox=rectangle(-1,-1,18,18)
    local hit=this.player_here()
    if hit and hit.dash_effect_time>0 then
      hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
      hit.dash_time=-1
      for ox=0,8,8 do
        for oy=0,8,8 do
          this.init_smoke(ox,oy)
        end
      end
      init_fruit(this,4,4)
    end
    this.hitbox=rectangle(0,0,16,16)
  end,
  draw=function(this)
    spr(64,this.x,this.y,2,2)
  end
}

function init_fruit(this,ox,oy)
  sfx_timer=20
  sfx(16)
  init_object(fruit,this.x+ox,this.y+oy,26)
  destroy_object(this)
end

key={
  if_not_fruit=true,
  update=function(this)
    local was=flr(this.spr)
    this.spr=9.5+sin(frames/30)
    if this.spr==10 and this.spr~=was then
      this.flip.x=not this.flip.x
    end
    if this.player_here() then
      sfx(23)
      sfx_timer=10
      destroy_object(this)
      has_key=true
    end
  end
}

chest={
  if_not_fruit=true,
  init=function(this)
    this.x-=4
    this.start=this.x
    this.timer=20
  end,
  update=function(this)
    if has_key then
      this.timer-=1
      this.x=this.start-1+rnd(3)
      if this.timer<=0 then
        init_fruit(this,0,-4)
      end
    end
  end
}

platform={
  init=function(this)
    this.x-=4
    this.hitbox.w=16
    this.last=this.x
    this.dir=this.spr==11 and -1 or 1
  end,
  update=function(this)
    this.spd.x=this.dir*0.65
    if this.x<-16 then this.x=128
    elseif this.x>128 then this.x=-16 end
    if not this.player_here() then
      local hit=this.check(player,0,-1)
      if hit then
        --hit.move_x(this.x-this.last,1)
        --hit.move_loop(this.x-this.last,1,"x")
        hit.move(this.x-this.last,0,1)
      end
    end
    this.last=this.x
  end,
  draw=function(this)
      spr(11,this.x,this.y-1,2,1)
  end
}

message={
  draw=function(this)
    this.text="-- celeste mountain --#this memorial to those# perished on the climb"
    if this.check(player,4,0) then
      if this.index<#this.text then
       this.index+=0.5
        if this.index>=this.last+1 then
          this.last+=1
          sfx(35)
        end
      end
      local _x,_y=8,96
      for i=1,this.index do
        if sub(this.text,i,i)~="#" then
          rectfill(_x-2,_y-2,_x+7,_y+6 ,7)
          ?sub(this.text,i,i),_x,_y,0
          _x+=5
        else
          _x=8
          _y+=7
        end
      end
    else
      this.index=0
      this.last=0
    end
  end
}

big_chest={
  init=function(this)
    this.state=0
    this.hitbox.w=16
  end,
  draw=function(this)
    if this.state==0 then
      local hit=this.check(player,0,8)
      if hit and hit.is_solid(0,1) then
        music(-1,500,7)
        sfx(37)
        pause_player=true
        hit.spd=vector(0,0)
        this.state=1
        this.init_smoke()
        this.init_smoke(8)
        this.timer=60
        this.particles={}
      end
      sspr(0,48,16,8,this.x,this.y)
    elseif this.state==1 then
      this.timer-=1
      shake=5
      flash_bg=true
      if this.timer<=45 and #this.particles<50 then
        add(this.particles,{
          x=1+rnd(14),
          y=0,
          h=32+rnd(32),
          spd=8+rnd(8)
        })
      end
      if this.timer<0 then
        this.state=2
        this.particles={}
        flash_bg=false
        new_bg=true
        init_object(orb,this.x+4,this.y+4)
        pause_player=false
      end
      foreach(this.particles,function(p)
        p.y+=p.spd
        line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
      end)
    end
    sspr(0,56,16,8,this.x,this.y+8)
  end
}

orb={
  init=function(this)
    this.spd.y=-4
  end,
  draw=function(this)
    this.spd.y=appr(this.spd.y,0,0.5)
    local hit=this.player_here()
    if this.spd.y==0 and hit then
      music_timer=45
      sfx(51)
      freeze=10
      shake=10
      destroy_object(this)
      max_djump=2
      hit.djump=2
    end
    spr(102,this.x,this.y)
    for i=0,0.875,0.125 do
      circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
    end
  end
}

flag={
  init=function(this)
    --this.show=false
    this.x+=5
    this.score=0
   --[[ for _ in pairs(got_fruit) do
      this.score+=1
    end]]
  end,
  draw=function(this)
    this.spr=118+frames/5%3
    draw_obj_sprite(this)
    --spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(26,55,6)
      ?"x"..this.score,64,9,7
      draw_time(49,16)
      ?"deaths:"..deaths,48,24,7
    elseif this.player_here() then
      sfx(55)
      sfx_timer=30
      this.show=true
    end
  end
}

room_title={
  init=function(this)
    this.delay=5
  end,
  draw=function(this)
    this.delay-=1
    if this.delay<-30 then
      destroy_object(this)
    elseif this.delay<0 then
      rectfill(24,58,104,70,0)
      if room.x==3 and room.y==1 then
        ?"old site",48,62,7
      elseif level_index==32000 then
        ?"summit",52,62,7
      else
        local level=(1+level_index)*100
        ?level.." m",52+(level<1000 and 2 or 0),62,7
      end
      draw_time(4,4)
    end
  end
}

psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={
  [1]=player_spawn,
  [8]=key,
  [11]=platform,
  [12]=platform,
  [18]=spring,
  [20]=chest,
  [22]=balloon,
  [23]=fall_floor,
  [26]=fruit,
  [28]=fly_fruit,
  [64]=fake_wall,
  [86]=message,
  [96]=big_chest,
  [118]=flag
}

-- [object functions]

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[level_index] then
    return
  end

  local obj={
    type=type,
    collideable=true,
    solids=false,
    spr=tile,
    flip=vector(false,false),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
  }

  function obj.init_smoke(ox,oy)
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
  end

  function obj.is_solid(ox,oy)
    return (oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy)) or
           obj.is_flag(ox,oy,0) or 
           obj.check(fall_floor,ox,oy) or
           obj.check(fake_wall,ox,oy)
  end
  
  function obj.is_ice(ox,oy)
    return obj.is_flag(ox,oy,4)
  end

  function obj.is_flag(ox,oy,flag)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,flag)
  end
  
  function obj.check(type,ox,oy)
    for other in all(objects) do
      if other and other.type==type and other~=obj and other.collideable and
        other.x+other.hitbox.x+other.hitbox.w>obj.x+obj.hitbox.x+ox and 
        other.y+other.hitbox.y+other.hitbox.h>obj.y+obj.hitbox.y+oy and
        other.x+other.hitbox.x<obj.x+obj.hitbox.x+obj.hitbox.w+ox and 
        other.y+other.hitbox.y<obj.y+obj.hitbox.y+obj.hitbox.h+oy then
        return other
      end
    end
  end

  function obj.player_here()
    return obj.check(player,0,0)
  end
  
  function obj.move(ox,oy,start)
    for axis in all({"x","y"}) do
      obj.rem[axis]+=axis=="x" and ox or oy
      local amt=flr(obj.rem[axis]+0.5)
      obj.rem[axis]-=amt
      if obj.solids then
        local step=sign(amt)
        local d=axis=="x" and step or 0
        for i=start,abs(amt) do
          if not obj.is_solid(d,step-d) then
            obj[axis]+=step
          else
            obj.spd[axis],obj.rem[axis]=0,0
            break
          end
        end
      else
        obj[axis]+=amt
      end
    end
  end

  add(objects,obj)

  if obj.type.init then
    obj.type.init(obj)
  end

  return obj
end

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  output_msg("6;1;0;2;") -- PlayerEvent::PlayerDeath
  sfx_timer=12
  sfx(0)
  deaths+=1
  shake=10
  destroy_object(obj)
  dead_particles={}
  for dir=0,0.875,0.125 do
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=2,--10,
      dx=sin(dir)*3,
      dy=cos(dir)*3
    })
  end
  restart_room()
end

-- [room functions]

function restart_room()
  delay_restart=15
end

function next_room()
  level_index=level_index+1
  if level_index==11 or level_index==21 or level_index==30 then -- quiet for old site, 2200m, summit
    music(30,500,7)
  elseif level_index==12 then -- 1300m
    music(20,500,7)
  end
  generate_room(0,0)
  load_room(0,0)
end

function load_room(x,y)
  if x ~= room.x or y ~= room.y then
    foreach(objects,function(o)
              o.persist = nil
    end)
  end
  
  has_dashed,has_key=false,false
  --remove existing objects
  -- foreach(objects,destroy_object)
  foreach(objects,function(o)
            if not o.persist then
              destroy_object(o)
            end
  end)

  --current room
  room.x,room.y=x,y
  if not is_title() then
    output_msg("3;1;pgleste_"..mseed..":"..x..":"..y..";") -- Join
  end
  -- entities
  for tx=0,15 do
    for ty=0,15 do
      local tile=mget(room.x*16+tx,room.y*16+ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end
  -- room title
  if not is_title() then
    init_object(room_title,0,0)
  end
end

-- [main update loop]

function _update()
  frames+=1
  if level_index<32000 then
    seconds+=frames\30
    minutes+=seconds\60
    seconds%=60
  end
  frames%=30
  
  if music_timer>0 then
    music_timer-=1
    if music_timer<=0 then
      music(10,0,7)
    end
  end
  
  if sfx_timer>0 then
    sfx_timer-=1
  end
  
  -- cancel if freeze
  if freeze>0 then 
    freeze-=1
    return
  end
  
  -- restart (soon)
  if delay_restart>0 then
    delay_restart-=1
    if delay_restart==0 then
      load_room(room.x,room.y)
    end
  end

  -- update each object
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y,0)
    if obj.type.update then
      obj.type.update(obj)
    end
  end)
  
  -- start game
  if is_title() then
    if start_game then
      start_game_flash-=1
      if start_game_flash<=-30 then
        begin_game()
      end
    elseif btn(🅾️) or btn(❎) then
      music(-1)
      start_game_flash,start_game=50,true
      sfx(38)
    end
  end
  poll_input()
end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end
  
  -- reset all palette values
  pal()
  
  -- start game flash
  if is_title() and start_game then
    local c=start_game_flash>10 and (frames%10<5 and 7 or 10) or (start_game_flash>5 and 2 or start_game_flash>0 and 1 or 0)
    if c<10 then
      for i=1,15 do
        pal(i,c)
      end
    end
  end

  -- draw bg color (pad for screenshake)
  cls()
  rectfill(0,0,127,127,flash_bg and frames/5 or new_bg and 2 or 0)

  -- bg clouds effect
  if not is_title() then
    foreach(clouds,function(c)
      c.x+=c.spd
      crectfill(c.x,c.y,c.x+c.w,c.y+16-c.w*0.1875,new_bg and 14 or 1)
      if c.x>128 then
        c.x=-c.w
        c.y=rnd(120)
      end
    end)
  end

  local rx,ry=room.x*16,room.y*16

  -- draw bg terrain
  map(rx,ry,0,0,16,16,4)

  -- draw clouds + orb chest
  foreach(objects,function(o)
    if o.type==platform then
      draw_object(o)
    end
  end)

  -- draw terrain (offset if title screen)
  map(rx,ry,is_title() and -4 or 0,0,16,16,2)
  
  -- draw objects
  foreach(objects,function(o)
    if o.type~=platform then
      draw_object(o)
    end
  end)
  
  -- draw fg terrain (not a thing)
  --map(room.x*16,room.y*16,0,0,16,16,8)
  
  -- particles
  foreach(particles,function(p)
    p.x+=p.spd
    p.y+=sin(p.off)
    p.off+=min(0.05,p.spd/32)
    crectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
    if p.x>132 then 
      p.x=-4
      p.y=rnd(128)
    end
  end)
  
  -- dead particles
  foreach(dead_particles,function(p)
    p.x+=p.dx
    p.y+=p.dy
    p.t-=0.2--1
    if p.t<=0 then
      del(dead_particles,p)
    end
    crectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+p.t*5%2)
  end)
  
  -- credits
  if is_title() then
    ?"z+x",58,80,5
    ?"matt thorson",42,96,5
    ?"noel berry",46,102,5
  end
  
  -- summit blinds effect
  if level_index==32001 then
    local p
    for o in all(objects) do
      if o.type==player then
        p=o
        break
      end
    end
    if p then
      local diff=min(24,40-abs(p.x+4-64))
      rectfill(0,0,diff,127,0)
      rectfill(127-diff,0,127,127,0)
    end
  end
  if not connected then
    ?"not connected",3,120,8
  end
end

function draw_object(obj)
  (obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
  spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end

function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end

function two_digit_str(x)
  return x<10 and "0"..x or x
end

function crectfill(x1,y1,x2,y2,c)
  if x1<128 and x2>0 and y1<128 and y2>0 then
    rectfill(max(0,x1),max(0,y1),min(127,x2),min(127,y2),c)
  end
end

-- [helper functions]

function clamp(val,a,b)
  return max(a,min(b,val))
end

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function maybe()
  return rnd(1)<0.5
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,x\8),min(15,(x+w-1)/8) do
    for j=max(0,y\8),min(15,(y+h-1)/8) do
      if fget(tile_at(i,j),flag) then
        return true
      end
    end
  end
end

function tile_at(x,y)
  return mget(room.x*16+x,room.y*16+y)
end

function spikes_at(x,y,w,h,xspd,yspd)
  for i=max(0,x\8),min(15,(x+w-1)/8) do
    for j=max(0,y\8),min(15,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if (tile==17 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0) or
         (tile==27 and y%8<=2 and yspd<=0) or
         (tile==43 and x%8<=2 and xspd<=0) or
         (tile==59 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0) then
         return true
      end
    end
  end
end

-->8
-- exit mask 0b + udlr
-- w = wall
-- 0-9 = probabilistic wall (p=#/10)
-- s = spike
-- b = balloon
-- x = spring
rm_templates={
  [0b0000]={
[[
0000
0000
0000
0000
]],
[[
0s00
sws0
0s00
0000
]],
[[
wwww
wwww
wwww
wwww
]],
[[
w88w
8118
8ss8
w88w
]],
[[
ssss
s00s
s00s
ssss
]],
[[
5555
5005
5005
5555
]],
[[
8448
0000
ssss
wwww
]],
[[
0110
0ww0
3ww3
wwww
]],
[[
0000
www0
www0
w820
]],
[[
0000
0www
0www
028w
]],
[[
0880
0ww0
0ww0
0ww0
]],
[[
0000
7ww7
4ww4
0000
]],
[[
wwww
wwww
0000
0000
]],
[[
s000
s0b0
s000
s000
]],
[[
000s
0b0s
000s
000s
]]
    },
  [0b0001]={
[[
0000
0000
0000
2ww2
]],
[[
5555
5000
5000
8www
]],
[[
s000
s000
s000
8www
]]
    },
  [0b0010]={
[[
0000
0000
0000
2ww2
]],
[[
5555
0005
0005
www8
]],
[[
000s
000s
000s
www8
]]
    },
  [0b0011]={
[[
0000
0000
0000
2ww2
]],
[[
0000
0000
ww00
wwww
]],
[[
0000
0000
00ww
wwww
]],
[[
5555
0000
0000
wwww
]],
[[
ssss
0000
0000
8ww8
]],
[[
8888
0ss0
0000
8ww8
]]
    },
  [0b0100]={
[[
5555
5005
5005
w00w
]],
[[
5ss5
5005
5005
8008
]]
    },
  [0b0101]={
[[
5555
5000
5000
w00w
]],
[[
ww40
w000
w000
w00w
]]
    },
  [0b0110]={
[[
5555
0005
0005
w00w
]],
[[
04ww
000w
000w
000w
]]
    },
  [0b0111]={
[[
5555
0000
0000
w00w
]],
[[
wwww
0ss0
0000
5005
]]
    },
  [0b1000]={
[[
5005
5005
5005
wwww
]],
[[
w00w
w00w
wssw
wwww
]],
[[
s00w
s00w
s00w
wwww
]],
[[
000s
000s
000s
wwww
]]
    },
  [0b1001]={
[[
5005
5000
5000
wwww
]],
[[
w000
w000
ww00
wwww
]],
[[
w000
ws00
wws0
wwww
]],
[[
0000
ww00
ww70
wwww
]],
[[
0000
0000
wwww
wwww
]],
[[
s000
s000
s0x0
ssws
]]
    },
  [0b1010]={
[[
5005
0005
0005
wwww
]],
[[
000w
000w
00ww
wwww
]],
[[
000w
00sw
0sww
wwww
]],
[[
0000
00ww
07ww
wwww
]],
[[
0000
0000
wwww
wwww
]],
[[
000s
000s
0x0s
swss
]]
    },
  [0b1011]={
[[
5005
0000
0000
wwww
]],
[[
0000
0000
wwww
wwww
]],
[[
0000
0000
wssw
wwww
]],
[[
0ss0
0000
0ww0
4ww4
]],
[[
0000
0000
w00w
w22w
]],
[[
0000
0xx0
swws
wwww
]]
    },
  [0b1100]={
[[
5005
5005
5005
w00w
]],
[[
w00w
w00w
w00w
w00w
]],
[[
w008
w008
ws0w
ws0w
]],
[[
800w
800w
w0sw
w0sw
]],
[[
000w
000w
w000
w000
]],
[[
w000
w000
000w
000w
]],
[[
0000
w00w
w00w
s00s
]],
[[
000w
0b0w
0005
0005
]],
[[
0000
00b0
0000
0000
]],
[[
s000
s0b0
s000
s000
]]
    },
  [0b1101]={
[[
5005
5000
5000
w00w
]],
[[
w000
w000
w500
ww00
]]
    },
  [0b1110]={
[[
5005
0005
0005
w00w
]],
[[
000w
000w
005w
00ww
]]
    },
  [0b1111]={
[[
0000
0000
0000
3003
]],
[[
5005
0000
0000
w00w
]],
[[
7000
0000
0000
7007
]],
[[
0007
0000
0000
7007
]],
[[
0000
0b00
0000
0000
]]
    }
}

autotile_walls={
  [0b0000]=32,
  [0b0001]=52,
  [0b0010]=54,
  [0b0011]=53,
  [0b0100]=39,
  [0b0101]=33,
  [0b0110]=35,
  [0b0111]=34,
  [0b1000]=55,
  [0b1001]=49,
  [0b1010]=51,
  [0b1011]=50,
  [0b1100]=48,
  [0b1101]=36,
  [0b1110]=38,
  [0b1111]=37
}

autotile_spikes={
  [0b0000]=0,
  [0b0001]=59,
  [0b0010]=43,
  [0b0011]=59,
  [0b0100]=17,
  [0b0101]=17,
  [0b0110]=17,
  [0b0111]=17,
  [0b1000]=27,
  [0b1001]=59,
  [0b1010]=43,
  [0b1011]=59,
  [0b1100]=17,
  [0b1101]=17,
  [0b1110]=17,
  [0b1111]=17
}

for sx=0,7 do
  for sy=0,7 do
    sset(40+sx,8+sy,({0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,1,1,1,0,1,1,1,1,7,1,7,1,1,0,1,1,1,9,9,1,0,0,1,1,7,7,7,1,0,0,1,1,9,7,7,9,0,0,1,1,9,6,6,9,0})[1+8*sy+sx]) fset(21,1,true)
  end
end

function generate_room(x,y)
  -- init chunks
  local rm={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
  -- starting chunk
  local r0,c0=3,flr(rnd(4))
  -- generate guaranteed path
  local r,c=r0,c0
  while r>=0 do
    local roll=flr(rnd(7))
    if roll<3 then
      if c~=0 then
        rm[cid(r,c)]|=0b0010
        rm[cid(r,c-1)]|=0b0001
        c-=1
      end
    elseif roll<6 then
      if c~=3 then
        rm[cid(r,c)]|=0b0001
        rm[cid(r,c+1)]|=0b0010
        c+=1
      end
    else
      rm[cid(r,c)]|=0b1000
      if r~=0 then
        rm[cid(r-1,c)]|=0b0100
      end
      r-=1
    end
  end
  local rx,ry=16*x,16*y
  -- mset all the things
  for cid=0,15 do
    local templates=rm_templates[rm[1+cid]]
    local template=remove_chr(templates[1+flr(rnd(#templates))],"\n")
    for tid=0,15 do
      local tchr=sub(template,1+tid,1+tid)
      local tile=tchr=="w" and 32 or 
      tonum(tchr) and (rnd(10)<tonum(tchr) and 32 or 0) or
      (tchr=="s" and cid~=r0*4+c0) and 17 or
      tchr=="b" and 22 or
      tchr=="x" and 18
      mset(rx+4*(cid%4)+tid%4,ry+4*(cid\4)+tid\4,tile)
    end
  end
  -- spawn platform + player
  for i=1,2 do
    mset(rx+4*c0+i,ry+4*r0+1,0)
    mset(rx+4*c0+i,ry+4*r0+2,0)
    mset(rx+4*c0+i,ry+4*r0+3,32)
  end
  mset(rx+4*c0+1+flr(rnd()+0.5),ry+4*r0+2,1)
  -- let balloons/springs breathe
  for tx=0,15 do
    for ty=3,15 do
      local tile=mget(rx+tx,ry+ty)
      if tile==22 or tile==18 then
        for dx=max(0,tx-1),min(15,tx+1) do
          for dy=max(0,ty-3),ty-2 do
            if mget(rx+dx,ry+dy-1)~=18 then
               mset(rx+dx,ry+dy,0)
            end
          end
        end
      end
    end
  end
  -- fill unreachable 
  local frontier={vector(4*c0+1,4*r0+2)}
  local visited={} visited[(4*r0+2)*16+4*c0+1]=true
  while #frontier>0 do
    local p=frontier[1]
    for dx=-1,1 do
      for dy=-1,1 do
        if abs(dx)+abs(dy)==1 then
          local nbx,nby=p.x+dx,p.y+dy
          if (dx~=-1 or p.x~=0) and (dx~=1 or p.x~=15) and 
            (dy~=-1 or p.y~=0) and (dy~=1 or p.y~=15) and
            not fget(mget(rx+nbx,ry+nby),0) and 
            not visited[nby*16+nbx] then
            add(frontier,vector(nbx,nby))
            visited[nby*16+nbx]=true
          end
        end
      end
    end
    deli(frontier,1)
  end
  for tx=0,15 do
    for ty=0,15 do
      if not visited[16*ty+tx] then
        mset(rx+tx,ry+ty,32)
      end
    end
  end
  -- add crumbles
  for tx=0,14 do
    for ty=2,15 do
      if rnd(1)<0.05 and 
        mget(rx+tx,ry+ty-1)==0 and mget(rx+tx+1,ry+ty-1)==0 and
        mget(rx+tx,ry+ty)==32 and mget(rx+tx+1,ry+ty)==32 and
        mget(rx+tx,ry+ty+1)==0 and mget(rx+tx+1,ry+ty+1)==0 then
        mset(rx+tx,ry+ty,23)
        mset(rx+tx+1,ry+ty,23)
      end
    end
  end
  -- autotile
  for tx=0,15 do
    for ty=0,15 do
      local _x,_y=rx+tx,ry+ty
      local tile=mget(_x,_y)
      if tile==17 or tile==27 or tile==43 or tile==59 then -- spike
        mset(_x,_y,autotile_spikes[nb_mask(x,y,tx,ty)])
      elseif fget(tile,0) then -- wall
        mset(_x,_y,autotile_walls[nb_mask(x,y,tx,ty)])
      elseif rnd()<0.125 and tile==0 and ty~=15 and fget(mget(_x,_y+1),0) then -- garnish
        -- can a tree fit?
        local tree=ty>1 and mget(_x,_y-1)==0 and mget(_x,_y-2)==0
        for dx=-1,1,2 do
          if (dx~=-1 or tx~=0) and (dx~=1 or tx~=15) then
            for dy=-1,0 do
              tree=tree and mget(_x+dx,_y+dy)==0
            end
          end
        end
        local deco=rnd()<0.005 and 21 or 63-flr(rnd(tree and 4 or 3))
        mset(_x,_y,deco)
        if deco==60 then
          mset(_x,_y-1,44)
        end
      end
    end
  end

end

function nb_mask(x,y,tx,ty)
  local _x,_y=16*x+tx,16*y+ty
  return ((tx>0 and fget(mget(_x-1,_y),0) or tx==0) and 0b0010 or 0)+
         ((tx<15 and fget(mget(_x+1,_y),0) or tx==15) and 0b0001 or 0)+
         ((ty>0 and fget(mget(_x,_y-1),0) or ty==0) and 0b1000 or 0)+
         ((ty<15 and fget(mget(_x,_y+1),0) or ty==15) and 0b0100 or 0)
end

function cid(r,c)
  return 4*r+c+1
end

function remove_chr(str,c)
  local _str=""
  for s in all(split(str,c,false)) do
    _str..=s
  end
  return _str
end

function generate_map(seed)
  if seed then
    srand(seed)
  end
  generate_room(0,0)
end

__init=_init
function _init()
  __init()
end

mseed=rnd(256)
mseed_spd=0.0
__update=_update
function _update()
  __update()
  if is_title() and not start_game then
    if btn(⬅️) then
      mseed_spd=min(0,max(-5,mseed_spd-0.34))
      mseed=max(0,flr(mseed)+flr(mseed_spd+0.5))
    end
    if btn(➡️) then
      mseed_spd=max(0,min(5,mseed_spd+0.34))
      mseed=min(16384,flr(mseed)+flr(mseed_spd+0.5))
    end
    if not btn(⬅️) and not btn(➡️) then
      mseed_spd=0.0
    end
  end
  if start_game_flash==50 then
    generate_map(mseed)
  end
end

__draw=_draw
function _draw()
  __draw()
  if is_title() then
    ?"seed: "..mseed,4,4,7
    ?"procgen",62,54,1
    ?"procgen",61,53,7
    ?"mod by meep",44,111,13
  end
end

function flag.draw(this)
  this.spr=118+frames/5%3
  draw_obj_sprite(this)
  if this.show then
    rectfill(32,2,96,31,0)
    cprint('seed: '..mseed,7,7)
    draw_time(48,14)
    cprint("deaths: "..deaths,23,7)
  elseif this.player_here() then
    sfx(55)
    sfx_timer=30
    this.show=true
  end
end

function cprint(str,y,c)
  ?str,64-2*#str,y,c
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
101111018888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
11171711888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0111991088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0117771008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
01197790003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
011966900070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000000000000008888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a1000000108888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa1111111108888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a1444444100888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1444444100000000499999944999999444004994002882000000000000288200000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37000000000000007700777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755777577775077777777777777777777770077777700000000000000000cccccccc00000000000000000000000000000000000000000000000000000000
7777777777777777700007770000777000007777700077770000000000000000c77ccccc00000000000000000000000000000000000000000000000000000000
7777cc7777cc777770cc777cccc777ccccc7770770c777070000000000000000c77cc7cc00000000000000000000000000000000000000000000000000000000
777cccccccccc77770c777cccc777ccccc777c0770777c070000000000000000cccccccc00000000000000000000000000006000000000000000000000000000
77cccccccccccc77707770000777000007770007777700070002eeeeeeee2000cccccccc00000000000000000000000000060600000000000000000000000000
57cc77ccccc7cc7577770000777000007770000777700007002eeeeeeeeee200cc7ccccc00000000000000000000000000d00060000000000000000000000000
577c77ccccccc7757000000000000000000c000770000c0700eeeeeeeeeeee00ccccc7cc0000000000000000000000000d00000c000000000000000000000000
777cccccccccc7777000000000000000000000077000000700e22222e2e22e00cccccccc000000000000000000000000d000000c000000000000000000000000
777cccccccccc7777000000000000000000000077000000700eeeeeeeeeeee000000000000000000000000000000000c0000000c000600000000000000000000
577cccccccccc7777000000c000000000000000770cc000700e22e2222e22e00000000000000000000000000000000d000000000c060d0000000000000000000
57cc7cccc77ccc7570000000000cc0000000000770cc000700eeeeeeeeeeee0000000000000000000000000000000c00000000000d000d000000000000000000
77ccccccc77ccc7770c00000000cc00000000c0770000c0700eee222e22eee0000000000000000000000000000000c0000000000000000000000000000000000
777cccccccccc7777000000000000000000000077000000700eeeeeeeeeeee005555555506666600666666006600c00066666600066666006666660066666600
7777cc7777cc777770000000000000000000000770c0000700eeeeeeeeeeee00555555556666666066666660660c000066666660666666606666666066666660
777777777777777770000000c0000000000000077000000700ee77eee7777e005555555566000660660000006600000066000000660000000066000066000000
57777577775577757000000000000000000000077000c007077777777777777055555555dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
000000000000000070000000000000000000000770000007007777005000000000000005dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
00aaaaaaaaaaaa00700000000000000000000007700c0007070000705500000000000055ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
0a999999999999a0700000000000c00000000007700000077077000755500000000005550ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb07555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb0755555555555555550000000000000c000000000000000000000000000000c00000000000
a99999999999999a70c00000000000000000000770c00007700bbb075555555555555555000000000000c00000000000000000000000000000000c0000000000
a99999999999999a700000000000000000000007700000070700007055555555555555550000000000cc0000000000000000000000000000000000c000000000
a99999999999999a07777777777777777777777007777770007777005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaa07777777777777777777777007777770004bbb00004b000000400bbb00000000c0000000000000000000000000000000000000c000000000
a49494a11a49494a70007770000077700000777770007777004bbbbb004bb000004bbbbb0000000100000000000000000000000000000000000000c00c000000
a494a4a11a4a494a70c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb00000000c0000000000000000000000000000000000000001010c00000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07040000000400bbb004000000000001000000000000000000000000000000000000000001000c0000
a49999aaaa99994a7777000007770000077700077777000704000000040000000400000000000100000000000000000000000000000000000000000000010000
a49444999944494a77700000777000007770000777700c0742000000420000004200000000000100000000000000000000000000000000000000000000001000
a494a444444a494a7000000000000000000000077000000740000000400000004000000000000000000000000000000000000000000000000000000000000000
a49499999999494a0777777777777777777777700777777040000000400000004000000000010000000000000000000000000000000000000000000000000010
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000a300000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000100009300000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000a300820000830000000000000000000000000000c400000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000827682000001009300000000000000000095a5b5c5d5e5f500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000828382670082768200000000000000000096a6b6c6d6e6f600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000a28282123282839200000000000000000097a7000000e7f700000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000868382125252328293a300000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000a282125284525232828386000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000008585868292425252525262018282860000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000082018283001323525284629200a2820000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000a28293f3123242522333020000820000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000122222526213331222328293827600000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001000135252845222225252523201838200000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001222324252525252525284525222223200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000770777077707700000000007770777077700000770077007770000000000000000000000000060000000000000000000000000000000000000000000000
00007000700070007070070000000070707070700000070007007000000000000000000000000000000000000000000000000000000000000000000000000000
00007770770077007070000000007770707077700000070007007770000000000000000000000000000000000000000000000000000000000000000000000000
00000070700070007070070000007000707000700000070007000070000000000000000000000000000000000000000000000000000000000000000000000000
00007700777077707770000000007770777000700700777077707770000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000660000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000660000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000007700000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d00060000000000000000000000000000000000000000600000000000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066677600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066677660666666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000070000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000000000000000000000000000000000000700
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000070000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c0000000000007770777007700770077077707700000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc00000000000007171717170717011701171117170000000000000000007000000000000000000000
000000000000000000000000000000000000000000000c0000000000000007771770171717100710077007171000000000000000000000000000000000000000
00000000000000000000000000000000000000000000c00000000000000007111717071717100717071107171000000000000000000000000000000000000000
00000000000000000000000000007000000000000001000000000000000007100717177010770777177707171000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000100010101100011011101110101000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c0000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000001000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005550000050500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000050050050500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555005000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005000050050500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005550000050500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555605500550550000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505050050005000000050050505050505050005050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505500505055005500505000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005500055055505000000055505550555055505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050550055505550000055505550505050505550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000ddd06dd0dd000000ddd0d0d00000ddd0ddd0ddd0ddd00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000ddd0d0d0d0d00000d0d0d0d00000ddd0d000d000d0d00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000d0d0d0d0d0d00000dd00ddd00000d0d0dd00dd00ddd00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000d0d0d0d0d0d00000d0d000d00000d0d0d000d000d0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000d0d0dd00ddd00000ddd0ddd00000d0d0ddd0ddd0d0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00088000880888000000880088088008800888008808880888088000000000000000000000000000000000000000000000000000000000000000000000000000
00080808080080000008000808080808080800080000800800080800000000000000000000000000000000000000000000000000000000000000000000000000
00080808080080000008000808080808080880080000800880080800000000000000000000000000000000000007000000000000000000000000000000000000
00080808080080000008000808080808080800080000800800080800000000000000000000000000000000000000000000000000000000000000000000060000
00080808800080000000880880080808080888008800800888088800000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131302020302020202020002000013131313020204020202020202020000131313130004040202020202020200001313131300000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

