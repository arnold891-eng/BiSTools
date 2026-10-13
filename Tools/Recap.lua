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
function RC.ToggleRival(db, a)
  if not (a and a.player and type(a.title) == "string") then return nil end
  local list = RC.Rivals(db)
  if list[a.title] then
    list[a.title] = nil
    NS.Print("%s is no longer a rival", a.title)
    return false
  end
  -- GOLD from the start: a rival you just clicked is the one you are hunting (Arn, 12 Oct: "current
  -- target gold, all previous targets silver, can click them again to turn them gold")
  list[a.title] = { class = a.class, guid = a.key, added = time and time() or 0, kills = 0, active = true }
  NS.Print("%s added to your rivals", T.text("warn", a.title))
  RC.PaintRivals()
  return true
end

--- Gold (hunted: the tracker calls them out) or silver (remembered, quiet).
function RC.SetActive(db, name, on)
  local r = RC.Rivals(db)[name]
  if not r then return nil end
  r.active = on and true or false
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

function RC.Spot(db, unit)
  if RC.GoldCount(db) == 0 then return looked(unit, nil, "nobody is gold") end
  local name = NS.Farm.Name(unit)
  if not name then return looked(unit, nil, "the game did not give a name (hidden, or nobody there)") end
  local r = RC.Rivals(db)[name]
  if not r then return looked(unit, name, "not a rival") end
  if not r.active then return looked(unit, name, "a silver rival") end
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
  f:SetSize(RC.W, footTop + 16)

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
      if IsShiftKeyDown and IsShiftKeyDown() then
        RC.Rivals(db)[self.rival] = nil
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
      GameTooltip:AddLine("Click: gold (hunting) or silver. Shift-click: forget.", 1, 1, 1, true)
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
  -- the target, read now, every way it can go wrong
  local ok, raw = pcall(UnitName, "target")
  local said
  if not ok then said = "refused"
  elseif raw == nil then said = "no target"
  elseif hidden(raw) then said = "HIDDEN by the game"
  else said = '"' .. tostring(raw) .. '"' end
  DEFAULT_CHAT_FRAME:AddMessage("  your target's name, as the game gives it now: " .. T.text("ink", said))
  if ok and type(raw) == "string" and not hidden(raw) then
    if list[raw] then
      DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("good", "that is a rival" .. (list[raw].active and " (gold)" or " (silver)")))
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
  local list = {}
  for name, r in pairs(RC.Rivals(db)) do list[#list + 1] = { name = name, r = r } end
  table.sort(list, function(x, y)
    if (x.r.active and true or false) ~= (y.r.active and true or false) then return x.r.active and true or false end
    return (x.r.seen or x.r.added or 0) > (y.r.seen or y.r.added or 0)
  end)
  for i, b in ipairs(d.rows) do
    local e = list[i]
    if e then
      b.rival = e.name
      local gold = e.r.active
      local mr, mg, mb = F.color(gold and "gold" or "dim")
      b.mark:SetColorTexture(mr, mg, mb, 1)
      b.name:SetText(e.name)
      local cc = e.r.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.r.class]
      if cc then b.name:SetTextColor(cc.r, cc.g, cc.b, gold and 1 or 0.55)
      else local r, g, bl = F.color("ink") b.name:SetTextColor(r, g, bl, gold and 1 or 0.55) end
      local bits = {}
      if (e.r.kills or 0) > 0 then bits[#bits + 1] = ("killed you %d"):format(e.r.kills) end
      local seen = ago(e.r.seen)
      if seen then bits[#bits + 1] = "seen " .. seen .. ((e.r.where and e.r.where ~= "") and (", " .. e.r.where) or "") end
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
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(unit) == "string" and not hidden(unit) then RC.Spot(db, unit) end
    return
  elseif event == "PLAYER_TARGET_CHANGED" then
    RC.Spot(db, "target") return
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    RC.Spot(db, "mouseover") return
  end
  if event == "PLAYER_DEAD" then
    RC.atDeath, RC.afterFight = RC.Read("at death"), nil
    RC.waitFight = true
    local events = RC.Fetch()
    RC.last = (events and #events > 0) and RC.Summary(RC.Hits(events), RC.MaxHP()) or nil
    -- a rival who killed you again: counted
    local k = RC.last and RC.last.killer
    local rival = k and k.player and RC.Rivals(db)[k.title]
    if rival then rival.kills = (rival.kills or 0) + 1 rival.last = time and time() or 0 end
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
for _, e in ipairs({ "PLAYER_DEAD", "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE",
                     "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
  RC.frame:RegisterEvent(e)
end
RC.frame:SetScript("OnEvent", RC.OnEvent)

NS.Registry:Register({
  name = "recap",
  desc = "what killed you, and how",
  usage = "/bist recap [rivals | forget <name> | raw]",
  defaults = { popup = true, pos = { "CENTER", 0, 140, "CENTER" } },
  options = {
    { kind = "toggle", label = "open when you die", get = function(db) return db.popup ~= false end,
      set = function(db, on) db.popup = on and true or false end },
    { kind = "toggle", label = "sound when a rival is near", get = function(db) return db.sound ~= false end,
      set = function(db, on) db.sound = on and true or false end },
  },
  OnOpen = function(_, db, recenter)
    if recenter then db.pos = { "CENTER", 0, 140, "CENTER" } if RC.win then RC.win:ClearAllPoints() RC.win:SetPoint("CENTER", UIParent, "CENTER", 0, 140) end end
    RC.Toggle(db, true)
  end,
  OnDisable = function() if RC.win then RC.win:Hide() end end,
  OnSlash = function(_, db, args)
    if args == "why" then return RC.Why(db) end
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
