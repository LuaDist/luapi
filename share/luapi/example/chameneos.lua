
--[[ 
This is a benchmark example from the Great Computer Language Shootout
http://shootout.alioth.debian.org/

This "Chameneos" benchmark is described as follows:

Each program should

    * create four differently coloured (blue, red, yellow, blue) concurrent chameneos creatures
    * each creature will repeatedly go to the meeting place and meet, or wait to meet, another chameneos "(at the request the caller does not know whether another chameneos is already present or not, neither if there will be one in some future)"
    * each creature will change colour to complement the colour of the chameneos that they met - don't use arithmetic to complement the colour, use if-else or switch/case or pattern-match
    * after N total meetings have taken place, any creature entering the meeting place will take on a faded colour, report the number of creatures it has met, and end
    * write the sum of reported creatures met

]]

require "pithreads"

local N = tonumber(arg and arg[1]) or 5000

local agent = pithreads.init()
local blue = agent:new("blue")
local red = agent:new("red")
local yellow = agent:new("yellow")
local report = agent:new("report")

function complement(color1,color2)
  if color1==color2 then
    return color2
  elseif color1==blue then
    if color2==red then
      return yellow
    elseif color2==yellow then
      return red
    end
  elseif color1==red then
    if color2==blue then
      return yellow
    elseif color2==yellow then
      return blue
    end
  elseif color1==yellow then
    if color2==blue then
      return red
    elseif color2==red then
      return blue
    end
  end
end

function Chameneos(proc,report,owncolor,color2,color3)
  local faded = false
  local nb = 0
  local function update(color) owncolor = complement(owncolor,color) end
  while not faded do
    proc:choice( { owncolor:send() },
                 { color2:receive() , function() update(color2) end },
                 { color3:receive() , function() update(color3) end })
    nb = nb + 1
    if nb >= N then 
      faded = true
    end
  end
  proc:send(report,nb)
end

function MeetingPlace(proc,nb,report)
  local total = 0
  while nb>0 do
    total = total + proc:receive(report)
    nb = nb - 1
  end
  print(total/2)
end

agent:spawn("Chameneos1",Chameneos,report,blue,red,yellow)
agent:spawn("Chameneos2",Chameneos,report,red,blue,yellow)
agent:spawn("Chameneos3",Chameneos,report,yellow,blue,red)
agent:spawn("Chameneos4",Chameneos,report,blue,red,yellow)

agent:spawn("MeetingPlace",MeetingPlace,4,report)

agent:run()