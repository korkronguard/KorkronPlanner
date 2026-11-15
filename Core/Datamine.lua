local _, KP = ...

local Datamine = {}
KP.Datamine = Datamine

local TICK = 0.5
local PER_TICK = 5
local WAIT = 10

local queue, pending, ticker = {}, {}, nil

local function DB()
  return KorkronPlannerDB.datamine
end

local function ItemApi(name)
  return (C_Item and C_Item[name]) or _G[name]
end

local function Text(v)
  return KP.Readable(v) and type(v) == "string" and v ~= "" and v or nil
end

local function ItemLink(id)
  local _, link = ItemApi("GetItemInfo")(id)
  return Text(link)
end

local function IsShield(id)
  return KP.Items[id] and KP.Items[id][1] == "shield"
end

local function BlockPattern()
  return "^" .. (SHIELD_BLOCK_TEMPLATE or "%d Block"):gsub("%%[ds]", "(%%d+)") .. "$"
end

local scanner
local function ShieldBlock(link)
  scanner = scanner or CreateFrame("GameTooltip", "KorkronPlannerScanTooltip", nil, "GameTooltipTemplate")
  scanner:SetOwner(UIParent, "ANCHOR_NONE")
  scanner:SetHyperlink(link)
  local pattern = BlockPattern()
  local block = 0
  for i = 1, scanner:NumLines() do
    local text = Text(_G["KorkronPlannerScanTooltipTextLeft" .. i]:GetText())
    local n = text and text:match(pattern)
    if n then block = tonumber(n) break end
  end
  scanner:Hide()
  return block
end

local function RecordItem(id, link)
  local stats = {}
  for key, value in pairs(ItemApi("GetItemStats")(link) or {}) do
    if KP.Readable(key) and KP.Readable(value) then stats[key] = value end
  end
  if IsShield(id) then stats.SHIELD_BLOCK = ShieldBlock(link) end
  DB().items[id] = stats
end

local function ItemStep(now)
  for id, since in pairs(pending) do
    local link = ItemLink(id)
    if link then
      RecordItem(id, link)
      pending[id] = nil
    elseif now - since > WAIT then
      DB().items[id] = false
      pending[id] = nil
    end
  end
  local request = ItemApi("RequestLoadItemDataByID")
  for _ = 1, math.min(PER_TICK, #queue) do
    local id = table.remove(queue)
    local link = ItemLink(id)
    if link then
      RecordItem(id, link)
    else
      if request then request(id) end
      pending[id] = now
    end
  end
end

function Datamine.TalentTexts(class)
  local configID = C_ClassTalents.GetActiveConfigID()
  local out = {}
  for _, t in ipairs(KP.Talents[class] or {}) do
    local node = C_Traits.GetNodeInfo(configID, t.id)
    local entryID = node and node.entryIDs and node.entryIDs[1]
    if KP.Readable(entryID) and entryID then
      local entry = C_Traits.GetEntryInfo(configID, entryID)
      local definition = entry and C_Traits.GetDefinitionInfo(entry.definitionID)
      local ranks = {}
      for rank = 1, t.ranks do ranks[rank] = Text(C_Traits.GetTraitDescription(entryID, rank)) end
      out[t.id] = { spell = definition and definition.spellID, ranks = ranks }
    end
  end
  return out
end

local function ReadTalents()
  local _, class = UnitClass("player")
  DB().talents[class] = Datamine.TalentTexts(class)
end

local function SpellbookIDs()
  local ids = {}
  for line = 2, C_SpellBook.GetNumSpellBookSkillLines() do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
    for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
      local item = C_SpellBook.GetSpellBookItemInfo(slot, Enum.SpellBookSpellBank.Player)
      if item and KP.Readable(item.spellID) and item.spellID then table.insert(ids, item.spellID) end
    end
  end
  return ids
end

function Datamine.SpellTexts()
  local list = {}
  for _, id in ipairs(SpellbookIDs()) do list[id] = Text(C_Spell.GetSpellDescription(id)) end
  return list
end

local function ReadSpells()
  local _, class = UnitClass("player")
  DB().spells[class] = { level = UnitLevel("player"), talents = KP.TalentRanks(), list = Datamine.SpellTexts() }
end

local function Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function GameBuild()
  return KP.Text((select(2, GetBuildInfo())))
end

local function NeedsReading(id)
  local stats = DB().items[id]
  return stats == nil
    or (stats and IsShield(id) and (stats.SHIELD_BLOCK == nil or DB().blockPattern ~= BlockPattern()))
end

local function Unread()
  local n = 0
  for id in pairs(KP.Items) do
    if NeedsReading(id) then n = n + 1 end
  end
  return n
end

local function Summary()
  local _, class = UnitClass("player")
  local done, unanswered = 0, 0
  for _, stats in pairs(DB().items) do
    done = done + 1
    if stats == false then unanswered = unanswered + 1 end
  end
  return ("%d of %d items (%d unanswered), %d talents, %d spells"):format(done, Count(KP.Items), unanswered,
    Count(DB().talents[class] or {}), Count((DB().spells[class] or {}).list or {}))
end

local function Stop()
  if ticker then ticker:Cancel() end
  ticker = nil
end

local function Step()
  if InCombatLockdown() or IsInInstance() then return end
  ItemStep(GetTime())
  if #queue == 0 and next(pending) == nil then
    Stop()
    DB().on = false
    DB().blockPattern = BlockPattern()
    KP:Print("datamine done: " .. Summary() .. ". Type /reload so the game saves it, then run the website's tools/datamine.py.")
  end
end

local function Start()
  DB().build = GameBuild()
  ReadTalents()
  ReadSpells()
  wipe(queue)
  wipe(pending)
  for id in pairs(KP.Items) do
    if NeedsReading(id) then table.insert(queue, id) end
  end
  table.sort(queue, function(a, b) return a > b end)
  Stop()
  ticker = C_Timer.NewTicker(TICK, function() KP.Safe(Step) end)
end

function Datamine.Command(word)
  if word == "clear" then
    Stop()
    KorkronPlannerDB.datamine = { on = false, items = {}, talents = {}, spells = {} }
    return KP:Print("datamine cleared: it no longer starts by itself (/kp datamine starts it again).")
  end
  DB().on = not DB().on
  if not DB().on then
    Stop()
    return KP:Print("datamine paused until your next login: " .. Summary() .. ".")
  end
  Start()
  KP:Print(("datamine on: reading your talents, spells and %d items from the game, 10 a second (about %d minutes; " ..
    "it pauses in combat and inside instances). So far: %s."):format(#queue, math.ceil(#queue / 10 / 60), Summary()))
end

KP:On("PLAYER_LOGIN", function()
  local db, build = DB(), GameBuild()
  if not db.build then return end
  if build ~= db.build then
    KP:Print(("datamine: new game build %s (was %s), so it reads everything again."):format(build, db.build))
    KorkronPlannerDB.datamine = { on = true, items = {}, talents = {}, spells = {} }
  elseif not db.on and Unread() > 0 then
    KP:Print(("datamine: %d items not read yet, so it reads them."):format(Unread()))
    db.on = true
  end
  if DB().on then KP.After(15, Start) end
end)
