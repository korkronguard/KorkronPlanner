local _, KP = ...

local Pane = {}
KP.StatsPane = Pane

local TARGETS = { { key = "same", label = "Normal enemy", text = "a normal enemy of your level" },
  { key = "elite", label = "Elite", text = "an elite of your level" },
  { key = "elite3", label = "Elite, 3 levels up", text = "an elite 3 levels above you" } }
local MAIN = { strength = true, agility = true, stamina = true, intellect = true, spirit = true }
local WEAPON = { mainHand = "Main-hand weapon", offHand = "Off-hand weapon", ranged = "Ranged weapon" }
local TURNS_OF = { v = "d", d = "d", e = "e" }
local SECTION = {
  ["eff. HP"] = { title = "Staying alive", total = "your effective health is %s", unit = "effective health",
    about = "Effective health is how much damage you can take before you die: your health, and what your armor, dodge, parry " ..
      "and block keep off you, measured against a raid boss." },
  DPS = { title = "Damage", total = "you do %s a second", unit = "damage a second",
    about = "Your damage a second against this enemy, pressing your abilities whenever they're ready and you have the rage or energy: " ..
      "the DPS tab's math. Buffs count while they're up." },
  HPS = { title = "Healing", total = "you heal %s a second", unit = "healing a second",
    about = "Your healing a second with the mana you have, by the planner's math." },
}
local FOR_UNIT = "%s: what a point adds to your %s"
local SUNDER_HEAD = ", with your Sunder Armor at %d stacks"
local SUNDER_ABOUT = "Against an elite this counts your own Sunder Armor: %d stacks from the start of the fight, then kept up, its rage " ..
  "paid out of this number. That's why it's higher than against a normal enemy, where none is counted: it dies before the " ..
  "stacks pay for themselves."
local ROWS, ROW_H, TOP = 18, 18, -122
local NAME_W, HAVE_W, ADDS_W, SAME_W, CAP_X = 150, 72, 62, 92, 390
local CONTROLS_X = 116
local SMALL = 0.0005
local SHARE = 0.05
local CHUNK = { armor = 12, bonusArmor = 12 }
local TWIN = { bonusArmor = "armor", spellDamage = "spellPower" }
local CHANCE = { crit = "your crit chance is %s%%", hit = "with your talents that's %s%% more hit", dodge = "your dodge chance is %s%%",
  parry = "your parry chance is %s%%", block = "your block chance is %s%%" }

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

local function Amount(x)
  if x < 100 then return KP.Num(x, 1) end
  local text = ("%d"):format(x + 0.5):reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (text:gsub("^,", ""))
end

local function Have(key)
  local amount, chance = KP.Sheet.Have(key)
  if not amount then return "" end
  if WEAPON[key] then return Amount(amount) .. " a sec" end
  return Amount(amount) .. (chance and (" (%s%%)"):format(KP.Num(chance, 1)) or "")
end

local function Points(x)
  return math.floor(x + 0.5)
end

local function Coming(found)
  if not found then return nil end
  if found.spare then return ("capped: %d to spare"):format(Points(found.spare)) end
  local turn = found.turns[1]
  return turn and ("%d more, then %s"):format(Points(turn.at), Worth(turn.worth) or "nothing") or nil
end

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

local function HitLine(W)
  local caps, sheet = KP.Sim.HitCaps(W.ctx.target), W.ctx.sheet
  local needs = ("your abilities stop missing at %s%% hit"):format(KP.Num(caps.melee, 1))
  if sheet.oh then needs = needs .. (", your white swings with two weapons at %s%%"):format(KP.Num(caps.dualWhite, 1)) end
  return ("Against this enemy %s. You have %s%%."):format(needs, KP.Num(sheet.hit, 1))
end

local function ShowRow(row)
  local line, pane = row.line, row.pane
  if not line then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if line.head then
    GameTooltip:AddLine(line.section.title)
    GameTooltip:AddLine(line.section.about, 1, 1, 1, true)
    if line.sunder then GameTooltip:AddLine(SUNDER_ABOUT:format(KP.SimData.rules.sunderStacks), 0.4, 0.8, 1, true) end
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
  pane.title = Text(pane, "KorkronPlannerFontNormalLarge", 0, 0, width - 10)
  pane.note = Text(pane, "KorkronPlannerFontHighlightSmall", 0, -20, width - 10)
  local function Choice(label, x, y, w, onClick)
    local b = CreateFrame("Button", nil, pane)
    b:SetSize(w, 22)
    KP.Style.Button(b)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", function()
      KP.Safe(function()
        onClick()
        KP.Window.Refresh()
        KP.BagIcons.Refresh()
      end)
    end)
    return b
  end
  pane.against = Text(pane, "KorkronPlannerFontNormalSmall", 0, -52, CONTROLS_X)
  pane.against:SetText("Measured against")
  pane.targets = {}
  for i, t in ipairs(TARGETS) do
    pane.targets[t.key] = Choice(t.label, CONTROLS_X + (i - 1) * 134, -46, 130, function() KorkronPlannerCharDB.statTarget = t.key end)
  end
  pane.who = Text(pane, "KorkronPlannerFontNormalSmall", 0, -78, CONTROLS_X)
  pane.who:SetText("Who's tanking it")
  pane.tanking = Choice("I'm tanking it", CONTROLS_X, -72, 130, function() KorkronPlannerCharDB.simNotHit = false end)
  pane.notTanking = Choice("Someone else is", CONTROLS_X + 134, -72, 130, function() KorkronPlannerCharDB.simNotHit = true end)
  local haveX, addsX, sameX = NAME_W, NAME_W + HAVE_W, NAME_W + HAVE_W + ADDS_W + 12
  pane.heads = { have = Text(pane, "KorkronPlannerFontNormalSmall", haveX, TOP + 16, HAVE_W, "RIGHT"),
    adds = Text(pane, "KorkronPlannerFontNormalSmall", addsX, TOP + 16, ADDS_W, "RIGHT"),
    same = Text(pane, "KorkronPlannerFontNormalSmall", sameX, TOP + 16, SAME_W),
    cap = Text(pane, "KorkronPlannerFontNormalSmall", CAP_X, TOP + 16, width - CAP_X) }
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
    row.shade = row:CreateTexture(nil, "BACKGROUND")
    row.shade:SetAllPoints()
    row.shade:SetColorTexture(1, 1, 1, 0.05)
    row.head = Text(row, "KorkronPlannerFontNormal", 0, -3, width, "LEFT", true)
    row.name = Text(row, "KorkronPlannerFontHighlight", 8, -2, NAME_W - 8, "LEFT", true)
    row.have = Text(row, "KorkronPlannerFontHighlight", haveX, -2, HAVE_W, "RIGHT", true)
    row.adds = Text(row, "KorkronPlannerFontHighlight", addsX, -2, ADDS_W, "RIGHT", true)
    row.same = Text(row, "KorkronPlannerFontHighlightSmall", sameX, -3, SAME_W, "LEFT", true)
    row.cap = Text(row, "KorkronPlannerFontHighlightSmall", CAP_X, -3, width - CAP_X, "LEFT", true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowRow, self) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pane.rows[r] = row
  end
  pane.foot = Text(pane, "KorkronPlannerFontDisableSmall", 0, TOP - ROWS * ROW_H - 4, width - 10)
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

local function Lines(pane, W)
  local lines = {}
  for _, m in ipairs(pane.measures) do
    local stats, section = Section(W, m), SECTION[m[4]]
    if #stats > 0 then
      local yours = pane.live and W.base[TURNS_OF[m[1]]]
      local sunder = yours and m[4] == "DPS" and KP.Sim.CountsSunder(W.ctx)
      table.insert(lines, { head = yours and section.title .. ": " .. section.total:format(Amount(yours)) ..
        (sunder and SUNDER_HEAD:format(KP.SimData.rules.sunderStacks) or "")
        or FOR_UNIT:format(section.title, section.unit), section = section, sunder = sunder })
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

function Pane.Refresh(pane, build)
  KP.StatWeights.Stale()
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
      KP.Style.SetButtonKind(pane.targets[t.key], t.key == target)
    end
    local hit = KorkronPlannerCharDB.simNotHit ~= true
    KP.Style.SetButtonKind(pane.tanking, hit)
    KP.Style.SetButtonKind(pane.notTanking, not hit)
    local stance = W.stance ~= "none" and ", in " .. KP.SimPane.StanceName[W.stance] or ""
    pane.note:SetText(("Worked out from the gear you wear, your talents and your weapons%s, against %s %s.%s%s"):format(
      stance, enemy, hit and "that's hitting you" or "that someone else is tanking",
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
      or "The addon works these out from your own gear for Warriors and Rogues only, so far."))
  SetShown(pane, false, true)
  ShowList(pane, planned)
end
