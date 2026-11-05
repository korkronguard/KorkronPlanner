-- Kor'kron Planner: the Priority tab of the /kp window. The planner website's Priority tab for your build at your
-- level (Data/Priority.lua, worked out by the website with the build's talents and gear at each level): what to keep
-- up, what to press first, the cooldowns. The website's own tab has the numbers for your gear.
local _, KP = ...

local Pane = {}
KP.PriorityPane = Pane

local SCROLLBAR = 26 -- room for the scroll bar on the right
local ICON = 18

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 0)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - SCROLLBAR, 1)
  scroll:SetScrollChild(content)
  pane.width, pane.content, pane.lines, pane.icons = width - SCROLLBAR, content, {}, {}
  return pane
end

-- Lines and icons are reused from one refresh to the next (the game can't delete font strings)
local function Layout(pane)
  local L = { y = 0, lines = 0, icons = 0 }
  function L.text(text, font, indent, gap)
    L.lines = L.lines + 1
    local fs = pane.lines[L.lines]
    if not fs then
      fs = pane.content:CreateFontString(nil, "OVERLAY")
      fs:SetJustifyH("LEFT")
      pane.lines[L.lines] = fs
    end
    fs:SetFontObject(font)
    fs:SetWidth(pane.width - indent)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", indent, -(L.y + gap))
    fs:SetText(text)
    fs:Show()
    L.y = L.y + gap + fs:GetStringHeight()
  end
  function L.icon(file, gap)
    L.icons = L.icons + 1
    local tex = pane.icons[L.icons]
    if not tex then
      tex = pane.content:CreateTexture(nil, "ARTWORK")
      tex:SetSize(ICON, ICON)
      pane.icons[L.icons] = tex
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", 0, -(L.y + gap))
    tex:SetTexture(file)
    tex:Show()
  end
  function L.finish()
    for i = L.lines + 1, #pane.lines do pane.lines[i]:Hide() end
    for i = L.icons + 1, #pane.icons do pane.icons[i]:Hide() end
    pane.content:SetHeight(L.y + 8)
  end
  return L
end

-- build: the chosen build (nil when none)
function Pane.Refresh(pane, build)
  local L = Layout(pane)
  local list = build and KP.Build.ForLevel(KP.Priority, build.key, UnitLevel("player"))
  if not list then
    L.text(build and "The Priority tab follows the planner's suggested builds: choose one on the left."
      or "Choose a build on the left.", "GameFontHighlight", 0, 0)
    return L.finish()
  end
  L.text(list.title ~= "" and list.title or build.name, "GameFontNormalLarge", 0, 0)
  L.text(("For level %d and up, with this build's talents and gear by then."):format(list.level), "GameFontDisableSmall", 0, 2)
  for _, section in ipairs(list.sections) do
    L.text(section.title, "GameFontNormal", 0, 12)
    if section.note ~= "" then L.text(section.note, "GameFontDisableSmall", 0, 2) end
    for _, item in ipairs(section.items) do
      if item.icon then L.icon(item.icon, 6) end
      L.text(item.name .. (item.tag ~= "" and ("  |cffffd100" .. item.tag .. "|r") or ""), "GameFontHighlight", ICON + 6, 6)
      if item.text ~= "" then L.text(item.text, "GameFontHighlightSmall", ICON + 6, 2) end
    end
  end
  L.text("From the planner website. Its Priority tab has the numbers for your own gear.", "GameFontDisableSmall", 0, 14)
  L.finish()
end
