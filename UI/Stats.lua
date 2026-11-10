-- Kor'kron Planner: the Stats tab of the /kp window. What 1 point of each stat adds for you. Where the addon has your class's
-- math (Core/StatWeights.lua: Warriors so far) it's from your own sheet, talents and weapons, against the enemy you choose,
-- with where each stat's worth turns (a cap). For the other classes it's the planner's numbers for your build with its best
-- gear at your level (Data/Weights.lua). The item tooltips and bag arrows judge gear by the same numbers.
local _, KP = ...

local Pane = {}
KP.StatsPane = Pane

local TARGETS = { { key = "same", label = "Normal enemy", text = "a normal enemy of your level" },
  { key = "elite", label = "Elite", text = "an elite of your level" },
  { key = "elite3", label = "Elite, 3 levels up", text = "an elite 3 levels above you" } }
local MAIN = { strength = true, agility = true, stamina = true, intellect = true, spirit = true }
local TURNS_OF = { v = "d", d = "d", e = "e" } -- which of a stat's turns goes with a measure (a damage dealer's v is its damage)
local ROWS, ROW_H, TOP = 15, 18, -142
local NAME_W, NUMBER_W, SHARE_W, COMING_X = 144, 76, 48, 354
local SMALL = 0.0005 -- a worth below this shows as nothing

-- a piece of text at a place in its parent; oneLine: a table cell, cut short rather than wrapped onto the row below
local function Text(parent, font, x, y, width, justify, oneLine)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWidth(width)
  if oneLine then fs:SetWordWrap(false) end
  fs:SetPoint("TOPLEFT", x, y)
  return fs
end

local function Worth(x)
  return math.abs(x) >= SMALL and KP.Upgrade.Number(x) or nil
end

-- a turn's place in whole points (it's worked out to a fraction of one)
local function Points(x)
  return math.floor(x + 0.5)
end

-- "47 more, then +0.021" for the nearest turn of a stat's worth, "capped: 12 to spare" past one; nil when there's none in reach
local function Coming(found)
  if not found then return nil end
  if found.spare then return ("capped: %d to spare"):format(Points(found.spare)) end
  local turn = found.turns[1]
  return turn and ("%d more, then %s"):format(Points(turn.at), Worth(turn.worth) or "nothing") or nil
end

-- the same in a sentence, for the row's tooltip
local function ComingLine(found, measure)
  if found.spare then
    return ("%s: more adds nothing. You have %d more than you need."):format(measure, Points(found.spare))
  end
  local first, second = found.turns[1], found.turns[2]
  if not first then return nil end
  local text = ("%s: that holds for the next %d points, then each adds %s"):format(measure, Points(first.at), Worth(first.worth) or "nothing")
  if second then
    text = text .. (" for %d more, then %s"):format(Points(second.at) - Points(first.at), Worth(second.worth) or "nothing")
  end
  return text .. "."
end

-- what hit has to reach against the enemy your weights are measured on
local function HitLine(W)
  local caps, sheet = KP.Sim.HitCaps(W.ctx.target), W.ctx.sheet
  local needs = ("your abilities stop missing at %s%% hit"):format(KP.Num(caps.melee, 1))
  if sheet.oh then needs = needs .. (", your white swings with two weapons at %s%%"):format(KP.Num(caps.dualWhite, 1)) end
  return ("Against this enemy %s. You have %s%%."):format(needs, KP.Num(sheet.hit, 1))
end

local function ShowRow(row)
  local stat, pane = row.stat, row.pane
  if not stat then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(stat.name)
  GameTooltip:AddLine("1 point adds " .. (KP.Upgrade.Describe(stat.value, pane.role, SMALL) or "nothing your build counts"), 1, 1, 1, true)
  local turns = pane.turns and pane.turns[stat.key]
  for _, m in ipairs(pane.measures) do
    local found = turns and turns[TURNS_OF[m[1]]]
    local line = found and ComingLine(found, (m[2]:gsub("^%l", string.upper)))
    if line then GameTooltip:AddLine(line, 0.4, 0.8, 1, true) end
  end
  if stat.key == "hit" and pane.live then GameTooltip:AddLine(HitLine(pane.live), 0.6, 0.6, 0.6, true) end
  if not pane.live then
    GameTooltip:AddLine("With the planner's best gear for your level on, not the gear you wear.", 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "GameFontNormalLarge", 0, 0, width - 10)
  pane.note = Text(pane, "GameFontDisableSmall", 0, -20, width - 10)
  local function Choice(label, x, y, w, onClick)
    local b = CreateFrame("Button", nil, pane, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", function()
      KP.Safe(function()
        onClick()
        KP.Window.Refresh()
        KP.BagIcons.Refresh() -- the arrows judge gear by these weights
      end)
    end)
    return b
  end
  pane.targets = {}
  for i, t in ipairs(TARGETS) do
    pane.targets[t.key] = Choice(t.label, (i - 1) * 134, -62, 130, function() KorkronPlannerCharDB.statTarget = t.key end)
  end
  pane.tanking = Choice("I'm tanking it", 0, -88, 130, function() KorkronPlannerCharDB.simNotHit = false end)
  pane.notTanking = Choice("Someone else is", 134, -88, 130, function() KorkronPlannerCharDB.simNotHit = true end)
  pane.heads = { first = Text(pane, "GameFontNormalSmall", NAME_W, TOP + 18, NUMBER_W, "RIGHT"),
    second = Text(pane, "GameFontNormalSmall", NAME_W + NUMBER_W, TOP + 18, NUMBER_W, "RIGHT"),
    share = Text(pane, "GameFontNormalSmall", NAME_W + 2 * NUMBER_W, TOP + 18, SHARE_W, "RIGHT"),
    coming = Text(pane, "GameFontNormalSmall", COMING_X, TOP + 18, width - COMING_X) }
  pane.heads.coming:SetText("Coming up")
  pane.rows = {}
  for r = 1, ROWS do
    local row = CreateFrame("Button", nil, pane)
    row:SetSize(width, ROW_H)
    row:SetPoint("TOPLEFT", 0, TOP - (r - 1) * ROW_H)
    row.pane = pane
    row.name = Text(row, "GameFontHighlight", 0, -2, NAME_W, "LEFT", true)
    row.first = Text(row, "GameFontHighlight", NAME_W, -2, NUMBER_W, "RIGHT", true)
    row.second = Text(row, "GameFontHighlight", NAME_W + NUMBER_W, -2, NUMBER_W, "RIGHT", true)
    row.share = Text(row, "GameFontDisableSmall", NAME_W + 2 * NUMBER_W, -3, SHARE_W, "RIGHT", true)
    row.coming = Text(row, "GameFontHighlightSmall", COMING_X, -3, width - COMING_X, "LEFT", true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowRow, self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "GameFontDisableSmall", 0, TOP - ROWS * ROW_H - 6, width - 10)
  return pane
end

local function SetShown(pane, controls, list)
  for _, b in pairs(pane.targets) do b:SetShown(controls) end
  pane.tanking:SetShown(controls)
  pane.notTanking:SetShown(controls)
  for _, head in pairs(pane.heads) do head:SetShown(list) end
  for _, row in ipairs(pane.rows) do row:SetShown(list) end
  pane.foot:SetShown(list)
end

-- The stats that count, biggest first in the role's first measure: { key, name, value = { v, e, d } per point }, and the
-- main stat they're compared with (nil when none counts)
local function Stats(W, measures)
  local first, second = measures[1][1], measures[2][1]
  local stats, main = {}, nil
  for _, s in ipairs(KP.Upgrade.STATS) do
    local value = KP.Upgrade.Value(W, s[1], 1)
    if math.abs(value[first]) >= SMALL or math.abs(value[second]) >= SMALL then
      local stat = { key = s[1], name = s[2]:gsub("^%l", string.upper), value = value }
      table.insert(stats, stat)
      if MAIN[s[1]] and value[first] >= SMALL and (not main or value[first] > main.value[first]) then main = stat end
    end
  end
  table.sort(stats, function(a, b)
    if a.value[first] ~= b.value[first] then return a.value[first] > b.value[first] end
    if a.value[second] ~= b.value[second] then return a.value[second] > b.value[second] end
    return a.name < b.name
  end)
  return stats, main
end

local function ShowList(pane, W)
  local measures = pane.measures
  local first, second = measures[1][1], measures[2][1]
  local stats, main = Stats(W, measures)
  pane.heads.first:SetText(measures[1][4])
  pane.heads.second:SetText(measures[2][4])
  pane.heads.share:SetText(main and "vs " .. main.name:sub(1, 3) or "")
  pane.heads.coming:SetShown(pane.turns ~= nil)
  for r, row in ipairs(pane.rows) do
    local stat = stats[r]
    row.stat = stat
    row:SetShown(stat ~= nil)
    if stat then
      row.name:SetText(stat.name)
      row.first:SetText(Worth(stat.value[first]) or "")
      row.second:SetText(Worth(stat.value[second]) or "")
      row.share:SetText(main and Worth(stat.value[first]) and ("%.2f"):format(stat.value[first] / main.value[first]) or "")
      local turns = pane.turns and pane.turns[stat.key]
      local coming = turns and Coming(turns[TURNS_OF[first]])
      if not coming and turns and TURNS_OF[second] ~= TURNS_OF[first] then
        coming = Coming(turns[TURNS_OF[second]])
        coming = coming and measures[2][4] .. ": " .. coming
      end
      row.coming:SetText(coming or "")
    end
  end
end

-- build: the chosen build (nil when none): its role decides which number comes first
function Pane.Refresh(pane, build)
  KP.StatWeights.Stale() -- a buff changes your sheet with no event the addon follows: showing the tab reads it again
  local role = build and build.role or "dps"
  local target = KP.StatWeights.Target(build)
  local knows = KP.StatWeights.Knows()
  local W, current = KP.StatWeights.Live(role, target)
  pane.role, pane.measures = role, KP.Upgrade.MEASURES[role] or KP.Upgrade.MEASURES.dps
  pane.live, pane.turns = W, W and KP.StatWeights.Turns(W) or nil
  pane.title:SetText("What each stat is worth to you")
  if W then
    local enemy
    for _, t in ipairs(TARGETS) do
      if t.key == target then enemy = t.text end
      if t.key == target then pane.targets[t.key]:LockHighlight() else pane.targets[t.key]:UnlockHighlight() end
    end
    local hit = KorkronPlannerCharDB.simNotHit ~= true
    if hit then pane.tanking:LockHighlight() pane.notTanking:UnlockHighlight() else pane.notTanking:LockHighlight() pane.tanking:UnlockHighlight() end
    pane.note:SetText(("From your own character sheet, talents and weapons in %s, against %s %s.%s%s"):format(
      KP.SimPane.StanceName[W.stance], enemy, hit and "that's hitting you" or "that someone else is tanking",
      build and "" or " No planner build chosen: counted as a damage dealer.",
      current and "" or " The game hides your numbers right now (in a fight or a dungeon?): these are from before."))
    pane.foot:SetText("Each number is what 1 more point adds for you right now, by the DPS tab's math. Your item tooltips and bag " ..
      "arrows judge gear by these. \"Coming up\" is where a stat's worth changes, like a cap: hover a stat for more. Buffs count " ..
      "while they're up. Procs, \"Use:\" effects and set bonuses aren't counted.")
    SetShown(pane, true, true)
    return ShowList(pane, W)
  end
  local planned = build and build.key and KP.Build.ForLevel(KP.Weights, build.key, UnitLevel("player"))
  if not planned then
    pane.note:SetText(knows and "The game hides your numbers right now (in a fight or a dungeon?), or you have no weapon in your hand. " ..
      "Open this tab again outside one." or "Choose one of the planner's builds on the left to see what each stat is worth to it.")
    return SetShown(pane, knows, false)
  end
  pane.note:SetText(("The planner's numbers for %s with its best gear at level %d, not for the gear you wear. %s"):format(
    build.name:gsub(" %b()", ""), planned.level, knows and "The game hides your own numbers right now (in a fight or a dungeon?)."
      or "The addon works these out from your own gear for Warriors only, so far."))
  pane.foot:SetText("Each number is what 1 more point adds for that build. Your item tooltips and bag arrows judge gear by these. " ..
    "Procs, \"Use:\" effects and set bonuses aren't counted.")
  SetShown(pane, false, true)
  ShowList(pane, planned)
end
