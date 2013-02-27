--[[
This example demonstrates the use of the broadcast primitives.
This is a very simple implementation of a global clock.

This example thus demonstrates that broadcast helps at 
expressing synchronous interactions.

Note that in this version, all receivers do *not* get the clock signal
except if the GLOBAL_SYNC variable is set to true.
]]

require "pithreads"

-- the number of worker pithreads
NB_WORKERS = tonumber(arg and arg[1]) or 10
-- the clock lifetime
TIME_TO_LIVE = tonumber(arg and arg[2]) or 3

-- the worker behavior
function Worker(thread,id,tick,work)
  while true do
    -- wait for the next tick
    local count = thread:listen(tick)
    print(thread.name,"Tick #",count," received")
    -- perform some work
    work(thread,id,count)
  end
end

-- the clock behavior
function Clock(thread,tick,ttl)
  for count=1,ttl do
    -- emit the tick
    thread:bcast(tick,count)
  end
end

agent = pithreads.init()

tick = agent:new("tick")

agent:spawn("Clock",Clock,tick,TIME_TO_LIVE)

agent:replicate("Worker",NB_WORKERS,Worker,tick,
                function(thread,id,tick)
                  print("Worker #",id," works at tick=",tick)
                end)

agent:run()