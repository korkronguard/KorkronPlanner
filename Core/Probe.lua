-- Kor'kron Planner: /kp probe. Finds out which talent, stat and spell functions Forever's client gives addons,
-- tries them read-only, and saves the answers to KorkronPlannerDB.probe (written to disk on /reload or logout).
-- Nothing here changes the character.
local _, KP = ...

local FUNCTIONS = {
  -- classic talent functions
  "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "GetTalentPrereqs", "LearnTalent",
  "UnitCharacterPoints", "GetUnspentTalentPoints",
  -- stats
  "UnitStat", "UnitAttackPower", "UnitRangedAttackPower", "UnitAttackSpeed", "UnitDamage", "UnitArmor",
  "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetHitModifier", "GetSpellHitModifier",
  "GetSpellBonusDamage", "GetSpellBonusHealing", "GetCombatRating", "GetCombatRatingBonus", "GetDodgeChance",
  "GetParryChance", "GetBlockChance", "GetManaRegen", "UnitPowerMax", "UnitHealthMax",
  -- what a stat gives, as the game's own character sheet shows it (Core/Sheet.lua uses them when they're there)
  "GetCritChanceFromAgility", "GetSpellCritChanceFromIntellect", "GetDodgeChanceFromAgility", "GetAttackPowerForStat",
  -- other
  "GetSpellInfo", "IsSpellKnown", "GetShapeshiftFormID", "InCombatLockdown", "issecretvalue",
}
local NAMESPACES = { "C_Traits", "C_ClassTalents", "C_SpecializationInfo", "C_Spell", "C_SpellBook", "C_PaperDollInfo" }

-- a value that's safe to keep in the saved report: hidden ("secret") values become "<hidden>", functions and other
-- objects their type, and tables are copied the same way (a few levels deep)
local function Clean(v, depth)
  if not KP.Readable(v) then return "<hidden>" end
  local kind = type(v)
  if kind == "table" then
    depth = (depth or 0) + 1
    if depth > 3 then return "<table>" end
    local out = {}
    for k, x in pairs(v) do
      if KP.Readable(k) then out[k] = Clean(x, depth) end
    end
    return out
  elseif kind == "function" or kind == "userdata" or kind == "thread" then
    return "<" .. kind .. ">"
  end
  return v
end

local function pack(...) return { n = select("#", ...), ... } end

-- call fn read-only and keep every result: n = how many (some can be nil), hidden ones as "<hidden>"
local function try(fn, ...)
  local r = pack(pcall(fn, ...))
  if not r[1] then return { error = Clean(r[2]) } end
  local out = { n = r.n - 1 }
  for i = 2, r.n do out[i - 1] = Clean(r[i]) end
  return out
end

function KP:Probe()
  local p = { time = date("%Y-%m-%d %H:%M"), build = Clean({ GetBuildInfo() }) }
  p.player = { class = Clean((select(2, UnitClass("player")))), race = Clean((select(2, UnitRace("player")))),
    level = Clean(UnitLevel("player")) }

  p.functions = {}
  for _, name in ipairs(FUNCTIONS) do p.functions[name] = type(_G[name]) == "function" end
  p.namespaces = {}
  for _, ns in ipairs(NAMESPACES) do
    local t = _G[ns]
    if type(t) == "table" then
      local keys = {}
      for k, v in pairs(t) do if type(v) == "function" then table.insert(keys, k) end end
      table.sort(keys)
      p.namespaces[ns] = keys
    end
  end

  -- classic talents: tabs and the first few talents of each
  p.talents = {}
  if p.functions.GetNumTalentTabs then
    p.talents.tabs = try(GetNumTalentTabs)
    local tabs = (p.talents.tabs and tonumber(p.talents.tabs[1])) or 0
    for tab = 1, math.min(tabs, 3) do
      p.talents["tab" .. tab] = try(GetTalentTabInfo, tab)
      if p.functions.GetNumTalents then
        local n = try(GetNumTalents, tab)
        p.talents["tab" .. tab .. "count"] = n
        for i = 1, math.min(tonumber(n and n[1]) or 0, 3) do
          p.talents["tab" .. tab .. "_" .. i] = try(GetTalentInfo, tab, i)
        end
      end
    end
  end
  if p.functions.UnitCharacterPoints then p.talents.points = try(UnitCharacterPoints, "player") end

  -- trait talents: the active config and its tree
  p.traits = {}
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    p.traits.activeConfig = try(C_ClassTalents.GetActiveConfigID)
    local configID = p.traits.activeConfig[1]
    if type(configID) == "number" and C_Traits and C_Traits.GetConfigInfo then
      local info = try(C_Traits.GetConfigInfo, configID)
      local first = info[1] -- already cleaned by try
      p.traits.configInfo = type(first) == "table" and { type = first.type, name = first.name, treeIDs = first.treeIDs } or info
    end
  end

  -- stats (each stat: base, effective, bonus, penalty)
  p.stats = {}
  if p.functions.UnitStat then for i = 1, 5 do p.stats["stat" .. i] = try(UnitStat, "player", i) end end
  for _, name in ipairs({ "GetCritChance", "GetRangedCritChance", "GetHitModifier", "GetSpellHitModifier",
    "GetDodgeChance", "GetParryChance", "GetBlockChance", "GetManaRegen" }) do
    if p.functions[name] then p.stats[name] = try(_G[name]) end
  end
  for _, name in ipairs({ "GetCritChanceFromAgility", "GetSpellCritChanceFromIntellect", "GetDodgeChanceFromAgility" }) do
    if p.functions[name] then p.stats[name] = try(_G[name], "player") end
  end
  if p.functions.GetAttackPowerForStat and p.functions.UnitStat then
    local _, strength = UnitStat("player", 1)
    p.stats.GetAttackPowerForStat = try(_G.GetAttackPowerForStat, 1, strength)
  end
  if p.functions.GetSpellCritChance then p.stats.spellCrit = try(GetSpellCritChance, 2) end
  if p.functions.GetSpellBonusDamage then p.stats.spellDamage = try(GetSpellBonusDamage, 2) end
  if p.functions.GetSpellBonusHealing then p.stats.healing = try(GetSpellBonusHealing) end
  if p.functions.UnitAttackPower then p.stats.attackPower = try(UnitAttackPower, "player") end
  if p.functions.UnitRangedAttackPower then p.stats.rangedAttackPower = try(UnitRangedAttackPower, "player") end
  if p.functions.UnitAttackSpeed then p.stats.attackSpeed = try(UnitAttackSpeed, "player") end
  if p.functions.UnitDamage then p.stats.damage = try(UnitDamage, "player") end
  if p.functions.UnitArmor then p.stats.armor = try(UnitArmor, "player") end

  KorkronPlannerDB.probe = p

  -- summary in chat
  local talentKind = p.functions.GetTalentInfo and "classic talent functions" or
    (p.namespaces.C_Traits and "trait functions (C_Traits)" or "no talent functions found")
  self:Print(("probe done (%s, level %s %s): %s; LearnTalent %s; %d of the functions it looks for exist.")
    :format(tostring(p.build[1]) .. " " .. tostring(p.build[2]), tostring(p.player.level), tostring(p.player.class), talentKind,
      p.functions.LearnTalent and "exists" or "missing",
      (function() local n = 0 for _, ok in pairs(p.functions) do if ok then n = n + 1 end end return n end)()))
  self:Print("type /reload so the game saves the full report (SavedVariables\\KorkronPlanner.lua).")
end
