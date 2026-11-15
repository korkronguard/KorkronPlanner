local _, KP = ...

local TalentFrame = {}
KP.TalentFrame = TalentFrame

local MAX_NUMBERED = 5
local GOLD = { 1, 0.82, 0 }

local bar

local function TalentWindow()
  return PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
end

local function ShowsYours(talents)
  return not talents:IsInspecting() and talents:IsActiveTabSelected()
end

local function Choose(key)
  KP.Build.Choose(key)
  KP.Window.BuildChanged()
end

local function IsChosen(key)
  local saved = KorkronPlannerCharDB.build
  return saved ~= nil and saved.key == key
end

local function MenuEntries(_, root)
  for _, spec in ipairs(KP.Build.BySpec()) do
    root:CreateTitle(spec.name)
    for _, build in ipairs(spec.builds) do
      root:CreateRadio(KP.Build.Label(build, spec.builds), IsChosen, function(key) KP.Safe(Choose, key) end, build.key)
    end
  end
  local saved = KorkronPlannerCharDB.build
  if saved and saved.order then
    root:CreateRadio("Your planner link", function() return true end, function() end)
  end
  root:CreateRadio("No build", function() return KorkronPlannerCharDB.build == nil end,
    function() KP.Safe(Choose, nil) end)
end

local function CreateBar(talents)
  bar = CreateFrame("Frame", "KorkronPlannerTalentBar", talents)
  bar:SetPoint("BOTTOMLEFT", 48, 6)
  bar:SetPoint("BOTTOMRIGHT", -48, 6)
  bar:SetHeight(26)
  bar.marks = {}
  local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", 0, 0)
  label:SetText("Kor'kron build:")
  bar.picker = CreateFrame("DropdownButton", nil, bar, "WowStyle1DropdownTemplate")
  bar.picker:SetWidth(240)
  bar.picker:SetPoint("LEFT", label, "RIGHT", 10, 0)
  bar.picker:SetupMenu(MenuEntries)
  bar.planner = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
  bar.planner:SetSize(80, 22)
  bar.planner:SetPoint("RIGHT", 0, 0)
  bar.planner:SetText("Planner")
  bar.planner:SetScript("OnClick", function() KP.Safe(KP.Window.Toggle) end)
  bar.next = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  bar.next:SetWidth(320)
  bar.next:SetJustifyH("RIGHT")
  bar.next:SetPoint("RIGHT", bar.planner, "LEFT", -10, 0)
end

local function NewMark()
  local m = CreateFrame("Frame")
  m.glow = m:CreateTexture(nil, "OVERLAY")
  m.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  m.glow:SetBlendMode("ADD")
  m.pulse = m.glow:CreateAnimationGroup()
  m.pulse:SetLooping("BOUNCE")
  local fade = m.pulse:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0.3)
  fade:SetDuration(0.7)
  m.order = m:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
  m.order:SetPoint("TOPLEFT", -2, 2)
  m.goal = m:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  m.goal:SetPoint("TOPRIGHT", 2, 2)
  m.goal:SetTextColor(unpack(GOLD))
  m.tick = m:CreateTexture(nil, "OVERLAY")
  m.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  m.tick:SetSize(16, 16)
  m.tick:SetPoint("TOPRIGHT", 4, 4)
  return m
end

local function Place(m, button)
  m:SetParent(button)
  m:ClearAllPoints()
  m:SetAllPoints(button)
  m:SetFrameLevel(button:GetFrameLevel() + 10)
  local pad = button:GetWidth() * 0.4
  m.glow:ClearAllPoints()
  m.glow:SetPoint("TOPLEFT", -pad, pad)
  m.glow:SetPoint("BOTTOMRIGHT", pad, -pad)
  m:Show()
end

local function Queue(steps, toSpend)
  local numbers, count, first = {}, 0, nil
  local limit = math.max(1, math.min(toSpend, MAX_NUMBERED))
  for _, step in ipairs(steps) do
    if count == limit then break end
    if not (step.done or step.dropped) then
      count = count + 1
      first = first or step
      numbers[step.id] = numbers[step.id] or {}
      table.insert(numbers[step.id], count)
    end
  end
  return numbers, count, first
end

local function NextText(step, toSpend)
  if not step then return "Build complete!" end
  local name = "|cffffd100" .. KP.Build.Describe(step) .. "|r"
  if toSpend > 0 then
    return ("Next: %s  (%d point%s to spend)"):format(name, toSpend, toSpend == 1 and "" or "s")
  end
  return ("Next, at level %d: %s"):format(math.max(10, UnitLevel("player") + 1), name)
end

local function ShowMarks(talents, want, ranks, numbers, count, nextStep)
  for id, n in pairs(want) do
    local button = n > 0 and talents:GetTalentButtonByNodeID(id)
    if button then
      bar.marks[id] = bar.marks[id] or NewMark()
      local m, have = bar.marks[id], ranks[id] or 0
      Place(m, button)
      local isNext = nextStep ~= nil and nextStep.id == id
      m.glow:SetShown(isNext)
      if isNext then m.pulse:Play() else m.pulse:Stop() end
      m.order:SetText(count > 1 and numbers[id] and table.concat(numbers[id], ",") or "")
      m.goal:SetText(have < n and ("%d/%d"):format(have, n) or "")
      m.tick:SetShown(have >= n)
    end
  end
end

function TalentFrame.Refresh()
  local talents = TalentWindow()
  if not (talents and talents:IsVisible()) then return end
  if not bar then CreateBar(talents) end
  for _, m in pairs(bar.marks) do m:Hide() end
  local yours = ShowsYours(talents)
  bar:SetShown(yours)
  if not yours then return end
  local build = KP.Build.Current()
  bar.picker:OverrideText(build and build.name or "Choose a build")
  if not build then return bar.next:SetText("") end
  local ranks = KP.TalentRanks(talents:GetConfigID())
  if not ranks then return bar.next:SetText("The game isn't showing your talents here.") end
  local steps, _, want = KP.Build.Follow(build, ranks)
  local spent, available = KP.Build.Points(ranks)
  local numbers, count, nextStep = Queue(steps, available - spent)
  ShowMarks(talents, want, ranks, numbers, count, nextStep)
  bar.next:SetText(NextText(nextStep, available - spent))
end

local function TooltipLines(tooltip, build, id, ranks)
  local t = KP.Build.Talent(id)
  local steps, _, want = KP.Build.Follow(build, ranks)
  local have, n = ranks[id] or 0, want[id] or 0
  local nextStep, step = KP.Build.NextStep(steps), nil
  for _, s in ipairs(steps) do
    if s.id == id and not (s.done or s.dropped) then
      step = s
      break
    end
  end
  tooltip:AddLine(" ")
  tooltip:AddDoubleLine("Kor'kron Planner", (build.name:gsub(" %b()", "")), GOLD[1], GOLD[2], GOLD[3], 0.6, 0.6, 0.6)
  if nextStep and nextStep.id == id then
    tooltip:AddLine(("The build's next point (%d of %d here)."):format(n, t.ranks), unpack(GOLD))
  elseif have > n then
    tooltip:AddLine(("Your own pick: %d point%s outside the build (it drops its last points to make room)."):format(
      have - n, have - n == 1 and "" or "s"), 0.3, 0.6, 1, true)
  elseif n > have then
    tooltip:AddLine(("The build: %d of %d points here."):format(n, t.ranks), unpack(GOLD))
  elseif n > 0 then
    tooltip:AddLine(("The build's %d point%s here: done."):format(n, n == 1 and "" or "s"), 0.2, 0.8, 0.2)
  else
    tooltip:AddLine("Not in this build.", 0.6, 0.6, 0.6)
  end
  local why, alts = step and build.why and build.why[step.index], step and build.alts and build.alts[step.index]
  if why then tooltip:AddLine("Why: " .. why, 0.4, 0.8, 1, true) end
  if alts then
    tooltip:AddLine("Also good here (the build adapts if you take one):", 0.4, 0.8, 1)
    for _, a in ipairs(alts) do
      local alt = KP.Build.Talent(a[1])
      tooltip:AddLine(("  %s %d/%d: %s"):format(alt.name, a[2], alt.ranks, a[3]), 1, 1, 1, true)
    end
  end
  if step and step.choice then
    tooltip:AddLine("Your choice: " .. KP.Build.ChoiceText(step.choice), GOLD[1], GOLD[2], GOLD[3], true)
  end
  if t.note then tooltip:AddLine(t.note, 0.75, 0.75, 0.75, true) end
end

local function AddTooltipLines(display, tooltip)
  local talents = TalentWindow()
  if not (talents and display.GetNodeID and ShowsYours(talents)) then return end
  local id = display:GetNodeID()
  if not (KP.Readable(id) and KP.Build.Talent(id)) then return end
  local build = KP.Build.Current()
  local ranks = build and KP.TalentRanks(talents:GetConfigID())
  if not ranks then return end
  TooltipLines(tooltip, build, id, ranks)
  tooltip:Show()
end

for _, event in ipairs({ "PlayerSpellsFrame.TalentTab.Show", "TalentFrameBase.ButtonsUpdated",
  "TalentFrameBase.ConfigUpdated" }) do
  EventRegistry:RegisterCallback(event, function() KP.Safe(TalentFrame.Refresh) end)
end
EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", function(_, display, tooltip)
  KP.Safe(AddTooltipLines, display, tooltip)
end)
KP:On("PLAYER_LEVEL_UP", function() KP.After(2, TalentFrame.Refresh) end)
