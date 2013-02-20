--[[
This examples benchmarks the N writers 1 reader configuration
]]

require "pithreads"

NBWRITERS = tonumber(arg and arg[1]) or 10000
NBMSG = tonumber(arg and arg[2]) or 1000

function Reader(proc,chan,nb)
  for i=1,nb do
    local m,id = proc:receive(chan)
    print("Receiver: receives message '" .. m .. "' from writer #" .. tostring(id))
  end
end

function Writer(proc,id,chan,msg)
  local count = 1
  while true do
    proc:send(chan,msg .. "#" .. tostring(count),id)
    count = count + 1
  end
end

agent = pithreads.init()

chan = agent:new("chan")

agent:spawn("Reader",Reader,chan,NBMSG)
pithreads.replicate(agent,"Writer",NBWRITERS,Writer,chan,"Message")

print("Starting the agent")
agent:run()

