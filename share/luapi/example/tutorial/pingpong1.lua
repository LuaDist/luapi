-- file pingpong1.lua

--[[
The classical ping-pong example is perhaps the hello world of
concurrent and distributed systems. It simply consists in two
Pi-threads sending and receiving messages to each other.

This version has an infinite behavior (use Ctrl-C to stop it)
]]

-- importing the module
require "pithreads"

-- the behavior of Ping and Pong
function PingPong(thread,inp,out,message)
  print(thread.name,"started")
  while true do
    local msg = thread:receive(inp)
    print(thread.name .. " receives '" .. msg .. "'")
    thread:send(out,message)
  end
end

-- the initialization behavior
function Init(thread,chan)
  print(thread.name,"started")
  thread:send(chan,"<<INIT>>")
  print(thread.name,"sent is value")
end

-- the pingpong agent
agent = pithreads.init()

-- first create the two channels
ping = agent:new("ping")
pong = agent:new("pong")

-- then create the ping and pong threads
pinger = agent:spawn("Pinger",PingPong,ping,pong,"<<PING>>")
ponger = agent:spawn("Ponger",PingPong,pong,ping,"<<PONG>>")

-- the initialization process
agent:spawn("init",Init,ping)

-- and let's start everything
print("Starting the agent")
agent:run()
