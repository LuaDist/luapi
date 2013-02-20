--[[
This examples implements a global synchronization clock
using the basic LuaPi primitives.

In bclock.lua we illustrate the use of the broadcast primitives
to encode a similar pattern in a more succint way.
]]

require "pithreads"

-- the number of worker threadesses
NB_WORKERS = tonumber(arg and arg[1]) or 5
-- the clock lifetime
TIME_TO_LIVE = tonumber(arg and arg[2]) or 3

-- the worker behavior
function Worker(thread,id,register,tick,barrier,work)
  thread:send(register,id)
  while true do
    -- wait for the next tick
    local count = thread:receive(tick)
    print(thread.name,"Tick #",count," received")
    -- perform some work
    work(thread,id,count)
    -- enter the synchronization barrier
    thread:send(barrier,id)
  end
end

-- the global clock behavior
function Clock(thread,register,tick,barrier,nbReg,ttl)
  for count=1,ttl do
    if nbReg==0 then
      return
    end
    -- emit the tick
    for i=1,nbReg do
      thread:send(tick,count)
    end
    -- synchronization barrier
    for i=1,nbReg do
      local pid = thread:receive(barrier)
      print("Worker #",pid," synchronized")
    end
    -- allow some new registrations
    while thread:tryReceive(register) do
      nbReg = nbReg + 1
    end
  end
end

-- Initial registrations of workers
function Init(thread,register,tick,barrier)
  local nbReg = 0
  thread:yield()
  while thread:tryReceive(register) do
    thread:yield()
    nbReg = nbReg + 1
  end
  thread:spawn("Clock",Clock,register,tick,barrier,nbReg,TIME_TO_LIVE)
end

agent = pithreads.init()

register = agent:new("register")
tick = agent:new("tick")
barrier = agent:new("barrier")

agent:replicate("Worker",NB_WORKERS,Worker,register,tick,barrier,
                function(thread,id,tick)
                  print("Worker #",id," works at tick=",tick)
                end)

agent:spawn("Init",Init,register,tick,barrier)

agent:run()