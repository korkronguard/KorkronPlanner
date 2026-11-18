local _, KP = ...

local Sheet = {}
KP.Sheet = Sheet

Sheet.INPUTS = { "level", "str", "agi", "sta", "int", "spi", "gearArmor", "armor", "health", "dodge", "parry", "block",
  "baseHealth", "baseMana", "hpPerSta", "speed", "twoHand", "agiPerCrit" }
Sheet.EFFECTS = {
  health = { "health", "health" },
  mana = { "mana", "mana" },
  ap = { "attack power", "attack power: more damage on every melee hit" },
  rap = { "ranged attack power", "ranged attack power: more damage on every shot" },
  crit = { "crit", "crit chance: hits for double damage" },
  spellCrit = { "spell crit", "spell crit chance: spells hit or heal for 1.5 times as much" },
  dodge = { "dodge", "dodge chance: a melee hit misses you completely" },
  armor = { "armor", "armor: less physical damage taken" },
  regen = { "mana regen", "mana per second from Spirit, once you haven't spent mana for 5 seconds" },
}
local PERCENT = { crit = true, spellCrit = true, dodge = true }
local GAME_RATES = {
  agi = { { "crit", "GetCritChanceFromAgility" }, { "dodge", "GetDodgeChanceFromAgility" } },
  int = { { "spellCrit", "GetSpellCritChanceFromIntellect" } },
}

local function Readable(v)
  if KP.Readable(v) then return v end
end

function Sheet.Inputs(class)
  local level = UnitLevel("player")
  local inputs = { level = level, hpPerSta = KP.LevelTables.hpPerSta[level],
    baseHealth = KP.LevelTables.baseHealth[class][level], baseMana = KP.LevelTables.baseMana[class][level],
    agiPerCrit = KP.LevelTables.agiPerCrit[class][level] }
  for i, key in ipairs({ "str", "agi", "sta", "int", "spi" }) do
    local _, effective = UnitStat("player", i)
    inputs[key] = Readable(effective)
  end
  local _, armor = UnitArmor("player")
  inputs.armor, inputs.health = Readable(armor), Readable(UnitHealthMax("player"))
  inputs.dodge, inputs.parry = Readable(GetDodgeChance()), Readable(GetParryChance())
  local offHand = Readable(GetInventoryItemID("player", 17))
  local shield = offHand and KP.Items[offHand] and KP.Items[offHand][1] == "shield"
  if shield then
    inputs.block = Readable(GetBlockChance())
  else
    inputs.block = 0
  end
  inputs.speed = Readable((UnitAttackSpeed("player")))
  local mainHand = Readable(GetInventoryItemID("player", 16))
  inputs.twoHand = mainHand and KP.Items[mainHand] and KP.Items[mainHand][1] == "twoHand" and 1 or 0
  local gearArmor = 0
  for slot = 1, 19 do
    local id = Readable(GetInventoryItemID("player", slot))
    local item = id and KP.Items[id]
    gearArmor = gearArmor + (item and item.a or 0)
  end
  inputs.gearArmor = gearArmor
  for _, key in ipairs(Sheet.INPUTS) do
    if inputs[key] == nil then return nil end
  end
  return inputs
end

local function BestSchool(fn)
  local best
  for school = 2, 7 do
    local v = Readable(fn(school))
    if v and (not best or v > best) then best = v end
  end
  return best
end

function Sheet.GameNumbers()
  local spellCrit = BestSchool(GetSpellCritChance)
  local _, armor = UnitArmor("player")
  armor = Readable(armor)
  local stops
  if armor and C_PaperDollInfo and C_PaperDollInfo.GetArmorEffectiveness then
    local share = Readable(C_PaperDollInfo.GetArmorEffectiveness(armor, UnitLevel("player")))
    stops = share and share * 100
  end
  return { health = Readable(UnitHealthMax("player")), mana = Readable(UnitPowerMax("player", 0)),
    ap = Readable((UnitAttackPower("player"))), rap = Readable((UnitRangedAttackPower("player"))),
    crit = Readable(GetCritChance()), spellCrit = spellCrit, armor = armor, regen = Readable((GetManaRegen())),
    armorStops = stops, dodge = Readable(GetDodgeChance()) }
end

local MAIN_STAT = { strength = 1, agility = 2, stamina = 3, intellect = 4, spirit = 5 }
local SCHOOL = { holyDamage = 2, fireDamage = 3, natureDamage = 4, frostDamage = 5, shadowDamage = 6, arcaneDamage = 7 }
local WEAPON_SLOT = { mainHand = 16, offHand = 17, ranged = 18 }
local CASTER = { MAGE = true, PRIEST = true, WARLOCK = true }
local RATING = {
  crit = { "CR_CRIT_MELEE", "CR_CRIT_SPELL", function(caster) return caster and BestSchool(GetSpellCritChance) or Readable(GetCritChance()) end },
  hit = { "CR_HIT_MELEE", "CR_HIT_SPELL", function(caster, index)
    local talents, rating = Readable((caster and GetSpellHitModifier or GetHitModifier)()), Readable(GetCombatRatingBonus(index))
    return talents and rating and talents + rating
  end },
  dodge = { "CR_DODGE", nil, function() return Readable(GetDodgeChance()) end },
  parry = { "CR_PARRY", nil, function() return Readable(GetParryChance()) end },
  block = { "CR_BLOCK", nil, function() return Readable(GetBlockChance()) end },
  defense = { "CR_DEFENSE_SKILL" }, expertise = { "CR_EXPERTISE" },
}

function Sheet.Have(key)
  if MAIN_STAT[key] then
    local _, effective = UnitStat("player", MAIN_STAT[key])
    return Readable(effective)
  elseif key == "armor" then
    local _, armor = UnitArmor("player")
    return Readable(armor)
  elseif key == "attackPower" or key == "rangedAttackPower" then
    local base, plus, minus = (key == "attackPower" and UnitAttackPower or UnitRangedAttackPower)("player")
    return Readable(base) and Readable(plus) and Readable(minus) and base + plus + minus or nil
  elseif key == "blockValue" then
    return GetShieldBlock and Readable(GetShieldBlock()) or nil
  elseif key == "healing" then
    return Readable(GetSpellBonusHealing())
  elseif key == "spellPower" or key == "spellDamage" then
    return BestSchool(GetSpellBonusDamage)
  elseif SCHOOL[key] then
    return Readable(GetSpellBonusDamage(SCHOOL[key]))
  elseif WEAPON_SLOT[key] then
    local id = Readable(GetInventoryItemID("player", WEAPON_SLOT[key]))
    local weapon = id and KP.Items[id] and KP.Items[id].w
    return weapon and (weapon[1] + weapon[2]) / 2 / weapon[3] or nil
  elseif RATING[key] then
    local _, class = UnitClass("player")
    local melee, spell, chance = unpack(RATING[key], 1, 3)
    local index = _G[CASTER[class] and spell or melee]
    local rating = index and Readable(GetCombatRating(index))
    if not rating then return nil end
    return rating, chance and chance(CASTER[class] and spell ~= nil, index) or nil
  end
end

function Sheet.IsEstimate(f, level)
  return f.estimate or (f.estimateAbove ~= nil and level > f.estimateAbove)
end

local compiled = {}
function Sheet.Work(expr, inputs)
  local fn = compiled[expr]
  if not fn then
    fn = assert(loadstring("return " .. expr))
    compiled[expr] = fn
  end
  setfenv(fn, setmetatable({ min = math.min, max = math.max }, { __index = inputs }))
  return fn()
end

local function GameRate(name, stat)
  local fn = _G[name]
  if type(fn) ~= "function" or not (stat and stat > 0) then return nil end
  local ok, total = KP.Safe(fn, "player")
  if not (ok and KP.Readable(total) and type(total) == "number") then return nil end
  return total / stat
end

function Sheet.Effects(class, inputs, key)
  local out, at = {}, {}
  local more = setmetatable({ [key] = inputs[key] + 1 }, { __index = inputs })
  for _, f in ipairs(KP.Formulas[class]) do
    if f.expr and Sheet.EFFECTS[f.game] then
      local change = Sheet.Work(f.expr, more) - Sheet.Work(f.expr, inputs)
      if math.abs(change) > 1e-9 then
        table.insert(out, { game = f.game, value = change, digits = f.digits or 0, estimate = Sheet.IsEstimate(f, inputs.level) })
        at[f.game] = #out
      end
    end
  end
  for _, rate in ipairs(GAME_RATES[key] or {}) do
    local value = GameRate(rate[2], inputs[key])
    if value then
      local effect = { game = rate[1], value = value, digits = 2 }
      if at[rate[1]] then out[at[rate[1]]] = effect else table.insert(out, effect) end
    end
  end
  return out
end

function Sheet.EffectText(effect, amount, long)
  local value = effect.value * amount
  local digits = effect.digits + (math.abs(value) < 0.1 and 1 or 0)
  local text = (value < 0 and "-" or "+") .. KP.Num(math.abs(value), digits) .. (PERCENT[effect.game] and "%" or "")
  return text .. " " .. Sheet.EFFECTS[effect.game][long and 2 or 1] .. (effect.estimate and " (estimate)" or "")
end
