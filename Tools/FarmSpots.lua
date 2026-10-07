-- BiSTools / Tools / FarmSpots.lua
-- Spawn timers for the farm tool, two levels deep.
--
--   zone   = where a cluster of the mob lives; radius = the option (default 20 yd).
--            Owns one raid mark for good, from the first kill there.
--   sub    = one spawn point inside a zone; radius = SUB_FACTOR x zone radius.
--            Gets a mark only while you stand in its zone: the first sub wears
--            the zone's mark, the rest borrow marks no zone owns. Walk out and
--            the borrowed marks go back to the pool.
--
-- The skull is never touched here: it is the cursor's.
-- The shelf lists every zone, soonest first, with its subs indented under it;
-- a zone's timer is its soonest sub. The zone you stand in is tinted.
local _, NS = ...
local T = NS.T
local F = NS.Farm
local S = { rows = {} }
F.Spots = S

S.SPOT_R  = 20      -- yards, zone radius default; db.spotRadius overrides (slider later)
S.R_MIN, S.R_MAX = 5, 60
S.SUB_FACTOR = 0.35 -- sub radius as a share of the zone radius
S.MAX_ZONES = 16    -- past 7 they show as #n (no mark left to own)
S.MAX_SUBS  = 12
S.EARLY = 0.25      -- a kill with more than this share of a sub's respawn still to run
                    -- is a different mob standing there, not an early respawn
S.BURST   = 60      -- seconds default; db.burst overrides (slider later). A kill this soon
                    -- after a spot's last kill is ANOTHER mob standing there (multi-pull),
                    -- so it gets its own spot and timer. Arn: 15 -> 25 -> "a cool minute".
S.B_MIN, S.B_MAX = 5, 300
S.PRUNE = 600       -- seconds default; db.prune overrides (slider later), 0 = off. A sub that
                    -- has sat "up" (past its respawn, or never learned one) this long with no
                    -- kill folds into its nearest sibling: probably a duplicate spawn point.
S.P_MIN, S.P_MAX = 60, 3600
S.MARKS = 7         -- star..cross; 8 (skull) is the cursor's
S.WARN_AT = 15
S.W, S.ROW, S.INDENT = 124, 14, 12

-- ---------------------------------------------------------------- where am I
function S.Here()
  if not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local map = C_Map.GetBestMapForUnit("player")
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  if not x or (x == 0 and y == 0) then return nil end
  return map, x, y
end

function S.Yards(map, x1, y1, x2, y2)
  local w, h = 1000, 1000
  if C_Map.GetMapWorldSize then
    local ww, hh = C_Map.GetMapWorldSize(map)
    if ww and ww > 0 then w, h = ww, hh end
  end
  local dx, dy = (x1 - x2) * w, (y1 - y2) * h
  return math.sqrt(dx * dx + dy * dy)
end

function S.Median(t)
  local c = {}
  for i, v in ipairs(t) do c[i] = v end
  table.sort(c)
  local n = #c
  if n == 0 then return nil end
  if n % 2 == 1 then return c[(n + 1) / 2] end
  return (c[n / 2] + c[n / 2 + 1]) / 2
end

function S.Radius(db)
  local r = tonumber(db.spotRadius) or S.SPOT_R
  if r < S.R_MIN then r = S.R_MIN elseif r > S.R_MAX then r = S.R_MAX end
  return r
end
function S.SubRadius(db) return S.Radius(db) * S.SUB_FACTOR end
function S.Reach(db) return math.max(S.Radius(db) * 1.5, 15) end
function S.Burst(db)
  local b = tonumber(db.burst) or S.BURST
  if b < S.B_MIN then b = S.B_MIN elseif b > S.B_MAX then b = S.B_MAX end
  return b
end
function S.SetBurst(db, b)
  b = tonumber(b)
  if not b then return nil end
  db.burst = b
  return S.Burst(db)
end
function S.Prune(db)
  local p = tonumber(db.prune)
  if p == nil then p = S.PRUNE end
  if p <= 0 then return 0 end
  if p < S.P_MIN then p = S.P_MIN elseif p > S.P_MAX then p = S.P_MAX end
  return p
end
function S.SetPrune(db, p)
  if type(p) == "string" and p:lower() == "off" then db.prune = 0 return 0 end
  p = tonumber(p)
  if not p then return nil end
  db.prune = p
  return S.Prune(db)
end
function S.SetRadius(db, r)
  r = tonumber(r)
  if not r then return nil end
  db.spotRadius = r
  return S.Radius(db)
end

-- ---------------------------------------------------------------- data
function S.List(db, name)
  db.spots = db.spots or {}
  db.spots[name] = db.spots[name] or {}
  local list = db.spots[name]
  for _, z in ipairs(list) do z.subs = z.subs or {} end -- upgrade flat spots -> zones
  return list
end

function S.Mob(db)
  return db.active or (db.last and db.last.name) or db.custom
end

--- The mob whose spots are SHOWN - the window, the call-out, the map pins, the arrow - and that is
--- the mob being farmed, nothing else (6 Oct 2026). Arn: clicking Mountain Lion again "should
--- remove all the marks on the minimap and clear the spawn timers window". S.Mob falls back to the
--- last kill, which kept them up after you stopped. The spots themselves are KEPT - pick the mob
--- again and everything it learned is back; the window's r button is what forgets a mob.
function S.Shown(db)
  return db.active
end

-- lowest mark 1..7 no zone owns
function S.FreeZoneMark(list)
  local used = {}
  for _, z in ipairs(list) do if z.mark then used[z.mark] = true end end
  for m = 1, S.MARKS do if not used[m] then return m end end
  return nil
end

-- marks no zone owns, in order: the pool subs borrow from
function S.Pool(list)
  local used, pool = {}, {}
  for _, z in ipairs(list) do if z.mark then used[z.mark] = true end end
  for m = 1, S.MARKS do if not used[m] then pool[#pool + 1] = m end end
  return pool
end

-- the zone you stand in (nearest, within the zone radius), or nil
function S.Current(db, name)
  local map, x, y = S.Here()
  if not map then return nil end
  local list = db.spots and db.spots[name]
  if not list then return nil end
  local best, bestD
  for _, z in ipairs(list) do
    if z.map == map then
      local d = S.Yards(map, z.x, z.y, x, y)
      if d <= S.Radius(db) and (not bestD or d < bestD) then best, bestD = z, d end
    end
  end
  return best, bestD
end

-- deal sub marks for the zone you are in, release everyone else's.
-- Stable while you stay: a sub keeps the mark it has if it is still legal.
function S.Assign(db, name)
  local list = S.List(db, name)
  local here = S.Current(db, name)
  for _, z in ipairs(list) do
    if z ~= here then for _, sb in ipairs(z.subs) do sb.mark = nil end end
  end
  if not here then return nil end
  local legal, taken = {}, {}
  if here.mark then legal[#legal + 1] = here.mark end
  for _, m in ipairs(S.Pool(list)) do legal[#legal + 1] = m end
  local isLegal = {}
  for _, m in ipairs(legal) do isLegal[m] = true end
  -- keep what is still legal and not doubled
  for _, sb in ipairs(here.subs) do
    if sb.mark and isLegal[sb.mark] and not taken[sb.mark] then taken[sb.mark] = true else sb.mark = nil end
  end
  -- oldest sub first gets the zone's own mark, then the pool
  for _, sb in ipairs(here.subs) do
    if not sb.mark then
      for _, m in ipairs(legal) do
        if not taken[m] then sb.mark = m taken[m] = true break end
      end
    end
  end
  return here
end

-- marks the scanner must not deal right now
function S.BoundMarks(db, name)
  local out = {}
  local list = db.spots and db.spots[name]
  if not list then return out end
  for _, z in ipairs(list) do if z.mark then out[z.mark] = true end end
  local here = S.Assign(db, name)
  if here then for _, sb in ipairs(here.subs) do if sb.mark then out[sb.mark] = true end end end
  return out
end

-- ---------------------------------------------------------------- record
local function learn(sp, now)
  local gap = now - sp.last
  if gap > 0 then
    sp.gaps = sp.gaps or {}
    table.insert(sp.gaps, gap)
    while #sp.gaps > 8 do table.remove(sp.gaps, 1) end
    sp.respawn = S.Median(sp.gaps)
  end
  sp.last = now
  sp.kills = (sp.kills or 1) + 1
end

local function nearest(items, map, x, y, within, filter)
  local best, bestD
  for _, it in ipairs(items) do
    if it.map == map or it.map == nil then
      if not filter or filter(it) then
        local d = S.Yards(map, it.x, it.y, x, y)
        if d <= within and (not bestD or d < bestD) then best, bestD = it, d end
      end
    end
  end
  return best, bestD
end

-- which zone (and sub) did this kill belong to?
--   1. the mark it died wearing: a sub wearing it (you are in that zone), else the zone owning it
--   2. nearest zone within the zone radius
--   3. nearest zone within reach with a sub that is up
function S.MatchZone(db, list, map, x, y, mark, now)
  if mark then
    for _, z in ipairs(list) do
      for _, sb in ipairs(z.subs) do if sb.mark == mark then return z, sb end end
    end
    for _, z in ipairs(list) do if z.mark == mark then return z end end
  end
  local z = nearest(list, map, x, y, S.Radius(db))
  if z then return z end
  z = nearest(list, map, x, y, S.Reach(db), function(zz)
    for _, sb in ipairs(zz.subs) do
      if sb.respawn and (now - sb.last) >= sb.respawn then return true end
    end
    return false
  end)
  return z
end

function S.Kill(db, name, mark)
  local map, x, y = S.Here()
  if not map then return end
  local now = time()
  local list = S.List(db, name)
  local z, sb = S.MatchZone(db, list, map, x, y, mark, now)
  if not z then
    db.spotSeq = (db.spotSeq or 0) + 1
    z = { id = db.spotSeq, map = map, x = x, y = y, last = now, kills = 0, subs = {}, mark = S.FreeZoneMark(list) }
    table.insert(list, z)
    while #list > S.MAX_ZONES do
      local worst, wi
      for i, zz in ipairs(list) do
        local score = (zz.mark and 1e9 or 0) + zz.last
        if not worst or score < worst then worst, wi = score, i end
      end
      table.remove(list, wi)
    end
    for _, zz in ipairs(list) do if not zz.mark then zz.mark = S.FreeZoneMark(list) end end
  end
  z.last = now
  z.kills = (z.kills or 0) + 1
  -- the sub inside the zone
  if not sb then
    sb = nearest(z.subs, map, x, y, S.SubRadius(db))
    if not sb then
      -- an "up" sub within the zone is the likely one when you shot from range
      sb = nearest(z.subs, map, x, y, S.Radius(db), function(s2)
        return s2.respawn and (now - s2.last) >= s2.respawn
      end)
    end
  end
  -- Arn's burst rule: three kills in 7-15 s are three mobs, not one respawning
  if sb and (now - sb.last) < S.Burst(db) then sb = nil end
  -- ...and Arn's other one: the sub is still counting down with real time left,
  -- so this was another spawn in the same place. (Estimates only ever run long,
  -- never short, so "too early" is a second mob, not a fast respawn.)
  if sb and sb.respawn and (sb.respawn - (now - sb.last)) > sb.respawn * S.EARLY then sb = nil end
  if sb then
    learn(sb, now)
    if S.Yards(map, sb.x, sb.y, x, y) <= S.SubRadius(db) then
      sb.x, sb.y = (sb.x * 3 + x) / 4, (sb.y * 3 + y) / 4
    end
  else
    z.subSeq = (z.subSeq or 0) + 1
    sb = { id = z.subSeq, x = x, y = y, last = now, kills = 1 }
    table.insert(z.subs, sb)
    while #z.subs > S.MAX_SUBS do
      local worst, wi
      for i, s2 in ipairs(z.subs) do
        local score = (s2.respawn and 1e9 or 0) + s2.last
        if not worst or score < worst then worst, wi = score, i end
      end
      table.remove(z.subs, wi)
    end
  end
  S.Refresh(db)
  return z, sb
end

function S.ClearMob(db)
  local mob = S.Shown(db)
  if mob and db.spots then db.spots[mob] = nil end
  S.Refresh(db)
  if mob then NS.Print("spots for %s reset", T.text("accent", mob)) end
end

function S.Clear(db)
  if db.spots then wipe(db.spots) end
  db.spotSeq = 0
  S.Refresh(db)
end

-- ---------------------------------------------------------------- prune
-- fold stale subs into their nearest sibling. Runs from the ticks.
function S.DoPrune(db)
  local window = S.Prune(db)
  if window == 0 then return 0 end
  local mob = S.Mob(db)
  local list = mob and db.spots and db.spots[mob]
  if not list then return 0 end
  local now, folded = time(), 0
  for _, z in ipairs(list) do
    local i = 1
    while i <= #z.subs do
      local sb = z.subs[i]
      local stale = (now - sb.last - (sb.respawn or 0)) > window
      if stale and #z.subs > 1 then
        local best, bestD
        for j, o in ipairs(z.subs) do
          if j ~= i then
            local d = S.Yards(z.map, sb.x, sb.y, o.x, o.y)
            if not bestD or d < bestD then best, bestD = o, d end
          end
        end
        best.kills = (best.kills or 1) + (sb.kills or 1)
        table.remove(z.subs, i)
        folded = folded + 1
      else
        i = i + 1
      end
    end
  end
  return folded
end

-- ---------------------------------------------------------------- target sync
-- Looking at the farmed mob while standing at a spot: it wears that spot's
-- mark. Inside a zone that is the sub's mark; outside, the zone's.
--- The mark the spot you stand at wants on the farmed mob, or nil. Split out of Sync on 6 Oct 2026:
--- on Forever the addon may not set a mark, so the farm key's macro asks this and /tm does it.
function S.Want(db)
  local name = db.active
  if not name then return nil end
  local map, x, y = S.Here()
  if not map then return nil end
  local list = db.spots and db.spots[name]
  if not list then return nil end
  local here = S.Assign(db, name)
  if here then
    local sb = nearest(here.subs, map, x, y, math.max(S.SubRadius(db) * 2, 10))
    return sb and sb.mark or here.mark
  end
  local z = nearest(list, map, x, y, S.Reach(db))
  return z and z.mark
end

function S.Sync(db)
  -- Forever: SetRaidTarget is protected (BugGrabber, 6 Oct) - the farm key's /tm marks instead.
  -- FIRST, before the target's name or flags are read: either can be a secret there.
  if NS.Farm and NS.Farm.Restricted and NS.Farm.Restricted() then return end
  local name = db.active
  if not name or not UnitExists("target") or UnitName("target") ~= name then return end
  if UnitIsDead("target") or (UnitIsTapDenied and UnitIsTapDenied("target")) then return end
  local want = S.Want(db)
  if want and NS.Farm.Mark("target") ~= want then
    SetRaidTarget("target", want)
    return want
  end
end

-- ---------------------------------------------------------------- callout
function S.Warn(db)
  S.DoPrune(db)
  if (db.sound or "first") == "off" then return end
  local mob = S.Shown(db)
  local list = mob and db.spots and db.spots[mob]
  if not list then return end
  local here = S.Assign(db, mob)
  local now = time()
  for _, z in ipairs(list) do
    for _, sb in ipairs(z.subs) do
      if sb.respawn then
        local left = sb.respawn - (now - sb.last)
        if left <= S.WARN_AT and left > -S.WARN_AT and sb.warnedFor ~= sb.last then
          sb.warnedFor = sb.last
          local m = (z == here) and sb.mark or z.mark
          F.Speak(m and F.MARK_NAMES[m] or ("Spot " .. (z.id or 0)))
        end
      end
    end
  end
end

-- ---------------------------------------------------------------- shelf
function S.Build(db)
  if S.frame then return S.frame end
  local f = CreateFrame("Frame", "BiSToolsFarmSpots", F.frame)
  S.frame = f
  f:SetSize(S.W, F.HEADER)
  f:SetFrameStrata("MEDIUM")
  f:SetPoint("TOPLEFT", F.frame, "TOPRIGHT", 4, 0)
  F.tex(f, "BACKGROUND", "frame", F.BODY_A)
  F.border(f, "edge", 0.35)

  local head = CreateFrame("Frame", nil, f)
  S.head = head
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(F.HEADER)
  F.tex(head, "BACKGROUND", "header", F.HEAD_A)
  local hair = head:CreateTexture(nil, "BORDER")
  hair:SetPoint("BOTTOMLEFT") hair:SetPoint("BOTTOMRIGHT") hair:SetHeight(1)
  do local r, g, b = F.color("edge") hair:SetColorTexture(r, g, b, 1) end
  S.title = F.fs(head, T.text("accent", "Spawns"), 9, "ink")
  S.title:SetPoint("LEFT", 6, 0)
  -- the zone you are in, as its mark, right after the title
  S.zoneIcon = head:CreateTexture(nil, "ARTWORK")
  S.zoneIcon:SetSize(11, 11)
  S.zoneIcon:SetPoint("LEFT", S.title, "RIGHT", 4, 0)
  S.zoneIcon:Hide()
  S.closeBtn = F.HeaderButton(head, -3, "x", "Hide timers", "They keep counting.", function() S.Toggle(db, false) end, "warn")
  S.resetBtn = F.HeaderButton(head, -17, "r", "Reset", "Forget every zone and timer for this mob. /bist farm spots clear wipes all mobs.",
    function() S.ClearMob(db) end)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  body:SetHeight(1)
  S.body = body
  S.empty = F.fs(body, "kill it a few times", 9, "muted")
  S.empty:SetPoint("TOPLEFT", 6, -4)
  f:Hide()
  return f
end

function S.Row(i)
  local r = S.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, S.body)
  r:SetHeight(S.ROW)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * S.ROW)
  r:SetPoint("TOPRIGHT", 0, -(i - 1) * S.ROW)
  r.bg = F.tex(r, "BACKGROUND", "surface", 0)
  r.arrow = r:CreateTexture(nil, "ARTWORK")
  r.arrow:SetSize(12, 12)
  r.arrow:SetPoint("LEFT", 5, 0)
  r.arrow:SetTexture("Interface\\Minimap\\MinimapArrow")
  r.id = F.fs(r, "", 7, "dim")
  r.id:SetPoint("LEFT", 19, 0)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(11, 11)
  r.icon:SetPoint("LEFT", 19, 0)
  r.clock = F.fs(r, "", 9, "ink2")
  r.clock:SetPoint("LEFT", 33, 0)
  r.dist = F.fs(r, "", 8, "muted")
  r.dist:SetPoint("RIGHT", -6, 0)
  S.rows[i] = r
  return r
end

function S.Clock(sec)
  sec = math.floor(sec + 0.5)
  if sec < 0 then sec = 0 end
  return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function S.Bearing(px, py, sx, sy)
  if not GetPlayerFacing then return nil end
  local facing = GetPlayerFacing()
  if not facing then return nil end
  local dx, dy = sx - px, sy - py
  if dx == 0 and dy == 0 then return 0 end
  local toSpot = math.atan2(-dx, -dy)
  local rel = toSpot - facing
  while rel > math.pi do rel = rel - 2 * math.pi end
  while rel < -math.pi do rel = rel + 2 * math.pi end
  return rel
end

-- one timer's text + colour + sort key (smaller = higher on the shelf)
function S.Describe(sp, now)
  local elapsed = now - sp.last
  if sp.respawn then
    local left = sp.respawn - elapsed
    if left <= 0 then return "up", "good", -1e6 + math.min(elapsed - sp.respawn, 1e5) end
    if left <= 30 then return S.Clock(left), "gold", left end
    return S.Clock(left), "ink2", left
  end
  return "+" .. S.Clock(elapsed), "muted", 1e6 - elapsed
end

-- a zone's row is its soonest sub (or the zone itself if it has no subs yet)
function S.ZoneTimer(z, now)
  local best, bestKey, bt, bc
  for _, sb in ipairs(z.subs) do
    local t, c, k = S.Describe(sb, now)
    if not bestKey or k < bestKey then best, bestKey, bt, bc = sb, k, t, c end
  end
  if best then return bt, bc, bestKey end
  return S.Describe(z, now)
end

function S.Refresh(db)
  S.Warn(db)
  if not S.frame or not S.frame:IsShown() then return end
  local mob = S.Shown(db)
  local list = mob and S.List(db, mob) or {}
  local now = time()
  local map, px, py = S.Here()
  local here = mob and S.Assign(db, mob) or nil
  -- zones soonest first, each followed by its subs soonest first, indented
  local zs = {}
  for _, z in ipairs(list) do
    local text, colour, key = S.ZoneTimer(z, now)
    zs[#zs + 1] = { z = z, text = text, colour = colour, key = key }
  end
  table.sort(zs, function(a, b) return a.key < b.key end)
  local shown = {}
  for _, e in ipairs(zs) do
    local z = e.z
    shown[#shown + 1] = { x = z.x, y = z.y, map = z.map, mark = z.mark, id = z.id,
      text = e.text, colour = e.colour, indent = 0, zone = (z == here) }
    local subs = {}
    for _, sb in ipairs(z.subs) do
      local text, colour, key = S.Describe(sb, now)
      subs[#subs + 1] = { x = sb.x, y = sb.y, map = z.map, mark = sb.mark, id = sb.id,
        text = text, colour = colour, key = key, indent = 1 }
    end
    table.sort(subs, function(a, b) return a.key < b.key end)
    for _, sr in ipairs(subs) do shown[#shown + 1] = sr end
  end
  if here and here.mark then
    S.zoneIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. here.mark)
    S.zoneIcon:Show()
  else
    S.zoneIcon:Hide()
  end
  for i = 1, math.max(#shown, #S.rows) do
    local r = S.Row(i)
    local e = shown[i]
    if e then
      local ind = e.indent * S.INDENT
      r.arrow:ClearAllPoints() r.arrow:SetPoint("LEFT", 5 + ind, 0)
      r.icon:ClearAllPoints() r.icon:SetPoint("LEFT", 19 + ind, 0)
      r.id:ClearAllPoints() r.id:SetPoint("LEFT", 19 + ind, 0)
      r.clock:ClearAllPoints() r.clock:SetPoint("LEFT", 33 + ind, 0)
      if e.mark then
        r.icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. e.mark)
        r.icon:Show()
        r.id:SetText("")
      else
        r.icon:Hide()
        r.id:SetText("#" .. (e.id or 0))
      end
      -- the zone you stand in gets the accent fill, like the active farm row
      if e.zone then local br, bg, bb = F.color("accentSoft") r.bg:SetColorTexture(br, bg, bb, 1)
      else local br, bg, bb = F.color("surface") r.bg:SetColorTexture(br, bg, bb, 0) end
      r.clock:SetText(e.text)
      local cr, cg, cb = F.color(e.colour)
      r.clock:SetTextColor(cr, cg, cb, 1)
      if map and map == e.map then
        r.dist:SetText(("%dy"):format(S.Yards(map, px, py, e.x, e.y)))
        local rot = S.Bearing(px, py, e.x, e.y)
        if rot then r.arrow:SetRotation(rot) r.arrow:Show() else r.arrow:Hide() end
      else
        r.dist:SetText("")
        r.arrow:Hide()
      end
      r:Show()
    else
      r:Hide()
    end
  end
  if #shown == 0 then
    S.empty:SetText(mob and "kill it a few times" or "pick a mob to farm")
    S.empty:Show()
  else S.empty:Hide() end
  local h = math.max(#shown * S.ROW, S.ROW) + 4
  S.body:SetHeight(h)
  S.frame:SetHeight(F.HEADER + h)
end

function S.Toggle(db, want)
  F.Build(db)
  S.Build(db)
  if want == nil then want = not S.frame:IsShown() end
  db.shelf = want and true or false
  if want then
    S.frame:Show()
    S.Refresh(db)
    if not S.ticker then S.ticker = C_Timer.NewTicker(0.25, function() S.Refresh(db) end) end
  else
    S.Hide()
  end
end

function S.Hide()
  if S.ticker then S.ticker:Cancel() S.ticker = nil end
  if S.frame then S.frame:Hide() end
end

-- reopen with the window if it was open last time
local hooked = F.Hook
function F.Hook(db)
  hooked(db)
  if db.shelf and db.shown then S.Toggle(db, true) end
end
