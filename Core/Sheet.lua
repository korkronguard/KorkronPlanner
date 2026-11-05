-- Kor'kron Planner: your character sheet. Your numbers and the game's, the planner website's formulas worked out with
-- them (Data/Formulas.lua), and what 1 point of a main stat does: the game's own conversions where it has them (crit
-- from Agility...), the website's formulas otherwise. Used by the Formulas tab and the item tooltips.
local _, KP = ...

local Sheet = {}
KP.Sheet = Sheet

-- the numbers a formula can use (Data/Formulas.lua says which)
Sheet.INPUTS = { "level", "str", "agi", "sta", "int", "spi", "gearArmor", "armor", "health", "dodge", "parry", "block",
  "baseHealth", "baseMana", "hpPerSta" }
-- what each character sheet number is called: short (tooltips) and with what it does (Formulas tab)
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
-- the game's own conversions, per main stat: what the game says the whole stat gives (divided by the stat for 1
-- point). Which of these Forever has isn't known yet (/kp probe records them); without one, the planner's formula
-- stays, marked as an estimate.
local GAME_RATES = {
  agi = { { "crit", "GetCritChanceFromAgility" }, { "dodge", "GetDodgeChanceFromAgility" } },
  int = { { "spellCrit", "GetSpellCritChanceFromIntellect" } },
}

-- a number the game gives, or nil when it's missing or hidden
local function Readable(v)
  if KP.Readable(v) then return v end
end

-- your numbers, from the game (nil: some are hidden, like inside a dungeon or raid)
function Sheet.Inputs(class)
  local level = UnitLevel("player")
  local inputs = { level = level, hpPerSta = KP.LevelTables.hpPerSta[level],
    baseHealth = KP.LevelTables.baseHealth[class][level], baseMana = KP.LevelTables.baseMana[class][level] }
  for i, key in ipairs({ "str", "agi", "sta", "int", "spi" }) do
    local _, effective = UnitStat("player", i)
    inputs[key] = Readable(effective)
  end
  local _, armor = UnitArmor("player")
  inputs.armor, inputs.health = Readable(armor), Readable(UnitHealthMax("player"))
  inputs.dodge, inputs.parry = Readable(GetDodgeChance()), Readable(GetParryChance())
  inputs.block = Readable(GetBlockChance())
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

-- the game's own numbers to compare the formulas with
function Sheet.GameNumbers()
  local spellCrit
  for school = 2, 7 do
    local crit = Readable(GetSpellCritChance(school))
    if crit and (not spellCrit or crit > spellCrit) then spellCrit = crit end
  end
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
    armorStops = stops }
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

-- what the game says 1 point of a stat gives, by one of its conversion functions (nil when it has none)
local function GameRate(name, stat)
  local fn = _G[name]
  if type(fn) ~= "function" or not (stat and stat > 0) then return nil end
  local ok, total = KP.Safe(fn, "player")
  if not (ok and KP.Readable(total) and type(total) == "number") then return nil end
  return total / stat
end

-- What 1 point of a main stat (key: str, agi, sta, int or spi) does on your character sheet:
-- { { game = "crit", value = 0.18, digits = 2, estimate = false }, ... }
function Sheet.Effects(class, inputs, key)
  local out, at = {}, {}
  local more = setmetatable({ [key] = inputs[key] + 1 }, { __index = inputs })
  for _, f in ipairs(KP.Formulas[class]) do
    if f.expr and Sheet.EFFECTS[f.game] then
      local change = Sheet.Work(f.expr, more) - Sheet.Work(f.expr, inputs)
      if math.abs(change) > 1e-9 then
        table.insert(out, { game = f.game, value = change, digits = f.digits or 0, estimate = f.estimate })
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

-- "+0.37% crit" (long: "+0.37% crit chance: hits for double damage") for amount points of the stat; a small value
-- gets one more decimal (spell crit per point of Intellect is about 0.01%)
function Sheet.EffectText(effect, amount, long)
  local value = effect.value * amount
  local digits = effect.digits + (math.abs(value) < 0.1 and 1 or 0)
  local text = (value < 0 and "-" or "+") .. KP.Num(math.abs(value), digits) .. (PERCENT[effect.game] and "%" or "")
  return text .. " " .. Sheet.EFFECTS[effect.game][long and 2 or 1] .. (effect.estimate and " (estimate)" or "")
end
