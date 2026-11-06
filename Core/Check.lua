-- Kor'kron Planner: the guild's automatic check of the planner's talent and spell numbers against the game, so nobody
-- has to type /kp datamine. With sharing on (/kp share), out of combat and outside instances, a minute after login:
--   talents: your class's talent tooltips at every rank, compared here with the planner's (Data/Talents.lua). Only the
--            ranks whose numbers differ are kept, with a count of those checked. Once per class for each game build and
--            addon version (KorkronPlannerDB.checks.version), at any level.
--   spells:  the descriptions of the spells you know that no character on this account has recorded for this version
--            (again after you learn new ones). The addon doesn't carry spell texts, so these go to the collector whole
--            and the website's tools/datamine.py compares them.
-- Records wait in KorkronPlannerDB.checks.outbox until the guild's collector acknowledges them. Messages (Comm.lua):
--   D^key^i^n^part   player: a record in parts, when the collector asks (Share.lua) or right away while it's around
--   E^key            collector: stored it; the player drops it
-- The collector keeps KorkronPlannerDB.checksCollected[key] = { from = sender, text }; its own records go straight in.
-- Record text, fields split by "~" (taken out of the game's text):
--   T~version~class~level~ranks checked~node ID,rank,game text~...   (only the talent ranks whose numbers differ)
--   P~version~class~level~spell ID~text~spell ID~text~...
local _, KP = ...

local Check = {}
KP.Check = Check
local Comm = KP.Comm

local DELAY = 60  -- seconds after login (or a spellbook change) before checking: things settle first
local sentAt = {} -- [key] = GetTime() a record was last sent

-- the game build and this addon's version: a new one of either checks again
local function Version()
  return ("%s/%s"):format(KP.Text((select(2, GetBuildInfo()))) or "?", KP.Version() or "?")
end

-- this version's checks, started over when the version changes (records not yet delivered stay in the outbox)
local function DB()
  local checks, version = KorkronPlannerDB.checks, Version()
  if checks.version ~= version then
    checks.version, checks.talents, checks.spells = version, {}, {}
  end
  return checks
end

-- the game's text made safe for a record: no "~" (the separator), color codes or line breaks
local function Clean(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", ""):gsub("[\r\n~]", " "))
end

local function Numbers(text)
  local out = {}
  for n in text:gmatch("%d+%.?%d*") do out[#out + 1] = tonumber(n) end
  return out
end

-- the same numbers in the same order ("5.0 sec" and "5 sec" agree; the wording may differ)
local function SameNumbers(a, b)
  local x, y = Numbers(a), Numbers(b)
  if #x ~= #y then return false end
  for i = 1, #x do
    if math.abs(x[i] - y[i]) > 1e-6 then return false end
  end
  return true
end

-- your class's talent tooltips against the planner's: the record, or nil when the game gave none (it'll try again)
local function TalentRecord(class)
  local game = KP.Datamine.TalentTexts(class)
  local fields, checked = { "T", DB().version, class, UnitLevel("player"), 0 }, 0
  for _, t in ipairs(KP.Talents[class] or {}) do
    for rank = 1, t.ranks do
      local text = game[t.id] and game[t.id].ranks[rank]
      if text then
        checked = checked + 1
        if not SameNumbers(text, t.desc[rank] or "") then
          fields[#fields + 1] = ("%d,%d,%s"):format(t.id, rank, Clean(text))
        end
      end
    end
  end
  fields[5] = checked
  return checked > 0 and table.concat(fields, "~") or nil
end

-- the spells you know that this account hasn't recorded yet: the record, or nil when there are none
local function SpellRecord(class)
  local recorded, fields = DB().spells, { "P", DB().version, class, UnitLevel("player") }
  for id, text in pairs(KP.Datamine.SpellTexts()) do
    if not recorded[id] then
      recorded[id] = true
      fields[#fields + 1] = id
      fields[#fields + 1] = Clean(text)
    end
  end
  return #fields > 4 and table.concat(fields, "~") or nil
end

local function Add(text)
  local key = ("%d%04d"):format(GetServerTime(), math.random(0, 9999))
  if KorkronPlannerDB.collector then
    KorkronPlannerDB.checksCollected[key] = { from = KP.Text(UnitName("player")) or "?", text = text }
  else
    KorkronPlannerDB.checks.outbox[key] = text
    if KP.Share.CollectorAround() then Check.SendUndelivered() end
  end
end

-- Share.lua calls this when the collector asks
function Check.SendUndelivered()
  if not KorkronPlannerDB.share or IsInInstance() then return end
  local now = GetTime()
  for key, text in pairs(KorkronPlannerDB.checks.outbox) do
    if not sentAt[key] or now - sentAt[key] >= KP.Share.RESEND_AFTER then
      sentAt[key] = now
      Comm.SendLong("D", key, text)
    end
  end
end

local scheduled

local function Run()
  scheduled = nil
  if not KorkronPlannerDB.share then return end
  if InCombatLockdown() or IsInInstance() then return Check.Schedule() end -- the game can hide values there
  local _, class = UnitClass("player")
  local checks = DB()
  if not checks.talents[class] then
    local record = TalentRecord(class)
    if record then
      checks.talents[class] = true
      Add(record)
    end
  end
  local spells = SpellRecord(class)
  if spells then Add(spells) end
end

function Check.Schedule()
  if scheduled then return end
  scheduled = true
  KP.After(DELAY, Run)
end

Comm.OnLong("D", function(key, text, sender)
  if not KorkronPlannerDB.collector then return end
  KorkronPlannerDB.checksCollected[key] = { from = sender, text = text }
  Comm.Send("E^" .. key) -- even when it was already here, so the player stops sending it
end)

Comm.On("E", function(msg)
  local key = msg:match("^E%^(%d+)$")
  if key then KorkronPlannerDB.checks.outbox[key] = nil end
end)

KP:On("PLAYER_LOGIN", Check.Schedule)
KP:On("SPELLS_CHANGED", Check.Schedule) -- a new spell's text goes out too
