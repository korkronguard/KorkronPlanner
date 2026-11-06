-- Kor'kron Planner: "a new version is out". The game can't see WowUp, so guildmates' addons tell each other their
-- version over the guild's addon channel (Comm.lua); a newer one than yours gets a line in chat, once a session, and
-- again at each login until you update (KorkronPlannerDB.newestSeen).
--   V^version   sent once, 20 seconds after login (outside instances). An addon with a newer version answers once,
--               a few seconds later, unless another one already did.
-- Addons before 0.14.1 don't know this message and ignore it.
local _, KP = ...

local Update = {}
KP.Update = Update
local Comm = KP.Comm

local URL = "https://github.com/korkronguard/KorkronPlanner"
local AFTER_LOGIN = 20 -- seconds: chat and the guild channel settle first

-- "0.14.1" -> { 0, 14, 1 }
local function Parts(version)
  local out = {}
  for n in version:gmatch("%d+") do out[#out + 1] = tonumber(n) end
  return out
end

-- whether version a is newer than b
function Update.Newer(a, b)
  local x, y = Parts(a), Parts(b)
  for i = 1, math.max(#x, #y) do
    if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) > (y[i] or 0) end
  end
  return false
end

local told -- the version the player was told about this session

local function Tell(version)
  if told == version then return end
  told = version
  KP:Print(("version %s is out (you have %s): update it in WowUp, or get it from %s"):format(version, KP.Version(), URL))
end

-- a version a guildmate's addon has: remembered and told when it's newer than ours
local function Seen(version)
  if not Update.Newer(version, KP.Version()) then return end
  if not KorkronPlannerDB.newestSeen or Update.Newer(version, KorkronPlannerDB.newestSeen) then
    KorkronPlannerDB.newestSeen = version
  end
  Tell(KorkronPlannerDB.newestSeen)
end

local heard = {} -- [version] = GetTime() a V with it last came in
local replying   -- an answer is waiting

Comm.On("V", function(msg)
  local version = msg:match("^V%^(%d+%.%d+[%d%.]*)$")
  if not version then return end
  local asked = GetTime()
  heard[version] = asked
  Seen(version)
  local mine = KP.Version()
  if replying or not Update.Newer(mine, version) then return end
  replying = true
  KP.After(math.random(2, 10), function()
    replying = false
    -- another addon already answered with ours or a newer one: nothing to add
    for v, at in pairs(heard) do
      if at > asked and not Update.Newer(mine, v) then return end
    end
    if not IsInInstance() then Comm.Send("V^" .. mine) end
  end)
end)

KP:On("PLAYER_LOGIN", function()
  KP.After(AFTER_LOGIN, function()
    local mine, newest = KP.Version(), KorkronPlannerDB.newestSeen
    if newest and Update.Newer(newest, mine) then
      Tell(newest)
    else
      KorkronPlannerDB.newestSeen = nil -- updated since
    end
    if not IsInInstance() then Comm.Send("V^" .. mine) end
  end)
end)
