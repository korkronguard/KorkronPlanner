local _, KP = ...

local Check = {}
KP.Check = Check
local Comm = KP.Comm

local DELAY = 60
local sentAt = {}

function Check.Version()
  return ("%s/%s"):format(KP.Text((select(2, GetBuildInfo()))) or "?", KP.Version() or "?")
end

local function DB()
  local checks, version = KorkronPlannerDB.checks, Check.Version()
  if checks.version ~= version then
    checks.version, checks.talents, checks.spells = version, {}, {}
  end
  return checks
end

local function Clean(text)
  return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", ""):gsub("[\r\n~]", " "))
end

local function Numbers(text)
  local out = {}
  for n in text:gmatch("%d+%.?%d*") do out[#out + 1] = tonumber(n) end
  return out
end

local function SameNumbers(a, b)
  local x, y = Numbers(a), Numbers(b)
  if #x ~= #y then return false end
  for i = 1, #x do
    if math.abs(x[i] - y[i]) > 1e-6 then return false end
  end
  return true
end

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

function Check.Add(text)
  local key = ("%d%04d"):format(GetServerTime(), math.random(0, 9999))
  if KorkronPlannerDB.collector then
    KorkronPlannerDB.checksCollected[key] = { from = KP.Text(UnitName("player")) or "?", text = text }
  else
    KorkronPlannerDB.checks.outbox[key] = text
    if KP.Share.CollectorAround() then Check.SendUndelivered() end
  end
end

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
  if InCombatLockdown() or IsInInstance() then return Check.Schedule() end
  local _, class = UnitClass("player")
  local checks = DB()
  if not checks.talents[class] then
    local record = TalentRecord(class)
    if record then
      checks.talents[class] = true
      Check.Add(record)
    end
  end
  local spells = SpellRecord(class)
  if spells then Check.Add(spells) end
end

function Check.Schedule()
  if scheduled then return end
  scheduled = true
  KP.After(DELAY, Run)
end

Comm.OnLong("D", function(key, text, sender)
  if not KorkronPlannerDB.collector then return end
  KorkronPlannerDB.checksCollected[key] = { from = sender, text = text }
  Comm.Send("E^" .. key)
end)

Comm.On("E", function(msg)
  local key = msg:match("^E%^(%d+)$")
  if key then KorkronPlannerDB.checks.outbox[key] = nil end
end)

KP:On("PLAYER_LOGIN", Check.Schedule)
KP:On("SPELLS_CHANGED", Check.Schedule)
