-- Kor'kron Planner: the fights you fight alone, in totals, for the guild's planner, so nobody has to send combat logs.
-- Addons can't read the combat log on Forever. What they can read (the client's own notes on its functions, and
-- /kp probe fight in Core/Probe.lua, run in game 2026-11-11):
--   * the game's combat numbers (UNIT_COMBAT): who was hit, the kind (WOUND, MISS, DODGE, PARRY, BLOCK, RESIST...) and
--     the mark (CRITICAL, GLANCING, CRUSHING, BLOCK_REDUCED...). The amount is hidden, and so is who hit or with what.
--   * the game's built-in damage meter (C_DamageMeter), hidden during a fight and readable after it: what you dealt,
--     ability by ability, what you took, and what each kind of enemy took. It keeps a count of its own per fight,
--     which ends a second or two after combat does.
--   * your own casts (UNIT_SPELLCAST_SUCCEEDED).
-- With sharing on, alone (no group) and outdoors, they're added up in KorkronPlannerCharDB.fights[your level][key],
-- key = "form:main hand:off hand:creature ID:enemy level:classification" (the stance or form's ID and the weapons'
-- item IDs when the enemy was first hit; 0 = none or hidden):
--   out      combat numbers on that enemy while you had it targeted, by "KIND" or "KIND.MARK" (yours, your pet's and a
--            passer-by's alike: the game doesn't say whose)
--   fights, sec, casts, inn   for fights against that enemy alone that you won (combat ended with you alive and the
--            enemy, still your target, dead: one you ran from, or that only chased you as you rode past, isn't one):
--            how many, their seconds, your casts by spell ID (one that starts the fight is missed), the combat
--            numbers on you
--   metered, msec, mdur, dealt, taken, spells, enemy   for those of them the damage meter still showed two seconds
--            later, as a fight of about that length against that creature alone: how many, their seconds, the meter's
--            own seconds, your damage, the damage you took, your damage by spell ID, and the damage the enemy took
--            from everyone (its health, when it died from full; more than `dealt` when someone helped)
-- At login and at each level-up the totals become records for the collector, carried by Check.lua's outbox:
--   F2~version~class~level~GUID~build key~key|fights|sec|metered|msec|mdur|dealt|taken|spells|casts|out|inn|enemy~...
-- (a map is "name:count,name:count"). The 2 is the rule the fights were counted by (RULE below): records starting "F~"
-- are the owner's first test runs, when a fight counted whether or not the enemy died; nothing reads them.
-- No names: enemies are creature IDs, and a fight with a player in it isn't kept.
local _, KP = ...

local Fights = {}
KP.Fights = Fights

local CLOSE_AFTER = 2 -- seconds after a fight before the damage meter is read: it closes its count a moment late
-- how a fight is counted (2: only when it's won). It's in a record's tag, and totals a character saved under another
-- rule (KorkronPlannerCharDB.fightsRule) are dropped at login, not sent as this one's
local RULE = 2

local fight       -- the fight in progress, when it counts: sharing on, alone, outdoors
local started = 0 -- fights begun this session: a newer one means the meter no longer holds an older one's numbers

local function Add(map, key, n) map[key] = (map[key] or 0) + n end

-- a game value when it can be read and is a number (or a table), else nil
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

-- the key of the enemy you have targeted, worked out once per enemy and fight. Anything that isn't a creature gives
-- nil, and makes the fight a mixed one unless it's you (a heal on yourself)
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

-- what the game's damage meter holds for this fight: your damage, by spell ID too, the damage you took, what the enemy
-- took from everyone, and the meter's own seconds. nil when it's hidden, or its count isn't this fight's (a meter
-- that's switched off counts none): it has to be about as long (seen in game: 1.2 to 1.8 sec longer, in whole seconds)
-- and against this one creature kind
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

-- did the fight end with you alive and its enemy dead? The enemy you kill stays your target, so that's where to look
-- (no target, or one that wasn't in the fight, has no key)
local function Won(done)
  local dead, guid = UnitIsDeadOrGhost("player"), KP.Text(UnitGUID("target"))
  if not KP.Readable(dead) or dead or not done.keys[guid] then return false end
  local killed = UnitIsDead("target")
  return KP.Readable(killed) and killed
end

-- a fight you won against one enemy goes into that enemy's totals (asked again here: the enemy's death may not show
-- until a moment after combat ends); the damage meter's numbers too, while it still holds this fight (no newer one
-- has begun) and shows it
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

-- a map as "name:count,name:count", in the names' order (the same totals always give the same text)
local function Map(map)
  local parts = {}
  for i, key in ipairs(Sorted(map)) do parts[i] = ("%s:%d"):format(key, math.floor(map[key] + 0.5)) end
  return table.concat(parts, ",")
end

-- your totals for the levels up to this one become records for the collector, and start over
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
