-- Kor'kron Planner: the Formulas tab of the /kp window. How the planner website works out your character sheet's
-- numbers (Data/Formulas.lua, written from the website's own math): each formula in words, worked out with your own
-- numbers, and the game's number next to it, with a tick when they agree. Then what 1 point of each stat does: what
-- it changes on your character sheet (the same formulas with 1 more) and what the planner says it's worth to your
-- build (Data/Weights.lua). Last, the rules of combat for your class.
local _, KP = ...

local Pane = {}
KP.FormulasPane = Pane

Pane.Create = KP.ScrollList.Create

local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
-- what each input of a formula is called in "Your numbers" (and its decimals there)
local INPUTS = { "level", "str", "agi", "sta", "int", "spi", "gearArmor", "armor", "health", "dodge", "parry", "block",
  "baseHealth", "baseMana", "hpPerSta" }
local LABEL = { level = "level", str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
  gearArmor = "armor on your gear", armor = "your armor", health = "your health", dodge = "dodge %", parry = "parry %",
  block = "block %", baseHealth = "base health", baseMana = "base mana", hpPerSta = "health per Stamina" }
local DIGITS = { dodge = 2, parry = 2, block = 2 }
-- the main stats, by their names in the formulas and in the stat weights
local MAIN_STATS = { { "str", "strength" }, { "agi", "agility" }, { "sta", "stamina" }, { "int", "intellect" },
  { "spi", "spirit" } }

-- a number the game gives, or nil when it's missing or hidden
local function Readable(v)
  if KP.Readable(v) then return v end
end

-- your numbers, from the game (nil: some are hidden, like inside a dungeon or raid)
local function Inputs(class)
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
  for _, key in ipairs(INPUTS) do
    if inputs[key] == nil then return nil end
  end
  return inputs
end

-- the game's own numbers to compare with
local function GameNumbers()
  local spellCrit
  for school = 2, 7 do
    local crit = Readable(GetSpellCritChance(school))
    if crit and (not spellCrit or crit > spellCrit) then spellCrit = crit end
  end
  local _, armor = UnitArmor("player")
  return { health = Readable(UnitHealthMax("player")), mana = Readable(UnitPowerMax("player", 0)),
    ap = Readable((UnitAttackPower("player"))), rap = Readable((UnitRangedAttackPower("player"))),
    crit = Readable(GetCritChance()), spellCrit = spellCrit, armor = Readable(armor), regen = Readable((GetManaRegen())) }
end

local compiled = {}
local function Work(expr, inputs)
  local fn = compiled[expr]
  if not fn then
    fn = assert(loadstring("return " .. expr))
    compiled[expr] = fn
  end
  setfenv(fn, setmetatable({ min = math.min, max = math.max }, { __index = inputs }))
  return fn()
end

-- "Your numbers: level 12, Strength 45" for the inputs this formula uses
local function YourNumbers(expr, inputs)
  local used = {}
  for _, key in ipairs(INPUTS) do
    if expr:find("%f[%w]" .. key .. "%f[%W]") then
      table.insert(used, LABEL[key] .. " " .. KP.Num(inputs[key], DIGITS[key] or 0))
    end
  end
  return "Your numbers: " .. table.concat(used, ", ")
end

-- "= 106   game: 106 ✓"
local function ResultLine(f, value, game)
  local digits, unit = f.digits or 0, f.unit or ""
  local text = "= " .. KP.Num(value, digits) .. unit
  if not f.game then return text end
  if game == nil then return text .. "   |cff999999game: hidden|r" end
  local same = math.abs(value - game) <= 0.5 * 10 ^ -digits + 1e-9
  local shown = KP.Num(game, digits) .. unit
  if same then return text .. "   game: " .. shown .. " " .. TICK end
  return text .. (f.estimate and "   game: " or "   |cffff9933game: ") .. shown .. (f.estimate and "" or "|r")
end

-- what 1 more point of a main stat changes on your character sheet, by the same formulas:
-- { "+2 armor", "+0.3% melee crit (estimate)" }
local function SheetChanges(list, inputs, key)
  local more = setmetatable({ [key] = inputs[key] + 1 }, { __index = inputs })
  local out = {}
  for _, f in ipairs(list) do
    if f.expr and f.game then
      local change = Work(f.expr, more) - Work(f.expr, inputs)
      if math.abs(change) >= 0.5 * 10 ^ -(f.digits or 0) then
        local unit = f.unit or ""
        local what = unit:sub(1, 1) == " " and unit or (unit .. " " .. f.name:lower())
        table.insert(out, "+" .. KP.Num(change, f.digits or 0) .. what .. (f.estimate and " (estimate)" or ""))
      end
    end
  end
  return out
end

-- What 1 point of each stat does: on your character sheet (main stats) and to the build you follow
local function StatSection(L, list, inputs, build)
  L.text("What 1 point of each stat does for you", "GameFontNormalLarge", 0, 16)
  local W = build and KP.Build.ForLevel(KP.Weights, build.key, UnitLevel("player"))
  L.text(W and ("Worth = what the planner says 1 point adds for " .. build.name .. " at your level.")
    or "Choose one of the planner's builds on the left to see what each point is worth to it.", "GameFontDisableSmall", 0, 2)
  local function Worth(key)
    return W and KP.Upgrade.Describe(KP.Upgrade.Value(W, key, 1), build.role, 0.0005)
  end
  for _, stat in ipairs(MAIN_STATS) do
    L.text(LABEL[stat[1]], "GameFontNormal", 0, 10)
    local changes = inputs and SheetChanges(list, inputs, stat[1]) or {}
    L.text(#changes > 0 and table.concat(changes, ", ") or "Nothing on your character sheet.", "GameFontHighlightSmall", 0, 2)
    local worth = Worth(stat[2])
    if worth then L.text("Worth " .. worth, "GameFontHighlightSmall", 0, 2) end
  end
  if not W then return end
  local others = {}
  for i = #MAIN_STATS + 1, #KP.Upgrade.STATS do
    local key, name = KP.Upgrade.STATS[i][1], KP.Upgrade.STATS[i][2]
    local worth = Worth(key)
    if worth then table.insert(others, name .. ": " .. worth) end
  end
  if #others > 0 then
    L.text("Other stats, 1 point each", "GameFontNormal", 0, 10)
    for _, line in ipairs(others) do L.text(line, "GameFontHighlightSmall", 0, 2) end
  end
end

-- build: the chosen build (nil when none), for what each stat is worth
function Pane.Refresh(pane, build)
  local L = KP.ScrollList.Layout(pane)
  local _, class = UnitClass("player")
  local list = KP.Formulas[class]
  L.text("How your numbers are worked out", "GameFontNormalLarge", 0, 0)
  L.text("The planner website's formulas, with your numbers. " .. TICK .. " = the game agrees.", "GameFontDisableSmall", 0, 2)
  local inputs = Inputs(class)
  if not inputs then
    L.text("The game hides some of your numbers here (inside a dungeon or raid?).", "GameFontHighlight", 0, 12)
  end
  local game = GameNumbers()
  local rules = {}
  for _, f in ipairs(list) do
    if f.expr and inputs then
      L.text(f.name .. (f.estimate and "  |cff999999(planner's estimate)|r" or ""), "GameFontNormal", 0, 12)
      L.text(f.text, "GameFontHighlightSmall", 0, 2)
      L.text(YourNumbers(f.expr, inputs), "GameFontDisableSmall", 0, 2)
      L.text(ResultLine(f, Work(f.expr, inputs), f.game and game[f.game]), "GameFontHighlight", 0, 2)
      if f.note then L.text(f.note, "GameFontDisableSmall", 0, 2) end
    elseif not f.expr then
      table.insert(rules, f)
    end
  end
  StatSection(L, list, inputs, build)
  L.text("Rules of combat", "GameFontNormalLarge", 0, 16)
  for _, f in ipairs(rules) do
    L.text("|cffffd100" .. f.name .. ":|r " .. f.text, "GameFontHighlightSmall", 0, 6)
  end
  L.finish()
end
