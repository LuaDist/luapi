
--[[ 
This is a benchmark example from the Great Computer Language Shootout
http://shootout.alioth.debian.org/

This "cheap concurrency" benchmark is described as follows:

Each program should create, keep alive, and send integer messages between N explicitly-linked threads. Programs may use kernel threads, lightweight threads, cooperative threads

Each program should

    * create 500 threads - each thread should
          o hold and use a reference to the next thread
          o take, and increment, an integer message
          o put the incremented message on the next thread
    * N times
          o put the integer message 0 on the first thread
          o add the message taken and incremented by the last thread to a sum
    * print the sum of incremented integer messages - a count of takes

]]

require "pithreads"

N = tonumber(arg and arg[1]) or 10

function Link(proc,take,follow)
  while true do
    local n = proc:receive(take)
    --print(proc.name,"receives",n)
    proc:send(follow,n+1)
  end
end

function Producer(proc,put)
  local n=1
  while n<=N do
    --print("Producer sends ",0)
    proc:send(put,0)
    n = n + 1
  end
end

function Consummer(proc,take)
  local n=1
  local sum=0
  while n<=N do
    sum = sum + proc:receive(take)
    --print("Consumer updates sum",sum)
    n = n + 1
  end
  print(sum)
end

agent = pithreads.init()

local NbLinks = 500
local nb = 1
local lprev = agent:new("link1")
local lfirst = lprev
while nb <= NbLinks do
  local lnext = agent:new("link"..tostring(nb+1))
  agent:spawn("Link"..tostring(nb),Link,lprev,lnext)
  lprev = lnext
  nb = nb + 1
end

agent:spawn("Consummer",Consummer,lprev)
agent:spawn("Producer",Producer,lfirst)

agent:run()
