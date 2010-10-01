module(...,package.seeall);

local TestingEnabled = true
local TestChecked = 0
local TestPositive = 0
local TestNegative = 0

function enableTests()
  TestingEnabled = true
end

function disableTests()
  TestingEnabled = false
end

function resetTests()
  TestChecked = 0
  TestPositive = 0
  TestNegative = 0
end

function check(expr,expect,message) 
  if TestingEnabled then
    TestChecked = TestChecked + 1
    if not (expr == expect) then
      TestNegative = TestNegative + 1
      print("Check error:",message,"test #",TestChecked)
      print(" => expected",expect)
      print(" => given",expr)
    else
      TestPositive = TestPositive + 1
    end
  end
end

function checkSummary() 
  print("Check Summary:")
  print(" => Passed tests:",TestPositive)
  print(" => Failed tests:",TestNegative)
end

-- Q : no other way get the length and/or to test if the table is empty ?
function lengthOfTable(table) 
  local count = 0
  for k,v in pairs(table) do
    count = count + 1
  end
  return count
end

local function toStringTable(table,depth,uptables)
  --print("toStringTable",table,"depth="..tostring(depth))
  if depth==0 then return tostring(table) end
  local str = "{";
  local count = lengthOfTable(table)
  for k,v in pairs(table) do
    local vstr = ""
    if type(v) == "table" then
      -- print(uptables[v])
      if uptables[v]~= nil then
        vstr = "<cycle>"
      else 
        uptables[v] = v
        vstr = toStringTable(v,depth-1,uptables)
      end
    else 
      vstr = toString(v)
    end
    -- print("vstr = "..vstr)
    if type(k)=="number" then
      str = str .. " " .. vstr
    else
      str = str .. " " .. tostring(k) .. " = " .. vstr
    end
    count = count - 1
    if count>0 then str = str .. "," else str = str .. " " end
  end
  str = str .. "}"
  --print("str",str)
  return str
end

function toString(v,...)
  --print("type of v = ",v,"is",type(v))
  local quoted = true
  local depth = 2 -- default depth is 2 we print tables in tables
  if #arg > 0 then
    if arg[1]=="unquoted" then
      quoted = false
    elseif type(arg[1])=="number" then
      depth = arg[1]
    end
    if arg[2]=="unquoted" then
      quoted = false
    elseif type(arg[2])=="number" and depth == 1 then
      depth = arg[2]
    end
  end
  if type(v)=="table" then
    return toStringTable(v,depth,{})
  elseif (type(v)=="string") and quoted then
    return '"'..tostring(v)..'"'
  else
    return tostring(v)
  -- return string.format("%d",v) -- Q: how to convert other numbers ?
  -- Q: stack overflow do not pop up ???
  -- Q: silently fails when some bad happens ???
  end
  error("SHOULD NOT BE HERE (CONTACT author)")
end

function printTable(t)
  print(toString(t))
end