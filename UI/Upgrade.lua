-- Kor'kron Planner: upgrade or downgrade on item tooltips (bags, your character, loot, vendors, links in chat). An
-- item's worth to the build you follow is its stats, armor and weapon damage, each times what one point is worth to you
-- (KP.StatWeights.For: from your own sheet where the addon has your class's math, else what the planner website says for
-- that build at your level, Data/Weights.lua, worked out with the planner's best gear for that level on), compared with
-- what you wear in that slot. The tooltip shows the totals (and the change in %) and, stat by
-- stat, what makes the difference; bag items that are an upgrade get an arrow (UI/BagIcons.lua). On an item you wear it
-- shows what that item gives you, stat by stat. Effects ("Chance on hit:", "Use:") and set bonuses aren't counted, and
-- the tooltip says so.
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
-- what the tooltips show for each kind of build: which weight (Data/Weights.lua), its name, the smallest change worth
-- showing, and the short name for the tooltip's right column. A tank's v mixes survival and damage, so its two parts
-- are shown instead (and v decides).
local MEASURES = {
  dps = { { "v", "DPS", 0.01, "DPS" }, { "e", "effective HP", 0.5, "eff. HP" } },
  heal = { { "v", "HPS", 0.01, "HPS" }, { "e", "effective HP", 0.5, "eff. HP" } },
  tank = { { "e", "effective HP", 0.5, "eff. HP" }, { "d", "DPS", 0.01, "DPS" } },
}
Upgrade.MEASURES = MEASURES
-- the main stats' names in Core/Sheet.lua, for what a point of them does
local SHEET_KEY = { strength = "str", agility = "agi", stamina = "sta", intellect = "int", spirit = "spi" }
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
local GOLD = { 1, 0.82, 0 }

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

-- the role's measures big enough to show: { { value, measure }, ... }; small: show smaller changes too
local function Shown(values, role, small)
  local out = {}
  for _, m in ipairs(MEASURES[role] or MEASURES.dps) do
    local x = values[m[1]]
    if math.abs(x) >= (small or m[3]) then table.insert(out, { x, m }) end
  end
  return out
end

-- "+31 effective HP, +0.4 DPS" for a role (nil when each is too small to show)
function Upgrade.Describe(values, role, small)
  local out = {}
  for _, s in ipairs(Shown(values, role, small)) do table.insert(out, Upgrade.Number(s[1]) .. " " .. s[2][2]) end
  return #out > 0 and table.concat(out, ", ") or nil
end

-- the same for a tooltip's right column: short names, green when it goes up, red when down ("" when nothing shows)
local function Colored(values, role)
  local out = {}
  for _, s in ipairs(Shown(values, role)) do
    table.insert(out, (s[1] > 0 and "|cff33ff33" or "|cffff5555") .. Upgrade.Number(s[1]) .. " " .. s[2][4] .. "|r")
  end
  return table.concat(out, "  ")
end

local function ItemID(link)
  return link and tonumber(link:match("item:(%d+)"))
end

-- the same item: same ID and same random bonus ("of the Bear" and "of the Monkey" share an ID)
local function SameItem(a, b)
  local function Key(link)
    local fields = KP.ItemFields(link)
    return fields and fields[1] .. ":" .. KP.ItemBonusIDs(fields)
  end
  local key = Key(a)
  return key ~= nil and key == Key(b)
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

-- what the hovered item would replace (as WornItem gives it), or why there's nothing to compare ("worn" and the slot
-- you wear it in)
local function Replaced(item, link, W)
  local slots = INV[item[1]]
  for _, inv in ipairs(slots) do
    if SameItem(select(2, Worn(inv)), link) then return nil, "worn", inv end
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

-- "+3.2%": x as a share of a number
local function Percent(x, of)
  return Upgrade.Number(x / of * 100) .. "%"
end

-- Whether a change goes up, and how much it is in %: by the build's number, or by survival when that doesn't move.
-- base = the build's number and survival themselves: yours, or with the planner's best gear at your level
-- (Data/Weights.lua); a tank's number is already relative (survival and damage on a log scale), so its change × 100 is the %.
local function Change(total, role, base)
  local main = (MEASURES[role] or MEASURES.dps)[1]
  if role == "tank" then return total.v > 0, Upgrade.Number(total.v * 100) .. "%" end
  if math.abs(total[main[1]]) >= main[3] then return total[main[1]] > 0, Percent(total[main[1]], base[main[1]]) end
  return total.e > 0, Percent(total.e, base.e) .. " survival"
end

-- The word for the whole change and its % (Change); "overall" when some of the numbers shown go the other way. nil: too
-- small to show.
local function Verdict(total, role, base)
  local shown = Shown(total, role)
  if #shown == 0 then return nil end
  local up, pct = Change(total, role, base)
  local mixed = false
  for _, s in ipairs(shown) do mixed = mixed or (s[1] > 0) ~= up end
  return (up and "Upgrade " or "Downgrade ") .. pct .. (mixed and " overall" or ""), up
end

-- What each stat that differs adds, biggest first: { left = "+2 Agility", right = coloured numbers, what = what those
-- points do on your character sheet (main stats; nil when the game hides your numbers) }
local function Breakdown(diff, W, role, class, inputs)
  local rows = {}
  local first = (MEASURES[role] or MEASURES.dps)[1][1]
  for key, amount in pairs(diff) do
    local value = Upgrade.Value(W, key, amount)
    local right = Colored(value, role)
    if right ~= "" and amount ~= 0 then
      local row = { left = ((WEAPON[key] and "%+.1f %s") or "%+.0f %s"):format(amount, STAT_NAME[key] or key),
        right = right, size = math.abs(value[first]) + math.abs(value.e) / 1000 }
      if SHEET_KEY[key] and inputs then
        local what = {}
        for _, effect in ipairs(KP.Sheet.Effects(class, inputs, SHEET_KEY[key])) do
          table.insert(what, KP.Sheet.EffectText(effect, amount))
        end
        row.what = #what > 0 and table.concat(what, ", ") or nil
      end
      table.insert(rows, row)
    end
  end
  table.sort(rows, function(a, b) return a.size > b.size end)
  return rows
end

-- An item against what it would replace, for the build you follow: { build, W (the weights: KP.StatWeights.For), item,
-- replaced (as WornItem gives it), diff (part by part), total, from (the level you can wear it from), level }; for the
-- item you wear, worn = true and diff = all it gives (no replaced); or nil, "twoHand" (an off-hand item while you hold a
-- two-hander) and the build; or nil (no suggested build, an item the planner doesn't know or your class can't use)
local function Compare(link)
  local build = KP.Build.Current()
  local id = ItemID(link)
  local item = id and KP.Items[id]
  if not (build and item) then return nil end
  local _, _, classID = UnitClass("player")
  local can = false
  for _, c in ipairs(item.c) do can = can or c == classID end
  if not can then return nil end
  local level = UnitLevel("player")
  local W = KP.StatWeights.For(build)
  if not W then return nil end
  local from = (item.late and item.late[classID]) or math.max(1, item[2])
  local replaced, why, inv = Replaced(item, link, W)
  if why == "worn" then
    local parts = Parts(id, link, HAND[inv])
    return { build = build, W = W, item = item, worn = true, diff = parts, total = Total(W, parts), from = from, level = level }
  end
  if why then return nil, why, build end
  local hand = HAND[INV[item[1]][1]]
  if item[1] == "oneHand" then hand, replaced = OneHandSlot(id, link, W, replaced) end
  local diff = Combine(Parts(id, link, hand), replaced.parts, -1)
  return { build = build, W = W, item = item, replaced = replaced, diff = diff, total = Total(W, diff), from = from,
    level = level }
end

-- Whether an item is an upgrade for your build that you can wear now (the arrow on bag items, UI/BagIcons.lua)
function Upgrade.IsUpgrade(link)
  local c = Compare(link)
  if not c or c.worn or c.from > c.level then return false end
  local _, up = Verdict(c.total, c.build.role, c.W.base)
  return up == true
end

-- The tooltip's first line under the header: upgrade or downgrade and by how much; for the item you wear, what it's
-- worth to you (as a share of the build's number, like an upgrade's %)
local function Headline(c, role)
  if c.worn then
    if #Shown(c.total, role) == 0 then return { "You wear this: it adds nothing your build counts", GREY } end
    return { "You wear this: worth " .. select(2, Change(c.total, role, c.W.base)), WHITE, right = Colored(c.total, role) }
  end
  local word, up = Verdict(c.total, role, c.W.base)
  local when = c.from > c.level and (" from level " .. c.from) or ""
  if word then return { word .. when, up and GREEN or RED, right = Colored(c.total, role) } end
  return { "About the same as what you wear" .. when, GREY }
end

-- The tooltip lines for an item link: { text, colour } or, in two columns, { text, colour, right = text } (nil:
-- nothing to say)
function Upgrade.Lines(link)
  local c, why, build = Compare(link)
  if not (c or why == "twoHand") then return nil end
  build = c and c.build or build
  local lines = { { "Kor'kron Planner", GOLD, right = "|cff999999" .. build.name:gsub(" %b()", "") .. "|r" } }
  if why == "twoHand" then
    table.insert(lines, { "Your main hand is a two-handed weapon.", GREY })
    return lines
  end
  table.insert(lines, Headline(c, build.role))
  local _, class = UnitClass("player")
  for _, row in ipairs(Breakdown(c.diff, c.W, build.role, class, KP.Sheet.Inputs(class))) do
    table.insert(lines, { "  " .. row.left, WHITE, right = row.right })
    if row.what then table.insert(lines, { "      " .. row.what, GREY }) end
  end
  if not c.worn then
    table.insert(lines, { c.replaced.name and ("vs. your " .. c.replaced.name) or "Your slot is empty.", GREY })
  end
  if c.item.fx then table.insert(lines, { "Its special effect isn't counted.", GREY }) end
  if c.item.set then table.insert(lines, { "Its set bonus isn't counted.", GREY }) end
  return lines
end

local function OnItemTooltip(tooltip)
  if not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  local lines = Upgrade.Lines(KP.Text(link))
  if not lines then return end
  tooltip:AddLine(" ")
  for _, line in ipairs(lines) do
    local r, g, b = line[2][1], line[2][2], line[2][3]
    if line.right then
      tooltip:AddDoubleLine(line[1], line.right, r, g, b, 1, 1, 1)
    else
      tooltip:AddLine(line[1], r, g, b, true)
    end
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
