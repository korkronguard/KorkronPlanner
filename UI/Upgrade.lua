local _, KP = ...

local Upgrade = {}
KP.Upgrade = Upgrade

local INV = {
  head = { 1 }, neck = { 2 }, shoulder = { 3 }, back = { 15 }, chest = { 5 }, wrist = { 9 }, hands = { 10 },
  waist = { 6 }, legs = { 7 }, feet = { 8 }, finger = { 11, 12 }, trinket = { 13, 14 },
  mainHand = { 16 }, oneHand = { 16 }, twoHand = { 16 }, offHand = { 17 }, heldInOffHand = { 17 }, shield = { 17 },
  ranged = { 18 }, thrown = { 18 }, relic = { 18 },
}
local HAND = { [16] = "mainHand", [17] = "offHand", [18] = "ranged" }
local WEAPON = { mainHand = true, offHand = true, ranged = true }
local OFF_HAND_WEAPON = { oneHand = true, offHand = true }
local GAME_STAT = {
  ITEM_MOD_STRENGTH_SHORT = "strength", ITEM_MOD_AGILITY_SHORT = "agility", ITEM_MOD_STAMINA_SHORT = "stamina",
  ITEM_MOD_INTELLECT_SHORT = "intellect", ITEM_MOD_SPIRIT_SHORT = "spirit", ITEM_MOD_ATTACK_POWER_SHORT = "attackPower",
  ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rangedAttackPower", ITEM_MOD_CRIT_RATING_SHORT = "crit",
  ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_EXPERTISE_RATING_SHORT = "expertise",
  ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
  ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block", ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
  ITEM_MOD_SPELL_POWER_SHORT = "spellPower", ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "spellDamage",
  ITEM_MOD_SPELL_HEALING_DONE_SHORT = "healing", ITEM_MOD_HOLY_DAMAGE_DONE_SHORT = "holyDamage",
  ITEM_MOD_FIRE_DAMAGE_DONE_SHORT = "fireDamage", ITEM_MOD_FROST_DAMAGE_DONE_SHORT = "frostDamage",
  ITEM_MOD_NATURE_DAMAGE_DONE_SHORT = "natureDamage", ITEM_MOD_SHADOW_DAMAGE_DONE_SHORT = "shadowDamage",
  ITEM_MOD_ARCANE_DAMAGE_DONE_SHORT = "arcaneDamage", ITEM_MOD_SPELL_PENETRATION_SHORT = "spellPen",
  ITEM_MOD_MANA_REGENERATION_SHORT = "manaRegen", ITEM_MOD_HEALTH_REGEN_SHORT = "healthRegen",
  ITEM_MOD_ATTACK_POWER_VS_BEAST_SHORT = "attackPowerVsBeasts", ITEM_MOD_ATTACK_POWER_VS_DEMON_SHORT = "attackPowerVsDemons",
  ITEM_MOD_ATTACK_POWER_VS_UNDEAD_SHORT = "attackPowerVsUndead",
  ITEM_MOD_SPELL_DAMAGE_VS_UNDEAD_SHORT = "spellDamageVsUndead", ITEM_MOD_DAGGERS_SHORT = "daggerSkill",
  ITEM_MOD_TWOHANDED_SWORDS_SHORT = "swordSkill", ITEM_MOD_TWOHANDED_AXES_SHORT = "axeSkill",
  ITEM_MOD_TWOHANDED_MACES_SHORT = "maceSkill", ITEM_MOD_FIST_WEAPONS_SHORT = "fistSkill",
}
local DAMAGE = { "v", "DPS", 0.01, "DPS", "damage" }
local HEALING = { "v", "HPS", 0.01, "HPS", "healing" }
local ALSO_DAMAGE = { "d", "DPS", 0.01, "DPS", "damage" }
local SURVIVAL = { "e", "effective HP", 0.5, "eff. HP", "survival" }
local MEASURES = {
  dps = { DAMAGE, SURVIVAL },
  heal = { HEALING, ALSO_DAMAGE, SURVIVAL },
  healSolo = { ALSO_DAMAGE, HEALING, SURVIVAL },
  tank = { SURVIVAL, ALSO_DAMAGE },
}
Upgrade.MEASURES = MEASURES

function Upgrade.Role(build)
  if build.role == "heal" and build.path == "solo" then return "healSolo" end
  return build.role
end
local SHEET_KEY = { strength = "str", agility = "agi", stamina = "sta", intellect = "int", spirit = "spi" }
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

function Upgrade.Number(x)
  local a = math.abs(x)
  local text = a >= 10 and ("%.0f"):format(a) or a >= 1 and ("%.1f"):format(a) or ("%.2g"):format(a)
  return (x < 0 and "-" or "+") .. text
end

function Upgrade.Value(W, key, amount)
  if WEAPON[key] then
    local hand = W[key] or {}
    return { v = amount * (hand[1] or 0), e = amount * (hand[2] or 0), d = amount * (hand[3] or 0) }
  end
  return { v = amount * (W.v[key] or 0), e = amount * (W.e[key] or 0), d = amount * ((W.d or {})[key] or 0) }
end

local function Shown(values, role, small)
  local out = {}
  for _, m in ipairs(MEASURES[role] or MEASURES.dps) do
    local x = values[m[1]]
    if math.abs(x) >= (small or m[3]) then table.insert(out, { x, m }) end
  end
  return out
end

function Upgrade.Describe(values, role, small)
  local out = {}
  for _, s in ipairs(Shown(values, role, small)) do table.insert(out, Upgrade.Number(s[1]) .. " " .. s[2][2]) end
  return #out > 0 and table.concat(out, ", ") or nil
end

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

local function SameItem(a, b)
  local function Key(link)
    local fields = KP.ItemFields(link)
    return fields and fields[1] .. ":" .. KP.ItemBonusIDs(fields)
  end
  local key = Key(a)
  return key ~= nil and key == Key(b)
end

local function GameStats(link)
  local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
  local stats = fn and fn(link)
  return stats and next(stats) and stats or nil
end

local function Parts(id, link, hand)
  local item, parts = KP.Items[id], {}
  if not item then return parts end
  for key, amount in pairs(item.s or {}) do parts[key] = amount end
  for name, amount in pairs(link and GameStats(link) or {}) do
    local key = GAME_STAT[name]
    if key and KP.Readable(amount) and amount then parts[key] = amount end
  end
  if item.a then parts.armor = item.a end
  if item.w then parts[hand] = (item.w[1] + item.w[2]) / 2 / item.w[3] end
  return parts
end

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

local function Better(a, b, role)
  local k = role == "tank" and "v" or (MEASURES[role] or MEASURES.dps)[1][1]
  return a[k] > b[k] or (a[k] == b[k] and a.e > b.e)
end

local function Worn(inv)
  local link = KP.Text(GetInventoryItemLink("player", inv))
  return ItemID(link), link
end

local function WornItem(inv, W)
  local id, link = Worn(inv)
  local parts = id and Parts(id, link, HAND[inv]) or {}
  return { name = link and link:match("%[(.-)%]"), parts = parts, total = Total(W, parts) }
end

local function Replaced(item, link, W, role)
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
    if not out or Better(out.total, worn.total, role) then out = worn end
  end
  return out
end

local tried = setmetatable({}, { __mode = "k" })

local function Hands(item, hand)
  local weapon = KP.Sim.Weapon(item)
  if item[1] == "twoHand" then return weapon and { mh = weapon, oh = false, shield = false } end
  if hand == "mainHand" then return weapon and { mh = weapon } end
  if hand ~= "offHand" then return {} end
  if item[1] == "shield" then return { oh = false } end
  return { oh = weapon or false, shield = false }
end

local function Judged(W, link, item, hand, diff)
  local total = Total(W, diff)
  local hands = W.live and Hands(item, hand)
  if not hands then return total end
  local key = link .. (hand or "")
  local mine = tried[W] or {}
  tried[W] = mine
  mine[key] = mine[key] or KP.StatWeights.TryOn(W, diff, hands)
  local worth = mine[key]
  return worth, { v = worth.v - total.v, e = worth.e - total.e, d = worth.d - total.d }, hands
end

local function OneHandSlot(id, link, W, mainWorn, role)
  local offID = Worn(17)
  local off = offID and KP.Items[offID]
  if not (off and OFF_HAND_WEAPON[off[1]]) then return "mainHand", mainWorn end
  local offWorn, item = WornItem(17, W), KP.Items[id]
  local inMain = Judged(W, link, item, "mainHand", Combine(Parts(id, link, "mainHand"), mainWorn.parts, -1))
  local inOff = Judged(W, link, item, "offHand", Combine(Parts(id, link, "offHand"), offWorn.parts, -1))
  if Better(inOff, inMain, role) then return "offHand", offWorn end
  return "mainHand", mainWorn
end

local function Percent(x, of)
  return Upgrade.Number(x / of * 100) .. "%"
end

local function Change(total, role, base)
  if role == "tank" then return total.v > 0, Upgrade.Number(total.v * 100) .. "%" end
  for i, m in ipairs(MEASURES[role] or MEASURES.dps) do
    local x = total[m[1]]
    if math.abs(x) >= m[3] then return x > 0, Percent(x, base[m[1]]) .. (i > 1 and " " .. m[5] or "") end
  end
end

local function Verdict(total, role, base)
  local shown = Shown(total, role)
  if #shown == 0 then return nil end
  local up, pct = Change(total, role, base)
  local mixed = false
  for _, s in ipairs(shown) do mixed = mixed or (s[1] > 0) ~= up end
  return (up and "Upgrade " or "Downgrade ") .. pct .. (mixed and " overall" or ""), up
end

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
  local role = Upgrade.Role(build)
  local replaced, why, inv = Replaced(item, link, W, role)
  if why == "worn" then
    local parts = Parts(id, link, HAND[inv])
    return { build = build, role = role, W = W, item = item, worn = true, diff = parts, total = Total(W, parts), from = from,
      level = level }
  end
  if why then return nil, why, build end
  local hand = HAND[INV[item[1]][1]]
  if item[1] == "oneHand" then hand, replaced = OneHandSlot(id, link, W, replaced, role) end
  local diff = Combine(Parts(id, link, hand), replaced.parts, -1)
  local total, rest, hands = Judged(W, link, item, hand, diff)
  return { build = build, role = role, W = W, item = item, replaced = replaced, diff = diff, total = total, rest = rest,
    hands = hands, from = from, level = level }
end

function Upgrade.IsUpgrade(link)
  local c = Compare(link)
  if not c or c.worn or c.from > c.level then return false end
  local _, up = Verdict(c.total, c.role, c.W.base)
  return up == true
end

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

local function Notable(rest, total, role)
  for _, m in ipairs(MEASURES[role] or MEASURES.dps) do
    local x = math.abs(rest[m[1]])
    if x >= m[3] and x >= 0.05 * math.abs(total[m[1]]) then return true end
  end
  return false
end

local function Wielding(hands, sheet)
  local out = {}
  local new, old = hands.mh or hands.oh, hands.mh and sheet.mh or hands.oh and sheet.oh
  if new and old and math.abs(new.speed - old.speed) >= 0.05 then
    table.insert(out, ("%.1f sec a swing, yours %.1f"):format(new.speed, old.speed))
  end
  if hands.shield == false and sheet.shield then table.insert(out, "no shield") end
  if hands.oh == false and sheet.oh then table.insert(out, "no off-hand weapon") end
  return #out > 0 and table.concat(out, ", ") or nil
end

local function RestLines(c, role)
  if not (c.rest and Notable(c.rest, c.total, role)) then return {} end
  local wielding = next(c.hands) ~= nil
  local out = { { "  " .. (wielding and "Wielding it" or "Caps and limits"), WHITE, right = Colored(c.rest, role) } }
  local what = wielding and Wielding(c.hands, c.W.ctx.sheet)
  if what then table.insert(out, { "      " .. what, GREY }) end
  return out
end

function Upgrade.Lines(link)
  local c, why, build = Compare(link)
  if not (c or why == "twoHand") then return nil end
  build = c and c.build or build
  local lines = { { "Kor'kron Planner", GOLD, right = "|cff999999" .. build.name:gsub(" %b()", "") .. "|r" } }
  if why == "twoHand" then
    table.insert(lines, { "Your main hand is a two-handed weapon.", GREY })
    return lines
  end
  table.insert(lines, Headline(c, c.role))
  local _, class = UnitClass("player")
  for _, row in ipairs(Breakdown(c.diff, c.W, c.role, class, KP.Sheet.Inputs(class))) do
    table.insert(lines, { "  " .. row.left, WHITE, right = row.right })
    if row.what then table.insert(lines, { "      " .. row.what, GREY }) end
  end
  for _, line in ipairs(RestLines(c, c.role)) do table.insert(lines, line) end
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

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip) KP.Safe(OnItemTooltip, tooltip) end)
else
  for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tooltip:HasScript("OnTooltipSetItem") then
      tooltip:HookScript("OnTooltipSetItem", function(self) KP.Safe(OnItemTooltip, self) end)
    end
  end
end
