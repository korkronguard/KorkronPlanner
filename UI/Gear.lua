-- Kor'kron Planner: the Gear tab of the /kp window. The planner website's Equip BiS for your build at your level
-- (Data/Gear.lua, worked out by the website with the build's talents and its own kind of weapons): for each slot the
-- best item and the next best, where each comes from, and a tick when you're wearing it. Clicking a slot lists its
-- options, and you can choose your own (saved per character, build and gear level). Link gives the item's Wowhead page
-- to copy, which says where to get it. Hovering an item shows the game's tooltip for it.
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
local WOWHEAD = "https://www.wowhead.com/forever/item=%d" -- Wowhead's WoW: Forever database, as on the website
local ROW, OPTION, PAD = 22, 20, 10
local MENU_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function Text(parent, font, width, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

-- the website doesn't know every item's icon (0), the game does. Which of its two icon functions Forever has isn't
-- known yet (the probe doesn't check), so either will do, and a question mark when neither answers.
local function ItemIcon(id, item)
  if item.icon ~= 0 then return item.icon end
  return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id))
    or "Interface\\Icons\\INV_Misc_QuestionMark"
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

local function ShowLink(id)
  KP.CopyBox(KP.GearItems[id].name .. " on Wowhead",
    "Press Ctrl+C to copy, then paste it into your web browser. The page says where to get the item.", WOWHEAD:format(id))
end

local function Wearing(invSlots, itemID)
  for _, inv in ipairs(invSlots) do
    local worn = GetInventoryItemID("player", inv)
    if KP.Readable(worn) and worn == itemID then return true end
  end
  return false
end

-- an item's icon (at left), name, source and Link button on a slot row or a menu line; right = room kept on the right
local function AddItemParts(row, left, right)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", left, 0)
  row.link = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.link:SetSize(36, 16)
  row.link:SetPoint("RIGHT", -right, 0)
  row.link:SetNormalFontObject("GameFontNormalSmall")
  row.link:SetHighlightFontObject("GameFontHighlightSmall")
  row.link:SetText("Link")
  row.link:SetScript("OnClick", function() KP.Safe(ShowLink, row.itemID) end)
  row.src = Text(row, "GameFontHighlightSmall", 62, "RIGHT")
  row.src:SetPoint("RIGHT", row.link, "LEFT", -4, 0)
  row.name = Text(row, "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.name:SetPoint("RIGHT", row.src, "LEFT", -4, 0)
  row.name:SetWordWrap(false) -- a long name is cut short instead of running onto a second line
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row:SetScript("OnEnter", function(self) KP.Safe(ShowItemTooltip, self) end)
  row:SetScript("OnLeave", HideTooltip)
end

local function ShowItem(row, id, worn)
  local item = KP.GearItems[id]
  row.itemID = id
  row.icon:SetTexture(ItemIcon(id, item))
  row.name:SetText(("|cff%s%s|r"):format(QUALITY[item.quality] or "ffffff", item.name))
  row.src:SetText((worn and (TICK .. " ") or "") .. (SOURCE[item.src] or ""))
  row.link:Show()
end

-- which of a slot's options is yours: the one you chose, else the planner's pick (also when a new version of the
-- website's gear no longer lists your choice)
local function ChosenIndex(options, chosenID)
  for i, option in ipairs(options) do
    if option[1] == chosenID then return i end
  end
  return 1
end

-- choosing the first option (the planner's pick) forgets your own choice
local function Choose(pane, i)
  local row, gear = pane.menu.row, KorkronPlannerCharDB.gear
  gear[pane.buildKey] = gear[pane.buildKey] or {}
  local byLevel = gear[pane.buildKey]
  byLevel[pane.gearLevel] = byLevel[pane.gearLevel] or {}
  byLevel[pane.gearLevel][row.slot.key] = i > 1 and row.options[i][1] or nil
  KP.Window.Refresh()
end

local function MenuLine(pane, i)
  local menu = pane.menu
  if menu.lines[i] then return menu.lines[i] end
  local line = CreateFrame("Button", nil, menu)
  line:SetSize(menu:GetWidth() - 2 * PAD, OPTION)
  line:SetPoint("TOPLEFT", menu.title, "BOTTOMLEFT", 0, -4 - (i - 1) * OPTION)
  line.check = line:CreateTexture(nil, "ARTWORK")
  line.check:SetSize(14, 14)
  line.check:SetPoint("LEFT", 0, 0)
  line.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  line.pct = Text(line, "GameFontHighlightSmall", 32, "RIGHT")
  line.pct:SetPoint("LEFT", 14, 0)
  AddItemParts(line, 50, 0)
  line:SetScript("OnClick", function() KP.Safe(Choose, pane, i) end)
  menu.lines[i] = line
  return line
end

local function CreateMenu(pane, width)
  local menu = CreateFrame("Frame", nil, pane, "BackdropTemplate")
  menu:SetBackdrop(MENU_BACKDROP)
  menu:SetBackdropColor(0, 0, 0, 0.95)
  menu:SetWidth(width)
  menu:SetFrameStrata("HIGH") -- over the /kp window, under the copy box
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu.title = Text(menu, "GameFontNormalSmall", width - 2 * PAD - 20)
  menu.title:SetPoint("TOPLEFT", PAD, -PAD)
  local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
  close:SetSize(24, 24)
  close:SetPoint("TOPRIGHT", -2, -2)
  menu.lines = {}
  menu:Hide()
  return menu
end

-- a slot's options under (or, low in the list, over) its row; clicking the row again closes it
local function OpenMenu(pane, row)
  local menu = pane.menu
  if menu:IsShown() and menu.row == row then return menu:Hide() end
  if not (row.options and #row.options > 1) then return end
  menu.row = row
  menu.title:SetText(row.slot.label .. ": the planner's options (% = how close each comes to the best)." ..
    " Click one to make it yours.")
  local chosen = ChosenIndex(row.options, pane.picks[row.slot.key])
  for i, option in ipairs(row.options) do
    local line = MenuLine(pane, i)
    ShowItem(line, option[1], Wearing(row.slot.inv, option[1]))
    line.pct:SetText(i == 1 and "Best" or (option[2] .. "%"))
    line.check:SetShown(i == chosen)
    line:Show()
  end
  for i = #row.options + 1, #menu.lines do menu.lines[i]:Hide() end
  menu:SetHeight(2 * PAD + menu.title:GetStringHeight() + 4 + #row.options * OPTION + 2)
  menu:ClearAllPoints()
  if row.index <= #SLOTS / 2 then
    menu:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
  else
    menu:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 0)
  end
  menu:Show()
end

function Pane.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  pane.title = Text(pane, "GameFontNormalLarge", width - 10)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.note = Text(pane, "GameFontDisableSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
  pane.rows = {}
  for i, slot in ipairs(SLOTS) do
    local row = CreateFrame("Button", nil, pane)
    row.index, row.slot = i, slot
    row:SetSize(width - 10, ROW)
    row:SetPoint("TOPLEFT", pane.note, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW)
    row.label = Text(row, "GameFontDisableSmall", 58)
    row.label:SetPoint("LEFT", 0, 0)
    row.arrow = row:CreateTexture(nil, "ARTWORK")
    row.arrow:SetSize(14, 14)
    row.arrow:SetPoint("RIGHT", 0, 0)
    row.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    AddItemParts(row, 60, 16)
    row:SetScript("OnClick", function(self) KP.Safe(OpenMenu, pane, self) end)
    pane.rows[i] = row
  end
  pane.menu = CreateMenu(pane, width - 10)
  return pane
end

-- one slot's row: your item for it (gold label when it's your own choice), or a dash when the planner has none.
-- Returns whether there's an item and whether you wear it.
local function ShowRow(row, options, chosenID)
  row.options = options
  if not options then
    row.itemID = nil
    row.label:SetText(row.slot.label)
    row.icon:SetTexture(nil)
    row.name:SetText("|cff808080-|r")
    row.src:SetText("")
    row.link:Hide()
    row.arrow:Hide()
    return false, false
  end
  local chosen = ChosenIndex(options, chosenID)
  local id = options[chosen][1]
  local worn = Wearing(row.slot.inv, id)
  ShowItem(row, id, worn)
  row.label:SetText(chosen > 1 and ("|cffffd100" .. row.slot.label .. "|r") or row.slot.label)
  row.arrow:SetShown(#options > 1)
  return true, worn
end

-- build: the chosen build (nil when none)
function Pane.Refresh(pane, build)
  pane.menu:Hide()
  local entry = build and KP.Build.ForLevel(KP.Gear, build.key, UnitLevel("player"))
  if not entry then
    pane.title:SetText(build and "Gear follows the planner's suggested builds" or "Choose a build")
    pane.note:SetText(build and "Choose one on the left to see its gear." or "")
    for _, row in ipairs(pane.rows) do row:Hide() end
    return
  end
  pane.buildKey, pane.gearLevel = build.key, entry.level
  pane.picks = (KorkronPlannerCharDB.gear[build.key] or {})[entry.level] or {}
  local shown, wearing = 0, 0
  for _, row in ipairs(pane.rows) do
    local has, worn = ShowRow(row, entry.items[row.slot.key], pane.picks[row.slot.key])
    shown, wearing = shown + (has and 1 or 0), wearing + (worn and 1 or 0)
    row:Show()
  end
  pane.title:SetText(("Gear for level %d and up: you wear %d of %d"):format(entry.level, wearing, shown))
  pane.note:SetText("Click a slot for its other options and to choose your own (gold). Link = the item's Wowhead page" ..
    ", which says where to get it. " .. TICK .. " = you're wearing it." ..
    (build.path == "pvp" and " PvP: ranked by the planner's questing numbers (it has none for fights against players)." or ""))
end
