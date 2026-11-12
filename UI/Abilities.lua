-- Kor'kron Planner: the Abilities tab of the /kp window. Every attack you have side by side, worked out by Core/Sim.lua (Sim.Grid)
-- from your character sheet, talents and weapons right now, against 1 to 5 enemies: rage, cooldown, chance to land and to crit,
-- damage per press, the biggest hit, bleed, damage per rage and per second, threat. Click a column's name to sort by it (again:
-- the other way). Warriors and Rogues so far (a Rogue's columns say energy, its openers "from Stealth"). It takes the whole width
-- of the window: the build list steps aside (UI/Window.lua).
local _, KP = ...

local Pane = {}
KP.AbilitiesPane = Pane

local ROW, TOP, MAX_ROWS = 18, -100, 19
local CLASSES = { WARRIOR = true, ROGUE = true } -- the classes Core/Sim.lua works out attacks for
local ENEMY_COUNTS = { 1, 2, 3, 4, 5 } -- the last shows as "5+": no attack hits more than 4
local ENEMIES = { { key = "same", label = "Normal" }, { key = "elite", label = "Elite" }, { key = "elite3", label = "Elite +3" } }
local STANCE = { battle = "Battle", defensive = "Defensive", berserker = "Berserker" }

local function Whole(v) return ("%.0f"):format(v) end
local function Tenth(v) return ("%.1f"):format(v) end
local function Rage(v) return v == math.floor(v) and ("%d"):format(v) or Tenth(v) end
local function Seconds(ms) return ms > 0 and ("%gs"):format(ms / 1000) or "-" end
local function Percent(v) return ("%.0f%%"):format(v) end

-- key: the row's field (Core/Sim.lua's Sim.Grid); show: its text (nothing shown as "-"); tip: what the header's tooltip says
local COLUMNS = {
  { key = "name", label = "Ability", width = 150, tip = "Your attacks at your level. One you can't use in the stance you're in is worked out " ..
    "in one you know that allows it (named after it)." },
  { key = "rage", label = "Rage", width = 40, show = Rage, tip = "What it costs, with your talents." },
  { key = "cdMs", label = "Cooldown", width = 58, show = Seconds, tip = "How long until you can use it again." },
  { key = "land", label = "Hit", width = 40, show = Percent, tip = "The chance it lands: not missed, dodged or parried (an enemy facing " ..
    "you parries; one hitting someone else doesn't)." },
  { key = "crit", label = "Crit", width = 40, show = Percent, tip = "The chance a hit that lands is a critical hit." },
  { key = "perPress", label = "Per press", width = 60, show = Whole, tip = "Its damage each time you press it, on all the enemies it hits, " ..
    "counting misses, dodges, parries and crits, after their armor." },
  { key = "biggest", label = "Biggest", width = 54, show = Whole, tip = "Its biggest single hit on one enemy: a crit at the top of its " ..
    "damage range. Execute's with all 100 rage." },
  { key = "bleed", label = "Bleed", width = 48, show = Whole, tip = "Damage over time (Rend, Garrote, Rupture), on all the enemies it hits, counting misses." },
  { key = "perRage", label = "Per rage", width = 54, show = Tenth, tip = "Per press and bleed together, for each point of rage it costs." },
  { key = "dps", label = "DPS", width = 48, show = Tenth, tip = "Damage a second if you press it every time you can: on its cooldown, " ..
    "a bleed as it runs out, at most once a global cooldown (1.5 sec). Heroic Strike and Cleave every swing, less the white hit " ..
    "they replace. Execute only works below 20% health; Revenge and Overpower when they light up." },
  { key = "threat", label = "Threat", width = 54, show = Whole, tip = "Its damage times your stance's and talents' threat " ..
    "(Defensive Stance and Defiance). A + means the game adds more threat of its own that the planner can't see (\"a high " ..
    "amount of threat\"). Sunder Armor's is its own threat, no damage." },
  { key = "threatPerRage", label = "Threat/rage", width = 66, show = Tenth, tip = "Threat for each point of rage it costs." },
  { key = "hits", label = "Targets", width = 50, show = Whole, tip = "How many of the enemies it hits: Thunder Clap and Whirlwind up " ..
    "to 4, Cleave 2, the rest 1 (the game's data)." },
}

local function Settings() return KorkronPlannerCharDB.abilities end

-- a column's words for your class's power: "rage" (the words as written) or "energy"
local function Worded(text, power)
  if power ~= "energy" then return text end
  return (text:gsub("Rage", "Energy"):gsub("rage", "energy"))
end

local function Text(parent, font, width, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

local function Tip(owner, title, text)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(title)
  GameTooltip:AddLine(text, 1, 1, 1, true)
  GameTooltip:Show()
end

local function ShowRowTip(row)
  local r = row.data
  if not r then return end
  local lines = {}
  if r.stance then table.insert(lines, ("Worked out in %s Stance: you can't use it in the one you're in."):format(STANCE[r.stance])) end
  if r.name == "Execute" then table.insert(lines, "Only on an enemy at 20% health or less. Each extra point of rage adds to it.") end
  if r.name == "Victory Rush" then table.insert(lines, "Only for 20 sec after you kill an enemy that gives experience.") end
  if r.name == "Revenge" then table.insert(lines, "Only after you block, dodge or parry.") end
  if r.name == "Overpower" then table.insert(lines, "Only after the enemy dodges.") end
  if r.name == "Shield Slam" then table.insert(lines, "Adds twice your Block Value (a combat log read it).") end
  if r.name == "Whirlwind" then table.insert(lines, "Strikes with your off-hand weapon too, at half damage.") end
  if r.stealth then table.insert(lines, "Only from Stealth: an opener.") end
  if r.name == "Eviscerate" or r.name == "Rupture" then table.insert(lines, "At 5 combo points.") end
  if r.name == "Riposte" then table.insert(lines, "Only after you parry.") end
  if r.moreThreat then table.insert(lines, "The game adds threat of its own that the planner can't see.") end
  if #lines == 0 then return end
  Tip(row, r.name, table.concat(lines, "\n"))
end

-- a row of small buttons, one per choice, after a label that takes labelWidth: set(choice.key) when clicked. Returns them by key,
-- and where the next row of them starts
local function Choices(pane, list, x, label, labelWidth, width, set)
  local title = Text(pane, "GameFontNormalSmall", labelWidth)
  title:SetPoint("TOPLEFT", x, -52)
  title:SetText(label)
  local buttons = {}
  x = x + labelWidth
  for i, choice in ipairs(list) do
    local b = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x + (i - 1) * (width + 2), -46)
    b:SetText(choice.label)
    b:SetScript("OnClick", function()
      KP.Safe(function()
        set(choice.key)
        Pane.Refresh(pane)
      end)
    end)
    buttons[choice.key] = b
  end
  return buttons, x + #list * (width + 2) + 14
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "GameFontNormalLarge", width - 10)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.note = Text(pane, "GameFontHighlightSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -4)
  local counts = {}
  for i, n in ipairs(ENEMY_COUNTS) do counts[i] = { key = n, label = i == #ENEMY_COUNTS and n .. "+" or tostring(n) } end
  local x
  pane.counts, x = Choices(pane, counts, 0, "Enemies", 54, 34, function(n) Settings().targets = n end)
  pane.enemies, x = Choices(pane, ENEMIES, x, "Each one", 58, 70, function(key) Settings().enemy = key end)
  -- the tanking choice is the DPS tab's and the Stats tab's too
  local hit = Choices(pane, { { key = false, label = "I'm tanking it" }, { key = true, label = "Someone else is" } }, x, "", 0, 116,
    function(notHit)
      KorkronPlannerCharDB.simNotHit = notHit
      KP.BagIcons.Refresh() -- the arrows judge gear by your stat weights, which follow this too
    end)
  pane.tanking, pane.notTanking = hit[false], hit[true]
  pane.headers = {}
  x = 0
  for i, c in ipairs(COLUMNS) do
    local h = CreateFrame("Button", nil, pane)
    h:SetSize(c.width, 20)
    h:SetPoint("TOPLEFT", x, TOP + 22)
    h.text = Text(h, "GameFontNormalSmall", c.width - 4, i == 1 and "LEFT" or "RIGHT")
    h.text:SetPoint(i == 1 and "LEFT" or "RIGHT", i == 1 and 4 or -2, 0)
    h.column = c
    h:SetScript("OnClick", function()
      KP.Safe(function()
        local s = Settings()
        if s.sort == c.key then s.desc = not s.desc else s.sort, s.desc = c.key, c.key ~= "name" end
        Pane.Refresh(pane)
      end)
    end)
    h:SetScript("OnEnter", function(self)
      KP.Safe(Tip, self, Worded(c.label, pane.power), Worded(c.tip, pane.power) .. "\n\nClick to sort by it, again for the other way.")
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.headers[i] = h
    x = x + c.width
  end
  pane.rows = {}
  for r = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, pane)
    row:SetSize(x, ROW)
    row:SetPoint("TOPLEFT", 0, TOP - (r - 1) * ROW)
    if r % 2 == 0 then -- every other row shaded, so the eye can follow a line across
      local shade = row:CreateTexture(nil, "BACKGROUND")
      shade:SetAllPoints()
      shade:SetColorTexture(1, 1, 1, 0.05)
    end
    row.cells = {}
    local cx = 0
    for i, c in ipairs(COLUMNS) do
      local cell = Text(row, "GameFontHighlightSmall", c.width - 6, i == 1 and "LEFT" or "RIGHT")
      cell:SetPoint("LEFT", cx + (i == 1 and 4 or 0), 0)
      row.cells[i] = cell
      cx = cx + c.width
    end
    row:SetScript("OnEnter", function(self) KP.Safe(ShowRowTip, self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "GameFontDisableSmall", width - 10)
  pane.foot:SetPoint("TOPLEFT", 0, TOP - MAX_ROWS * ROW - 6)
  return pane
end

local function SetGridShown(pane, shown)
  for _, h in ipairs(pane.headers) do h:SetShown(shown) end
  if not shown then
    for _, row in ipairs(pane.rows) do row:Hide() end
  end
  pane.foot:SetShown(shown)
end

local function Highlight(buttons, chosen)
  for key, b in pairs(buttons) do
    if key == chosen then b:LockHighlight() else b:UnlockHighlight() end
  end
end

-- nothing (shown as "-") sorts last either way
local function Sorted(rows, key, desc)
  table.sort(rows, function(a, b)
    local x, y = a[key], b[key]
    if x == nil or y == nil or x == y then
      if (x == nil) ~= (y == nil) then return y == nil end
      return a.name < b.name
    end
    if desc then return x > y end
    return x < y
  end)
  return rows
end

-- the columns where 0 is a real answer (no rage, no cooldown, no chance), shown as one; elsewhere 0 means it doesn't do that: "-"
local ZERO_SHOWN = { rage = true, cdMs = true, land = true, crit = true }

local function Cell(column, row)
  if column.key == "name" then
    local tag = row.stance and STANCE[row.stance] or row.stealth and "from Stealth"
    return row.name .. (tag and (" |cff999999(" .. tag .. ")|r") or "")
  end
  local v = row[column.key]
  if v == nil or (v == 0 and not ZERO_SHOWN[column.key]) then return "-" end
  local text = column.show(v)
  if column.key == "threat" and row.moreThreat then text = text .. "+" end
  return text
end

function Pane.Refresh(pane)
  local _, class = UnitClass("player")
  if not CLASSES[class] then
    pane.title:SetText("Warriors and Rogues only, so far")
    pane.note:SetText("This tab works out every attack from your own character sheet. The other classes will come one at a time.")
    return SetGridShown(pane, false)
  end
  local s = Settings()
  pane.power = KP.SimData[class].power
  -- a Rogue has no stance: its attacks are worked out as they are ("none")
  local current, known
  if class == "WARRIOR" then current, known = KP.Sim.Stances() else current, known = "none", {} end
  local sheet, ranks = KP.Sim.Sheet(), KP.Sim.Ranks()
  pane.title:SetText("Your attacks")
  if not (current and sheet and ranks) then
    pane.note:SetText(pane.shown and "The game hides your numbers right now (in a fight or a dungeon?): these are from before."
      or "The game hides your numbers right now (in a fight or a dungeon?). Open this tab again outside one.")
    if not pane.shown then SetGridShown(pane, false) end
    return
  end
  if not sheet.mh then
    pane.note:SetText("Equip a weapon to see your attacks.")
    pane.shown = false
    return SetGridShown(pane, false)
  end
  local level, notHit = UnitLevel("player"), KorkronPlannerCharDB.simNotHit == true
  local base = { class = class, level = level, ranks = ranks, sheet = sheet, target = KP.Sim.Targets(level)[s.enemy], beingHit = not notHit }
  local rows = Sorted(KP.Sim.Grid(base, current, known, s.targets), s.sort, s.desc)
  pane.note:SetText((STANCE[current] and ("In " .. STANCE[current] .. " Stance, from") or "From") .. " your character sheet right now. " ..
    "Hover a column's name for what it means, an attack for when it works.")
  Highlight(pane.counts, s.targets)
  Highlight(pane.enemies, s.enemy)
  Highlight({ [false] = pane.tanking, [true] = pane.notTanking }, notHit)
  SetGridShown(pane, true)
  for i, h in ipairs(pane.headers) do
    local c = COLUMNS[i]
    h.text:SetText(Worded(c.label, pane.power) .. (s.sort == c.key and (s.desc and " v" or " ^") or ""))
  end
  for r, row in ipairs(pane.rows) do
    local data = rows[r]
    row.data = data
    row:SetShown(data ~= nil)
    if data then
      for i, c in ipairs(COLUMNS) do row.cells[i]:SetText(Cell(c, data)) end
    end
  end
  pane.foot:SetText("Averages, not one fight: buffs count while they're up. Enemy armor, health and hits by level come from combat logs. " ..
    "Threat with a + has more the game adds that can't be seen.")
  pane.shown = true
end
