-- Kor'kron Planner: a green arrow on the items in your bags that are an upgrade for your build and that you can wear
-- now (UI/Upgrade.lua decides, as on the tooltip). In the game's own bag windows it's our own arrow in each slot's top
-- right corner: the game's arrow on the left is switched by other addons (Pawn, RXPGuides). Baganator replaces those
-- windows: there the arrow is one of its corner icons (top right unless the player moves it), and the Planner is also
-- an upgrade source for its searches.
local _, KP = ...

local BagIcons = {}
KP.BagIcons = BagIcons

local function NewArrow(button)
  local arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
  arrow:SetAtlas("bags-greenarrow", true)
  return arrow
end

-- the arrow on a game bag slot (made the first time it's needed)
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

local function MarkWindow(window)
  for _, button in window:EnumerateValidItems() do
    local link = KP.Text(C_Container.GetContainerItemLink(button:GetBagID(), button:GetID()))
    Arrow(button):SetShown(KP.Upgrade.IsUpgrade(link))
  end
end

-- every bag window the game has: the combined bag and one per bag (ContainerFrame.lua)
local function Windows()
  local list = { ContainerFrameCombinedBags }
  for _, window in ipairs(ContainerFrameContainer.ContainerFrames) do table.insert(list, window) end
  return list
end

-- your build, level or gear changed: mark the open bags again
function BagIcons.Refresh()
  for _, window in ipairs(Windows()) do
    if window:IsShown() then MarkWindow(window) end
  end
  if Baganator then Baganator.API.RequestItemButtonsRefresh() end
end

KP:On("PLAYER_LOGIN", function()
  -- the game refreshes a window's slots in UpdateItems (on opening it, looting, moving items): mark them after it
  for _, window in ipairs(Windows()) do
    hooksecurefunc(window, "UpdateItems", function(self) KP.Safe(MarkWindow, self) end)
  end
  if Baganator then
    -- the upgrade source only answers Baganator's searches; the arrow you see is the corner icon
    Baganator.API.RegisterUpgradePlugin("Kor'kron Planner", "korkronplanner", SafeIsUpgrade)
    Baganator.API.RegisterCornerWidget("Kor'kron Planner", "korkronplanner",
      function(_, details) return SafeIsUpgrade(details.itemLink) end, NewArrow,
      { corner = "top_right", priority = 1 })
  end
end)
KP:On("PLAYER_EQUIPMENT_CHANGED", BagIcons.Refresh)
KP:On("PLAYER_LEVEL_UP", function() KP.After(5, BagIcons.Refresh) end) -- UnitLevel lags behind the event
