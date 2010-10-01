--[[
This is the classical example of the dining philosophers
by Edsger W. Dijsktra.

The solution proposed here demonstrates the use of the
join patterns to ensure safety.

Note that this version is fair : all philosophers are able
to eat regularly.
]]


require "pithreads"
require "utils"

-- the number of philosophers
NBPHILOS = tonumber(arg and arg[1]) or 5
-- the number of resources (forks,plates,chairs)
NBRES = tonumber(arg and arg[2]) or 5
-- then quantity of noodle in each plate (nil cancels termination)
QUANTITY = tonumber(arg and arg[3]) or 10

-- global statistics
STATS = {}

-- the behavior of forks
function Fork(thread,take)
  while true do
    thread:signal(take)
    --print(thread.name.." taken")
    thread:wait(take)
    --print(thread.name.." released")
  end
end

-- the behavior of plates
function Plate(thread,eat,quantity)
  while quantity==nil or quantity>0 do
    thread:send(eat,1) -- one noodle
    if quantity~=nil then
      quantity = quantity - 1
    end
  end
  thread:send(eat,0)
end

-- the behavior of chairs
function Chair(thread,seat,fork1,fork2,plate)
  local leave = thread:new("leave:"..thread.name)
  local ok = true
  while ok do
    thread:send(seat,fork1,fork2,plate,leave)
    --print(thread.name.." used")
    ok = thread:receive(leave)
    --print(thread.name.." leaved")
  end
  print(thread.name.." removed")
end

-- the bevahior of philosophers
function Philo(thread,seat,activate)
  local total = 0
  while true do
    print(thread.name .. " thinks")
    local fork1,fork2,eat,leave = thread:receive(seat)
    print(thread.name .. " seats")
    local reply = thread:receive(activate)
    print(thread.name .. " gets the reply code")
    thread:join({ fork1:receive(), fork2:receive() }, 
              function(f1,f2) print(thread.name .. " takes the forks") 
              end)()
    local nb = thread:receive(eat)
    total = total + nb
    STATS[thread.name] = total
    print(thread.name .. " eats " .. tostring(nb) .. " noodle(s)")
    thread:signal(fork1)
    thread:signal(fork2)
    print(thread.name .. " releases the forks")

    thread:signal(reply)
    print(thread.name .. " abandons the reply code")

    if nb==0 then
      thread:send(leave,false)
      print(thread.name .. " .. Nothing to eat ? leave the table")
      thread:wait(reply)
      return -- the threadess should die
    else
      thread:send(leave,true)
      print(thread.name .. " leaves the table")
      thread:wait(reply)
    end
  end
end

-- the reply codes dispatcher
function Dispatcher(thread,activate,nbres,nbthreads)
  while true do
    local threadcount = 1
    local replies = {}
    while threadcount <= nbthreads do
      local first = threadcount
      for i=first,nbres+first-1 do
        table.insert(replies,thread:new("reply"..tostring(i)))
        thread:send(activate,replies[threadcount])
        threadcount = threadcount + 1
      end
      for i=first,nbres+first-1 do
        thread:wait(replies[i])
      end
    end
    for i,reply in ipairs(replies) do
      thread:signal(reply)
    end
  end
end

agent = pithreads.init()

local seat = agent:new("seat")
local activate = agent:new("activate")

-- creating the forks and plates
local forks = {}
local plates = {}
for i=1,NBRES do
  -- create the i-th fork
  local fork = agent:new("fork"..tostring(i))
  table.insert(forks,fork)
  agent:spawn("Fork"..tostring(i),Fork,fork)
  -- create the i-th plate
  local plate = agent:new("plate"..tostring(i))
  table.insert(plates,plate)
  agent:spawn("Plate"..tostring(i),Plate,plate,QUANTITY)
end

-- creating the chairs
agent:spawn("Chair1",Chair,seat,forks[NBRES],forks[1],plates[1])
for i=2,NBRES do
  agent:spawn("Chair"..tostring(i),Chair,seat,forks[i-1],forks[i],plates[i])
end

local inits = {}
for i=1,NBPHILOS do
  local init = agent:new("init"..tostring(i))
  table.insert(inits,init)
  -- create the i-th philosopher
  agent:spawn("Philo"..tostring(i),Philo,seat,activate)
end

agent:spawn("Dispatcher",Dispatcher,activate,NBRES,NBPHILOS)

print("Starting the agent")
agent:run()

print("Ending the agent")
print("Consumption statistics:")
local totals = 0
for pname,total in pairs(STATS) do
  print(pname..": "..tostring(total))
  totals = totals + total
end
print("Total consumption = " ..tostring(totals))