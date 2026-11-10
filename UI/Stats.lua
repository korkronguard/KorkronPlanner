-- Kor'kron Planner: the Stats tab of the /kp window. For each of your build's two numbers (staying alive and damage, or
-- healing), the stats that count: how much of each you have, what 1 more point adds, how that compares with your main stat,
-- and how far a cap is. Where the addon has your class's math (Core/StatWeights.lua: Warriors so far) it's from your own
-- sheet, talents and weapons, against the enemy you choose. For the other classes it's the planner's numbers for your build
-- with its best gear at your level (Data/Weights.lua). The item tooltips and bag arrows judge gear by the same numbers.
local _, KP = ...

local Pane = {}
KP.StatsPane = Pane

local TARGETS = { { key = "same", label = "Normal enemy", text = "a normal enemy of your level" },
  { key = "elite", label = "Elite", text = "an elite of your level" },
  { key = "elite3", label = "Elite, 3 levels up", text = "an elite 3 levels above you" } }
local MAIN = { strength = true, agility = true, stamina = true, intellect = true, spirit = true }
local WEAPON = { mainHand = "Main-hand weapon", offHand = "Off-hand weapon", ranged = "Ranged weapon" }
local TURNS_OF = { v = "d", d = "d", e = "e" } -- which of a stat's turns goes with a measure (a damage dealer's v is its damage)
-- A section per number of the build, by the short name UI/Upgrade.lua's MEASURES give it: its heading, your own total in
-- words, what a point adds in words, and what the number is
local SECTION = {
  ["eff. HP"] = { title = "Staying alive", total = "your effective health is %s", unit = "effective health",
    about = "Effective health is how much damage you can take before you die: your health, and what your armor, dodge, parry " ..
      "and block keep off you, measured against a raid boss." },
  DPS = { title = "Damage", total = "you do %s a second", unit = "damage a second",
    about = "Your damage a second against this enemy, pressing your abilities whenever they're ready and you have the rage: " ..
      "the DPS tab's math. Buffs count while they're up." },
  HPS = { title = "Healing", total = "you heal %s a second", unit = "healing a second",
    about = "Your healing a second with the mana you have, by the planner's math." },
}
local FOR_UNIT = "%s: what a point adds to your %s" -- a section's heading when the numbers are the planner's, not your own
local ROWS, ROW_H, TOP = 18, 18, -122
local NAME_W, HAVE_W, ADDS_W, SAME_W, CAP_X = 150, 72, 62, 92, 390 -- the columns, left to right (the last runs to the edge)
local CONTROLS_X = 116 -- where the two rows of buttons start, after their labels
local SMALL = 0.0005 -- a worth below this shows as nothing
local SHARE = 0.05 -- a stat that adds less than this share of its section's best is left out
local CHUNK = { armor = 12, bonusArmor = 12 } -- armor comes in hundreds on an item where other stats come in tens
-- a stat that's another under a second name on items: left out when a point of it is worth the same
local TWIN = { bonusArmor = "armor", spellDamage = "spellPower" }
-- the chance a rating feeds, in words (Core/Sheet.lua's Have gives it in %)
local CHANCE = { crit = "your crit chance is %s%%", hit = "with your talents that's %s%% more hit", dodge = "your dodge chance is %s%%",
  parry = "your parry chance is %s%%", block = "your block chance is %s%%" }

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

-- "1,759", "61.3": a whole number with its thousands apart, a small one with a decimal
local function Amount(x)
  if x < 100 then return KP.Num(x, 1) end
  local text = ("%d"):format(x + 0.5):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (text:gsub("^,", ""))
end

-- How much of a stat you have, as the list shows it: "147", "31 (6.2%)" for a rating and the chance it feeds, "44.5 a sec"
-- for a weapon; "" when the game has no number for it or hides it
local function Have(key)
  local amount, chance = KP.Sheet.Have(key)
  if not amount then return "" end
  if WEAPON[key] then return Amount(amount) .. " a sec" end
  return Amount(amount) .. (chance and (" (%s%%)"):format(KP.Num(chance, 1)) or "")
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
local function ComingLine(found)
  if found.spare then return ("More adds nothing: you have %d more than you need."):format(Points(found.spare)) end
  local first, second = found.turns[1], found.turns[2]
  if not first then return nil end
  local text = ("That holds for the next %d points, then each adds %s"):format(Points(first.at), Worth(first.worth) or "nothing")
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

-- a line of the list under the mouse: what a section's number is, or a stat in full
local function ShowRow(row)
  local line, pane = row.line, row.pane
  if not line then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if line.head then
    GameTooltip:AddLine(line.section.title)
    GameTooltip:AddLine(line.section.about, 1, 1, 1, true)
    return GameTooltip:Show()
  end
  local unit = line.section.unit
  GameTooltip:AddLine(line.name)
  GameTooltip:AddLine((WEAPON[line.key] and "Each 1 more damage a second on it adds %s %s." or "1 more point adds %s %s."):format(
    Worth(line.worth), unit), 1, 1, 1, true)
  local amount, chance = KP.Sheet.Have(line.key)
  if amount then
    GameTooltip:AddLine(("You have %s%s."):format(Amount(amount) .. (WEAPON[line.key] and " damage a second on it" or ""),
      chance and "; " .. CHANCE[line.key]:format(KP.Num(chance, 2)) or ""), 1, 1, 1, true)
  end
  if line.same then
    GameTooltip:AddLine(("That's worth as much %s as %s %s."):format(unit, KP.Num(line.same, 2), line.main.name), 1, 1, 1, true)
  end
  if CHUNK[line.key] then GameTooltip:AddLine("Armor comes in hundreds on an item, so it adds up.", 1, 1, 1, true) end
  local turns = pane.turns and pane.turns[line.key]
  local found = turns and turns[TURNS_OF[line.measure]]
  local coming = found and ComingLine(found)
  if coming then GameTooltip:AddLine(coming, 0.4, 0.8, 1, true) end
  if line.key == "hit" and pane.live then GameTooltip:AddLine(HitLine(pane.live), 0.6, 0.6, 0.6, true) end
  if not pane.live then
    GameTooltip:AddLine("With the planner's best gear for your level on, not the gear you wear.", 0.6, 0.6, 0.6, true)
  end
  GameTooltip:Show()
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "GameFontNormalLarge", 0, 0, width - 10)
  pane.note = Text(pane, "GameFontHighlightSmall", 0, -20, width - 10)
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
  pane.against = Text(pane, "GameFontNormalSmall", 0, -52, CONTROLS_X)
  pane.against:SetText("Measured against")
  pane.targets = {}
  for i, t in ipairs(TARGETS) do
    pane.targets[t.key] = Choice(t.label, CONTROLS_X + (i - 1) * 134, -46, 130, function() KorkronPlannerCharDB.statTarget = t.key end)
  end
  pane.who = Text(pane, "GameFontNormalSmall", 0, -78, CONTROLS_X)
  pane.who:SetText("Who's tanking it")
  pane.tanking = Choice("I'm tanking it", CONTROLS_X, -72, 130, function() KorkronPlannerCharDB.simNotHit = false end)
  pane.notTanking = Choice("Someone else is", CONTROLS_X + 134, -72, 130, function() KorkronPlannerCharDB.simNotHit = true end)
  local haveX, addsX, sameX = NAME_W, NAME_W + HAVE_W, NAME_W + HAVE_W + ADDS_W + 12
  pane.heads = { have = Text(pane, "GameFontNormalSmall", haveX, TOP + 16, HAVE_W, "RIGHT"),
    adds = Text(pane, "GameFontNormalSmall", addsX, TOP + 16, ADDS_W, "RIGHT"),
    same = Text(pane, "GameFontNormalSmall", sameX, TOP + 16, SAME_W),
    cap = Text(pane, "GameFontNormalSmall", CAP_X, TOP + 16, width - CAP_X) }
  pane.heads.have:SetText("You have")
  pane.heads.adds:SetText("+1 adds")
  pane.heads.same:SetText("Same worth as")
  pane.heads.cap:SetText("Until a cap")
  pane.rows = {}
  for r = 1, ROWS do
    local row = CreateFrame("Button", nil, pane)
    row:SetSize(width, ROW_H)
    row:SetPoint("TOPLEFT", 0, TOP - (r - 1) * ROW_H)
    row.pane = pane
    row.shade = row:CreateTexture(nil, "BACKGROUND") -- every other stat, so the eye can follow a line across
    row.shade:SetAllPoints()
    row.shade:SetColorTexture(1, 1, 1, 0.05)
    row.head = Text(row, "GameFontNormal", 0, -3, width, "LEFT", true)
    row.name = Text(row, "GameFontHighlight", 8, -2, NAME_W - 8, "LEFT", true)
    row.have = Text(row, "GameFontHighlight", haveX, -2, HAVE_W, "RIGHT", true)
    row.adds = Text(row, "GameFontHighlight", addsX, -2, ADDS_W, "RIGHT", true)
    row.same = Text(row, "GameFontHighlightSmall", sameX, -3, SAME_W, "LEFT", true)
    row.cap = Text(row, "GameFontHighlightSmall", CAP_X, -3, width - CAP_X, "LEFT", true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowRow, self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "GameFontDisableSmall", 0, TOP - ROWS * ROW_H - 4, width - 10)
  pane.foot:SetText("Hover a line for more. Your item tooltips and bag arrows judge gear by these numbers. Procs, \"Use:\" " ..
    "effects and set bonuses aren't counted.")
  return pane
end

local function SetShown(pane, controls, list)
  pane.against:SetShown(controls)
  pane.who:SetShown(controls)
  for _, b in pairs(pane.targets) do b:SetShown(controls) end
  pane.tanking:SetShown(controls)
  pane.notTanking:SetShown(controls)
  for _, head in pairs(pane.heads) do head:SetShown(list) end
  for _, row in ipairs(pane.rows) do row:SetShown(list) end
  pane.foot:SetShown(list)
end

-- The stats that count for one of the build's numbers (m: its entry in UI/Upgrade.lua's MEASURES), most per point first:
-- { key, name, measure, section, worth = what 1 point adds, main = the section's main stat, same = how many points of it a
-- point of this is worth (nil for the main stat itself) }. A stat that adds next to nothing beside the others is left out,
-- and one that's another stat's twin (bonus armor) when it's worth the same.
local function Section(W, m)
  local stats, main, top = {}, nil, 0
  for _, s in ipairs(KP.Upgrade.STATS) do
    local key = s[1]
    local worth = KP.Upgrade.Value(W, key, 1)[m[1]]
    if worth >= SMALL then
      local stat = { key = key, name = WEAPON[key] or s[2], measure = m[1], section = SECTION[m[4]], worth = worth }
      table.insert(stats, stat)
      if not WEAPON[key] then top = math.max(top, worth * (CHUNK[key] or 1)) end
      if MAIN[key] and (not main or worth > main.worth) then main = stat end
    end
  end
  local kept = {}
  for _, stat in ipairs(stats) do
    local twin = TWIN[stat.key] and Worth(KP.Upgrade.Value(W, TWIN[stat.key], 1)[m[1]]) == Worth(stat.worth)
    if not twin and (WEAPON[stat.key] or stat.worth * (CHUNK[stat.key] or 1) >= SHARE * top) then
      stat.main, stat.same = main, main and stat ~= main and stat.worth / main.worth or nil
      table.insert(kept, stat)
    end
  end
  table.sort(kept, function(a, b)
    if a.worth ~= b.worth then return a.worth > b.worth end
    return a.name < b.name
  end)
  return kept
end

-- The list's lines, top to bottom: a heading per number of the build (with your own total when the weights are yours), then
-- its stats
local function Lines(pane, W)
  local lines = {}
  for _, m in ipairs(pane.measures) do
    local stats, section = Section(W, m), SECTION[m[4]]
    if #stats > 0 then
      local yours = pane.live and W.base[TURNS_OF[m[1]]]
      table.insert(lines, { head = yours and section.title .. ": " .. section.total:format(Amount(yours))
        or FOR_UNIT:format(section.title, section.unit), section = section })
      for _, stat in ipairs(stats) do table.insert(lines, stat) end
    end
  end
  return lines
end

local function ShowList(pane, W)
  local lines = Lines(pane, W)
  pane.heads.cap:SetShown(pane.turns ~= nil)
  local shaded = false
  for r, row in ipairs(pane.rows) do
    local line = lines[r]
    row.line = line
    row:SetShown(line ~= nil)
    if line then
      shaded = not line.head and not shaded
      row.shade:SetShown(shaded)
      row.head:SetText(line.head or "")
      row.name:SetText(line.head and "" or line.name)
      row.have:SetText(line.head and "" or Have(line.key))
      row.adds:SetText(line.head and "" or Worth(line.worth))
      row.same:SetText(line.same and KP.Num(line.same, 2) .. " " .. line.main.name or "")
      local turns = pane.turns and not line.head and pane.turns[line.key]
      row.cap:SetText(turns and Coming(turns[TURNS_OF[line.measure]]) or "")
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
  pane.measures = KP.Upgrade.MEASURES[role] or KP.Upgrade.MEASURES.dps
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
    pane.note:SetText(("Worked out from the gear you wear, your talents and your weapons, in %s, against %s %s.%s%s"):format(
      KP.SimPane.StanceName[W.stance], enemy, hit and "that's hitting you" or "that someone else is tanking",
      build and "" or " No planner build chosen: counted as a damage dealer.",
      current and "" or " The game hides your numbers right now (in a fight or a dungeon?): these are from before."))
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
  SetShown(pane, false, true)
  ShowList(pane, planned)
end
