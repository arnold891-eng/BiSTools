--[[
  BiSTools :: Tools/Threat.lua - the threat tool: a crosshair that grows as a mob's threat turns.

  Asked for by a BiS Tools user, through Arn (13 Oct 2026): "a threat tracker ... like the cross
  hairs, and if something is losing threat it changes color ... and I guess dps can use it too the
  other way: no crosshairs until they start getting threat on a target".

  Then Arn, the same evening: "is there a color curve? ... as they approach 600 barely visible,
  like 1%, 700, 800, 900, 1000 flashing red 100% ... dps like to cut it close and we don't want
  something flashing all the time".

  So ONE crosshair whose strength follows the threat, never a two-state flag:
    level = how close the mob is to turning, from `db.from` (60% of what it takes to pull) to 100%
    alpha  barely there at the start, full at the top
    colour yellow -> orange -> red
    flash  only from T.FLASH_AT (95%) up, or when it has turned. Cutting it close at 85% is steady.

    DPS / HEALER  the level is YOUR scaled threat on the mob (UnitDetailedThreatSituation's
                  scaledPercentage: 100 = you pull it). On you: full red, flashing.
    TANK          on you: the level is whoever in the group is closest to pulling it off you
                  (their scaledPercentage, looked up at most every T.SCAN seconds per mob).
                  Not on you - or, in a group in an instance, fighting the group and never touched
                  by you: full red, flashing.

  READABLE ON FOREVER: threat is on the desk's list of what still reads inside combat, and the
  census says ShouldUnitThreatValuesBeSecret = false. Every answer is still asked "secret?" first;
  a hidden answer draws NOTHING - which is not the same as "not on its list".

  The crosshair is the recap's (RC.MarkPlate, your style, pinned to the nameplate), kind "threat",
  tinted here. It never covers a rival's or the farm's crosshair. Events only - no ticker - and the
  fight ending takes every threat crosshair down.
]]
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap
local F = NS.Farm

local T = {}
NS.Threat = T

T.YELLOW = { 1.00, 0.85, 0.15 }
T.ORANGE = { 1.00, 0.45, 0.05 }
T.RED    = { 1.00, 0.12, 0.12 }
RC.MARK_COLOUR.threat = T.YELLOW
T.FLASH_AT = 95                    -- % of a pull: from here on it flashes (Arn: not all the time)
T.FROM = 60                        -- % of a pull where it starts to show (db.from overrides)
T.MIN_ALPHA = 0.04                 -- "barely visible" at the start
T.SCAN = 0.5                       -- a tank's look at the group, per mob, at most this often
T.ROLES = { "auto", "tank", "dps" }
T.plates = {}                      -- nameplate units on screen right now
T.scan = {}                        -- unit -> { at, level } (the tank's group look, kept briefly)

local plain = F.Plain

local function yes(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return plain(v)
end

--- tank or dps. "auto" asks the group role the game knows; anything else is dps.
function T.Role(db)
  if db.role == "tank" or db.role == "dps" then return db.role end
  return yes(UnitGroupRolesAssigned, "player") == "TANK" and "tank" or "dps"
end

--- One unit's threat on a mob: tanking (true/false), and how close to pulling it (0-100+), or nil
--- when the game hides it. notListed = a plain "not on its list".
local function secret(v)
  if not issecretvalue then return false end
  local ok, s = pcall(issecretvalue, v)
  return (not ok) or s == true
end

function T.Read(who, u)
  local res = { pcall(UnitDetailedThreatSituation, who, u) }
  if not res[1] then return nil end
  local tanking, status, scaled = res[2], res[3], res[4]
  -- "secret?" BEFORE any comparison - on Forever even `== nil` on a secret counts against us
  if secret(tanking) or secret(status) or secret(scaled) then return nil end     -- hidden: nothing
  if tanking == nil and status == nil then return nil, nil, true end             -- not on its list
  return tanking == true, type(scaled) == "number" and scaled or 0
end

--- 0-1 from `from`% to 100%.
function T.Level(pct, from)
  if type(pct) ~= "number" then return nil end
  if pct >= 100 then return 1 end
  local t = (pct - from) / (100 - from)
  if t <= 0 then return nil end
  return t
end

--- The tank's view of a mob ON them: how close the nearest groupmate is to pulling it.
function T.Closest(u, from)
  local now = GetTime()
  local c = T.scan[u]
  if c and now - c.at < T.SCAN then return c.level, c.pct end
  local best = nil
  local raid = yes(IsInRaid) == true
  local n = yes(GetNumGroupMembers) or 0
  -- cost: at most once per T.SCAN per mob on screen, and only for a tank holding it
  for i = 1, raid and n or (n - 1) do
    local _, pct = T.Read(raid and ("raid" .. i) or ("party" .. i), u)
    if pct and (not best or pct > best) then best = pct end
  end
  local level = T.Level(best, from)
  T.scan[u] = { at = now, level = level, pct = best }
  return level, best
end

--- How strongly this mob is drawn now: level 0-1 (nil = not at all), and the % it stands at.
function T.Measure(db, role, u)
  local from = tonumber(db.from) or T.FROM
  local tanking, pct, notListed = T.Read("player", u)
  if role == "tank" then
    if notListed then
      -- a mob fighting your group that you never touched - in a group, in an instance,
      -- attackable and in combat (the open world's other fights stay out)
      if not (T.grouped and T.instance) then return nil end
      if yes(UnitCanAttack, "player", u) ~= true then return nil end
      if yes(UnitAffectingCombat, u) ~= true then return nil end
      return 1, 100
    end
    if tanking == nil then return nil end                 -- hidden
    if not tanking then return 1, 100 end                 -- lost
    return T.Closest(u, from)
  end
  if notListed or tanking == nil then return nil end
  if tanking then return 1, 100 end                       -- it is on you
  return T.Level(pct, from), pct
end

--- yellow -> orange -> red along the level
function T.Colour(level)
  local a, b, f
  if level <= 0.5 then a, b, f = T.YELLOW, T.ORANGE, level / 0.5
  else a, b, f = T.ORANGE, T.RED, (level - 0.5) / 0.5 end
  return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

--- Tint a crosshair for a level: colour, strength, and the flash only near the top.
function T.Tint(f, level, pct)
  local r, g, b = T.Colour(level)
  for _, part in ipairs(f.parts or {}) do part:SetColorTexture(r, g, b, 1) end
  local flash = (pct or 0) >= T.FLASH_AT
  if f.pulse then
    if flash then
      if not f.pulse:IsPlaying() then f.pulse:Play() end
    elseif f.pulse:IsPlaying() then
      f.pulse:Stop()
    end
  end
  if not flash then f:SetAlpha(T.MIN_ALPHA + (1 - T.MIN_ALPHA) * level * level) end
  f.level, f.flashing = level, flash
end

function T.On() return R:Enabled("threat") and T.fighting end

--- Draw, re-tint or take down the threat crosshair on one nameplate.
function T.Paint(u)
  if not T.plates[u] then return end
  local have = RC.marks[u]
  if have and have.kind ~= "threat" then return end      -- a rival's or the farm's stays
  local level, pct
  if T.On() then level, pct = T.Measure(T.db, T.role, u) end
  if level then
    if not have and not RC.MarkPlate(u, "threat", "threat") then return end
    T.Tint(RC.marks[u], level, pct)
  elseif have then
    RC.UnmarkUnit(u)
  end
end

function T.PaintAll() for u in pairs(T.plates) do T.Paint(u) end end

function T.ClearAll()
  RC.ClearKind("threat")
  T.scan = {}
end

--- What the fight is about, read once when it starts (not per threat change).
function T.Begin(db)
  T.fighting = true
  T.role = T.Role(db)
  T.grouped = yes(IsInGroup) == true
  T.instance = yes(IsInInstance) == true
  T.scan = {}
  T.PaintAll()
end

function T.OnEvent(_, event, unit)
  local db = T.db
  if not db then return end
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(unit) == "string" and plain(unit) then
      T.plates[unit] = true
      if T.On() then T.Paint(unit) end
    end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if type(unit) == "string" and plain(unit) then T.plates[unit] = nil T.scan[unit] = nil end
  elseif event == "UNIT_THREAT_LIST_UPDATE" then
    -- one mob's list moved: that mob only
    if T.On() and type(unit) == "string" and plain(unit) and T.plates[unit] then T.Paint(unit) end
  elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
    -- YOUR standing moved somewhere: every plate on screen
    if T.On() then T.PaintAll() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if R:Enabled("threat") then T.Begin(db) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    T.fighting = nil
    T.ClearAll()
  end
end

-- registered at load, never from a timer (Olympus: Forever can refuse a registration from a timer);
-- an event this client does not know is pcalled, not thrown
T.frame = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_THREAT_LIST_UPDATE",
                     "UNIT_THREAT_SITUATION_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  pcall(T.frame.RegisterEvent, T.frame, e)
end
T.frame:SetScript("OnEvent", T.OnEvent)

function T.Why(db)
  local marked = 0
  for _, f in pairs(RC.marks) do if f.kind == "threat" then marked = marked + 1 end end
  local plates = 0
  for _ in pairs(T.plates) do plates = plates + 1 end
  NS.Print("threat: %s, as %s (%s); shows from %d%%, flashes from %d%%; %d nameplate(s) in sight, %d with a crosshair%s",
    R:Enabled("threat") and "on" or "off", T.Role(db), db.role or "auto", tonumber(db.from) or T.FROM,
    T.FLASH_AT, plates, marked, T.fighting and "" or " - out of combat, so none")
end

R:Register({
  name = "threat",
  desc = "a crosshair that grows as a mob's threat turns",
  usage = "/bist threat [auto | tank | dps | from <30-90> | why]",
  defaults = { role = "auto", from = T.FROM },
  options = {
    { kind = "seg", label = "watch as", values = T.ROLES,
      get = function(db) return db.role or "auto" end,
      set = function(db, v)
        db.role = v
        if T.fighting then T.role = T.Role(db) T.scan = {} T.PaintAll() end
      end },
    { kind = "step", label = "show from", min = 30, max = 90, step = 10,
      get = function(db) return tonumber(db.from) or T.FROM end,
      set = function(db, v) db.from = v T.scan = {} if T.fighting then T.PaintAll() end end,
      show = function(db) return (tonumber(db.from) or T.FROM) .. "%" end },
  },
  OnInit = function(_, db) T.db = db end,
  OnDisable = function() T.ClearAll() end,
  OnSlash = function(_, db, args)
    T.db = db
    args = (args or ""):lower()
    if args == "auto" or args == "tank" or args == "dps" then
      db.role = args
      if T.fighting then T.role = T.Role(db) T.scan = {} T.PaintAll() end
      return NS.Print("threat: watching as %s", args == "auto" and (T.Role(db) .. " (auto)") or args)
    end
    local from = tonumber(args:match("^from%s+(%d+)$") or "")
    if from then
      db.from = math.max(30, math.min(90, from))
      T.scan = {}
      return NS.Print("threat: shows from %d%% of a pull", db.from)
    end
    T.Why(db)
  end,
})
