-- Kor'kron Planner: a small window with one line of text selected, ready for Ctrl+C (the game can't copy to the
-- clipboard or open web pages itself). Used by /kp export and the Gear tab's Wowhead links.
local _, KP = ...

local box

local function Create()
  local Style = KP.Style
  box = CreateFrame("Frame", "KorkronPlannerCopy", UIParent)
  box:SetSize(520, 138)
  box:SetPoint("CENTER")
  box:SetFrameStrata("DIALOG") -- over the /kp window
  box:SetMovable(true)
  box:EnableMouse(true)
  box:RegisterForDrag("LeftButton")
  box:SetScript("OnDragStart", box.StartMoving)
  box:SetScript("OnDragStop", box.StopMovingOrSizing)
  Style.Window(box, "")
  box.hint = box:CreateFontString(nil, "OVERLAY", "KorkronPlannerFontNormalSmall")
  box.hint:SetPoint("TOPLEFT", 14, Style.TOP - 2)
  box.hint:SetPoint("RIGHT", -14, 0)
  box.hint:SetJustifyH("LEFT")
  local edit = CreateFrame("EditBox", nil, box, "BackdropTemplate")
  Style.EditBox(edit)
  edit:SetSize(488, 24)
  edit:SetPoint("TOPLEFT", 16, Style.TOP - 40)
  edit:SetAutoFocus(true)
  edit:SetScript("OnEscapePressed", function() box:Hide() end)
  -- typing puts the text back, so what gets copied is always the whole line
  edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(box.text); self:HighlightText() end end)
  box.edit = edit
end

function KP.CopyBox(title, hint, text)
  if not box then Create() end
  box.title:SetText(title)
  box.hint:SetText(hint)
  box.text = text
  box.edit:SetText(text)
  box:Show()
  box.edit:SetFocus()
  box.edit:HighlightText()
end
