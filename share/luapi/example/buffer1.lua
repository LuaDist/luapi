-- a one place buffer example
-- (concurrent/buffer1.pi in CubeVM)

require "pithreads"

NB_WRITERS = tonumber(arg and arg[1]) or 2
WRITER_FUEL = tonumber(arg and arg[2]) or 4
NB_READERS = tonumber(arg and arg[1]) or 3
READER_FUEL = tonumber(arg and arg[4]) or 4

function Cell(proc,read,write,ival)
   local val = ival
   while true do
      proc:choice(
      {write:receive(), function(nval)
			   print("Written: " .. tostring(nval))
			   val = nval
			end },
      {read:send(val) })()
   end
			  
end


function Reader(proc,read,fuel)
   while fuel>0 do
      local val = proc:receive(read)
      print("Reader reads: " .. tostring(val) .. " (fuel=" .. tostring(fuel) .. ")")
      fuel = fuel - 1
   end
end

function Writer(proc,write,num,fuel)
   while fuel>0 do
      proc:send(write,num)
      print("Writer writes: " .. tostring(num))
      fuel = fuel - 1
   end
end


function SpawnReaders(agent,nbR,read,fuel)
   while nbR >0 do
      agent:spawn("Reader"..tostring(nbR),Reader,read,fuel)
      nbR = nbR - 1
   end
end

function SpawnWriters(agent,nbW,write,fuel)
   while nbW > 0 do
      agent:spawn("Writer"..tostring(nbW),Writer,write,nbW,fuel)
      nbW = nbW - 1
   end
end

agent = pithreads.init()

local read = agent:new("read")
local write = agent:new("write")

agent:spawn("Cell",Cell,read,write,-1)

SpawnReaders(agent,NB_READERS,read,READER_FUEL)
SpawnWriters(agent,NB_WRITERS,write,WRITER_FUEL)

agent:run()
