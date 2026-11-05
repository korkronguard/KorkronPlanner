-- Kor'kron Planner: sharing snapshots (Snapshot.lua) with the guild's collector: the Guild Master's addon with
-- collector mode on (/kp collect on; the setting is account-wide). Players can stop sharing with /kp share off.
--
-- Guild addon messages (Comm.lua):
--   Q                      collector: "send what you haven't delivered yet" (10 s after login, then every 10 minutes)
--   S^level^i^n^part       player: part i of n of one snapshot's text. Sent in answer to Q (after a random 2-20 s, so
--                          the guild doesn't answer at once), and straight away for a new snapshot while a collector
--                          is around
--   A^guid^level^stamp     collector: stored that snapshot; the player marks it delivered and stops sending it
-- Our own messages come back to us too, and each handler ignores those: a collector never answers Q, only a
-- collector reads S, and an A only counts for the character whose GUID it names.
--
-- The collector keeps KorkronPlannerDB.collected[guid] = { name = sender, levels = { [level] = text } }, the newest
-- snapshot per character and level. Names stay in the collector's saved file; they never go on the website.
local _, KP = ...

local Share = {}
KP.Share = Share
local Comm = KP.Comm

local ASK_EVERY = 600    -- seconds between a collector's questions
local AROUND = 900       -- a collector asked less than this long ago: new snapshots go out straight away
local RESEND_AFTER = 300 -- an undelivered snapshot is sent again after this long
local PART = 230         -- characters of snapshot text per message (the header fills the rest of the 255)

local NOTICE = "shares your character's level, stats, gear and talents with the Kor'kron Guard's planner, so its "
  .. "numbers match the game (never chat, whispers or where you are; names never appear on the website). "
  .. "Type /kp share off to stop."

-- player side -------------------------------------------------------------------------------------------------

local lastAsked                                   -- GetTime() of the last Q we saw
local sentAt = setmetatable({}, { __mode = "k" }) -- [snapshot] = GetTime() it was last sent

local function SendSnapshot(level, snap)
  local text = KP.Snapshot.Text(snap)
  local n = math.ceil(#text / PART)
  for i = 1, n do
    Comm.Send(("S^%d^%d^%d^%s"):format(level, i, n, text:sub((i - 1) * PART + 1, i * PART)))
  end
end

local function SendUndelivered()
  if not KorkronPlannerDB.share or IsInInstance() then return end
  local now = GetTime()
  for level, snap in pairs(KorkronPlannerCharDB.snapshots) do
    if not snap.delivered and (not sentAt[snap] or now - sentAt[snap] >= RESEND_AFTER) then
      sentAt[snap] = now
      SendSnapshot(level, snap)
    end
  end
end

Comm.On("Q", function()
  lastAsked = GetTime()
  if KorkronPlannerDB.collector then return end
  KP.After(math.random(2, 20), SendUndelivered)
end)

Comm.On("A", function(msg)
  local guid, level, stamp = msg:match("^A%^([^%^]+)%^(%d+)%^(%d+)$")
  if not guid or guid ~= KP.Text(UnitGUID("player")) then return end
  local snap = KorkronPlannerCharDB.snapshots[tonumber(level)]
  if snap and snap.stamp == tonumber(stamp) then snap.delivered = true end
end)

-- collector side ----------------------------------------------------------------------------------------------

-- keep a snapshot's text if it's the newest for its character and level; returns guid, level, stamp (nil when the
-- text can't be read)
local function Store(text, from)
  local guid, stamp, level = text:match("^%d+;([^;]+);(%d+);[^;]*;[^;]*;(%d+);")
  if not guid then return end
  stamp, level = tonumber(stamp), tonumber(level)
  local char = KorkronPlannerDB.collected[guid] or { levels = {} }
  KorkronPlannerDB.collected[guid] = char
  char.name = from
  local old = char.levels[level]
  if not old or tonumber(old:match("^%d+;[^;]+;(%d+);")) < stamp then char.levels[level] = text end
  return guid, level, stamp
end

-- the collector's own characters store their snapshots directly
local function StoreOwn()
  local me = KP.Text(UnitName("player")) or "?"
  for _, snap in pairs(KorkronPlannerCharDB.snapshots) do
    if not snap.delivered and Store(KP.Snapshot.Text(snap), me) then snap.delivered = true end
  end
end

local partial = {} -- [sender^level] = { n = parts expected, parts = { ... } }

Comm.On("S", function(msg, sender)
  if not KorkronPlannerDB.collector then return end
  local level, i, n, part = msg:match("^S%^(%d+)%^(%d+)%^(%d+)%^(.*)$")
  if not part then return end
  i, n = tonumber(i), tonumber(n)
  local key = sender .. "^" .. level
  if i == 1 then partial[key] = { n = n, parts = {} } end
  local p = partial[key]
  -- parts arrive in order; after a gap the snapshot is dropped and comes again with the player's next send
  if not p or p.n ~= n or #p.parts ~= i - 1 then
    partial[key] = nil
    return
  end
  p.parts[i] = part
  if i < n then return end
  partial[key] = nil
  local guid, storedLevel, stamp = Store(table.concat(p.parts), sender)
  -- acknowledged even when we already had it, so the player stops resending
  if guid then Comm.Send(("A^%s^%d^%d"):format(guid, storedLevel, stamp)) end
end)

local ticker

local function Ask()
  if not IsInInstance() then Comm.Send("Q") end
end

local function StartCollecting()
  StoreOwn()
  if ticker then return end
  KP.After(10, Ask)
  ticker = C_Timer.NewTicker(ASK_EVERY, function() KP.Safe(Ask) end)
end

-- shared -------------------------------------------------------------------------------------------------------

-- Snapshot.lua calls this after keeping a new snapshot
function Share.Added()
  if KorkronPlannerDB.collector then
    StoreOwn()
  elseif lastAsked and GetTime() - lastAsked < AROUND then
    SendUndelivered()
  end
end

-- /kp share [on|off]
function Share.SetSharing(on)
  if on ~= nil then KorkronPlannerDB.share = on end
  if KorkronPlannerDB.share then
    KP:Print("sharing is on: your addon " .. NOTICE)
  else
    KP:Print("sharing is off: nothing about your characters is sent. /kp share on turns it back on.")
  end
end

-- /kp collect [on|off]: only the Guild Master can turn it on
function Share.SetCollector(on)
  if on then
    local _, _, rankIndex = GetGuildInfo("player")
    if not (KP.Readable(rankIndex) and rankIndex == 0) then
      KP:Print("only the Guild Master can collect.")
      return
    end
    KorkronPlannerDB.collector = true
    StartCollecting()
  elseif on == false then
    KorkronPlannerDB.collector = false
    if ticker then
      ticker:Cancel()
      ticker = nil
    end
  end
  local characters, snapshots = 0, 0
  for _, char in pairs(KorkronPlannerDB.collected) do
    characters = characters + 1
    for _ in pairs(char.levels) do snapshots = snapshots + 1 end
  end
  KP:Print(("collector %s: %d snapshots from %d characters (saved on /reload or logout).")
    :format(KorkronPlannerDB.collector and "on" or "off", snapshots, characters))
end

KP:On("PLAYER_LOGIN", function()
  if not KorkronPlannerDB.shareNotice then
    KorkronPlannerDB.shareNotice = true
    KP.After(15, function() KP:Print("this addon " .. NOTICE) end)
  end
  if KorkronPlannerDB.collector then StartCollecting() end
end)
