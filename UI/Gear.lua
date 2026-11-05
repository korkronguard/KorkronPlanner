-- Kor'kron Planner: the Gear tab of the /kp window. The planner website's Equip BiS for your build at your level
-- (Data/Gear.lua, worked out by the website with the build's talents and its own kind of weapons): the item for each
-- slot, where it comes from, and a tick when you're wearing it. Hovering an item shows the game's tooltip for it.
local _, KP = ...

local Pane = {}
KP.GearPane = Pane

-- the slots in the character screen's order, with the inventory slots to look in for what you wear (a ring or trinket
-- counts in either of its two)
local SLOTS = {
  { key = "head", label = "Head", inv = { 1 } }, { key = "neck", label = "Neck", inv = { 2 } },
  { key = "shoulder", label = "Shoulders", inv = { 3 } }, { key = "back", label = "Back", inv = { 15 } },
  { key = "chest", label = "Chest", inv = { 5 } }, { key = "wrist", label = "Wrists", inv = { 9 } },
  { key = "hands", label = "Hands", inv = { 10 } }, { key = "waist", label = "Waist", inv = { 6 } },
  { key = "legs", label = "Legs", inv = { 7 } }, { key = "feet", label = "Feet", inv = { 8 } },
  { key = "finger1", label = "Ring", inv = { 11, 12 } }, { key = "finger2", label = "Ring", inv = { 11, 12 } },
  { key = "trinket1", label = "Trinket", inv = { 13, 14 } }, { key = "trinket2", label = "Trinket", inv = { 13, 14 } },
  { key = "mainHand", label = "Main hand", inv = { 16 } }, { key = "offHand", label = "Off hand", inv = { 17 } },
  { key = "ranged", label = "Ranged", inv = { 18 } },
}
local QUALITY = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee", [5] = "ff8000" }
local SOURCE = { quest = "Quest", drop = "Drop", vendor = "Vendor", crafted = "Crafted" }
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local ROW = 19

local function Text(parent, font, width, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

local function ShowItemTooltip(row)
  if not row.itemID then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetItemByID(row.itemID)
  GameTooltip:Show()
end

local function HideTooltip()
  GameTooltip:Hide()
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "GameFontNormalLarge", width - 10)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.note = Text(pane, "GameFontDisableSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
  pane.rows = {}
  for i = 1, #SLOTS do
    local row = CreateFrame("Frame", nil, pane)
    row:SetSize(width - 10, ROW)
    row:SetPoint("TOPLEFT", pane.note, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW)
    row.slot = Text(row, "GameFontDisableSmall", 62)
    row.slot:SetPoint("LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 64, 0)
    row.src = Text(row, "GameFontHighlightSmall", 70, "RIGHT")
    row.src:SetPoint("RIGHT", 0, 0)
    row.name = Text(row, "GameFontHighlightSmall", width - 10 - 84 - 74)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) KP.Safe(ShowItemTooltip, self) end)
    row:SetScript("OnLeave", HideTooltip)
    pane.rows[i] = row
  end
  return pane
end

local function Wearing(invSlots, itemID)
  for _, inv in ipairs(invSlots) do
    local worn = GetInventoryItemID("player", inv)
    if KP.Readable(worn) and worn == itemID then return true end
  end
  return false
end

-- build: the chosen build (nil when none)
function Pane.Refresh(pane, build)
  local entry = build and KP.Build.ForLevel(KP.Gear, build.key, UnitLevel("player"))
  if not entry then
    pane.title:SetText(build and "Gear follows the planner's suggested builds" or "Choose a build")
    pane.note:SetText(build and "Choose one on the left to see its gear." or "")
    for _, row in ipairs(pane.rows) do row:Hide() end
    return
  end
  local picked, wearing = 0, 0
  for i, slot in ipairs(SLOTS) do
    local row, id = pane.rows[i], entry.items[slot.key]
    local item = id and KP.GearItems[id]
    row.itemID = item and id
    row.slot:SetText(slot.label)
    if item then
      local worn = Wearing(slot.inv, id)
      picked, wearing = picked + 1, wearing + (worn and 1 or 0)
      row.icon:SetTexture(item.icon)
      row.name:SetText(("|cff%s%s|r"):format(QUALITY[item.quality] or "ffffff", item.name))
      row.src:SetText((worn and (TICK .. " ") or "") .. (SOURCE[item.src] or ""))
    else
      row.icon:SetTexture(nil)
      row.name:SetText("|cff808080-|r")
      row.src:SetText("")
    end
    row:Show()
  end
  pane.title:SetText(("Gear for level %d and up: you wear %d of %d"):format(entry.level, wearing, picked))
  pane.note:SetText("The planner's best item for each slot with this build's talents and weapons. " .. TICK ..
    " = you're wearing it. Hover an item for its tooltip.")
end
