-- Kor'kron Planner: what the rotation helper says to press. Your build's Priority list at your level
-- (Data/Priority.lua) carries a rule per line for the builds the helper is on for (Warriors, Retribution): its kind, the
-- spell ID of each rank, cooldown, global cooldown, aura... In a fight Forever lets an addon read whether a spell is
-- usable (rage, stance, a lit Overpower or Execute) and whether its cooldown runs, but not for how long, nor your
-- rage, your auras or the target's health (/kp probe combat, 2026-11-05). So the addon keeps its own book: your
-- casts (time, target) and your buffs as the game shows them out of combat, with the website's durations.
local _, KP = ...

local Rotation = {}
KP.Rotation = Rotation

local REFRESH = 3 -- seconds left on a buff or debuff when renewing it is due
local PICKS = 3   -- the press now and the two after it
local ELITE = { elite = true, rareelite = true, worldboss = true } -- big cooldowns are for these

local casts = {}   -- [line name] = when you last cast it
local buffs = {}   -- [line name] = when your buff runs out (0 = not up)
local debuffs = {} -- [target GUID] = { [line name] = when it runs out on that target }

local cache = {}   -- the rules for one build and level: { key, level, phases }

-- Your build's rules at your level, by phase: { start = { lines }, main = ..., execute = ..., cooldowns = ... }, or
-- nil (no suggested build chosen, or none of its lines have rules). Rage dumps are left out: the game hides your rage.
function Rotation.Rules()
  local build = KP.Build.Current()
  local key, level = build and build.key, UnitLevel("player")
  if not key then return nil end
  if cache.key == key and cache.level == level then return cache.phases end
  local list, phases = KP.Build.ForLevel(KP.Priority, key, level), nil
  for _, section in ipairs(list and list.sections or {}) do
    for _, item in ipairs(section.phase and section.items or {}) do
      if item.rule and item.rule.kind ~= "dump" then
        phases = phases or {}
        phases[section.phase] = phases[section.phase] or {}
        table.insert(phases[section.phase], item)
      end
    end
  end
  cache = { key = key, level = level, phases = phases }
  return phases
end

-- Whether your class has helper rules at all (for the switch in /kp and the one-time notice)
function Rotation.ForClass()
  local _, class = UnitClass("player")
  for _, lists in pairs(KP.Priority[KP.Text(class)] or {}) do
    for _, section in ipairs(lists[1].sections) do
      if section.phase then return true end
    end
  end
  return false
end

-- the rank of a line's spell you know (the highest), or nil
local function Known(rule)
  for i = #rule.ids, 1, -1 do
    if IsSpellKnown(rule.ids[i]) then return rule.ids[i] end
  end
end

-- What the game says about a spell now: { usable (rage, stance, lit), cooling (its cooldown runs; the global
-- cooldown doesn't count) }, or nil when it hides either
local function State(id)
  local usable, cd = C_Spell.IsSpellUsable(id), C_Spell.GetSpellCooldown(id)
  if not (KP.Readable(usable) and KP.Readable(cd)) then return nil end
  local active, onGCD = cd and cd.isActive, cd and cd.isOnGCD
  if not (KP.Readable(active) and KP.Readable(onGCD)) then return nil end
  return { usable = usable == true, cooling = active == true and onGCD ~= true }
end

-- whether a line's spell works on your target: Exorcism only on Undead and Demons (the spell's own list, rule.creatures:
-- bit n-1 = the game's creature type n, UnitCreatureType's second answer); a type the game hides counts as no
local function ForTarget(rule)
  if not rule.creatures then return true end
  local _, typeID = UnitCreatureType("target")
  return KP.Readable(typeID) and typeID ~= nil and math.floor(rule.creatures / 2 ^ (typeID - 1)) % 2 == 1
end

local function Has(list, value)
  for _, v in ipairs(list) do
    if v == value then return true end
  end
end

-- your cast of a line's spell: when (its cooldown), and its aura on you or on the target
local function OnCast(unit, _, spellID)
  if not (KP.Readable(unit) and unit == "player" and KP.Readable(spellID)) then return end
  local now, guid = GetTime(), KP.Text(UnitGUID("target"))
  for _, items in pairs(Rotation.Rules() or {}) do
    for _, item in ipairs(items) do
      local rule = item.rule
      if Has(rule.ids, spellID) then
        casts[item.name] = now
        local ends = now + (rule.dur or 0) / 1000
        if rule.dur and rule.aura == "you" then
          buffs[item.name] = ends
        elseif rule.dur and rule.aura == "target" and guid then
          debuffs[guid] = debuffs[guid] or {}
          debuffs[guid][item.name] = ends
        end
      end
    end
  end
end

-- Out of combat the game shows your buffs (in a fight it refuses): note when each line's buff runs out
local function ReadBuffs(phases)
  local up = {} -- [spell ID] = when it runs out (math.huge: no end)
  for i = 1, 40 do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not (a and KP.Readable(a)) then break end
    local id, ends = a.spellId, a.expirationTime
    if KP.Readable(id) and KP.Readable(ends) and type(ends) == "number" then up[id] = ends == 0 and math.huge or ends end
  end
  for _, items in pairs(phases) do
    for _, item in ipairs(items) do
      if item.rule.aura == "you" then
        buffs[item.name] = 0
        for _, id in ipairs(item.rule.ids) do buffs[item.name] = math.max(buffs[item.name], up[id] or 0) end
      end
    end
  end
end

-- when a line's aura runs out (sim: what the presses worked out ahead put up)
local function AuraEnds(item, guid, sim)
  if sim[item.name] then return sim[item.name] end
  if item.rule.aura == "target" then return guid and debuffs[guid] and debuffs[guid][item.name] or 0 end
  return buffs[item.name] or 0
end

-- whether a line wants pressing at time t, apart from being ready
local function Wanted(item, guid, t, sim)
  local kind = item.rule.kind
  if kind == "keepSolo" and IsInGroup() then return false end
  if kind == "keep" or kind == "keepSolo" then return AuraEnds(item, guid, sim) - t < REFRESH end
  if kind == "missing" then return AuraEnds(item, guid, sim) <= t end
  return true -- opener, pull, ready, stack (a filler once stacked)
end

-- The Execute phase: while the game lets you use Execute (the target is under 20%), which it shows even when it hides
-- the target's health
local function ExecutePhase(phases)
  for _, item in ipairs(phases.execute or {}) do
    if item.name == "Execute" then
      local id = Known(item.rule)
      local s = id and State(id)
      return s and s.usable
    end
  end
end

-- The lines that apply now, in order: before the fight the start (Charge...), against an elite or boss the big
-- cooldowns, then the Execute phase's lines or the main ones
local function Order(phases)
  local order = {}
  local function add(items)
    for _, item in ipairs(items or {}) do table.insert(order, item) end
  end
  if not InCombatLockdown() then add(phases.start) end
  if ELITE[KP.Text(UnitClassification("target")) or ""] then add(phases.cooldowns) end
  add(ExecutePhase(phases) and phases.execute or phases.main)
  return order
end

-- Up to three presses, { { item, id }, ... }: now and the two after. Each line you can press (usable now, or usable
-- but cooling down from a cast the addon saw) gets the time it's free; then, played forward, the first line that's
-- wanted and free goes next (its cooldown starts, its aura goes up, its global cooldown passes). Rage can't be seen,
-- so this assumes you have it. Returns nil and "hidden" when the game hides what this needs.
function Rotation.Picks()
  local phases = Rotation.Rules()
  if not phases then return nil, "no rules" end
  local now, guid = GetTime(), KP.Text(UnitGUID("target"))
  if not InCombatLockdown() then ReadBuffs(phases) end
  local free = {}
  for _, item in ipairs(Order(phases)) do
    local id = ForTarget(item.rule) and Known(item.rule)
    local s = id and State(id)
    if id and not s then return nil, "hidden" end
    local at = s and s.usable and (not s.cooling and now or casts[item.name] and casts[item.name] + item.rule.cd / 1000)
    if at then table.insert(free, { item = item, id = id, at = math.max(now, at) }) end
  end
  local picks, sim, t = {}, {}, now
  while #picks < PICKS do
    local pick
    for _, f in ipairs(free) do
      if f.at <= t and Wanted(f.item, guid, t, sim) then pick = f break end
    end
    if not pick then -- nothing free yet: the one free soonest
      for _, f in ipairs(free) do
        if Wanted(f.item, guid, f.at, sim) and (not pick or f.at < pick.at) then pick = f end
      end
      if not pick then break end
      t = pick.at
    end
    table.insert(picks, { item = pick.item, id = pick.id })
    local rule = pick.item.rule
    pick.at = t + rule.cd / 1000
    if rule.dur and rule.aura then sim[pick.item.name] = t + rule.dur / 1000 end
    t = t + rule.gcd / 1000
  end
  return picks
end

KP:On("UNIT_SPELLCAST_SUCCEEDED", OnCast)
KP:On("PLAYER_REGEN_ENABLED", function() wipe(debuffs) end) -- the fight is over: its targets' debuffs with it
