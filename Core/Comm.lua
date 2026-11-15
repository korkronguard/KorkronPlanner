local _, KP = ...

local Comm = {}
KP.Comm = Comm

local PREFIX = "KorkronPlanner"
local MAX_MESSAGE = 255
local CPS, BURST, OVERHEAD = 800, 2000, 25
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
    table.remove(queue, 1)
    if THROTTLED[C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD")] then
      table.insert(queue, 1, msg)
      bucket = 0
      return
    end
    bucket = bucket - cost
  end
  frame:Hide()
end

local pump = CreateFrame("Frame")
pump:Hide()
pump:SetScript("OnUpdate", function(frame, elapsed) KP.Safe(Pump, frame, elapsed) end)

function Comm.Send(msg)
  if not IsInGuild() then return end
  assert(#msg <= MAX_MESSAGE, "addon message too long")
  table.insert(queue, msg)
  pump:Show()
end

local handlers = {}

function Comm.On(command, fn)
  handlers[command] = fn
end

local PART = 230

function Comm.SendLong(tag, key, text)
  local n = math.ceil(#text / PART)
  for i = 1, n do
    Comm.Send(("%s^%s^%d^%d^%s"):format(tag, key, i, n, text:sub((i - 1) * PART + 1, i * PART)))
  end
end

function Comm.OnLong(tag, fn)
  local partial = {}
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
  prefix, msg, channel, sender = KP.Text(prefix), KP.Text(msg), KP.Text(channel), KP.Text(sender)
  if prefix ~= PREFIX or channel ~= "GUILD" or not msg or not sender then return end
  local handler = handlers[msg:match("^[^%^]+")]
  if handler then handler(msg, sender) end
end)
