-- Kor'kron Planner: upgrade or downgrade on item tooltips (bags, your character, loot, vendors, links in chat). An
-- item's worth to the build you follow is its stats, armor and weapon damage, each times what the planner website says
-- one point is worth to that build at your level (Data/Weights.lua, worked out with the planner's best gear for that
-- level on), compared with what you wear in that slot. The tooltip shows the totals and, stat by stat, what makes the
-- difference. Effects ("Chance on hit:", "Use:") and set bonuses aren't counted, and the tooltip says so.
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
local WEAPON = { mainHand = true, offHand = true, ranged = true }
local OFF_HAND_WEAPON = { oneHand = true, offHand = true }
-- the five main stats come from the game's own reading of the item, which includes random bonuses ("of the Bear")
local PRIMARY = { strength = "ITEM_MOD_STRENGTH_SHORT", agility = "ITEM_MOD_AGILITY_SHORT",
  stamina = "ITEM_MOD_STAMINA_SHORT", intellect = "ITEM_MOD_INTELLECT_SHORT", spirit = "ITEM_MOD_SPIRIT_SHORT" }
-- what the tooltips show for each kind of build: which weight (Data/Weights.lua), its name, and the smallest change
-- worth showing. A tank's v mixes survival and damage, so its two parts are shown instead (and v decides).
local MEASURES = {
  dps = { { "v", "DPS", 0.01 }, { "e", "effective HP", 0.5 } },
  heal = { { "v", "HPS", 0.01 }, { "e", "effective HP", 0.5 } },
  tank = { { "e", "effective HP", 0.5 }, { "d", "DPS", 0.01 } },
}
-- the stats the planner counts, in the order the Formulas tab lists them
Upgrade.STATS = {
  { "strength", "Strength" }, { "agility", "Agility" }, { "stamina", "Stamina" }, { "intellect", "Intellect" },
  { "spirit", "Spirit" }, { "armor", "Armor" }, { "bonusArmor", "Bonus armor" }, { "attackPower", "Attack power" },
  { "rangedAttackPower", "Ranged attack power" }, { "crit", "Crit rating" }, { "hit", "Hit rating" },
  { "expertise", "Expertise rating" }, { "defense", "Defense rating" }, { "dodge", "Dodge rating" },
  { "parry", "Parry rating" }, { "block", "Block rating" }, { "blockValue", "Block value" },
  { "spellPower", "Spell power" }, { "spellDamage", "Spell damage" }, { "healing", "Healing" },
  { "holyDamage", "Holy spell damage" }, { "fireDamage", "Fire spell damage" }, { "frostDamage", "Frost spell damage" },
  { "natureDamage", "Nature spell damage" }, { "shadowDamage", "Shadow spell damage" },
  { "arcaneDamage", "Arcane spell damage" }, { "spellPen", "Spell penetration" }, { "manaRegen", "Mana per 5 sec" },
  { "healthRegen", "Health per 5 sec" }, { "attackPowerVsBeasts", "Attack power vs Beasts" },
  { "attackPowerVsDemons", "Attack power vs Demons" }, { "attackPowerVsUndead", "Attack power vs Undead" },
  { "spellDamageVsUndead", "Spell damage vs Undead" }, { "daggerSkill", "Dagger skill" },
  { "swordSkill", "Sword skill" }, { "axeSkill", "Axe skill" }, { "maceSkill", "Mace skill" },
  { "fistSkill", "Fist weapon skill" },
  { "mainHand", "main-hand weapon DPS" }, { "offHand", "off-hand weapon DPS" }, { "ranged", "ranged weapon DPS" },
}
local STAT_NAME = {}
for _, s in ipairs(Upgrade.STATS) do STAT_NAME[s[1]] = s[2] end
local GREEN, RED, GREY, WHITE = { 0.1, 1, 0.1 }, { 1, 0.25, 0.25 }, { 0.6, 0.6, 0.6 }, { 0.9, 0.9, 0.9 }

-- "+31", "+1.4", "+0.61", "-0.027": two figures for small numbers, so a point's worth still shows
function Upgrade.Number(x)
  local a = math.abs(x)
  local text = a >= 10 and ("%.0f"):format(a) or a >= 1 and ("%.1f"):format(a) or ("%.2g"):format(a)
  return (x < 0 and "-" or "+") .. text
end

-- what an amount of a stat, armor or weapon damage per second (key mainHand / offHand / ranged) adds: { v, e, d }
function Upgrade.Value(W, key, amount)
  if WEAPON[key] then
    local hand = W[key] or {}
    return { v = amount * (hand[1] or 0), e = amount * (hand[2] or 0), d = amount * (hand[3] or 0) }
  end
  return { v = amount * (W.v[key] or 0), e = amount * (W.e[key] or 0), d = amount * ((W.d or {})[key] or 0) }
end

-- "+31 effective HP, +0.4 DPS" for a role (nil when each is too small to show); small: show smaller changes too
function Upgrade.Describe(values, role, small)
  local out = {}
  for _, m in ipairs(MEASURES[role] or MEASURES.dps) do
    local x = values[m[1]]
    if math.abs(x) >= (small or m[3]) then table.insert(out, Upgrade.Number(x) .. " " .. m[2]) end
  end
  return #out > 0 and table.concat(out, ", ") or nil, #out
end

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

-- what the weights count on an item: { [stat, "armor" or the weapon's hand] = amount }
local function Parts(id, link, hand)
  local item, parts = KP.Items[id], {}
  if not item then return parts end
  local game = link and GameStats(link)
  for key, amount in pairs(item.s or {}) do
    if not (game and PRIMARY[key]) then parts[key] = amount end
  end
  if game then
    for key, name in pairs(PRIMARY) do
      local amount = game[name]
      if KP.Readable(amount) and amount then parts[key] = amount end
    end
  end
  if item.a then parts.armor = item.a end
  if item.w then parts[hand] = (item.w[1] + item.w[2]) / 2 / item.w[3] end
  return parts
end

-- a + sign × b, part by part
local function Combine(a, b, sign)
  local out = {}
  for key, amount in pairs(a) do out[key] = amount end
  for key, amount in pairs(b) do out[key] = (out[key] or 0) + sign * amount end
  return out
end

local function Total(W, parts)
  local total = { v = 0, e = 0, d = 0 }
  for key, amount in pairs(parts) do
    local value = Upgrade.Value(W, key, amount)
    for m, x in pairs(value) do total[m] = total[m] + x end
  end
  return total
end

local function Better(a, b)
  return a.v > b.v or (a.v == b.v and a.e > b.e)
end

local function Worn(inv)
  local link = KP.Text(GetInventoryItemLink("player", inv))
  return ItemID(link), link
end

-- what you wear in an inventory slot: { name (nil when empty), parts, total }
local function WornItem(inv, W)
  local id, link = Worn(inv)
  local parts = id and Parts(id, link, HAND[inv]) or {}
  return { name = link and link:match("%[(.-)%]"), parts = parts, total = Total(W, parts) }
end

-- what the hovered item would replace (as WornItem gives it), or why there's nothing to compare
local function Replaced(item, link, W)
  local slots = INV[item[1]]
  for _, inv in ipairs(slots) do
    if SameItem(select(2, Worn(inv)), link) then return nil, "worn" end
  end
  local mainID = Worn(16)
  local main = mainID and KP.Items[mainID]
  if slots[1] == 17 and main and main[1] == "twoHand" then return nil, "twoHand" end
  if item[1] == "twoHand" then
    local mh, oh = WornItem(16, W), WornItem(17, W)
    local parts = Combine(mh.parts, oh.parts, 1)
    return { name = mh.name and oh.name and (mh.name .. " and " .. oh.name) or mh.name or oh.name, parts = parts,
      total = Total(W, parts) }
  end
  local out
  for _, inv in ipairs(slots) do
    local worn = WornItem(inv, W)
    if not out or Better(out.total, worn.total) then out = worn end -- rings and trinkets: the weaker one
  end
  return out
end

-- A one-hander goes in the main hand, or, when you dual wield, in whichever hand it does more for: the hand and what
-- it would replace there
local function OneHandSlot(id, link, W, mainWorn)
  local offID = Worn(17)
  local off = offID and KP.Items[offID]
  if not (off and OFF_HAND_WEAPON[off[1]]) then return "mainHand", mainWorn end
  local offWorn = WornItem(17, W)
  local inMain = Total(W, Combine(Parts(id, link, "mainHand"), mainWorn.parts, -1))
  local inOff = Total(W, Combine(Parts(id, link, "offHand"), offWorn.parts, -1))
  if Better(inOff, inMain) then return "offHand", offWorn end
  return "mainHand", mainWorn
end

-- the line saying better or worse: by the build's number, or by survival when that doesn't move (a tank: its v)
local function Verdict(total, role)
  local text = Upgrade.Describe(total, role)
  if not text then return "About the same as what you wear", GREY end
  local main = (MEASURES[role] or MEASURES.dps)[1]
  local up
  if role == "tank" then
    up = total.v > 0
  elseif math.abs(total[main[1]]) >= main[3] then
    up = total[main[1]] > 0
  else
    up = total.e > 0
  end
  return (up and "Upgrade: " or "Downgrade: ") .. text, up and GREEN or RED
end

-- "  +81 Armor -> +31 effective HP (0.38 each)": what each stat that differs adds, biggest first
local function Breakdown(diff, W, role)
  local lines = {}
  for key, amount in pairs(diff) do
    local value = Upgrade.Value(W, key, amount)
    local text, shown = Upgrade.Describe(value, role)
    if text and amount ~= 0 then
      local label = ((WEAPON[key] and "%+.1f %s") or "%+.0f %s"):format(amount, STAT_NAME[key] or key)
      if shown == 1 and math.abs(amount) ~= 1 then
        for _, m in ipairs(MEASURES[role] or MEASURES.dps) do
          if math.abs(value[m[1]]) >= m[3] then
            text = text .. " (" .. Upgrade.Number(value[m[1]] / amount):gsub("^%+", "") .. " each)"
          end
        end
      end
      local first = (MEASURES[role] or MEASURES.dps)[1][1]
      table.insert(lines, { "  " .. label .. " -> " .. text, math.abs(value[first]) + math.abs(value.e) / 1000 })
    end
  end
  table.sort(lines, function(a, b) return a[2] > b[2] end)
  return lines
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
  local diff = Combine(Parts(id, link, hand), replaced.parts, -1)
  local text, colour = Verdict(Total(W, diff), build.role)
  local from = (item.late and item.late[classID]) or math.max(1, item[2])
  if from > level then text = ("From level %d: %s"):format(from, text) end
  table.insert(lines, { text, colour })
  for _, line in ipairs(Breakdown(diff, W, build.role)) do table.insert(lines, { line[1], WHITE }) end
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
