-- Kor'kron Planner: guild addon messages. Sending goes through a queue with Kor'kron Roster's bandwidth budget
-- (~800 bytes a second, like ChatThrottleLib), so a long answer never floods the guild channel.
local _, KP = ...

local Comm = {}
KP.Comm = Comm

local PREFIX = "KorkronPlanner"
local MAX_MESSAGE = 255
local CPS, BURST, OVERHEAD = 800, 2000, 25
-- Enum.SendAddonMessageResult values that mean "try again later" (AddonMessageThrottle, ChannelThrottle)
local THROTTLED = { [3] = true, [8] = true }

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local queue = {}
local bucket = BURST

local function Pump(frame, elapsed)
  bucket = math.min(BURST, bucket + CPS * elapsed)
  while queue[1] do
    local msg = queue[1]
    local cost = #msg + OVERHEAD
    if bucket < cost then return end
    -- taken off the queue before sending, so a message the game rejects with an error isn't retried every frame
    table.remove(queue, 1)
    if THROTTLED[C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD")] then
      table.insert(queue, 1, msg)
      bucket = 0 -- the server pushed back; retry once the bucket refills
      return
    end
    bucket = bucket - cost
  end
  frame:Hide()
end

local pump = CreateFrame("Frame")
pump:Hide()
pump:SetScript("OnUpdate", function(frame, elapsed) KP.Safe(Pump, frame, elapsed) end)

-- Queue a message for the guild channel (nothing happens outside a guild)
function Comm.Send(msg)
  if not IsInGuild() then return end
  assert(#msg <= MAX_MESSAGE, "addon message too long")
  table.insert(queue, msg)
  pump:Show()
end

-- Receiving: Comm.On("Q", function(msg, sender) end) gets every guild message whose first "^" field is "Q".
-- The guild channel also delivers our own messages back to us.
local handlers = {}

function Comm.On(command, fn)
  handlers[command] = fn
end

-- Long texts (a snapshot, a talent and spell check) in parts: "tag^key^i^n^part", PART characters each.
-- Comm.OnLong(tag, function(key, text, sender) end) gets the whole text once its last part is in. Parts arrive in
-- order; after a gap the text is dropped, and the sender's next try brings it whole.
local PART = 230

function Comm.SendLong(tag, key, text)
  local n = math.ceil(#text / PART)
  for i = 1, n do
    Comm.Send(("%s^%s^%d^%d^%s"):format(tag, key, i, n, text:sub((i - 1) * PART + 1, i * PART)))
  end
end

function Comm.OnLong(tag, fn)
  local partial = {} -- [sender^key] = { n = parts expected, parts = { ... } }
  Comm.On(tag, function(msg, sender)
    local key, i, n, part = msg:match("^[^%^]+%^([^%^]+)%^(%d+)%^(%d+)%^(.*)$")
    if not part then return end
    i, n = tonumber(i), tonumber(n)
    local id = sender .. "^" .. key
    if i == 1 then partial[id] = { n = n, parts = {} } end
    local p = partial[id]
    if not p or p.n ~= n or #p.parts ~= i - 1 then
      partial[id] = nil
      return
    end
    p.parts[i] = part
    if i < n then return end
    partial[id] = nil
    fn(key, table.concat(p.parts), sender)
  end)
end

KP:On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
  -- the game can hide these inside instances; a hidden message can't be read, so it's skipped
  prefix, msg, channel, sender = KP.Text(prefix), KP.Text(msg), KP.Text(channel), KP.Text(sender)
  if prefix ~= PREFIX or channel ~= "GUILD" or not msg or not sender then return end
  local handler = handlers[msg:match("^[^%^]+")]
  if handler then handler(msg, sender) end
end)
