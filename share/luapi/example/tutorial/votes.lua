--[[
This is an implementation of a Voting protocol.
The example illustrates the primitives for atomic 
1-TO-N (broadcast) and 1-FROM-N (collect) interactions.
]]

require "pithreads"

NBVOTERS = tonumber(arg and arg[1]) or 5
NBTURNS = tonumber(arg and arg[2]) or 3

-- behavior for the vote coordinator
function Coordinator(thread,vote,nb,ifYes,ifNo)
  for turn=1,nb do
    -- (1) create a secret channel for this turn's vote
    local secret = thread:new("secret"..tostring(turn))
    -- (2) broadcast the vote activation message (with the secret channel)
    thread:broadcast(vote,turn,secret)
    -- (3) collect all votes
    local votes = thread:collect(secret)
    -- (4) analyze the votes and take the final decision
    --     Remark: votes is an array of returned values
    local nbYes = 0
    for i,yes in ipairs(votes) do
      if yes[1]==true then
        nbYes = nbYes + 1
      end
    end
    if nbYes >= #votes / 2 then
      ifYes(turn,#votes,nbYes)
    else
      ifNo(turn,#votes,nbYes)
    end
  end
end

-- the common behavior of voters
function Voter(thread,id,vote)
  while true do
    local turn, secret = thread:receive(vote)
    if math.random() > 0.5 then
      print("Voter #" .. tostring(id) .. ": vote YES")
      thread:send(secret,true) -- vote YES
    else
      print("Voter #" .. tostring(id) .. ": vote NO")
      thread:send(secret,false) -- vote NO
    end
  end
end

agent = pithreads.init()

vote = agent:new("vote")

agent:spawn("Coordinator",Coordinator,vote,NBTURNS,
            function(turn,nbVotes,nbYes)
              print("Turn #" .. tostring(turn) .. " global decision is YES")
              print("( " .. tostring(nbVotes) .. " voters, " .. tostring(nbYes) .. " voted Yes)")
            end,
            function(turn,nbVotes,nbYes)
              print("Turn #" .. tostring(turn) .. " global decision is NO")
              print("( " .. tostring(nbVotes) .. " voters, " .. tostring(nbYes) .. " voted Yes)")
            end)

agent:replicate("Voter",NBVOTERS,Voter,vote)

print("Starting the agent")
agent:run()

