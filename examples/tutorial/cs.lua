--[[
This example describes a useful pattern for mutual exclusion of
concurrent critical sections using the LuaPi constructs.
]]

-- import the LuaPi module
require "pithreads"

-- the number of pi-threads with Critical Sections
N = tonumber(arg and arg[1]) or 1000

-- a counter for running critical sections
CS_COUNT = 0

-- the common behavior for all Critical Section pi-threads
function CS(thread,n,lock,csfun)
  local enter,leave = thread:receive(lock)
  -- START of Critical Section
  CS_COUNT = CS_COUNT + 1
  thread:send(enter,n)
  -- the critical section content
  csfun(thread)
  thread:send(leave,n)
  -- END of Critical Section
  CS_COUNT = CS_COUNT - 1
  thread:send(lock,enter,leave)
end

-- A behavior to observe the Critical sections
function Observer(thread,enter,leave)
  while true do
    local n = thread:receive(enter)
    print("Lock taken by "..tostring(n))
    -- check the mutual exclusion property
    assert(CS_COUNT==1)
    local m = thread:receive(leave)
    print("Lock released by "..tostring(m))
    -- check the take/release pair
    assert(n==m)
  end
end

-- A process behavior that spawns other pi-threads
function Launch(thread,n,lock,start,csfun)
  while n>0 do
    print("Start process : "..tostring(n))
    thread:spawn("CS"..tostring(n),CS,n,lock,csfun)
    n = n - 1
  end
  print("Go !")
  thread:signal(start)
end

-- The synchronization barrier
function Barrier(thread,start,lock,enter,leave)
  thread:wait(start)
  thread:send(lock,enter,leave)
end

-- create the agent
agent = pithreads.init()

-- create the channels
lock = agent:new("lock")
enter = agent:new("enter")
leave = agent:new("leave")
start = agent:new("start")

-- spawn the pi-threads
agent:spawn("Launch",Launch,N,lock,start,
  function (thread)
    print("Process "..thread.name..": critical section")
  end)

agent:spawn("Observer",Observer,enter,leave)
agent:spawn("Barrier",Barrier,start,lock,enter,leave)

print("Starting the agent")
agent:run()
