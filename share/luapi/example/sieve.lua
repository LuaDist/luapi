require "pithreads"

function GenInt2(proc,i,nb,gen)
  while i<nb do
    proc:send(gen,i)
    i = i + 2
  end
end

function PrimeFilter(proc,cin,n,cout)
  local x = proc:receive(cin)
  if x % n == 0 then
    PrimeFilter(proc,cin,n,cout)
  else
    proc:send(cout,x)
    PrimeFilter(proc,cin,n,cout)
  end
end

function EndPrimeFilter(proc,cin)
  local x = proc:receive(cin)
  local cout = proc:new("out")
  print(x," is prime")
  proc:spawn("PrimeFilter("..tostring(x)..")",PrimeFilter,cin,x,cout)
  EndPrimeFilter(proc,cout)
end

agent = pithreads.init()

local gen = agent:new("gen")
local out = agent:new("out")

agent:spawn("Generator",GenInt2,3,1000,gen)
agent:spawn("PrimeFilter(2)",PrimeFilter,gen,2,out)
agent:spawn("EndPrimeFilter",EndPrimeFilter,out)

agent:run()
