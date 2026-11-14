-- Kor'kron Planner: the /kp window. On the left you pick one of your class's suggested builds (by spec: Solo, Dungeon,
-- PvP) or paste a planner link; on the right, tabs: Build (the next talent, the points after it, your own picks and
-- choices), Talents (UI/Talents.lua), Priority (UI/Priority.lua), Gear (UI/Gear.lua), Stats (UI/Stats.lua), Formulas
-- (UI/Formulas.lua), DPS (UI/Sim.lua) and Abilities (UI/Abilities.lua), which takes the whole width: the build picker steps
-- aside while it's open.
local _, KP = ...

local Window = {}
KP.Window = Window

local Style = KP.Style
local TOP = Style.TOP -- the tab row
local MAX_BUILDS = 12 -- three paths for each of three specs, with room for a spec that has two builds on a path
local ROWS = 14       -- upcoming points shown
local RIGHT = 282     -- where the tabs start
local PICK_W = 252    -- the build picker on the left
local PANE_W, PANE_H = 520, 470
local LEFT = 16       -- where a pane that takes the whole width starts
local TABS = { { key = "build", label = "Build" }, { key = "talents", label = "Talents" }, { key = "priority", label = "Priority" },
  { key = "gear", label = "Gear" }, { key = "stats", label = "Stats" }, { key = "formulas", label = "Formulas" },
  { key = "sim", label = "DPS" }, { key = "abilities", label = "Abilities" } }
local TAB_W = 63 -- eight tabs across the pane
local WIDE = { abilities = true } -- the tabs that take the whole width

local frame
local tab = "build"

-- a point of the path: the talent's tooltip at the rank it gives, the planner's reason for it, the talents the math
-- rates nearly as good there, whether it's your choice, the talent's note
local function ShowPointTooltip(row)
  local t, step = KP.Build.Talent(row.step.id), row.step
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(KP.Build.Describe(step))
  GameTooltip:AddLine(t.desc[step.rank], 1, 1, 1, true)
  if row.why then GameTooltip:AddLine("Why: " .. row.why, 0.4, 0.8, 1, true) end
  if row.alts then
    GameTooltip:AddLine("Also good here (the build adapts if you take one):", 0.4, 0.8, 1)
    for _, a in ipairs(row.alts) do
      local alt = KP.Build.Talent(a[1])
      GameTooltip:AddLine(("  %s %d/%d: %s"):format(alt.name, a[2], alt.ranks, a[3]), 1, 1, 1, true)
    end
  end
  if step.choice then GameTooltip:AddLine("Your choice: " .. KP.Build.ChoiceText(step.choice), 1, 0.82, 0, true) end
  if t.note then GameTooltip:AddLine(t.note, 0.75, 0.75, 0.75, true) end
  GameTooltip:Show()
end

local function ShowBuildTooltip(owner, build)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(build.name)
  GameTooltip:AddLine(build.summary, 1, 1, 1, true)
  if build.measured then
    GameTooltip:AddLine(("Measured by the planner's math: %d of %d points (the rest picked by judgment)."):format(build.measured,
      #build.order), 0.75, 0.75, 0.75, true)
  end
  if build.judgment then GameTooltip:AddLine("Judgment, not measured: " .. build.judgment, 0.4, 0.8, 1, true) end
  GameTooltip:Show()
end

local function ShowSummaryTooltip(owner)
  local build = KP.Build.Current()
  if build and build.summary then ShowBuildTooltip(owner, build) end
end

local function HideTooltip()
  GameTooltip:Hide()
end

local function Text(parent, font, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH("LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

-- the left column: suggested builds (a heading per spec, then its Solo / Dungeon / PvP buttons) and the link box, in one frame
-- (frame.picker) that a wide tab hides
local function CreatePicker()
  local picker = CreateFrame("Frame", nil, frame)
  picker:SetAllPoints()
  frame.picker = picker
  local pick = Text(picker, "KorkronPlannerFontNormal")
  pick:SetPoint("TOPLEFT", 16, TOP - 4)
  pick:SetText("Suggested builds")
  frame.specHeaders = {}
  for i = 1, 3 do frame.specHeaders[i] = Text(picker, "KorkronPlannerFontHighlightSmall", PICK_W) end
  frame.buildButtons = {}
  for i = 1, MAX_BUILDS do
    local b = CreateFrame("Button", nil, picker)
    b:SetHeight(22)
    Style.Button(b)
    b:SetScript("OnClick", function(self)
      KP.Safe(function()
        KP.Build.Choose(self.key)
        Window.BuildChanged()
      end)
    end)
    b:SetScript("OnEnter", function(self) KP.Safe(ShowBuildTooltip, self, self.build) end)
    b:SetScript("OnLeave", HideTooltip)
    frame.buildButtons[i] = b
  end

  local linkLabel = Text(picker, "KorkronPlannerFontNormal")
  linkLabel:SetPoint("TOPLEFT", 16, TOP - 232)
  linkLabel:SetText("Or paste a planner link")
  local box = CreateFrame("EditBox", nil, picker, "BackdropTemplate")
  Style.EditBox(box)
  box:SetSize(PICK_W - 56, 22)
  box:SetPoint("TOPLEFT", 16, TOP - 250)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  local use = CreateFrame("Button", nil, picker)
  use:SetSize(52, 22)
  Style.Button(use)
  use:SetPoint("LEFT", box, "RIGHT", 4, 0)
  use:SetText("Use")
  local linkNote = Text(picker, "KorkronPlannerFontHighlightSmall", PICK_W)
  linkNote:SetPoint("TOPLEFT", 16, TOP - 278)
  use:SetScript("OnClick", function()
    KP.Safe(function()
      linkNote:SetText(KP.Build.UseLink(box:GetText()))
      box:ClearFocus()
      Window.BuildChanged()
    end)
  end)
  frame.linkBox, frame.useButton, frame.linkNote = box, use, linkNote
end

-- the Build tab: name, provisional note, points, next talent, the points after it, points off the build
local function CreateBuildPane()
  local pane = CreateFrame("Frame", nil, frame)
  pane:SetSize(PANE_W, PANE_H)
  local width = PANE_W - 10
  frame.heading = Text(pane, "KorkronPlannerFontNormalLarge", width)
  frame.heading:SetPoint("TOPLEFT", 0, 0)
  -- hovering the build's name shows its summary (a font string can't take the mouse, so a frame lies over it)
  frame.headingHover = CreateFrame("Frame", nil, pane)
  frame.headingHover:SetAllPoints(frame.heading)
  frame.headingHover:EnableMouse(true)
  frame.headingHover:SetScript("OnEnter", function(self) KP.Safe(ShowSummaryTooltip, self) end)
  frame.headingHover:SetScript("OnLeave", HideTooltip)
  frame.note = Text(pane, "KorkronPlannerFontHighlightSmall", width)
  frame.note:SetPoint("TOPLEFT", frame.heading, "BOTTOMLEFT", 0, -4)
  frame.status = Text(pane, "KorkronPlannerFontHighlight", width)
  frame.status:SetPoint("TOPLEFT", frame.note, "BOTTOMLEFT", 0, -8)
  frame.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, pane)
    row:SetSize(width, 20)
    row:SetPoint("TOPLEFT", i == 1 and frame.status or frame.rows[i - 1], "BOTTOMLEFT", 0, i == 1 and -8 or -2)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 38, 0)
    row.level = Text(row, "KorkronPlannerFontHighlightSmall")
    row.level:SetPoint("LEFT", 0, 0)
    row.name = Text(row, "KorkronPlannerFontHighlight", width - 62)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowPointTooltip, self) end)
    row:SetScript("OnLeave", HideTooltip)
    frame.rows[i] = row
  end
  frame.off = Text(pane, "KorkronPlannerFontHighlightSmall", width)
  frame.off:SetPoint("TOPLEFT", frame.rows[ROWS], "BOTTOMLEFT", 0, -8)
  frame.choices = Text(pane, "KorkronPlannerFontHighlightSmall", width)
  frame.choices:SetPoint("TOPLEFT", frame.off, "BOTTOMLEFT", 0, -4)
  return pane
end

local function Create()
  frame = CreateFrame("Frame", "KorkronPlannerWindow", UIParent)
  frame:SetSize(RIGHT + PANE_W + 16, PANE_H + 80)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:SetToplevel(true) -- comes to the front when clicked (over the game's talent window, which opens it too)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function() KP.Safe(Window.Refresh) end)
  table.insert(UISpecialFrames, "KorkronPlannerWindow") -- Escape closes it
  Style.Window(frame, "Kor'kron Planner")

  CreatePicker()
  frame.panes = { build = CreateBuildPane(), talents = KP.TalentsPane.Create(frame, PANE_W, PANE_H),
    priority = KP.PriorityPane.Create(frame, PANE_W, PANE_H), gear = KP.GearPane.Create(frame, PANE_W, PANE_H),
    stats = KP.StatsPane.Create(frame, PANE_W, PANE_H), formulas = KP.FormulasPane.Create(frame, PANE_W, PANE_H),
    sim = KP.SimPane.Create(frame, PANE_W, PANE_H), abilities = KP.AbilitiesPane.Create(frame, RIGHT + PANE_W - LEFT, PANE_H) }
  for key, pane in pairs(frame.panes) do pane:SetPoint("TOPLEFT", WIDE[key] and LEFT or RIGHT, TOP - 32) end
  frame.tabButtons = {}
  for i, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, frame)
    b:SetSize(TAB_W, 22)
    Style.Button(b)
    b:SetPoint("TOPLEFT", RIGHT + (i - 1) * (TAB_W + 2), TOP)
    b:SetText(t.label)
    b:SetScript("OnClick", function() KP.Safe(Window.ShowTab, t.key) end)
    frame.tabButtons[t.key] = b
  end
  frame:Hide() -- new frames start shown; Toggle shows it, which fills it in (OnShow)
end

-- a heading per spec, then its builds three to a row (two when a label needs the room)
local function ShowBuildButtons(chosenKey)
  local y, n = TOP - 22, 0
  local specs = KP.Build.BySpec()
  for s, header in ipairs(frame.specHeaders) do
    local spec = specs[s]
    header:SetShown(spec ~= nil)
    if spec then
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", 16, y)
      header:SetText(spec.name)
      y = y - 15
      local labels, perRow = {}, 3
      for i, build in ipairs(spec.builds) do
        labels[i] = KP.Build.Label(build, spec.builds) .. (build.provisional and " *" or "")
        if #labels[i] > 12 then perRow = 2 end
      end
      local w = math.floor((PICK_W - (perRow - 1) * 4) / perRow)
      for i, build in ipairs(spec.builds) do
        n = n + 1
        local b, col = frame.buildButtons[n], (i - 1) % perRow
        if i > 1 and col == 0 then y = y - 24 end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", 14 + col * (w + 4), y)
        b:SetWidth(w)
        b.key, b.build = build.key, build
        b:SetText(labels[i])
        b:Show()
        Style.SetButtonKind(b, build.key == chosenKey)
      end
      y = y - 28
    end
  end
  for i = n + 1, MAX_BUILDS do frame.buildButtons[i]:Hide() end
end

-- the upcoming points: the first not taken is "Next", the rest follow in the build's order (points dropped to make
-- room for your own picks left out). build.why = the planner's reason for each point and build.alts the talents it
-- rates nearly as good there (a suggested build's; a pasted link has neither)
local function ShowRows(steps, build)
  local shown = 0
  for _, step in ipairs(steps) do
    if not (step.done or step.dropped) and shown < ROWS then
      shown = shown + 1
      local row, t = frame.rows[shown], KP.Build.Talent(step.id)
      row.step, row.why, row.alts = step, build.why and build.why[step.index], build.alts and build.alts[step.index]
      row.level:SetText(shown == 1 and "|cffffd100Next|r" or ("Lv " .. step.level))
      row.icon:SetTexture(t.icon)
      row.name:SetText(KP.Build.Describe(step) .. (step.choice and "  |cff999999(your choice)|r" or "") ..
        (row.alts and "  |cff999999(or ...)|r" or ""))
      row:Show()
    end
  end
  for i = shown + 1, ROWS do frame.rows[i]:Hide() end
  return shown
end

local function HideRows()
  for _, row in ipairs(frame.rows) do row:Hide() end
end

local function RefreshBuildPane(build, why, saved)
  frame.off:SetText("")
  frame.choices:SetText("")
  if not build then
    frame.heading:SetText("Choose a build")
    frame.note:SetText(saved and why or "Pick one of the planner's builds on the left, or paste a link to your own " ..
      "build from the planner website. This window then shows the talent to take next.")
    frame.status:SetText("")
    return HideRows()
  end
  frame.heading:SetText(build.name)
  frame.note:SetText(build.provisional and ("|cffff9933Provisional:|r " .. build.provisional) or
    build.judgment and "|cff66ccffPvP:|r its PvP talents are picked from class knowledge (hover the name)." or "")
  local choices = {}
  for _, f in ipairs(build.flex or {}) do
    table.insert(choices, ("|cffffd100Your choice (%d point%s):|r %s"):format(f.points, f.points == 1 and "" or "s",
      KP.Build.ChoiceText(f)))
  end
  frame.choices:SetText(table.concat(choices, "\n"))
  local ranks = KP.TalentRanks()
  if not ranks then
    frame.status:SetText("The game isn't showing your talents here (inside a dungeon or raid?).")
    return HideRows()
  end
  local spent, available = KP.Build.Points(ranks)
  if available == 0 then
    frame.status:SetText("Talent points start at level 10. Your first points:")
  elseif spent < available then
    frame.status:SetText(("You have %d talent point%s to spend."):format(available - spent, available - spent == 1 and "" or "s"))
  else
    frame.status:SetText(("All %d talent points spent."):format(spent))
  end
  local steps, own = KP.Build.Follow(build, ranks)
  if ShowRows(steps, build) == 0 then frame.status:SetText("Build complete!") end
  local off, extra = {}, 0
  for _, o in ipairs(own) do
    table.insert(off, ("%s +%d"):format(KP.Build.Talent(o.id).name, o.extra))
    extra = extra + o.extra
  end
  if #off > 0 then
    frame.off:SetText(("|cff66b3ffYour own picks:|r %s (the build's last %s room)"):format(table.concat(off, ", "),
      extra == 1 and "point makes" or (extra .. " points make")))
  end
end

function Window.Refresh()
  if not (frame and frame:IsShown()) then return end
  local saved = KorkronPlannerCharDB.build
  ShowBuildButtons(saved and saved.key)
  for key, pane in pairs(frame.panes) do pane:SetShown(key == tab) end
  frame.picker:SetShown(not WIDE[tab])
  for key, b in pairs(frame.tabButtons) do Style.SetButtonKind(b, key == tab) end
  local build, why = KP.Build.Current()
  if tab == "talents" then
    KP.TalentsPane.Refresh(frame.panes.talents, build)
  elseif tab == "priority" then
    KP.PriorityPane.Refresh(frame.panes.priority, build)
  elseif tab == "gear" then
    KP.GearPane.Refresh(frame.panes.gear, build)
  elseif tab == "stats" then
    KP.StatsPane.Refresh(frame.panes.stats, build)
  elseif tab == "formulas" then
    KP.FormulasPane.Refresh(frame.panes.formulas, build)
  elseif tab == "sim" then
    KP.SimPane.Refresh(frame.panes.sim)
  elseif tab == "abilities" then
    KP.AbilitiesPane.Refresh(frame.panes.abilities)
  else
    RefreshBuildPane(build, why, saved)
  end
end

function Window.ShowTab(key)
  tab = key
  Window.Refresh()
end

function Window.Toggle()
  if not frame then Create() end
  frame:SetShown(not frame:IsShown())
  if frame:IsShown() then frame:Raise() end
end

-- after a build is chosen anywhere (here or on the game's talent window): everything that shows it
function Window.BuildChanged()
  Window.Refresh()
  KP.BagIcons.Refresh()
  KP.TalentFrame.Refresh()
end

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM" }) do
  KP:On(event, function() KP.After(2, Window.Refresh) end) -- the game's numbers settle a moment after these
end
