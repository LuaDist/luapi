
require "pithreads"

FUEL = tonumber(arg and arg[1]) or 1000

function Positive(proc,chan,fuel)
  while fuel>0 do
    proc:choice( 
      { chan:send(1), function() print "Positive: sends 1" end },
      { chan:receive(), function(x) print("Positive: receives "..tostring(x)) end }
    )()
    fuel = fuel - 1
  end
end

function Negative(proc,chan,fuel)
  while fuel>0 do
    proc:choice( 
      { chan:send(2), function() print "Negative: sends 2" end },
      { chan:receive(), function(x) print("Negative: receives "..tostring(x)) end }
    )()
    fuel = fuel - 1
  end
end

agent = pithreads.init()

chan = agent:new("chan")
agent:spawn("Positive",Positive,chan,FUEL)
agent:spawn("Negative",Negative,chan,FUEL)

agent:run()