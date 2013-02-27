module(...,package.seeall);

require "utils"

u=utils

-- **********************************
-- * Utility functions               
-- *
-- **********************************

-- debugging facility
DebugMode = true -- set to true/false to enable/disable debugging

local function DEBUG(proc,...) end
if DebugMode then
   DEBUG = function(proc,...)
      if proc ~= nil and proc.name ~= nil then
        print("["..proc.name.."]",...)
      else
        print("[AGENT]",...)
      end
  end
end

-- *****************************************
-- * Process management
-- *
-- * 
-- *****************************************

local destroy = function(proc) end

local function processInitWrapper(proc,fun,...)
  --coroutine.yield(proc)
  proc.mode = "ready"
  proc:yield()
  --DEBUG(proc,"starts with fun",fun,"arg",...)
  fun(proc,...)
  -- DEBUG(proc.agent,"HERE proc=",proc)
  destroy(proc)
end

-- create a new process
-- status mode is: init -> ready <-> waiting -> ended
-- R: missing scheme-like symbols  (+ dotted  symb1.symb2  is unique)
--    to implements abstract states
-- R : also missing hygienic macros (of course !)
-- R : thanks to coroutine, do not really miss call/cc (except for pedagogical purpose)
-- R : miss PARENTHESES (or course !)
-- commitments in a table, each entry is chan -> { array of commitments by this process }
local function makeProcess(iagent,name,fun,...)
  local proc = { tag="proc", name=name, mode="init", commits = {}, agent=iagent,
                 routine=coroutine.create(processInitWrapper),send=send,emit=send,signal=send,
                 receive=receive,wait=receive,listen=receive,
                 trySend=trySend,tryReceive=tryReceive,
                 choice=Choice.make, tryChoice=Choice.try,
                 broadcast=broadcast,bcast=broadcast,speak=broadcast,talk=broadcast,
                 collect=collect,
                 join=Join.join,
                 new=function(proc,...) 
                       return proc.agent:new(...) 
                     end, 
                 spawn=function(proc,...) 
                         return proc.agent:spawn(...) 
                       end,
                 yield=yieldProcess}
  local procMT = { __tostring = processToString }
  setmetatable(proc,procMT)
  --DEBUG(iagent,"Make process: "..tostring(proc).." with arguments",...)
  table.insert(iagent.procs.ready,proc)
  proc.ref = #iagent.procs.ready   -- reference in the agent (O(1) detroy)
  local ret,res = coroutine.resume(proc.routine,proc,fun,...)
  if not ret then
    error("Initialisation error: "..res)
  end
  return proc
end

function processToString(proc)
  local str = "proc["..proc.name..":"..tostring(proc.ref).."("..proc.mode.."),commits={ "
  for chan,commits in pairs(proc.commits) do
    for i,commit in pairs(commits) do
      str = str .. commitToString(commit) .. " "
      end
  end
  str = str .. "}]"
  return str
end

-- global spawn function
spawn = makeProcess

-- global start function
start = startProcess

-- yield to another process
function yieldProcess(proc)
  --DEBUG(proc,"yields")
  result = coroutine.yield()
  --DEBUG(proc,"resumes with",u.toString(result))
  return result
end

-- makes a process waiting (yielding the associated coroutine)
local function awaitProcess(proc)
  --assert(proc.mode~="waiting","The process must not be already waiting")

  proc.mode="waiting"
  local ready = proc.agent.procs.ready
  local waiting = proc.agent.procs.waiting
  -- remove the process from the ready queue
  if #ready==1 then
    table.remove(ready,proc.ref)
  else
    ready[proc.ref] = ready[#ready]
    ready[proc.ref].ref = proc.ref
    table.remove(ready,#ready)
  end
  -- and put it in the waiting queue
  table.insert(waiting,proc)
  proc.ref = #waiting  
end

-- makes a join process waiting (yielding the associated coroutine)
local function awaitJoinProcess(proc)
  --assert(proc.mode~="waiting","The process must not be already waiting")

  proc.mode="joining"
  local ready = proc.agent.procs.ready
  local joining = proc.agent.procs.joining
  -- remove the process from the ready queue
  if #ready==1 then
    table.remove(ready,proc.ref)
  else
    ready[proc.ref] = ready[#ready]
    ready[proc.ref].ref = proc.ref
    table.remove(ready,#ready)
  end
  -- and put it in the joining queue
  table.insert(joining,proc)
  proc.ref = #joining
end

-- push a process in the prioritized queue (treated prioritarily by the scheduler)
local function pushPrioProcess(proc)
  --assert(proc~=nil,"The process must not be nil")
  --assert(proc.mode=="ready","The process must be ready to be prioritized")
  
  table.insert(proc.agent.procs.prio,proc)
end

-- pop a process from the prioritized queue (called by the scheduler)
local function popPrioProcess(agent)
  --assert(next(agent.procs.prio)~=nil,"The prioritized queue must not be empty")
  local proc = table.remove(agent.procs.prio)
  return proc
end

-- set a process in ready mode and put it in the ready and prioritized queues
local function readyProcess(proc)
  --assert(proc~=nil,"The process must not be nil")
  --assert(proc.mode=="waiting","The process must be initially waiting")

  proc.mode = "ready"

  local ready = proc.agent.procs.ready
  local waiting = proc.agent.procs.waiting
  -- remove the process from the waiting queue
  if #waiting==1 then
    table.remove(waiting,proc.ref)
  else
    waiting[proc.ref] = waiting[#waiting]
    waiting[proc.ref].ref = proc.ref
    table.remove(waiting,#waiting)
  end
  -- and put it in the ready queue
  table.insert(ready,proc)
  proc.ref = #ready
  
  pushPrioProcess(proc) -- makes the process prioritized
end

-- set a process in ready mode and put it in the ready and prioritized queues
local function readyJoiningProcess(proc)
  --assert(proc~=nil,"The process must not be nil")
  --assert(proc.mode=="waiting","The process must be initially waiting")

  proc.mode = "ready"

  local ready = proc.agent.procs.ready
  local joining = proc.agent.procs.joining
  -- remove the process from the joining queue
  if #joining==1 then
    table.remove(joining,proc.ref)
  else
    joining[proc.ref] = joining[#joining]
    joining[proc.ref].ref = proc.ref
    table.remove(joining,#joining)
  end
  -- and put it in the ready queue
  table.insert(ready,proc)
  proc.ref = #ready
end

-- awakes a process and return the commitment leading to the wake
local function awakeProcess(proc)
  --assert(proc~=nil,"The process must not be nil")

  --DEBUG(proc,"awaking")
  --DEBUG(proc,"coroutine status",coroutine.status(proc.routine))
  local err,ret = coroutine.resume(proc.routine)  -- TODO: what if res is false ?  error-management ?
  --DEBUG(proc,"end of wake with",err,res)
  -- --DEBUG(proc,"traceback: "..debug.traceback())
  if not err then
    error("Process "..tostring(proc).." aborted: \n ==> "..ret)
  end
  -- here ret is true so there is no error
  return ret -- should be a commitment
end

-- *****************************************
-- * Channel management
-- *
-- * 
-- *****************************************

-- create new channels
-- Commitments in a table, each entry is:
--    proc -> { commitments make by the process on THIS channel }
local function makeChannel(agent,name)
  local chan = { tag="chan", name=name, incommits={}, outcommits={}, 
                 send=Guard.send, receive=Guard.receive,
                 broadcasting=nil, collecting=nil, outjoin=nil, injoin=nil }
  local chanMT = { __tostring = channelToString }
  setmetatable(chan,chanMT)
  -- XXX: do not record channels globally (if needed, use weak references to
  --      let the GC perform its work...)
  -- table.insert(agent.chans,chan)
  return chan
end

function channelToString(chan)
  local str = "chan["..chan.name..",incommits={ "
  for proc,commits in pairs(chan.incommits) do
    for i,commit in ipairs(commits) do
      str = str .. commitToString(commit) .. " "
    end
  end
  str = str .. "}]"
  return str
end

-- global new (channel) function
new = makeChannel

-- *****************************************
-- * Commitment management
-- *
-- * 
-- *****************************************

-- a process makes a commitment (input or output) on chan
-- kind is "input" or "output"
-- cont is the continuation if the commitment is resolved
-- (only for non-deterministic choices)
local function makeCommitment(proc,chan,kind,cont) 
  -- create the commitment
  local commit = { tag="commit", proc=proc, chan=chan, kind=kind, cont=cont}
  local commitMT = { __tostring = commitToString }
  setmetatable(commit,commitMT)
  ----DEBUG(proc,"creating new commitment: "..u.toString(commit))
  ----DEBUG(proc,"process is " .. u.toString(cproc.name),"chan is " .. u.toString(chan,1))
  return commit
end

-- special case for input commitment
local function makeInputCommitment(proc,chan,cont)
  return makeCommitment(proc,chan,"input",cont)
end

-- special case for output commitment
local function makeOutputCommitment(proc,chan,value,extra,cont)
  commit = makeCommitment(proc,chan,"output",cont)
  commit.value = value
  commit.extra = extra
  return commit
end

function commitToString(commit)
  if commit.kind=="input" then
    return "Commit["..commit.proc.name.."<-"..commit.chan.name.."("..commit.kind..")]"
  else
    return "Commit["..commit.proc.name.."->"..commit.chan.name.."("..commit.kind..")]"
  end
end

-- function to look for a commitment of the correct kind
local function lookupCommitment(proc,commits)
  if commits==nil then
    return nil
  else
  -- look for a commitment
  --DEBUG(chan,"Lookup for commitment on "..tostring(chan).." of kind "..kind)
    for proc2,commits in pairs(commits) do
      -- TODO: here we always take the first commitment ... maybe a fair approach would be better
      -- (easy, keep a counter in the channel)
      if proc2~=proc then
        return commits[1]
      end
    end
  end
end

-- function to look for all commitments of the correct kind (used for broadcast only)
local function lookupAllCommitments(proc,commits)
  --DEBUG(chan,"Lookup for all commitments on "..tostring(chan).." of kind "..kind)
  if commits==nil then
    return nil
  else
    local selected = {}
    -- we only need to get one corresponding commitment for each found process
    for proc2,pcommits in pairs(commits) do
      --TODO: here select the first commitment of the peer process
      -- maybe other strategies could be implemented (random/fair)
      if proc2~=proc then -- XXX: should not be the case (a broadcasting process cannot put commitments)
        table.insert(selected,pcommits[1])
      end
    end
    return selected
  end
end

local function registerCommitment(proc,chan,commit)
  -- register the commitment in the process
  if proc.commits[chan] == nil then
    proc.commits[chan] = { commit }
  else
    table.insert(proc.commits[chan],commit)
  end
  --DEBUG(proc,"register commitment: "..u.toString(proc.commits,3))
  -- register the commitment in the channel
  local commits = nil
  if commit.kind=="input" then
    commits = chan.incommits
  else
    commits = chan.outcommits
  end

  if commits[proc] == nil then
    commits[proc] = { commit }
  else
   table.insert(commits[proc],commit)
  end
  --DEBUG(proc,"register commitment in chan: "..u.toString(chan.commits,3))
end

-- erase all commitments of a process
local function eraseCommitments(proc)
  --DEBUG(proc,"Erase commitments of "..tostring(proc))
  for chan,commits in pairs(proc.commits) do
    chan.incommits[proc] = nil
    chan.outcommits[proc] = nil
  end
  proc.commits = {}
end

-- *****************************************
-- * Choice management
-- *
-- * 
-- *****************************************


Guard = {}
function Guard.send(chan,value,...)
  return { tag="guard", chan=chan,mode="send",value=value,extra={...} }
end

function Guard.receive(chan)
  return { tag="guard", chan=chan, mode="receive" }
end

Choice = {}
function Choice.try(proc,...)
  local arg={...}
  local tryChoiceFun = function()
    local chosen = -1
    --DEBUG(proc,"Making choice, args = "..u.toString(arg,3))
    for i,ch in ipairs(arg) do
      local choice = ch[1]
      local cont = ch[2]
      --DEBUG(proc,"Analyse choice "..u.toString(choice))
      if type(choice)=="boolean" then
        if choice then
          if cont~=nil then -- if true
            cont()  -- the run the continuation
          end
          chosen = i  -- and selects this guard
          break;
        end
      elseif type(choice)=="function" then
        if choice() then -- boolean guard
          if cont~=nil then -- if true
            cont()  -- the run the continuation
          end
          chosen = i  -- and selects this guard
          break;
        end
      elseif type(choice)~="table" or choice.tag~="guard" or choice.mode==nil then
        error("Invalid guard")
      elseif choice.mode=="send" then
        -- if broadcasting then skip one scheduler round
        while choice.chan.broadcasting~=nil or choice.chan.outjoin~=nil do
          yieldProcess(proc)
        end
        -- first try to resolve the choice    
        local commit = lookupCommitment(proc,choice.chan.incommits)
        --DEBUG(proc,"Choice matches with input commitment: "..tostring(commit))
        if commit~=nil then
          eraseCommitments(commit.proc) -- erase commitments for the channel
          --DEBUG(proc,"awake choice process "..tostring(commit.proc).." for "..tostring(commit))
          pushPrioProcess(proc) -- put ourselves in the prioritized queue (but after the receiver)
          commit.value = choice.value -- gives the sent value to the receiver
          commit.extra = choice.extra
          commit.proc.lastCommit=commit -- the receiver will be awoken with the chosen commitment
          readyProcess(commit.proc) -- ready (and prioritize) the receiver
          yieldProcess(proc) -- yield this process and let the scheduler awake the receiver
          -- if I have a continuation, then run it (send: no argument)
          if cont~=nil then
            cont()
          end
          chosen = i -- the choice number is returned (for global continuation)
          break -- we quit the loop for the continuation activation
        end
      elseif choice.mode=="receive" then
        -- if collecting then skip one scheduler round
        while choice.chan.collecting~=nil or choice.chan.injoin~=nil do
          yieldProcess(proc)
        end
        -- first try to resolve the choice
        local commit = lookupCommitment(proc,choice.chan.outcommits)
        --DEBUG(proc,"Choice matches with output commitment: "..tostring(commit))
        if commit~=nil then
          eraseCommitments(commit.proc) -- erase commitments for the sender
          commit.proc.lastCommit = commit -- gives the sender the commited (for optional choice resolution)
          readyProcess(commit.proc) -- make the sender ready and prioritize it
          -- if I have a continuation, then run it (receive: pass argument)
          if cont~=nil then
            cont(commit.value,unpack(commit.extra))
          end
          chosen = i -- the choice number is returned (for global continuation)
          break -- we quit the loop for the continuation activation
        end
      else
        error("Invalid guard mode '" .. tostring(guard.mode) .. "'")
      end
    end -- for loop
    if chosen==-1 then
      return false
    else
      return true,chosen
    end
  end -- tryChoiceFun()
  return tryChoiceFun
end

function Choice.make(proc,...)
  local arg = {...}  -- lua pre 5.1 compatibility for luajit
  local choiceFun = function ()
    local commits = {}
    local chosen = -1
    --DEBUG(proc,"Making choice, args = "..u.toString(arg,3))
    for i,ch in ipairs(arg) do
      local choice = ch[1]
      local cont = ch[2]
      --DEBUG(proc,"Analyse choice "..u.toString(choice))
      if type(choice)=="boolean" then
        if choice then
          if cont~=nil then -- if true
            cont()  -- the run the continuation
          end
          chosen = i  -- and selects this guard
          break;
        end
      elseif type(choice)=="function" then
        if choice() then -- boolean guard
          if cont~=nil then -- if true
            cont()  -- the run the continuation
          end
          chosen = i  -- and selects this guard
          break;
        end
      elseif type(choice)~="table" or choice.tag~="guard" or choice.mode==nil then
        error("Invalid guard")
      elseif choice.mode=="send" then
        -- if broadcasting then skip one scheduler round
        while choice.chan.broadcasting~=nil or choice.chan.outjoin~=nil do
          yieldProcess(proc)
        end
        -- first try to resolve the choice    
        local commit = lookupCommitment(proc,choice.chan.incommits)
        --DEBUG(proc,"Choice matches with input commitment: "..tostring(commit))
        if commit~=nil then
          eraseCommitments(commit.proc) -- erase commitments for the channel
          --DEBUG(proc,"awake choice process "..tostring(commit.proc).." for "..tostring(commit))
          pushPrioProcess(proc) -- put ourselves in the prioritized queue (but after the receiver)
          commit.value = choice.value -- gives the sent value to the receiver
          commit.extra = choice.extra
          commit.proc.lastCommit=commit -- the receiver will be awoken with the chosen commitment
          readyProcess(commit.proc) -- ready (and prioritize) the receiver
          yieldProcess(proc) -- yield this process and let the scheduler awake the receiver
          -- if I have a continuation, then run it (send: no argument)
          if cont~=nil then
            cont()
          end
          chosen = i -- the choice number is returned (for global continuation)
          break -- we quit the loop for the continuation activation
        else -- else record the commitment
          table.insert(commits,makeOutputCommitment(proc,choice.chan,choice.value,choice.extra,cont))
        end
      elseif choice.mode=="receive" then
        -- if collecting then skip one scheduler round
        while choice.chan.collecting~=nil or choice.chan.injoin~=nil do
          yieldProcess(proc)
        end
        -- first try to resolve the choice
        local commit = lookupCommitment(proc,choice.chan.outcommits)
        --DEBUG(proc,"Choice matches with output commitment: "..tostring(commit))
        if commit~=nil then
          eraseCommitments(commit.proc) -- erase commitments for the sender
          commit.proc.lastCommit = commit -- gives the sender the commited (for optional choice resolution)
          readyProcess(commit.proc) -- make the sender ready and prioritize it
          -- if I have a continuation, then run it (receive: pass argument)
          if cont~=nil then
            cont(commit.value,unpack(commit.extra))
          end
          chosen = i -- the choice number is returned (for global continuation)
          break -- we quit the loop for the continuation activation
        else -- else record the commitment
          table.insert(commits,makeInputCommitment(proc,choice.chan,cont))
        end
      else
        error("Invalid guard mode '" .. tostring(guard.mode) .. "'")
      end
    end -- for loop
    if chosen==-1 then
      --DEBUG(proc,"Register all choice commitments in "..u.toString(commits))
      -- no branch has been chosen
      for i,commit in ipairs(commits) do
        commit.index = i
        proc.lastCommit = nil
        registerCommitment(proc,commit.chan,commit)
      end
      awaitProcess(proc)
      yieldProcess(proc)
      --DEBUG(proc,"(choice) Awaken with commitment "..u.toString(commit))
      local commit = proc.lastCommit
      proc.lastCommit = nil
      if commit.cont~=nil then -- there is a continuation to execute  
      --DEBUG(proc,"A continuation has to execute: ",commit.cont)
        if commit.kind=="output" then -- output continuation
          --DEBUG(proc,"Output (or broadcast) continuation (no arg)")
          commit.cont()
        elseif commit.kind=="input" then -- input continuation
          --DEBUG(proc,"Intput continuation (passed arg="..tostring(commit.value)..")")
          commit.cont(commit.value,unpack(commit.extra))
        end
      end
      --DEBUG(proc,"Choosen (after waiting) "..tostring(chosen).."th branch")
      return commit.index
    else
      --DEBUG(proc,"Choosen "..tostring(chosen).."th branch")
      return chosen
    end
  end
  return choiceFun
end

-- *****************************************
-- * Join patterns
-- *
-- * 
-- *****************************************
Join={}

function Join.activate(proc,boolguards,inguards,outguards)
  --DEBUG(proc,"Activate join pattern")
  -- first try to enable all boolean guards
  for i,guard in ipairs(boolguards) do
    if not guard() then
      return false
    end
  end

  --DEBUG(proc,"Activate join: boolean guards passed")

  -- second try to enable all output guards
  local incommits = {}
  for i,guard in ipairs(outguards) do
    local commit = lookupCommitment(proc,guard.chan.incommits)
    if commit==nil then
      return false
    end
    table.insert(incommits,commit)
  end

  --DEBUG(proc,"Activate join: output guards passed")

  -- second try to enable all input guards
  local outcommits = {}
  for i,guard in ipairs(inguards) do
    local commit = lookupCommitment(proc,guard.chan.outcommits)
    if commit==nil then
      --DEBUG(proc,"Activate join: input guard unmatched on "..tostring(guard.chan.name))
      return false
    end
    table.insert(outcommits,commit)
  end

  --DEBUG(proc,"Activate join: input guards passed")

  -- if we are here then we now all the output and input commitments
  -- that enable this join pattern
  return true,outcommits,incommits
end

function Join.protect(proc,inchans,outchans)
  for chan,v in pairs(inchans) do
    chan.injoin = proc
  end
  for chan,v in pairs(outchans) do
    chan.outjoin = proc
  end
end

function Join.unprotect(proc,inchans,outchans)
  for chan,v in pairs(inchans) do
    chan.injoin = nil
  end
  for chan,v in pairs(outchans) do
    chan.outjoin = nil
  end
end

function Join.enact(proc,incommits,outcommits,outguards)

  local values = {}

  -- awake sender processes
  for i,commit in ipairs(outcommits) do
    eraseCommitments(commit.proc) -- erase commitments for the channel
    commit.proc.lastCommit = commit -- tell the chosen commitment to the sender (choice resolution)
    readyProcess(commit.proc) -- we keep the priority but the sender will come next in the priority
    --DEBUG(proc,"Join: add first value",commit.value)
    local val = { commit.value }
    for i,value in ipairs(commit.extra) do
      --DEBUG(proc,"Join: add extra value",value)
      table.insert(val,value)
    end
    if #val==1 then
      --DEBUG(proc,"Join: added unique value",val[1])
      table.insert(values,val[1])
    else
      table.insert(values,val)
    end
  end

  -- awake receiver processes
  for i,commit in ipairs(incommits) do
    eraseCommitments(commit.proc) -- erase commitments for the channel
    commit.value = outguards[i].value -- gives the sent value to the receiver
    commit.extra = outguards[i].extra
    commit.proc.lastCommit=commit -- the receiver will be awoken with the chosen commitment
    readyProcess(commit.proc) -- ready (and prioritize) the receiver
  end

  --DEBUG(proc,"Join: returned values=",u.toString(values))
  return values
end

function Join.resolve(proc,incommits,outcommits,outguards,cont)
  local values = Join.enact(proc,incommits,outcommits,outguards)
  if next(values)==nil then -- no received value
    pushPrioProcess(proc) -- put ourselves in the prioritized queue (but after the receivers)
    yieldProcess(proc) -- not a receiver so pass the dutch
    if cont~=nil then
       cont()
    end
  else -- at least one received value
    if cont~=nil then
      cont(unpack(values))
    end
  end
end

function Join.join(proc,...)
  local args = { ... }
  local i = 1
  local patterns = {}
  while i<=#args do
    local boolguards = {}
    local outguards = {}
    local inguards = {}
    local outchans = {}
    local inchans = {}
    local pattern = args[i]
    if type(pattern)~="table" then
      error("A join pattern is expected")
    end
    for j,guard in ipairs(pattern) do
      if not guard then
         i = i + 1 -- do not record the whole pattern
         break
      elseif guard~=true then -- skip true guards
        if type(guard)=="function" then
          table.insert(boolguards,guard)
        elseif type(guard)~="table" then
          error("Invalid join pattern: Unknow guard type")
        elseif guard.mode==nil then
          error("Invalid join pattern: Missing guard mode")
        elseif guard.mode=="send" then
          outchans[guard.chan] = true
          table.insert(outguards,guard)
        elseif guard.mode=="receive" then
          table.insert(inguards,guard)
          inchans[guard.chan] = true
        else
          error("Invalid join pattern: invalid guard mode '" .. tostring(guard.mode) .. "'",2)
        end
      end
    end -- for j, ...
    local patt = { tag="join", boolguards=boolguards, outguards=outguards, inguards=inguards, inchans=inchans, outchans=outchans }
    i = i + 1
    if type(args[i])=="function" then
      patt.cont = args[i]
      i = i + 1
    end
    table.insert(patterns,patt)
  end -- end while

  local joinFun = function()
    while true do  -- join patterns are running until one is enabled
      local ok = false
      local outcommits = nil
      local incommits = nil
      local choice = 0
      local patt = nil
      -- (1) activate the patterns before yielding
      for i,pattern in ipairs(patterns) do
        ok, outcommits, incommits = Join.activate(proc,pattern.boolguards,pattern.inguards,pattern.outguards)
        if ok then 
          patt = pattern
          choice=i
          break 
        end
      end
      if ok then
        Join.resolve(proc,incommits,outcommits,patt.outguards,patt.cont)
        return choice
      end
      -- (2) protect the join channels  (join patterns are prioritary)
      --for i,pattern in ipairs(patterns) do
       --Join.protect(proc,pattern.inchans,pattern.outchans)
      --end
      -- (3) let one scheduler round pass
      yieldProcess(proc)
      -- (4) try to activate again the patterns after yielding
      for i,pattern in ipairs(patterns) do
        ok, outcommits, incommits = Join.activate(proc,pattern.boolguards,pattern.inguards,pattern.outguards)
        if ok then
          choice = i
          patt = pattern
          break 
        end
      end
      -- (5) unproctect the join channels
      --for i,pattern in ipairs(patterns) do
       --Join.unprotect(proc,pattern.inchans,pattern.outchans)
      --end
      -- (6) resolve join
      if ok then
        Join.resolve(proc,incommits,outcommits,patt.outguards,patt.cont)
        return choice
      end
      -- the join process must await
      awaitJoinProcess(proc)
    end
    -- not reachable
  end -- end of joinFun
  return joinFun
end

-- *****************************************
-- * Communication primitives
-- *
-- * 
-- *****************************************

-- non-blocking emission
function trySend(sender,chan,value,...)
  -- if broadcasting is active the cannot send now
  if chan.broadcasting~=nil or chan.outjoin~=nil then
    return false
  end

  local commit = lookupCommitment(sender,chan.incommits)
  if commit~=nil then
    local receiver = commit.proc
    eraseCommitments(receiver) -- erase commitments for the channel
    pushPrioProcess(sender) -- make this process the second in the list of prioritized processes
    commit.value = value -- tell the receiver the received value
    commit.extra = { ... }
    receiver.lastCommit = commit -- tell the receiver the chosen commitment
    readyProcess(receiver) -- ready and make the receiver prioritary    
    yieldProcess(sender) -- do not put in the waiting queue
    return true
  else
    return false
  end
end

-- blocking emission
function send(sender,chan,value,...)
   --DEBUG("Sender ",sender.name," send on channel ",chan,"value",value)
   -- if broadcasting then skip one scheduler round
   while chan.broadcasting~=nil or chan.outjoin~=nil do
      yieldProcess(sender)
   end

  --DEBUG(sender,"wants to send "..tostring(value)..","..tostring(extra).." on channel "..channelToString(chan))
  if trySend(sender,chan,value,...) then
    return
  else
    -- no input commitment found (only output commitments, so add a new commitment)
    commit = makeOutputCommitment(sender,chan,value,{...})
    sender.lastCommit = nil -- cancel the last commitment
    registerCommitment(sender,chan,commit)
    awaitProcess(sender) -- put in the waiting queue
    yieldProcess(sender) -- send forgets about any received value
    -- then continue when awoken
  end
end

-- the broadcast function
function broadcast(sender,chan,value,...)
  --DEBUG(sender,"wants to send "..tostring(value).." on channel "..channelToString(chan))

  -- if already broadcasting then yield before broadcasting again
  while chan.broadcasting~=nil or chan.outjoin~=nil do
    yieldProcess(sender)
  end
 
  -- restrict the use of chan for output
  chan.broadcasting = sender
  --  yields to ensure all the potential receivers are ready to receive
  yieldProcess(sender)
  -- the restriction is finished
  chan.broadcasting = nil

  -- look for a commitment
  local commits = lookupAllCommitments(sender,chan.incommits)
  if commits~=nil then
    pushPrioProcess(sender) -- make this process the next of receivers in the list of prioritized processes
    for i,commit in ipairs(commits) do
      local receiver = commit.proc
      eraseCommitments(receiver) -- erase commitments for the channel
      commit.value = value -- tell the receiver the received value
      commit.extra = { ... }
      receiver.lastCommit = commit -- tell the receiver the chosen commitment
      readyProcess(receiver) -- ready and make the receiver prioritary
    end
    yieldProcess(sender) -- do not put in the waiting queue
    return true -- ok the broadcast was a success
  else
    return false -- ko no potential receiver
  end
end

-- the collect function  (symmetric of broadcast)
function collect(receiver,chan)
  --DEBUG(sender,"wants to send "..tostring(value).." on channel "..channelToString(chan))

  -- if already collecting then yield before collecting again
  while chan.collecting~=nil or chan.injoin~=nil do
    yieldProcess(receiver)
  end
 
  -- restrict the use of chan for input
  chan.collecting = receiver
  --  yields to ensure all the potential receivers are ready to receive
  yieldProcess(receiver)
  -- the restriction is finished
  chan.collecting = nil

  --  yields to ensure all the potential senders are ready to send
  yieldProcess(receiver)
  -- the table (array) to store the collected values
  local collection = {}
  -- look for a commitment
  local commits = lookupAllCommitments(receiver,chan.outcommits)
  if commits~=nil then
    for i,commit in ipairs(commits) do
      local sender = commit.proc
      eraseCommitments(sender) -- erase commitments for the channel
      sender.lastCommit = commit -- for choice resolution
      collection[i] = {} 
      collection[i][1] = commit.value
      for j,val in ipairs(commit.extra) do
        collection[i][j] = val
      end
      readyProcess(sender) -- ready and make the sender prioritary
    end
  end

  -- we simply return the collection (and keep the control)
  return collection
end

-- receiveImpl
function tryReceiveImpl(receiver,chan)
  local commit = lookupCommitment(receiver,chan.outcommits)
  if commit~=nil then
    local sender = commit.proc
    eraseCommitments(sender) -- erase commitments for the channel
    sender.lastCommit = commit -- tell the chosen commitment to the sender (choice resolution)
    readyProcess(sender) -- we keep the priority but the sender will come next in the priority
    return commit
  else
    return nil
  end 
end

-- non-blocking reception funtion
function tryReceive(receiver,chan)
  --DEBUG(receiver,"tries to receive on "..channelToString(chan))

  -- if collecting then cannot receive now
  if chan.collecting~=nil or chan.injoin~=nil then
    return false
  end

  -- look for a commitment
  local commit = tryReceiveImpl(receiver,chan)
  if commit~=nil then
    return true,commit.value,unpack(commit.extra)
  else
    return false
  end 
end

-- the reception funtion
function receive(receiver,chan)
  --DEBUG(receiver,"tries to receive on "..channelToString(chan))

  -- if collecting then yield
  while chan.collecting~=nil or chan.injoin~=nil do
    yieldProcess(receiver)
  end

  -- look for a commitment
  local commit = tryReceiveImpl(receiver,chan)
  if commit~=nil then
    return commit.value,unpack(commit.extra)
  end
  -- no output commitments, only input commitments ... add one
  local commit = makeInputCommitment(receiver,chan)
  receiver.lastCommit = nil -- cancel the last commitment
  registerCommitment(receiver,chan,commit)
  ----DEBUG(receiver,"waiting with "..processToString(receiver))
  awaitProcess(receiver)
  yieldProcess(receiver) -- we should be awoken with a value
  --DEBUG(receiver,"received ",commit)
  return receiver.lastCommit.value , unpack(receiver.lastCommit.extra)
end

-- *****************************************
-- * Agent management
-- *
-- * An agent schedules a queue of processes
-- *****************************************

-- create a new agent (scheduler for processes)
local function makeAgent()
   -- XXX: chans queue not needed and probably bad wrt. Lua GC
   -- local agent = { procs = {}, chans = {}, routine=coroutine.create(scheduling), spawn=spawn,new=new,run=run }
   local agent = { tag="agent", procs = { prio = {}, ready = {}, waiting = {}, joining = {}}, routine=coroutine.create(scheduling), spawn=spawn,new=new,run=run,
                    replicate=replicate }
   local agentMT = { __tostring = agentToString } -- Q: how to make agentToString local ?
   setmetatable(agent,agentMT)
   return agent
end

function agentToString(agent)
  return u.toString(agent,3)
  -- return "Agent{}"
end

-- global init function
init = makeAgent

local function destroyProcess(proc)
  --DEBUG(proc,"to be destroyed")
  eraseCommitments(proc)
  local ready = proc.agent.procs.ready
  if #ready == 1 then
    table.remove(ready,proc.ref)
  else
    ready[proc.ref] = ready[#ready]
    ready[proc.ref].ref = proc.ref
    table.remove(ready,#ready)
  end
  proc.mode = "ended"
  --DEBUG(proc,"destroyed")
end

destroy = destroyProcess

-- the main scheduling function
function scheduling(agent)
  --DEBUG(agent,"started "..u.toString(agent))
  local finish = false
  local ready = agent.procs.ready
  local joining = agent.procs.joining
  local prio = agent.procs.prio
  local finishTurn = false
  while not finish do  
    --print(agent)
    --print "here"
    local i= 1
    local proc = nil
    while i<=#ready do
      if next(prio)~=nil then
        proc = popPrioProcess(agent)
        i = proc.ref
      else
        proc = ready[i]
      end
      --assert(proc.ref == i,"The process reference "..proc.ref.." must match the position "..i.." in the ready queue")
      --DEBUG(agent,"tries process #"..tostring(i),"process",proc.name,"(" .. proc.mode .. ")")
      local status = coroutine.status(proc.routine)
      --DEBUG(proc,"Coroutine status",status)
      --if status == "dead" then
	 --DEBUG(agent,"HERE")
        --destroyProcess(proc)
      --else
        --assert(proc.mode~="waiting","process must not be waiting")
        --DEBUG(agent,"awake process "..proc.name)
        awakeProcess(proc)
        --DEBUG(agent,"awakes with commitment "..tostring(commit))
        while #prio > 1 do
          proc = popPrioProcess(agent)
          i = proc.ref
          --DEBUG(agent,"awakes (2) with commitment "..tostring(commit))
          awakeProcess(proc)
        end
      --end
      i = i + 1
    end

    if next(ready)==nil then
      if not finishTurn and next(joining)~=nil then
        for ref,proc in ipairs(joining) do
          readyJoiningProcess(proc)
        end
        finishTurn=true
      else
        --print(agent)
        print("====")
        print("All Pi-theads terminated")
        finish=true
      end
    else -- more process to execute
      finishTurn = false
    end
  end
  --print("End of scheduling")
end

-- global run function
function run(agent)
  --print("Start scheduling")
  local res,ret = coroutine.resume(agent.routine,agent)
  if not res then
    error("Agent aborted: \n==> "..ret)
  end
end

-- *****************************************
-- * Misc. utilities
-- *
-- * Various useful user-level functions
-- *****************************************

function replicate(agent,procname,n,procfun,...)
  --DEBUG(agent,"replicate with arguments",...)  
  for i=1,n do
    agent:spawn(procname..tostring(i),procfun,i,...)
  end
end
