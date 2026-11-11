-- Kor'kron Planner: the DPS tab of the /kp window. Your damage a second against a normal mob of your level, an elite of your
-- level and an elite 3 levels up, in each stance you know, worked out by Core/Sim.lua from your character sheet, talents and
-- weapons right now. Warriors only so far.
local _, KP = ...

local Pane = {}
KP.SimPane = Pane

local TARGETS = { { key = "same", label = "Normal", under = "your level" }, { key = "elite", label = "Elite", under = "your level" },
  { key = "elite3", label = "Elite", under = "3 levels up" } }
local STANCES = { { key = "battle", label = "Battle Stance" }, { key = "defensive", label = "Defensive Stance" },
  { key = "berserker", label = "Berserker Stance" } }
Pane.StanceName = {} -- "Battle Stance" for "battle" (the Stats tab names your stance too)
for _, stance in ipairs(STANCES) do Pane.StanceName[stance.key] = stance.label end
local LABEL_W, COLUMN_W, ROW, TOP = 170, 110, 26, -118
local BEST = "|cff40ff40%.1f|r"
local PLAIN = "%.1f"

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
  GameTooltip:AddLine(("A fight lasts about %d sec, with %.1f rage coming in a second."):format(math.floor(R.fightSec + 0.5), R.rageIncome), 0.6, 0.6, 0.6, true)
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
  pane.title = Text(pane, "GameFontNormalLarge", width - 10)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.note = Text(pane, "GameFontDisableSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
  local function Switch(label, x, notHit)
    local b = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    b:SetSize(130, 22)
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
    local header = Text(pane, "GameFontNormalSmall", COLUMN_W, "RIGHT")
    header:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COLUMN_W, TOP + 30)
    header:SetText(t.label .. "\n" .. t.under)
    pane.headers[i] = header
  end
  pane.rows = {}
  for r, stance in ipairs(STANCES) do
    local row = { stance = stance, cells = {} }
    local y = TOP - (r - 1) * ROW
    row.label = Text(pane, "GameFontHighlight", LABEL_W)
    row.label:SetPoint("TOPLEFT", 0, y)
    for i, t in ipairs(TARGETS) do
      local cell = CreateFrame("Button", nil, pane)
      cell:SetSize(COLUMN_W, ROW - 4)
      cell:SetPoint("TOPLEFT", LABEL_W + (i - 1) * COLUMN_W, y + 3)
      cell.text = Text(cell, "GameFontHighlightLarge", COLUMN_W, "RIGHT")
      cell.text:SetPoint("RIGHT", 0, 0)
      cell.target = t
      cell:SetScript("OnEnter", function(self) KP.Safe(ShowBreakdown, self) end)
      cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
      row.cells[i] = cell
    end
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "GameFontDisableSmall", width - 10)
  pane.foot:SetPoint("TOPLEFT", 0, TOP - #STANCES * ROW - 8)
  pane.foot:SetText("The green number is your best stance for that enemy. Hover a number for what it's made of.\n\n" ..
    "An average over a fight against one enemy, from your character sheet right now: buffs count while they're up, and buttons you " ..
    "press like Retaliation don't count. It assumes you press your abilities whenever they're ready and you have the rage.\n\n" ..
    "How sure this is: your rage, enemy armor up to level 33 and most of your abilities were measured in combat logs. Elites come " ..
    "from over 100 read at levels 16 to 33: 3 times the health, the same armor, hits a bit over twice as hard. The elite columns count " ..
    "your own Sunder Armor, 5 from the start and then kept up, so stack it early; on a normal mob it isn't worth the rage. Against " ..
    "enemies 3 levels above you, glancing blows still follow the original game's rules; one log saw more of them than that, so that " ..
    "column may read a little high. Set bonuses aren't counted.")
  return pane
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

function Pane.Refresh(pane)
  local _, class = UnitClass("player")
  if class ~= "WARRIOR" then
    pane.title:SetText("Warriors only, so far")
    pane.note:SetText("This tab works out your damage from your own character sheet. The other classes will come one at a time.")
    return SetGridShown(pane, false)
  end
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
  pane.note:SetText(not beingHit and "Someone else holds the enemy: no rage from being hit, and no Revenge."
    or sheet.shield and "The enemy is hitting you: that's your rage from being hit, your shield talents and Revenge."
    or "The enemy is hitting you: that's your rage from being hit and Revenge.")
  SetGridShown(pane, true)
  if beingHit then
    pane.tanking:LockHighlight()
    pane.notTanking:UnlockHighlight()
  else
    pane.notTanking:LockHighlight()
    pane.tanking:UnlockHighlight()
  end
  local best = {}
  for _, row in ipairs(pane.rows) do
    local key = row.stance.key
    local has = key == current or known[key]
    row.label:SetShown(has)
    row.label:SetText(row.stance.label .. (key == current and " (you)" or ""))
    for i, cell in ipairs(row.cells) do
      cell:SetShown(has)
      cell.result, cell.sunder = nil, nil
      if has then
        local ctx = { level = level, stance = key, ranks = ranks, sheet = KP.Sim.InStance(sheet, current, key),
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
  pane.shown = true
end
