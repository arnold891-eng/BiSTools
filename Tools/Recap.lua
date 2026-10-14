-- BiSTools / Tools / Recap.lua
-- WHAT KILLED YOU - step one: MEASURE (12 Oct 2026).
--
-- Arn, for a friend: "can we do a death recap of who or what killed him", with a League of Legends
-- death recap for the look. The combat log is closed to addons on Forever (solved.md: PARTY_KILL,
-- never the combat log). What is open is the game's own record of your last death, C_DeathRecap -
-- in the Forever census, and read by EllesmereUI's damage meters and Olympus on Arn's PC. Ellesmere's
-- note: the fields "may come back SECRET mid-combat". Nobody here knows WHICH fields, or WHEN they
-- become readable, and the whole design hangs on it: plain numbers allow totals, "48%" and "1,344
-- damage in 19 seconds"; hidden ones allow only a list the game draws for us.
--
-- So this tool does not guess. It reads the record three times - the moment you die, when the fight
-- ends, and when you ask - and `/bist recap` prints every field of every hit, as its value or as
-- <hidden>. Nothing here does arithmetic on, compares, or keys a table with anything it was handed:
-- a field is shown only after issecretvalue said it may be. No timers; two events, both rare.
local _, NS = ...
local T, R = NS.T, NS.Registry

local RC = { MAX_ROWS = 10 }
NS.Recap = RC

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end

-- a TABLE can be hidden as a whole; issecretvalue is not for tables (Overlord asks canaccessvalue)
local function hiddenTable(t)
  if issecrettable then
    local ok, yes = pcall(issecrettable, t)
    if not ok or yes == true then return true end
  end
  if canaccessvalue then
    local ok, yes = pcall(canaccessvalue, t)
    if not ok or yes ~= true then return true end
  end
  return false
end

--- One field as text, never touching a hidden one.
local function show(v)
  if hidden(v) then return "<hidden>" end
  local kind = type(v)
  if kind == "string" then return '"' .. v:sub(1, 40) .. '"' end
  if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(v) end
  return "<" .. kind .. ">"
end
RC.Show = show

--- Read the game's record of your last death, as text. A snapshot: what the game said, when.
function RC.Read(label)
  local snap = { label = label, rows = {}, hiddenFields = {}, notes = {} }
  local D = C_DeathRecap
  if not (D and D.GetRecapEvents) then
    snap.notes[#snap.notes + 1] = "this client has no death recap to read"
    return snap
  end
  if D.HasRecapEvents then
    local ok, has = pcall(D.HasRecapEvents)
    snap.has = ok and show(has) or "refused"
  end
  if D.GetRecapMaxHealth then
    local ok, hp = pcall(D.GetRecapMaxHealth)
    snap.maxHealth = ok and show(hp) or "refused"
  end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    snap.instance = ok and show(inside) or "refused"
  end
  snap.combat = InCombatLockdown and show(InCombatLockdown()) or "?"

  local ok, events = pcall(D.GetRecapEvents)
  if not ok then
    snap.notes[#snap.notes + 1] = "the game refused: " .. tostring(events)
    return snap
  end
  if events == nil then
    snap.notes[#snap.notes + 1] = "the game has no record (nothing has killed you yet)"
    return snap
  end
  if hidden(events) or (type(events) == "table" and hiddenTable(events)) then
    snap.notes[#snap.notes + 1] = "the whole record is hidden"
    return snap
  end
  if type(events) ~= "table" then
    snap.notes[#snap.notes + 1] = "the game answered " .. show(events) .. ", not a list"
    return snap
  end
  local okN, n = pcall(function() return #events end)
  snap.count = okN and n or nil
  for i = 1, math.min(snap.count or 0, RC.MAX_ROWS) do
    local row = events[i]
    if type(row) ~= "table" or hiddenTable(row) then
      snap.rows[#snap.rows + 1] = ("#%d %s"):format(i, type(row) == "table" and "<hidden hit>" or show(row))
    else
      local keys = {}
      pcall(function() for k in pairs(row) do keys[#keys + 1] = k end end)
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do
        local okV, v = pcall(function() return row[k] end)
        local s = okV and show(v) or "<refused>"
        if s == "<hidden>" or s == "<refused>" then snap.hiddenFields[tostring(k)] = true end
        parts[#parts + 1] = tostring(k) .. "=" .. s
      end
      snap.rows[#snap.rows + 1] = ("#%d %s"):format(i, table.concat(parts, " "))
    end
  end
  return snap
end

--- Print one snapshot.
function RC.Say(snap)
  if not snap then return end
  local hiddenList = {}
  for k in pairs(snap.hiddenFields) do hiddenList[#hiddenList + 1] = k end
  table.sort(hiddenList)
  NS.Print("%s: %s hits recorded · max health %s · in instance %s · in combat %s",
    T.text("accent", snap.label), tostring(snap.count or 0), tostring(snap.maxHealth or "?"),
    tostring(snap.instance or "?"), tostring(snap.combat or "?"))
  for _, note in ipairs(snap.notes) do DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("warn", note)) end
  if snap.count and snap.count > 0 then
    DEFAULT_CHAT_FRAME:AddMessage("  " .. (#hiddenList > 0
      and T.text("warn", "hidden: " .. table.concat(hiddenList, ", "))
      or T.text("good", "nothing hidden")))
  end
  for _, line in ipairs(snap.rows) do DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("muted", line)) end
end

-- ---------------------------------------------------------------- the recap, as data
-- MEASURED, 12 Oct 2026 (Arn, Ragefire Chasm, in combat, in an instance): NOTHING HIDDEN. Ten rows,
-- newest first: amount, overkill, critical, blocked, currentHP (health BEFORE the hit: 13 then 27
-- with 14 overkill), timestamp, sourceName, sourceGUID, event, school - and GetRecapMaxHealth plain.
-- So the totals are ours to add up. Each field is still asked before it is used: a player killer on
-- a PvP server is not measured yet, and a hidden field must cost the window a number, not an error.
--
-- AND FOREVER RE-NAMES A MOB ON EVERY HIT: one Molten Elemental (one GUID) was "Flashs", then
-- "Shaquanda", then "Smitecrust". So a hit belongs to its GUID, and a mob's name is the words its
-- kind's names share ("Molten Elemental"), the nicknames listed under it.
local function field(row, k)
  local ok, v = pcall(function() return row[k] end)
  if not ok or hidden(v) then return nil end
  return v
end
local function num(v) return type(v) == "number" and v or nil end

--- The game's record, or nil and why. Newest first, as the game gives it.
function RC.Fetch()
  local D = C_DeathRecap
  if not (D and D.GetRecapEvents) then return nil, "this client has no death recap" end
  local ok, events = pcall(D.GetRecapEvents)
  if not ok then return nil, "the game refused" end
  if type(events) ~= "table" or hidden(events) or hiddenTable(events) then return nil, "no record" end
  return events
end

--- Each hit as plain values; a field the game hid is simply missing.
function RC.Hits(events)
  local hits = {}
  for i = 1, #(events or {}) do
    local row = events[i]
    if type(row) == "table" and not hiddenTable(row) then
      local spell = field(row, "spellName")
      local ev = field(row, "event")
      hits[#hits + 1] = {
        amount = num(field(row, "amount")), overkill = num(field(row, "overkill")),
        crit = field(row, "critical") == true, blocked = num(field(row, "blocked")),
        absorbed = num(field(row, "absorbed")), resisted = num(field(row, "resisted")),
        hp = num(field(row, "currentHP")), t = num(field(row, "timestamp")),
        name = type(field(row, "sourceName")) == "string" and field(row, "sourceName") or nil,
        guid = type(field(row, "sourceGUID")) == "string" and field(row, "sourceGUID") or nil,
        spell = type(spell) == "string" and spell
          or ((type(ev) == "string" and ev:find("^SWING")) and "melee") or "?",
      }
    else
      hits[#hits + 1] = { hiddenHit = true, spell = "?" }
    end
  end
  return hits
end

-- "Creature-0-4621-389-178375-11321-0003CD6" -> "11321": the kind of mob, whatever its nickname
local function kindOf(guid)
  if type(guid) ~= "string" then return nil end
  if guid:find("^Player%-") then return guid end
  return guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") or guid
end

-- the words every nickname of one kind starts with: "Molten Elemental"
local function shared(names)
  local first = names[1]
  if not first then return "?" end
  if #names == 1 then return first end
  local words = {}
  for w in first:gmatch("%S+") do words[#words + 1] = w end
  local keep = #words
  for i = 2, #names do
    local same = 0
    local k = 0
    for w in names[i]:gmatch("%S+") do
      k = k + 1
      if k > keep or w ~= words[k] then break end
      same = k
    end
    keep = math.min(keep, same)
  end
  if keep == 0 then return first end
  return table.concat(words, " ", 1, keep)
end
RC.Shared = shared

--- Who did what: attackers by GUID, the killer (the newest hit's), the two biggest others, totals.
function RC.Summary(hits, maxHP)
  local s = { hits = hits, attackers = {}, maxHP = num(maxHP), total = 0, whole = true }
  local by, kinds = {}, {}
  for i = #hits, 1, -1 do                                  -- oldest first: names in the order they came
    local h = hits[i]
    local key = h.guid or h.name or "?"
    local a = by[key]
    if not a then
      a = { key = key, kind = kindOf(h.guid) or key, names = {}, seen = {}, total = 0, crits = 0, hits = 0,
            spells = {}, whole = true }
      by[key] = a
      s.attackers[#s.attackers + 1] = a
    end
    if h.name and not a.seen[h.name] then a.seen[h.name] = true a.names[#a.names + 1] = h.name end
    kinds[a.kind] = kinds[a.kind] or {}
    if h.name then table.insert(kinds[a.kind], h.name) end
    a.hits = a.hits + 1
    if h.crit then a.crits = a.crits + 1 end
    if h.amount then
      a.total = a.total + h.amount
      s.total = s.total + h.amount
      a.spells[h.spell] = (a.spells[h.spell] or 0) + h.amount
    else
      a.whole, s.whole = false, false
    end
  end
  for _, a in ipairs(s.attackers) do
    local kindNames = kinds[a.kind] or {}
    a.title = (#kindNames > 0) and shared(kindNames) or a.key
    -- what is left of each nickname once the kind's words are taken off
    local nick = {}
    for _, n in ipairs(a.names) do
      local rest = n:sub(#a.title + 2)
      if n:sub(1, #a.title) == a.title and rest ~= "" then nick[#nick + 1] = rest end
    end
    a.nicks = nick
    -- WHAT IT MOSTLY HIT YOU WITH (Arn, 12 Oct, killed by three hunters: "their main spell")
    for spell, amount in pairs(a.spells) do
      if not a.topAmt or amount > a.topAmt then a.top, a.topAmt = spell, amount end
    end
    -- A PLAYER: their class, for the colour of their name (GetPlayerInfoByGUID, in the census)
    if type(a.key) == "string" and a.key:find("^Player%-") then
      a.player = true
      if GetPlayerInfoByGUID then
        local ok, _, class = pcall(GetPlayerInfoByGUID, a.key)
        if ok and type(class) == "string" and not hidden(class) then a.class = class end
      end
    end
  end
  local newest = hits[1]
  s.killer = newest and by[newest.guid or newest.name or "?"]
  s.blow = newest
  local others = {}
  for _, a in ipairs(s.attackers) do if a ~= s.killer then others[#others + 1] = a end end
  table.sort(others, function(x, y) return x.total > y.total end)
  s.assists = { others[1], others[2] }
  local oldest = hits[#hits]
  if newest and oldest and newest.t and oldest.t then s.seconds = newest.t - oldest.t end
  s.startHP = oldest and oldest.hp
  return s
end

-- ---------------------------------------------------------------- the window
-- Built on the farm window's kit (NS.Farm: F.tex, F.fs, F.border, F.HeaderButton) and the family
-- prompt. Plain frames only - nothing secure - so it may open in a fight.
RC.W, RC.HEADER, RC.PAD = 360, 16, 6
RC.CARD_H, RC.STRIP_H, RC.ROW_H, RC.ROWS = 66, 28, 12, 6
RC.RIVAL_ROWS = 10

local function K() return NS.Farm end

local function fitText(fs, text, width)
  if BiSTheme and BiSTheme.Fit then BiSTheme.Fit(fs, text, width) else fs:SetText(text) end
end

local function pct(n, total)
  if not (n and total and total > 0) then return "" end
  return (" (%d%%)"):format(math.floor(n / total * 100 + 0.5))
end

-- ---------------------------------------------------------------- rivals
-- Arn, 12 Oct, after three hunters killed him: "if i click on the player they get added to my
-- rival list for that player tracker pvp". Kept by NAME - the name is what a nameplate will show
-- the tracker - with class, when first added, and how often they have killed you since.
function RC.Rivals(db)
  db.rivals = type(db.rivals) == "table" and db.rivals or {}
  return db.rivals
end

--- Add a player to your rivals, or take them off. Answers true when they are a rival now.
--- /bist recap rival: your target added as a rival (or, already one, taken off). The battleground
--- road (13 Oct): the right-click menu cannot carry our line inside an instance (RC.MenuSafe), and
--- this touches nothing of the game's - it reads the target and writes our own list. Works in a
--- macro on a button.
function RC.RivalFromTarget(db)
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not hidden(v) then return v end
  end
  if ask(UnitExists, "target") ~= true then return NS.Print("target a player first") end
  if ask(UnitIsPlayer, "target") ~= true then return NS.Print("your target is not a player") end
  local name = ask(GetUnitName, "target", false)
  if type(name) ~= "string" or name == "" or name == (UNKNOWNOBJECT or "Unknown") then name = ask(UnitName, "target") end
  if type(name) ~= "string" or name == "" or name == (UNKNOWNOBJECT or "Unknown") then
    return NS.Print("the game is not giving your target's name right now")
  end
  if name == ask(UnitName, "player") then return NS.Print("that is you") end
  local r, key = RC.Find(db, name)
  if r then return RC.ToggleRival(db, { player = true, title = key }) end
  if RC.Friendly("target") then return NS.Print("%s is friendly - rivals are enemy players", name) end
  local okC, _, class = pcall(UnitClass, "target")
  if not okC or hidden(class) or type(class) ~= "string" then class = nil end
  return RC.ToggleRival(db, { player = true, title = name, class = class, key = ask(UnitGUID, "target") })
end

function RC.ToggleRival(db, a)
  if not (a and a.player and type(a.title) == "string") then return nil end
  local list = RC.Rivals(db)
  if list[a.title] then
    list[a.title] = nil
    RC.UnmarkRival(a.title)
    RC.ApplyButton(db)
    NS.Print("%s is no longer a rival", a.title)
    RC.PaintRivals()                            -- the drawer, too (it kept showing them)
    return false
  end
  -- GOLD from the start: a rival you just clicked is the one you are hunting (Arn, 12 Oct: "current
  -- target gold, all previous targets silver, can click them again to turn them gold")
  -- added inside a battleground or an arena: for THAT match only (Arn, 14 Oct: "it resets at the end
  -- of the bg - dont want a rival list that's 10000 names long after doing many bgs")
  local bg = RC.InPvP() or nil
  list[a.title] = { class = a.class, guid = a.key, added = time and time() or 0, kills = 0, active = true, bg = bg }
  NS.Print("%s added to your rivals%s", T.text("warn", a.title), bg and " for this match" or "")
  RC.PaintRivals()
  RC.ApplyButton(db)
  return true
end

--- A rival killed you again: counted. A battleground rival who has killed you RC.KEEP_AFTER times
--- in the match is kept for good (Arn, 14 Oct: "more than 3 times like 10 times or something").
RC.KEEP_AFTER = 10
function RC.KilledBy(db, rival, name)
  rival.kills = (rival.kills or 0) + 1
  rival.last = time and time() or 0
  if rival.bg and rival.kills >= RC.KEEP_AFTER then
    rival.bg = nil
    NS.Print("%s has killed you %d times - kept as a rival for good", T.text("warn", tostring(name)), rival.kills)
  end
end

--- Out of the battleground: its rivals go. A /reload inside it keeps them (still in PvP).
function RC.DropMatchRivals(db)
  if RC.InPvP() then return 0 end
  local list, n = RC.Rivals(db), 0
  for name, r in pairs(list) do
    if type(r) == "table" and r.bg then
      list[name] = nil
      RC.UnmarkRival(name)
      n = n + 1
    end
  end
  if n > 0 then
    NS.Print("the match is over: %d battleground rival(s) let go", n)
    RC.PaintRivals()
    RC.ApplyButton(db)
  end
  return n
end

--- Gold (hunted: the tracker calls them out) or silver (remembered, quiet).
function RC.SetActive(db, name, on)
  local r = RC.Rivals(db)[name]
  if not r then return nil end
  r.active = on and true or false
  if not r.active then RC.UnmarkRival(name) end
  RC.ApplyButton(db)
  RC.PaintRivals()
  return r.active
end

--- How many are gold. The tracker asks this first and stops at zero - so a city full of
--- nameplates costs nothing to a player who is hunting nobody.
function RC.GoldCount(db)
  local n = 0
  for _, r in pairs(RC.Rivals(db)) do if r.active then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------- the tracker
-- A GOLD RIVAL IN SIGHT: a nameplate appearing, your target, or your mouse over them. Names are read
-- the farm tool's way (F.Name: plain or nil - a nameplate's name can be secret in an instance), and
-- compared as strings, which is ours to do. One call-out per rival per RC.ALERT_GAP seconds: a rival
-- who stays on screen is news once, not every frame.
RC.ALERT_GAP = 60

local function place()
  local zone = GetZoneText and GetZoneText() or ""
  local sub = GetSubZoneText and GetSubZoneText() or ""
  if hidden(zone) then zone = "" end
  if hidden(sub) then sub = "" end
  if sub ~= "" and sub ~= zone then return sub end
  return zone
end

-- WHAT THE TRACKER LAST SAW, AND WHY IT STAYED QUIET (12 Oct 2026). Arn, with Hunting Moms on his
-- target: "dont think i got a notification or sound". /bist recap why prints this. Kept in three
-- plain fields, not a table per look: a nameplate storm must not churn memory for a diagnostic.
local function looked(unit, name, why)
  RC.lookUnit, RC.lookName, RC.lookWhy = unit, name, why
  return nil
end

-- ---------------------------------------------------------------- the crosshair on a rival's nameplate
-- Arn, 12 Oct, in a crowd at Hillsbrad: "is there a way to draw a crosshairs like our healing addon via
-- the name plates" ... "gold rivals only, pulsing". BiS Healing's target crosshair - thick corner
-- brackets, a tick in from each side, outlined - in red, pinned to the rival's nameplate so the client
-- carries it as they move: no OnUpdate, nothing run per frame. The pulse is the client's own
-- animation, like the shield button's. A nameplate the client locks away (IsForbidden - inside an
-- instance, possibly) gets no crosshair and costs no error.
RC.marks, RC.markPool = {}, {}
-- the rails hang MARK_H under the plate: a player's height at fighting range (nameplates keep their
-- size with distance and bodies do not, so far off the frame is roomier than the body)
RC.MARK_ARM, RC.MARK_THICK, RC.MARK_H = 8, 2, 70
RC.MARK_WIDE, RC.MARK_W = 0.5, 60      -- half the plate's width; 60 px when the plate will not say
RC.MARK_RED = { 1.00, 0.18, 0.18 }
-- RED FOR PLAYERS, PURPLE FOR MOBS (Arn, 12 Oct: "lets keep red for players purple for mobs?"). Your rivals
-- red; a GUILD rival, added by somebody else, amber ("show with a different color crosshair to know it was
-- from someone else"); the mob you farm and the mobs RestedXP's guide wants (FarmGuide.lua), BiS purple.
RC.MOB_PURPLE = { 0.73, 0.50, 1.00 }
RC.MARK_COLOUR = { own = RC.MARK_RED, guild = { 1.00, 0.62, 0.10 }, farm = RC.MOB_PURPLE, guide = RC.MOB_PURPLE }

local function bar(f, layer, r, g, b)
  local t = f:CreateTexture(nil, layer)
  t:SetColorTexture(r, g, b, 1)
  return t
end

-- ARN'S SHAPE (12 Oct, the second ask): the nameplate on top, and under it a rail down each side of
-- the body with a tick pointing in at the middle -
--      [name plate]
--      |          |
--      |_        -|
--      |          |
-- Each piece drawn twice: black underneath, a pixel wider all round, red on top.
-- AND OTHER SHAPES TO PLAY WITH (Arn, 12 Oct: "maybe in the recap or options we can play around with
-- different crosshairs"). Each is built from the same outlined red pieces, in the same frame - half
-- the plate's width, MARK_H tall, under the plate:
--   rails    | _       - |   a rail down each side, a tick in at the middle (Arn's)
--   L        BiS Healing's target brackets: an L at each corner
--   aim      a scope: a line in from the middle of each side, a gap round the centre
--   box      a thin outline all the way round
-- and "none" (Arn, 12 Oct: "they can select none cross hair if they dont want one"): no mark at all - the
-- warning, the sound and the target button still work
RC.STYLES = { "rails", "L", "aim", "box", "scope", "drop", "chevron", "tee", "none" }
RC.SIGHT_LEN = 14

local function crosshair(f, style, colour)
  local T, A = RC.MARK_THICK, RC.MARK_ARM
  local c = colour or RC.MARK_RED
  -- a fixed-size piece at one anchor
  local function piece(point, w, h, x, y)
    local o = bar(f, "BORDER", 0, 0, 0)
    o:SetPoint(point, f, point, x, y) o:SetSize(w + 2, h + 2)
    local t = bar(f, "ARTWORK", c[1], c[2], c[3])
    t:SetPoint(point, f, point, x + (point:find("LEFT") and 1 or point:find("RIGHT") and -1 or 0),
      y + (point:find("TOP") and -1 or point:find("BOTTOM") and 1 or 0))
    t:SetSize(w, h)
    f.parts[#f.parts + 1] = t
    return t
  end
  -- a whole edge, stretched between two corners
  local function edge(p1, p2, across)
    local o = bar(f, "BORDER", 0, 0, 0)
    o:SetPoint(p1, f, p1) o:SetPoint(p2, f, p2)
    if across == "h" then o:SetHeight(T + 2) else o:SetWidth(T + 2) end
    local t = bar(f, "ARTWORK", c[1], c[2], c[3])
    local dx, dy = (across == "v") and (p1:find("LEFT") and 1 or -1) or 0, (across == "h") and (p1:find("TOP") and -1 or 1) or 0
    t:SetPoint(p1, f, p1, dx, dy) t:SetPoint(p2, f, p2, dx, dy)
    if across == "h" then t:SetHeight(T) else t:SetWidth(T) end
    f.parts[#f.parts + 1] = t
    return t
  end
  -- a piece centred on the frame's middle, moved by (x, y), turned by `rot` (radians) - the game
  -- turns a texture about its own centre, so the black outline is turned the same way
  local function mid(x, y, w, h, rot)
    local o = bar(f, "BORDER", 0, 0, 0)
    o:SetPoint("CENTER", f, "CENTER", x, y) o:SetSize(w + 2, h + 2)
    local t = bar(f, "ARTWORK", c[1], c[2], c[3])
    t:SetPoint("CENTER", f, "CENTER", x, y) t:SetSize(w, h)
    if rot and t.SetRotation then
      pcall(o.SetRotation, o, rot)
      pcall(t.SetRotation, t, rot)
    end
    f.parts[#f.parts + 1] = t
    return t
  end
  f.style = style
  if style == "L" then
    for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      piece(p, A + 4, T, 0, 0)                    -- the flat arm of the L
      piece(p, T, A + 4, 0, 0)                    -- and the upright one
    end
  elseif style == "aim" then
    local L = RC.SIGHT_LEN
    piece("TOP", T, L, 0, 0) piece("BOTTOM", T, L, 0, 0)
    piece("LEFT", L, T, 0, 0) piece("RIGHT", L, T, 0, 0)
  elseif style == "box" then
    edge("TOPLEFT", "TOPRIGHT", "h") edge("BOTTOMLEFT", "BOTTOMRIGHT", "h")
    edge("TOPLEFT", "BOTTOMLEFT", "v") edge("TOPRIGHT", "BOTTOMRIGHT", "v")
  -- AND FOUR FROM ARN'S PICTURES (12 Oct, "more ideas"): a rifle scope, an ACOG drop, a chevron, a tee.
  -- Drawn round the frame's centre - the middle of the body under the nameplate.
  elseif style == "scope" then
    local P, L = 4, 12                            -- the thick posts, in from each edge
    piece("TOP", P, L, 0, 0) piece("BOTTOM", P, L, 0, 0)
    piece("LEFT", L, P, 0, 0) piece("RIGHT", L, P, 0, 0)
    mid(0, 9, 1, 10) mid(0, -9, 1, 10)            -- the thin lines, stopping short of the centre
    mid(-9, 0, 10, 1) mid(9, 0, 10, 1)
    mid(0, 8, 5, 1) mid(0, -8, 5, 1)              -- a range tick across each thin line
    mid(-8, 0, 1, 5) mid(8, 0, 1, 5)
    mid(0, 0, 3, 3)                               -- the dot
  elseif style == "drop" then
    mid(-3, 2, 7, T, math.pi / 4)                 -- the chevron's two slants, meeting on top
    mid(3, 2, 7, T, -math.pi / 4)
    mid(0, -9, 1, 14)                             -- the ladder below it
    mid(0, -5, 6, 1) mid(0, -10, 5, 1) mid(0, -15, 4, 1)
  elseif style == "chevron" then
    mid(-4, 0, 10, T + 1, math.pi / 4)
    mid(4, 0, 10, T + 1, -math.pi / 4)
  elseif style == "tee" then
    mid(0, 3, 16, T + 1)                          -- the bar
    mid(0, -3, T + 1, 12)                         -- and the stem down from its middle
  else
    f.style = "rails"
    f.leftRail = piece("TOPLEFT", T, RC.MARK_H, 0, 0)
    f.rightRail = piece("TOPRIGHT", T, RC.MARK_H, 0, 0)
    f.leftTick = piece("LEFT", A, T, 0, 0)        -- "_", in from the left at the middle
    f.rightTick = piece("RIGHT", A, T, 0, 0)      -- "-", in from the right
  end
end

--- Pick a crosshair; every rival on screen is redrawn in it at once, so styles can be compared.
function RC.SetStyle(db, style)
  local valid = false
  for _, s in ipairs(RC.STYLES) do if s == style then valid = true end end
  if not valid then return false end
  db.style = style
  local live = {}
  for unit, f in pairs(RC.marks) do live[unit] = { f.rival, f.kind } end
  for unit in pairs(live) do RC.UnmarkUnit(unit) end
  for _, pool in pairs(RC.markPool) do for _, f in ipairs(pool) do f:Hide() end end
  RC.markPool = {}                                -- frames of the old shape are not reused
  RC.style = style
  for unit, m in pairs(live) do RC.MarkPlate(unit, m[1], m[2]) end
  return true
end

local function newMark(kind)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f.parts = {}
  f.kind = kind
  crosshair(f, RC.style or "rails", RC.MARK_COLOUR[kind] or RC.MARK_RED)
  if f.CreateAnimationGroup then
    local ok, pulse = pcall(f.CreateAnimationGroup, f)
    if ok and pulse then
      local fade = pulse:CreateAnimation("Alpha")
      fade:SetFromAlpha(1) fade:SetToAlpha(0.35) fade:SetDuration(0.6)
      if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
      pulse:SetLooping("BOUNCE")
      f.pulse = pulse
    end
  end
  return f
end

-- a crosshair frame of a kind, outside the plate system: the threat window's preview draws one
RC.NewMark = newMark

--- Put the crosshair on this nameplate unit for that rival. Answers true when it stands.
function RC.MarkPlate(unit, rival, kind)
  kind = kind or "own"
  if (RC.style or "rails") == "none" then return false end
  if type(unit) ~= "string" or not unit:find("^nameplate") then return false end
  if RC.marks[unit] then
    if RC.marks[unit].kind == kind then RC.marks[unit].rival = rival return true end
    RC.UnmarkUnit(unit)                          -- a guild rival who became yours: redrawn in your colour
  end
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return false end
  local okP, plate = pcall(get, unit)
  if not okP or not plate then return false end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return false end
  RC.markPool[kind] = RC.markPool[kind] or {}
  local f = table.remove(RC.markPool[kind]) or newMark(kind)
  -- under the plate, centred, HALF its width (Arn, seeing them in game: "maybe we can tighten it up
  -- 50%" - a plate is far wider than a body), MARK_H tall: the rails frame the body below the name
  local placed = pcall(function()
    local pw = plate:GetWidth()
    if type(pw) ~= "number" or hidden(pw) or pw <= 0 then pw = RC.MARK_W / RC.MARK_WIDE end
    f:ClearAllPoints()
    f:SetSize(math.floor(pw * RC.MARK_WIDE + 0.5), RC.MARK_H)
    f:SetPoint("TOP", plate, "BOTTOM", 0, -2)
  end)
  if not placed then table.insert(RC.markPool[kind], f) return false end
  f.rival, f.unit = rival, unit
  f:Show()
  if f.pulse then f.pulse:Play() end
  RC.marks[unit] = f
  return true
end

--- Take the crosshair off one nameplate (it left), or off every plate of one rival (silver, forgotten).
function RC.UnmarkUnit(unit)
  local f = RC.marks[unit]
  if not f then return end
  if f.pulse then f.pulse:Stop() end
  f:Hide()
  f:ClearAllPoints()
  RC.marks[unit] = nil
  RC.markPool[f.kind or "own"] = RC.markPool[f.kind or "own"] or {}
  table.insert(RC.markPool[f.kind or "own"], f)
end
function RC.UnmarkRival(rival)
  for unit, f in pairs(RC.marks) do
    if f.rival == rival then RC.UnmarkUnit(unit) end
  end
end

-- ---------------------------------------------------------------- guild rivals
-- Arn, 12 Oct: "yes build it and lets make it a toggle dont show guild rivals etc or show with a
-- different color crosshair to know it was from someone else". A GUILD rival is on everyone's list:
-- added from the right-click menu, learned by every guildmate running BiS Tools, drawn AMBER where
-- yours are red. Whoever has one in sight says so to the guild - once a minute per rival - and the
-- drawer shows who saw them where. Over LibBiSComm's GUILD channel (a guild-scoped MOD, BiSLoot's
-- road): the lib only lets a guild-roster sender in, drops our own echo, and limits each sender.
--   ADD|name|class   DEL|name   SEEN|name|where   ASK   LIST|name|class|name|class...
-- A newcomer ASKs once; one guildmate answers (whoever's jittered timer fires first - the others
-- hear the LIST and stand down).
RC.MOD, RC.SEEN_GAP, RC.LIST_PER = "RIVAL", 60, 6

function RC.GuildRivals(db)
  db.guildRivals = type(db.guildRivals) == "table" and db.guildRivals or {}
  return db.guildRivals
end

local function cleanName(v)
  if type(v) ~= "string" or hidden(v) or v == "" or #v > 48 or v:find("[|\n]") then return nil end
  return v
end

local function lib()
  local l = NS.Comm and NS.Comm.Lib and NS.Comm.Lib()
  if l and l.Enabled and l:Enabled() then return l end
  return nil
end

local function send(cmd, ...)
  local l = lib()
  if not l then return false end
  return l:SendTo("GUILD", RC.MOD, cmd, ...)
end

--- A guild rival in, from you (sent) or from the guild (quiet).
function RC.GuildAdd(db, name, class, by, fromGuild)
  name = cleanName(name)
  if not name then return false end
  local g = RC.GuildRivals(db)
  local e = g[name] or { added = time and time() or 0 }
  e.class = (type(class) == "string" and class ~= "" and not hidden(class)) and class or e.class
  e.by = e.by or by
  g[name] = e
  if not fromGuild then
    send("ADD", name, e.class or "")
    NS.Print("%s is a guild rival now - the guild sees them in amber", T.text("warn", name))
  end
  RC.PaintRivals()
  return true
end

function RC.GuildDel(db, name, fromGuild)
  name = cleanName(name)
  if not name or not RC.GuildRivals(db)[name] then return false end
  RC.GuildRivals(db)[name] = nil
  for unit, f in pairs(RC.marks) do
    if f.rival == name and f.kind == "guild" then RC.UnmarkUnit(unit) end
  end
  if not fromGuild then send("DEL", name) NS.Print("%s is off the guild's rivals", name) end
  RC.PaintRivals()
  return true
end

--- The guild rival a name belongs to (whole name, or the character name alone), or nil.
function RC.FindGuild(db, name)
  if type(name) ~= "string" then return nil end
  local g = RC.GuildRivals(db)
  if g[name] then return g[name], name end
  for key, e in pairs(g) do
    if key:match("^(%S+)") == name then return e, key end
  end
  return nil
end

-- what the guild hears
function RC.OnGuild(db, sender, cmd, a, b, ...)
  if db.guildShow == false and cmd ~= "ASK" then return end   -- switched off: deaf to it
  if cmd == "ADD" then
    RC.GuildAdd(db, a, b, sender, true)
  elseif cmd == "DEL" then
    RC.GuildDel(db, a, true)
  elseif cmd == "SEEN" then
    local name = cleanName(a)
    local e = name and RC.GuildRivals(db)[name]
    if e then
      e.seen = time and time() or 0
      e.where = cleanName(b) or ""
      e.seenBy = cleanName(sender)
      RC.PaintRivals()
    end
  elseif cmd == "ASK" then
    if not next(RC.GuildRivals(db)) then return end
    local asked = GetTime and GetTime() or 0
    RC.askedAt = asked
    local after = (C_Timer and C_Timer.After)
    if not after then return end
    after(1 + math.random() * 3, function()
      if RC.listHeardAt and RC.listHeardAt >= asked then return end   -- somebody answered first
      RC.SendList(db)
    end)
  elseif cmd == "LIST" then
    RC.listHeardAt = GetTime and GetTime() or 0
    local pairs_ = { a, b, ... }
    for i = 1, #pairs_, 2 do RC.GuildAdd(db, pairs_[i], pairs_[i + 1], sender, true) end
  end
end

function RC.SendList(db)
  local names = {}
  for name in pairs(RC.GuildRivals(db)) do names[#names + 1] = name end
  table.sort(names)
  for i = 1, #names, RC.LIST_PER do
    local args = {}
    for j = i, math.min(#names, i + RC.LIST_PER - 1) do
      args[#args + 1] = names[j]
      args[#args + 1] = RC.GuildRivals(db)[names[j]].class or ""
    end
    send("LIST", unpack(args))
  end
end

function RC.HookGuild(db)
  local l = NS.Comm and NS.Comm.Lib and NS.Comm.Lib()
  if not (l and l.RegisterGuildMod and l.RegisterHandler) or RC.guildHooked then return false end
  l:RegisterGuildMod(RC.MOD)
  for _, cmd in ipairs({ "ADD", "DEL", "SEEN", "ASK", "LIST" }) do
    l:RegisterHandler(RC.MOD, cmd, function(sender, ...) RC.OnGuild(db, sender, cmd, ...) end)
  end
  RC.guildHooked = true
  -- a newcomer asks once, after the roster has had time to arrive
  if C_Timer and C_Timer.After then
    C_Timer.After(15, function() if IsInGuild and IsInGuild() and db.guildShow ~= false then send("ASK") end end)
  end
  return true
end

-- ---------------------------------------------------------------- guildmates, in passing
-- Arn, 12 Oct: "while not in a party and we see their name plate no noise just a small little cross
-- hair or something so if we pass by each other in town but turn off during party and raid and
-- battleground so its not spammy". A small teal + under a guildmate's nameplate; nothing else. Only
-- while SOLO - not in a group, not in a battleground or arena - and gone the moment that changes.
RC.mates = {}
RC.matePool = {}
RC.MATE = { 0.31, 0.82, 0.81 }

function RC.Solo()
  if IsInGroup and IsInGroup() then return false end
  if IsInInstance then
    local ok, inside, kind = pcall(IsInInstance)
    if ok and not hidden(kind) and (kind == "pvp" or kind == "arena") then return false end
  end
  return true
end

--- THE GUILD CREST (Arn, 14 Oct: "guild mates some type of clan icon ... for pals you have to
--- select it, guild mates you dont have to like but there should be respect at least in the icon"):
--- a small teal shield, a chevron inside, in glowing strokes. A client without Lines keeps the +.
RC.CREST = {
  { 1, 1, 1, 0.2 }, { 1, 0.2, 0.6, -0.45 }, { 0.6, -0.45, 0, -1 }, { 0, -1, -0.6, -0.45 },
  { -0.6, -0.45, -1, 0.2 }, { -1, 0.2, -1, 1 }, { -1, 1, 1, 1 },          -- the shield
  { -0.5, 0.4, 0, -0.05 }, { 0, -0.05, 0.5, 0.4 },                        -- the chevron
}

local function newMate()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetSize(11, 11)
  local c = RC.MATE
  if f.CreateLine then
    f:SetSize(11, 13)
    f.parts = {}
    local x, y = 11 / 2 - 1, 13 / 2 - 1
    for _, s in ipairs(RC.CREST) do
      for _, layer in ipairs({ { 3, 0.3 }, { 1.4, 1 } }) do
        local l = f:CreateLine(nil, "ARTWORK")
        l:SetTexture("Interface\\Buttons\\WHITE8X8")
        l:SetVertexColor(c[1], c[2], c[3], layer[2])
        l:SetThickness(layer[1])
        l:SetStartPoint("CENTER", f, s[1] * x, s[2] * y)
        l:SetEndPoint("CENTER", f, s[3] * x, s[4] * y)
        f.parts[#f.parts + 1] = l
      end
    end
    f.bar = f.parts[2]
    f.crest = true
    return f
  end
  for _, d in ipairs({ { 11, 2 }, { 2, 11 } }) do
    local o = bar(f, "BORDER", 0, 0, 0) o:SetPoint("CENTER") o:SetSize(d[1] + 2, d[2] + 2)
    local t = bar(f, "ARTWORK", c[1], c[2], c[3]) t:SetPoint("CENTER") t:SetSize(d[1], d[2])
    f.bar = t
  end
  return f
end

function RC.MarkMate(unit)
  if RC.mates[unit] then return true end
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return false end
  local okP, plate = pcall(get, unit)
  if not okP or not plate then return false end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return false end
  local f = table.remove(RC.matePool) or newMate()
  if not pcall(function() f:ClearAllPoints() f:SetPoint("TOP", plate, "BOTTOM", 0, -2) end) then
    table.insert(RC.matePool, f)
    return false
  end
  f:Show()
  RC.mates[unit] = f
  return true
end

function RC.UnmarkMate(unit)
  local f = RC.mates[unit]
  if not f then return end
  f:Hide() f:ClearAllPoints()
  RC.mates[unit] = nil
  table.insert(RC.matePool, f)
end

function RC.ClearMates() for unit in pairs(RC.mates) do RC.UnmarkMate(unit) end end

--- Is this nameplate a guildmate? A plain yes only.
local function isMate(unit)
  if not UnitIsInMyGuild then return false end
  local ok, yes = pcall(UnitIsInMyGuild, unit)
  return ok and not hidden(yes) and yes == true
end

-- ---------------------------------------------------------------- pals
-- Arn, 14 Oct, right after rivals became enemies only: "i do want a friendly list too ... puts a
-- tiny little heart green when you add a pal when you right click on and add a pal". db.pals[name] =
-- { guid, added }. A tiny green heart over a pal's nameplate, OUT OF COMBAT ONLY ("only works out of
-- combat for now"): a fight takes every heart down, its end puts them back. Friendly players only.
RC.hearts, RC.heartPool, RC.plates = {}, {}, {}
RC.PAL = { 0.30, 0.95, 0.45 }

function RC.Pals(db)
  db.pals = type(db.pals) == "table" and db.pals or {}
  return db.pals
end

--- A heart of glowing strokes (the classic curve, 12 pieces), or a small green square without Lines.
local function newHeart()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetSize(12, 11)
  local c = RC.PAL
  if not f.CreateLine then
    local t = bar(f, "ARTWORK", c[1], c[2], c[3]) t:SetPoint("CENTER") t:SetSize(6, 6)
    return f
  end
  local pts = {}
  for i = 0, 12 do
    local t = i / 12 * 2 * math.pi
    local x = 16 * math.sin(t) ^ 3
    local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
    pts[#pts + 1] = { x / 17 * 6, y / 17 * 5.5 }
  end
  f.parts = {}
  for i = 1, #pts - 1 do
    for _, layer in ipairs({ { 3.5, 0.35 }, { 1.6, 1 } }) do
      local l = f:CreateLine(nil, "ARTWORK")
      l:SetTexture("Interface\\Buttons\\WHITE8X8")
      l:SetVertexColor(c[1], c[2], c[3], layer[2])
      l:SetThickness(layer[1])
      l:SetStartPoint("CENTER", f, pts[i][1], pts[i][2])
      l:SetEndPoint("CENTER", f, pts[i + 1][1], pts[i + 1][2])
      f.parts[#f.parts + 1] = l
    end
  end
  return f
end

--- The pal a nameplate (or the target) belongs to, or nil: whole names first, a one-word plate by
--- its first word, never a readable GUID that is somebody else's - the rival lessons, kept.
function RC.PalFor(db, unit)
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not hidden(v) then return v end
  end
  local list = RC.Pals(db)
  if next(list) == nil then return nil end
  local whole = ask(GetUnitName, unit, false)
  local name = (type(whole) == "string" and whole ~= "") and whole or (NS.Farm and NS.Farm.Name(unit))
  if type(name) ~= "string" then return nil end
  local p, key = list[name], name
  if not p and not name:find(" ", 1, true) then
    for k, e in pairs(list) do if k:match("^(%S+)") == name then p, key = e, k break end end
  end
  if p and type(p.guid) == "string" then
    local guid = ask(UnitGUID, unit)
    if type(guid) == "string" and guid ~= p.guid then return nil end
  end
  return p, key
end

function RC.UnmarkPal(unit)
  local f = RC.hearts[unit]
  if not f then return end
  f:Hide() f:ClearAllPoints()
  RC.hearts[unit] = nil
  table.insert(RC.heartPool, f)
end

function RC.ClearPals() for unit in pairs(RC.hearts) do RC.UnmarkPal(unit) end end

--- One plate: the heart over it when it is a friendly pal and no fight is on.
function RC.SpotPal(db, unit)
  if type(unit) ~= "string" or not unit:find("^nameplate") then return false end
  if next(RC.Pals(db)) == nil then return false end                 -- nobody: one table lookup
  if InCombatLockdown and InCombatLockdown() then return false end  -- out of combat only
  if not RC.Friendly(unit) then RC.UnmarkPal(unit) return false end
  if not RC.PalFor(db, unit) then RC.UnmarkPal(unit) return false end
  if RC.hearts[unit] then return true end
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return false end
  local okP, plate = pcall(get, unit)
  if not okP or not plate then return false end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return false end
  local f = table.remove(RC.heartPool) or newHeart()
  if not pcall(function() f:ClearAllPoints() f:SetPoint("BOTTOM", plate, "TOP", 0, 2) end) then
    table.insert(RC.heartPool, f)
    return false
  end
  f:Show()
  RC.hearts[unit] = f
  return true
end

function RC.SpotPals(db) for unit in pairs(RC.plates) do RC.SpotPal(db, unit) end end

--- Your target becomes a pal (a friendly player, not you), or - a pal already - stops being one.
function RC.PalFromTarget(db)
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not hidden(v) then return v end
  end
  if ask(UnitExists, "target") ~= true or ask(UnitIsPlayer, "target") ~= true then
    return NS.Print("target a friendly player first")
  end
  if ask(UnitIsUnit, "player", "target") == true then return NS.Print("that is you") end
  local p, key = RC.PalFor(db, "target")
  if p then
    RC.Pals(db)[key] = nil
    RC.ClearPals() RC.SpotPals(db)
    return NS.Print("%s is no longer a pal", key)
  end
  if not RC.Friendly("target") then return NS.Print("pals are friendly players - that one is an enemy") end
  local name = ask(GetUnitName, "target", false)
  if type(name) ~= "string" or name == "" then name = ask(UnitName, "target") end
  if type(name) ~= "string" or name == "" then return NS.Print("the game is not giving your target's name right now") end
  RC.Pals(db)[name] = { guid = ask(UnitGUID, "target"), added = time and time() or 0 }
  RC.SpotPals(db)
  return NS.Print("%s added to your pals - a little green heart over them, out of combat", T.text("good", name))
end

-- ---------------------------------------------------------------- the rival target button
-- Arn, 12 Oct: "i just did /tar Ford Knox and i was able to target an enemy player what about a small
-- button that targets all our rivals". /target is a macro command, so a SECURE button may run it on a
-- click - the farm key's road. One line per gold rival, by the name the recap knows (the form Arn's
-- /tar took); the last line that finds someone wins, so the most recently seen rival goes last. A
-- secure button is rewritten OUT OF COMBAT only - a change in a fight waits for the fight to end.
RC.MACRO_MAX = 255

--- The macro: /target per gold rival, oldest-seen first, within the client's macro length.
function RC.TargetMacro(db)
  local gold = {}
  for name, r in pairs(RC.Rivals(db)) do if r.active then gold[#gold + 1] = { name = name, r = r } end end
  table.sort(gold, function(x, y) return (x.r.seen or x.r.added or 0) > (y.r.seen or y.r.added or 0) end)
  local lines, len = {}, 0
  for _, g in ipairs(gold) do                     -- most recent first, while there is room
    local line = "/target " .. g.name
    if len + #line + 1 > RC.MACRO_MAX then break end
    table.insert(lines, 1, line)                  -- ... and written so the most recent runs LAST
    len = len + #line + 1
  end
  return table.concat(lines, "\n"), #lines
end

function RC.TargetButton(db)
  if RC.tbtn then return RC.tbtn end
  local F = K()
  local b = CreateFrame("Button", "BiSToolsRivalTarget", UIParent, "SecureActionButtonTemplate")
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  F.tex(b, "BACKGROUND", "field", 0.95)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  -- crossed swords, the game's own picture for players fighting - not a hunter's shot (Arn, 12 Oct)
  b.icon:SetTexture("Interface\\Icons\\Ability_DualWield")
  b.edge = F.border(b, "warn", 1)
  -- it lives in the "BiS> tools" box (Box.lua), which places, moves and shows it
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Target a rival")
    local gold = {}
    for name, r in pairs(RC.Rivals(db)) do if r.active then gold[#gold + 1] = name end end
    table.sort(gold)
    GameTooltip:AddLine(table.concat(gold, ", "), 1, 0.82, 0.2, true)
    GameTooltip:AddLine("/bist recap key <key> binds it.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  RC.tbtn = b
  return b
end

-- ---------------------------------------------------------------- the battleground "+ rival" button
-- Arn, 13 Oct: "maybe a bg button that rivals someone so i dont have to type". The game's right-click
-- menu cannot carry our line inside an instance (RC.MenuSafe), so in a battleground or arena the
-- BiS> tools box gets a button: "+" - your target becomes a gold rival; "-" - they are one, a click
-- takes them off; dim - your target is not an enemy player. A PLAIN button (nothing secure: it reads
-- the target and writes our list), so its face may change mid-fight; the box lays it out only out of
-- combat, on the way into the battleground.

--- In a battleground or an arena?
function RC.InPvP()
  if not IsInInstance then return false end
  local ok, inside, kind = pcall(IsInInstance)
  if not ok or hidden(inside) or hidden(kind) then return false end
  return inside == true and (kind == "pvp" or kind == "arena")
end

function RC.AddButton(db)
  if RC.abtn then return RC.abtn end
  local F = K()
  local b = CreateFrame("Button", "BiSToolsRivalAdd", UIParent)
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("LeftButtonUp")
  F.tex(b, "BACKGROUND", "field", 0.95)
  -- JUST A RED "+" (Arn, 13 Oct, seeing it beside the rival target button: both wore the crossed
  -- swords and looked the same - "just keep it a red +"). No icon: the sign is the face.
  b.edge = F.border(b, "warn", 1)
  b.sign = b:CreateFontString(nil, "OVERLAY")
  b.sign:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
  b.sign:SetPoint("CENTER", b, "CENTER", 0, 1)
  local mr = RC.MARK_RED
  b.sign:SetTextColor(mr[1], mr[2], mr[3])
  b:SetScript("OnClick", function()
    RC.RivalFromTarget(R:DBFor(R:Get("recap")))
    RC.PaintAdd()
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.state == "remove" and "Take your target off your rivals" or "Make your target a rival")
    GameTooltip:AddLine("For battlegrounds and arenas, where the right-click menu cannot carry it. Same as /bist recap rival.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  RC.abtn = b
  return b
end

--- The button's face for your current target: "+", "-", or dim. Text and alpha only - safe mid-fight.
function RC.PaintAdd()
  local b = RC.abtn
  if not b then return end
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not hidden(v) then return v end
  end
  local enemy = ask(UnitIsPlayer, "target") == true and ask(UnitCanAttack, "player", "target") == true
  local name = enemy and (ask(UnitName, "target")) or nil
  if not (enemy and type(name) == "string") then
    b.state = "none"
    b.sign:SetText("+")
    b:SetAlpha(0.4)
    return
  end
  local r = RC.Find(R:DBFor(R:Get("recap")), name)
  b.state = r and "remove" or "add"
  b.sign:SetText(r and "-" or "+")
  b:SetAlpha(1)
end

--- Write the gold rivals into the button, show it when there is anyone to target, bind the key.
--- In a fight: remembered, done when it ends.
function RC.ApplyButton(db)
  if InCombatLockdown and InCombatLockdown() then RC.btnDirty = true return false end
  RC.btnDirty = nil
  local b = RC.TargetButton(db)
  local macro, n = RC.TargetMacro(db)
  b:SetAttribute("macrotext", macro)
  b.count = n
  -- shown, placed and hidden by the box; without one (it loads later), shown here
  if NS.Box and NS.Box.Refresh then NS.Box.Refresh()
  elseif n > 0 and db.button ~= false and R:Enabled("recap") then b:Show() else b:Hide() end
  ClearOverrideBindings(b)
  if db.key and n > 0 and R:Enabled("recap") then SetOverrideBindingClick(b, true, db.key, "BiSToolsRivalTarget") end
  return true
end

-- ---------------------------------------------------------------- "add rival" on a player's right-click menu
-- Arn, 12 Oct, right-clicking an enemy's portrait: "when i right click maybe we can add add rival here".
-- The game's own way in: Menu.ModifyMenu("MENU_UNIT_" .. kind, fn) adds a line - nothing of the game's
-- is replaced or hooked. Read off Olympus 1.2.3 (MIT), which hands back the player's `name` and
-- `surname` apart (Forever's), and which learned to stay OUT of the guild roster menus: a line there
-- left the game's own promote / kick refused from tainted code. So those are never touched here.
RC.MENUS = { "ENEMY_PLAYER", "PLAYER", "FRIEND", "PARTY", "RAID_PLAYER", "CHAT_ROSTER",
  -- Arn, 13 Oct: "i cant see the add rival when i right click them". A unit frame that opens its
  -- menu through the secure "togglemenu" action (EllesmereUI's do, to dodge 12.x's togglemenu gate)
  -- can file a player's menu as TARGET or FOCUS - so those carry the line too, for players only
  "TARGET", "FOCUS" }

--- CAN A LINE GO INTO THE GAME'S RIGHT-CLICK MENU HERE? Not inside an instance. Arn's BugGrabber
--- in a battleground, 13 Oct: "FrameUtil.lua:223: attempt to perform arithmetic on local 'frameLeft'
--- (a secret number value, while execution tainted by 'BiSTools')" - inside an instance the
--- menu's own frame rects are secret, and once an addon has put a line in the menu, Blizzard's
--- layout runs tainted and may not do sums on them: the menu breaks (no Report Player, no Copy
--- Name). Outside, the rects are plain and the line is fine. So inside: no line, ever - and
--- /bist recap rival adds your target instead, with nothing of the game's touched.
function RC.MenuSafe()
  if not IsInInstance then return true end
  local ok, inside = pcall(IsInInstance)
  if not ok or hidden(inside) then return false end
  return inside ~= true
end

--- A guild roster menu is never touched (Olympus: a line there left promote/kick refused).
function RC.MenuAllowed(tag)
  if type(tag) ~= "string" then return false end
  local up = tag:upper()
  return not (up:find("GUILD", 1, true) or up:find("COMMUNIT", 1, true))
end

--- The full name a menu is about ("Dai Joubu"), or nil when it is nobody, hidden, or you.
function RC.MenuName(ctx)
  if type(ctx) ~= "table" then return nil end
  local first, sur = field(ctx, "name"), field(ctx, "surname")
  -- IN A BATTLEGROUND THE MENU CARRIES NO NAME (Arn, 13 Oct, /bist recap why on Grape Sprite's
  -- PLAYER menu: "the menu gave no name") - while the game still names the unit itself. So the
  -- menu's unit answers: GetUnitName first (it has Forever's surname; UnitName can leave it off)
  if type(first) ~= "string" or first == "" then
    local unit = field(ctx, "unit")
    if type(unit) ~= "string" then return nil end
    for _, fn in ipairs({ function() return GetUnitName and GetUnitName(unit, false) end,
                          function() return UnitName(unit) end }) do
      local ok, n = pcall(fn)
      if ok and type(n) == "string" and not hidden(n) and n ~= "" and n ~= (UNKNOWNOBJECT or "Unknown") then
        first, sur = n, nil
        break
      end
    end
    if type(first) ~= "string" or first == "" then return nil end
  end
  local me = UnitName and UnitName("player")
  if not hidden(me) and me == first then return nil end
  if type(sur) == "string" and sur ~= "" then return first .. " " .. sur end
  return first
end

--- The lines for one menu: add, or remove, this player as a rival.
function RC.MenuLines(db, root, ctx)
  -- WHY the line was or was not added, kept for /bist recap why (Arn in a battleground, 13 Oct: the
  -- menu was PLAYER and joined, so the question left is what the line's own checks decided)
  local function say(why) RC.menuDecision = why end
  if not R:Enabled("recap") then return say("the recap tool is off") end
  if not RC.MenuSafe() then
    return say("inside an instance (a battleground): the game's menu breaks with an addon line there - /bist recap rival adds your target")
  end
  if not (root and root.CreateButton) then return say("the menu would not take a line") end
  -- a menu about a UNIT must be about a player (TARGET and FOCUS also open on mobs); a menu with no
  -- unit (a name in chat) is a player by where it came from
  local unit = field(ctx, "unit")
  if type(unit) == "string" then
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not okP then return say("the game refused 'is this a player?' for " .. unit) end
    if hidden(isPlayer) then return say("the game HID whether " .. unit .. " is a player") end
    if isPlayer ~= true then return say(unit .. " is not a player") end
  end
  local name = RC.MenuName(ctx)
  if not name then
    local raw = field(ctx, "name")
    return say(raw == nil and "the menu gave no name (hidden by the game, or none)" or "it is your own menu")
  end
  local r, key = RC.Find(db, name)
  -- a friend is never ADDED (Arn, 14 Oct: "there should be a check if its friendly target not a
  -- rival but a pal - enemy hostile player rival"); one already on the list can still be taken off
  if not r and type(unit) == "string" and RC.Friendly(unit) then
    -- a friend gets the PAL line instead (Arn, 14 Oct: "right click on and add a pal")
    local p, pkey = RC.PalFor(db, unit)
    say((p and "remove pal" or "add pal") .. " for " .. name .. " - friendly, so a pal, not a rival")
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(p and "BiS: remove pal" or "BiS: add pal", function()
      if p then
        RC.Pals(db)[pkey] = nil
        RC.ClearPals() RC.SpotPals(db)
        NS.Print("%s is no longer a pal", pkey)
      else
        local function ask(fn, ...)
          if type(fn) ~= "function" then return nil end
          local ok, v = pcall(fn, ...)
          if ok and not hidden(v) then return v end
        end
        RC.Pals(db)[name] = { guid = ask(UnitGUID, unit), added = time and time() or 0 }
        RC.SpotPals(db)
        NS.Print("%s added to your pals - a little green heart over them, out of combat", T.text("good", name))
      end
    end)
    return
  end
  say("added for " .. name)
  if root.CreateDivider then root:CreateDivider() end
  root:CreateButton(r and "BiS: remove rival" or "BiS: add rival", function()
    if r then
      RC.Rivals(db)[key] = nil
      RC.UnmarkRival(key)
      NS.Print("%s is no longer a rival", key)
      RC.PaintRivals()
      RC.ApplyButton(db)
      return
    end
    local unit = field(ctx, "unit")
    local class, guid
    if type(unit) == "string" then
      local okC, _, c = pcall(UnitClass, unit)
      if okC and type(c) == "string" and not hidden(c) then class = c end
      local okG, g = pcall(UnitGUID, unit)
      if okG and type(g) == "string" and not hidden(g) then guid = g end
    end
    RC.ToggleRival(db, { player = true, title = name, class = class, key = guid })
  end)
  -- and the guild's list, for a player in a guild with the guild rivals on
  if IsInGuild and IsInGuild() and db.guildShow ~= false then
    local g, gkey = RC.FindGuild(db, name)
    root:CreateButton(g and "BiS: remove guild rival" or "BiS: add guild rival", function()
      if g then RC.GuildDel(db, gkey) return end
      local unit, class = field(ctx, "unit"), nil
      if type(unit) == "string" then
        local okC, _, c = pcall(UnitClass, unit)
        if okC and type(c) == "string" and not hidden(c) then class = c end
      end
      RC.GuildAdd(db, name, class, nil, false)
    end)
  end
end

RC.tags = {}                       -- menu kinds the line is in

function RC.HookTag(db, kind)
  if RC.tags[kind] or not RC.MenuAllowed(kind) then return end
  RC.tags[kind] = true
  pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) RC.MenuLines(db, root, ctx) end)
end

function RC.HookMenus(db)
  if RC.menusHooked then return true end
  if not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  for _, kind in ipairs(RC.MENUS) do RC.HookTag(db, kind) end
  -- AND EVERY MENU THE GAME OPENS: its kind is noted for /bist recap why, and a kind not seen
  -- before gets the line from the next right-click on (the hook runs after the menu is built, so
  -- the first open of a new kind is a miss). Guild roster menus never.
  if type(UnitPopup_OpenMenu) == "function" and hooksecurefunc then
    pcall(hooksecurefunc, "UnitPopup_OpenMenu", function(which)
      if type(which) ~= "string" or hidden(which) then return end
      RC.lastMenu = which
      RC.HookTag(db, which)
    end)
  end
  RC.menusHooked = true
  return true
end

--- The rival a name belongs to, or nil. MEASURED 12 Oct (Arn's /bist recap why, Hunting Moms on his
--- target): the death recap names a player WITH Forever's surname - "Hunting Moms" - and UnitName
--- gives the character name alone - "Hunting". The character name is the unique one; the surname is
--- Forever's addition. So a rival is found by its whole name or by its first word.
function RC.Find(db, name)
  if type(name) ~= "string" then return nil end
  local list = RC.Rivals(db)
  if list[name] then return list[name], name end
  -- both ways round: "Hunting" finds the rival "Hunting Moms", and "Grape Sprite" (the recap's
  -- name for a killer) finds a rival added as plain "Grape" (from a battleground menu, 13 Oct)
  local firstOf = name:match("^(%S+)")
  for key, r in pairs(list) do
    if key:match("^(%S+)") == name or key == firstOf then return r, key end
  end
  return nil
end

--- A player you cannot attack: a pal, never a rival. True only on the game's plain "no" - a hidden
--- or refused answer is not taken as friendly (nothing is blocked on a guess).
function RC.Friendly(unit)
  if type(UnitCanAttack) ~= "function" then return false end
  local ok, can = pcall(UnitCanAttack, "player", unit)
  if not ok or hidden(can) then return false end
  return can ~= true
end

--- The rival a NAMEPLATE belongs to, or nil (Arn, 14 Oct: "terry daviss is marked as rival because
--- there is a terry lin alliance"). RC.Find's first-word road is for a plate that gives ONE word: when
--- the plate carries the whole name ("Terry Daviss", GetUnitName), only that whole name counts - or a
--- rival kept as one word ("Grape") that it starts with. And a rival whose GUID we hold is never a
--- plate whose readable GUID is another's, whatever the names say.
function RC.FindPlate(db, unit, name)
  local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and not hidden(v) then return v end
  end
  local whole = ask(GetUnitName, unit, false)
  local r, key
  if type(whole) == "string" and whole:find(" ", 1, true) then
    local list = RC.Rivals(db)
    if list[whole] then
      r, key = list[whole], whole
    else
      local first = whole:match("^(%S+)")
      if list[first] then r, key = list[first], first end
    end
  else
    r, key = RC.Find(db, name)
  end
  if r and type(r.guid) == "string" then
    local guid = ask(UnitGUID, unit)
    if type(guid) == "string" and guid ~= r.guid then return nil end
  end
  return r, key
end

--- A guild rival in sight: the amber crosshair, and the guild told - once a minute per rival.
local function spotGuild(db, unit, e, full)
  RC.MarkPlate(unit, full, "guild")
  local now = GetTime and GetTime() or 0
  e.seen = time and time() or 0
  e.where = place()
  e.seenBy = nil
  if not e.sentAt or now - e.sentAt >= RC.SEEN_GAP then
    e.sentAt = now
    send("SEEN", full, e.where or "")
  end
  RC.PaintRivals()
  return looked(unit, full, "a guild rival - amber, the guild told")
end

--- Take every crosshair of one kind down (the farm moved on to another mob, or stopped).
function RC.ClearKind(kind)
  for unit, f in pairs(RC.marks) do if f.kind == kind then RC.UnmarkUnit(unit) end end
end

--- Is this a mob RestedXP's guide wants right now? Only while the farm tool shows the guide's mobs.
local function guideWants(name)
  local F = NS.Farm
  local G, fdb = F and F.Guide, F and F.db
  if not (G and G.mobs and #G.mobs > 0 and fdb and fdb.guide ~= false and fdb.cross ~= false and R:Enabled("farm")) then
    return false
  end
  if name == nil then return true end           -- asked only "is there a list at all"
  for _, n in ipairs(G.mobs) do if n == name then return true end end
  return false
end

--- The farm tool's mob, when it is farming one and wants the crosshair - or nil.
local function farmMob()
  local F = NS.Farm
  local fdb = F and F.db
  if not (fdb and fdb.active and fdb.cross ~= false and R:Enabled("farm")) then return nil end
  return fdb.active
end

function RC.Spot(db, unit)
  local gold = RC.GoldCount(db) > 0
  local farm = type(unit) == "string" and unit:find("^nameplate") ~= nil and farmMob() or nil
  local guild = db.guildShow ~= false and next(RC.GuildRivals(db)) ~= nil
  local mates = db.mates ~= false and RC.solo ~= false and type(unit) == "string" and unit:find("^nameplate") ~= nil
  -- nothing to look for: no client call at all (a city of nameplates costs nothing)
  local guide = type(unit) == "string" and unit:find("^nameplate") ~= nil and guideWants(nil)
  if not (gold or guild or mates or farm or guide) then return looked(unit, nil, "nobody is gold") end
  local name = NS.Farm.Name(unit)
  if not name then return looked(unit, nil, "the game did not give a name (hidden, or nobody there)") end
  -- the farmed mob: a clean copy (alive, untapped, attackable - the farm tool's own test) goes green
  if farm and name == farm then
    if NS.Farm.Clean(unit) then RC.MarkPlate(unit, name, "farm") end
    return looked(unit, name, "the mob you farm")
  end
  if guide and guideWants(name) then
    if NS.Farm.Clean(unit) then RC.MarkPlate(unit, name, "guide") end
    return looked(unit, name, "a mob the RestedXP guide wants")
  end
  local r, full = RC.FindPlate(db, unit, name)
  if r and RC.Friendly(unit) then r = nil end     -- a pal who shares a rival's name: never their crosshair
  if not (r and r.active) then
    local e, gfull = nil, nil
    if guild then e, gfull = RC.FindGuild(db, name) end
    if e then return spotGuild(db, unit, e, gfull) end
    if mates and isMate(unit) then
      RC.MarkMate(unit)
      return looked(unit, name, "a guildmate - the small +")
    end
    if not r then return looked(unit, name, "not a rival") end
    return looked(unit, full, "a silver rival")
  end
  name = full                                    -- called out by the name the recap knows them by
  RC.MarkPlate(unit, full)                       -- gold: the crosshair, whether or not it is called out now
  local now = GetTime and GetTime() or 0
  r.seen = time and time() or 0
  r.where = place()
  if r.alertAt and now - r.alertAt < RC.ALERT_GAP then
    looked(unit, name, "called out less than a minute ago")
    return name
  end
  looked(unit, name, "called out")
  r.alertAt = now
  local cc = r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
  if RaidNotice_AddMessage and RaidWarningFrame then
    RaidNotice_AddMessage(RaidWarningFrame, "Rival nearby: " .. name,
      cc and { r = cc.r, g = cc.g, b = cc.b } or (ChatTypeInfo and ChatTypeInfo.RAID_WARNING))
  end
  NS.Print("%s nearby%s", T.text("warn", name), (r.where and r.where ~= "") and (" - " .. r.where) or "")
  if db.sound ~= false and PlaySound then PlaySound(NS.Farm.PING, "Master") end
  RC.PaintRivals()
  return name
end

local function card(parent, w)
  local F = K()
  -- A BUTTON: a player on it can be clicked into your rivals. A mob card ignores the click.
  local c = CreateFrame("Button", nil, parent)
  c:SetSize(w, RC.CARD_H)
  c:RegisterForClicks("LeftButtonUp")
  c.bg = F.tex(c, "BACKGROUND", "field", 0.95)
  c.edge = F.border(c, "hair", 1)
  c.rival = F.fs(c, "", 8, "gold")     c.rival:SetPoint("TOPRIGHT", -5, -4)
  c:SetScript("OnClick", function(self)
    if not self.a or not RC.db then return end
    RC.ToggleRival(RC.db, self.a)
    if RC.last then RC.Paint(RC.last) end
  end)
  c:SetScript("OnEnter", function(self)
    if not (self.a and self.a.player) then return end
    self.edge:set("accent", 1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      local isRival = RC.db and RC.Rivals(RC.db)[self.a.title]
      GameTooltip:AddLine(isRival and "Click: no longer a rival" or "Click: add to your rivals")
      GameTooltip:AddLine("The PvP tracker watches for your rivals.", 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  c:SetScript("OnLeave", function(self)
    self.edge:set("hair", 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  c.role = F.fs(c, "", 8, "muted")     c.role:SetPoint("TOPLEFT", 5, -4)
  c.name = F.fs(c, "", 10, "ink")      c.name:SetPoint("TOPLEFT", 5, -14)
  c.nick = F.fs(c, "", 8, "muted")     c.nick:SetPoint("TOPLEFT", 5, -26)
  c.barBg = c:CreateTexture(nil, "ARTWORK")
  c.barBg:SetPoint("TOPLEFT", 5, -38) c.barBg:SetSize(w - 10, 3)
  do local r, g, b = F.color("hair") c.barBg:SetColorTexture(r, g, b, 1) end
  c.bar = c:CreateTexture(nil, "OVERLAY")
  c.bar:SetPoint("TOPLEFT", c.barBg, "TOPLEFT") c.bar:SetHeight(3)
  do local r, g, b = F.color("warn") c.bar:SetColorTexture(r, g, b, 1) end
  c.dmg = F.fs(c, "", 9, "ink2")       c.dmg:SetPoint("TOPLEFT", 5, -44)
  c.what = F.fs(c, "", 8, "muted")     c.what:SetPoint("TOPLEFT", 5, -55)
  c.w = w
  return c
end

local function paintCard(c, a, role, s, isKiller)
  c.a = a
  if not a then c:Hide() return end
  c:Show()
  local w = c.w - 10
  c.role:SetText(role)
  do local F = K() local r, g, b = F.color(isKiller and "warn" or "muted") c.role:SetTextColor(r, g, b, 1) end
  c.rival:SetText((a.player and RC.db and RC.Rivals(RC.db)[a.title]) and "rival" or "")
  fitText(c.name, a.title, w - (c.rival:GetText() ~= "" and 26 or 0))
  -- a player's name in their class colour; a mob's in ink
  do
    local cc = a.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[a.class]
    if cc then c.name:SetTextColor(cc.r, cc.g, cc.b, 1)
    else local F = K() local r, g, b = F.color("ink") c.name:SetTextColor(r, g, b, 1) end
  end
  fitText(c.nick, table.concat(a.nicks, ", "), w)
  local share = (a.whole and s.total > 0) and (a.total / s.total) or 0
  c.bar:SetWidth(math.max(1, w * share))
  c.dmg:SetText(a.whole and (tostring(a.total) .. pct(a.total, s.total)) or "?")
  local line
  if isKiller and s.blow then
    local b = s.blow
    -- short: a card is a third of the window, and the hits list below already says "melee"
    line = "killing blow " .. (b.amount and tostring(b.amount) or "?")
    if b.overkill and b.overkill > 0 then line = line .. (" +%d"):format(b.overkill) end
  elseif a.top and a.topAmt then
    line = ("%s %d"):format(a.top, a.topAmt)              -- "Arcane Shot 288": how they did it
  else
    line = ("%d hits"):format(a.hits) .. (a.crits > 0 and (" · %d crit%s"):format(a.crits, a.crits > 1 and "s" or "") or "")
  end
  fitText(c.what, line, w)
end

function RC.Build(db)
  RC.db = db                            -- the cards' clicks write rivals here
  if RC.win then return RC.win end
  local F = K()
  local f = CreateFrame("Frame", "BiSToolsRecap", UIParent)
  RC.win = f
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  F.tex(f, "BACKGROUND", "frame", 0.96)
  F.border(f, "edge", 0.6)

  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(RC.HEADER)
  F.tex(head, "BACKGROUND", "header", 1)
  f.title = F.fs(head, "", 8, "ink")
  f.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  f.con = BiSTheme.Console(f.title, { width = RC.W - 20 - 8 })
  f.con:Set("name", "death recap", "accent")
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + (dt or 0)
    if acc >= 0.1 then acc = 0 if f.con then f.con:Paint() end end
  end)
  f.closeBtn = F.HeaderButton(head, -3, "x", "Close", "/bist recap opens your last death again.",
    function() RC.Toggle(db, false) end, "warn")
  -- SMALL OR BIG (Arn, 12 Oct: "the recap window is minimized right now if i click a button it
  -- maximize and shows more info all rivals"): the drawer underneath holds every rival
  f.moreBtn = F.HeaderButton(head, -17, "+", "Rivals", "Every rival: gold you are hunting, silver you are not.",
    function() RC.SetExpanded(db, not db.expanded) end)

  local P = RC.PAD
  local cw = math.floor((RC.W - P * 4) / 3)
  f.left, f.mid, f.right = card(f, cw), card(f, cw), card(f, cw)
  f.left:SetPoint("TOPLEFT", f, "TOPLEFT", P, -(RC.HEADER + P))
  f.mid:SetPoint("TOPLEFT", f.left, "TOPRIGHT", P, 0)
  f.right:SetPoint("TOPLEFT", f.mid, "TOPRIGHT", P, 0)

  -- your health before each hit, oldest to newest: a column each, gold where it was a crit
  local stripTop = RC.HEADER + P + RC.CARD_H + P
  f.cols = {}
  local colW = math.floor((RC.W - P * 2) / 10)
  for i = 1, 10 do
    local col = f:CreateTexture(nil, "ARTWORK")
    col:SetPoint("BOTTOMLEFT", f, "TOPLEFT", P + (i - 1) * colW, -(stripTop + RC.STRIP_H))
    col:SetSize(colW - 2, 1)
    f.cols[i] = col
  end
  f.stripLeft = F.fs(f, "", 8, "muted")
  f.stripLeft:SetPoint("TOPLEFT", f, "TOPLEFT", P, -(stripTop + RC.STRIP_H + 2))
  f.stripRight = F.fs(f, "dead", 8, "warn")
  f.stripRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P, -(stripTop + RC.STRIP_H + 2))

  -- the hits, newest first
  local listTop = stripTop + RC.STRIP_H + 14
  f.caption = F.fs(f, "", 8, "muted")
  f.caption:SetPoint("TOPLEFT", f, "TOPLEFT", P, -listTop)
  f.rows = {}
  for i = 1, RC.ROWS do
    local y = -(listTop + 11 + (i - 1) * RC.ROW_H)
    local r = {}
    r.ago = F.fs(f, "", 9, "muted")   r.ago:SetPoint("TOPLEFT", f, "TOPLEFT", P, y)
    r.who = F.fs(f, "", 9, "ink")     r.who:SetPoint("TOPLEFT", f, "TOPLEFT", P + 30, y)
    r.what = F.fs(f, "", 9, "muted")  r.what:SetPoint("TOPLEFT", f, "TOPLEFT", P + 172, y)
    r.amt = F.fs(f, "", 9, "ink2")    r.amt:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P, y)
    f.rows[i] = r
  end
  local footTop = listTop + 11 + RC.ROWS * RC.ROW_H + 4
  f.foot = F.fs(f, "", 9, "ink2")
  f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", P, -footTop)
  -- "STOP SHOWING THIS" (Arn, 12 Oct): on a line of its own, right - the total line above can be long.
  -- It turns "open when you die" off and closes; with that already off it reads "show when I die".
  local stop = CreateFrame("Button", nil, f)
  stop:SetSize(110, 12)
  stop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -P, -(footTop + 13))
  stop.label = F.fs(stop, "", 8, "muted")
  stop.label:SetPoint("RIGHT", stop, "RIGHT", 0, 0)
  stop:SetScript("OnClick", function()
    db.popup = db.popup == false
    if db.popup then
      NS.Print("the recap opens again when you die")
    else
      NS.Print("the recap will not open when you die - %s shows your last death, or turn \"open when you die\" back on in the options",
        NS.T.text("accent", "/bist recap"))
      RC.Toggle(db, false)
    end
    RC.PaintStop(db)
  end)
  stop:SetScript("OnEnter", function(self) local r, g, b = F.color("ink") self.label:SetTextColor(r, g, b, 1) end)
  stop:SetScript("OnLeave", function(self) local r, g, b = F.color("muted") self.label:SetTextColor(r, g, b, 1) end)
  f.stop = stop
  f:SetSize(RC.W, footTop + 28)

  -- THE DRAWER: every rival, gold first. A row is a button: click = gold/silver, shift-click = forget.
  local d = CreateFrame("Frame", nil, f)
  f.drawer = d
  d:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
  d:SetWidth(RC.W)
  F.tex(d, "BACKGROUND", "frame", 0.96)
  F.border(d, "edge", 0.6)
  d.caption = F.fs(d, "rivals - gold: hunting, silver: not. click to switch", 8, "muted")
  d.caption:SetPoint("TOPLEFT", d, "TOPLEFT", P, -5)
  d.rows = {}
  for i = 1, RC.RIVAL_ROWS do
    local b = CreateFrame("Button", nil, d)
    b:SetSize(RC.W - P * 2, RC.ROW_H + 2)
    b:SetPoint("TOPLEFT", d, "TOPLEFT", P, -(16 + (i - 1) * (RC.ROW_H + 2)))
    b:RegisterForClicks("LeftButtonUp")
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.mark:SetSize(7, 7)
    b.name = F.fs(b, "", 9, "ink")      b.name:SetPoint("LEFT", b, "LEFT", 12, 0)
    b.info = F.fs(b, "", 8, "muted")    b.info:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    b:SetScript("OnClick", function(self)
      if not self.rival then return end
      -- a GUILD row: click = make them yours (gold), shift-click = off the guild's list
      if self.guild then
        local e = RC.GuildRivals(db)[self.rival]
        if IsShiftKeyDown and IsShiftKeyDown() then RC.GuildDel(db, self.rival)
        elseif e then RC.ToggleRival(db, { player = true, title = self.rival, class = e.class }) end
        return
      end
      if IsShiftKeyDown and IsShiftKeyDown() then
        RC.Rivals(db)[self.rival] = nil
        RC.UnmarkRival(self.rival)
        RC.ApplyButton(db)
        NS.Print("%s is no longer a rival", self.rival)
        RC.PaintRivals()
      else
        RC.SetActive(db, self.rival, not RC.Rivals(db)[self.rival].active)
      end
    end)
    b:SetScript("OnEnter", function(self)
      if not (self.rival and GameTooltip) then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.rival)
      GameTooltip:AddLine(self.guild and "A guild rival. Click: make them yours. Shift-click: off the guild's list."
        or "Click: gold (hunting) or silver. Shift-click: forget.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    d.rows[i] = b
  end
  d.more = F.fs(d, "", 8, "muted")
  d:Hide()

  local pos = db.pos
  f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
  f:Hide()
  return f
end

function RC.Paint(s)
  local f = RC.win
  if not f then return end
  local F = K()
  if not s then                                  -- no death this session: an empty top, the drawer below
    f.mid:Hide() f.left:Hide() f.right:Hide()
    for _, col in ipairs(f.cols) do col:Hide() end
    f.stripLeft:SetText("") f.stripRight:SetText("")
    f.caption:SetText("nothing has killed you this session")
    for _, r in ipairs(f.rows) do r.ago:SetText("") r.who:SetText("") r.what:SetText("") r.amt:SetText("") end
    f.foot:SetText("")
    return
  end
  f.stripRight:SetText("dead")
  paintCard(f.mid, s.killer, "killer", s, true)
  paintCard(f.left, s.assists[1], "assist", s, false)
  paintCard(f.right, s.assists[2], "assist", s, false)

  -- the strip: oldest hit on the left
  local hits = s.hits
  local maxHP = s.maxHP or s.startHP or 1
  for i = 1, 10 do
    local col = f.cols[i]
    local h = hits[#hits - i + 1]
    if h and h.hp and maxHP > 0 then
      col:SetHeight(math.max(1, RC.STRIP_H * math.min(1, h.hp / maxHP)))
      local r, g, b = F.color(h.crit and "gold" or "good")
      col:SetColorTexture(r, g, b, 1)
      col:Show()
    else
      col:Hide()
    end
  end
  f.stripLeft:SetText(s.startHP and ("%d of %d health when these began"):format(s.startHP, s.maxHP or s.startHP)
    or "health: the game did not say")

  f.caption:SetText(("last %d hits, newest first"):format(#hits))
  local newestT = hits[1] and hits[1].t
  for i = 1, RC.ROWS do
    local r, h = f.rows[i], hits[i]
    if h then
      local ago = (newestT and h.t) and (newestT - h.t) or nil
      r.ago:SetText(ago and ("-%.1fs"):format(ago) or "")
      local a = h.name or "?"
      fitText(r.who, a, 138)
      local tag = h.spell
      if h.crit then tag = tag .. " crit" end
      if h.blocked and h.blocked > 0 then tag = tag .. (" %d blk"):format(h.blocked) end
      fitText(r.what, tag, 100)
      local amt = h.amount and tostring(h.amount) or "?"
      if h.overkill and h.overkill > 0 then amt = amt .. (" +%d"):format(h.overkill) end
      r.amt:SetText(amt)
      local c = (i == 1) and "warn" or (h.crit and "gold" or "ink2")
      local cr, cg, cb = F.color(c) r.amt:SetTextColor(cr, cg, cb, 1)
    else
      r.ago:SetText("") r.who:SetText("") r.what:SetText("") r.amt:SetText("")
    end
  end
  if s.whole and s.seconds then
    -- MORE DAMAGE THAN HEALTH is not a bug: the record keeps the hits, not your heals (Arn, killed
    -- by three hunters from 361 health while 1047 landed). Said, so it does not read as one.
    -- the overkill landed on nobody: 306 with 14 over, from 292, is not a heal (Ragefire, 12 Oct)
    local over = (s.blow and s.blow.overkill and s.blow.overkill > 0) and s.blow.overkill or 0
    local healed = s.startHP and (s.total - over) > s.startHP
    f.foot:SetText(("%d damage in %.1f seconds%s"):format(s.total, s.seconds,
      healed and " - you healed through some of it" or ""))
  elseif s.seconds then
    f.foot:SetText(("damage in %.1f seconds (some amounts hidden)"):format(s.seconds))
  else
    f.foot:SetText("")
  end
end

--- /bist recap why: the tracker's own account of itself, for "it did not call them out".
function RC.Why(db)
  local list, gold = RC.Rivals(db), {}
  local n = 0
  for name, r in pairs(list) do
    n = n + 1
    if r.active then gold[#gold + 1] = name end
  end
  table.sort(gold)
  NS.Print("tracker: %d rival%s, gold: %s", n, n == 1 and "" or "s",
    #gold > 0 and T.text("gold", table.concat(gold, ", ")) or T.text("warn", "nobody"))
  DEFAULT_CHAT_FRAME:AddMessage("  last look: " .. T.text("muted", ("%s - %s - %s"):format(
    tostring(RC.lookUnit or "none yet"), tostring(RC.lookName or "no name"), tostring(RC.lookWhy or "-"))))
  -- the right-click menu: which kind the game opened last, and whether "add rival" is in it
  local menu = RC.lastMenu
  DEFAULT_CHAT_FRAME:AddMessage("  last right-click menu: " .. (menu and T.text("ink", menu) or T.text("muted", "none seen yet"))
    .. (menu and (RC.tags[menu] and T.text("good", " - has the rival line") or
        T.text("warn", RC.MenuAllowed(menu) and " - not yet (right-click again)" or " - a guild menu: never")) or ""))
  DEFAULT_CHAT_FRAME:AddMessage("  the rival line, last time: " .. T.text("ink", RC.menuDecision or "no menu with it opened yet"))
  -- the target, read now, every way it can go wrong
  local ok, raw = pcall(UnitName, "target")
  local said
  if not ok then said = "refused"
  elseif raw == nil then said = "no target"
  elseif hidden(raw) then said = "HIDDEN by the game"
  else said = '"' .. tostring(raw) .. '"' end
  DEFAULT_CHAT_FRAME:AddMessage("  your target's name, as the game gives it now: " .. T.text("ink", said))
  if ok and type(raw) == "string" and not hidden(raw) then
    local r, full = RC.Find(db, raw)
    if r then
      DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("good", ("that is your rival %s"):format(full)
        .. (r.active and " (gold)" or " (silver)")))
    else
      -- the recap may know them by a longer name than the nameplate does (a surname)
      for name in pairs(list) do
        if name:sub(1, #raw) == raw or raw:sub(1, #name) == name then
          DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("warn", ("not the same name as your rival \"%s\""):format(name)))
        end
      end
    end
  end
  local cvar = C_CVar and C_CVar.GetCVar or GetCVar
  if cvar then
    local okC, v = pcall(cvar, "nameplateShowEnemies")
    DEFAULT_CHAT_FRAME:AddMessage("  enemy nameplates: " .. T.text("muted",
      (okC and not hidden(v)) and ((v == "1" or v == 1) and "on" or "off") or "?"))
  end
end

-- "3m ago" / "2h ago" / "4d ago"
local function ago(stamp)
  local now = time and time() or 0
  if type(stamp) ~= "number" or stamp <= 0 then return nil end
  local s = math.max(0, now - stamp)
  if s < 3600 then return ("%dm ago"):format(math.floor(s / 60)) end
  if s < 86400 then return ("%dh ago"):format(math.floor(s / 3600)) end
  return ("%dd ago"):format(math.floor(s / 86400))
end

--- The drawer: gold first, then the most recently seen. Silver rows are dimmed.
function RC.PaintRivals()
  local f, db = RC.win, RC.db
  if not (f and f.drawer and db) then return end
  local d, F = f.drawer, K()
  -- yours gold, then the guild's (amber), then yours silver; the most recently seen first in each
  local list = {}
  for name, r in pairs(RC.Rivals(db)) do list[#list + 1] = { name = name, r = r, rank = r.active and 1 or 3 } end
  if db.guildShow ~= false then
    for name, e in pairs(RC.GuildRivals(db)) do
      if not RC.Rivals(db)[name] then list[#list + 1] = { name = name, r = e, rank = 2, guild = true } end
    end
  end
  table.sort(list, function(x, y)
    if x.rank ~= y.rank then return x.rank < y.rank end
    return (x.r.seen or x.r.added or 0) > (y.r.seen or y.r.added or 0)
  end)
  for i, b in ipairs(d.rows) do
    local e = list[i]
    if e then
      b.rival, b.guild = e.name, e.guild
      local gold = e.r.active or e.guild
      local mr, mg, mb
      if e.guild then mr, mg, mb = unpack(RC.MARK_COLOUR.guild) else mr, mg, mb = F.color(gold and "gold" or "dim") end
      b.mark:SetColorTexture(mr, mg, mb, 1)
      b.name:SetText(e.name)
      local cc = e.r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.r.class]
      if cc then b.name:SetTextColor(cc.r, cc.g, cc.b, gold and 1 or 0.55)
      else local r, g, bl = F.color("ink") b.name:SetTextColor(r, g, bl, gold and 1 or 0.55) end
      local bits = {}
      if e.guild then bits[#bits + 1] = "guild" end
      if (e.r.kills or 0) > 0 then bits[#bits + 1] = ("killed you %d"):format(e.r.kills) end
      local seen = ago(e.r.seen)
      if seen then
        bits[#bits + 1] = "seen " .. seen .. ((e.r.where and e.r.where ~= "") and (", " .. e.r.where) or "")
          .. ((e.guild and e.r.seenBy) and (" (" .. e.r.seenBy .. ")") or "")
      elseif e.guild and e.r.by then
        bits[#bits + 1] = "from " .. e.r.by
      end
      fitText(b.info, table.concat(bits, " · "), RC.W - 160)
      b:Show()
    else
      b.rival = nil
      b:Hide()
    end
  end
  local shown = math.min(#list, #d.rows)
  if #list == 0 then
    d.more:SetText("no rivals yet - click a player on a death recap")
    d.more:SetPoint("TOPLEFT", d, "TOPLEFT", RC.PAD, -18)
    d.more:Show()
  elseif #list > shown then
    d.more:SetText(("%d more - /bist recap rivals lists them all"):format(#list - shown))
    d.more:SetPoint("TOPLEFT", d, "TOPLEFT", RC.PAD, -(18 + shown * (RC.ROW_H + 2)))
    d.more:Show()
  else
    d.more:SetText("")
    d.more:Hide()
  end
  local rows = math.max(shown, 1) + ((#list > shown or #list == 0) and 1 or 0)
  d:SetHeight(20 + rows * (RC.ROW_H + 2))
end

--- Small or big: the drawer of rivals under the recap.
function RC.SetExpanded(db, on)
  db.expanded = on and true or false
  local f = RC.win
  if not f then return db.expanded end
  if db.expanded then RC.PaintRivals() f.drawer:Show() else f.drawer:Hide() end
  if f.moreBtn and f.moreBtn.label then f.moreBtn.label:SetText(db.expanded and "-" or "+") end
  return db.expanded
end

function RC.PaintStop(db)
  local s = RC.win and RC.win.stop
  if s then s.label:SetText(db.popup == false and "show when I die" or "stop showing this") end
end

function RC.Toggle(db, want)
  RC.Build(db)
  if want == nil then want = not RC.win:IsShown() end
  if want then
    if not RC.last then
      local events = RC.Fetch()
      if events and #events > 0 then RC.last = RC.Summary(RC.Hits(events), RC.MaxHP()) end
    end
    -- no death yet, but rivals: the window opens for the drawer alone
    if not RC.last and next(RC.Rivals(db)) == nil then
      NS.Print("nothing has killed you yet this session")
      RC.win:Hide()
      return false
    end
    RC.Paint(RC.last)
    RC.PaintStop(db)
    RC.SetExpanded(db, db.expanded or not RC.last)
    RC.win:Show()
  else
    RC.win:Hide()
  end
  return want
end

function RC.MaxHP()
  local D = C_DeathRecap
  if not (D and D.GetRecapMaxHealth) then return nil end
  local ok, hp = pcall(D.GetRecapMaxHealth)
  if not ok or hidden(hp) then return nil end
  return num(hp)
end

-- ---------------------------------------------------------------- events
-- DIED: read the record, open the window (unless switched off), and keep a measuring snapshot for
-- /bist recap raw - a player killer on a PvP server is the case nobody has measured yet.
-- BACK ON YOUR FEET (unghosted at your corpse, or resurrected where you fell): it closes.
function RC.OnEvent(_, event, unit)
  if not R:Enabled("recap") then return end
  local db = R:DBFor(R:Get("recap"))
  -- THE TRACKER: a nameplate appearing, a new target, the mouse on someone
  if event == "NAME_PLATE_UNIT_REMOVED" then
    if RC.marks[unit] then RC.UnmarkUnit(unit) end
    if RC.mates[unit] then RC.UnmarkMate(unit) end
    RC.plates[unit] = nil
    if RC.hearts[unit] then RC.UnmarkPal(unit) end
    return
  elseif event == "PLAYER_REGEN_DISABLED" then
    RC.ClearPals()                                   -- the hearts are for out of combat
    return
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
    -- the guildmate + is for passing each other alone: a group, a battleground or an arena ends it
    RC.solo = RC.Solo()
    if not RC.solo then RC.ClearMates() end
    if event == "PLAYER_ENTERING_WORLD" then RC.DropMatchRivals(db) end
    return
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    if type(unit) == "string" and not hidden(unit) then
      RC.plates[unit] = true
      RC.SpotPal(db, unit)
      RC.Spot(db, unit)
    end
    return
  elseif event == "PLAYER_TARGET_CHANGED" then
    RC.PaintAdd()
    RC.Spot(db, "target") return
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    RC.Spot(db, "mouseover") return
  end
  if event == "PLAYER_REGEN_ENABLED" then RC.SpotPals(db) end     -- the fight over: the hearts back
  if event == "PLAYER_DEAD" then
    RC.atDeath, RC.afterFight = RC.Read("at death"), nil
    RC.waitFight = true
    local events = RC.Fetch()
    RC.last = (events and #events > 0) and RC.Summary(RC.Hits(events), RC.MaxHP()) or nil
    -- a rival who killed you again: counted
    local k = RC.last and RC.last.killer
    local rival = k and k.player and RC.Rivals(db)[k.title]
    if rival then RC.KilledBy(db, rival, k.title) end
    if RC.last and db.popup ~= false then RC.Toggle(db, true) end
  elseif event == "PLAYER_REGEN_ENABLED" and RC.btnDirty and not RC.waitFight then
    RC.ApplyButton(db)
  elseif event == "PLAYER_REGEN_ENABLED" and RC.waitFight then
    if RC.btnDirty then RC.ApplyButton(db) end
    RC.waitFight = nil
    RC.afterFight = RC.Read("after the fight")
  elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
    if RC.win and RC.win:IsShown() then
      local ok, dead = pcall(function() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") end)
      if ok and not hidden(dead) and not dead then RC.win:Hide() end
    end
  end
end

-- the farm moving to another mob (or stopping) takes the old green crosshairs down
do
  local F = NS.Farm
  if F and F.SetActive then
    local set = F.SetActive
    F.SetActive = function(...)
      local r = set(...)
      RC.ClearKind("farm")
      if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
      return r
    end
  end
  -- and a new guide step takes the old step's blue crosshairs down
  local G = F and F.Guide
  if G and G.Take then
    local take = G.Take
    G.Take = function(...)
      local r = take(...)
      RC.ClearKind("guide")
      return r
    end
  end
end

RC.frame = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_DEAD", "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE",
                     "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                     "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED" }) do
  RC.frame:RegisterEvent(e)
end
RC.frame:SetScript("OnEvent", RC.OnEvent)

NS.Registry:Register({
  name = "recap",
  desc = "what killed you, and how",
  usage = "/bist recap [rival | rivals | pal | pals | forget <name> | key <key> | style <name> | why | raw]  (/bist rival, /bist pal ... work too)",
  defaults = { popup = true, pos = { "CENTER", 0, 140, "CENTER" } },
  options = {
    { kind = "toggle", label = "open when you die", get = function(db) return db.popup ~= false end,
      set = function(db, on) db.popup = on and true or false end },
    { kind = "toggle", label = "sound when a rival is near", get = function(db) return db.sound ~= false end,
      set = function(db, on) db.sound = on and true or false end },
    -- eight shapes do not fit one row of buttons: a stepper, the name shown, each step redrawn live
    { kind = "step", label = "crosshair", min = 1, max = #RC.STYLES, step = 1,
      get = function(db) for i, s in ipairs(RC.STYLES) do if s == (db.style or "rails") then return i end end return 1 end,
      set = function(db, v) RC.SetStyle(db, RC.STYLES[v] or "rails") end,
      show = function(db) return db.style or "rails" end },
    -- THE HINT (Arn: "a hint that says need nameplates on"): the crosshair hangs under a nameplate, and the
    -- game shows none for enemies until it is told to. The button tells it.
    { kind = "button", label = "needs nameplates on", button = "turn on", action = function()
        if InCombatLockdown and InCombatLockdown() then return NS.Print("not in a fight - try again after") end
        local set = (C_CVar and C_CVar.SetCVar) or SetCVar
        if set and pcall(set, "nameplateShowEnemies", "1") then NS.Print("enemy nameplates on") end
      end },
    { kind = "toggle", label = "guild rivals (amber)", get = function(db) return db.guildShow ~= false end,
      set = function(db, on)
        db.guildShow = on and true or false
        if not on then for unit, f in pairs(RC.marks) do if f.kind == "guild" then RC.UnmarkUnit(unit) end end end
        RC.PaintRivals()
      end },
    { kind = "toggle", label = "guildmates (+, alone)", get = function(db) return db.mates ~= false end,
      set = function(db, on) db.mates = on and true or false if not on then RC.ClearMates() end end },
    { kind = "toggle", label = "rival target button", get = function(db) return db.button ~= false end,
      set = function(db, on) db.button = on and true or false RC.ApplyButton(db) end },
  },
  OnOpen = function(_, db, recenter)
    if recenter then db.pos = { "CENTER", 0, 140, "CENTER" } if RC.win then RC.win:ClearAllPoints() RC.win:SetPoint("CENTER", UIParent, "CENTER", 0, 140) end end
    RC.Toggle(db, true)
  end,
  OnDisable = function(_, db)
    if RC.win then RC.win:Hide() end
    for unit in pairs(RC.marks) do RC.UnmarkUnit(unit) end
    RC.ClearMates()
    RC.ApplyButton(db)
  end,
  OnEnable = function(_, db) RC.ApplyButton(db) end,
  OnLogin = function(_, db) RC.style = db.style RC.ApplyButton(db) RC.HookMenus(db) RC.HookGuild(db) end,
  OnSlash = function(_, db, args)
    if args == "why" then return RC.Why(db) end
    if args == "rival" then return RC.RivalFromTarget(db) end
    if args == "pal" then return RC.PalFromTarget(db) end
    local style = args:match("^style%s*(%S*)$")
    if style then
      if RC.SetStyle(db, (style == "l" or style == "L") and "L" or style:lower()) then return NS.Print("crosshair: %s", db.style) end
      return NS.Print("crosshair styles: %s (now: %s)", table.concat(RC.STYLES, ", "), db.style or "rails")
    end
    local key = args:match("^key%s+(%S+)$")
    if key then
      db.key = (key:lower() ~= "off") and key:upper() or nil
      RC.ApplyButton(db)
      return NS.Print(db.key and ("%s targets your rivals"):format(db.key) or "rival key off")
    end
    if args == "pals" then
      local names = {}
      for name in pairs(RC.Pals(db)) do names[#names + 1] = name end
      table.sort(names)
      if #names == 0 then return NS.Print("no pals yet - target a friendly player and /bist pal, or right-click them") end
      NS.Print("your pals (%d): %s", #names, table.concat(names, ", "))
      return
    end
    if args == "rivals" then
      local names = {}
      for name in pairs(RC.Rivals(db)) do names[#names + 1] = name end
      table.sort(names)
      if #names == 0 then return NS.Print("no rivals yet - click a player on your death recap") end
      NS.Print("your rivals (%d):", #names)
      for _, name in ipairs(names) do
        local r = RC.Rivals(db)[name]
        local cc = r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[r.class]
        local shown = cc and ("|cff%02x%02x%02x%s|r"):format(cc.r * 255, cc.g * 255, cc.b * 255, name) or name
        DEFAULT_CHAT_FRAME:AddMessage(("  %s %s"):format(shown,
          T.text("muted", (r.kills or 0) > 0 and ("killed you %d more time%s"):format(r.kills, r.kills > 1 and "s" or "") or "")))
      end
      return
    end
    local forget = args:match("^forget%s+(.+)$")
    if forget then
      local list = RC.Rivals(db)
      for name in pairs(list) do
        if name:lower() == forget:lower() then
          list[name] = nil
          RC.UnmarkRival(name)
          RC.ApplyButton(db)
          return NS.Print("%s is no longer a rival", name)
        end
      end
      return NS.Print("no rival called %s", forget)
    end
    if args == "raw" or args == "now" then
      if args == "raw" then
        if not RC.atDeath then NS.Print("no death since you logged in - here is what the game holds right now:") end
        RC.Say(RC.atDeath)
        RC.Say(RC.afterFight)
      end
      RC.Say(RC.Read("right now"))
      return
    end
    RC.Toggle(db)
  end,
})
