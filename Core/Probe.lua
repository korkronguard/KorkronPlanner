local _, KP = ...

local FUNCTIONS = {
  "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "GetTalentPrereqs", "LearnTalent",
  "UnitCharacterPoints", "GetUnspentTalentPoints",
  "UnitStat", "UnitAttackPower", "UnitRangedAttackPower", "UnitAttackSpeed", "UnitDamage", "UnitArmor",
  "GetCritChance", "GetRangedCritChance", "GetSpellCritChance", "GetHitModifier", "GetSpellHitModifier",
  "GetSpellBonusDamage", "GetSpellBonusHealing", "GetCombatRating", "GetCombatRatingBonus", "GetDodgeChance",
  "GetParryChance", "GetBlockChance", "GetShieldBlock", "GetManaRegen", "UnitPowerMax", "UnitHealthMax",
  "GetCritChanceFromAgility", "GetSpellCritChanceFromIntellect", "GetDodgeChanceFromAgility", "GetAttackPowerForStat",
  "GetSpellInfo", "IsSpellKnown", "GetShapeshiftFormID", "InCombatLockdown", "issecretvalue",
}
local NAMESPACES = { "C_Traits", "C_ClassTalents", "C_SpecializationInfo", "C_Spell", "C_SpellBook", "C_PaperDollInfo" }

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

local function try(fn, ...)
  local r = pack(pcall(fn, ...))
  if not r[1] then return { error = Clean(r[2]) } end
  local out = { n = r.n - 1 }
  for i = 2, r.n do out[i - 1] = Clean(r[i]) end
  return out
end

local function Functions(names)
  local out = {}
  for _, name in ipairs(names) do out[name] = type(_G[name]) == "function" end
  return out
end

local function Namespaces(names)
  local out = {}
  for _, ns in ipairs(names) do
    local t = _G[ns]
    if type(t) == "table" then
      local keys = {}
      for k, v in pairs(t) do if type(v) == "function" then table.insert(keys, k) end end
      table.sort(keys)
      out[ns] = keys
    end
  end
  return out
end

function KP:Probe()
  local p = { time = date("%Y-%m-%d %H:%M"), build = Clean({ GetBuildInfo() }) }
  p.player = { class = Clean((select(2, UnitClass("player")))), race = Clean((select(2, UnitRace("player")))),
    level = Clean(UnitLevel("player")) }

  p.functions = Functions(FUNCTIONS)
  p.namespaces = Namespaces(NAMESPACES)

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

  p.traits = {}
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    p.traits.activeConfig = try(C_ClassTalents.GetActiveConfigID)
    local configID = p.traits.activeConfig[1]
    if type(configID) == "number" and C_Traits and C_Traits.GetConfigInfo then
      local info = try(C_Traits.GetConfigInfo, configID)
      local first = info[1]
      p.traits.configInfo = type(first) == "table" and { type = first.type, name = first.name, treeIDs = first.treeIDs } or info
    end
  end

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

  local talentKind = p.functions.GetTalentInfo and "classic talent functions" or
    (p.namespaces.C_Traits and "trait functions (C_Traits)" or "no talent functions found")
  self:Print(("probe done (%s, level %s %s): %s; LearnTalent %s; %d of the functions it looks for exist.")
    :format(tostring(p.build[1]) .. " " .. tostring(p.build[2]), tostring(p.player.level), tostring(p.player.class), talentKind,
      p.functions.LearnTalent and "exists" or "missing",
      (function() local n = 0 for _, ok in pairs(p.functions) do if ok then n = n + 1 end end return n end)()))
  self:Print("type /reload so the game saves the full report (SavedVariables\\KorkronPlanner.lua).")
end

local METER_TYPES = { "DamageDone", "DamageTaken", "EnemyDamageTaken", "HealingDone" }
local COUNTED = { player = true, target = true, pet = true }

local function MeterType(kind)
  local current = Enum.DamageMeterSessionType.Current
  local you = C_DamageMeter.GetCombatSessionSourceFromType(current, kind, UnitGUID("player"))
  local out = { session = Clean(C_DamageMeter.GetCombatSessionFromType(current, kind)), you = Clean(you) }
  if type(out.you) == "table" and type(out.you.combatSpells) == "table" then
    for i, spell in ipairs(you.combatSpells) do out.you.combatSpells[i] = Clean(spell) end
  end
  return out
end

local function Meter()
  if type(C_DamageMeter) ~= "table" then return { missing = true } end
  local out = { available = try(C_DamageMeter.IsDamageMeterAvailable), enabled = try(GetCVar, "damageMeterEnabled"),
    sessions = try(C_DamageMeter.GetAvailableCombatSessions),
    seconds = try(C_DamageMeter.GetSessionDurationSeconds, Enum.DamageMeterSessionType.Current), types = {} }
  for _, name in ipairs(METER_TYPES) do
    local ok, result = pcall(MeterType, Enum.DamageMeterType[name])
    out.types[name] = ok and result or { error = Clean(result) }
  end
  return out
end

local function Target()
  return { level = try(UnitLevel, "target"), classification = try(UnitClassification, "target"),
    health = try(UnitHealth, "target"), healthMax = try(UnitHealthMax, "target") }
end

local watch
local watcher = CreateFrame("Frame")

local function MeterLine(meter)
  if meter.missing then return "this client has no damage meter" end
  local you = meter.types.DamageDone.you
  if type(you) ~= "table" or type(you.totalAmount) ~= "number" then return "the game's damage meter couldn't be read" end
  return ("the game's damage meter says you did %s damage with %d abilities"):format(KP.Num(you.totalAmount, 0), #you.combatSpells)
end

local function FightOver()
  if not watch or not watch.start or InCombatLockdown() then return end
  watcher:UnregisterAllEvents()
  local fight = watch
  watch = nil
  fight.start = nil
  fight.meter = Meter()
  KorkronPlannerDB.fightProbe.fight = fight
  local numbers, hidden = 0, 0
  for _, kind in pairs(fight.combat.target or {}) do
    numbers, hidden = numbers + kind.count, hidden + kind.hiddenAmounts
  end
  KP:Print(("fight check done (%s sec): %s; %d combat numbers on your target, %d with a hidden amount. Type /reload so the game saves it.")
    :format(KP.Num(fight.seconds, 0), MeterLine(fight.meter), numbers, hidden))
end

local WATCHED = {}
function WATCHED.PLAYER_REGEN_DISABLED()
  watch.fights = watch.fights + 1
  watch.start = GetTime()
end
function WATCHED.PLAYER_REGEN_ENABLED()
  watch.seconds = watch.seconds + GetTime() - watch.start
  KP.After(2, FightOver)
end
function WATCHED.UNIT_COMBAT(unit, kind, mark, amount)
  if not KP.Readable(unit) or not COUNTED[unit] then return end
  if unit == "target" and not watch.target then watch.target = Target() end
  local units = watch.combat
  units[unit] = units[unit] or {}
  local key = KP.Text(kind) or "<hidden>"
  local seen = units[unit][key] or { count = 0, amounts = 0, hiddenAmounts = 0, marks = {} }
  units[unit][key] = seen
  seen.count = seen.count + 1
  local readable = KP.Readable(amount) and "amounts" or "hiddenAmounts"
  seen[readable] = seen[readable] + 1
  mark = KP.Text(mark) or "<hidden>"
  seen.marks[mark] = (seen.marks[mark] or 0) + 1
end
watcher:SetScript("OnEvent", function(_, event, ...) KP.Safe(WATCHED[event], ...) end)

function KP:ProbeFight()
  if InCombatLockdown() then return self:Print("type /kp probe fight outside a fight.") end
  KorkronPlannerDB.fightProbe = { time = date("%Y-%m-%d %H:%M"), build = Clean({ GetBuildInfo() }),
    calm = { meter = Meter(), target = Target() } }
  watch = { fights = 0, seconds = 0, combat = {} }
  for event in pairs(WATCHED) do watcher:RegisterEvent(event) end
  self:Print("fight check armed: fight one enemy on your own. Two seconds after it dies the addon reads what the game's "
    .. "damage meter and combat numbers showed, and says so here.")
end
