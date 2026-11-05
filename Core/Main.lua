-- Kor'kron Planner: saved settings and slash commands.
local ADDON, KP = ...

-- account-wide: share = send snapshots to the guild's collector; collector = this account collects (owner only)
local DEFAULTS = { debug = false, share = true, collector = false, collected = {} }

KP:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  KorkronPlannerDB = KorkronPlannerDB or {}
  for k, v in pairs(DEFAULTS) do
    if KorkronPlannerDB[k] == nil then KorkronPlannerDB[k] = v end
  end
  KorkronPlannerCharDB = KorkronPlannerCharDB or {}
  KorkronPlannerCharDB.snapshots = KorkronPlannerCharDB.snapshots or {}
  KorkronPlannerCharDB.gear = KorkronPlannerCharDB.gear or {} -- your own gear choices (UI/Gear.lua)
end)

local HELP = {
  "/kp - your build: the next talent to take and the points after it",
  "/kp export - your stats as a code for the planner website",
  "/kp share - whether your stats are shared with the guild planner (/kp share off stops it, /kp share on starts it)",
  "/kp probe - check what the game lets the addon read (for the addon's author)",
  "/kp errors - show errors the addon ran into (/kp errors clear empties the list)",
}

local SWITCH = { on = true, off = false } -- no word = nil: just show the setting

SLASH_KORKRONPLANNER1 = "/kp"
SlashCmdList.KORKRONPLANNER = function(msg)
  local cmd = strlower(strtrim(msg or ""))
  local word, rest = cmd:match("^(%S*)%s*(.-)$")
  if cmd == "" then
    KP.Safe(KP.Window.Toggle)
  elseif cmd == "learn" then -- the owner's level-10 test (Core/Build.lua), not in the help yet
    KP.Safe(KP.Build.LearnNext)
  elseif cmd == "export" then
    KP.Safe(KP.ShowExport, KP)
  elseif cmd == "probe" then
    KP.Safe(KP.Probe, KP)
  elseif (word == "share" or word == "collect") and (rest == "" or rest == "on" or rest == "off") then
    KP.Safe(word == "share" and KP.Share.SetSharing or KP.Share.SetCollector, SWITCH[rest])
  elseif cmd == "errors" then
    if #KP.errors == 0 then KP:Print("no errors.") end
    for i, e in ipairs(KP.errors) do
      KP:Print(i .. ". " .. e.message .. (e.count > 1 and (" (" .. e.count .. " times)") or ""))
    end
  elseif cmd == "errors clear" then
    wipe(KP.errors)
    KP:Print("errors cleared.")
  elseif cmd == "debug" then
    KorkronPlannerDB.debug = not KorkronPlannerDB.debug
    KP:Print("debug " .. (KorkronPlannerDB.debug and "on" or "off"))
  else
    KP:Print("commands:")
    for _, line in ipairs(HELP) do print("  " .. line) end
  end
end
