-- Kor'kron Planner: the Talents tab of the /kp window. Your class's three trees (Data/Talents.lua: the game's own layout)
-- with your points next to the build's: a gold frame where the build wants (more) points, green where you've taken all
-- it wants, red for points the build doesn't use, white around the build's next point. Hover a talent for its tooltip.
local _, KP = ...

local Pane = {}
KP.TalentsPane = Pane

-- grid step and icon size (a coloured square 2 px wider on each side frames the icon): a tree's four columns fill its
-- third of the 520 px pane
local CELL, ICON = 40, 34
local HEADER = 24 -- the tree names above the grid
local COLORS = {
  next = { 1, 1, 1 }, done = { 0.2, 0.8, 0.2 }, todo = { 0.95, 0.75, 0.1 }, extra = { 0.9, 0.2, 0.2 }, none = { 0.15, 0.15, 0.15 },
}

local function MyClass()
  local _, class = UnitClass("player")
  return KP.Text(class)
end

local function ShowTalentTooltip(cell)
  local t, s = cell.talent, cell.shown
  GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
  GameTooltip:AddLine(t.name)
  GameTooltip:AddLine(("Your points: %d/%d    The build: %d"):format(s.yours, t.ranks, s.planned), 0.8, 0.8, 0.8)
  if s.isNext then GameTooltip:AddLine("The build's next point", 1, 0.82, 0) end
  GameTooltip:AddLine(t.desc[math.max(1, math.min(t.ranks, s.yours))], 1, 1, 1, true)
  if t.requires then
    local req = KP.Build.Talent(t.requires[1])
    GameTooltip:AddLine(("Needs %s (%d)"):format(req and req.name or "?", t.requires[2]), 1, 0.4, 0.4)
  end
  if t.note then GameTooltip:AddLine(t.note, 0.75, 0.75, 0.75, true) end
  GameTooltip:Show()
end

local function HideTooltip()
  GameTooltip:Hide()
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.treeWidth = math.floor(width / 3)
  pane.headers = {}
  for tree = 1, 3 do
    local h = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetWidth(pane.treeWidth - 4)
    h:SetJustifyH("LEFT")
    h:SetPoint("TOPLEFT", (tree - 1) * pane.treeWidth, 0)
    pane.headers[tree] = h
  end
  pane.status = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pane.status:SetWidth(width - 10)
  pane.status:SetJustifyH("LEFT")
  pane.status:SetPoint("TOPLEFT", 0, -(HEADER + 7 * CELL + 8))
  return pane
end

-- one framed icon per talent of your class, placed by its tree, row and column (made once: the class never changes)
local function CreateCells(pane, talents)
  pane.cells = {}
  for i, t in ipairs(talents) do
    local cell = CreateFrame("Frame", nil, pane)
    cell:SetSize(ICON + 4, ICON + 4)
    cell:SetPoint("TOPLEFT", (t.tree - 1) * pane.treeWidth + t.col * CELL, -(HEADER + t.row * CELL))
    cell.border = cell:CreateTexture(nil, "BACKGROUND")
    cell.border:SetAllPoints()
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(ICON, ICON)
    cell.icon:SetPoint("CENTER")
    cell.icon:SetTexture(t.icon)
    cell.rank = cell:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    cell.rank:SetPoint("BOTTOMRIGHT", 2, -2)
    cell.talent = t
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(self) KP.Safe(ShowTalentTooltip, self) end)
    cell:SetScript("OnLeave", HideTooltip)
    pane.cells[i] = cell
  end
end

-- which frame colour a talent gets
local function Kind(yours, want, isNext)
  if isNext then return "next" end
  if want > 0 then
    if yours > want then return "extra" end
    return yours >= want and "done" or "todo"
  end
  return yours > 0 and "extra" or "none"
end

-- build: the chosen build (nil when none)
function Pane.Refresh(pane, build)
  local talents = KP.Talents[MyClass()] or {} -- the class's talents in order, and .trees = the three tree names
  if not pane.cells then CreateCells(pane, talents) end
  local ranks = KP.TalentRanks()
  local planned = {}
  for _, id in ipairs(build and build.order or {}) do planned[id] = (planned[id] or 0) + 1 end
  local nextStep = build and ranks and KP.Build.NextStep(KP.Build.Steps(build.order, ranks))
  local yoursIn, plannedIn = { 0, 0, 0 }, { 0, 0, 0 }
  for _, cell in ipairs(pane.cells) do
    local t = cell.talent
    local yours, want = ranks and ranks[t.id] or 0, planned[t.id] or 0
    local isNext = nextStep ~= nil and nextStep.id == t.id
    local kind = Kind(yours, want, isNext)
    cell.shown = { yours = yours, planned = want, isNext = isNext }
    cell.border:SetColorTexture(unpack(COLORS[kind]))
    cell.icon:SetDesaturated(kind == "none")
    cell.rank:SetText(yours > 0 and ("%d/%d"):format(yours, t.ranks) or "")
    yoursIn[t.tree], plannedIn[t.tree] = yoursIn[t.tree] + yours, plannedIn[t.tree] + want
  end
  for tree = 1, 3 do
    pane.headers[tree]:SetText(("%s  %d"):format((talents.trees or {})[tree] or "", yoursIn[tree]) ..
      (build and ("|cff999999 / %d|r"):format(plannedIn[tree]) or ""))
  end
  if not ranks then
    pane.status:SetText("The game isn't showing your talents here (inside a dungeon or raid?).")
  elseif not build then
    pane.status:SetText("Your points. Choose a build on the left to see it next to yours.")
  else
    pane.status:SetText("Your points / the build's in each tree. |cfff2bf1aGold|r: the build wants more there. " ..
      "|cff33cc33Green|r: done. |cffe63333Red|r: points the build doesn't use. White: the build's next point." ..
      (nextStep and ("\nNext: " .. KP.Build.Describe(nextStep)) or "\nYour build is complete."))
  end
end
