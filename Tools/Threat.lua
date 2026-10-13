--[[
  BiSTools :: Tools/Threat.lua - the threat tool: crosshairs on the mobs whose threat you should watch.

  Asked for by a BiS Tools user, through Arn (13 Oct 2026): "a threat tracker ... like the cross
  hairs, and if something is losing threat it changes color on stuff in combat but not attacking
  them, and I guess dps can use it too the other way: no crosshairs until they start getting threat
  on a target".

    TANK   a mob in the fight that is NOT on you: orange.  On you, but someone is close: yellow.
    DPS    nothing - until you climb over the tank on a mob: yellow. It is on you: orange.
    (a healer is "dps" here: the same warning that a mob is about to turn on you)

  READABLE ON FOREVER: the desk's lockdown measurements list threat among what still reads inside
  combat, and the census says ShouldUnitThreatValuesBeSecret = false. Every answer is still asked
  "secret?" first (NS.Farm.Plain) - a hidden one draws nothing.

  The crosshair is the recap's (RC.MarkPlate - your chosen style, pinned to the nameplate, the
  client carries it): two new kinds, "threat" (yellow) and "aggro" (orange). A rival's or the
  farm's crosshair on the same plate is never covered. Everything is event-driven - no ticker,
  nothing per frame - and the fight ending takes every threat crosshair down.
]]
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap
local F = NS.Farm

local T = {}
NS.Threat = T

T.YELLOW = { 1.00, 0.85, 0.15 }
T.ORANGE = { 1.00, 0.35, 0.05 }
RC.MARK_COLOUR.threat = T.YELLOW
RC.MARK_COLOUR.aggro = T.ORANGE
T.KINDS = { threat = true, aggro = true }
T.ROLES = { "auto", "tank", "dps" }
T.plates = {}                      -- nameplate units on screen right now

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

--- The crosshair this mob earns now: "aggro", "threat" or nil.
---   UnitThreatSituation(you, mob): nil = you are not on its list; 0 = on it, below the tank;
---   1 = above the tank but it is not on you; 2 = on you, someone close; 3 = on you, safely.
function T.Kind(role, u)
  local okS, raw = pcall(UnitThreatSituation, "player", u)
  if not okS then return nil end
  -- HIDDEN IS NOT "NOT ON ITS LIST". A secret answer draws nothing; only a plain nil means you are
  -- off the mob's list (the suite caught the first draft painting a hidden answer orange for a tank)
  if raw ~= nil and plain(raw) == nil then return nil end
  local s = raw
  if role == "tank" then
    if type(s) ~= "number" then
      -- not on its list at all: a mob fighting your group that you have never touched - in a
      -- group, in an instance, attackable and in combat (the open world's other fights stay out)
      if not (T.grouped and T.instance) then return nil end
      if yes(UnitCanAttack, "player", u) ~= true then return nil end
      if yes(UnitAffectingCombat, u) ~= true then return nil end
      return "aggro"
    end
    if s <= 1 then return "aggro" end
    if s == 2 then return "threat" end
    return nil
  end
  if type(s) ~= "number" then return nil end
  if s >= 2 then return "aggro" end
  if s == 1 then return "threat" end
  return nil
end

function T.On() return R:Enabled("threat") and T.fighting end

--- Draw (or take down) the threat crosshair on one nameplate.
function T.Paint(u)
  if not T.plates[u] then return end
  local have = RC.marks[u]
  if have and not T.KINDS[have.kind] then return end      -- a rival's or the farm's stays
  local kind = T.On() and T.Kind(T.role, u) or nil
  if kind then
    if not (have and have.kind == kind) then RC.MarkPlate(u, "threat", kind) end
  elseif have then
    RC.UnmarkUnit(u)
  end
end

function T.PaintAll() for u in pairs(T.plates) do T.Paint(u) end end

function T.ClearAll()
  RC.ClearKind("threat")
  RC.ClearKind("aggro")
end

--- What the fight is about, read once when it starts (not per threat change).
function T.Begin(db)
  T.fighting = true
  T.role = T.Role(db)
  T.grouped = yes(IsInGroup) == true
  local inside = yes(IsInInstance)
  T.instance = inside == true
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
    if type(unit) == "string" and plain(unit) then T.plates[unit] = nil end
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
  for _, f in pairs(RC.marks) do if T.KINDS[f.kind] then marked = marked + 1 end end
  local plates = 0
  for _ in pairs(T.plates) do plates = plates + 1 end
  NS.Print("threat: %s, as %s (%s); %d nameplate(s) in sight, %d with a threat crosshair%s",
    R:Enabled("threat") and "on" or "off", T.Role(db), db.role or "auto", plates, marked,
    T.fighting and "" or " - out of combat, so none")
end

R:Register({
  name = "threat",
  desc = "crosshairs on the mobs whose threat you should watch",
  usage = "/bist threat [auto | tank | dps | why]",
  defaults = { role = "auto" },
  options = {
    { kind = "seg", label = "watch as", values = T.ROLES,
      get = function(db) return db.role or "auto" end,
      set = function(db, v)
        db.role = v
        if T.fighting then T.role = T.Role(db) T.PaintAll() end
      end },
  },
  OnInit = function(_, db) T.db = db end,
  OnDisable = function() T.ClearAll() end,
  OnSlash = function(_, db, args)
    T.db = db
    args = (args or ""):lower()
    if args == "auto" or args == "tank" or args == "dps" then
      db.role = args
      if T.fighting then T.role = T.Role(db) T.PaintAll() end
      return NS.Print("threat: watching as %s", args == "auto" and (T.Role(db) .. " (auto)") or args)
    end
    T.Why(db)
  end,
})
