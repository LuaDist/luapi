--[[ This example tests join patterns.
It is inspired by the JoCaml manual (cf. http://jocaml.inria.fr)
--]]

require "pithreads"

function FruitAndCake(proc,fruit,cake)
  while true do
    proc:join({fruit:receive(), cake:receive()},
              function(f,c)
                print(f.." "..c)
              end)()
  end
end

function Cake(proc,cake,name,finish)
  proc:send(cake,name)
  proc:signal(finish)
end

function Fruit(proc,fruit,name,finish)
  proc:send(fruit,name)
  proc:signal(finish)
end

function Main(proc,fruit,cake)
  local finish = proc:new("finish")

  -- first example
  proc:spawn("Cake",Cake,cake,"pie",finish)
  proc:spawn("Fruit",Fruit,fruit,"apple",finish)

  proc:wait(finish)
  proc:wait(finish)

  -- second example
  proc:spawn("Cake1",Cake,cake,"crumble",finish)
  proc:spawn("Cake2",Cake,cake,"pie",finish)
  proc:spawn("Fruit1",Fruit,fruit,"rhaspberry",finish)
  proc:spawn("Fruit2",Fruit,fruit,"apple",finish)

  proc:wait(finish)
  proc:wait(finish)
  proc:wait(finish)
  proc:wait(finish)
end

local agent = pithreads.init()

local fruit = agent:new("fruit")
local cake = agent:new("cake")

agent:spawn("Main",Main,fruit,cake)
agent:spawn("FruitAndCake",FruitAndCake,fruit,cake)

agent:run()