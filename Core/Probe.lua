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

-- which of these global functions exist
local function Functions(names)
  local out = {}
  for _, name in ipairs(names) do out[name] = type(_G[name]) == "function" end
  return out
end

-- every function in these C_ tables (the ones the game has)
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

-- /kp probe combat: what the game lets an addon see during a fight (for a rotation helper). Once armed, the next fight
-- outdoors and the next one in a dungeon or raid are each checked a few seconds in, while still in combat, and saved to
-- KorkronPlannerDB.combatProbe.world / .instance; a chat line says what was readable and what was hidden.
local CHECK_AFTER = 4 -- seconds into the fight: the opening abilities are on cooldown and their debuffs up
local GLOBAL_COOLDOWN = 61304 -- the game's spell for the global cooldown
local COMBO_POINTS = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local MAX_SPELLS = 16
local COMBAT_FUNCTIONS = { "UnitAura", "UnitBuff", "UnitDebuff", "GetSpellCooldown", "IsUsableSpell", "IsSpellInRange",
  "GetComboPoints", "UnitPower", "UnitPowerType", "UnitHealth", "GetShapeshiftForm", "GetShapeshiftFormInfo",
  "UnitCastingInfo", "UnitChannelInfo", "UnitClassification", "UnitCreatureType", "UnitCanAttack", "GetActionInfo",
  "GetBindingKey" }
local COMBAT_NAMESPACES = { "C_UnitAuras", "C_AssistedCombat", "C_CooldownViewer", "C_ActionBar" }

-- a function in one of the game's C_ tables, or nil
local function Api(ns, name)
  local t = _G[ns]
  return type(t) == "table" and t[name] or nil
end

-- like try, but a function the game doesn't have gives "<missing>"
local function call(fn, ...)
  if type(fn) ~= "function" then return "<missing>" end
  return try(fn, ...)
end

-- the first few auras on a unit (filter "HELPFUL" or "HARMFUL"), as the game describes them
local function Auras(unit, filter)
  local list, read = {}, Api("C_UnitAuras", "GetAuraDataByIndex") or _G.UnitAura
  for i = 1, 8 do
    local r = call(read, unit, i, filter)
    list[i] = r
    if type(r) ~= "table" or r.error or r[1] == nil or r[1] == "<hidden>" then break end
  end
  return list
end

-- your spellbook's first active spells, the General tab left out
local function SpellsToTry()
  local ids = {}
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
  local lines = call(Api("C_SpellBook", "GetNumSpellBookSkillLines"))
  for line = 2, tonumber(type(lines) == "table" and lines[1]) or 0 do
    local info = call(Api("C_SpellBook", "GetSpellBookSkillLineInfo"), line)
    info = type(info) == "table" and type(info[1]) == "table" and info[1] or {}
    local first = tonumber(info.itemIndexOffset) or 0
    for slot = first + 1, first + (tonumber(info.numSpellBookItems) or 0) do
      local item = call(Api("C_SpellBook", "GetSpellBookItemInfo"), slot, bank)
      item = type(item) == "table" and item[1]
      if #ids < MAX_SPELLS and type(item) == "table" and type(item.spellID) == "number" and not item.isPassive
        and (not SPELL or item.itemType == SPELL) then
        table.insert(ids, item.spellID)
      end
    end
  end
  return ids
end

-- the other ways the game offers to ask about auras, each tried on your buffs and the target's debuffs
local function OtherAuras(spells)
  local function aura(name) return Api("C_UnitAuras", name) end
  local out = {
    slots = { call(aura("GetAuraSlots"), "player", "HELPFUL"), call(aura("GetAuraSlots"), "target", "HARMFUL") },
    unitAuras = { call(aura("GetUnitAuras"), "player", "HELPFUL"), call(aura("GetUnitAuras"), "target", "HARMFUL") },
    instanceIDs = { call(aura("GetUnitAuraInstanceIDs"), "player", "HELPFUL"),
      call(aura("GetUnitAuraInstanceIDs"), "target", "HARMFUL") },
    byIndex = { call(aura("GetBuffDataByIndex"), "player", 1), call(aura("GetDebuffDataByIndex"), "target", 1) },
    bySpellID = {}, byName = {},
  }
  for i, s in ipairs(spells) do
    out.bySpellID[i] = { call(aura("GetPlayerAuraBySpellID"), s.id), call(aura("GetUnitAuraBySpellID"), "target", s.id) }
    local name = type(s.name) == "table" and s.name[1]
    if type(name) == "string" and name ~= "<hidden>" then
      out.byName[i] = { call(aura("GetAuraDataBySpellName"), "player", name, "HELPFUL"),
        call(aura("GetAuraDataBySpellName"), "target", name, "HARMFUL") }
    end
  end
  return out
end

-- whether the game's cooldown swirl takes a cooldown the addon can't read (then a helper could still show the time
-- left), tried on the first spell that's on cooldown
local function SwirlTest(spells)
  local spellID = (spells[1] or {}).id
  for _, s in ipairs(spells) do
    if type(s.cooldown) == "table" and type(s.cooldown[1]) == "table" and s.cooldown[1].isActive == true then
      spellID = s.id
      break
    end
  end
  if not spellID then return {} end
  local swirl = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
  swirl:Hide()
  local getCooldown, getDuration = Api("C_Spell", "GetSpellCooldown"), Api("C_Spell", "GetSpellCooldownDuration")
  return {
    spellID = spellID,
    times = call(function()
      local cd = getCooldown(spellID)
      swirl:SetCooldown(cd.startTime, cd.duration)
      return true
    end),
    durationObject = (getDuration and swirl.SetCooldownFromDurationObject) and call(function()
      swirl:SetCooldownFromDurationObject(getDuration(spellID))
      return true
    end) or "<missing>",
  }
end

-- the spells you cast since the fight began, as the game reported them (UNIT_SPELLCAST_SUCCEEDED)
local casts = {}
local function RecordCast(unit, castGUID, spellID)
  local db = KorkronPlannerDB.combatProbe
  if db and db.armed and #casts < 8 then
    table.insert(casts, Clean({ unit = unit, castGUID = castGUID, spellID = spellID, inCombat = InCombatLockdown() }))
  end
end
local castWatch = CreateFrame("Frame")
castWatch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
castWatch:SetScript("OnEvent", function(_, _, ...) KP.Safe(RecordCast, ...) end)

-- everything a rotation helper would read, as the game answers it right now
local function CombatReport(instanceType)
  local r = { time = date("%Y-%m-%d %H:%M"), build = Clean({ GetBuildInfo() }), instanceType = Clean(instanceType),
    player = { class = Clean((select(2, UnitClass("player")))), level = Clean(UnitLevel("player")) },
    functions = Functions(COMBAT_FUNCTIONS), namespaces = Namespaces(COMBAT_NAMESPACES) }
  r.power = { current = call(_G.UnitPower, "player"), max = call(_G.UnitPowerMax, "player"),
    kind = call(_G.UnitPowerType, "player"), combo = call(_G.UnitPower, "player", COMBO_POINTS) }
  r.globalCooldown = call(Api("C_Spell", "GetSpellCooldown"), GLOBAL_COOLDOWN)
  r.spells = {}
  for i, id in ipairs(SpellsToTry()) do
    r.spells[i] = { id = id, name = call(Api("C_Spell", "GetSpellName"), id),
      cooldown = call(Api("C_Spell", "GetSpellCooldown"), id), usable = call(Api("C_Spell", "IsSpellUsable"), id),
      inRange = call(Api("C_Spell", "IsSpellInRange"), id, "target") }
  end
  r.buffs, r.debuffs = Auras("player", "HELPFUL"), Auras("target", "HARMFUL")
  r.otherAuras, r.swirl, r.casts = OtherAuras(r.spells), SwirlTest(r.spells), { unpack(casts) }
  r.target = { health = call(_G.UnitHealth, "target"), healthMax = call(_G.UnitHealthMax, "target"),
    classification = call(_G.UnitClassification, "target"), creatureType = call(_G.UnitCreatureType, "target"),
    canAttack = call(_G.UnitCanAttack, "player", "target"), guid = call(_G.UnitGUID, "target") }
  r.stance = { call(_G.GetShapeshiftForm), call(_G.GetShapeshiftFormID) }
  r.casting = { call(_G.UnitCastingInfo, "player"), call(_G.UnitChannelInfo, "player") }
  r.assisted = { call(Api("C_AssistedCombat", "IsAvailable")), call(Api("C_AssistedCombat", "GetNextCastSpell")),
    call(Api("C_AssistedCombat", "GetRotationSpells")) }
  return r
end

-- what a set of results shows: "hidden" when any value was, else "error", "readable", "missing" or "nothing seen"
-- (no value to read, like a target without debuffs)
local function Verdict(results)
  local seen = {}
  local function walk(v, key)
    if key == "error" then seen.error = true
    elseif v == "<hidden>" then seen.hidden = true
    elseif v == "<missing>" then seen.missing = true
    elseif type(v) == "table" then for k, x in pairs(v) do if k ~= "n" then walk(x, k) end end
    elseif v ~= nil then seen.value = true end
  end
  walk(results)
  return seen.hidden and "hidden" or seen.error and "error" or seen.value and "readable" or seen.missing and "missing"
    or "nothing seen"
end

-- the summary's groups, in chat order: a name and the results it looks at
local function Groups(r)
  local function field(name)
    local out = {}
    for i, s in ipairs(r.spells) do out[i] = s[name] end
    return out
  end
  return {
    { "power", { r.power.current, r.power.max } }, { "combo points", { r.power.combo } },
    { "cooldowns", { r.globalCooldown, field("cooldown") } }, { "usable", field("usable") },
    { "in range", field("inRange") }, { "your buffs", r.buffs }, { "target debuffs", r.debuffs },
    { "target health", { r.target.health, r.target.healthMax } },
    { "target type", { r.target.classification, r.target.creatureType, r.target.canAttack } },
    { "stance or form", r.stance }, { "casting", r.casting }, { "assisted combat", r.assisted },
    { "spells you cast", r.casts }, { "target id", { r.target.guid } },
    { "swirl (times)", { r.swirl.times } }, { "swirl (duration)", { r.swirl.durationObject } },
    { "aura slots", r.otherAuras.slots }, { "unit auras", r.otherAuras.unitAuras },
    { "aura instance IDs", r.otherAuras.instanceIDs }, { "buff/debuff by index", r.otherAuras.byIndex },
    { "aura by spell ID", r.otherAuras.bySpellID }, { "aura by name", r.otherAuras.byName },
  }
end

local function CombatCheck()
  local db = KorkronPlannerDB.combatProbe
  local inInstance, instanceType = IsInInstance()
  local place = inInstance and "instance" or "world"
  if not (db and db.armed) or db[place] or not InCombatLockdown() then return end
  local r = CombatReport(instanceType)
  r.seen = {}
  local byVerdict = {}
  for _, group in ipairs(Groups(r)) do
    local verdict = Verdict(group[2])
    r.seen[group[1]] = verdict
    byVerdict[verdict] = byVerdict[verdict] or {}
    table.insert(byVerdict[verdict], group[1])
  end
  db[place] = r
  if db.world and db.instance then db.armed = nil end

  local parts = {}
  for _, verdict in ipairs({ "readable", "hidden", "error", "nothing seen", "missing" }) do
    if byVerdict[verdict] then table.insert(parts, verdict .. ": " .. table.concat(byVerdict[verdict], ", ")) end
  end
  KP:Print(("combat check %s: %s."):format(inInstance and "in an instance" or "outdoors", table.concat(parts, "; ")))
  KP:Print(db.armed and ("now one fight " .. (inInstance and "outdoors" or "in a dungeon or raid") .. ", then /reload.")
    or "both checks done: type /reload so the game saves them.")
end

-- arming also reads your buffs as they are now, before any fight
function KP:ArmCombatProbe()
  local calm = { inCombat = InCombatLockdown(), buffs = Auras("player", "HELPFUL") }
  calm.seen = Verdict(calm.buffs)
  KorkronPlannerDB.combatProbe = { armed = true, calm = calm }
  self:Print(("combat check on: your next fight outdoors and your next one in a dungeon or raid are each checked %d " ..
    "seconds in. Fight as usual (use your abilities, have a buff up); a line here says what the game showed. " ..
    "Your buffs right now: %s."):format(CHECK_AFTER, calm.seen))
end

KP:On("PLAYER_REGEN_DISABLED", function()
  local db = KorkronPlannerDB.combatProbe
  if db and db.armed then
    wipe(casts)
    KP.After(CHECK_AFTER, CombatCheck)
  end
end)
