
require "pithreads"

FUEL = tonumber(arg and arg[1]) or 10

function MaxDie(proc,die,fuel)
  -- need to prepare the lexical environment for the choice
  local die1 , die2
  -- prepare the choice in advance
  local choice = proc:choice( 
      { function() return die1 >= die2 end, function() print "MaxDie: chooses die 1" ; proc:send(die,die1) end },
      { true, function() print "MaxDie: chooses die 2" ; proc:send(die,die2) end })
  -- main loop
  while fuel>0 do
    die1 = math.random(6) -- change the variables in current scope (affects the choice)
    die2 = math.random(6)
    local ch = choice() -- enact the choice once
    print("MaxDie: Branch #" .. tostring(ch) .. " executed")
    fuel = fuel - 1
  end
end

function FetchDie(proc,diechan)
  while true do
    local die = proc:receive(diechan)
    print("FetchDir: received " .. tostring(die))
  end
end

agent = pithreads.init()

die = agent:new("die")

maxDie = agent:spawn("MaxDie",MaxDie,die,FUEL)
fetchDie = agent:spawn("FetchDie",FetchDie,die,FUEL)

agent:run()
