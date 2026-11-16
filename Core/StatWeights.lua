local _, KP = ...

local StatWeights = {}
KP.StatWeights = StatWeights

local RULES = KP.SimData.rules
local SHARP = 0.15
local TURN = 0.25
local TURN_STATS = { hit = { "d", 10, 30 }, crit = { "d", 10, 30 }, agility = { "d", 10, 20 }, armor = { "e", 100, 30 } }
local BACK_STEPS = 10
local SCALED = { ap = "apPct", health = "healthPct" }

local function With(t, changes)
  local copy = {}
  for k, v in pairs(t) do copy[k] = v end
  for k, v in pairs(changes) do copy[k] = v end
  return copy
end

local function Stats(ctx)
  return KP.SimData[ctx.class or "WARRIOR"].stats
end

local function WithStat(ctx, key, amount)
  local sheet = With(ctx.sheet, {})
  for field, per in pairs(Stats(ctx)[key].adds) do
    local each = type(per) == "table" and per[ctx.level] or per
    sheet[field] = sheet[field] + amount * each * (SCALED[field] and 1 + sheet[SCALED[field]] / 100 or 1)
  end
  if key == "strength" and sheet.shield then
    sheet.blockValue = sheet.blockValue + math.floor((sheet.strength + amount) / 20) - math.floor(sheet.strength / 20)
    sheet.strength = sheet.strength + amount
  end
  return With(ctx, { sheet = sheet })
end

local function WithWeapon(ctx, hand, dps)
  local weapon = ctx.sheet[hand]
  local more = dps * weapon.speed
  return With(ctx, { sheet = With(ctx.sheet, { [hand] = With(weapon, { min = weapon.min + more, max = weapon.max + more }) }) })
end

local function Measure(ctx, role)
  local R = KP.Sim.Compute(ctx)
  local m = { d = R and R.dps or 0, e = KP.Sim.Survival(ctx), fightSec = R and R.fightSec }
  m.v = role == "tank" and RULES.tankMix.survival * math.log(m.e) + RULES.tankMix.damage * math.log(1 + m.d) or m.d
  return m
end

function StatWeights.Of(ctx, role)
  local base = Measure(ctx, role)
  if base.d <= 0 then return nil end
  local fight = With(ctx, { fightSec = base.fightSec })
  local W = { live = true, v = {}, e = {}, d = {}, base = base, ctx = fight, role = role }
  local function Per(m, amount)
    return (m.v - base.v) / amount, (m.e - base.e) / amount, (m.d - base.d) / amount
  end
  for key, stat in pairs(Stats(ctx)) do
    W.v[key], W.e[key], W.d[key] = Per(Measure(WithStat(fight, key, stat.amount), role), stat.amount)
  end
  for hand, field in pairs({ mainHand = "mh", offHand = "oh" }) do
    if ctx.sheet[field] then W[hand] = { Per(Measure(WithWeapon(fight, field, RULES.weaponProbe), role), RULES.weaponProbe) } end
  end
  return W
end

function StatWeights.Scan(xs, fs)
  local slopes, turns = {}, {}
  for i = 2, #xs do slopes[i] = (fs[i] - fs[i - 1]) / (xs[i] - xs[i - 1]) end
  local noise = 1e-9 * math.max(1, math.abs(fs[1]))
  local function Differ(x, y, by)
    return math.abs(x - y) > math.max(noise, (by or SHARP) * math.max(math.abs(x), math.abs(y)))
  end
  local i, clean = 3, 2
  while i < #xs and #turns < 2 do
    local before, here, after = slopes[i - 1], slopes[i], slopes[i + 1]
    local back = i - 2 >= clean and slopes[i - 2] or nil
    if Differ(here, before) or (back and Differ(here, back)) then
      local from = back and math.abs(here - after) <= 0.03 * math.abs(here - back) and i - 2 or i - 1
      local a, b = slopes[from], from == i - 2 and here or after
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

local function Follow(ctx, key, measure, step, steps, dir)
  local xs, fs = {}, {}
  for k = 0, steps + 1 do
    local x = dir * (k == 0 and 0 or 1 + (k - 1) * step)
    local with = WithStat(ctx, key, x)
    xs[k + 1], fs[k + 1] = x, measure == "d" and KP.Sim.Compute(with).dps or KP.Sim.Survival(with)
  end
  return xs, fs
end

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

local last = {}
local fresh = {}

function StatWeights.Target(build)
  return KorkronPlannerCharDB.statTarget or (build and build.kind == "group" and UnitLevel("player") >= 60 and "elite3") or "same"
end

function StatWeights.Knows()
  local _, class = UnitClass("player")
  return KP.Sim.Knows(class)
end

local function Work(role, targetKey)
  if not StatWeights.Knows() then return nil end
  local _, class = UnitClass("player")
  local stance = KP.Sim.Stances()
  local sheet, ranks = KP.Sim.Sheet(), KP.Sim.Ranks()
  if not (stance and sheet and ranks and sheet.mh) then return nil end
  local level = UnitLevel("player")
  local W = StatWeights.Of({ class = class, level = level, stance = stance, ranks = ranks, sheet = sheet,
    target = KP.Sim.Targets(level)[targetKey], beingHit = KorkronPlannerCharDB.simNotHit ~= true }, role)
  if W then W.stance, W.target = stance, targetKey end
  return W
end

function StatWeights.Live(role, targetKey)
  local id = ("%s %s %s"):format(role or "dps", targetKey, tostring(KorkronPlannerCharDB.simNotHit == true))
  if not fresh[id] then
    local W = Work(role or "dps", targetKey)
    if W then last[id], fresh[id] = W, true end
  end
  return last[id], fresh[id] == true
end

function StatWeights.For(build)
  return (StatWeights.Live(build.role, StatWeights.Target(build))) or KP.Build.ForLevel(KP.Weights, build.key, UnitLevel("player"))
end

function StatWeights.Stale()
  fresh = {}
end

for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM" }) do
  KP:On(event, function()
    StatWeights.Stale()
    KP.After(2, function()
      StatWeights.Stale()
      KP.BagIcons.Refresh()
    end)
  end)
end
