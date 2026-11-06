-- Kor'kron Planner: the rotation helper's window. A small movable bar: the big icon is what to press now, the two
-- small ones what comes after (Core/Rotation.lua), each with the game's own cooldown swirl; hovering one shows its
-- Priority line. Off by default (/kp helper, or the switch in /kp); shown in combat or with an enemy targeted.
-- KorkronPlannerCharDB.helper = { on, locked, point = { anchor, x, y } }
local _, KP = ...

local Helper = {}
KP.Helper = Helper

local BIG, SMALL, GAP = 48, 32, 6
local TICK = 0.1 -- seconds between updates while it's on

local frame, ticker
local swirlsStale = true -- a cooldown started or ended: set the swirls again

local function Settings()
  return KorkronPlannerCharDB.helper
end

local function ShowTooltip(icon)
  local item = icon.item
  if not item then return end
  GameTooltip:SetOwner(icon, "ANCHOR_TOP")
  GameTooltip:AddLine(item.name .. (item.tag ~= "" and ("  |cffffd100" .. item.tag .. "|r") or ""))
  if item.text ~= "" then GameTooltip:AddLine(item.text, 1, 1, 1, true) end
  GameTooltip:Show()
end

local function StartMove()
  if not Settings().locked then frame:StartMoving() end
end

local function StopMove()
  frame:StopMovingOrSizing()
  local anchor, _, _, x, y = frame:GetPoint()
  Settings().point = { anchor, x, y }
end

local function CreateIcon(size)
  local icon = CreateFrame("Frame", nil, frame)
  icon:SetSize(size, size)
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetAllPoints()
  icon.swirl = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
  icon.swirl:SetAllPoints()
  -- the icons take the mouse (for their tooltip), so dragging one moves the bar
  icon:EnableMouse(true)
  icon:RegisterForDrag("LeftButton")
  icon:SetScript("OnDragStart", StartMove)
  icon:SetScript("OnDragStop", StopMove)
  icon:SetScript("OnEnter", function(self) KP.Safe(ShowTooltip, self) end)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return icon
end

local function Create()
  frame = CreateFrame("Frame", "KorkronPlannerHelper", UIParent)
  frame:SetSize(BIG + 2 * (GAP + SMALL), BIG)
  local p = Settings().point
  if p then frame:SetPoint(p[1], UIParent, p[1], p[2], p[3]) else frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame.icons = { CreateIcon(BIG), CreateIcon(SMALL), CreateIcon(SMALL) }
  frame.icons[1]:SetPoint("LEFT", frame, "LEFT", 0, 0)
  for i = 2, 3 do frame.icons[i]:SetPoint("BOTTOMLEFT", frame.icons[i - 1], "BOTTOMRIGHT", GAP, 0) end
  frame.note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.note:SetPoint("LEFT", frame, "LEFT", 0, 0)
  frame:Hide()
end

local function Yes(v)
  return KP.Readable(v) and v and true or false
end

-- an enemy you could fight: shown before the pull too, so Charge and your buffs come up
local function EnemyTargeted()
  return Yes(UnitExists("target")) and Yes(UnitCanAttack("player", "target")) and not Yes(UnitIsDead("target"))
end

local function Update()
  local picks, why
  if InCombatLockdown() or EnemyTargeted() then picks, why = KP.Rotation.Picks() end
  frame:SetShown(picks ~= nil or why == "hidden")
  if not frame:IsShown() then return end
  frame.note:SetText(why == "hidden" and "The game hides your spells here." or "")
  for i, icon in ipairs(frame.icons) do
    local pick = picks and picks[i]
    icon.item = pick and pick.item
    icon:SetShown(pick ~= nil)
    if pick and (pick.id ~= icon.id or swirlsStale) then
      icon.id = pick.id
      icon.texture:SetTexture(pick.item.icon)
      -- the game's own cooldown, which it gives a swirl but hides from addons (setting the times would fail)
      icon.swirl:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(pick.id))
    end
  end
  swirlsStale = false
end

-- start or stop updating to match the setting
local function Run()
  if Settings().on and not ticker then
    if not frame then Create() end
    ticker = C_Timer.NewTicker(TICK, function() KP.Safe(Update) end)
  elseif not Settings().on and ticker then
    ticker:Cancel()
    ticker = nil
    frame:Hide()
  end
end

function Helper.IsOn()
  return Settings().on
end

function Helper.SetOn(on)
  if on and not KP.Rotation.ForClass() then
    return KP:Print("the rotation helper isn't ready for your class yet (Warriors and Retribution Paladins so far; " ..
      "the others follow).")
  end
  Settings().on = on
  Run()
  KP.Window.Refresh()
  if not on then return KP:Print("rotation helper off.") end
  KP:Print("rotation helper on: it shows in combat or with an enemy targeted. Big icon = press now, then the next " ..
    "two. Drag it where you like; /kp helper lock keeps it there.")
  if not KP.Rotation.Rules() then
    local build = KP.Build.Current()
    KP:Print(build and build.key and "it doesn't cover your build yet (Paladins: Retribution so far)."
      or "it follows the planner's suggested builds: choose one in /kp.")
  end
end

-- /kp helper [on | off | lock | unlock]: no word switches it on or off
function Helper.Command(word)
  if word == "lock" or word == "unlock" then
    Settings().locked = word == "lock"
    return KP:Print("rotation helper " .. (word == "lock" and "locked in place." or "unlocked: drag it to move it."))
  end
  if word == "on" then return Helper.SetOn(true) end
  if word == "off" then return Helper.SetOn(false) end
  Helper.SetOn(not Settings().on)
end

KP:On("SPELL_UPDATE_COOLDOWN", function() swirlsStale = true end)
KP:On("PLAYER_LOGIN", function()
  Run()
  KP.After(25, function()
    if KorkronPlannerDB.helperNotice or not KP.Rotation.ForClass() then return end
    KorkronPlannerDB.helperNotice = true
    KP:Print("new: a rotation helper shows what to press next for your build (Warriors and Retribution Paladins so " ..
      "far). /kp helper turns it on.")
  end)
end)
