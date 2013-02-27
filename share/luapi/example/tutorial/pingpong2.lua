-- file pingpong2.lua

--[[
The classical ping-pong example is perhaps the hello world of
concurrent and distributed systems. It simply consists in two
processes sending and receiving messages to each other.

This version has a finite behavior using a fuel consumption
metaphor.
]]

-- importing the module
require "pithreads"

-- the behavior of Ping and Pong
function PingPong(proc,inp,out,message,fuel)
  print(proc.name,"started")
  while fuel>0 do
    print(proc.name,"fuel="..tostring(fuel))
    local msg = proc:receive(inp)
    print(proc.name .. " receives '" .. msg .. "'")
    proc:send(out,message)
    fuel = fuel - 1
  end
end

function Init(proc,chan)
  print(proc.name,"started")
  proc:send(chan,"<<INIT>>")
  print(proc.name,"sent is value")
end

agent = pithreads.init()

ping = agent:new("ping")
pong = agent:new("pong")

pinger = agent:spawn("Pinger",PingPong,ping,pong,"<<PING>>",1500)
ponger = agent:spawn("Ponger",PingPong,pong,ping,"<<PONG>>",1500)

agent:spawn("init",Init,ping)

print("Starting the agent")
agent:run()
