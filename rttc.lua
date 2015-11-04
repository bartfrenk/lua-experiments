-- luacheck: globals RunTimeTypes declare boolean option any protect check
RunTimeTypes = {_G = _G}
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local error = error
local type = type
local rawset = rawset
local rawget = rawget
local tostring = tostring
local table = table
_G.setfenv(1, RunTimeTypes)

function option(base)
  local function fn(x)
    if x == nil then
      return true
    else
      return base(x)
    end
  end
  return fn
end

function boolean(x)
  return x ~= nil and type(x) == "boolean"
end

function any(x) -- luacheck: no unused args
  return true
end

function protect(tbl)
  local mt = getmetatable(tbl) or {}
  mt.__declared = mt.__declared or {}

  for key, _ in pairs(tbl) do
    if mt.__declared[key] == nil then
      mt.__declared[key] = any
    end
  end

  mt.__index = function(t, key)
    if mt.__declared and mt.__declared[key] then
      return rawget(t, key)
    else
      error("Attempt to read undeclared field '"..key.."'")
    end
  end

  mt.__newindex = function(t, key, value)
    if mt.__declared and mt.__declared[key] then
      if mt.__declared[key](value) then
        rawset(t, key, value)
      else
        error("'"..tostring(value).."' does not have the correct type for '"..key.."'")
      end
    else
      error("Attempt to assign to undeclared field '"..key.."'")
    end
  end

  tbl.check = check
  tbl.declare = declare
  setmetatable(tbl, mt)
  return tbl
end

function declare(tbl, fields)
  local mt = getmetatable(tbl) or {}
  if (mt.__declared) then
    for name, validator in pairs(fields) do
      mt.__declared[name] = validator
    end
  else
    mt.__declared = fields
  end
  setmetatable(tbl, mt)
end

function check(tbl)
  local mt = getmetatable(tbl)
  if (not mt) or (not mt.__declared) then
    return
  end
  local violations = {}
  for name, validator in pairs(mt.__declared) do
    if not validator(tbl[name]) then
      table.insert(violations, name)
    end
  end
  if (#violations > 0) then
    local message = "Incorrect types for fields: "..table.concat(violations, ", ")
    error(message)
  end
end

_G.setfenv(1, _G)

local boolean = RunTimeTypes.boolean
local option = RunTimeTypes.option
local any = RunTimeTypes.any

local function test()
  local tbl = RunTimeTypes.protect {}
  tbl:declare{
    a = boolean,
    b = option(boolean),
    c = any,
    d = boolean
  }
  for key, value in pairs(getmetatable(tbl).__declared) do
    print(key, value)
  end
  print(pcall(function() tbl.a = nil end))
  tbl.a = false
  tbl.b = nil
  tbl.d = true
  tbl:check()
  tbl.a = nil
  tbl.b = true
  print(pcall(function() tbl:check() end))
  tbl.b = 4
  tbl.d = nil
  print(pcall(function() tbl:check() end))
end

test()
