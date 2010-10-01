--[[ This example demonstrate the use of join patterns
The join patterns comes from the join-calculus theory and
form the main feature of the Jocaml language (cf. http://jocaml.inria.fr).
Here we use join patterns to coordinate a concurrent implementation
of the quicksort algorithm.
--]]

require "pithreads"

LENGTH = tonumber(arg and arg[1]) or 50
MIN = tonumber(arg and arg[2]) or 1
MAX = tonumber(arg and arg[3]) or LENGTH

function RandomPivot(imin,imax)
  return math.random(imin,imax)
end

function MidPivot(imin,imax)
  return (imax-imin) / 2 + imin
end

function MinPivot(imin,imax)
  return imin;
end

function MaxPivot(imin,imax)
  return imax;
end

function Partition(tab,pivot)
  local left = {}
  local right = {}
  local rep = 0
  local prev = nil
  for i,elem in ipairs(tab) do
    if elem==prev then
      rep = rep + 1
    end
    prev = elem
    if elem<=pivot then
      table.insert(left,elem)
    else
      table.insert(right,elem)
    end
  end
  return rep~=#tab-1,left,right
end

function Assemble(left,right)
  for i,elem in ipairs(right) do
    table.insert(left,elem)
  end
  return left
end

function QuickSort(proc,tab,pivotfun,finish)
  if #tab<=1 then
    proc:send(finish,tab)
    return
  end
  local pivotindex = pivotfun(1,#tab)
  local cont,left,right = Partition(tab,tab[pivotindex])
  if not cont then
    proc:send(finish,tab)
    return
  end
  local finish1 = proc:new("finish1")
  local finish2 = proc:new("finish2")
  proc:spawn("Sort",QuickSort,left,pivotfun,finish1)
  proc:spawn("Sort",QuickSort,right,pivotfun,finish2)
  left = proc:receive(finish1)
  right = proc:receive(finish2)
--[[
  local ok = proc:join({ finish1:receive(), finish2:receive() },
                      function(left,right)
                        proc:send(finish,Assemble(left,right))
                      end)()
  if not ok then
    error("Join failure")
  end
]]
  proc:send(finish,Assemble(left,right))
end

function PrintTab(tab)
  local str = "[ "
  for i,elem in ipairs(tab) do
    str = str .. tostring(elem)
    if i<#tab then
      str = str .. ", "
    end
  end
  str = str .. " ]"
  return str
end

function Main(proc,tab)
  print("Initial: " .. tostring(PrintTab(tab)))
  local finish = proc:new("finish")

  proc:spawn("Sort",QuickSort,tab,RandomPivot,finish)
  local sorted = proc:receive(finish)

  print("Sorted: " .. tostring(PrintTab(sorted)))
end

local agent = pithreads.init()

local tab = {}
for i=1,LENGTH do
  table.insert(tab,math.random(MIN,MAX))
end 

agent:spawn("Main",Main,tab)

agent:run()