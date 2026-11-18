local _, KP = ...

local Snapshot = {}
KP.Snapshot = Snapshot

local VERSION = 6
local DELAY = 5
local SCHOOLS = { 2, 3, 4, 5, 6, 7 }
local RATINGS = { "CR_DEFENSE_SKILL", "CR_DODGE", "CR_PARRY", "CR_BLOCK", "CR_HIT_MELEE", "CR_HIT_RANGED",
  "CR_HIT_SPELL", "CR_CRIT_MELEE", "CR_CRIT_RANGED", "CR_CRIT_SPELL", "CR_HASTE_MELEE", "CR_HASTE_RANGED",
  "CR_HASTE_SPELL", "CR_EXPERTISE", "CR_ARMOR_PENETRATION" }

local function num(v) return KP.Num(v, 4) end

local function All(...)
  local out = {}
  for i = 1, select("#", ...) do out[i] = num((select(i, ...))) end
  return table.concat(out, ",")
end

local function PerSchool(fn)
  local out = {}
  for i, school in ipairs(SCHOOLS) do out[i] = num(fn(school)) end
  return table.concat(out, ",")
end

local function Ratings()
  local out = {}
  for _, name in ipairs(RATINGS) do
    local index = _G[name]
    if index then
      local rating = GetCombatRating(index)
      if KP.Readable(rating) and (tonumber(rating) or 0) ~= 0 then
        table.insert(out, name:sub(4) .. ":" .. num(rating) .. ":" .. num(GetCombatRatingBonus(index)))
      end
    end
  end
  return table.concat(out, ",")
end

local function Items()
  local out = {}
  for slot = 1, 19 do
    local f = KP.ItemFields(KP.Text(GetInventoryItemLink("player", slot)))
    if f then
      table.insert(out, table.concat({ slot, f[1], f[2] or "", f[7] or "", KP.ItemBonusIDs(f) }, ":"))
    end
  end
  return table.concat(out, ",")
end

local function Talents()
  local out = {}
  for _, n in ipairs(KP.TalentNodes() or {}) do
    if n.purchased + n.current + n.active > 0 then
      table.insert(out, table.concat({ n.id, n.purchased, n.current, n.active }, ":"))
    end
  end
  return table.concat(out, ",")
end

local function FromStat(name)
  local fn = _G[name]
  if type(fn) ~= "function" then return "" end
  local ok, value = KP.Safe(fn, "player")
  return ok and num(value) or ""
end

local function Pet()
  if not UnitExists("pet") then return (";"):rep(13) end
  local family, familyID = UnitCreatureFamily("pet")
  return table.concat({
    (KP.Text(family) or "") .. "," .. num(familyID), num(UnitLevel("pet")),
    All(UnitStat("pet", 1)), All(UnitStat("pet", 2)), All(UnitStat("pet", 3)),
    All(UnitStat("pet", 4)), All(UnitStat("pet", 5)),
    num(UnitHealthMax("pet")), num(UnitPowerMax("pet", 0)), All(UnitArmor("pet")),
    All(UnitAttackPower("pet")), All(UnitDamage("pet")), All(UnitAttackSpeed("pet")),
    GetPetHappiness and All(GetPetHappiness()) or "",
  }, ";")
end

local FERAL = { [1] = true, [5] = true, [8] = true }

local function Forms()
  local out = {}
  for _, text in pairs(KorkronPlannerCharDB.forms[UnitLevel("player")] or {}) do table.insert(out, text) end
  table.sort(out)
  return table.concat(out, ",")
end

local function ReadForm()
  local form = GetShapeshiftFormID()
  if not (KP.Readable(form) and FERAL[form]) or InCombatLockdown() or IsInInstance() then return end
  local min, max, _, _, pos, neg, percent = UnitDamage("player")
  local base, plus, minus = UnitAttackPower("player")
  local values = { form, min, max, pos, neg, percent, (UnitAttackSpeed("player")), base, plus, minus,
    GetInventoryItemID("player", 16) or 0 }
  for i = 1, #values do
    if not KP.Readable(values[i]) then return end
    values[i] = num(values[i])
  end
  local level = UnitLevel("player")
  local readings = KorkronPlannerCharDB.forms[level] or {}
  KorkronPlannerCharDB.forms[level] = readings
  local text = table.concat(values, ":")
  if readings[form] == text then return end
  readings[form] = text
  Snapshot.Schedule()
end

local function Body()
  local _, class = UnitClass("player")
  local _, race, raceID = UnitRace("player")
  local ok, talents = KP.Safe(Talents)
  return table.concat({
    KP.Text(class) or "", KP.Text(race) or "", num(UnitLevel("player")),
    All(UnitStat("player", 1)), All(UnitStat("player", 2)), All(UnitStat("player", 3)),
    All(UnitStat("player", 4)), All(UnitStat("player", 5)),
    num(UnitHealthMax("player")), num(UnitPowerMax("player", 0)),
    num(GetCritChance()), num(GetRangedCritChance()), PerSchool(GetSpellCritChance),
    num(GetHitModifier()), num(GetSpellHitModifier()),
    num(GetDodgeChance()), num(GetParryChance()), num(GetBlockChance()),
    All(UnitAttackPower("player")), All(UnitRangedAttackPower("player")),
    PerSchool(GetSpellBonusDamage), num(GetSpellBonusHealing()),
    All(UnitArmor("player")), All(GetManaRegen()),
    Ratings(), Items(), ok and talents or "", num(raceID),
    FromStat("GetCritChanceFromAgility"), FromStat("GetSpellCritChanceFromIntellect"), FromStat("GetDodgeChanceFromAgility"),
    Pet(),
    num(GetShapeshiftFormID()), All(UnitDamage("player")), All(UnitAttackSpeed("player")), Forms(),
  }, ";")
end

function Snapshot.Text(snap)
  return table.concat({ VERSION, KP.Text(UnitGUID("player")) or "", snap.stamp, snap.body }, ";")
end

local scheduled, afterCombat = false, false

local function Loaded()
  local health = UnitHealthMax("player")
  return not KP.Readable(health) or (health or 0) > 0
end

local function Take()
  scheduled = false
  if InCombatLockdown() then
    afterCombat = true
    return
  end
  if IsInInstance() then return end
  if not Loaded() then return Snapshot.Schedule() end
  local level = UnitLevel("player")
  local body = Body()
  local snapshots = KorkronPlannerCharDB.snapshots
  local old = snapshots[level]
  if old and old.body == body then return end
  local pet = UnitExists("pet")
  if old and old.pet and not pet then return end
  snapshots[level] = { stamp = GetServerTime(), body = body, pet = pet or nil }
  KP.Share.Added()
end

function Snapshot.Schedule()
  if scheduled then return end
  scheduled = true
  KP.After(DELAY, Take)
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "UNIT_PET" }) do
  KP:On(event, Snapshot.Schedule)
end

KP:On("PLAYER_REGEN_ENABLED", function()
  if not afterCombat then return end
  afterCombat = false
  Snapshot.Schedule()
end)

for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
  KP:On(event, function() KP.After(2, ReadForm) end)
end
