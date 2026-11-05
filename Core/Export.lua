-- Kor'kron Planner: /kp export. Your character's real stats as one line to paste into the planner website.
--
-- Format (version 1), fields separated by "|":
--   KP1 | CLASS | RACE | level | str | agi | sta | int | spi | crit | spellCrit | hit | ap | rap | spellDamage | healing
-- Each of the five stats is "base:effective:bonus:penalty" from UnitStat. The others are plain numbers (blank when
-- the game doesn't give them). The website's import box (to build) reads this; keep the two in step.
local _, KP = ...

local function num(v) return KP.Num(v, 2) end

-- base + buffs + debuffs (UnitAttackPower's three numbers), or nil when the base is missing or any part is hidden
local function total(base, plus, minus)
  if not (KP.Readable(base) and KP.Readable(plus) and KP.Readable(minus)) or base == nil then return nil end
  return (tonumber(base) or 0) + (tonumber(plus) or 0) + (tonumber(minus) or 0)
end

local function call(name, ...)
  local fn = _G[name]
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

function KP:ExportCode()
  local fields = { "KP1", KP.Text((select(2, UnitClass("player")))) or "", KP.Text((select(2, UnitRace("player")))) or "",
    num(UnitLevel("player")) }
  for i = 1, 5 do
    local base, stat, plus, minus = call("UnitStat", "player", i)
    table.insert(fields, table.concat({ num(base), num(stat), num(plus), num(minus) }, ":"))
  end
  local ap, apPlus, apMinus = call("UnitAttackPower", "player")
  local rap, rapPlus, rapMinus = call("UnitRangedAttackPower", "player")
  table.insert(fields, num(call("GetCritChance")))
  table.insert(fields, num(call("GetSpellCritChance", 2)))
  table.insert(fields, num(call("GetHitModifier")))
  table.insert(fields, num(total(ap, apPlus, apMinus)))
  table.insert(fields, num(total(rap, rapPlus, rapMinus)))
  table.insert(fields, num(call("GetSpellBonusDamage", 2)))
  table.insert(fields, num(call("GetSpellBonusHealing")))
  return table.concat(fields, "|")
end

function KP:ShowExport()
  KP.CopyBox("Kor'kron Planner: your stats", "Press Ctrl+C to copy, then paste it into the planner website.", self:ExportCode())
end
