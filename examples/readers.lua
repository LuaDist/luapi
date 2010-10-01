--[[
This examples benchmarks the 1 writer N readers configuration
]]

require "pithreads"

NBREADERS = tonumber(arg and arg[1]) or 10000
NBMSG = tonumber(arg and arg[2]) or 1000

function Writer(proc,chan,nb,msg)
  for i=1,nb do
    proc:send(chan,msg .. "#" .. tostring(i))
  end
end

function Reader(proc,id,chan)
  while true do
    local m = proc:receive(chan)
    print("Reader #" .. tostring(id) .. ": received '" .. m .. "'")
  end
end

agent = pithreads.init()

chan = agent:new("chan")

agent:spawn("Writer",Writer,chan,NBMSG,"Message")
pithreads.replicate(agent,"Reader",NBREADERS,Reader,chan)

print("Starting the agent")
agent:run()

