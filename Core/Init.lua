local ADDON, KP = ...
KorkronPlanner = KP

KP.name = ADDON
KP.errors = {}

local PREFIX = "|cffc41f3bKor'kron Planner|r: "

function KP:Print(...)
  print(PREFIX .. strjoin(" ", tostringall(...)))
end

function KP:Debug(...)
  if KorkronPlannerDB and KorkronPlannerDB.debug then
    print("|cff888888KP debug:|r " .. strjoin(" ", tostringall(...)))
  end
end

local function RecordError(err)
  err = tostring(err)
  for _, e in ipairs(KP.errors) do
    if e.message == err then
      e.count = e.count + 1
      return
    end
  end
  local first = #KP.errors == 0
  table.insert(KP.errors, { message = err, count = 1 })
  if #KP.errors > 20 then table.remove(KP.errors, 1) end
  if first then KP:Print("something went wrong; type /kp errors to see it.") end
end

local function Traceback(e)
  local stack = debugstack and debugstack(2, 4, 0)
  return tostring(e) .. (stack and ("\n" .. stack) or "")
end

function KP.Safe(fn, ...)
  local n = select("#", ...)
  local ok, err
  if n == 0 then
    ok, err = xpcall(fn, Traceback)
  else
    local args = { ... }
    ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, Traceback)
  end
  if not ok then RecordError(err) end
  return ok, err
end

function KP.Readable(v)
  return not (issecretvalue and issecretvalue(v))
end

function KP.Text(v)
  if not KP.Readable(v) or v == nil then return nil end
  return tostring(v)
end

function KP.Num(v, places)
  if not KP.Readable(v) or v == nil then return "" end
  local text = ("%." .. places .. "f"):format(tonumber(v) or 0)
  if places > 0 then text = text:gsub("0+$", ""):gsub("%.$", "") end
  return text
end

function KP.ItemFields(link)
  local itemString = link and link:match("item:([%-%d:]+)")
  if not itemString then return nil end
  local fields = {}
  for v in (itemString .. ":"):gmatch("([^:]*):") do table.insert(fields, v) end
  return fields
end

function KP.ItemBonusIDs(fields)
  local ids = {}
  for i = 14, 13 + (tonumber(fields[13]) or 0) do table.insert(ids, fields[i]) end
  return table.concat(ids, "+")
end

function KP.Version()
  local metadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return metadata(ADDON, "Version")
end

function KP.After(seconds, fn)
  C_Timer.After(seconds, function() KP.Safe(fn) end)
end

local frame = CreateFrame("Frame")
local handlers = {}
frame:SetScript("OnEvent", function(_, event, ...)
  for _, fn in ipairs(handlers[event] or {}) do
    KP.Safe(fn, ...)
  end
end)

function KP:On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(handlers[event], fn)
end
