--[[
  BiSTools :: Tools/Threat.lua - the threat tool: what each mob's threat is doing, drawn on its plate.

  Asked for by a BiS Tools user, through Arn (13 Oct 2026): "a threat tracker ... like the cross
  hairs, and if something is losing threat it changes color ... and I guess dps can use it too the
  other way: no crosshairs until they start getting threat on a target". Then Arn: a CURVE - "as they
  approach 600 barely visible, like 1% ... 1000 flashing red ... we don't want something flashing all
  the time". Then the guild (Ariarie, Gnomerpills, 13 Oct): a colour for every situation, the left
  side of the bar as the place for it, a small DBM-style glow, and "customizable colors would be
  peak" - Arn: "think we need a customization window" (Tools/ThreatWindow.lua).

  SITUATIONS (T.STATES; each with its own colour and on/off, saved account-wide):
    tank  mine       on me                                   purple   steady
          otherTank  on another tank (their group role)      grey     steady
          nonTank    on somebody who is not a tank           red      flashes
          slipping   on me, a groupmate nearing a pull       orange   the curve
          idle       out of combat                           yellow   off by default
    dps   climb      my threat climbing toward a pull        yellow -> orange -> red, the curve
          onMe       it turned on me                         red      flashes
  THE CURVE: from `from`% of a pull (60) it fades in - barely visible - to full at 100%, and it
  flashes only from `flashAt`% (95). Cutting it close at 85% is a steady warning, not a strobe.
  NOT POSSIBLE: blue for a crowd-controlled mob - Forever hides a mob's debuffs in combat.

  LOOKS (db.look): "crosshair" (the recap's, your style, kind "threat" - never covering a rival's
  or the farm's), "marker" (a bar down the LEFT side of the plate - stays readable when plates
  stack in an AoE pull) and "glow" (a soft ring round the plate). Marker and glow are our own
  frames on UIParent pinned to the plate: nothing of Blizzard's (or EllesmereUI's) plate is
  touched, and a plate the client locks away (IsForbidden) gets nothing.

  READ: UnitDetailedThreatSituation(who, mob) - isTanking, status, scaledPercentage (100 = pulls it).
  Readable in combat on Forever (the desk's lockdown list; ShouldUnitThreatValuesBeSecret = false).
  "secret?" is asked before ANY comparison - even == on a secret counts against us - and a hidden
  answer draws nothing. A tank's look at the group (who holds it, who is closest) is cached per mob
  for T.SCAN seconds. Events only; the fight ending takes every threat mark down.
]]
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap
local F = NS.Farm

local T = {}
NS.Threat = T

T.PURPLE = { 0.73, 0.50, 1.00 }
T.GREY   = { 0.62, 0.62, 0.66 }
T.YELLOW = { 1.00, 0.85, 0.15 }
T.ORANGE = { 1.00, 0.45, 0.05 }
T.RED    = { 1.00, 0.12, 0.12 }
RC.MARK_COLOUR.threat = T.YELLOW
T.FLASH_AT = 95                    -- % of a pull: from here on a curve flashes (db.flashAt overrides)
T.FROM = 60                        -- % of a pull where a curve starts to show (db.from overrides)
T.MIN_ALPHA = 0.04                 -- "barely visible" at the start
T.SCAN = 0.5                       -- a tank's look at the group, per mob, at most this often
T.ROLES = { "auto", "tank", "dps" }
T.LOOKS = { "crosshair", "marker", "glow" }
T.MARK_W = 5                       -- the left marker's width
T.GLOW = 3                         -- the glow ring's thickness

-- every situation: key, whose, label, default colour(s), on by default, flashes / follows the curve
T.STATES = {
  { key = "mine",      role = "tank", label = "On me",                 colour = T.PURPLE, on = true },
  { key = "otherTank", role = "tank", label = "On another tank",       colour = T.GREY,   on = true },
  { key = "nonTank",   role = "tank", label = "On a non-tank",         colour = T.RED,    on = true, flash = true },
  { key = "slipping",  role = "tank", label = "Nearly losing it",      colour = T.ORANGE, on = true, curve = true },
  { key = "idle",      role = "tank", label = "Out of combat",         colour = T.YELLOW, on = false },
  { key = "climb",     role = "dps",  label = "Climbing toward a pull", colours = { T.YELLOW, T.ORANGE, T.RED }, on = true, curve = true },
  { key = "onMe",      role = "dps",  label = "It's on me",            colour = T.RED,    on = true, flash = true },
}
T.byKey = {}
for _, s in ipairs(T.STATES) do T.byKey[s.key] = s end

T.plates = {}                      -- nameplate units on screen right now
T.scan = {}                        -- unit -> the tank's group look, kept T.SCAN seconds
T.ind, T.pool = {}, {}             -- marker/glow frames on plates, and spare ones per look

local plain = F.Plain

local function yes(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return plain(v)
end

local function secret(v)
  if not issecretvalue then return false end
  local ok, s = pcall(issecretvalue, v)
  return (not ok) or s == true
end

------------------------------------------------------------------ settings --

function T.From(db) return tonumber(db.from) or T.FROM end
function T.FlashAt(db) return tonumber(db.flashAt) or T.FLASH_AT end
function T.Look(db)
  for _, l in ipairs(T.LOOKS) do if db.look == l then return l end end
  return "marker"
end

function T.IsOn(db, key)
  -- nothing saved yet = the default (the first draft read "no table" as `false`: everything off)
  local o = nil
  if type(db.on) == "table" then o = db.on[key] end
  if o == nil then return T.byKey[key].on end
  return o
end

local function copy(c) return { c[1], c[2], c[3] } end

--- A situation's colour (or, for the climb, one of its three: i = 1 low, 2 mid, 3 high).
function T.ColourOf(db, key, i)
  local s = T.byKey[key]
  local saved = type(db.colours) == "table" and db.colours[key .. (i and ("." .. i) or "")]
  if type(saved) == "table" and type(saved[1]) == "number" then return saved end
  if s.colours then return s.colours[i or 1] end
  return s.colour
end

function T.SetColour(db, key, i, c)
  db.colours = type(db.colours) == "table" and db.colours or {}
  db.colours[key .. (i and ("." .. i) or "")] = copy(c)
  T.Refresh()
end

function T.SetOn(db, key, on)
  db.on = type(db.on) == "table" and db.on or {}
  db.on[key] = on and true or false
  T.Refresh()
end

function T.ResetColours(db)
  db.colours = {}
  T.Refresh()
end

--- tank or dps. "auto" asks the group role the game knows; anything else is dps.
function T.Role(db)
  if db.role == "tank" or db.role == "dps" then return db.role end
  return yes(UnitGroupRolesAssigned, "player") == "TANK" and "tank" or "dps"
end

------------------------------------------------------------------- reading --

--- One unit's threat on a mob: tanking (true/false) and how close to pulling it (0-100+); nil when
--- the game hides it; notListed = a plain "not on its list".
-- WHEN THE DETAILED NUMBERS ARE HIDDEN (Arn, 13 Oct: "ever since the threat custom window I don't
-- think it's working" - the window's build moved to the detailed read, and nothing on screen said
-- whether the game hands it over in a fight): fall back to the simple situation - 0 below the
-- tank (draws nothing for a dps), 1 above the tank (it is about to turn: 95%, flashing), 2/3 on you.
-- No smooth curve that way, but every situation still shows. T.how says which read was used.
T.SIMPLE = { [0] = 0, [1] = 95 }

function T.Read(who, u)
  local res = { pcall(UnitDetailedThreatSituation, who, u) }
  if res[1] then
    local tanking, status, scaled = res[2], res[3], res[4]
    -- "secret?" BEFORE any comparison - on Forever even `== nil` on a secret counts against us
    if not (secret(tanking) or secret(status) or secret(scaled)) then
      T.how = "detailed"
      if tanking == nil and status == nil then return nil, nil, true end
      return tanking == true, type(scaled) == "number" and scaled or 0
    end
  end
  local ok, s = pcall(UnitThreatSituation, who, u)
  if not ok or secret(s) then T.how = "hidden" return nil end
  T.how = "simple"
  if s == nil then return nil, nil, true end
  if type(s) ~= "number" then return nil end
  return s >= 2, T.SIMPLE[s] or 0
end

--- Each read of one unit on a mob, as the game hands it over: a value, "nil", "HIDDEN" or "refused".
function T.Raw(who, u)
  local function show(v)
    if secret(v) then return "HIDDEN" end
    if v == nil then return "nil" end
    return tostring(v)
  end
  local d = { pcall(UnitDetailedThreatSituation, who, u) }
  local det = d[1] and ("tanking " .. show(d[2]) .. ", status " .. show(d[3]) .. ", % of a pull " .. show(d[4])) or "refused"
  local s = { pcall(UnitThreatSituation, who, u) }
  local simple = s[1] and show(s[2]) or "refused"
  return det, simple
end

--- 0-1 from `from`% to 100%.
function T.Level(pct, from)
  if type(pct) ~= "number" then return nil end
  if pct >= 100 then return 1 end
  local t = (pct - from) / (100 - from)
  if t <= 0 then return nil end
  return t
end

--- The tank's look at the group for one mob: the highest groupmate %, and who holds it.
function T.Group(u)
  local now = GetTime()
  local c = T.scan[u]
  if c and now - c.at < T.SCAN then return c end
  c = { at = now }
  local raid = yes(IsInRaid) == true
  local n = yes(GetNumGroupMembers) or 0
  -- cost: at most once per T.SCAN per mob on screen
  for i = 1, raid and n or (n - 1) do
    local m = raid and ("raid" .. i) or ("party" .. i)
    local tanking, pct = T.Read(m, u)
    if tanking then c.holder = m end
    if pct and (not c.best or pct > c.best) then c.best = pct end
  end
  if c.holder then c.holderTank = yes(UnitGroupRolesAssigned, c.holder) == "TANK" end
  T.scan[u] = c
  return c
end

--- What this mob's plate should say now: situation key, level 0-1 and the % it stands at - or nil.
function T.Measure(db, role, u)
  if not T.fighting then
    if role == "tank" and T.IsOn(db, "idle") and yes(UnitCanAttack, "player", u) == true
       and yes(UnitAffectingCombat, u) == false then
      return "idle", 1
    end
    return nil
  end
  local from = T.From(db)
  local tanking, pct, notListed = T.Read("player", u)
  if role == "tank" then
    if notListed then
      -- never touched it: only a fight of YOUR group counts (in a group, in an instance,
      -- attackable and in combat) - the open world's other fights stay out
      if not (T.grouped and T.instance) then return nil end
      if yes(UnitCanAttack, "player", u) ~= true then return nil end
      if yes(UnitAffectingCombat, u) ~= true then return nil end
    elseif tanking == nil then
      return nil                                          -- hidden
    end
    if tanking then
      local g = T.Group(u)
      local level = T.Level(g.best, from)
      if level and T.IsOn(db, "slipping") then return "slipping", level, g.best end
      if T.IsOn(db, "mine") then return "mine", 1 end
      return nil
    end
    local g = T.Group(u)
    if g.holder and g.holderTank then
      return T.IsOn(db, "otherTank") and "otherTank" or nil, 1
    end
    return T.IsOn(db, "nonTank") and "nonTank" or nil, 1, 100
  end
  if notListed or tanking == nil then return nil end
  if tanking then return T.IsOn(db, "onMe") and "onMe" or nil, 1, 100 end
  if not T.IsOn(db, "climb") then return nil end
  local level = T.Level(pct, from)
  if not level then return nil end
  return "climb", level, pct
end

local function mix(a, b, f) return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f end

--- The colour, alpha and flash for a situation at a level.
function T.Style(db, key, level, pct)
  local s = T.byKey[key]
  local r, g, b
  if s.colours then
    local lo, mid, hi = T.ColourOf(db, key, 1), T.ColourOf(db, key, 2), T.ColourOf(db, key, 3)
    if level <= 0.5 then r, g, b = mix(lo, mid, level / 0.5) else r, g, b = mix(mid, hi, (level - 0.5) / 0.5) end
  else
    local c = T.ColourOf(db, key)
    r, g, b = c[1], c[2], c[3]
  end
  local flash = s.flash or (s.curve and (pct or 0) >= T.FlashAt(db)) or false
  local alpha = s.curve and (T.MIN_ALPHA + (1 - T.MIN_ALPHA) * level * level) or 1
  return r, g, b, flash and 1 or alpha, flash
end

------------------------------------------------------------------- drawing --

local function plateOf(u)
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return nil end
  local ok, plate = pcall(get, u)
  if not ok or not plate then return nil end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return nil end
  return plate
end

local function pulse(f)
  if not f.CreateAnimationGroup then return end
  local ok, g = pcall(f.CreateAnimationGroup, f)
  if not (ok and g) then return end
  local fade = g:CreateAnimation("Alpha")
  fade:SetFromAlpha(1) fade:SetToAlpha(0.3) fade:SetDuration(0.5)
  if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
  g:SetLooping("BOUNCE")
  f.pulse = g
end

local function tex(f, layer)
  local t = f:CreateTexture(nil, layer)
  t:SetColorTexture(1, 1, 1, 1)
  return t
end

--- A marker or a glow frame. Its coloured textures are in f.parts; f.Paint(r, g, b) recolours them.
function T.NewIndicator(look)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f.parts, f.look = {}, look
  if look == "marker" then
    local o = tex(f, "BORDER") o:SetColorTexture(0, 0, 0, 1) o:SetAllPoints(f)
    local t = tex(f, "ARTWORK")
    t:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1) t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.parts[1] = t
  else
    -- a solid ring hugging the plate and a fainter one outside it: a small glow without anyone's
    -- art. Each ring is a frame G (or 2G) bigger than the plate, its edges G thick inside it.
    -- SIDES AND BOTTOM ONLY - a U, open at the top (Arn, 13 Oct, on the first glow: the top edge
    -- ran through the mob's name above the bar)
    local G = T.GLOW
    for ring = 1, 2 do
      local rf = CreateFrame("Frame", nil, f)
      rf:SetPoint("TOPLEFT", f, "TOPLEFT", -ring * G, ring * G)
      rf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", ring * G, -ring * G)
      for _, e in ipairs({ { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
                           { "TOPLEFT", "BOTTOMLEFT", "v" }, { "TOPRIGHT", "BOTTOMRIGHT", "v" } }) do
        local t = tex(rf, "ARTWORK")
        t:SetPoint(e[1], rf, e[1]) t:SetPoint(e[2], rf, e[2])
        if e[3] == "h" then t:SetHeight(G) else t:SetWidth(G) end
        t.ringAlpha = ring == 1 and 1 or 0.35
        f.parts[#f.parts + 1] = t
      end
    end
  end
  function f.Paint(r, g, b)
    for _, t in ipairs(f.parts) do t:SetColorTexture(r, g, b, t.ringAlpha or 1) end
  end
  pulse(f)
  return f
end

--- Pin an indicator to a plate: the marker down the plate's left side, the glow round all of it.
function T.Place(f, plate)
  f:ClearAllPoints()
  if f.look == "marker" then
    f:SetPoint("TOPRIGHT", plate, "TOPLEFT", -2, 0)
    f:SetPoint("BOTTOMRIGHT", plate, "BOTTOMLEFT", -2, 0)
    f:SetWidth(T.MARK_W)
  else
    f:SetPoint("TOPLEFT", plate, "TOPLEFT", -1, 1)
    f:SetPoint("BOTTOMRIGHT", plate, "BOTTOMRIGHT", 1, -1)
  end
end

local function setFlash(f, flash, alpha)
  if f.pulse then
    if flash then
      if not f.pulse:IsPlaying() then f.pulse:Play() end
    elseif f.pulse:IsPlaying() then
      f.pulse:Stop()
    end
  end
  if not flash then f:SetAlpha(alpha) end
  f.flashing = flash
end

--- Take a plate's threat mark down, whatever look it is in.
function T.Undraw(u)
  local have = RC.marks[u]
  if have and have.kind == "threat" then RC.UnmarkUnit(u) end
  local f = T.ind[u]
  if f then
    if f.pulse then f.pulse:Stop() end
    f:Hide()
    f:ClearAllPoints()
    T.ind[u] = nil
    T.pool[f.look] = T.pool[f.look] or {}
    table.insert(T.pool[f.look], f)
  end
end

--- Draw a plate's threat mark in the chosen look.
function T.Draw(db, u, key, r, g, b, alpha, flash)
  local look = T.Look(db)
  if look == "crosshair" then
    local have = RC.marks[u]
    if have and have.kind ~= "threat" then return end          -- a rival's or the farm's stays
    if not have and not RC.MarkPlate(u, "threat", "threat") then return end
    local m = RC.marks[u]
    for _, part in ipairs(m.parts or {}) do part:SetColorTexture(r, g, b, 1) end
    setFlash(m, flash, alpha)
    m.key, m.level = key, alpha
    return
  end
  local f = T.ind[u]
  if f and f.look ~= look then T.Undraw(u) f = nil end
  if not f then
    local plate = plateOf(u)
    if not plate then return end
    T.pool[look] = T.pool[look] or {}
    f = table.remove(T.pool[look]) or T.NewIndicator(look)
    T.Place(f, plate)
    f:Show()
    T.ind[u] = f
  end
  f.Paint(r, g, b)
  setFlash(f, flash, alpha)
  f.key = key
end

function T.On() return R:Enabled("threat") end

--- Draw, re-colour or take down one plate's mark.
function T.Paint(u)
  if not T.plates[u] then return end
  local db = T.db
  local key, level, pct
  if T.On() then key, level, pct = T.Measure(db, T.role or T.Role(db), u) end
  if not key then return T.Undraw(u) end
  T.Draw(db, u, key, T.Style(db, key, level, pct))
end

function T.PaintAll() for u in pairs(T.plates) do T.Paint(u) end end

function T.ClearAll()
  for u in pairs(T.ind) do T.Undraw(u) end
  RC.ClearKind("threat")
  T.scan = {}
end

--- After any setting changes: everything redrawn from scratch.
function T.Refresh()
  local db = T.db
  if not db then return end
  T.role = T.Role(db)
  T.ClearAll()
  T.PaintAll()
  if T.UI and T.UI.Paint then T.UI.Paint() end
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
    if type(unit) == "string" and plain(unit) then
      T.Undraw(unit)
      T.plates[unit], T.scan[unit] = nil, nil
    end
  elseif event == "UNIT_THREAT_LIST_UPDATE" then
    -- one mob's list moved: that mob only
    if T.fighting and T.On() and type(unit) == "string" and plain(unit) and T.plates[unit] then T.Paint(unit) end
  elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
    -- YOUR standing moved somewhere: every plate on screen
    if T.fighting and T.On() then T.PaintAll() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if T.On() then T.Begin(db) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    T.fighting = nil
    T.ClearAll()
    if T.On() then T.role = T.Role(db) T.PaintAll() end    -- the out-of-combat colour, if it is on
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
  for _ in pairs(T.ind) do marked = marked + 1 end
  for _, f in pairs(RC.marks) do if f.kind == "threat" then marked = marked + 1 end end
  local plates = 0
  for _ in pairs(T.plates) do plates = plates + 1 end
  NS.Print("threat: %s, as %s (%s), look %s; shows from %d%%, flashes from %d%%; %d nameplate(s) in sight, %d marked%s",
    R:Enabled("threat") and "on" or "off", T.Role(db), db.role or "auto", T.Look(db), T.From(db),
    T.FlashAt(db), plates, marked, T.fighting and "" or " - out of combat")
  -- what the game hands over for your target, read now - run it IN a fight to see the real answer
  if yes(UnitExists, "target") == true then
    local det, simple = T.Raw("player", "target")
    DEFAULT_CHAT_FRAME:AddMessage("  your target, detailed: " .. det)
    DEFAULT_CHAT_FRAME:AddMessage("  your target, simple: " .. simple .. "   (last read used: " .. tostring(T.how or "none yet") .. ")")
  else
    DEFAULT_CHAT_FRAME:AddMessage("  target a mob in a fight and ask again: it shows what the game hands over")
  end
end

R:Register({
  name = "threat",
  -- A BETA, OFF UNTIL SOMEONE TURNS IT ON (Arn, 13 Oct: removed in a hurry when the right-click menu
  -- broke in a battleground - that was the menu taint, not this - then "we keep the threat stuff
  -- beta": in releases, off). /bist on threat turns it on; the Hub shows "threat (beta)".
  title = "threat (beta)",
  defaultOff = true,
  desc = "(beta) what each mob's threat is doing, on its plate",
  usage = "/bist threat [auto | tank | dps | from <30-90> | why]  (no word: the window)",
  defaults = { role = "auto", from = T.FROM, flashAt = T.FLASH_AT, look = "marker" },
  options = {
    { kind = "seg", label = "watch as", values = T.ROLES,
      get = function(db) return db.role or "auto" end,
      set = function(db, v) db.role = v T.Refresh() end },
    { kind = "step", label = "show from", min = 30, max = 90, step = 10,
      get = function(db) return T.From(db) end,
      set = function(db, v) db.from = v T.Refresh() end,
      show = function(db) return T.From(db) .. "%" end },
  },
  OnInit = function(_, db) T.db = db end,
  OnDisable = function() T.ClearAll() end,
  OnEnable = function() T.Refresh() end,
  IsOpen = function() return T.UI and T.UI.IsOpen and T.UI.IsOpen() or false end,
  OnOpen = function(_, db, recenter) if T.UI then T.UI.Open(db, recenter) end end,
  OnSlash = function(_, db, args)
    T.db = db
    args = (args or ""):lower()
    if args == "auto" or args == "tank" or args == "dps" then
      db.role = args
      T.Refresh()
      return NS.Print("threat: watching as %s", args == "auto" and (T.Role(db) .. " (auto)") or args)
    end
    local from = tonumber(args:match("^from%s+(%d+)$") or "")
    if from then
      db.from = math.max(30, math.min(90, from))
      T.Refresh()
      return NS.Print("threat: shows from %d%% of a pull", db.from)
    end
    if args == "why" then return T.Why(db) end
    if T.UI then return T.UI.Toggle(db) end
    T.Why(db)
  end,
})
