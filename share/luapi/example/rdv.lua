--[[
This example shows a unicast implementation of a useful concurrency
pattern: Rendez-vous communication.

A (simpler) broadcast implementation is proposed in brdv.lua
]]


require "pithreads"
require "utils"

NBRDV = tonumber(arg and arg[1]) or 100
NBPROCS = tonumber(arg and arg[2]) or 1000

RDVcount = 1

function RDVRegister(proc,reg,nb)
  local n = nb
  local rdv = proc:new("rdv"..tostring(RDVcount))
  while n>0 do
    local init = proc:receive(reg)
    proc:send(init,rdv)
    n = n - 1
  end
  RDVcount = RDVcount + 1
  proc:spawn("RendezVous"..tostring(RDVcount),RDVRegister,reg,nb)
  RendezVous(proc,rdv,nb)
end

function RendezVous(proc,rdv,nb)
  local n = nb
  print(proc.name .. " activation")
  while n > 0 do
    proc:send(rdv)
  end
end

function Participant(proc,n,reg)
  local init = proc:new("init-"..proc.name)
  proc:send(reg,init)
  local rdv = proc:receive(init)
  print("Participant "..proc.name.." registered")
  proc:receive(rdv)
  print("Partipant "..proc.name.." joined")
end

agent = pithreads.init()

reg = agent:new("reg")

agent:spawn("RendezVous"..tostring(RDVcount),RDVRegister,reg,NBRDV)
pithreads.replicate(agent,"Participant",NBPROCS,Participant,reg)

print("Starting the agent")
agent:run()

