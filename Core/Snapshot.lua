-- Kor'kron Planner: snapshots of your own character, the data the guild's collector gathers (Share.lua).
-- KorkronPlannerCharDB.snapshots[level] = { stamp, body, delivered } keeps the latest snapshot for each level.
-- One is taken a few seconds after logging in, a level-up, a gear change or a talent change, but never in combat or
-- inside an instance (the game can hide values there, and group buffs would skew them). A snapshot that matches the
-- one already kept for that level is not kept again.
--
-- Text format, version 3, fields separated by ";":
--   3;guid;stamp;CLASS;RACE;level;str;agi;sta;int;spi;maxHealth;maxMana;crit;rangedCrit;spellCrit;hit;spellHit;
--   dodge;parry;block;attackPower;rangedAttackPower;spellDamage;healing;armor;manaRegen;ratings;items;talents;raceID;
--   critFromAgility;spellCritFromIntellect;dodgeFromAgility
-- Version 2 added raceID (UnitRace's 3rd value, the game's race ID: both Skyborne races give the RACE "Skyborne").
-- Version 3 added what the game's own character sheet says the whole of Agility / Intellect gives (empty when the
-- client has no such function). A snapshot kept before a version and sent later lacks its fields.
-- The first six fields keep their place in every version (the collector reads them). stamp = server time in
-- seconds. A field for a game function lists every number it returns, comma-separated: UnitStat base,effective,
-- plus,minus; UnitAttackPower base,plus,minus; UnitArmor and GetManaRegen as the game gives them. spellCrit and
-- spellDamage have one number per school 2-7 (holy, fire, nature, frost, shadow, arcane). ratings:
-- NAME:rating:percent for each combat rating that isn't 0 (NAME = the game's CR_ name without "CR_"). items:
-- slot:itemID:enchantID:suffixID per worn item. talents: nodeID:ranksPurchased:currentRank:activeRank per talent
-- node with points (the game's trait node IDs; Forever doesn't always fill all three). A hidden or missing number
-- is left empty.
local _, KP = ...

local Snapshot = {}
KP.Snapshot = Snapshot

local VERSION = 3
local DELAY = 5 -- seconds: lets stats settle (UnitLevel still gives the old level during PLAYER_LEVEL_UP)
local SCHOOLS = { 2, 3, 4, 5, 6, 7 }
local RATINGS = { "CR_DEFENSE_SKILL", "CR_DODGE", "CR_PARRY", "CR_BLOCK", "CR_HIT_MELEE", "CR_HIT_RANGED",
  "CR_HIT_SPELL", "CR_CRIT_MELEE", "CR_CRIT_RANGED", "CR_CRIT_SPELL", "CR_HASTE_MELEE", "CR_HASTE_RANGED",
  "CR_HASTE_SPELL", "CR_EXPERTISE", "CR_ARMOR_PENETRATION" }

local function num(v) return KP.Num(v, 4) end

-- every number given, comma-separated
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
    -- Forever's links look like |cnIQ4:|Hitem:12345:0:...|h[Name]|h|r
    local link = KP.Text(GetInventoryItemLink("player", slot))
    local itemString = link and link:match("item:([%-%d:]+)")
    if itemString then
      local f = {}
      for v in (itemString .. ":"):gmatch("([^:]*):") do table.insert(f, v) end
      table.insert(out, table.concat({ slot, f[1], f[2] or "", f[7] or "" }, ":"))
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

-- what the game says a whole stat gives ("" when the client has no such function; which ones Forever has isn't known
-- yet, so a failing one goes to /kp errors and the rest of the snapshot is still kept)
local function FromStat(name)
  local fn = _G[name]
  if type(fn) ~= "function" then return "" end
  local ok, value = KP.Safe(fn, "player")
  return ok and num(value) or ""
end

-- everything after the stamp
local function Body()
  local _, class = UnitClass("player")
  local _, race, raceID = UnitRace("player")
  -- the trait functions are the least known part of Forever's API: if they fail, the error goes to /kp errors and
  -- the rest of the snapshot is still kept
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
  }, ";")
end

-- A kept snapshot as the line the collector stores
function Snapshot.Text(snap)
  return table.concat({ VERSION, KP.Text(UnitGUID("player")) or "", snap.stamp, snap.body }, ";")
end

local scheduled, afterCombat = false, false

local function Take()
  scheduled = false
  if InCombatLockdown() then
    afterCombat = true
    return
  end
  if IsInInstance() then return end -- leaving it means a loading screen, which schedules a new one
  local level = UnitLevel("player")
  local body = Body()
  local snapshots = KorkronPlannerCharDB.snapshots
  local old = snapshots[level]
  if old and old.body == body then return end
  snapshots[level] = { stamp = GetServerTime(), body = body }
  KP.Share.Added()
end

function Snapshot.Schedule()
  if scheduled then return end
  scheduled = true
  KP.After(DELAY, Take)
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
  KP:On(event, Snapshot.Schedule)
end

KP:On("PLAYER_REGEN_ENABLED", function()
  if not afterCombat then return end
  afterCombat = false
  Snapshot.Schedule()
end)
