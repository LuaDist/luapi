
--[[ This example comes from a Mozart/Oz manual
http://www.mozart-oz.org/documentation/apptut/node9.html#chapter.concurrency.cheap

It simply mesure the context switching time for concurrent processes that do nothing
]]

require "pithreads"

N = tonumber(arg and arg[1]) or 1000
NB = tonumber(arg and arg[2]) or 10

function Bug(proc,id,sig,nb)
  for i=1,nb do
    proc:receive(sig)
    proc:send(sig) -- just signal (eq. context-switch)
  end
end
            
agent = pithreads.init()

local sig = agent:new("sig")

pithreads.replicate(agent,"Bug",N,Bug,sig,NB)
start = agent:spawn("Start",function(proc) proc:send(sig) end)

agent:run()
