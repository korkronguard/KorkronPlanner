local _, KP = ...

local BagIcons = {}
KP.BagIcons = BagIcons

local function NewArrow(button)
  local arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
  arrow:SetAtlas("bags-greenarrow", true)
  return arrow
end

local function Arrow(button)
  if not button.korkronArrow then
    button.korkronArrow = NewArrow(button)
    button.korkronArrow:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
  end
  return button.korkronArrow
end

local function SafeIsUpgrade(link)
  local upgrade
  KP.Safe(function() upgrade = KP.Upgrade.IsUpgrade(KP.Text(link)) end)
  return upgrade
end

local ellesmereArrows = setmetatable({}, { __mode = "k" })
local function EllesmereArrow(button, data)
  local overlay = button._textOverlay
  if not overlay then return end
  local arrow = ellesmereArrows[button]
  if not arrow then
    arrow = NewArrow(overlay)
    arrow:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", 0, 0)
    ellesmereArrows[button] = arrow
  end
  arrow:SetShown(data.itemLink ~= nil and SafeIsUpgrade(data.itemLink) == true)
end

local function MarkWindow(window)
  for _, button in window:EnumerateValidItems() do
    local link = KP.Text(C_Container.GetContainerItemLink(button:GetBagID(), button:GetID()))
    Arrow(button):SetShown(KP.Upgrade.IsUpgrade(link))
  end
end

local function Windows()
  local list = { ContainerFrameCombinedBags }
  for _, window in ipairs(ContainerFrameContainer.ContainerFrames) do table.insert(list, window) end
  return list
end

function BagIcons.Refresh()
  for _, window in ipairs(Windows()) do
    if window:IsShown() then MarkWindow(window) end
  end
  if Baganator then Baganator.API.RequestItemButtonsRefresh() end
  if EUI_Bags and EUI_Bags:IsVisible() then EUI_Bags:RefreshInventory() end
end

KP:On("PLAYER_LOGIN", function()
  for _, window in ipairs(Windows()) do
    hooksecurefunc(window, "UpdateItems", function(self) KP.Safe(MarkWindow, self) end)
  end
  if Baganator then
    Baganator.API.RegisterUpgradePlugin("Kor'kron Planner", "korkronplanner", SafeIsUpgrade)
    Baganator.API.RegisterCornerWidget("Kor'kron Planner", "korkronplanner",
      function(_, details) return SafeIsUpgrade(details.itemLink) end, NewArrow,
      { corner = "top_right", priority = 1 })
  end
  if EUI_Bags and EUI_Bags.RegisterItemOverlayIcon then
    EUI_Bags.RegisterItemOverlayIcon("Kor'kron Planner", EllesmereArrow)
  end
end)
KP:On("PLAYER_EQUIPMENT_CHANGED", BagIcons.Refresh)
KP:On("PLAYER_LEVEL_UP", function() KP.After(5, BagIcons.Refresh) end)
