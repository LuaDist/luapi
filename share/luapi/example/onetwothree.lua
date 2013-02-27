
require "pithreads"

FUEL = tonumber(arg and arg[1]) or 1000

function Poke(proc,one,two,three,fuel)
  while fuel>0 do
    proc:choice( 
      { one:send(1), function() print "Poke: chooses 1" end },
      { two:send(2), function() print "Poke: chooses 2" end },
      { three:send(3), function() print "Poke: chooses 3" end }
    )()
    fuel = fuel - 1
  end
end

function Peek(proc,c1,c2,fuel)
  while fuel > 0 do
    proc:choice( 
      { c1:receive(), function(x) print(proc.name..": received on "..tostring(c1)..": "..tostring(x)) end },
      { c2:receive(), function(x) print(proc.name..": received on "..tostring(c2)..": "..tostring(x)) end }
    )()
    fuel = fuel - 1
  end
end
            
agent = pithreads.init()

one = agent:new("one")
two = agent:new("two")
three = agent:new("three")

poke = agent:spawn("Poke",Poke,one,two,three,FUEL)
peek1 = agent:spawn("Peek1",Peek,one,two,FUEL)
peek2 = agent:spawn("Peek2",Peek,three,two,FUEL)

agent:run()
