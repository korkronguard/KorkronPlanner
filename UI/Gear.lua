local _, KP = ...

local Pane = {}
KP.GearPane = Pane

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
local WOWHEAD = "https://www.wowhead.com/forever/item=%d"
local ROW, OPTION, PAD = 22, 20, 10
local PRE_RAID_ILVL = 63
local Style = KP.Style

local function Text(parent, font, width, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  if width then fs:SetWidth(width) end
  return fs
end

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

local function AddItemParts(row, left, right)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", left, 0)
  row.link = CreateFrame("Button", nil, row)
  row.link:SetSize(36, 16)
  Style.Button(row.link)
  row.link:SetPoint("RIGHT", -right, 0)
  row.link:SetText("Link")
  row.link:SetScript("OnClick", function() KP.Safe(ShowLink, row.itemID) end)
  row.src = Text(row, "KorkronPlannerFontHighlightSmall", 62, "RIGHT")
  row.src:SetPoint("RIGHT", row.link, "LEFT", -4, 0)
  row.name = Text(row, "KorkronPlannerFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.name:SetPoint("RIGHT", row.src, "LEFT", -4, 0)
  row.name:SetWordWrap(false)
  local gold = Style.COLOR.gold
  local lit = row:CreateTexture(nil, "HIGHLIGHT")
  lit:SetAllPoints()
  lit:SetColorTexture(gold[1], gold[2], gold[3], 0.12)
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

local function ChosenIndex(options, chosenID)
  for i, option in ipairs(options) do
    if option[1] == chosenID then return i end
  end
  return 1
end

local function Choose(pane, i)
  local row, gear = pane.menu.row, KorkronPlannerCharDB.gear
  gear[pane.buildKey] = gear[pane.buildKey] or {}
  local byLevel = gear[pane.buildKey]
  byLevel[pane.gearKey] = byLevel[pane.gearKey] or {}
  byLevel[pane.gearKey][row.slot.key] = i > 1 and row.options[i][1] or nil
  KP.Window.Refresh()
end

local function MenuLine(pane, i)
  local menu = pane.menu
  if menu.lines[i] then return menu.lines[i] end
  local line = CreateFrame("Button", nil, menu)
  line:SetSize(menu:GetWidth() - 2 * PAD, OPTION)
  line:SetPoint("TOPLEFT", menu.title, "BOTTOMLEFT", 0, -4 - (i - 1) * OPTION)
  line.check = Style.Tick(line, 14)
  line.check:SetPoint("LEFT", 0, 0)
  line.pct = Text(line, "KorkronPlannerFontHighlightSmall", 32, "RIGHT")
  line.pct:SetPoint("LEFT", 14, 0)
  AddItemParts(line, 50, 0)
  line:SetScript("OnClick", function() KP.Safe(Choose, pane, i) end)
  menu.lines[i] = line
  return line
end

local function CreateMenu(pane, width)
  local menu = CreateFrame("Frame", nil, pane, "BackdropTemplate")
  Style.Panel(menu)
  menu:SetWidth(width)
  menu:SetFrameStrata("HIGH")
  menu:SetClampedToScreen(true)
  menu:EnableMouse(true)
  menu.title = Text(menu, "KorkronPlannerFontNormalSmall", width - 2 * PAD - 20)
  menu.title:SetPoint("TOPLEFT", PAD, -PAD)
  Style.CloseButton(menu):SetPoint("TOPRIGHT", -6, -6)
  menu.lines = {}
  menu:Hide()
  return menu
end

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
  pane.title = Text(pane, "KorkronPlannerFontNormalLarge", width - 160)
  pane.title:SetPoint("TOPLEFT", 0, 0)
  pane.switch = CreateFrame("Button", nil, pane)
  pane.switch:SetSize(140, 18)
  Style.Button(pane.switch)
  pane.switch:SetPoint("TOPRIGHT", -10, 0)
  pane.switch:SetScript("OnClick", function()
    KorkronPlannerCharDB.gearRaid = not KorkronPlannerCharDB.gearRaid or nil
    KP.Window.Refresh()
  end)
  pane.note = Text(pane, "KorkronPlannerFontDisableSmall", width - 10)
  pane.note:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
  pane.rows = {}
  for i, slot in ipairs(SLOTS) do
    local row = CreateFrame("Button", nil, pane)
    row.index, row.slot = i, slot
    row:SetSize(width - 10, ROW)
    row:SetPoint("TOPLEFT", pane.note, "BOTTOMLEFT", 0, -6 - (i - 1) * ROW)
    row.label = Text(row, "KorkronPlannerFontDisableSmall", 58)
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

function Pane.Refresh(pane, build)
  pane.menu:Hide()
  local entry = build and KP.Build.ForLevel(KP.Gear, build.key, UnitLevel("player"))
  if not entry then
    pane.title:SetText(build and "Gear follows the planner's suggested builds" or "Choose a build")
    pane.note:SetText(build and "Choose one on the left to see its gear." or "")
    for _, row in ipairs(pane.rows) do row:Hide() end
    pane.switch:Hide()
    return
  end
  local pre = entry.pre ~= nil and not KorkronPlannerCharDB.gearRaid
  pane.buildKey, pane.gearKey = build.key, pre and (entry.level .. " pre-raid") or entry.level
  pane.picks = (KorkronPlannerCharDB.gear[build.key] or {})[pane.gearKey] or {}
  local shown, wearing = 0, 0
  for _, row in ipairs(pane.rows) do
    local has, worn = ShowRow(row, (pre and entry.pre or entry.items)[row.slot.key], pane.picks[row.slot.key])
    shown, wearing = shown + (has and 1 or 0), wearing + (worn and 1 or 0)
    row:Show()
  end
  pane.switch:SetShown(entry.pre ~= nil)
  pane.switch:SetText(pre and "Show raid gear" or "Show pre-raid gear")
  pane.title:SetText((pre and "Pre-raid gear" or ("Gear for level %d and up"):format(entry.level)) ..
    (": you wear %d of %d"):format(wearing, shown))
  pane.note:SetText("Click a slot for its other options and to choose your own (gold). Link = the item's Wowhead page" ..
    ", which says where to get it. " .. TICK .. " = you're wearing it." ..
    (pre and " Pre-raid: items of item level " .. PRE_RAID_ILVL .. " and under, Dungeon Set 2 and three level 65 items " ..
      "(dungeons, quests, crafting, reputation; no raid rewards)." or "") ..
    (entry.floors and (" Reaches %d%% hit and %d%% expertise first, then the most survival and damage."):format(
      entry.floors.hit, entry.floors.expertise) or "") ..
    (build.path == "pvp" and " PvP: ranked by the planner's questing numbers (it has none for fights against players)." or ""))
end
