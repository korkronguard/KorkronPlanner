local _, KP = ...

local Build = {}
KP.Build = Build

local FIRST_LEVEL = 10
local LINK_CHARS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

local function MyClass()
  local _, class = UnitClass("player")
  return KP.Text(class)
end

function Build.Suggested()
  return KP.Builds[MyClass()] or {}
end

local byId = {}
function Build.Talent(id)
  local class = MyClass()
  if not byId[class] then
    byId[class] = {}
    for _, t in ipairs(KP.Talents[class] or {}) do byId[class][t.id] = t end
  end
  return byId[class][id]
end

function Build.Describe(step)
  local t = Build.Talent(step.id)
  return ("%s %d/%d"):format(t.name, step.rank, t.ranks)
end

function Build.ChoiceText(f)
  local names = {}
  for _, id in ipairs(f.options) do table.insert(names, Build.Talent(id).name) end
  return ("%s, or %s: %s"):format(Build.Talent(f.id).name, table.concat(names, " or "), f.why)
end

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

function Build.ForLevel(data, key, level)
  local list = key and (data[MyClass()] or {})[key]
  if not list then return nil end
  local found = list[1]
  for _, entry in ipairs(list) do
    if entry.level <= level then found = entry end
  end
  return found
end

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

function Build.Follow(build, ranks)
  local planned = {}
  for _, id in ipairs(build.order) do planned[id] = (planned[id] or 0) + 1 end
  local want, choiceOf = {}, {}
  for id, n in pairs(planned) do want[id] = n end
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

function Build.Points(ranks)
  local spent = 0
  for _, rank in pairs(ranks) do spent = spent + rank end
  return spent, math.max(0, UnitLevel("player") - FIRST_LEVEL + 1)
end

function Build.Choose(key)
  KorkronPlannerCharDB.build = key and { key = key } or nil
end

function Build.UseLink(text)
  local order, why = Build.FromLink(text)
  if not order then return why end
  KorkronPlannerCharDB.build = { order = order }
  return ("using your planner link (%d points)."):format(#order)
end

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

KP:On("PLAYER_LEVEL_UP", function() KP.After(5, Build.Remind) end)
KP:On("PLAYER_LOGIN", function() KP.After(20, Build.Remind) end)
