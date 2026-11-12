-- Kor'kron Planner: your damage a second against the enemies you meet, worked out in game from your own character sheet,
-- talents and weapons. It's the planner website's math for a Warrior (site/js/calc.js: warriorRotation, warriorAttacks,
-- tankRage, shieldBlock, whiteHits, abilityResult, compute), written in Lua because the game can't run the website's. Change
-- both together: the website's tools/export_sim.js writes Tests/sim_cases.lua, characters it worked out, and the tests here
-- fail when this file's answers drift from them. An average over the fight, not a replay of one. A Rogue's attacks (the
-- Abilities tab) are worked out here too; the rotation and stat weights are a Warrior's only.
local _, KP = ...

local Sim = {}
KP.Sim = Sim

local DATA = KP.SimData.WARRIOR -- the rotation's, a Warrior's
local RULES = KP.SimData.rules

-- the class data a character's attacks read (ctx.class: the class token, a Warrior when not given)
local function Data(ctx)
  return KP.SimData[ctx.class or "WARRIOR"]
end

local function Clamp(diff) return math.max(0, math.min(3, diff)) end

-- ---------------------------------------------------------------- the enemies

local function MobDps(level)
  return math.max(math.min(level - 4, 21), 0.014 * level * level + 0.35 * level)
end

-- health as the combat logs read it, [level, health] with straight lines between; before the first reading and past the last,
-- the nearest one's share of the original game's formula (calc.js's healthFrom)
local function Formula(level)
  return (level < 20 and 0.9 or 1) * level * level + 12 * level
end

local function HealthFrom(points, level)
  local first, last = points[1], points[#points]
  if level <= first[1] then return Formula(level) * first[2] / Formula(first[1]) end
  if level >= last[1] then return Formula(level) * last[2] / Formula(last[1]) end
  for i = 2, #points do
    local l1, h1 = points[i][1], points[i][2]
    if l1 >= level then
      local l0, h0 = points[i - 1][1], points[i - 1][2]
      return h0 + (h1 - h0) * (level - l0) / (l1 - l0)
    end
  end
end

local function MobArmor(level)
  local points = RULES.mobArmor
  if level <= points[1][1] then return points[1][2] * level / points[1][1] end
  for i = 2, #points do
    local l1, a1 = points[i][1], points[i][2]
    if l1 >= level then
      local l0, a0 = points[i - 1][1], points[i - 1][2]
      return a0 + (a1 - a0) * (level - l0) / (l1 - l0)
    end
  end
  return points[#points][2]
end

local function Round(v) return math.floor(v + 0.5) end

-- { same, elite, elite3 }, as calc.js's mobTargets
function Sim.Targets(level)
  local armor, higher = Round(MobArmor(level)), Round(MobArmor(level + 3))
  return {
    same = { diff = 0, armor = armor, health = HealthFrom(RULES.mobHealth, level), hitMult = 1 },
    elite = { diff = 0, armor = armor, health = HealthFrom(RULES.eliteHealth, level), hitMult = RULES.eliteHit, ownSunder = true },
    elite3 = { diff = 3, armor = higher, health = HealthFrom(RULES.eliteHealth, level + 3), hitMult = RULES.eliteHit, ownSunder = true },
  }
end

-- ---------------------------------------------------------------- talents

local talentIndex = {} -- by class: talent name -> its data
local function TalentText(ctx, name)
  local class = ctx.class or "WARRIOR"
  if not talentIndex[class] then
    talentIndex[class] = {}
    for _, t in ipairs(KP.Talents[class]) do talentIndex[class][t.name] = t end
  end
  local rank = ctx.ranks[name]
  local t = talentIndex[class][name]
  return rank and rank > 0 and t and t.desc[rank] or nil
end

-- the first number a talent's tooltip gives for this pattern, 0 when you don't have it
local function TalentNumber(ctx, name, pattern)
  local text = TalentText(ctx, name)
  return text and tonumber(text:match(pattern)) or 0
end

local function HasTalent(ctx, name)
  return (ctx.ranks[name] or 0) > 0
end

-- a talent's first number at your rank (calc.js's talentValue)
local function TalentValue(ctx, name)
  local rank = ctx.ranks[name] or 0
  return rank > 0 and DATA.values[name][rank] or 0
end

-- what a talent needs in your hands: a shield, or one of these weapons (and an off-hand one)
local function NeedsMet(needs, sheet)
  if not needs then return true end
  if needs.shield then return sheet.shield end
  if needs.offHand and not sheet.oh then return false end
  for _, key in ipairs({ "mh", "oh", "rg" }) do
    local w = sheet[key]
    if w and needs.weapons[w.subclass] then return true end
  end
  return false
end

-- what your talents and stance add beyond your character sheet, and each ability's modifiers from them and your race's
-- racials (Eureka!, averaged over its cooldown)
local function TalentEffects(ctx)
  local data = Data(ctx)
  local sheet, stance = ctx.sheet, data.stances[ctx.stance]
  -- threatMult: the stance's threat and each talent's, multiplied together (calc.js's threatOf: +80% and +20% make x2.16)
  local out = { dmgPct = stance.damage, damageTaken = sheet.damageTaken + stance.taken, offhandPct = 0, armorIgnore = 0,
    extraAttack = 0, offhandHit = 0, mods = {}, threatMult = 1 + stance.threat / 100 }
  local function AddMods(mods)
    for _, m in ipairs(mods or {}) do
      local ability = out.mods[m[1]] or { flat = {}, pct = {} }
      out.mods[m[1]] = ability
      local kind = m[3] and ability.pct or ability.flat
      kind[m[2]] = (kind[m[2]] or 0) + m[4]
    end
  end
  local function Add(effect)
    out.dmgPct = out.dmgPct + (effect.dmgPct or 0)
    out.damageTaken = out.damageTaken + (effect.damageTaken or 0)
    out.offhandPct = out.offhandPct + (effect.offhandPct or 0)
    out.armorIgnore = out.armorIgnore + (effect.armorIgnore or 0)
    out.extraAttack = out.extraAttack + (effect.extraAttack or 0)
    out.offhandHit = out.offhandHit + (effect.offhandHit or 0)
    if ctx.beingHit then out.dmgPct = out.dmgPct + (effect.dmgPctHit or 0) end
    AddMods(effect.mods)
  end
  AddMods((data.racials[sheet.race] or {}).mods)
  for name, rank in pairs(ctx.ranks) do
    local t = rank > 0 and data.talents[name]
    if t and NeedsMet(t.needs, sheet) then
      local effect = t.ranks[rank] or {}
      Add(effect)
      if effect.threatPct and (not t.stances or t.stances[ctx.stance]) then
        out.threatMult = out.threatMult * (1 + effect.threatPct / 100)
      end
      local bySubclass = t.bySubclass and sheet.mh and t.bySubclass[rank]
      if bySubclass then Add(bySubclass[sheet.mh.subclass] or {}) end
    end
  end
  return out
end

-- ---------------------------------------------------------------- the attack table and your swings

local function BookRank(name, level)
  local best
  for _, r in ipairs(DATA.book[name].ranks) do
    if (r.level or 1) <= level then best = r end
  end
  return best
end

-- your own Sunder Armor against an elite (calc.js's ownSunder): one a global cooldown from the start until 5 are up, then again
-- as it runs out. A Warrior's only
local function OwnSunder(ctx)
  local rank = ctx.target.ownSunder and (ctx.class or "WARRIOR") == "WARRIOR" and BookRank("Sunder Armor", ctx.level)
  if not rank then return nil end
  local T = ctx.fightSec or RULES.longFight
  local stacks = math.min(RULES.sunderStacks, math.ceil(T / 1.5))
  local uses = stacks + math.max(0, T - (stacks - 1) * 1.5) / (rank.durMs / 1000)
  local cost = rank.cost / 10 - TalentNumber(ctx, "Improved Sunder Armor", "by (%d+)")
  return { perStack = rank.armor, stacks = stacks, share = 1.5 / T, ragePerSec = uses * cost / T }
end

-- whether the numbers for this fight count your own Sunder Armor: the tabs say so where they do
function Sim.CountsSunder(ctx)
  return OwnSunder(ctx) ~= nil
end

local function Mitigation(ctx, tal)
  local function Reduction(stacks, perStack)
    local armor = math.max(0, ctx.target.armor - stacks * perStack) * (1 - tal.armorIgnore / 100)
    return math.min(0.75, armor / (armor + 400 + 85 * ctx.level))
  end
  local own = OwnSunder(ctx)
  if not own then return Reduction(0, 0) end
  local total, left = 0, 1 -- over the fight: each stack on the way up, then the last one for the rest
  for k = 1, own.stacks - 1 do
    total = total + own.share * Reduction(k, own.perStack)
    left = left - own.share
  end
  return total + left * Reduction(own.stacks, own.perStack)
end

local function CritSuppression(ctx) return Clamp(ctx.target.diff) end

-- moreMiss: misses on top of the table's, which hit takes off too (a dual wielder's white swings). An enemy that's hitting
-- you faces you, and parries some of what comes from the front
local function AttackTable(ctx, kind, moreMiss)
  local d, sheet = Clamp(ctx.target.diff), ctx.sheet
  if kind == "magic" then
    return { miss = math.max(1, RULES.spellMiss[d + 1] - sheet.spellHit), dodge = 0, parry = 0 }
  end
  local hit = d >= 3 and math.max(0, sheet.hit - 1) or sheet.hit
  return { miss = math.max(0, RULES.meleeMiss[d + 1] + (moreMiss or 0) - hit), dodge = 5 + d * 0.5,
    parry = ctx.beingHit and RULES.meleeParry[d + 1] or 0 }
end

-- How much hit takes every miss off against a target (calc.js's hitCaps): abilities and white swings with one weapon, white
-- swings with two, spells (1% of them always miss)
function Sim.HitCaps(target)
  local d = Clamp(target.diff)
  local melee = RULES.meleeMiss[d + 1] + (d >= 3 and 1 or 0)
  return { melee = melee, dualWhite = melee + RULES.dualWieldMiss, spell = RULES.spellMiss[d + 1] - 1 }
end

local function WhiteHits(ctx, tal)
  local sheet, out = ctx.sheet, {}
  local d = Clamp(ctx.target.diff)
  local dual = sheet.mh and sheet.oh
  local mit = Mitigation(ctx, tal)
  local suppress = CritSuppression(ctx)
  local c = math.max(0, sheet.crit - suppress) / 100
  local haste = TalentValue(ctx, "Flurry") * (1 - (1 - c) ^ 4) -- attack speed for 3 swings after a crit
  local deepRate = TalentValue(ctx, "Deep Wounds") / 100
  local function Swing(item, label, mult)
    local apBonus = (sheet.ap / 14) * item.speed
    local scale = mult * (1 + tal.dmgPct / 100) * (1 - mit)
    local avg = ((item.min + apBonus) * scale + (item.max + apBonus) * scale) / 2
    local t = AttackTable(ctx, "melee", (dual and RULES.dualWieldMiss or 0) - (label == "Off hand" and tal.offhandHit or 0))
    local miss = t.miss
    local glance = RULES.glanceChance[d + 1]
    local crit = math.max(0, math.min(sheet.crit - suppress, 100 - miss - t.dodge - t.parry - glance))
    local hit = math.max(0, 100 - miss - t.dodge - t.parry - glance - crit)
    local perSwing = avg * (hit + crit * 2 + glance * RULES.glanceDamage[d + 1]) / 100
    local effSpeed = item.speed / ((1 + haste / 100) * (1 + sheet.meleeHaste / 100))
    local swings = label == "Main hand" and 1 + tal.extraAttack or 1
    local deepWounds = 0
    if deepRate > 0 and label == "Main hand" then
      local critsPerSec = (crit / 100) / effSpeed + 0.25 * math.max(0, sheet.crit - suppress) / 100
      local uptime = math.min(1, critsPerSec * 12)
      deepWounds = uptime * deepRate * ((item.min + item.max) / 2 + (sheet.ap / 14) * item.speed) / 12
    end
    table.insert(out, { label = label, twoHand = item.twoHand, avg = avg, speed = item.speed, effSpeed = effSpeed, perSwing = perSwing,
      dps = perSwing * swings / effSpeed, miss = miss, dodge = t.dodge, parry = t.parry, glance = glance, crit = crit, hit = hit,
      deepWounds = deepWounds })
  end
  if sheet.mh then Swing(sheet.mh, "Main hand", 1) end
  if sheet.oh then Swing(sheet.oh, "Off hand", 0.5 * (1 + tal.offhandPct / 100)) end
  return out
end

-- ---------------------------------------------------------------- abilities

local function PickRank(ability, level)
  local best
  for _, r in ipairs(ability.ranks) do
    if r.level <= level and (not best or r.level >= best.level) then best = r end
  end
  return best
end

local function EffectValue(e, rank, level)
  local L = rank.maxLevel and rank.maxLevel > 0 and math.min(level, rank.maxLevel) or level
  return e.base + (e.perLevel or 0) * math.max(0, L - rank.spellLevel)
end

local function NormalSpeed(item)
  if item.twoHand then return RULES.normalSpeed.twoHand end
  if item.subclass == 15 then return RULES.normalSpeed.dagger end
  return RULES.normalSpeed.oneHand
end

-- How many of n enemies one effect hits, and what that multiplies its damage by (calc.js's targetsHit): an area hits them all up
-- to the spell's limit (Thunder Clap and Whirlwind 4); a chain (Cleave) jumps to `chain` of them
local ONE_TARGET = { [5] = true, [6] = true, [21] = true, [25] = true, [45] = true, [57] = true, [77] = true }
local function TargetsHit(e, rank, n)
  if n <= 1 or e.target == 1 then return 1, 1 end
  if ONE_TARGET[e.target] then
    if not (e.chain and e.chain > 1) then return 1, 1 end
    local hits, amp, mult = math.min(n, e.chain), e.chainAmp or 1, 0
    for k = 0, hits - 1 do mult = mult + amp ^ k end
    return hits, mult
  end
  local hits = math.min(n, rank.maxTargets or n)
  return hits, hits
end

-- an ability's damage from its effects on n enemies, before talents and armor (calc.js's effectDamage, for a Warrior's kinds of
-- effect), with the weapon in that hand ("mainHand" or "offHand")
local function EffectDamage(name, rank, ctx, durMs, hand, n)
  local sheet = ctx.sheet
  local ap, item = sheet.ap, hand == "offHand" and sheet.oh or sheet.mh
  local out = { dmin = 0, dmax = 0, dot = 0, ticks = 0, hasDirect = false, hits = 1 }
  local weapon, flat, wpct, wMult = nil, 0, 1, 1
  local textBonus = (not RULES.apDummy[name] and rank.textAP or 0) * ap
  for _, e in ipairs(rank.effects) do
    local isDamage = e.effect == 2 or e.effect == 17 or e.effect == 31 or e.effect == 58 or e.effect == 121 or
      (e.effect == 6 and (e.aura == 3 or e.aura == 53))
    if not (isDamage and e.target == 1) then
      local v = EffectValue(e, rank, ctx.level)
      local spread = (e.variance or 0) / 2
      local hits, m = TargetsHit(e, rank, n)
      -- a finishing move at 5 combo points (calc.js's COMBO_POINTS): its number per point, not spread
      local perCombo = (e.perResource or 0) * RULES.comboPoints
      if e.effect == 17 or e.effect == 58 or e.effect == 121 then
        local speed = e.effect == 121 and NormalSpeed(item) or item.speed
        weapon = { min = item.min + (ap / 14) * speed, max = item.max + (ap / 14) * speed }
        flat = flat + v
        out.hasDirect = true
        wMult, out.hits = math.max(wMult, m), math.max(out.hits, hits)
      elseif e.effect == 31 then
        wpct = wpct * v / 100
        weapon = weapon or { min = item.min + (ap / 14) * item.speed, max = item.max + (ap / 14) * item.speed }
        out.hasDirect = true
        wMult, out.hits = math.max(wMult, m), math.max(out.hits, hits)
      elseif e.effect == 2 then
        -- Shield Slam: twice your Block Value (calc.js's BLOCK_VALUE_SHARE); Eviscerate: a share of attack power per point
        local bonus = (e.apCoef or 0) * ap + (RULES.unshownAp[name] or 0) * ap + (RULES.blockValueShare[name] or 0) * sheet.blockValue +
          (name == "Eviscerate" and ap * RULES.eviscerateApPerPoint * RULES.comboPoints or 0) + ((e.apCoef or 0) ~= 0 and 0 or textBonus)
        textBonus = 0
        out.dmin = out.dmin + (v * (1 - spread) + perCombo + bonus) * m
        out.dmax = out.dmax + (v * (1 + spread) + perCombo + bonus) * m
        out.hasDirect = true
        out.hits = math.max(out.hits, hits)
      elseif e.effect == 3 then
        if RULES.apDummy[name] == e.i then
          out.dmin = out.dmin + ap * v / 100 * m
          out.dmax = out.dmax + ap * v / 100 * m
          out.hasDirect = true
        elseif name == "Execute" and e.i == 0 then
          out.dmin = out.dmin + v
          out.dmax = out.dmax + v
          out.hasDirect = true
        end
      elseif e.effect == 6 and (e.aura == 3 or e.aura == 53) then
        -- Rupture lasts longer per combo point (calc.js's LONGER_PER_POINT)
        local dur = durMs + (perCombo ~= 0 and (RULES.longerPerPoint[name] or 0) * RULES.comboPoints or 0)
        local ticks = (e.period or 0) > 0 and math.floor(dur / e.period) or 0
        out.ticks = math.max(out.ticks, ticks)
        out.dot = out.dot + ticks * (v + perCombo + (RULES.unshownApPerTick[name] or 0) * ap) * m
        out.hits = math.max(out.hits, hits)
      end
    end
  end
  if weapon then
    out.dmin = out.dmin + (weapon.min + flat) * wpct * wMult
    out.dmax = out.dmax + (weapon.max + flat) * wpct * wMult
  end
  return out
end

local NO_MODS = { flat = {}, pct = {} }

-- what one use on n enemies does and costs, or nil when you can't use it (calc.js's abilityResult)
local function Ability(ctx, tal, name, n)
  local data = Data(ctx)
  local ability = data.abilities[name]
  if ability.talent and not HasTalent(ctx, ability.talent) then return nil end
  local rank = PickRank(ability, ctx.level)
  if not rank then return nil end
  if ability.needsShield and not ctx.sheet.shield then return nil end
  if ability.weapons and not ability.weapons[ctx.sheet.mh.subclass] then return nil end
  if ability.stances and not ability.stances[ctx.stance] then return nil end
  if ability.offHand and not ctx.sheet.oh then return nil end -- Shank strikes with your off-hand weapon alone
  local mods = tal.mods[name] or NO_MODS
  local function Flat(op) return mods.flat[op] or 0 end
  local function Pct(op) return mods.pct[op] or 0 end
  local durMs = math.max(0, (rank.durMs + Flat(1)) * (1 + Pct(1) / 100))
  local r = EffectDamage(name, rank, ctx, durMs, ability.offHand and "offHand" or "mainHand", n)
  -- Whirlwind strikes with the off hand too, at half damage like every off-hand hit
  if ability.bothHands and ctx.sheet.oh then
    local oh = EffectDamage(name, rank, ctx, durMs, "offHand", n)
    local share = 0.5 * (1 + tal.offhandPct / 100)
    r.dmin, r.dmax = r.dmin + oh.dmin * share, r.dmax + oh.dmax * share
  end
  -- spells it sets off (Intercept's stun, Mutilate's two strikes): each one's damage, the second with your off hand when you
  -- have one (calc.js's abilityResult)
  for _, strike in ipairs(rank.strikes or {}) do
    local sub = setmetatable({ effects = strike.effects, textAP = false }, { __index = rank })
    local s = EffectDamage(name, sub, ctx, durMs, strike.off and ctx.sheet.oh and "offHand" or "mainHand", n)
    r.dmin, r.dmax, r.dot = r.dmin + s.dmin, r.dmax + s.dmax, r.dot + s.dot
    r.hasDirect, r.hits = r.hasDirect or s.hasDirect, math.max(r.hits, s.hits)
  end
  local isSpell = rank.defense ~= 2 -- Thunder Clap: it uses the spell table, but it's Physical: armor stops it like the rest
  local dmgMult = (1 + Pct(0) / 100) * (1 + Pct(8) / 100) * (1 + tal.dmgPct / 100)
  local dotMult = (1 + Pct(22) / 100) * (1 + tal.dmgPct / 100)
  local mit = 1 - Mitigation(ctx, tal)
  -- Revenge's share of attack power skips Defensive Stance's penalty (calc.js's revengeStanceBack)
  local stanceBack = 0
  if name == "Revenge" and rank.textAP then
    stanceBack = (-data.stances[ctx.stance].damage / 100) * rank.textAP * ctx.sheet.ap * (1 + Pct(0) / 100) * (1 + Pct(8) / 100)
  end
  local flatDmg = Flat(0)
  local dmin = r.hasDirect and ((r.dmin + flatDmg) * dmgMult + stanceBack) * mit or 0
  local dmax = r.hasDirect and ((r.dmax + flatDmg) * dmgMult + stanceBack) * mit or 0
  local dot = r.dot * dotMult
  local critChance = math.max(0, (isSpell and ctx.sheet.spellCrit or ctx.sheet.crit - CritSuppression(ctx)) + Flat(7))
  local critMult = 1 + (isSpell and 0.5 or 1) * (1 + Pct(15) / 100)
  local t = AttackTable(ctx, isSpell and "magic" or "melee")
  local miss = math.max(0, t.miss - Flat(16))
  local land = math.max(0, 100 - miss - t.dodge - t.parry) / 100
  local avg = (dmin + dmax) / 2
  local critFactor = 1 + math.min(100, critChance) / 100 * (critMult - 1)
  local closest = name == "Whirlwind" and
    TalentNumber(ctx, "Improved Whirlwind", "closest enemy by (%d+)%%") / 100 / math.max(1, r.hits) or 0
  local directExpected = land * avg * critFactor * (1 + closest)
  local dotExpected = land * dot * (rank.dotCrit and critFactor or 1)
  local expected = directExpected + dotExpected
  local amp
  for _, e in ipairs(rank.effects) do amp = amp or e.amp end
  return {
    name = name, expected = expected, directExpected = directExpected, dotExpected = dotExpected, ticks = r.ticks, durMs = durMs,
    perRage = amp and avg > 0 and amp * 10 * dmgMult * mit * (expected / avg) or 0,
    castMs = math.max(0, (rank.castMs + Flat(10)) * (1 + Pct(10) / 100)) / (1 + ctx.sheet.castHaste / 100),
    cdMs = math.max(0, (rank.cdMs + Flat(11)) * (1 + Pct(11) / 100)),
    cost = math.max(0, (rank.cost + Flat(14)) * (1 + Pct(14) / 100)) / (data.power == "rage" and 10 or 1), -- rage is kept x10
    -- for the Abilities tab: a normal hit (after armor), the chance to land and crit, the enemies hit, what an extra point of
    -- rage adds to a normal hit (Execute), and what multiplies its damage into threat
    dmax = dmax, avg = avg, land = land, critChance = math.min(100, critChance), critMult = critMult, hits = r.hits,
    extraPerRage = amp and amp * 10 * dmgMult * mit or 0, threatMult = tal.threatMult * (1 + Pct(2) / 100),
  }
end

-- ---------------------------------------------------------------- being hit

local function Outcomes(sheet)
  local d = math.max(0, sheet.defense) * 0.0004
  return { miss = RULES.baseMiss + d, dodge = sheet.dodge / 100 + d, parry = sheet.parry / 100 + d,
    block = sheet.shield and sheet.block / 100 + d or 0 }
end

-- the share of swings at you that don't land in full (a block counted as avoided), at most 60% (calc.js's avoidance)
local function Avoidance(sheet)
  local o = Outcomes(sheet)
  return math.min(0.6, o.miss + o.dodge + o.parry + o.block)
end

local function MeleeTaken(sheet, tal, level, hitMult)
  local armorDR = math.min(0.75, sheet.armor / (sheet.armor + 400 + 85 * level))
  return MobDps(level) * hitMult * (1 - Avoidance(sheet)) * (1 - armorDR) * (1 + tal.damageTaken / 100)
end

-- Survival: your health through armor and avoidance against a raid boss, 3 levels above you (calc.js's ehp)
function Sim.Survival(ctx)
  local sheet = ctx.sheet
  local armorDR = math.min(0.75, sheet.armor / (sheet.armor + 400 + 85 * (ctx.level + 3)))
  return sheet.health / ((1 - armorDR) * (1 - Avoidance(sheet))) / (1 + TalentEffects(ctx).damageTaken / 100)
end

local function RageConversion(level)
  local c = RULES.rageC
  return c[1] * level * level + c[2] * level + c[3]
end

local function TankRage(ctx, tal)
  local sheet = ctx.sheet
  local o, swings = Outcomes(sheet), 1 / RULES.mobSwing
  local perBlock = (TalentNumber(ctx, "Shield Specialization", "(%d+)%% chance to generate") / 100) *
    TalentNumber(ctx, "Shield Specialization", "generate (%d+) Rage when you Block")
  local perDodge = sheet.shield and (TalentNumber(ctx, "Master of Defense", "(%d+)%% chance to generate") / 100) *
    TalentNumber(ctx, "Master of Defense", "generate (%d+) Rage when you Dodge") or 0
  local landed = swings * math.max(0, 1 - o.miss - o.dodge - o.parry)
  local mobLevel = ctx.level + math.max(0, ctx.target.diff)
  local hits = RULES.rageTakenPerC * MeleeTaken(sheet, tal, mobLevel, ctx.target.hitMult) / RageConversion(ctx.level) +
    RULES.ragePerHitTaken * landed
  local shieldRage = swings * (o.block * perBlock + (o.dodge + o.parry) * perDodge)
  return { o = o, swings = swings, perBlock = perBlock, rage = hits + shieldRage }
end

-- Shield Block on cooldown: { perSec = extra blocks a second, rage = what it costs a second }
local function ShieldBlock(ctx, t, rage)
  local book = DATA.book["Shield Block"]
  local sb = ctx.sheet.shield and book.stances[ctx.stance] and BookRank("Shield Block", ctx.level)
  local max = book.max
  if not sb or not max or (sb.cdMs or 0) == 0 then return { perSec = 0, rage = 0 } end
  local cd = sb.cdMs / 1000
  local swingsIn = math.min(sb.durMs / 1000, cd) * t.swings
  local blocked = math.min(max, swingsIn * math.max(0, 1 - t.o.miss - t.o.dodge - t.o.parry))
  local extra = math.max(0, blocked - swingsIn * t.o.block)
  local net = (sb.cost / 10 - extra * t.perBlock) / cd
  local f = net <= 0 and 1 or math.min(1, math.max(0, rage) / net)
  return { perSec = f * extra / cd, rage = f * net }
end

local function RevengeRate(t, moreBlocks, cd)
  local procs = t.swings * (t.o.dodge + t.o.parry + t.o.block) + moreBlocks
  return procs > 0 and 1 / (cd + math.exp(-procs * math.min(RULES.revengeWindow, cd)) / procs) or 0
end

-- ---------------------------------------------------------------- the rotation

local function FightMs(ctx) return ctx.fightSec and ctx.fightSec * 1000 or math.huge end

-- Mortal Strike or Bloodthirst, Whirlwind, Thunder Clap, Rend, Slam and Overpower: most damage per rage first, as often as
-- their cooldowns, rage and the global cooldown allow (calc.js's warriorAttacks)
local function Attacks(ctx, white, use, state, add)
  local melee, mh = {}, nil
  for _, w in ipairs(white) do
    table.insert(melee, w)
    if w.label == "Main hand" then mh = w end
  end
  local function PerCd(a) return a and a.cdMs > 0 and 1000 / a.cdMs or 0 end
  local gcd = math.max(0, 1 - state.gcdUsed)
  local function Take(a, perSec, dmg)
    local needRage = perSec * a.cost
    local needTime = perSec * math.max(1.5, a.castMs / 1000)
    local f = math.max(0, math.min(1, needRage ~= 0 and state.rage / needRage or 1, needTime ~= 0 and gcd / needTime or 1))
    if f < 0.01 then return 0 end
    state.rage = state.rage - f * needRage
    gcd = gcd - f * needTime
    add(a.name, f * perSec * dmg)
    return f
  end
  local rend, op, slam = use("Rend"), use("Overpower"), use("Slam")
  local rendEvery, rendLost = 0, 0
  if rend and rend.durMs > 0 then
    local half = rend.ticks > 0 and rend.durMs / rend.ticks / 2 or 0
    local T = FightMs(ctx)
    local everyMs = math.max(0, math.min(rend.durMs, T))
    local landed = T >= rend.durMs and 1 or math.max(0, T - half) / (rend.durMs - half)
    rendEvery = 1000 / everyMs
    rendLost = rend.dotExpected * (1 - landed)
  end
  local bloodthrill = TalentNumber(ctx, "Bloodthrill", "a (%d+)%% chance to allow an activation of Overpower") / 100
  local rendUp = rend and rend.expected > 0 and bloodthrill > 0 and op and Take(rend, rendEvery, rend.expected - rendLost) > 0.99
  local list = {}
  local function Push(a, perSec, loss)
    if a and a.expected > 0 and perSec > 0 then
      table.insert(list, { a = a, perSec = perSec, dmg = a.expected - (loss or 0), order = #list })
    end
  end
  local main = use("Mortal Strike") or use("Bloodthirst")
  Push(main, PerCd(main))
  Push(use("Whirlwind"), PerCd(use("Whirlwind")))
  Push(use("Thunder Clap"), PerCd(use("Thunder Clap")))
  if rend and not rendUp then Push(rend, rendEvery, rendLost) end
  local slamText = TalentText(ctx, "Improved Slam")
  local slamFree = slamText and slamText:find("cooldown of your Slam ability by %d+ sec") and
    slamText:find("no longer interrupts or delays your melee swing")
  if slam then
    local swingDps = 0
    for _, w in ipairs(melee) do swingDps = swingDps + w.perSwing / w.effSpeed end
    Push(slam, PerCd(slam), slamFree and 0 or swingDps * (slam.castMs / 1000))
  end
  if op and op.cdMs > 0 then
    local dodges = 0
    for _, w in ipairs(melee) do dodges = dodges + w.dodge / 100 / w.effSpeed end
    local fromRend = rendUp and mh and bloodthrill * (math.max(0, 100 - mh.miss - mh.dodge - mh.parry) / 100) / mh.effSpeed or 0
    Push(op, math.min(1000 / op.cdMs, dodges + fromRend))
  end
  table.sort(list, function(x, y)
    local xr, yr = x.dmg / (x.a.cost > 0 and x.a.cost or 1e-9), y.dmg / (y.a.cost > 0 and y.a.cost or 1e-9)
    if xr ~= yr then return xr > yr end
    return x.order < y.order
  end)
  for _, c in ipairs(list) do Take(c.a, c.perSec, c.dmg) end
end

-- calc.js's warriorRotation: rage in, then attacks in order. { dps, parts = { { name, dps } }, rageIncome }
local function Rotation(ctx)
  local tal = TalentEffects(ctx)
  local white = WhiteHits(ctx, tal)
  if #white == 0 then return nil end
  local parts, dps = {}, 0
  for _, w in ipairs(white) do
    table.insert(parts, { name = w.label .. " (white)", dps = w.dps })
    dps = dps + w.dps
    if w.deepWounds > 0 then
      table.insert(parts, { name = "Deep Wounds", dps = w.deepWounds })
      dps = dps + w.deepWounds
    end
  end
  local cache = {}
  local function Use(name)
    if cache[name] == nil then cache[name] = Ability(ctx, tal, name, 1) or false end
    return cache[name] or nil
  end
  local level, tank = ctx.level, ctx.stance == "defensive"
  local unbridled = TalentValue(ctx, "Unbridled Wrath") / 100 -- chance per hit of 1 extra rage
  local offhandBonus = TalentNumber(ctx, "Dual Wield Specialization", "Rage generated by your off%-hand attacks by (%d+)%%")
  local function SwingRage(w)
    return (w.twoHand and RULES.ragePerSwingSec2H or RULES.ragePerSwingSec) * w.speed * ((w.hit + w.glance + w.crit * 2) / 100) *
      (w.label == "Off hand" and RULES.offhandRage * (1 + offhandBonus / 100) or 1)
  end
  local rage = 0
  for _, w in ipairs(white) do rage = rage + (SwingRage(w) + unbridled) / w.effSpeed end
  if HasTalent(ctx, "Anger Management") then rage = rage + 1 / 3 end
  local reckless = TalentNumber(ctx, "Reckless Swings", "next (%d+) melee attacks") *
    TalentNumber(ctx, "Reckless Swings", "generate (%d+) additional Rage")
  rage = rage + reckless * (1000 / (RULES.recklessCd * 1000))
  local blood = BookRank("Bloodrage", level)
  if blood then
    rage = rage + DATA.book.Bloodrage.rage * (1 + TalentNumber(ctx, "Improved Bloodrage", "by (%d+)%%") / 100) * (1000 / blood.cdMs)
  end
  local charge = BookRank("Charge", level)
  local pullRage = charge and (ctx.stance == "battle" or (tank and HasTalent(ctx, "Vanguard"))) and
    (charge.rage or 0) + TalentNumber(ctx, "Improved Charge", "Charge ability by (%d+)") or 0
  if pullRage > 0 and ctx.fightSec then rage = rage + pullRage / ctx.fightSec end
  local t = ctx.beingHit and TankRage(ctx, tal) or nil
  if t then rage = rage + t.rage end
  local rageIncome, firstAbilityPart = rage, #parts + 1
  local state = { rage = rage, gcdUsed = 0 }
  local own = OwnSunder(ctx)
  if own then state.rage = math.max(0, state.rage - own.ragePerSec) end
  if t then
    local moreBlocks = ShieldBlock(ctx, t, state.rage)
    state.rage = state.rage - moreBlocks.rage
    local rv = Use("Revenge")
    if rv and rv.cdMs > 0 and state.rage > 0 then
      local r = RevengeRate(t, moreBlocks.perSec, rv.cdMs / 1000)
      local f = rv.cost > 0 and math.min(1, state.rage / (rv.cost * r)) or 1
      state.rage = state.rage - f * rv.cost * r
      state.gcdUsed = state.gcdUsed + f * r * 1.5
      table.insert(parts, { name = "Revenge", dps = f * r * rv.expected })
      dps = dps + f * r * rv.expected
    end
  end
  local slam = Use("Shield Slam")
  if slam and slam.cdMs > 0 and state.rage > 0 then
    local uses = 1000 / slam.cdMs
    local perSec = slam.cost * uses
    local f = perSec > 0 and math.min(1, state.rage / perSec) or 1
    state.rage = state.rage - perSec * f
    state.gcdUsed = state.gcdUsed + f * 1.5 * uses
    table.insert(parts, { name = "Shield Slam", dps = f * slam.expected * uses })
    dps = dps + f * slam.expected * uses
  end
  Attacks(ctx, white, Use, state, function(name, d)
    table.insert(parts, { name = name, dps = d })
    dps = dps + d
  end)
  local hs, mh = Use("Heroic Strike"), white[1]
  if hs and state.rage > 0 then
    local perSec = math.min(state.rage / (hs.cost + SwingRage(mh)), 1 / mh.effSpeed)
    local d = perSec * math.max(0, hs.expected - mh.perSwing)
    table.insert(parts, { name = "Heroic Strike", dps = d })
    dps = dps + d
  end
  local ex = Use("Execute")
  if ex and ex.expected > 0 then
    local rate = ex.cost > 0 and math.min(1 / 1.5, rageIncome / ex.cost) or 1 / 1.5
    local leftover = math.max(0, rageIncome - rate * ex.cost)
    local exDps = rate * ex.expected + leftover * ex.perRage
    local normal = 0
    for i = firstAbilityPart, #parts do
      normal = normal + parts[i].dps
      parts[i].dps = parts[i].dps * (1 - RULES.executePhase)
    end
    dps = dps - normal * RULES.executePhase + exDps * RULES.executePhase
    table.insert(parts, { name = "Execute", dps = exDps * RULES.executePhase })
  end
  local shown = {}
  for _, p in ipairs(parts) do
    if p.dps > 0.05 then table.insert(shown, p) end
  end
  return { dps = dps, parts = shown, rageIncome = rageIncome }
end

-- ---------------------------------------------------------------- one fight

-- calc.js's compute: the fight lasts as long as the enemy takes to die at the damage you do in a fight that long. A long
-- fight's damage gives the first guess, the damage in that fight the second; then the secant until one is within 1%. A length
-- already worked out (ctx.fightSec) is kept: stat weights compare the same fight with and without a stat.
function Sim.Compute(ctx)
  if ctx.fightSec then
    local R = Rotation(ctx)
    if R then R.fightSec = ctx.fightSec end
    return R
  end
  local function WithFight(T)
    local copy = {}
    for k, v in pairs(ctx) do copy[k] = v end
    copy.fightSec = T
    return Rotation(copy)
  end
  local long = WithFight(nil)
  if not long or long.dps <= 0 then return long end
  local hp = ctx.target.health
  local function Guess(T)
    local R = WithFight(T)
    return { T = T, R = R, miss = R.dps > 0 and hp / R.dps - T or math.huge }
  end
  local tried = { Guess(hp / long.dps) }
  if tried[1].miss ~= math.huge then table.insert(tried, Guess(tried[1].T + tried[1].miss)) end
  for _ = 1, 2 do
    if #tried < 2 then break end
    local last = tried[#tried]
    if last.miss == math.huge or math.abs(last.miss) <= 0.01 * last.T then break end
    local other = tried[#tried - 1]
    for i = #tried - 1, 1, -1 do
      if (tried[i].miss > 0) ~= (last.miss > 0) then
        other = tried[i]
        break
      end
    end
    local T = last.T - last.miss * (last.T - other.T) / (last.miss - other.miss)
    if not (T > 0 and T < math.huge) then break end
    table.insert(tried, Guess(T))
  end
  local best = tried[1]
  for _, p in ipairs(tried) do
    if math.abs(p.miss) < math.abs(best.miss) then best = p end
  end
  best.R.fightSec = best.T
  return best.R
end

-- ---------------------------------------------------------------- the Abilities tab: every attack, side by side

local STANCE_ORDER = { "battle", "defensive", "berserker" }
-- attacks on your next swing: they replace that swing and don't take a global cooldown
local NEXT_SWING = { ["Heroic Strike"] = true, Cleave = true }

-- An attack's row. one: on one enemy, all: on n. Per press counts misses, dodges and crits; the biggest is a crit at the top of the
-- roll on one enemy (Execute's with all 100 rage); per second, pressed as often as it can be: on its cooldown, a bleed as it runs
-- out, at most once a global cooldown; Heroic Strike and Cleave every swing, less the white hit they replace (mh). Threat: damage
-- times your stance's and talents' threat (Sunder Armor's own is in its row); moreThreat: the server adds some the files don't hold.
-- ability: its data (the class's); stealth: an opener used from Stealth
local function GridRow(name, ability, one, all, mh, stance)
  local total = all.directExpected + all.dotExpected
  local dps
  if NEXT_SWING[name] then
    dps = (total - mh.perSwing) / mh.effSpeed
  else
    dps = total / (math.max(all.cdMs, all.dotExpected > 0 and all.durMs or 0, 1500) / 1000)
  end
  local threat = total * all.threatMult
  return { name = name, stance = stance, rage = all.cost, cdMs = all.cdMs, land = one.land * 100, crit = one.critChance,
    perPress = all.directExpected, bleed = all.dotExpected, hits = all.hits, dps = dps, threat = threat,
    biggest = (one.dmax + one.extraPerRage * math.max(0, 100 - one.cost)) * one.critMult,
    perRage = all.cost > 0 and total / all.cost or nil, threatPerRage = all.cost > 0 and threat / all.cost or nil,
    moreThreat = ability.moreThreat, stealth = ability.stealth }
end

-- Sunder Armor's row: no damage, its own threat when it lands
local function SunderRow(ctx, tal, stance)
  local book = DATA.book["Sunder Armor"]
  local rank = BookRank("Sunder Armor", ctx.level)
  if not rank or (book.stances and not book.stances[ctx.stance]) then return nil end
  local t = AttackTable(ctx, "melee")
  local land = math.max(0, 100 - t.miss - t.dodge - t.parry) / 100
  local cost = rank.cost / 10 - TalentNumber(ctx, "Improved Sunder Armor", "by (%d+)")
  local threat = land * rank.threat * tal.threatMult
  return { name = "Sunder Armor", stance = stance, rage = cost, cdMs = 0, land = land * 100, perPress = 0, bleed = 0, hits = 1,
    dps = 0, threat = threat, perRage = 0, threatPerRage = cost > 0 and threat / cost or nil }
end

-- Every attack you have against n enemies like base.target, one row each, worked out in the stance you're in (`current`), or else
-- in the first stance you know that allows it (its row's `stance` names that one). base: { class (a Warrior when not given),
-- level, ranks, sheet (read in your stance), target, beingHit }; known: the stances you know. A Rogue has none: current "none".
function Sim.Grid(base, current, known, n)
  local data = Data(base)
  local rows, done = {}, {}
  local order = { current }
  for _, s in ipairs(STANCE_ORDER) do
    if s ~= current and known[s] then table.insert(order, s) end
  end
  for _, stance in ipairs(order) do
    local ctx = {}
    for k, v in pairs(base) do ctx[k] = v end
    ctx.stance, ctx.sheet = stance, stance == current and base.sheet or Sim.InStance(base.sheet, current, stance)
    local tal = TalentEffects(ctx)
    local mh = WhiteHits(ctx, tal)[1]
    local other = stance ~= current and stance or nil
    for name, ability in pairs(data.abilities) do
      local one = not done[name] and Ability(ctx, tal, name, 1)
      if one then
        done[name] = true
        table.insert(rows, GridRow(name, ability, one, Ability(ctx, tal, name, n), mh, other))
      end
    end
    local sunder = data.book and not done["Sunder Armor"] and SunderRow(ctx, tal, other)
    if sunder then
      done["Sunder Armor"] = true
      table.insert(rows, sunder)
    end
  end
  return rows
end

-- ---------------------------------------------------------------- your character, from the game

local STANCE_OF_FORM = { [17] = "battle", [18] = "defensive", [19] = "berserker" }
local STANCE_OF_SPELL = { [2457] = "battle", [71] = "defensive", [2458] = "berserker" }

-- the stance you're in, and the ones you know
function Sim.Stances()
  local known = {}
  for i = 1, GetNumShapeshiftForms() do
    local _, _, _, spellID = GetShapeshiftFormInfo(i)
    local stance = KP.Readable(spellID) and STANCE_OF_SPELL[spellID]
    if stance then known[stance] = true end
  end
  local form = GetShapeshiftFormID()
  return KP.Readable(form) and STANCE_OF_FORM[form] or nil, known
end

local function Weapon(slot)
  local id = GetInventoryItemID("player", slot)
  local item = KP.Readable(id) and KP.Items[id]
  if not (item and item.w) then return nil end
  return { min = item.w[1], max = item.w[2], speed = item.w[3], subclass = item.w[4], twoHand = item[1] == "twoHand" }
end

local function Number(v)
  return KP.Readable(v) and v or nil
end

-- Your character sheet as the math reads it, for the stance you're in; nil when the game is hiding numbers. Racial cooldowns
-- (Blood Fury, Berserking) count at their average, as on the website, unless they're up right now.
function Sim.Sheet()
  local base, plus, minus = UnitAttackPower("player")
  base, plus, minus = Number(base), Number(plus), Number(minus)
  local _, armor = UnitArmor("player")
  armor = Number(armor)
  local crit, dodge, parry, block = Number(GetCritChance()), Number(GetDodgeChance()), Number(GetParryChance()), Number(GetBlockChance())
  local attackSpeed = Number((UnitAttackSpeed("player")))
  local meleeHit, spellHit = Number(GetHitModifier()), Number(GetSpellHitModifier())
  local meleeRating, spellRating = Number(GetCombatRatingBonus(CR_HIT_MELEE)), Number(GetCombatRatingBonus(CR_HIT_SPELL))
  local spellCrit = Number(GetSpellCritChance(2))
  local health = Number(UnitHealthMax("player"))
  if not (base and plus and minus and armor and crit and dodge and parry and block and attackSpeed and meleeHit and spellHit and
    meleeRating and spellRating and spellCrit and health) then
    return nil
  end
  local mh, oh, rg = Weapon(16), Weapon(17), Weapon(18)
  local offHand = GetInventoryItemID("player", 17)
  local offItem = KP.Readable(offHand) and KP.Items[offHand]
  local shield = offItem and offItem[1] == "shield" or false
  -- your Block Value: Shield Slam adds twice it. The game's GetShieldBlock hasn't been seen on Forever yet; without it, none counts
  local blockValue = shield and GetShieldBlock and Number(GetShieldBlock()) or 0
  local _, _, raceID = UnitRace("player")
  local _, class = UnitClass("player")
  local racial = Data({ class = class }).racials[raceID] or {}
  local haste = mh and (mh.speed / attackSpeed - 1) * 100 or 0
  return {
    ap = (base + plus + minus) * (1 + (racial.apPct or 0) / 100), apPct = racial.apPct or 0,
    crit = crit + (racial.crit or 0), spellCrit = spellCrit + (racial.crit or 0),
    hit = meleeHit + meleeRating, spellHit = spellHit + spellRating, armor = armor, dodge = dodge, parry = parry, block = block,
    defense = 0, health = health, healthPct = racial.healthPct or 0, damageTaken = racial.damageTaken or 0,
    meleeHaste = haste + (racial.meleeHaste or 0),
    castHaste = racial.castHaste or 0, shield = shield, blockValue = blockValue, mh = mh, oh = oh, rg = rg, race = raceID,
  }
end

-- your talents as { [name] = rank }, or nil when the game is hiding them
function Sim.Ranks()
  local byNode = KP.TalentRanks()
  if not byNode then return nil end
  local _, class = UnitClass("player")
  local ranks = {}
  for _, t in ipairs(KP.Talents[class]) do
    if (byNode[t.id] or 0) > 0 then ranks[t.name] = byNode[t.id] end
  end
  return ranks
end

-- the sheet as it would read in another stance: only Berserker Stance's crit changes it
function Sim.InStance(sheet, from, to)
  local copy = {}
  for k, v in pairs(sheet) do copy[k] = v end
  local change = DATA.stances[to].crit - DATA.stances[from].crit
  copy.crit, copy.spellCrit = sheet.crit + change, sheet.spellCrit + change
  return copy
end
