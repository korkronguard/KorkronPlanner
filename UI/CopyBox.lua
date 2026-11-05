-- Kor'kron Planner: a small window with one line of text selected, ready for Ctrl+C (the game can't copy to the
-- clipboard or open web pages itself). Used by /kp export and the Gear tab's Wowhead links.
local _, KP = ...

local box

local function Create()
  box = CreateFrame("Frame", "KorkronPlannerCopy", UIParent, "BasicFrameTemplateWithInset")
  box:SetSize(520, 130)
  box:SetPoint("CENTER")
  box:SetFrameStrata("DIALOG") -- over the /kp window
  box:SetMovable(true)
  box:EnableMouse(true)
  box:RegisterForDrag("LeftButton")
  box:SetScript("OnDragStart", box.StartMoving)
  box:SetScript("OnDragStop", box.StopMovingOrSizing)
  box.title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  box.title:SetPoint("TOP", 0, -5)
  box.hint = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  box.hint:SetPoint("TOPLEFT", 14, -32)
  box.hint:SetPoint("RIGHT", -14, 0)
  box.hint:SetJustifyH("LEFT")
  local edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
  edit:SetSize(480, 24)
  edit:SetPoint("TOPLEFT", 20, -70)
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
