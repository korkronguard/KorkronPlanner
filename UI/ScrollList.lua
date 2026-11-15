local _, KP = ...

local ScrollList = {}
KP.ScrollList = ScrollList

local SCROLLBAR = 26
ScrollList.ICON = 18

function ScrollList.Create(parent, width, height)
  local pane = CreateFrame("Frame", nil, parent)
  pane:SetSize(width, height)
  local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -SCROLLBAR, 0)
  KP.Style.ScrollBar(scroll)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width - SCROLLBAR, 1)
  scroll:SetScrollChild(content)
  pane.width, pane.content, pane.lines, pane.icons = width - SCROLLBAR, content, {}, {}
  return pane
end

function ScrollList.Layout(pane)
  local L = { y = 0, lines = 0, icons = 0 }
  function L.text(text, font, indent, gap)
    L.lines = L.lines + 1
    local fs = pane.lines[L.lines]
    if not fs then
      fs = pane.content:CreateFontString(nil, "OVERLAY")
      fs:SetJustifyH("LEFT")
      pane.lines[L.lines] = fs
    end
    fs:SetFontObject(font)
    fs:SetWidth(pane.width - indent)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", indent, -(L.y + gap))
    fs:SetText(text)
    fs:Show()
    L.y = L.y + gap + fs:GetStringHeight()
  end
  function L.icon(file, gap)
    L.icons = L.icons + 1
    local tex = pane.icons[L.icons]
    if not tex then
      tex = pane.content:CreateTexture(nil, "ARTWORK")
      tex:SetSize(ScrollList.ICON, ScrollList.ICON)
      pane.icons[L.icons] = tex
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", 0, -(L.y + gap))
    tex:SetTexture(file)
    tex:Show()
  end
  function L.finish()
    for i = L.lines + 1, #pane.lines do pane.lines[i]:Hide() end
    for i = L.icons + 1, #pane.icons do pane.icons[i]:Hide() end
    pane.content:SetHeight(L.y + 8)
  end
  return L
end
