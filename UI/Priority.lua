-- Kor'kron Planner: the Priority tab of the /kp window. The planner website's Priority tab for your build at your
-- level (Data/Priority.lua, worked out by the website with the build's talents and gear at each level): what to keep
-- up, what to press first, the cooldowns. The website's own tab has the numbers for your gear.
local _, KP = ...

local Pane = {}
KP.PriorityPane = Pane

local ICON = KP.ScrollList.ICON

Pane.Create = KP.ScrollList.Create

-- build: the chosen build (nil when none)
function Pane.Refresh(pane, build)
  local L = KP.ScrollList.Layout(pane)
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
