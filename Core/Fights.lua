local _, KP = ...

local Fights = {}
KP.Fights = Fights

local CLOSE_AFTER = 2
local RULE = 2

local fight
local started = 0

local function Add(map, key, n) map[key] = (map[key] or 0) + n end

local function Number(v)
  if KP.Readable(v) and type(v) == "number" then return v end
end
local function Table(v)
  if KP.Readable(v) and type(v) == "table" then return v end
end

local function Bucket(level, key)
  local levels = KorkronPlannerCharDB.fights
  levels[level] = levels[level] or {}
  levels[level][key] = levels[level][key] or { fights = 0, sec = 0, metered = 0, msec = 0, mdur = 0, dealt = 0,
    taken = 0, enemy = 0, spells = {}, casts = {}, out = {}, inn = {} }
  return levels[level][key]
end

local function TargetKey()
  local guid = KP.Text(UnitGUID("target"))
  if not guid then return nil end
  local key = fight.keys[guid]
  if key == nil then
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then
      key = ("%d:%d:%d:%s:%d:%s"):format(Number(GetShapeshiftFormID()) or 0, Number(GetInventoryItemID("player", 16)) or 0,
        Number(GetInventoryItemID("player", 17)) or 0, id, Number(UnitLevel("target")) or 0,
        ((KP.Text(UnitClassification("target")) or ""):gsub("%W", "")))
      fight.enemies, fight.only, fight.creature = fight.enemies + 1, key, tonumber(id)
    else
      key = false
      if guid ~= KP.Text(UnitGUID("player")) then fight.mixed = true end
    end
    fight.keys[guid] = key
  end
  return key or nil
end

KP:On("PLAYER_REGEN_DISABLED", function()
  started = started + 1
  fight = nil
  local level = Number(UnitLevel("player"))
  if not level or not KorkronPlannerDB.share or IsInGroup() or IsInInstance() then return end
  fight = { id = started, start = GetTime(), level = level, keys = {}, enemies = 0, casts = {}, inn = {} }
end)

KP:On("UNIT_COMBAT", function(unit, kind, mark)
  if not fight or not KP.Readable(unit) or (unit ~= "target" and unit ~= "player") then return end
  kind, mark = KP.Text(kind), KP.Text(mark) or ""
  if not kind then return end
  local outcome = kind:gsub("[^%w_]", "")
  if mark ~= "" then outcome = outcome .. "." .. mark:gsub("[^%w_]", "") end
  if unit == "player" then
    Add(fight.inn, outcome, 1)
  else
    local key = TargetKey()
    if key then Add(Bucket(fight.level, key).out, outcome, 1) end
  end
end)

KP:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if not fight or not KP.Readable(unit) or unit ~= "player" then return end
  spellID = Number(spellID)
  if spellID then Add(fight.casts, spellID, 1) end
end)

local function Metered(done)
  local kinds, current, me = Enum.DamageMeterType, Enum.DamageMeterSessionType.Current, UnitGUID("player")
  local mine = Table(C_DamageMeter.GetCombatSessionSourceFromType(current, kinds.DamageDone, me))
  local dealt = mine and Number(mine.totalAmount)
  if not dealt then return nil end
  local seconds = Number(C_DamageMeter.GetSessionDurationSeconds(current))
  if not seconds or seconds < done.sec - 1 or seconds > done.sec + 4 then return nil end
  local session = Table(C_DamageMeter.GetCombatSessionFromType(current, kinds.EnemyDamageTaken))
  local enemies = session and Table(session.combatSources)
  local enemy = enemies and #enemies == 1 and Table(enemies[1])
  if not enemy or Number(enemy.sourceCreatureID) ~= done.creature then return nil end
  local spells = {}
  for _, spell in ipairs(Table(mine.combatSpells) or {}) do
    local id, amount = Table(spell) and Number(spell.spellID), Table(spell) and Number(spell.totalAmount)
    if id and amount then Add(spells, id, amount) end
  end
  local got = Table(C_DamageMeter.GetCombatSessionSourceFromType(current, kinds.DamageTaken, me))
  return { dealt = dealt, spells = spells, taken = got and Number(got.totalAmount) or 0,
    enemy = Number(enemy.totalAmount) or 0, seconds = seconds }
end

local function Won(done)
  local dead, guid = UnitIsDeadOrGhost("player"), KP.Text(UnitGUID("target"))
  if not KP.Readable(dead) or dead or not done.keys[guid] then return false end
  local killed = UnitIsDead("target")
  return KP.Readable(killed) and killed
end

local function Close(done)
  if done.enemies ~= 1 or done.mixed or not (done.won or Won(done)) then return end
  local b = Bucket(done.level, done.only)
  b.fights, b.sec = b.fights + 1, b.sec + done.sec
  for id, n in pairs(done.casts) do Add(b.casts, id, n) end
  for outcome, n in pairs(done.inn) do Add(b.inn, outcome, n) end
  if started ~= done.id or InCombatLockdown() then return end
  local meter = Metered(done)
  if not meter then return end
  b.metered, b.msec, b.mdur = b.metered + 1, b.msec + done.sec, b.mdur + meter.seconds
  b.dealt, b.taken, b.enemy = b.dealt + meter.dealt, b.taken + meter.taken, b.enemy + meter.enemy
  for id, amount in pairs(meter.spells) do Add(b.spells, id, amount) end
end

KP:On("PLAYER_REGEN_ENABLED", function()
  local done = fight
  fight = nil
  if not done then return end
  done.sec = GetTime() - done.start
  done.won = Won(done)
  KP.After(CLOSE_AFTER, function() Close(done) end)
end)

local function Sorted(map)
  local keys = {}
  for key in pairs(map) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  return keys
end

local function Map(map)
  local parts = {}
  for i, key in ipairs(Sorted(map)) do parts[i] = ("%s:%d"):format(key, math.floor(map[key] + 0.5)) end
  return table.concat(parts, ",")
end

function Fights.Flush(upTo)
  local _, class = UnitClass("player")
  local build = KorkronPlannerCharDB.build
  for _, level in ipairs(Sorted(KorkronPlannerCharDB.fights)) do
    if level <= upTo then
      local buckets = KorkronPlannerCharDB.fights[level]
      local fields = { "F" .. RULE, KP.Check.Version(), class, level, KP.Text(UnitGUID("player")) or "", build and build.key or "" }
      for _, key in ipairs(Sorted(buckets)) do
        local b = buckets[key]
        fields[#fields + 1] = table.concat({ key, b.fights, ("%.1f"):format(b.sec), b.metered, ("%.1f"):format(b.msec),
          ("%.1f"):format(b.mdur), math.floor(b.dealt + 0.5), math.floor(b.taken + 0.5), Map(b.spells), Map(b.casts),
          Map(b.out), Map(b.inn), math.floor(b.enemy + 0.5) }, "|")
      end
      KorkronPlannerCharDB.fights[level] = nil
      KP.Check.Add(table.concat(fields, "~"))
    end
  end
end

KP:On("PLAYER_LOGIN", function()
  if KorkronPlannerCharDB.fightsRule ~= RULE then
    KorkronPlannerCharDB.fights, KorkronPlannerCharDB.fightsRule = {}, RULE
  end
  Fights.Flush(math.huge)
end)
KP:On("PLAYER_LEVEL_UP", function(level)
  level = Number(level)
  if level then Fights.Flush(level - 1) end
end)
