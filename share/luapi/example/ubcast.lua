--[[
This examples illustrates the semantics of mixed
unicast and broadcast primitives on a shared channel
]]

require "pithreads"

NBRECEIVERS = tonumber(arg and arg[1]) or 10
NBMSG = tonumber(arg and arg[2]) or 100

function Receiver(proc,id,chan)
  while true do
    local m = proc:receive(chan)
    print("Receiver# " .. tostring(id) .. " receives message :" .. m )
  end
end

function BCastSender(proc,chan,nb,msg)
  for count = 1,nb do
    proc:bcast(chan,msg .. " #" .. tostring(count))
    count = count + 1
  end
end

function UCastSender(proc,chan,nb,msg)
  for count = 1,nb do
    proc:send(chan,msg .. "#" .. tostring(count))
    count = count + 1
  end
end

agent = pithreads.init()

chan = agent:new("chan")

agent:spawn("BCastSender",BCastSender,chan,NBMSG,"Broadcast Message")
agent:spawn("UCastSender",UCastSender,chan,NBMSG,"Unicast Message")
pithreads.replicate(agent,"Receiver",NBRECEIVERS,Receiver,chan)

print("Starting the agent")
agent:run()

