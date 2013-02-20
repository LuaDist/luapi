--[[
This example demonstrates the use of the broadcast primitives.
This is a very simple implementation of a global clock.

This example thus demonstrates that broadcast helps at 
expressing synchronous interactions.

In this version, and unlike bclock.lua, the behavior
is globally synchronous thanks to the use of an intermediate Barrier
process (which is used in a way that looks like a rendez-vous, see rdv.lua)

In this version, all receivers get the signal. A first drawback is that
the number of receivers must be statically known, here by the Barrier
process that drives Clock's activation. A second drawback is that we ultimately
rely on a scheduling-level property, which ensures that all ready processes
will get a change to go back to listening mode before the clock is activated
again.

A more complete, concise and dynamic solution is (or will be) proposed in bclock3.lua
, but it requires a non-trivial modification of the semantics for broadcast.
]]

require "pithreads"
require "utils"

-- the number of receiver processes
NBPROCS = tonumber(arg and arg[1]) or 10

-- the number of ticks to simulate
NBTICKS = tonumber(arg and arg[2]) or 10

function Clock(proc,clock,init,fuel,clockstart)
  local tick = init
  while fuel>0 do
    -- first wait so that the receivers are ready
    proc:wait(clockstart)
    print("Tick #" .. tostring(tick))
    proc:bcast(clock,tick)
    tick = tick + 1
    fuel = fuel - 1
  end
end

function Barrier(proc,clockstart,ready,nbreceivers)
  while true do
    local i = nbreceivers
    while i>0 do
      proc:wait(ready)
      i = i - 1
    end
    proc:yield() -- this is important to ensure the
                 -- receivers have a chance to do their listening
                 -- note that this trick is scheduling-dependent
                 -- and here works because we use a home-made scheduler
                 -- with system-level threads this would not work
    proc:signal(clockstart)
  end
end

function Receiver(proc,id,clock,ready)
  while true do
    proc:signal(ready)
    print("Receiver #" ..tostring(id).." listens")
    local count = proc:listen(clock)
    print("Receiver #" ..tostring(id).." listened tick #"..tostring(count))
  end
end

agent = pithreads.init()

-- the clock channel
clock = agent:new("clock")
clockstart = agent:new("clockstart")
ready = agent:new("ready")

-- the Receiver processes
pithreads.replicate(agent,"Receiver",NBPROCS,Receiver,clock,ready)

-- the Barrier process
agent:spawn("Barrier",Barrier,clockstart,ready,NBPROCS)

-- the Clock process
agent:spawn("Clock",Clock,clock,1,NBTICKS,clockstart)

print("Starting the agent")
agent:run()