-- Kor'kron Planner: following a build in game. A build is the planner website's order of talent points (one node ID
-- per point, the first at level 10): one of your class's suggested builds (Data/Builds.lua) or a planner share link.
-- KorkronPlannerCharDB.build = { key = "arms" } (a suggested build) or { order = { node IDs } } (a pasted link).
local _, KP = ...

local Build = {}
KP.Build = Build

local FIRST_LEVEL = 10
-- the planner's link alphabet (site/js/talents.js): character n stands for the class's n-th talent in link order
local LINK_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

local function MyClass()
  local _, class = UnitClass("player")
  return KP.Text(class)
end

-- Your class's suggested builds (empty for a class the data doesn't have)
function Build.Suggested()
  return KP.Builds[MyClass()] or {}
end

local byId = {}
-- A talent of your class by node ID: { id, tree, row, col, ranks, name, icon }, or nil
function Build.Talent(id)
  local class = MyClass()
  if not byId[class] then
    byId[class] = {}
    for _, t in ipairs(KP.Talents[class] or {}) do byId[class][t.id] = t end
  end
  return byId[class][id]
end

-- "Improved Rend 2/3" for a step of Build.Steps
function Build.Describe(step)
  local t = Build.Talent(step.id)
  return ("%s %d/%d"):format(t.name, step.rank, t.ranks)
end

-- A build's entry for your level in per-level data (KP.Priority, KP.Gear: [class][build key] = { { level, ... } }):
-- the last one that starts at or below the level (below the first, the first), or nil. A level 60 build only has 60,
-- so below that its leveling build's entries are used (the last one whose pair it is: Protection's dungeon-ready
-- leveling build comes after the solo one).
function Build.ForLevel(data, key, level)
  local class = MyClass()
  local all = data[class] or {}
  local list = key and all[key]
  if not list then return nil end
  if list[1].level > level then
    for _, b in ipairs(Build.Suggested()) do
      if b.pair == key and all[b.key] then list = all[b.key] end
    end
  end
  local found = list[1]
  for _, entry in ipairs(list) do
    if entry.level <= level then found = entry end
  end
  return found
end

-- The chosen build: { name, order, provisional, summary }, or nil and why not
function Build.Current()
  local saved = KorkronPlannerCharDB.build
  if not saved then return nil, "no build chosen" end
  if saved.key then
    for _, b in ipairs(Build.Suggested()) do
      if b.key == saved.key then return b end
    end
    return nil, "that suggested build is gone from this version: choose another"
  end
  for _, id in ipairs(saved.order) do
    if not Build.Talent(id) then return nil, "your saved link doesn't fit the current talent trees: paste it again" end
  end
  return { name = "Your planner link", order = saved.order }
end

-- A planner share link (https://korkronguard.github.io/planner/#c=warrior&...&t4=...) as a build order, or nil and why
function Build.FromLink(text)
  local code = text:match("[#&]t4=([%w%-_]*)")
  if not code then
    if text:match("[#&]t[23]=") then
      return nil, "that's an older planner link: open it on the website once, then copy the link again."
    end
    return nil, "that isn't a planner link (use the planner's Copy link button)."
  end
  local class = (text:match("[#&]c=(%a+)") or ""):upper()
  if class ~= MyClass() then return nil, ("that link is for another class (%s)."):format(class:lower()) end
  local talents = KP.Talents[class]
  local order = {}
  for ch in code:gmatch(".") do
    local t = talents[LINK_CHARS:find(ch, 1, true)]
    if not t then return nil, "that link doesn't fit the addon's talent trees: is the addon up to date?" end
    table.insert(order, t.id)
  end
  if #order == 0 then return nil, "that link has no talents in it." end
  return order
end

-- Each point of a build: { id, rank (the talent's rank after this point), level, done }. A point is done when the
-- talent already has that many points, whatever order you took them in.
function Build.Steps(order, ranks)
  local given, steps = {}, {}
  for i, id in ipairs(order) do
    given[id] = (given[id] or 0) + 1
    steps[i] = { id = id, rank = given[id], level = FIRST_LEVEL + i - 1, done = (ranks[id] or 0) >= given[id] }
  end
  return steps
end

function Build.NextStep(steps)
  for _, step in ipairs(steps) do
    if not step.done then return step end
  end
end

-- Talents with more points than the whole build gives them: { { id, extra }, ... }
function Build.OffBuild(order, ranks)
  local planned = {}
  for _, id in ipairs(order) do planned[id] = (planned[id] or 0) + 1 end
  local off = {}
  for id, rank in pairs(ranks) do
    if rank > (planned[id] or 0) then table.insert(off, { id = id, extra = rank - (planned[id] or 0) }) end
  end
  table.sort(off, function(a, b) return a.id < b.id end)
  return off
end

-- Points spent and points your level gives: spent, available
function Build.Points(ranks)
  local spent = 0
  for _, rank in pairs(ranks) do spent = spent + rank end
  return spent, math.max(0, UnitLevel("player") - FIRST_LEVEL + 1)
end

function Build.Choose(key)
  KorkronPlannerCharDB.build = { key = key }
end

-- returns what happened, in words
function Build.UseLink(text)
  local order, why = Build.FromLink(text)
  if not order then return why end
  KorkronPlannerCharDB.build = { order = order }
  return ("using your planner link (%d points)."):format(#order)
end

-- One chat line when you have a point to spend: the build's next talent
function Build.Remind()
  local build = Build.Current()
  local ranks = KP.TalentRanks()
  if not (build and ranks) then return end
  local spent, available = Build.Points(ranks)
  if spent >= available then return end
  local step = Build.NextStep(Build.Steps(build.order, ranks))
  if step then KP:Print(("next talent (%s): %s. /kp shows the rest."):format(build.name, Build.Describe(step))) end
end

-- /kp learn: the owner's test of whether an addon may spend talent points on Forever (not in the help yet). Spends
-- the build's next point with the game's trait functions and says what they answered.
function Build.LearnNext()
  if InCombatLockdown() then return KP:Print("not in combat.") end
  local build, why = Build.Current()
  if not build then return KP:Print(why .. ".") end
  local _, configID = KP.TalentNodes()
  local ranks = KP.TalentRanks()
  if not ranks then return KP:Print("the game isn't showing your talents here.") end
  local step = Build.NextStep(Build.Steps(build.order, ranks))
  if not step then return KP:Print("your build is complete.") end
  local bought = C_Traits.PurchaseRank(configID, step.id)
  local committed = bought and C_ClassTalents.CommitConfig(configID)
  if bought and not committed then C_Traits.RollbackConfig(configID) end
  KP:Print(("learn test, %s: PurchaseRank %s, CommitConfig %s."):format(Build.Describe(step), tostring(bought),
    tostring(committed)))
end

KP:On("PLAYER_LEVEL_UP", function() KP.After(5, Build.Remind) end) -- UnitLevel lags behind the event
KP:On("PLAYER_LOGIN", function() KP.After(20, Build.Remind) end)
