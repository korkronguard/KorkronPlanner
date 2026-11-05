-- Kor'kron Planner: the Formulas tab of the /kp window. How the planner website works out your character sheet's
-- numbers (Data/Formulas.lua, written from the website's own math): each formula in words, worked out with your own
-- numbers, and the game's number next to it, with a tick when they agree. Then the rules of combat for your class.
local _, KP = ...

local Pane = {}
KP.FormulasPane = Pane

Pane.Create = KP.ScrollList.Create

local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
-- what each input of a formula is called in "Your numbers"
local INPUTS = { "level", "str", "agi", "sta", "int", "spi", "gearArmor", "armor", "baseHealth", "baseMana", "hpPerSta" }
local LABEL = { level = "level", str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
  gearArmor = "armor on your gear", armor = "your armor", baseHealth = "base health", baseMana = "base mana",
  hpPerSta = "health per Stamina" }

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
  inputs.armor = Readable(armor)
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
    if expr:find("%f[%w]" .. key .. "%f[%W]") then table.insert(used, LABEL[key] .. " " .. KP.Num(inputs[key], 0)) end
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

function Pane.Refresh(pane)
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
  L.text("Rules of combat", "GameFontNormalLarge", 0, 16)
  for _, f in ipairs(rules) do
    L.text("|cffffd100" .. f.name .. ":|r " .. f.text, "GameFontHighlightSmall", 0, 6)
  end
  L.finish()
end
