-- Kor'kron Planner: the Formulas tab of the /kp window. First what 1 point of each stat does for you: on your
-- character sheet (the game's own conversions where it has them, the planner's formulas otherwise; Core/Sheet.lua)
-- and what the planner says it's worth to your build (Data/Weights.lua). Then how the planner website works out your
-- character sheet's numbers (Data/Formulas.lua): each formula in words, worked out with your numbers, with the game's
-- number next to it and a tick when they agree. Last, the rules of combat for your class.
local _, KP = ...

local Pane = {}
KP.FormulasPane = Pane

Pane.Create = KP.ScrollList.Create

local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local INDENT = 10
-- what each input of a formula is called in "Your numbers" (and its decimals there)
local LABEL = { level = "level", str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
  gearArmor = "armor on your gear", armor = "your armor", health = "your health", dodge = "dodge %", parry = "parry %",
  block = "block %", baseHealth = "base health", baseMana = "base mana", hpPerSta = "health per Stamina",
  hit = "your average main-hand hit" }
local DIGITS = { dodge = 2, parry = 2, block = 2, hit = 1 }
-- the main stats, by their names in the formulas and in the stat weights
local MAIN_STATS = { { "str", "strength" }, { "agi", "agility" }, { "sta", "stamina" }, { "int", "intellect" },
  { "spi", "spirit" } }

-- "Your numbers: level 12, Strength 45" for the inputs this formula uses
local function YourNumbers(expr, inputs)
  local used = {}
  for _, key in ipairs(KP.Sheet.INPUTS) do
    if expr:find("%f[%w]" .. key .. "%f[%W]") then
      table.insert(used, LABEL[key] .. " " .. KP.Num(inputs[key], DIGITS[key] or 0))
    end
  end
  return "Your numbers: " .. table.concat(used, ", ")
end

-- "Attack power = 106   game: 106 ✓"
local function ResultLine(f, value, game)
  local digits, unit = f.digits or 0, f.unit or ""
  local text = f.name .. " = " .. KP.Num(value, digits) .. unit
  if f.estimate then text = text .. "  |cff999999(estimate)|r" end
  if not f.game or game == nil then return text end
  local same = math.abs(value - game) <= 0.5 * 10 ^ -digits + 1e-9
  local shown = KP.Num(game, digits) .. unit
  if same then return text .. "   |cffffffffgame: " .. shown .. "|r " .. TICK end
  return text .. (f.estimate and "   |cffffffffgame: " or "   |cffff9933game: ") .. shown .. "|r"
end

-- Each number in a formula or rule: what it is and where it comes from (the game files, the original game's rule,
-- Forever's patch notes, the planner's estimate...)
local function Numbers(L, f, indent)
  L.text("Where the numbers come from:", "GameFontDisableSmall", indent, 4)
  for _, n in ipairs(f.numbers) do
    L.text("|cffffd100" .. n[1] .. ":|r " .. n[2] .. ". |cff999999From: " .. n[3] .. ".|r", "GameFontHighlightSmall", indent + INDENT, 2)
  end
end

-- What 1 point of each stat does: on your character sheet (main stats) and to the build you follow
local function StatSection(L, class, inputs, build)
  L.text("What each stat does for you", "GameFontNormalLarge", 0, 0)
  local W = build and KP.Build.ForLevel(KP.Weights, build.key, UnitLevel("player"))
  L.text("For 1 point of each stat, from the game's own numbers where it gives them. " ..
    (W and ("Worth: what the planner says it adds for " .. build.name:gsub(" %b()", "") .. " at your level.")
      or "Choose one of the planner's builds on the left to see what each point is worth to it."),
    "GameFontDisableSmall", 0, 2)
  local function Worth(key)
    return W and KP.Upgrade.Describe(KP.Upgrade.Value(W, key, 1), build.role, 0.0005)
  end
  for _, stat in ipairs(MAIN_STATS) do
    L.text(LABEL[stat[1]], "GameFontNormal", 0, 10)
    local effects = inputs and KP.Sheet.Effects(class, inputs, stat[1]) or {}
    for _, effect in ipairs(effects) do
      L.text(KP.Sheet.EffectText(effect, 1, true), "GameFontHighlightSmall", INDENT, 2)
    end
    if #effects == 0 then L.text("Nothing on your character sheet.", "GameFontHighlightSmall", INDENT, 2) end
    local worth = Worth(stat[2])
    if worth then L.text("|cff7fd7ffWorth " .. worth .. "|r", "GameFontHighlightSmall", INDENT, 2) end
  end
  if not W then return end
  local others = {}
  for i = #MAIN_STATS + 1, #KP.Upgrade.STATS do
    local key, name = KP.Upgrade.STATS[i][1], KP.Upgrade.STATS[i][2]
    local worth = Worth(key)
    if worth then table.insert(others, name .. ": |cff7fd7ff" .. worth .. "|r") end
  end
  if #others > 0 then
    L.text("Other stats, worth of 1 point", "GameFontNormal", 0, 10)
    for _, line in ipairs(others) do L.text(line, "GameFontHighlightSmall", INDENT, 2) end
  end
end

-- build: the chosen build (nil when none), for what each stat is worth
function Pane.Refresh(pane, build)
  local L = KP.ScrollList.Layout(pane)
  local _, class = UnitClass("player")
  local list = KP.Formulas[class]
  local inputs = KP.Sheet.Inputs(class)
  if not inputs then
    L.text("The game hides some of your numbers here (inside a dungeon or raid?).", "GameFontHighlight", 0, 0)
  end
  StatSection(L, class, inputs, build)
  L.text("How your numbers are worked out", "GameFontNormalLarge", 0, 18)
  L.text("The planner website's formulas, with your numbers. " .. TICK .. " = the game agrees.", "GameFontDisableSmall", 0, 2)
  L.text("Under each formula, where its numbers come from. Forever's game files: read from the game itself. The " ..
    "original game's rule: worked out by the game's server, so it isn't in the files; it's how WoW has always worked, " ..
    "and Classic servers use the same. Checked on Forever: matched against real characters. Patch notes: Forever's own. " ..
    "Estimate: the planner's best guess until real characters show the game's rule.", "GameFontDisableSmall", 0, 4)
  local game = KP.Sheet.GameNumbers()
  local rules = {}
  for _, f in ipairs(list) do
    if f.expr and inputs then
      L.text(ResultLine(f, KP.Sheet.Work(f.expr, inputs), f.game and game[f.game]), "GameFontNormal", 0, 10)
      L.text(f.text, "GameFontHighlightSmall", INDENT, 2)
      L.text(YourNumbers(f.expr, inputs), "GameFontDisableSmall", INDENT, 2)
      if f.note then L.text(f.note, "GameFontDisableSmall", INDENT, 2) end
      Numbers(L, f, INDENT)
    elseif not f.expr then
      table.insert(rules, f)
    end
  end
  L.text("Rules of combat", "GameFontNormalLarge", 0, 18)
  for _, f in ipairs(rules) do
    L.text("|cffffd100" .. f.name .. ":|r " .. f.text, "GameFontHighlightSmall", 0, 6)
    Numbers(L, f, INDENT)
  end
  L.finish()
end
