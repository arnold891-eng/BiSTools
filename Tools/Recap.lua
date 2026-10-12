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

local function K() return NS.Farm end

local function fitText(fs, text, width)
  if BiSTheme and BiSTheme.Fit then BiSTheme.Fit(fs, text, width) else fs:SetText(text) end
end

local function pct(n, total)
  if not (n and total and total > 0) then return "" end
  return (" (%d%%)"):format(math.floor(n / total * 100 + 0.5))
end

local function card(parent, w)
  local F = K()
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(w, RC.CARD_H)
  c.bg = F.tex(c, "BACKGROUND", "field", 0.95)
  c.edge = F.border(c, "hair", 1)
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
  if not a then c:Hide() return end
  c:Show()
  local w = c.w - 10
  c.role:SetText(role)
  do local F = K() local r, g, b = F.color(isKiller and "warn" or "muted") c.role:SetTextColor(r, g, b, 1) end
  fitText(c.name, a.title, w)
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
  else
    line = ("%d hits"):format(a.hits) .. (a.crits > 0 and (" · %d crit%s"):format(a.crits, a.crits > 1 and "s" or "") or "")
  end
  fitText(c.what, line, w)
end

function RC.Build(db)
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
  f:SetSize(RC.W, footTop + 16)

  local pos = db.pos
  f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
  f:Hide()
  return f
end

function RC.Paint(s)
  local f = RC.win
  if not (f and s) then return end
  local F = K()
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
    f.foot:SetText(("%d damage in %.1f seconds"):format(s.total, s.seconds))
  elseif s.seconds then
    f.foot:SetText(("damage in %.1f seconds (some amounts hidden)"):format(s.seconds))
  else
    f.foot:SetText("")
  end
end

function RC.Toggle(db, want)
  RC.Build(db)
  if want == nil then want = not RC.win:IsShown() end
  if want then
    if not RC.last then
      local events = RC.Fetch()
      if events and #events > 0 then RC.last = RC.Summary(RC.Hits(events), RC.MaxHP()) end
    end
    if not RC.last then
      NS.Print("nothing has killed you yet this session")
      RC.win:Hide()
      return false
    end
    RC.Paint(RC.last)
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
function RC.OnEvent(_, event)
  if not R:Enabled("recap") then return end
  local db = R:DBFor(R:Get("recap"))
  if event == "PLAYER_DEAD" then
    RC.atDeath, RC.afterFight = RC.Read("at death"), nil
    RC.waitFight = true
    local events = RC.Fetch()
    RC.last = (events and #events > 0) and RC.Summary(RC.Hits(events), RC.MaxHP()) or nil
    if RC.last and db.popup ~= false then RC.Toggle(db, true) end
  elseif event == "PLAYER_REGEN_ENABLED" and RC.waitFight then
    RC.waitFight = nil
    RC.afterFight = RC.Read("after the fight")
  elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
    if RC.win and RC.win:IsShown() then
      local ok, dead = pcall(function() return UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") end)
      if ok and not hidden(dead) and not dead then RC.win:Hide() end
    end
  end
end

RC.frame = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_DEAD", "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
  RC.frame:RegisterEvent(e)
end
RC.frame:SetScript("OnEvent", RC.OnEvent)

NS.Registry:Register({
  name = "recap",
  desc = "what killed you, and how",
  usage = "/bist recap [raw]",
  defaults = { popup = true, pos = { "CENTER", 0, 140, "CENTER" } },
  options = {
    { kind = "toggle", label = "open when you die", get = function(db) return db.popup ~= false end,
      set = function(db, on) db.popup = on and true or false end },
  },
  OnOpen = function(_, db, recenter)
    if recenter then db.pos = { "CENTER", 0, 140, "CENTER" } if RC.win then RC.win:ClearAllPoints() RC.win:SetPoint("CENTER", UIParent, "CENTER", 0, 140) end end
    RC.Toggle(db, true)
  end,
  OnDisable = function() if RC.win then RC.win:Hide() end end,
  OnSlash = function(_, db, args)
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
