-- Kor'kron Planner: /kp datamine, the owner's check of the planner's data against the game itself. While it's on
-- (account-wide, off by default, not in the help) it asks the game, a few at a time and never in combat or inside an
-- instance, for:
--   items:   every wearable item's stats (KP.Items' IDs), loading each item from the server first (GetItemStats)
--   talents: your class's talent tooltips at every rank (C_Traits.GetTraitDescription)
--   spells:  your spellbook's descriptions with your talents (C_Spell.GetSpellDescription)
-- It all stays in KorkronPlannerDB.datamine on this PC; the planner website's tools/datamine.py compares it with the
-- website's data. Nothing is sent anywhere.
-- KorkronPlannerDB.datamine = { on, build, items = { [item ID] = { [game stat key] = value } or false (no answer) },
--   talents = { [class] = { [node ID] = { spell, ranks = { [rank] = text } } } },
--   spells = { [class] = { level, talents = { [node ID] = rank }, list = { [spell ID] = text } } } }
local _, KP = ...

local Datamine = {}
KP.Datamine = Datamine

local TICK = 0.5   -- seconds between steps
local PER_TICK = 5 -- items asked for per step: 10 a second
local WAIT = 10    -- seconds to wait for the server before an item counts as unanswered

local queue, pending, ticker = {}, {}, nil

local function DB()
  return KorkronPlannerDB.datamine
end

-- the game's item functions: C_Item on newer clients, the old globals otherwise
local function ItemApi(name)
  return (C_Item and C_Item[name]) or _G[name]
end

local function Text(v)
  return KP.Readable(v) and type(v) == "string" and v ~= "" and v or nil
end

-- an item's link if the game has the item loaded (it fetches it from the server when asked)
local function ItemLink(id)
  local _, link = ItemApi("GetItemInfo")(id)
  return Text(link)
end

local function RecordItem(id, link)
  local stats = {}
  for key, value in pairs(ItemApi("GetItemStats")(link) or {}) do
    if KP.Readable(key) and KP.Readable(value) then stats[key] = value end
  end
  DB().items[id] = stats
end

-- answers to earlier requests, then the next few items
local function ItemStep(now)
  for id, since in pairs(pending) do
    local link = ItemLink(id)
    if link then
      RecordItem(id, link)
      pending[id] = nil
    elseif now - since > WAIT then
      DB().items[id] = false -- the server didn't answer: not an item it has
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

-- your class's talents: { [node ID] = { spell, ranks = { [rank] = tooltip } } }, as the game writes them (also
-- Check.lua's)
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

-- every spell in your spellbook (the General tab left out)
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

-- your spellbook's descriptions: { [spell ID] = text } (also Check.lua's)
function Datamine.SpellTexts()
  local list = {}
  for _, id in ipairs(SpellbookIDs()) do list[id] = Text(C_Spell.GetSpellDescription(id)) end
  return list
end

-- with the level and talents they were read at (both change the numbers)
local function ReadSpells()
  local _, class = UnitClass("player")
  DB().spells[class] = { level = UnitLevel("player"), talents = KP.TalentRanks(), list = Datamine.SpellTexts() }
end

local function Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- "8,000 of 8,593 items (12 unanswered), 51 talents, 34 spells"
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
  if InCombatLockdown() or IsInInstance() then return end -- the game can hide values there
  ItemStep(GetTime())
  if #queue == 0 and next(pending) == nil then
    Stop()
    DB().on = false
    KP:Print("datamine done: " .. Summary() .. ". Type /reload so the game saves it, then run the website's tools/datamine.py.")
  end
end

local function Start()
  DB().build = KP.Text((select(2, GetBuildInfo())))
  ReadTalents()
  ReadSpells()
  wipe(queue)
  wipe(pending)
  for id in pairs(KP.Items) do
    if DB().items[id] == nil then table.insert(queue, id) end
  end
  table.sort(queue, function(a, b) return a > b end) -- taken from the end: lowest IDs first
  Stop()
  ticker = C_Timer.NewTicker(TICK, function() KP.Safe(Step) end)
end

-- /kp datamine [clear]: no word switches it on or off (it carries on where it stopped); clear forgets what it read
function Datamine.Command(word)
  if word == "clear" then
    Stop()
    KorkronPlannerDB.datamine = { on = false, items = {}, talents = {}, spells = {} }
    return KP:Print("datamine cleared.")
  end
  DB().on = not DB().on
  if not DB().on then
    Stop()
    return KP:Print("datamine paused: " .. Summary() .. ".")
  end
  Start()
  KP:Print(("datamine on: reading your talents, spells and %d items from the game, 10 a second (about %d minutes; " ..
    "it pauses in combat and inside instances). So far: %s."):format(#queue, math.ceil(#queue / 10 / 60), Summary()))
end

KP:On("PLAYER_LOGIN", function()
  if DB().on then KP.After(15, Start) end -- carries on after a /reload or the next login
end)
