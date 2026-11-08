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

-- "Improved Rend 2/3" for a step of Build.Follow
function Build.Describe(step)
  local t = Build.Talent(step.id)
  return ("%s %d/%d"):format(t.name, step.rank, t.ranks)
end

-- "Deflection, or Benediction: why" for a "your choice" entry of a build
function Build.ChoiceText(f)
  local names = {}
  for _, id in ipairs(f.options) do table.insert(names, Build.Talent(id).name) end
  return ("%s, or %s: %s"):format(Build.Talent(f.id).name, table.concat(names, " or "), f.why)
end

-- a build's short name among its spec's builds (Build.BySpec): its path, and when the spec has two builds on that
-- path, their roles (Feral: Cat or Bear) or which is the leveling one
local PATH_LABEL = { solo = "Solo", dungeon = "Dungeon", pvp = "PvP" }
local ROLE_WORD = { tank = "tank", dps = "damage", heal = "healer" }
function Build.Label(build, siblings)
  local same, rolesDiffer = 0, false
  for _, b in ipairs(siblings) do
    if b.path == build.path then
      same = same + 1
      rolesDiffer = rolesDiffer or b.role ~= build.role
    end
  end
  if same < 2 then return PATH_LABEL[build.path] end
  return ("%s (%s)"):format(PATH_LABEL[build.path], rolesDiffer and ROLE_WORD[build.role] or
    (build.kind == "group" and "60" or "leveling"))
end

-- A build's entry for your level in per-level data (KP.Priority, KP.Gear: [class][build key] = { { level, ... } }):
-- the last one that starts at or below the level (below the first, the first), or nil
function Build.ForLevel(data, key, level)
  local list = key and (data[MyClass()] or {})[key]
  if not list then return nil end
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

-- Your build as you follow it, your own choices counted. Each point of the build: { id, rank (the talent's rank after
-- this point), level, index (its place in the order), choice (the build's "your choice" entry it belongs to, if any),
-- done, dropped }. A point is done when the talent already has that many points, whatever order you took them in.
-- You may deviate two ways:
--  * a "your choice" point (build.flex) you put into one of its options counts as the build's point;
--  * any other point outside the build is your own pick: the build drops its last points to make room (51 in all).
-- Returns the steps, your own picks ({ { id, extra } }) and what the build now asks of each talent ({ [node ID] = n }).
function Build.Follow(build, ranks)
  local planned = {}
  for _, id in ipairs(build.order) do planned[id] = (planned[id] or 0) + 1 end
  local want, choiceOf = {}, {}
  for id, n in pairs(planned) do want[id] = n end
  -- the build's points of a flex talent you haven't taken yet move to the options you took instead
  for _, f in ipairs(build.flex or {}) do
    choiceOf[f.id] = f
    local open = math.min(f.points, math.max(0, want[f.id] - (ranks[f.id] or 0)))
    for _, o in ipairs(f.options) do
      local n = math.min(open, math.max(0, (ranks[o] or 0) - (want[o] or 0)))
      want[o], want[f.id], open = (want[o] or 0) + n, want[f.id] - n, open - n
    end
  end
  local own, extra = {}, 0
  for id, rank in pairs(ranks) do
    if rank > (want[id] or 0) then
      table.insert(own, { id = id, extra = rank - (want[id] or 0) })
      extra = extra + rank - (want[id] or 0)
    end
  end
  table.sort(own, function(a, b) return a.id < b.id end)
  local given, steps = {}, {}
  for i, id in ipairs(build.order) do
    given[id] = (given[id] or 0) + 1
    local f = choiceOf[id]
    steps[i] = { id = id, rank = given[id], level = FIRST_LEVEL + i - 1, index = i,
      choice = f and given[id] > planned[id] - f.points and f or nil,
      -- a rank above what the build now asks: a your-choice point you put elsewhere
      done = (ranks[id] or 0) >= given[id] or given[id] > want[id] }
  end
  for i = #steps, 1, -1 do
    if extra == 0 then break end
    if not steps[i].done then
      steps[i].dropped, extra = true, extra - 1
      want[steps[i].id] = want[steps[i].id] - 1
    end
  end
  return steps, own, want
end

function Build.NextStep(steps)
  for _, step in ipairs(steps) do
    if not (step.done or step.dropped) then return step end
  end
end

-- Your class's suggested builds by spec (the tree a build puts most points in), in tree order, each spec's builds Solo
-- first, then Dungeon, then PvP (on one path, a leveling build before a level 60 one):
-- { { tree, name, builds = { ... } }, ... }
local PATH_ORDER = { solo = 1, dungeon = 2, pvp = 3 }
function Build.BySpec()
  local specs, trees = {}, (KP.Talents[MyClass()] or {}).trees or {}
  for n, b in ipairs(Build.Suggested()) do
    local tree = 1
    for t = 2, 3 do if b.points[t] > b.points[tree] then tree = t end end
    specs[tree] = specs[tree] or { tree = tree, name = trees[tree], builds = {} }
    table.insert(specs[tree].builds, { build = b, n = n })
  end
  local list = {}
  for tree = 1, 3 do
    local spec = specs[tree]
    if spec then
      table.sort(spec.builds, function(a, b)
        local pa, pb = PATH_ORDER[a.build.path], PATH_ORDER[b.build.path]
        if pa ~= pb then return pa < pb end
        if a.build.kind ~= b.build.kind then return a.build.kind == "leveling" end
        return a.n < b.n
      end)
      for i, entry in ipairs(spec.builds) do spec.builds[i] = entry.build end
      table.insert(list, spec)
    end
  end
  return list
end

-- Points spent and points your level gives: spent, available
function Build.Points(ranks)
  local spent = 0
  for _, rank in pairs(ranks) do spent = spent + rank end
  return spent, math.max(0, UnitLevel("player") - FIRST_LEVEL + 1)
end

-- key: a suggested build's, or nil for no build
function Build.Choose(key)
  KorkronPlannerCharDB.build = key and { key = key } or nil
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
  local step = Build.NextStep(Build.Follow(build, ranks))
  if step then
    KP:Print(("next talent (%s): %s. Your talent window (N) marks it; /kp shows the rest."):format(build.name,
      Build.Describe(step)))
  end
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
  local step = Build.NextStep(Build.Follow(build, ranks))
  if not step then return KP:Print("your build is complete.") end
  local bought = C_Traits.PurchaseRank(configID, step.id)
  local committed = bought and C_ClassTalents.CommitConfig(configID)
  if bought and not committed then C_Traits.RollbackConfig(configID) end
  KP:Print(("learn test, %s: PurchaseRank %s, CommitConfig %s."):format(Build.Describe(step), tostring(bought),
    tostring(committed)))
end

KP:On("PLAYER_LEVEL_UP", function() KP.After(5, Build.Remind) end) -- UnitLevel lags behind the event
KP:On("PLAYER_LOGIN", function() KP.After(20, Build.Remind) end)
