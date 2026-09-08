-- BiSTools / Tools / TargetFarming.lua
-- Remembers the last mob you killed (or a name you typed). Click it and the
-- scanner ticks: every half second it looks for a fresh copy nearby (alive, not
-- in combat, not tapped) and drops the skull on it. Click again to stop.
-- Optional key targets whatever wears the skull.
local _, NS = ...
local T = NS.T
local SKULL = 8   -- mouseover finds wear the skull
local SCAN_MARKS = 7   -- the scanner deals 1..7 (star..cross) to every free copy it sees

-- everything for this tool hangs off one table (locals budget rule)
local F = { rows = {} }

local SHADE = { frame = "0d0b18", header = "141127", field = "17132e", hair = "2a2446", edge = "3a3260" }
local function hx(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
function F.color(name)
  if SHADE[name] then return hx(SHADE[name]) end
  return T.rgb(name)
end
function F.tex(parent, layer, name, a)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  local r, g, b = F.color(name)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end
function F.fs(parent, text, size, color)
  local s = parent:CreateFontString(nil, "OVERLAY")
  s:SetFont(STANDARD_TEXT_FONT, size or 12, "")
  local r, g, b = F.color(color or "ink")
  s:SetTextColor(r, g, b, 1)
  s:SetText(text or "")
  return s
end
-- ---------------------------------------------------------------- kills
function F.OwnGUID(guid)
  return guid and (guid == UnitGUID("player") or (UnitExists("pet") and guid == UnitGUID("pet")))
end

function F.Record(db, name, guid)
  local last = db.last
  if last and last.name == name then
    last.count = last.count + 1
    last.guid = guid or last.guid
  else
    db.last = { name = name, count = 1, guid = guid }
  end
  return db.last
end

-- ---------------------------------------------------------------- scan
function F.Plates()
  if not C_NamePlate or not C_NamePlate.GetNamePlates then return {} end
  return C_NamePlate.GetNamePlates()
end

function F.Clean(u)
  return UnitExists(u) and UnitCanAttack("player", u) and not UnitIsDead(u)
    and not UnitAffectingCombat(u) and not (UnitIsTapDenied and UnitIsTapDenied(u))
end

-- ---------------------------------------------------------------- sound
-- db.sound: "first"  = voice line on the first find, quiet ping after (default)
--           "always" = voice line on every find
--           "off"    = nothing
F.VOICE_LINE = "Skull"
F.MARK_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
F.PING = 3081 -- TELL_MESSAGE (whisper ping): audible over combat, not a siren
F.SOUND_MODES = { "first", "always", "off" }
function F.Speak(text)
  local FC = _G.FojjiCore
  if FC and FC.Speak and FC:Speak(text) then return "fojji" end
  if C_VoiceChat and C_VoiceChat.SpeakText then
    C_VoiceChat.SpeakText(0, text, Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1, 1, 100)
    return "tts"
  end
  PlaySound(F.PING, "Master")
  return "ping"
end
function F.Found(db, line)
  db.finds = (db.finds or 0) + 1
  local mode = db.sound or "first"
  if mode == "off" then return end
  if mode == "always" or db.finds == 1 then F.Speak(line or F.VOICE_LINE) else PlaySound(F.PING, "Master") end
end
function F.SetSound(db, mode)
  for _, m in ipairs(F.SOUND_MODES) do
    if m == mode then db.sound = m return true end
  end
  return false
end

-- one pass: returns unit token that now carries the skull (or nil)
function F.Scan(name, db)
  -- the mouse first: hovering works from any distance, nameplates do not
  if UnitExists("mouseover") and UnitName("mouseover") == name and F.Clean("mouseover") then
    -- already wearing anything (scanner mark, hand mark, skull)? leave it alone
    if not GetRaidTargetIndex("mouseover") then
      SetRaidTarget("mouseover", SKULL)
      if db then F.Found(db, "Skull") end
    end
    return "mouseover"
  end
  -- plates: every clean copy gets its own mark from 1..7. Marks already on a
  -- clean copy stay put; the rest get the lowest mark nobody clean is wearing.
  local first, used, unmarked = nil, {}, {}
  if db and F.Spots then
    for m in pairs(F.Spots.BoundMarks(db, name)) do used[m] = true end -- spot marks are not the scanner's to deal
  end
  for _, plate in ipairs(F.Plates()) do
    local u = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if u and UnitName(u) == name and F.Clean(u) then
      local m = GetRaidTargetIndex(u)
      if m and m >= 1 and m <= SCAN_MARKS then
        used[m] = true
        first = first or u
      else
        unmarked[#unmarked + 1] = u
      end
    end
  end
  local dealt = 0
  for _, u in ipairs(unmarked) do
    local m
    for i = 1, SCAN_MARKS do if not used[i] then m = i break end end
    if not m then break end
    used[m] = true
    SetRaidTarget(u, m)
    dealt = dealt + 1
    first = first or u
  end
  if dealt > 0 and db then F.Found(db, F.MARK_NAMES[dealt == 1 and GetRaidTargetIndex(unmarked[1]) or 0] or "Target") end
  return first
end

function F.Tick(db)
  if not db.active then return F.Stop() end
  F.marked = F.Scan(db.active, db)
  if F.Spots then F.Spots.Sync(db) F.Spots.Warn(db) end
end

function F.Start(db)
  if F.ticker then F.ticker:Cancel() end
  F.ticker = C_Timer.NewTicker(db.interval or 0.5, function() F.Tick(db) end)
  F.Tick(db)
end

function F.Stop()
  if F.ticker then F.ticker:Cancel() F.ticker = nil end
  F.marked = nil
end

function F.SetActive(db, name)
  if name and db.active == name then name = nil end
  db.active = name
  db.finds = 0
  if name then
    if not NS.Registry:Enabled("farm") then db.active = nil return end
    F.Start(db)
    NS.Print("farming %s - skull follows a free one", T.text("accent", name))
  else
    F.Stop()
  end
  F.Refresh(db)
end

-- ---------------------------------------------------------------- target key
-- One secure button. PreClick (out of combat) points it at the skulled unit;
-- in combat it falls back to /targetexact <name>.
function F.TargetButton()
  if F.tbtn then return F.tbtn end
  local b = CreateFrame("Button", "BiSToolsFarmTarget", UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "")
  b:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local db = F.db
    local u = db and db.active and (F.marked or F.Scan(db.active))
    if u and F.Clean(u) then
      self:SetAttribute("type", "target")
      self:SetAttribute("unit", u)
    else
      self:SetAttribute("type", "macro")
      self:SetAttribute("unit", nil)
      self:SetAttribute("macrotext", db and db.active and ("/targetexact " .. db.active) or "")
    end
  end)
  F.tbtn = b
  return b
end

function F.ApplyKey(db)
  local b = F.TargetButton()
  if InCombatLockdown() then F.keyDirty = true return end
  F.keyDirty = false
  ClearOverrideBindings(b)
  if db.key then SetOverrideBindingClick(b, true, db.key, "BiSToolsFarmTarget") end
end

-- ---------------------------------------------------------------- window
-- Innervate chrome: 16px header, tiny logo, 9pt title, 12x12 boxed buttons.
--   +------------------------------+
--   | [skull] Target Farming  _  x |
--   |  Vekh'nir Dreadhawk      x24 |   <- last thing you killed; click = farm it
--   |  Typed Name                  |   <- only when you searched for one
--   |  [ mob name...             ] |
--   +------------------------------+
F.W, F.HEADER, F.ROW, F.FIELD, F.PAD = 170, 16, 16, 16, 4
F.HEAD_A, F.BODY_A = 0.5, 0.45

function F.border(frame, name, a)
  local b = {}
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do
    local t = frame:CreateTexture(nil, "OVERLAY")
    local r, g, bl = F.color(name)
    t:SetColorTexture(r, g, bl, a or 1)
    b[side] = t
  end
  b.top:SetPoint("TOPLEFT") b.top:SetPoint("TOPRIGHT") b.top:SetHeight(1)
  b.bottom:SetPoint("BOTTOMLEFT") b.bottom:SetPoint("BOTTOMRIGHT") b.bottom:SetHeight(1)
  b.left:SetPoint("TOPLEFT") b.left:SetPoint("BOTTOMLEFT") b.left:SetWidth(1)
  b.right:SetPoint("TOPRIGHT") b.right:SetPoint("BOTTOMRIGHT") b.right:SetWidth(1)
  function b:set(n, alpha)
    local r, g, bl = F.color(n)
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do self[side]:SetColorTexture(r, g, bl, alpha or 1) end
  end
  return b
end

function F.HeaderButton(head, x, label, tip, tip2, onclick, colour)
  local b = CreateFrame("Button", nil, head)
  b:SetSize(12, 12)
  b:SetPoint("RIGHT", head, "RIGHT", x, 0)
  F.tex(b, "BACKGROUND", "field", 0.9)
  local edge = F.border(b, "edge", 1)
  local t = F.fs(b, label, 8, colour or "muted")
  t:SetPoint("CENTER")
  b.edge, b.label = edge, t
  b:SetScript("OnClick", function() onclick() end)
  b:SetScript("OnEnter", function(self)
    edge:set(colour or "accent", 1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(tip)
      if tip2 then GameTooltip:AddLine(tip2, 1, 1, 1, true) end
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    edge:set("edge", 1)
    if GameTooltip then GameTooltip:Hide() end
  end)
  return b
end

function F.Build(db)
  if F.frame then return F.frame end
  F.db = db
  local f = CreateFrame("Frame", "BiSToolsFarm", UIParent)
  F.frame = f
  f:SetSize(F.W, F.HEADER)
  f:SetFrameStrata("MEDIUM")
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
  F.tex(f, "BACKGROUND", "frame", F.BODY_A)
  F.border(f, "edge", 0.35)

  local head = CreateFrame("Frame", nil, f)
  F.head = head
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(F.HEADER)
  F.tex(head, "BACKGROUND", "header", F.HEAD_A)
  local hair = head:CreateTexture(nil, "BORDER")
  hair:SetPoint("BOTTOMLEFT") hair:SetPoint("BOTTOMRIGHT") hair:SetHeight(1)
  do local r, g, b = F.color("edge") hair:SetColorTexture(r, g, b, 1) end

  local logo = head:CreateTexture(nil, "ARTWORK")
  logo:SetSize(11, 11)
  logo:SetPoint("LEFT", head, "LEFT", 4, 0)
  logo:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
  local title = F.fs(head, "Target |cffb980ffFarming|r", 9, "ink")
  title:SetPoint("LEFT", logo, "RIGHT", 4, 0)

  F.closeBtn = F.HeaderButton(head, -3, "x", "Close", "/bt farm reopens it. The scanner keeps going.",
    function() F.Toggle(db, false) end, "warn")
  F.collapseBtn = F.HeaderButton(head, -17, "_", "Collapse", "Just the title bar.",
    function() F.SetCollapsed(db, not db.collapsed) end)
  F.spotsBtn = F.HeaderButton(head, -31, "t", "Spawn timers", "Where you killed it and when it comes back. /bt farm spots",
    function() if F.Spots then F.Spots.Toggle(db) end end)

  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
  body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  body:SetHeight(1)
  F.body = body

  -- search field: its own little well with an edge, like Innervate's inputs
  local well = CreateFrame("Frame", nil, body)
  well:SetHeight(F.FIELD)
  F.tex(well, "BACKGROUND", "field", 0.9)
  F.wellEdge = F.border(well, "edge", 1)
  F.well = well
  local eb = CreateFrame("EditBox", "BiSToolsFarmName", well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 9, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(48)
  do local r, g, b = F.color("ink") eb:SetTextColor(r, g, b, 1) end
  local ph = F.fs(well, "mob name...", 9, "dim")
  ph:SetPoint("LEFT", 4, 0)
  F.placeholder = ph
  eb:SetScript("OnEditFocusGained", function() ph:Hide() F.wellEdge:set("accent", 1) end)
  eb:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then ph:Show() end
    F.wellEdge:set("edge", 1)
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self)
    local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
    self:SetText("")
    self:ClearFocus()
    if name ~= "" then F.Search(db, name) end
  end)
  F.edit = eb

  local pos = db.pos
  f:SetPoint(pos[1], UIParent, pos[4] or pos[1], pos[2], pos[3])
  f:Hide()
  F.Refresh(db)
  return f
end

-- a row: 3px accent bar when it is the active one, name left, count right
function F.Row(i, db)
  local r = F.rows[i]
  if r then return r end
  r = CreateFrame("Button", "BiSToolsFarmRow" .. i, F.body)
  r:SetHeight(F.ROW)
  r.bg = F.tex(r, "BACKGROUND", "surface", 0)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT") r.bar:SetPoint("BOTTOMLEFT") r.bar:SetWidth(3)
  do local rr, g, b = F.color("accent") r.bar:SetColorTexture(rr, g, b, 1) end
  r.name = F.fs(r, "", 9, "ink")
  r.name:SetPoint("LEFT", 8, 0)
  r.count = F.fs(r, "", 8, "muted")
  r.count:SetPoint("RIGHT", -6, 0)
  r:SetScript("OnEnter", function(self) F.PaintRow(self, db, true) end)
  r:SetScript("OnLeave", function(self) F.PaintRow(self, db, false) end)
  r:SetScript("OnClick", function(self) if self.mob then F.SetActive(db, self.mob) end end)
  F.rows[i] = r
  return r
end

function F.PaintRow(r, db, hover)
  local active = r.mob and r.mob == db.active
  local rr, g, b
  if active then rr, g, b = F.color("accentSoft") r.bg:SetColorTexture(rr, g, b, 1)
  elseif hover then rr, g, b = F.color("sunken") r.bg:SetColorTexture(rr, g, b, 1)
  else rr, g, b = F.color("surface") r.bg:SetColorTexture(rr, g, b, 0) end
  if active then r.bar:Show() else r.bar:Hide() end
  rr, g, b = F.color(active and "accent" or "ink")
  r.name:SetTextColor(rr, g, b, 1)
end

-- what the body shows: the last kill, then the searched name if it is a different mob
function F.Entries(db)
  local out = {}
  if db.last then out[#out + 1] = db.last end
  if db.custom and not (db.last and db.last.name == db.custom) then
    out[#out + 1] = { name = db.custom, count = db.customKills or 0 }
  end
  return out
end

function F.Refresh(db)
  if not F.frame then return end
  local entries = db.collapsed and {} or F.Entries(db)
  local y = 0
  for i = 1, math.max(#entries, #F.rows) do
    local r = F.Row(i, db)
    local e = entries[i]
    if e then
      r.mob = e.name
      r.name:SetText(e.name)
      r.count:SetText(e.count > 1 and ("x" .. e.count) or "")
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", F.body, "TOPLEFT", 0, -y)
      r:SetPoint("TOPRIGHT", F.body, "TOPRIGHT", 0, -y)
      F.PaintRow(r, db, false)
      r:Show()
      y = y + F.ROW
    else
      r.mob = nil
      r:Hide()
    end
  end
  if db.collapsed then
    F.well:Hide()
  else
    F.well:Show()
    F.well:ClearAllPoints()
    F.well:SetPoint("TOPLEFT", F.body, "TOPLEFT", F.PAD, -(y + F.PAD))
    F.well:SetPoint("TOPRIGHT", F.body, "TOPRIGHT", -F.PAD, -(y + F.PAD))
    y = y + F.PAD + F.FIELD + F.PAD
  end
  F.body:SetHeight(math.max(y, 1))
  F.frame:SetHeight(F.HEADER + y)
end

-- typed name: remember it, farm it
function F.Search(db, name)
  if db.custom ~= name then db.customKills = 0 end
  db.custom = name
  if db.active ~= name then F.SetActive(db, name) else F.Refresh(db) end
end

function F.SetCollapsed(db, on)
  db.collapsed = on and true or false
  F.Refresh(db)
end

function F.Clear(db)
  db.last = nil
  db.custom = nil
  db.customKills = 0
  F.SetActive(db, nil)
end

function F.Toggle(db, want)
  F.Build(db)
  if want == nil then want = not F.frame:IsShown() end
  db.shown = want and true or false
  if want then F.frame:Show() F.Refresh(db) else F.frame:Hide() end
end

-- ---------------------------------------------------------------- events
function F.OnEvent(db, event, ...)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local _, sub, _, srcGUID, _, _, _, dstGUID, dstName = CombatLogGetCurrentEventInfo()
    if sub == "PARTY_KILL" and F.OwnGUID(srcGUID) and dstName
      and dstGUID and dstGUID:find("^Creature") then
      -- locked on something? then only that mob counts; the page does not
      -- swap to whatever else you killed on the way
      if db.active and dstName ~= db.active then return end
      if db.active and db.custom == dstName and not (db.last and db.last.name == dstName) then
        db.customKills = (db.customKills or 0) + 1
      else
        F.Record(db, dstName, dstGUID)
      end
      if F.Spots then
        -- the mark it died wearing tells the spot apart better than where you stood
        local mark
        if UnitExists("target") and UnitGUID("target") == dstGUID then mark = GetRaidTargetIndex("target") end
        F.Spots.Kill(db, dstName, mark)
      end
      F.Refresh(db)
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if F.keyDirty then F.ApplyKey(db) end
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    if db.active and F.ticker then F.Tick(db) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if db.active and F.Spots then F.Spots.Sync(db) end
  end
end

function F.Hook(db)
  F.events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  F.events:RegisterEvent("PLAYER_REGEN_ENABLED")
  F.events:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  F.events:RegisterEvent("PLAYER_TARGET_CHANGED")
  F.ApplyKey(db)
  if db.shown then F.Toggle(db, true) end
  if db.active then F.Start(db) end
end

NS.Registry:Register({
  name = "farm",
  desc = "click a kill; skull auto-follows a free copy nearby",
  usage = "/bt farm [clear | add <name> | key <KEY>|none | sound first|always|off | spots [clear] | radius <yd> | burst <sec> | prune <sec>|off]",
  defaults = { last = nil, custom = nil, shown = true, collapsed = false, pos = { "CENTER", 300, 0 },
    active = nil, interval = 0.5, key = nil, sound = "first", finds = 0 },
  OnInit = function(self, db)
    F.db = db
    F.events = CreateFrame("Frame")
    F.events:SetScript("OnEvent", function(_, ev, ...) F.OnEvent(db, ev, ...) end)
  end,
  OnLogin = function(self, db) F.Hook(db) end,
  OnEnable = function(self, db) F.Hook(db) end,
  OnDisable = function(self, db)
    F.events:UnregisterAllEvents()
    if F.Spots then F.Spots.Hide() end
    F.Stop()
    if F.tbtn and not InCombatLockdown() then ClearOverrideBindings(F.tbtn) end
    if F.frame then F.frame:Hide() end
  end,
  OnSlash = function(self, db, args)
    local cmd, rest = args:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd == "clear" then return F.Clear(db) end
    if cmd == "spots" and F.Spots then
      if rest:lower() == "clear" then return F.Spots.Clear(db) end
      return F.Spots.Toggle(db)
    end
    if cmd == "burst" and F.Spots then
      if rest ~= "" then F.Spots.SetBurst(db, rest) end
      return NS.Print("burst window: %s s (%d-%d) - kills closer than this at one spot are different mobs",
        T.text("accent", F.Spots.Burst(db)), F.Spots.B_MIN, F.Spots.B_MAX)
    end
    if cmd == "prune" and F.Spots then
      if rest ~= "" then F.Spots.SetPrune(db, rest) end
      local p = F.Spots.Prune(db)
      return NS.Print("prune: %s - a spot sat up this long with no kill folds into its neighbour",
        p == 0 and T.text("warn", "off") or T.text("accent", p .. " s"))
    end
    if cmd == "radius" and F.Spots then
      local r = rest ~= "" and F.Spots.SetRadius(db, rest)
      return NS.Print("spot radius: %s yd (%d-%d)", T.text("accent", F.Spots.Radius(db)), F.Spots.R_MIN, F.Spots.R_MAX)
    end
    if cmd == "sound" then
      if rest ~= "" and not F.SetSound(db, rest:lower()) then
        return NS.Print("sound first | always | off")
      end
      return NS.Print("sound: %s", T.text("accent", db.sound or "first"))
    end
    if cmd == "add" and rest ~= "" then F.Toggle(db, true) return F.Search(db, rest) end
    if cmd == "key" then
      if rest == "" then return NS.Print("target key: %s", db.key or "none") end
      db.key = rest:lower() ~= "none" and rest:upper() or nil
      F.ApplyKey(db)
      return NS.Print("target key %s", db.key and T.text("accent", db.key) or "cleared")
    end
    F.Toggle(db)
  end,
})
NS.Farm = F
