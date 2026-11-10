-- Kor'kron Planner: what a point of each stat is worth to you right now, from your own character sheet, talents and weapons.
-- The planner website's recipe for a stat weight (calc.js's statProbe, gear.js's bisWeights): your number with a stand-in item
-- on, less without, per point, in a fight of the same length. Core/Sim.lua does the working out, so only for the classes it
-- knows (Warriors so far). An answer has the shape of an entry of Data/Weights.lua (the same weights for the planner's best
-- gear at your level), which stays the answer for the other classes and until the game has shown your numbers once. The tests
-- check these against the weights calc.js itself gives its 198 characters (Tests/sim_cases.lua).
local _, KP = ...

local StatWeights = {}
KP.StatWeights = StatWeights

local DATA = KP.SimData.WARRIOR
local RULES = KP.SimData.rules
local SHARP = 0.15 -- a stat's worth changing by more than this from one step to the next: a turn may be there, not a curve
local TURN = 0.25  -- and it is one (a cap) when the worth beyond differs by more than this from the worth before
-- The stats whose worth can turn by the game's rules, in which of your numbers ("d" damage: hit caps, the white hits' crit
-- cap; "e" survival: armor's 75%), in what steps (points) and how many of them to look ahead. Dodge, parry, block and defense
-- are left out: their only turn is the planner's own 60% limit on avoidance, which isn't the game's.
local TURN_STATS = { hit = { "d", 10, 30 }, crit = { "d", 10, 30 }, agility = { "d", 10, 20 }, armor = { "e", 100, 30 } }
local BACK_STEPS = 10 -- and how many steps to look back, for a stat that adds nothing any more
local SCALED = { ap = "apPct", health = "healthPct" } -- sheet numbers a race's % raises, and where the sheet keeps that %

local function With(t, changes)
  local copy = {}
  for k, v in pairs(t) do copy[k] = v end
  for k, v in pairs(changes) do copy[k] = v end
  return copy
end

-- A character with some more points of a stat on: Data/Sim.lua's stats say what a point adds to the sheet (read from the
-- website's math by trying it); attack power and health grow by the race's share (an Orc's Blood Fury, a Tauren's Endurance)
-- like the rest of them
local function WithStat(ctx, key, amount)
  local sheet = With(ctx.sheet, {})
  for field, per in pairs(DATA.stats[key].adds) do
    local each = type(per) == "table" and per[ctx.level] or per
    sheet[field] = sheet[field] + amount * each * (SCALED[field] and 1 + sheet[SCALED[field]] / 100 or 1)
  end
  return With(ctx, { sheet = sheet })
end

-- The same with a weapon ("mh" or "oh") doing some more damage per second
local function WithWeapon(ctx, hand, dps)
  local weapon = ctx.sheet[hand]
  local more = dps * weapon.speed
  return With(ctx, { sheet = With(ctx.sheet, { [hand] = With(weapon, { min = weapon.min + more, max = weapon.max + more }) }) })
end

-- A character's numbers: d = damage a second, e = survival, v = the role's own (a tank's: both on a log scale, as the
-- website's tankScore)
local function Measure(ctx, role)
  local R = KP.Sim.Compute(ctx)
  local m = { d = R and R.dps or 0, e = KP.Sim.Survival(ctx), fightSec = R and R.fightSec }
  m.v = role == "tank" and RULES.tankMix.survival * math.log(m.e) + RULES.tankMix.damage * math.log(1 + m.d) or m.d
  return m
end

-- The weights of a character (ctx: as Core/Sim.lua's Compute takes it) for a role: { live = true, v = { [stat] = per point },
-- e, d, mainHand / offHand = { v, e, d } per damage per second on that weapon, base = { v, e, d }, ctx = the character in the
-- fight they were measured in }; nil when there's no damage to measure (no weapon)
function StatWeights.Of(ctx, role)
  local base = Measure(ctx, role)
  if base.d <= 0 then return nil end
  local fight = With(ctx, { fightSec = base.fightSec })
  local W = { live = true, v = {}, e = {}, d = {}, base = base, ctx = fight, role = role }
  local function Per(m, amount)
    return (m.v - base.v) / amount, (m.e - base.e) / amount, (m.d - base.d) / amount
  end
  for key, stat in pairs(DATA.stats) do
    W.v[key], W.e[key], W.d[key] = Per(Measure(WithStat(fight, key, stat.amount), role), stat.amount)
  end
  for hand, field in pairs({ mainHand = "mh", offHand = "oh" }) do
    if ctx.sheet[field] then W[hand] = { Per(Measure(WithWeapon(fight, field, RULES.weaponProbe), role), RULES.weaponProbe) } end
  end
  return W
end

-- Where a line of readings turns sharply: xs = points of a stat added (or taken off: below 0), fs = your number there.
-- Up to two turns, nearest first: { { at = points from now, worth = per point beyond it } }. The website's calc.js has the
-- same in JavaScript (statScan): change them together.
function StatWeights.Scan(xs, fs)
  local slopes, turns = {}, {}
  for i = 2, #xs do slopes[i] = (fs[i] - fs[i - 1]) / (xs[i] - xs[i - 1]) end -- slopes[i]: the worth over the step ending at xs[i]
  local noise = 1e-9 * math.max(1, math.abs(fs[1]))
  local function Differ(x, y, by)
    return math.abs(x - y) > math.max(noise, (by or SHARP) * math.max(math.abs(x), math.abs(y)))
  end
  local i, clean = 3, 2 -- clean: the first step known to lie wholly before the next turn
  -- the last step is left out: with no step after it, a turn there can't be told from a jump
  while i < #xs and #turns < 2 do
    local before, here, after = slopes[i - 1], slopes[i], slopes[i + 1]
    local back = i - 2 >= clean and slopes[i - 2] or nil
    -- two steps back too: a turn near a step's end changes that step's worth too little to show against its neighbour
    if Differ(here, before) or (back and Differ(here, back)) then
      -- Where the old worth (a) gives way to the new (b): your number at the end of the stretch is what the two add up to.
      -- This step already at the new worth: the turn was in the step before (from: the step a is read from). Else it's in
      -- this step, which mixes the two.
      local from = back and math.abs(here - after) <= 0.03 * math.abs(here - back) and i - 2 or i - 1
      local a, b = slopes[from], from == i - 2 and here or after
      -- the worth after is about the worth before: your number jumped there or bent a little (rage running short), it
      -- didn't turn
      if Differ(a, b, TURN) then
        local at = xs[from] + ((fs[i] - fs[from]) - b * (xs[i] - xs[from])) / (a - b)
        at = math.max(math.min(xs[from], xs[i]), math.min(math.max(xs[from], xs[i]), at))
        table.insert(turns, { at = at, worth = b })
      end
      clean, i = i + 1, i + 2
    else
      i = i + 1
    end
  end
  return turns
end

-- One of your numbers ("d" or "e") as a stat is followed step by step from where you are (dir 1: more of it, -1: less):
-- xs = the points, fs = the number there
local function Follow(ctx, key, measure, step, steps, dir)
  local xs, fs = {}, {}
  for k = 0, steps + 1 do
    local x = dir * (k == 0 and 0 or 1 + (k - 1) * step) -- the first step is 1 point: what the next point is worth
    local with = WithStat(ctx, key, x)
    xs[k + 1], fs[k + 1] = x, measure == "d" and KP.Sim.Compute(with).dps or KP.Sim.Survival(with)
  end
  return xs, fs
end

-- Where your stats' worth turns (caps), worked out once per set of weights: W.turns[stat][measure] ("d" or "e") = { now = what
-- the next point adds, turns = as Scan gives them, spare = the points you could lose before it costs anything (nil unless the
-- next point adds nothing) }
function StatWeights.Turns(W)
  if W.turns then return W.turns end
  W.turns = {}
  for key, t in pairs(TURN_STATS) do
    local measure, step, steps = t[1], t[2], t[3]
    local xs, fs = Follow(W.ctx, key, measure, step, steps, 1)
    local found = { now = fs[2] - fs[1], turns = StatWeights.Scan(xs, fs) }
    if math.abs(found.now) <= 1e-9 * math.max(1, math.abs(fs[1])) then
      local lost = StatWeights.Scan(Follow(W.ctx, key, measure, step, BACK_STEPS, -1))[1]
      found.spare = lost and -lost.at or nil
    end
    W.turns[key] = { [measure] = found }
  end
  return W.turns
end

-- ---------------------------------------------------------------- yours, from the game

local last = {}  -- the weights last worked out, by role, enemy and whether it hits you: kept while the game hides your numbers
local fresh = {} -- which of those are from your sheet as it is now

-- The enemy your weights are measured against: your choice on the Stats tab, else what the website measures a build
-- against (a raid boss for a level 60 group build, an enemy of your level otherwise)
function StatWeights.Target(build)
  return KorkronPlannerCharDB.statTarget or (build and build.kind == "group" and UnitLevel("player") >= 60 and "elite3") or "same"
end

-- whether the addon has your class's math (Core/Sim.lua)
function StatWeights.Knows()
  local _, class = UnitClass("player")
  return class == "WARRIOR"
end

local function Work(role, targetKey)
  if not StatWeights.Knows() then return nil end
  local stance = KP.Sim.Stances()
  local sheet, ranks = KP.Sim.Sheet(), KP.Sim.Ranks()
  if not (stance and sheet and ranks and sheet.mh) then return nil end
  local level = UnitLevel("player")
  local W = StatWeights.Of({ level = level, stance = stance, ranks = ranks, sheet = sheet, target = KP.Sim.Targets(level)[targetKey],
    beingHit = KorkronPlannerCharDB.simNotHit ~= true }, role)
  if W then W.stance, W.target = stance, targetKey end
  return W
end

-- Your own weights against one of Core/Sim.lua's enemies ("same", "elite", "elite3"), and whether they're from your sheet as
-- it is now (false: as it last was, while the game hides it in a fight or a dungeon); nil for a class the addon has no math
-- for, or before the game has shown your numbers once
function StatWeights.Live(role, targetKey)
  local id = ("%s %s %s"):format(role or "dps", targetKey, tostring(KorkronPlannerCharDB.simNotHit == true))
  if not fresh[id] then
    local W = Work(role or "dps", targetKey)
    if W then last[id], fresh[id] = W, true end
  end
  return last[id], fresh[id] == true
end

-- The weights to judge gear by for a build: yours when the addon can work them out, else the planner's for its best gear at
-- your level (nil for a pasted planner link, which has none)
function StatWeights.For(build)
  return (StatWeights.Live(build.role, StatWeights.Target(build))) or KP.Build.ForLevel(KP.Weights, build.key, UnitLevel("player"))
end

-- Your sheet changed (or may have): work the weights out again when they're next asked for
function StatWeights.Stale()
  fresh = {}
end

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM" }) do
  KP:On(event, function()
    StatWeights.Stale()
    KP.After(2, function() -- the game's numbers settle a moment after these: the bag arrows follow the weights
      StatWeights.Stale()
      KP.BagIcons.Refresh()
    end)
  end)
end
