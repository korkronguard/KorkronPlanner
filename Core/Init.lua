-- Kor'kron Planner: shared namespace, printing, safe calls and events.
local ADDON, KP = ...
KorkronPlanner = KP -- global for /dump and debugging

KP.name = ADDON
KP.errors = {} -- { { message, count }, ... }: each different error once, the newest 20

local PREFIX = "|cffc41f3bKor'kron Planner|r: "

function KP:Print(...)
  print(PREFIX .. strjoin(" ", tostringall(...)))
end

function KP:Debug(...)
  if KorkronPlannerDB and KorkronPlannerDB.debug then
    print("|cff888888KP debug:|r " .. strjoin(" ", tostringall(...)))
  end
end

-- an error is kept once (repeats just count up), the list holds the newest 20, and the chat notice shows when the
-- list goes from empty to not empty (once, and again after /kp errors clear)
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

-- the error text plus where it happened (for /kp errors)
local function Traceback(e)
  local stack = debugstack and debugstack(2, 4, 0)
  return tostring(e) .. (stack and ("\n" .. stack) or "")
end

-- Run fn safely: an error is kept for /kp errors and announced once, instead of silently breaking the addon
-- (WoW hides addon errors by default).
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

-- Forever can hide values from addons ("secret values", see issecretvalue). Any maths, comparison (even `== nil`)
-- or string work on one throws an error, so check Readable before touching a game value at all.
function KP.Readable(v)
  return not (issecretvalue and issecretvalue(v))
end

-- A game value as a plain string, or nil when it's missing or hidden
function KP.Text(v)
  if not KP.Readable(v) or v == nil then return nil end
  return tostring(v)
end

-- A game number as text with at most `places` decimals ("12.5"), or "" when it's missing or hidden
function KP.Num(v, places)
  if not KP.Readable(v) or v == nil then return "" end
  local text = ("%." .. places .. "f"):format(tonumber(v) or 0):gsub("%.?0+$", "") -- gsub also returns a count
  return text
end

-- Run fn after `seconds`, through KP.Safe
function KP.After(seconds, fn)
  C_Timer.After(seconds, function() KP.Safe(fn) end)
end

-- Events: KP:On("EVENT", function(...) end)
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
