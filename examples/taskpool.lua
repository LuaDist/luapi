
require "pithreads"
require "utils"


function TaskPool(proc,remain,enter,leave)
  while true do
    if remain>0 then
        proc:choice( 
        { enter:receive(),  function(id) print("[OPEN] Entering: "..tostring(id))
                                remain = remain - 1
                            end },
        { leave:receive(),  function(id) print("[OPEN] Leaving: "..tostring(id))
                                remain = remain + 1
                            end }
        )()
    else
      local id = proc:receive(leave)
      print("[CLOSE] Leaving: "..tostring(id))
      remain = remain + 1
    end
  end
end


function Task(proc,id,sleep,enter,leave)
  proc:send(enter,id)
  while sleep>0 do
    proc:yield()
    sleep = sleep -1
  end
  proc:send(leave,id)
end


NBTASKS = tonumber(arg and arg[1]) or 1000

POOLSIZE = 50
SLEEP = 10

agent = pithreads.init()

enter = agent:new("enter")
leave = agent:new("leave")

agent:spawn("TaskPool",TaskPool,POOLSIZE,enter,leave)

pithreads.replicate(agent,"Task",NBTASKS,Task,SLEEP,enter,leave)

print("Starting the agent")
agent:run()

