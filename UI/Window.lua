-- Kor'kron Planner: the /kp window. On the left you pick one of your class's suggested builds or paste a planner
-- link; on the right, tabs: Build (the next talent, the points after it, points spent outside the build) and Priority
-- (UI/Priority.lua).
local _, KP = ...

local Window = {}
KP.Window = Window

local MAX_BUILDS = 8 -- Druids have the most: four specs, each with a level 60 and a leveling build
local ROWS = 10      -- upcoming points shown
local RIGHT = 262    -- where the tabs start
local PANE_W, PANE_H = 362, 388
local TABS = { { key = "build", label = "Build" }, { key = "priority", label = "Priority" } }

local frame
local tab = "build"

-- a point of the path: the talent's tooltip at the rank it gives, the planner's reason for it, the talent's note
local function ShowPointTooltip(row)
  local t = KP.Build.Talent(row.step.id)
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:AddLine(KP.Build.Describe(row.step))
  GameTooltip:AddLine(t.desc[row.step.rank], 1, 1, 1, true)
  if row.why then GameTooltip:AddLine("Why: " .. row.why, 0.4, 0.8, 1, true) end
  if t.note then GameTooltip:AddLine(t.note, 0.75, 0.75, 0.75, true) end
  GameTooltip:Show()
end

local function ShowSummaryTooltip(owner)
  local build = KP.Build.Current()
  if not (build and build.summary) then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(build.name)
  GameTooltip:AddLine(build.summary, 1, 1, 1, true)
  GameTooltip:Show()
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

-- the left column: suggested builds and the link box
local function CreatePicker()
  local pick = Text(frame, "GameFontNormal")
  pick:SetPoint("TOPLEFT", 16, -34)
  pick:SetText("Suggested builds")
  frame.buildButtons = {}
  for i = 1, MAX_BUILDS do
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(232, 22)
    b:SetPoint("TOPLEFT", 14, -52 - (i - 1) * 25)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetScript("OnClick", function(self)
      KP.Safe(function()
        KP.Build.Choose(self.key)
        Window.Refresh()
      end)
    end)
    frame.buildButtons[i] = b
  end

  local linkLabel = Text(frame, "GameFontNormal")
  linkLabel:SetPoint("TOPLEFT", 16, -262)
  linkLabel:SetText("Or paste a planner link")
  local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  box:SetSize(170, 22)
  box:SetPoint("TOPLEFT", 22, -280)
  box:SetAutoFocus(false)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  local use = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  use:SetSize(52, 22)
  use:SetPoint("LEFT", box, "RIGHT", 6, 0)
  use:SetText("Use")
  local linkNote = Text(frame, "GameFontHighlightSmall", 232)
  linkNote:SetPoint("TOPLEFT", 16, -308)
  use:SetScript("OnClick", function()
    KP.Safe(function()
      linkNote:SetText(KP.Build.UseLink(box:GetText()))
      box:ClearFocus()
      Window.Refresh()
    end)
  end)
  frame.linkBox, frame.useButton, frame.linkNote = box, use, linkNote
end

-- the Build tab: name, provisional note, points, next talent, the points after it, points off the build
local function CreateBuildPane()
  local pane = CreateFrame("Frame", nil, frame)
  pane:SetSize(PANE_W, PANE_H)
  local width = PANE_W - 10
  frame.heading = Text(pane, "GameFontNormalLarge", width)
  frame.heading:SetPoint("TOPLEFT", 0, 0)
  -- hovering the build's name shows its summary (a font string can't take the mouse, so a frame lies over it)
  frame.headingHover = CreateFrame("Frame", nil, pane)
  frame.headingHover:SetAllPoints(frame.heading)
  frame.headingHover:EnableMouse(true)
  frame.headingHover:SetScript("OnEnter", function(self) KP.Safe(ShowSummaryTooltip, self) end)
  frame.headingHover:SetScript("OnLeave", HideTooltip)
  frame.note = Text(pane, "GameFontHighlightSmall", width)
  frame.note:SetPoint("TOPLEFT", frame.heading, "BOTTOMLEFT", 0, -4)
  frame.status = Text(pane, "GameFontHighlight", width)
  frame.status:SetPoint("TOPLEFT", frame.note, "BOTTOMLEFT", 0, -8)
  frame.rows = {}
  for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, pane)
    row:SetSize(width, 20)
    row:SetPoint("TOPLEFT", i == 1 and frame.status or frame.rows[i - 1], "BOTTOMLEFT", 0, i == 1 and -8 or -2)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 38, 0)
    row.level = Text(row, "GameFontHighlightSmall")
    row.level:SetPoint("LEFT", 0, 0)
    row.name = Text(row, "GameFontHighlight", width - 62)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowPointTooltip, self) end)
    row:SetScript("OnLeave", HideTooltip)
    frame.rows[i] = row
  end
  frame.off = Text(pane, "GameFontHighlightSmall", width)
  frame.off:SetPoint("TOPLEFT", frame.rows[ROWS], "BOTTOMLEFT", 0, -8)
  return pane
end

local function Create()
  frame = CreateFrame("Frame", "KorkronPlannerWindow", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(RIGHT + PANE_W + 16, PANE_H + 72)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function() KP.Safe(Window.Refresh) end)
  table.insert(UISpecialFrames, "KorkronPlannerWindow") -- Escape closes it
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("Kor'kron Planner")

  CreatePicker()
  frame.panes = { build = CreateBuildPane(), priority = KP.PriorityPane.Create(frame, PANE_W, PANE_H) }
  for _, pane in pairs(frame.panes) do pane:SetPoint("TOPLEFT", RIGHT, -62) end
  frame.tabButtons = {}
  for i, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(90, 22)
    b:SetPoint("TOPLEFT", RIGHT + (i - 1) * 94, -30)
    b:SetText(t.label)
    b:SetScript("OnClick", function() KP.Safe(Window.ShowTab, t.key) end)
    frame.tabButtons[t.key] = b
  end
  frame:Hide() -- new frames start shown; Toggle shows it, which fills it in (OnShow)
end

local function ShowBuildButtons(chosenKey)
  local builds = KP.Build.Suggested()
  for i, b in ipairs(frame.buildButtons) do
    local build = builds[i]
    b.key = build and build.key
    b:SetShown(build ~= nil)
    if build then b:SetText(build.name .. (build.provisional and " *" or "")) end
    if build and build.key == chosenKey then b:LockHighlight() else b:UnlockHighlight() end
  end
end

-- the upcoming points: the first not taken is "Next", the rest follow in the build's order. why = the planner's
-- reason for each point (a suggested build's; a pasted link has none)
local function ShowRows(steps, why)
  local shown = 0
  for i, step in ipairs(steps) do
    if not step.done and shown < ROWS then
      shown = shown + 1
      local row, t = frame.rows[shown], KP.Build.Talent(step.id)
      row.step, row.why = step, why and why[i]
      row.level:SetText(shown == 1 and "|cffffd100Next|r" or ("Lv " .. step.level))
      row.icon:SetTexture(t.icon)
      row.name:SetText(KP.Build.Describe(step))
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
  if not build then
    frame.heading:SetText("Choose a build")
    frame.note:SetText(saved and why or "Pick one of the planner's builds on the left, or paste a link to your own " ..
      "build from the planner website. This window then shows the talent to take next.")
    frame.status:SetText("")
    return HideRows()
  end
  frame.heading:SetText(build.name)
  frame.note:SetText(build.provisional and ("|cffff9933Provisional:|r " .. build.provisional) or "")
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
  if ShowRows(KP.Build.Steps(build.order, ranks), build.why) == 0 then frame.status:SetText("Build complete!") end
  local off = {}
  for _, o in ipairs(KP.Build.OffBuild(build.order, ranks)) do
    table.insert(off, ("%s +%d"):format(KP.Build.Talent(o.id).name, o.extra))
  end
  if #off > 0 then frame.off:SetText("|cffff9933Not in this build:|r " .. table.concat(off, ", ")) end
end

function Window.Refresh()
  if not (frame and frame:IsShown()) then return end
  local saved = KorkronPlannerCharDB.build
  ShowBuildButtons(saved and saved.key)
  for key, pane in pairs(frame.panes) do pane:SetShown(key == tab) end
  for key, b in pairs(frame.tabButtons) do
    if key == tab then b:LockHighlight() else b:UnlockHighlight() end
  end
  local build, why = KP.Build.Current()
  if tab == "priority" then
    KP.PriorityPane.Refresh(frame.panes.priority, build)
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
end

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP" }) do
  KP:On(event, function() KP.After(2, Window.Refresh) end) -- the game's numbers settle a moment after these
end
