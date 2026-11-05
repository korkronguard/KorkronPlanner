-- Kor'kron Planner: upgrade or downgrade on item tooltips (bags, your character, loot, vendors, links in chat). An
-- item's worth to the build you follow is its stats, armor and weapon damage, each times what the planner website says
-- one point is worth to that build at your level (Data/Weights.lua, worked out with the planner's best gear for that
-- level on), compared with what you wear in that slot. Effects ("Chance on hit:", "Use:") and set bonuses aren't
-- counted, and the tooltip says so.
local _, KP = ...

local Upgrade = {}
KP.Upgrade = Upgrade

-- the inventory slots each kind of item goes in (rings and trinkets: either of two)
local INV = {
  head = { 1 }, neck = { 2 }, shoulder = { 3 }, back = { 15 }, chest = { 5 }, wrist = { 9 }, hands = { 10 },
  waist = { 6 }, legs = { 7 }, feet = { 8 }, finger = { 11, 12 }, trinket = { 13, 14 },
  mainHand = { 16 }, oneHand = { 16 }, twoHand = { 16 }, offHand = { 17 }, heldInOffHand = { 17 }, shield = { 17 },
  ranged = { 18 }, thrown = { 18 }, relic = { 18 },
}
local HAND = { [16] = "mainHand", [17] = "offHand", [18] = "ranged" } -- whose weapon damage weight counts
local OFF_HAND_WEAPON = { oneHand = true, offHand = true }
-- the five main stats come from the game's own reading of the item, which includes random bonuses ("of the Bear")
local PRIMARY = { strength = "ITEM_MOD_STRENGTH_SHORT", agility = "ITEM_MOD_AGILITY_SHORT",
  stamina = "ITEM_MOD_STAMINA_SHORT", intellect = "ITEM_MOD_INTELLECT_SHORT", spirit = "ITEM_MOD_SPIRIT_SHORT" }
local UNIT = { dps = "damage per second", heal = "healing per second" }
local GREEN, RED, GREY = { 0.1, 1, 0.1 }, { 1, 0.25, 0.25 }, { 0.6, 0.6, 0.6 }

local function ItemID(link)
  return link and tonumber(link:match("item:(%d+)"))
end

-- the same item: same ID and same random bonus (the link's 7th number: "of the Bear" and "of the Monkey" share an ID)
local function SameItem(a, b)
  local function Key(link)
    local fields = {}
    for v in ((link and link:match("item:([%-%d:]+)") or "") .. ":"):gmatch("([^:]*):") do table.insert(fields, v) end
    return (fields[1] or "") .. ":" .. (tonumber(fields[7]) or 0)
  end
  return a ~= nil and b ~= nil and Key(a) == Key(b)
end

-- the game's stats for this exact item (nil when it can't say yet, like an item it hasn't loaded). Which of the two
-- functions Forever has isn't known yet (not in the probe), so either will do.
local function GameStats(link)
  local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
  local stats = fn and fn(link)
  return stats and next(stats) and stats or nil
end

-- what an item adds to the build: v = its number (damage or healing per second), e = survival (effective health).
-- hand: which weapon's damage weight counts for it.
local function Worth(id, link, W, hand)
  local item = KP.Items[id]
  if not item then return 0, 0 end
  local v, e = 0, 0
  local function Add(key, amount)
    v, e = v + amount * (W.v[key] or 0), e + amount * (W.e[key] or 0)
  end
  local game = link and GameStats(link)
  for key, amount in pairs(item.s or {}) do
    if not (game and PRIMARY[key]) then Add(key, amount) end
  end
  if game then
    for key, name in pairs(PRIMARY) do
      local amount = game[name]
      if KP.Readable(amount) and amount then Add(key, amount) end
    end
  end
  Add("armor", item.a or 0)
  local weapon = item.w
  if weapon and W[hand] then
    local dps = (weapon[1] + weapon[2]) / 2 / weapon[3]
    v, e = v + dps * W[hand][1], e + dps * W[hand][2]
  end
  return v, e
end

local function Worn(inv)
  local link = KP.Text(GetInventoryItemLink("player", inv))
  return ItemID(link), link
end

-- what you wear in an inventory slot: { id, link, v, e }
local function WornWorth(inv, W)
  local id, link = Worn(inv)
  local v, e = 0, 0
  if id then v, e = Worth(id, link, W, HAND[inv]) end
  return { name = link and link:match("%[(.-)%]"), v = v, e = e }
end

local function Better(a, b)
  return a.v > b.v or (a.v == b.v and a.e > b.e)
end

-- what the hovered item would replace: { name, v, e } (name nil for an empty slot), or why there's nothing to compare
local function Replaced(item, link, W)
  local slots = INV[item[1]]
  for _, inv in ipairs(slots) do
    if SameItem(select(2, Worn(inv)), link) then return nil, "worn" end
  end
  local mainID = Worn(16)
  local main = mainID and KP.Items[mainID]
  if slots[1] == 17 and main and main[1] == "twoHand" then return nil, "twoHand" end
  local out
  if item[1] == "twoHand" then
    local mh, oh = WornWorth(16, W), WornWorth(17, W)
    local name = mh.name and oh.name and (mh.name .. " and " .. oh.name) or mh.name or oh.name
    out = { name = name, v = mh.v + oh.v, e = mh.e + oh.e }
  else
    for _, inv in ipairs(slots) do
      local worn = WornWorth(inv, W)
      if not out or Better(out, worn) then out = worn end -- rings and trinkets: the weaker one
    end
  end
  return out
end

-- the line saying how much better or worse, with its colour
local function Verdict(dv, de, role)
  if role ~= "tank" and math.abs(dv) >= 0.05 then
    return ("%s: %+.1f %s"):format(dv > 0 and "Upgrade" or "Downgrade", dv, UNIT[role] or "damage per second"),
      dv > 0 and GREEN or RED
  end
  if math.abs(de) >= 1 then
    local same = role == "tank" and "" or ("Same " .. (UNIT[role] or "damage per second") .. ", ")
    return ("%s%s%+d effective health"):format(de > 0 and "Upgrade: " or "Downgrade: ", same, math.floor(de + 0.5)),
      de > 0 and GREEN or RED
  end
  return "About the same as what you wear", GREY
end

-- A one-hander goes in the main hand, or, when you dual wield, in whichever hand it does more for: the hand and what
-- it would replace there
local function OneHandSlot(id, link, W, mainWorn)
  local offID = Worn(17)
  local off = offID and KP.Items[offID]
  if not (off and OFF_HAND_WEAPON[off[1]]) then return "mainHand", mainWorn end
  local offWorn = WornWorth(17, W)
  local v1, e1 = Worth(id, link, W, "mainHand")
  local v2, e2 = Worth(id, link, W, "offHand")
  if Better({ v = v2 - offWorn.v, e = e2 - offWorn.e }, { v = v1 - mainWorn.v, e = e1 - mainWorn.e }) then
    return "offHand", offWorn
  end
  return "mainHand", mainWorn
end

-- The tooltip lines for an item link, as { text, colour } (nil: nothing to say)
function Upgrade.Lines(link)
  local build = KP.Build.Current()
  local id = ItemID(link)
  local item = id and KP.Items[id]
  if not (build and item) then return nil end
  local _, _, classID = UnitClass("player")
  local can = false
  for _, c in ipairs(item.c) do can = can or c == classID end
  if not can then return nil end
  local level = UnitLevel("player")
  local W = KP.Build.ForLevel(KP.Weights, build.key, level)
  if not W then return nil end
  local lines = { { "Kor'kron Planner (" .. build.name .. ")", { 1, 0.82, 0 } } }
  local replaced, why = Replaced(item, link, W)
  if why == "worn" then return nil end
  if why == "twoHand" then
    table.insert(lines, { "Your main hand is a two-handed weapon.", GREY })
    return lines
  end
  local hand = HAND[INV[item[1]][1]]
  if item[1] == "oneHand" then hand, replaced = OneHandSlot(id, link, W, replaced) end
  local v, e = Worth(id, link, W, hand)
  local text, colour = Verdict(v - replaced.v, e - replaced.e, build.role)
  local from = (item.late and item.late[classID]) or math.max(1, item[2])
  if from > level then text = ("From level %d: %s"):format(from, text) end
  table.insert(lines, { text, colour })
  table.insert(lines, { replaced.name and ("compared with your " .. replaced.name) or "your slot is empty", GREY })
  if item.fx then table.insert(lines, { "Its special effect isn't counted.", GREY }) end
  if item.set then table.insert(lines, { "Its set bonus isn't counted.", GREY }) end
  return lines
end

local function OnItemTooltip(tooltip)
  if not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  local lines = Upgrade.Lines(KP.Text(link))
  if not lines then return end
  tooltip:AddLine(" ")
  for _, line in ipairs(lines) do
    tooltip:AddLine(line[1], line[2][1], line[2][2], line[2][3], true)
  end
end

-- newer clients announce every item tooltip through TooltipDataProcessor; older ones through OnTooltipSetItem (which
-- of the two Forever has isn't known yet; with neither, the tooltips just stay as they are)
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) KP.Safe(OnItemTooltip, tooltip) end)
else
  for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tooltip:HasScript("OnTooltipSetItem") then
      tooltip:HookScript("OnTooltipSetItem", function(self) KP.Safe(OnItemTooltip, self) end)
    end
  end
end
