--[[
This example demonstrates an asynchronous model
of communication built above the LuaPi primitives.
Most importantly, the example also illustrates the
use of the expressive choice construct.
]]

-- import the LuaPi module
require "pithreads"

-- the number of writer threads
NWRITERS = tonumber(arg and arg[1]) or 100
-- the number of writes per writer
NWRITES = tonumber(arg and arg[2]) or 10
-- the number of writer threads
NREADERS = tonumber(arg and arg[3]) or 50
-- the capacity of the queue
CAPACITY = tonumber(arg and arg[4]) or 25

-- a behavior for a message Queue behavior
function MsgQueue(thread,put,take,capacity)
  local queue = {}
  while true do
    print("Queue size: ",#queue)
    -- empty queue (can only put)
    if next(queue)==nil then
      print("Queue is empty")
      local msg = thread:receive(put)
      table.insert(queue,1,msg)
    -- full queue (can only take)
    elseif #queue==capacity then
      print("Queue is full")
      local msg = table.remove(queue)
      thread:send(take,msg)
    else -- other cases (can put or take)
      local msg = queue[#queue]
      thread:choice(
        { put:receive(),  function(msg)
                           table.insert(queue,1,msg)
                          end },
        { take:send(msg), function()
                           table.remove(queue)
                          end })()
    end
  end
end

-- A behavior for writer threads
function Writer(thread,id,put,msg,count)
  local first = count
  while count>0 do
    print("Writer #",id," sends: ",msg..tostring(first+1-count))
    thread:send(put,msg..tostring(first+1-count))
    count = count - 1
    thread:yield() -- for better illustration of behavior
  end
end

-- A behavior for reader threads
function Reader(thread,id,take)
  while true do
    local msg = thread:receive(take)
    print("Reader #",id," receives: ",msg)
    thread:yield() -- for better illustration of behavior
  end
end

-- create the agent
agent = pithreads.init()

-- create the channels
put = agent:new("put")
take = agent:new("take")

-- spawn the threads

agent:spawn("MsgQueue",MsgQueue,put,take,CAPACITY)

agent:replicate("Writer",NWRITERS,Writer,put,"<BEEP>",NWRITES)
agent:replicate("Reader",NREADERS,Reader,take)

print("Starting the agent")
agent:run()
