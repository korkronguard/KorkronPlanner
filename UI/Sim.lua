-- Kor'kron Planner: the DPS tab of the /kp window. Your damage a second against a normal mob of your level, an elite of your
-- level and an elite 3 levels up, in each stance you know (one row for a class without stances), worked out by Core/Sim.lua from
-- your character sheet, talents and weapons right now. Warriors and Rogues so far.
local _, KP = ...

local Pane = {}
KP.SimPane = Pane

local TARGETS = { { key = "same", label = "Normal", under = "your level" }, { key = "elite", label = "Elite", under = "your level" },
  { key = "elite3", label = "Elite", under = "3 levels up" } }
local STANCES = { { key = "battle", label = "Battle Stance" }, { key = "defensive", label = "Defensive Stance" },
  { key = "berserker", label = "Berserker Stance" }, { key = "none", label = "Your rotation" } }
Pane.StanceName = {} -- "Battle Stance" for "battle" (the Stats tab names your stance too)
for _, stance in ipairs(STANCES) do Pane.StanceName[stance.key] = stance.label end
local LABEL_W, COLUMN_W, ROW, TOP = 170, 110, 26, -118
local BEST = "|cff40ff40%.1f|r"
local PLAIN = "%.1f"
-- under the numbers, by class
local FOOT = {
  WARRIOR = "The green number is your best stance for that enemy. Hover a number for what it's made of.\n\n" ..
    "An average over a fight against one enemy, from your character sheet right now: buffs count while they're up, and buttons you " ..
    "press like Retaliation don't count. It assumes you press your abilities whenever they're ready and you have the rage.\n\n" ..
    "How sure this is: your rage, enemy armor and health and most of your abilities were measured in combat logs. Elites have " ..
    "about 2.6 times a normal enemy's health, the same armor, and hit a bit over twice as hard. The elite columns count your own " ..
    "Sunder Armor, 5 from the start and then kept up, so stack it early; on a normal mob it isn't worth the rage. Against enemies " ..
    "3 levels above you, glancing blows still follow the original game's rules; one log saw more of them than that, so that " ..
    "column may read a little high. Set bonuses aren't counted.",
  ROGUE = "Hover a number for what it's made of.\n\n" ..
    "An average over a fight against one enemy, from your character sheet right now: buffs count while they're up. It keeps " ..
    "Slice and Dice up at the length that does most, spends the rest of your energy on your best builder to 5 combo points and " ..
    "Eviscerate, uses Shank whenever it's ready, counts Instant Poison on both weapons and averages Adrenaline Rush and Blade " ..
    "Flurry over their cooldowns. Backstab and Mutilate assume you're behind the enemy.\n\n" ..
    "How sure this is: enemy armor and health were measured in combat logs; a Rogue's own numbers haven't been checked against a " ..
    "Rogue's fights yet. Instant Poison's 20% chance a hit and Eviscerate's share of attack power are the original game's. Set " ..
    "bonuses aren't counted.",
}

local function Text(parent, font, width, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

local function ShowBreakdown(cell)
  local R = cell.result
  if not R then return end
  GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
  GameTooltip:AddLine(cell.title)
  local parts = {}
  for _, p in ipairs(R.parts) do table.insert(parts, p) end
  table.sort(parts, function(a, b) return a.dps > b.dps end)
  for _, p in ipairs(parts) do
    GameTooltip:AddDoubleLine(p.name, PLAIN:format(p.dps), 1, 1, 1, 1, 1, 1)
  end
  if cell.sunder then
    GameTooltip:AddLine(("Counts your own Sunder Armor: %d stacks from the start of the fight, then kept up, its rage paid out of these " ..
      "numbers. A normal enemy's number counts none."):format(KP.SimData.rules.sunderStacks), 0.4, 0.8, 1, true)
  end
  local power = R.rageIncome and ("%.1f rage coming in"):format(R.rageIncome) or ("%.1f energy"):format(R.energy)
  GameTooltip:AddLine(("A fight lasts about %d sec, with %s a second."):format(math.floor(R.fightSec + 0.5), power), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function SetGridShown(pane, shown)
  pane.tanking:SetShown(shown)
  pane.notTanking:SetShown(shown)
  pane.foot:SetShown(shown)
  for _, header in ipairs(pane.headers) do header:SetShown(shown) end
  for _, row in ipairs(pane.rows) do row.label:SetShown(shown) for _, cell in ipairs(row.cells) do cell:SetShown(shown) end end
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "KorkronPlannerFontNormalLarge", width - 10)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.note = Text(pane, "KorkronPlannerFontDisableSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
  local function Switch(label, x, notHit)
    local b = CreateFrame("Button", nil, pane)
    b:SetSize(130, 22)
    KP.Style.Button(b)
    b:SetPoint("TOPLEFT", x, -58)
    b:SetText(label)
    b:SetScript("OnClick", function()
      KP.Safe(function()
        KorkronPlannerCharDB.simNotHit = notHit
        Pane.Refresh(pane)
        KP.BagIcons.Refresh() -- the arrows judge gear by your stat weights, which follow this too
      end)
    end)
    return b
  end
  pane.tanking, pane.notTanking = Switch("I'm tanking it", 0, false), Switch("Someone else is", 134, true)
  pane.headers = {}
  for i, t in ipairs(TARGETS) do
    local header = Text(pane, "KorkronPlannerFontNormalSmall", COLUMN_W, "RIGHT")
    header:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COLUMN_W, TOP + 30)
    header:SetText(t.label .. "\n" .. t.under)
    pane.headers[i] = header
  end
  pane.rows = {} -- placed one under the other as they're shown (Place)
  for r, stance in ipairs(STANCES) do
    local row = { stance = stance, cells = {} }
    row.label = Text(pane, "KorkronPlannerFontHighlight", LABEL_W)
    for i, t in ipairs(TARGETS) do
      local cell = CreateFrame("Button", nil, pane)
      cell:SetSize(COLUMN_W, ROW - 4)
      cell.text = Text(cell, "KorkronPlannerFontHighlightLarge", COLUMN_W, "RIGHT")
      cell.text:SetPoint("RIGHT", 0, 0)
      cell.target = t
      cell:SetScript("OnEnter", function(self) KP.Safe(ShowBreakdown, self) end)
      cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.cells[i] = cell
    end
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "KorkronPlannerFontDisableSmall", width - 10)
  return pane
end

-- a shown row at height y
local function Place(row, y)
  row.label:ClearAllPoints()
  row.label:SetPoint("TOPLEFT", 0, y)
  for i, cell in ipairs(row.cells) do
    cell:ClearAllPoints()
    cell:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COLUMN_W, y + 3)
  end
end

-- the last numbers stay on screen while the game hides new ones
local function ShowHidden(pane)
  pane.title:SetText("Your damage a second")
  if pane.shown then
    pane.note:SetText("The game hides your numbers right now (in a fight or a dungeon?): these are from before. They update when it shows them again.")
    return
  end
  pane.note:SetText("The game hides your numbers right now (in a fight or a dungeon?). Open this tab again outside one.")
  SetGridShown(pane, false)
end

-- the line under the title: what being hit means for this class's numbers
local function HitNote(class, beingHit, shield)
  if class == "ROGUE" then
    return beingHit and "The enemy is attacking you: it faces you and parries some of your attacks."
      or "Someone else holds the enemy: you attack from behind, so it doesn't parry."
  end
  return not beingHit and "Someone else holds the enemy: no rage from being hit, and no Revenge."
    or shield and "The enemy is hitting you: that's your rage from being hit, your shield talents and Revenge."
    or "The enemy is hitting you: that's your rage from being hit and Revenge."
end

function Pane.Refresh(pane)
  local _, class = UnitClass("player")
  if not KP.Sim.Knows(class) then
    pane.title:SetText("Warriors and Rogues only, so far")
    pane.note:SetText("This tab works out your damage from your own character sheet. The other classes will come one at a time.")
    return SetGridShown(pane, false)
  end
  pane.foot:SetText(FOOT[class])
  local current, known = KP.Sim.Stances()
  local sheet, ranks = KP.Sim.Sheet(), KP.Sim.Ranks()
  if not (current and sheet and ranks) then return ShowHidden(pane) end
  if not sheet.mh then
    pane.title:SetText("Your damage a second")
    pane.note:SetText("Equip a weapon to see your damage.")
    pane.shown = false
    return SetGridShown(pane, false)
  end
  local level = UnitLevel("player")
  local beingHit = KorkronPlannerCharDB.simNotHit ~= true
  local targets = KP.Sim.Targets(level)
  pane.title:SetText("Your damage a second")
  pane.note:SetText(HitNote(class, beingHit, sheet.shield))
  SetGridShown(pane, true)
  KP.Style.SetButtonKind(pane.tanking, beingHit)
  KP.Style.SetButtonKind(pane.notTanking, not beingHit)
  local best, y = {}, TOP
  for _, row in ipairs(pane.rows) do
    local key = row.stance.key
    local has = key == current or known[key]
    row.label:SetShown(has)
    row.label:SetText(row.stance.label .. (key == current and key ~= "none" and " (you)" or ""))
    if has then
      Place(row, y)
      y = y - ROW
    end
    for i, cell in ipairs(row.cells) do
      cell:SetShown(has)
      cell.result, cell.sunder = nil, nil
      if has then
        local ctx = { class = class, level = level, stance = key, ranks = ranks, sheet = KP.Sim.InStance(sheet, current, key),
          target = targets[cell.target.key], beingHit = beingHit }
        cell.result, cell.sunder = KP.Sim.Compute(ctx), KP.Sim.CountsSunder(ctx)
        cell.title = ("%s, %s %s"):format(row.stance.label, cell.target.label:lower(), cell.target.under)
        best[i] = math.max(best[i] or 0, cell.result.dps)
      end
    end
  end
  for _, row in ipairs(pane.rows) do
    for i, cell in ipairs(row.cells) do
      if cell.result then cell.text:SetText((cell.result.dps == best[i] and BEST or PLAIN):format(cell.result.dps)) end
    end
  end
  pane.foot:ClearAllPoints()
  pane.foot:SetPoint("TOPLEFT", 0, y - 8)
  pane.shown = true
end
