local _, KP = ...

local Pane = {}
KP.FormulasPane = Pane

Pane.Create = KP.ScrollList.Create

local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local INDENT = 10
local LABEL = { level = "level", str = "Strength", agi = "Agility", sta = "Stamina", int = "Intellect", spi = "Spirit",
  gearArmor = "armor on your gear", armor = "your armor", health = "your health", dodge = "dodge %", parry = "parry %",
  block = "block %", baseHealth = "base health", baseMana = "base mana", hpPerSta = "health per Stamina",
  speed = "your swing time", twoHand = "a two-hander (1 yes, 0 no)", agiPerCrit = "Agility per 1% crit at your level" }
local DIGITS = { dodge = 2, parry = 2, block = 2, speed = 2, agiPerCrit = 2 }
local MAIN_STATS = { { "str", "strength" }, { "agi", "agility" }, { "sta", "stamina" }, { "int", "intellect" },
  { "spi", "spirit" } }

local function YourNumbers(expr, inputs)
  local used = {}
  for _, key in ipairs(KP.Sheet.INPUTS) do
    if expr:find("%f[%w]" .. key .. "%f[%W]") then
      table.insert(used, LABEL[key] .. " " .. KP.Num(inputs[key], DIGITS[key] or 0))
    end
  end
  return "Your numbers: " .. table.concat(used, ", ")
end

local function ResultLine(f, value, game, level)
  local digits, unit = f.digits or 0, f.unit or ""
  local estimate = KP.Sheet.IsEstimate(f, level)
  local text = f.name .. " = " .. KP.Num(value, digits) .. unit
  if estimate then text = text .. "  |cff999999(estimate)|r" end
  if not f.game or game == nil then return text end
  local same = math.abs(value - game) <= 0.5 * 10 ^ -digits + 1e-9
  local shown = KP.Num(game, digits) .. unit
  if same then return text .. "   |cffffffffgame: " .. shown .. "|r " .. TICK end
  return text .. (estimate and "   |cffffffffgame: " or "   |cffff9933game: ") .. shown .. "|r"
end

local function Numbers(L, f, indent)
  L.text("Where the numbers come from:", "KorkronPlannerFontDisableSmall", indent, 4)
  for _, n in ipairs(f.numbers) do
    L.text("|cffffd100" .. n[1] .. ":|r " .. n[2] .. ". |cff999999From: " .. n[3] .. ".|r", "KorkronPlannerFontHighlightSmall", indent + INDENT, 2)
  end
end

local function StatSection(L, class, inputs, build)
  L.text("What each stat does for you", "KorkronPlannerFontNormalLarge", 0, 0)
  local W = build and KP.StatWeights.For(build)
  L.text("For 1 point of each stat, from the game's own numbers where it gives them. " ..
    (W and (W.live and "Worth: what it adds for you with the gear you wear (the Stats tab lists them all)."
        or "Worth: what the planner says it adds for " .. build.name:gsub(" %b()", "") .. " at your level.")
      or "Choose one of the planner's builds on the left to see what each point is worth to it."),
    "KorkronPlannerFontDisableSmall", 0, 2)
  local function Worth(key)
    return W and KP.Upgrade.Describe(KP.Upgrade.Value(W, key, 1), build.role, 0.0005)
  end
  for _, stat in ipairs(MAIN_STATS) do
    L.text(LABEL[stat[1]], "KorkronPlannerFontNormal", 0, 10)
    local effects = inputs and KP.Sheet.Effects(class, inputs, stat[1]) or {}
    for _, effect in ipairs(effects) do
      L.text(KP.Sheet.EffectText(effect, 1, true), "KorkronPlannerFontHighlightSmall", INDENT, 2)
    end
    if #effects == 0 then L.text("Nothing on your character sheet.", "KorkronPlannerFontHighlightSmall", INDENT, 2) end
    local worth = Worth(stat[2])
    if worth then L.text("|cff7fd7ffWorth " .. worth .. "|r", "KorkronPlannerFontHighlightSmall", INDENT, 2) end
  end
  if not W then return end
  local others = {}
  for i = #MAIN_STATS + 1, #KP.Upgrade.STATS do
    local key, name = KP.Upgrade.STATS[i][1], KP.Upgrade.STATS[i][2]
    local worth = Worth(key)
    if worth then table.insert(others, name .. ": |cff7fd7ff" .. worth .. "|r") end
  end
  if #others > 0 then
    L.text("Other stats, worth of 1 point", "KorkronPlannerFontNormal", 0, 10)
    for _, line in ipairs(others) do L.text(line, "KorkronPlannerFontHighlightSmall", INDENT, 2) end
  end
end

function Pane.Refresh(pane, build)
  local L = KP.ScrollList.Layout(pane)
  local _, class = UnitClass("player")
  local list = KP.Formulas[class]
  local inputs = KP.Sheet.Inputs(class)
  if not inputs then
    L.text("The game hides some of your numbers here (inside a dungeon or raid?).", "KorkronPlannerFontHighlight", 0, 0)
  end
  StatSection(L, class, inputs, build)
  L.text("How your numbers are worked out", "KorkronPlannerFontNormalLarge", 0, 18)
  L.text("The planner website's formulas, with your numbers. " .. TICK .. " = the game agrees.", "KorkronPlannerFontDisableSmall", 0, 2)
  L.text("Under each formula, where its numbers come from. Forever's game files: read from the game itself. The " ..
    "original game's rule: worked out by the game's server, so it isn't in the files; it's how WoW has always worked, " ..
    "and Classic servers use the same. Checked on Forever: matched against real characters. Patch notes: Forever's own. " ..
    "Estimate: the planner's best guess until real characters show the game's rule.", "KorkronPlannerFontDisableSmall", 0, 4)
  local game = KP.Sheet.GameNumbers()
  local rules = {}
  for _, f in ipairs(list) do
    if f.expr and inputs then
      L.text(ResultLine(f, KP.Sheet.Work(f.expr, inputs), f.game and game[f.game], inputs.level), "KorkronPlannerFontNormal", 0, 10)
      L.text(f.text, "KorkronPlannerFontHighlightSmall", INDENT, 2)
      L.text(YourNumbers(f.expr, inputs), "KorkronPlannerFontDisableSmall", INDENT, 2)
      if f.note then L.text(f.note, "KorkronPlannerFontDisableSmall", INDENT, 2) end
      Numbers(L, f, INDENT)
    elseif not f.expr then
      table.insert(rules, f)
    end
  end
  L.text("Rules of combat", "KorkronPlannerFontNormalLarge", 0, 18)
  for _, f in ipairs(rules) do
    L.text("|cffffd100" .. f.name .. ":|r " .. f.text, "KorkronPlannerFontHighlightSmall", 0, 6)
    Numbers(L, f, INDENT)
  end
  L.finish()
end
