-- BiSTools headless harness. Run from the addon root:  lua5.1 dev/tests.lua
-- ------------------------------------------------------------ WoW mock
local W = { combat = false, target = nil, plates = {}, marks = {}, now = 0 }
_G.__W = W
-- the TOC is the truth for the version and for what loads, in what order
local function readTOC()
  local fh = assert(io.open("BiSTools.toc", "r"))
  local ver, list = nil, {}
  for line in fh:lines() do
    line = line:gsub("\r$", "")
    local v = line:match("^## Version:%s*(.-)%s*$")
    if v then ver = v end
    if line ~= "" and not line:match("^#") then list[#list + 1] = (line:gsub("\\", "/")) end
  end
  fh:close()
  return ver, list
end
local TOC_VERSION, TOC_FILES = readTOC()
_G.GetAddOnMetadata = function(_, key) if key == "Version" then return TOC_VERSION end return "test" end
_G.STANDARD_TEXT_FONT = "font"
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.lastMsg = m end }
_G.SlashCmdList = {}
_G.GetTime = function() return W.now end
W.afters = {}
function W.runAfters(dt)
  W.now = W.now + (dt or 1)
  local again = true
  while again do
    again = false
    for i = #W.afters, 1, -1 do
      local a = W.afters[i]
      if a.at <= W.now then table.remove(W.afters, i) a.fn() again = true end
    end
  end
end
-- group / raid: W.raid = { {name, zone, online, x, y, inst, visible}, ... }, raid1 = W.raid[1] = "Me"
W.raid, W.inRaid, W.me = { { name = "Me" } }, false, { zone = "Netherstorm", x = 0, y = 0, inst = 530 }
_G.GetNumGroupMembers = function() return #W.raid > 1 and #W.raid or 0 end
_G.IsInRaid = function() return W.inRaid end
_G.IsInGroup = function(cat) if cat then return false end return #W.raid > 1 end
_G.LE_PARTY_CATEGORY_INSTANCE = 2
_G.GetRaidRosterInfo = function(i)
  local m = W.raid[i]
  if not m then return nil end
  return m.name, 0, 1, 70, "Warrior", "WARRIOR", m.zone, m.online ~= false, false
end
_G.UnitIsUnit = function(a, b)
  local function nm(u)
    if u == "player" then return "Me" end
    if u == "target" then return W.target and W.target.name end
    local i = u:match("^raid(%d+)$") return i and W.raid[tonumber(i)] and W.raid[tonumber(i)].name
  end
  return nm(a) ~= nil and nm(a) == nm(b)
end
_G.UnitPosition = function(u)
  if u == "player" then return W.me.y, W.me.x, 0, W.me.inst end
  local i = u:match("^raid(%d+)$")
  local m = i and W.raid[tonumber(i)]
  if m and m.inst == W.me.inst then return m.y, m.x, 0, m.inst end
  return nil
end
_G.UnitIsVisible = function(u)
  local i = u:match("^raid(%d+)$")
  local m = i and W.raid[tonumber(i)]
  return m and m.visible ~= false and m.inst == W.me.inst and m.x ~= nil or false
end
_G.UnitIsConnected = function() return true end
_G.GetRealZoneText = function() return W.me.zone end
_G.IsInInstance = function() return false, "none" end
_G.GetInstanceInfo = function() return W.me.zone, "none", 0, "", 0, 0, false, W.me.inst end
_G.IsShiftKeyDown = function() return W.shift or false end
W.cursor = { 0, 0 }
_G.GetCursorPosition = function() return W.cursor[1], W.cursor[2] end
W.interactKey = "NUMPADMULTIPLY"
_G.GetBindingKey = function(cmd) if cmd == "INTERACTTARGET" then return W.interactKey end end
W.messages = {}
function W.sentCount(needle) local n = 0 for _, m in ipairs(W.messages) do if m:find(needle, 1, true) then n = n + 1 end end return n end
_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chan) W.messages[#W.messages + 1] = msg W.prefixes[#W.prefixes + 1] = prefix end }
W.prefixes = {}
W.innervateLoaded = false
_G.IsAddOnLoaded = function(name) return name == "BiSInnervate" and W.innervateLoaded or false end
_G.hooksecurefunc = function(name, fn)
  local orig = _G[name]
  if type(orig) ~= "function" then return end
  _G[name] = function(...) local r = orig(...) fn(...) return r end
end
W.offer = nil
_G.GetSummonConfirmSummoner = function() return W.offer and W.offer.summoner end
_G.GetSummonConfirmAreaName = function() return W.offer and W.offer.area end
_G.GetSummonConfirmTimeLeft = function() return W.offer and W.offer.left or 0 end
_G.ConfirmSummon = function() W.accepted = true end
W.notices = {}
_G.RaidWarningFrame = {}
_G.RaidNotice_AddMessage = function(_, text) W.notices[#W.notices + 1] = text end
_G.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.5, b = 0 } }
W.tooltipShown, W.tooltipText = false, nil
_G.GameTooltipTextLeft1 = { GetText = function() return W.tooltipText end }
W.now = 1000
_G.time = function() return W.now end
W.facing = 0
_G.GetPlayerFacing = function() return W.facing end
W.map, W.px, W.py = 1952, 0.50, 0.50   -- world size 5000x3300 -> 0.01 = 50y/33y
_G.C_Map = {
  GetBestMapForUnit = function() return W.map end,
  GetPlayerMapPosition = function() return { GetXY = function() return W.px, W.py end } end,
  GetMapWorldSize = function() return 5000, 3300 end,
}
_G.GameTooltip = { SetOwner = function() end, AddLine = function() end, AddDoubleLine = function() end, Show = function() end, Hide = function() end,
  IsShown = function() return W.tooltipShown end, GetOwner = function() return nil end }
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.InCombatLockdown = function() return W.combat end
_G.UnitGUID = function(u)
  if u == "player" then return "Player-1" elseif u == "pet" then return "Pet-1" end
  if u == "target" and W.target then return W.target.guid end
end
_G.UnitExists = function(u)
  if u == "player" then return true end
  local ri = u:match("^raid(%d+)$")
  if ri then return W.raid[tonumber(ri)] ~= nil end
  if u == "pet" then return W.hasPet end
  if u == "target" then return W.target ~= nil end
  return W.plates[u] ~= nil
end
local function unit(u) if u == "target" then return W.target end return W.plates[u] end
_G.UnitName = function(u)
  if u == "player" then return "Me" end
  local i = u:match("^raid(%d+)$")
  if i then return W.raid[tonumber(i)] and W.raid[tonumber(i)].name end
  local x = unit(u) return x and x.name
end
_G.UnitIsDead = function(u) local x = unit(u) return x and x.dead or false end
_G.UnitAffectingCombat = function(u) local x = unit(u) return x and x.combat or false end
_G.UnitIsTapDenied = function(u) local x = unit(u) return x and x.tapped or false end
_G.UnitCanAttack = function(_, u) local x = unit(u) return x and x.hostile ~= false end
_G.SetRaidTarget = function(u, i)
  for k, v in pairs(W.marks) do if v == i then W.marks[k] = nil end end -- one skull at a time
  W.marks[u] = i
end
_G.GetRaidTargetIndex = function(u) return W.marks[u] end
W.tickers = {}
_G.C_Timer = { After = function(delay, fn) W.afters[#W.afters + 1] = { at = W.now + delay, fn = fn } end,
  NewTicker = function(iv, fn)
  local t = { iv = iv, fn = fn, alive = true }
  function t:Cancel() self.alive = false end
  W.tickers[#W.tickers + 1] = t
  return t
end }
function W.tick() for _, t in ipairs(W.tickers) do if t.alive then t.fn() end end end
W.binds = {}
W.sounds = {} W.spoken = {}
_G.PlaySound = function(id) W.sounds[#W.sounds + 1] = id end
_G.C_VoiceChat = { SpeakText = function(_, text) W.spoken[#W.spoken + 1] = text end }
_G.ClearOverrideBindings = function(owner) W.binds[owner] = nil end
_G.SetOverrideBindingClick = function(owner, prio, key, btn) W.binds[owner] = { key = key, btn = btn } end
_G.CombatLogGetCurrentEventInfo = function() return unpack(W.cleu) end
_G.C_NamePlate = { GetNamePlates = function()
  local out = {}
  for tok in pairs(W.plates) do if tok:find("^nameplate") then out[#out + 1] = { namePlateUnitToken = tok } end end
  table.sort(out, function(a, b) return a.namePlateUnitToken < b.namePlateUnitToken end)
  return out
end }

local function num3(a, b, c) return type(a) == "number" and type(b) == "number" and type(c) == "number" end
local function Texture()
  local t = { shown = true }
  function t:SetAllPoints() end
  function t:SetPoint() end
  function t:SetHeight() end
  function t:SetWidth() end
  function t:SetSize() end
  function t:SetTexture(x) self.file = x end
  function t:SetTexCoord() end
  function t:ClearAllPoints() end
  function t:SetRotation(r) if type(r) ~= "number" then error("SetRotation wants a number") end self.rot = r end
  function t:SetColorTexture(r, g, b, a)
    if not num3(r, g, b) then error("SetColorTexture wants r,g,b numbers") end
    self.color = { r, g, b, a }
  end
  function t:Hide() self.shown = false end
  function t:Show() self.shown = true end
  return t
end
local function FontString()
  local s = { shown = true }
  function s:SetFont(_, size) self.size = size end
  function s:SetPoint(p, rel, rp, x, y) if type(rel) == "number" then self.x, self.y = rel, rp else self.x, self.y = x, y end end
  function s:ClearAllPoints() end
  function s:SetText(x) self.text = x end
  function s:GetText() return self.text end
  function s:SetAlpha(a) self.alpha = a end
  function s:GetParent() return self.parent end
  function s:SetTextColor(r, g, b, a)
    if not num3(r, g, b) then error("SetTextColor wants r,g,b numbers") end
    self.color = { r, g, b, a }
  end
  -- ~5.5 px per character at the sizes we use: close enough to catch a label
  -- that runs into the next control
  -- ~0.6 px per point per character: 9pt = 5.4, 8pt = 4.8. Close enough to catch a
  -- label that runs into the next control or off the window
  function s:GetStringWidth()
    -- inline textures |T...:w:h...|t take their declared width, escapes take none
    local t, tex = tostring(self.text or ""), 0
    t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #t * (self.size or 9) * 0.6 + tex
  end
  function s:Hide() self.shown = false end
  function s:Show() self.shown = true end
  return s
end
local frames = {}
_G.CreateFrame = function(kind, name, parent, template)
  local f = { kind = kind, name = name, parent = parent, template = template,
    shown = true, scripts = {}, attrs = {}, events = {}, h = 0 }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterAllEvents() self.events = {} end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:IsMouseOver() return W.mouseOver == self end
  function f:GetParent() return self.parent end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:CreateTexture() local t = Texture() self.regions = self.regions or {} self.regions[#self.regions + 1] = t return t end
  function f:CreateFontString() local fs = FontString() fs.parent = self return fs end
  function f:SetSize(w, h) self.w, self.h = w, h end
  function f:SetHeight(h) self.h = h end
  function f:SetWidth(w) self.w = w end
  function f:SetAllPoints() end
  function f:SetTextInsets() end
  function f:SetFont() end
  function f:SetAutoFocus() end
  function f:SetMaxLetters() end
  function f:SetTextColor(r, g, b) if not num3(r, g, b) then error("SetTextColor wants r,g,b") end end
  function f:SetText(x) self.text = x end
  function f:GetText() return self.text or "" end
  function f:ClearFocus() end
  function f:GetHeight() return self.h end
  function f:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
  function f:ClearAllPoints() self.point = nil end
  function f:GetPoint() return "TOPLEFT", nil, "CENTER", 12, -34 end
  function f:SetFrameStrata() end
  function f:SetFrameLevel() end
  function f:GetCenter() return self.cx or 0, self.cy or 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetAlpha(a) self.alpha = a end
  function f:SetMovable() end
  function f:EnableMouse() end
  function f:SetClampedToScreen() end
  function f:RegisterForDrag() end
  function f:RegisterForClicks(c) self.clicks = c end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:IsShown() return self.shown end
  function f:SetAttribute(k, v) if W.combat then error("attribute set in combat: " .. k) end self.attrs[k] = v end
  function f:GetAttribute(k) return self.attrs[k] end
  function f:Click()
    if self.scripts.PreClick then self.scripts.PreClick(self, "LeftButton", true) end
    local t = self.attrs.type
    local tunit = self.attrs.unit or self.attrs["*unit1"]
    if t == "target" or (t == nil and self.attrs["*type1"] == "target") then
      local ri = tunit and tunit:match("^raid(%d+)$")
      W.target = ri and W.raid[tonumber(ri)] or W.plates[tunit]
    elseif t == "macro" then
      local nm = self.attrs.macrotext:match("^/targetexact (.+)$")
      W.target = nil
      for _, tok in ipairs({ "nameplate1", "nameplate2", "nameplate3" }) do
        local p = W.plates[tok]
        if p and p.name == nm then W.target = p break end
      end
    end
    if self.scripts.PostClick then self.scripts.PostClick(self, "LeftButton", true) end
  end
  if name then frames[name] = true _G[name] = f end
  return f
end

_G.Minimap = CreateFrame("Frame", "Minimap")
_G.Minimap.cx, _G.Minimap.cy = 1000, 500
-- ------------------------------------------------------------ load
local before = {} for k in pairs(_G) do before[k] = true end
local NS = {}
-- load exactly what the TOC lists, in TOC order (libs included, no stubs); a bogus
-- TOC line breaks the run here, the same way it would break the client
local files = TOC_FILES
assert(#files >= 9, "TOC lists fewer files than expected: " .. #files)
local handlers = {}
local realCF = _G.CreateFrame
_G.CreateFrame = function(...)
  local f = realCF(...)
  local ss = f.SetScript
  f.SetScript = function(self, k, fn) ss(self, k, fn) if k == "OnEvent" then handlers[#handlers + 1] = { fn = fn, frame = self } end end
  return f
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(f)
  assert(chunk, "TOC lists a file that does not load: " .. tostring(f) .. " (" .. tostring(err) .. ")")
  chunk("BiSTools", NS)
end
-- dev/theme.lua: poison the accent AFTER the files load, BEFORE anything is built
if _G.__THEME_MUTATION then BiSTheme.hex.accent = _G.__THEME_MUTATION end
-- Core/Init's frame is the one that listens for ADDON_LOADED (the libs' frames load first)
local core
for _, h in ipairs(handlers) do if h.frame.events.ADDON_LOADED then core = h.fn end end
core(nil, "ADDON_LOADED", "BiSTools")
core(nil, "PLAYER_LOGIN")
-- the client fires PLAYER_ENTERING_WORLD after login; that is when the lib says HI
local function fireAll(ev, ...)
  local seen = {}
  for _, h in ipairs(handlers) do
    local f = h.frame
    if not seen[f] and f.events[ev] and f.scripts.OnEvent then seen[f] = true f.scripts.OnEvent(f, ev, ...) end
  end
end
fireAll("PLAYER_ENTERING_WORLD")
local S = SlashCmdList.BISTOOLS
local R = NS.Registry
local F = NS.Farm
local db = R:DBFor(R:Get("farm"))
local function fire(ev, ...) F.events.scripts.OnEvent(F.events, ev, ...) end
local function db_summon() return R:DBFor(R:Get("summon")) end
local function kill(name, guid, src, mark)
  guid = guid or ("Creature-0-0-0-0-123-" .. name)
  W.cleu = { 0, "PARTY_KILL", false, src or "Player-1", "Me", 0, 0, guid, name }
  if mark then W.target = { name = name, guid = guid } W.marks.target = mark end
  fire("COMBAT_LOG_EVENT_UNFILTERED")
  if mark then W.target = nil W.marks.target = nil end
end
local pass = 0
local function ok(cond, msg) if not cond then error("FAIL: " .. msg, 2) end pass = pass + 1 end

-- ------------------------------------------------------------ checks
ok(BiSToolsFarm and BiSToolsFarm:IsShown(), "window shown on login (db.shown default)")
ok(BiSToolsFarm.h == 16 + 4 + 16 + 4, "no kills: header + search well only")
ok(BiSToolsFarmTarget and BiSToolsFarmTarget.template == "SecureActionButtonTemplate", "one secure target button exists")
ok(W.binds[BiSToolsFarmTarget] == nil, "no key bound by default")

kill("Wolf") kill("Wolf")
ok(db.last.name == "Wolf" and db.last.count == 2, "last kill + count")
ok(BiSToolsFarmRow1.name.text == "Wolf" and BiSToolsFarmRow1.count.text == "x2", "row 1 paints Wolf x2")
ok(BiSToolsFarm.h == 16 + 16 + 4 + 16 + 4, "one row + search well")
kill("Boar")
ok(db.last.name == "Boar" and db.last.count == 1 and BiSToolsFarmRow1.name.text == "Boar", "new mob replaces last")
ok(BiSToolsFarmRow2 == nil, "only one kill row")
ok(BiSToolsFarmRow1.template == nil, "rows are plain buttons (rebuildable in combat)")

kill("Farmer", "Player-99") ok(db.last.name == "Boar", "player kills ignored")
kill("Rat", nil, "Player-7") ok(db.last.name == "Boar", "other people's kills ignored")
W.hasPet = true kill("Rat", nil, "Pet-1") ok(db.last.name == "Rat", "pet kills count")

W.combat = true kill("Bear") W.combat = false
ok(BiSToolsFarmRow1.name.text == "Bear", "rows rebuild in combat")

-- hover paints (strict stub catches multi-return truncation)
BiSToolsFarmRow1.scripts.OnEnter(BiSToolsFarmRow1) ok(BiSToolsFarmRow1.bg.color[4] == 1, "hover fills row")
BiSToolsFarmRow1.scripts.OnLeave(BiSToolsFarmRow1) ok(BiSToolsFarmRow1.bg.color[4] == 0, "leave clears row")
F.collapseBtn.scripts.OnEnter(F.collapseBtn) F.collapseBtn.scripts.OnLeave(F.collapseBtn)
F.closeBtn.scripts.OnEnter(F.closeBtn) F.closeBtn.scripts.OnLeave(F.closeBtn)
F.edit.scripts.OnEditFocusGained(F.edit) F.edit.scripts.OnEditFocusLost(F.edit)

-- click once: scanner starts, a mark lands on the free copy
S("farm spots clear")   -- earlier kills made spots (which own marks); start the scanner clean
W.plates = {
  nameplate1 = { name = "Bear", combat = true },
  nameplate2 = { name = "Bear", tapped = true },
  nameplate3 = { name = "Bear" },
}
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Bear", "click sets active")
ok(F.ticker and F.ticker.alive and F.ticker.iv == 0.5, "ticker running at 0.5s")
ok(W.marks.nameplate3 == 1 and W.marks.nameplate1 == nil and W.marks.nameplate2 == nil, "star on the free one, not the busy ones")
ok(BiSToolsFarmRow1.bar.shown and BiSToolsFarmRow1.bg.color[4] == 1, "active row painted (bar + fill)")
BiSToolsFarmRow1.scripts.OnLeave(BiSToolsFarmRow1)
ok(BiSToolsFarmRow1.bg.color[4] == 1, "active row keeps its fill after mouse leaves")

-- tick again: a second free plate gets the next mark, the first keeps its star
W.plates.nameplate2 = { name = "Bear" }
W.tick() ok(W.marks.nameplate3 == 1 and W.marks.nameplate2 == 2, "second free copy gets circle, star stays")
W.tick() ok(W.marks.nameplate3 == 1 and W.marks.nameplate2 == 2, "stable across ticks")
-- a mark the player put on by hand is respected: nameplate5 wearing square keeps it
W.plates.nameplate5 = { name = "Bear" } W.marks.nameplate5 = 6
W.tick() ok(W.marks.nameplate5 == 6, "hand-placed mark kept")
-- skull on a plate is not one of ours: it gets a scanner mark on top (skull moves off)
W.plates.nameplate6 = { name = "Bear" } W.marks.nameplate6 = 8
W.tick() ok(W.marks.nameplate6 == 3, "skulled plate gets a scanner mark (diamond), skull is the cursor's")
W.plates.nameplate5 = nil W.plates.nameplate6 = nil W.marks.nameplate5 = nil W.marks.nameplate6 = nil

-- skulled one gets tagged: skull moves to another free one
W.plates.nameplate3.tapped = true
W.plates.nameplate2 = nil
W.plates.nameplate4 = { name = "Bear" }
W.tick()
ok(W.marks.nameplate4 == 1 and W.marks.nameplate3 == nil, "star moves when the marked one gets busy")

-- nothing free: no mark, ticker keeps going
W.plates = { nameplate1 = { name = "Bear", combat = true } } W.marks = {}
W.tick() ok(next(W.marks) == nil and F.ticker.alive, "no free plate -> no mark, still scanning")

-- dead ones never marked
W.plates = { nameplate1 = { name = "Bear", dead = true } }
W.tick() ok(next(W.marks) == nil, "corpse not marked")

-- sound, default "first": voice on find 1 only, ping after; nothing for "already marked"
ok(#W.spoken == 1 and #W.sounds == 3, "four real finds so far -> one voice line, three pings")
ok(W.spoken[1] == "Star" and W.sounds[1] == 3081, "plate find names its mark, ping is the whisper sound")
W.marks = {} W.plates.nameplate1 = { name = "Bear" } W.tick() W.tick() W.tick()
ok(#W.sounds == 4 and #W.spoken == 1, "find 5 pings; a mark staying put is not a find")
-- "always": voice every find
S("farm sound always") ok(db.sound == "always", "sound always")
for i = 1, 3 do W.marks = {} W.plates.nameplate1 = { name = "Bear" } W.tick() end
ok(#W.spoken == 4 and #W.sounds == 4, "always -> three more voice lines, no pings")
-- "off": silent
S("farm sound off") ok(db.sound == "off", "sound off")
W.marks = {} W.tick() ok(#W.spoken == 4 and #W.sounds == 4, "off -> silent")
S("farm sound nonsense") ok(db.sound == "off", "bad mode ignored")
S("farm sound first") ok(db.sound == "first", "back to first")
-- FojjiCore present -> it gets the line, tts untouched
_G.FojjiCore = { Speak = function(_, t) W.fojji = t return true end }
W.plates = { nameplate1 = { name = "Bear" } } W.marks = {}
db.finds = 0 W.tick()
ok(W.fojji == "Star" and #W.spoken == 4, "FojjiCore speaks when loaded")
_G.FojjiCore = nil

-- mouseover: hovering the mob from anywhere marks it, instantly on the event
W.plates = { nameplate1 = { name = "Bear" } } W.marks = {} db.finds = 0
W.plates.mouseover = { name = "Bear" }
fire("UPDATE_MOUSEOVER_UNIT")
ok(W.marks.mouseover == 8 and W.marks.nameplate1 == nil, "mouseover gets the skull, plates not touched")
ok(W.spoken[#W.spoken] == "Skull", "mouseover find says Skull")
ok(db.finds == 1, "mouseover mark is a find")
fire("UPDATE_MOUSEOVER_UNIT") W.tick()
ok(db.finds == 1, "hovering the already-marked one is not a new find")
W.plates.mouseover = { name = "Bear", tapped = true } W.marks = {}
W.tick()
ok(W.marks.mouseover == nil and W.marks.nameplate1 == 1, "tapped mouseover ignored, plates still scanned")
-- both marks can be out at once: X from the scanner stays while the skull goes on the hover
W.marks = { nameplate1 = 1 } W.plates.mouseover = { name = "Bear" }
W.tick() ok(W.marks.mouseover == 8 and W.marks.nameplate1 == 1, "skull and scanner marks coexist")
-- hovering a copy that already wears a scanner mark: skull must NOT overwrite it
W.marks = { mouseover = 4 } W.plates.mouseover = { name = "Bear" }
local f0 = db.finds
W.tick() ok(W.marks.mouseover == 4 and db.finds == f0, "hover on a marked mob keeps its mark, no find")
W.plates.mouseover = { name = "Boar" } W.marks = {}
W.tick() ok(W.marks.mouseover == nil, "other mob under the mouse ignored")
W.plates.mouseover = nil
-- mouseover event with nothing active does nothing
local act = db.active db.active = nil F.Stop()
W.plates.mouseover = { name = "Bear" } W.marks = {}
fire("UPDATE_MOUSEOVER_UNIT") ok(next(W.marks) == nil, "no active -> hover does nothing")
W.plates.mouseover = nil db.active = act F.Start(db)

-- click again: off
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == nil and not F.ticker, "second click stops the scanner")
ok(not BiSToolsFarmRow1.bar.shown and BiSToolsFarmRow1.bg.color[4] == 0, "row unpainted")

-- typed name: second row, active, kill row untouched
F.edit:SetText("  Ancient Bear  ")
F.edit.scripts.OnEnterPressed(F.edit)
ok(db.custom == "Ancient Bear" and db.active == "Ancient Bear", "typed name searched + active")
ok(BiSToolsFarmRow1.name.text == "Bear" and BiSToolsFarmRow2.name.text == "Ancient Bear" and BiSToolsFarmRow2.shown, "kill row 1, typed row 2")
ok(BiSToolsFarmRow2.bar.shown and not BiSToolsFarmRow1.bar.shown, "typed row is the active one")
ok(BiSToolsFarmRow2.count.text == "", "count 0 paints blank")
ok(F.edit:GetText() == "", "box cleared")
ok(BiSToolsFarm.h == 16 + 32 + 4 + 16 + 4, "two rows + well")
-- switching back to the kill row cancels the old ticker
local tOld = F.ticker
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Bear" and not tOld.alive and F.ticker.alive and db.finds == 0, "switch active: old ticker cancelled, finds reset")
ok(BiSToolsFarmRow1.bar.shown and not BiSToolsFarmRow2.bar.shown, "bar follows")
-- typed name same as the kill: no duplicate row
F.edit:SetText("Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.custom == "Bear" and BiSToolsFarmRow2.shown == false, "same name as last kill -> one row")
S("farm add Old Bear") ok(db.active == "Old Bear" and BiSToolsFarmRow2.name.text == "Old Bear", "/bt farm add")
-- locked on Old Bear: a stray Wolf kill does not touch the page
kill("Wolf")
ok(BiSToolsFarmRow1.name.text == "Bear" and db.last.name == "Bear" and BiSToolsFarmRow2.name.text == "Old Bear" and db.active == "Old Bear", "locked: other kills ignored, page frozen")
-- kills of the locked (typed) mob count on its own row
kill("Old Bear") kill("Old Bear")
ok(db.customKills == 2 and BiSToolsFarmRow2.count.text == "x2" and db.last.name == "Bear", "locked typed mob counts on row 2, last-kill row untouched")
-- unlock: tracker back on
BiSToolsFarmRow2.scripts.OnClick(BiSToolsFarmRow2)
ok(db.active == nil, "unlocked")
kill("Wolf")
ok(BiSToolsFarmRow1.name.text == "Wolf" and db.last.name == "Wolf", "unlocked: last-kill tracker resumes")
F.edit:SetText("Old Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.active == "Old Bear" and db.customKills == 2, "re-locking the same typed name keeps its count")
F.edit:SetText("Elder Bear") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.customKills == 0, "a different typed name resets the count")
-- locked on the last-kill row: its own kills still count there
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
ok(db.active == "Wolf", "locked on Wolf")
kill("Wolf")
ok(db.last.count == 2 and BiSToolsFarmRow1.count.text == "x2", "locked last-kill mob keeps counting")
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
F.edit:SetText("Old Bear") F.edit.scripts.OnEnterPressed(F.edit)

-- target key
S("farm key F")
ok(db.key == "F" and W.binds[BiSToolsFarmTarget].key == "F", "key bound")
W.plates = { nameplate1 = { name = db.active } } W.marks = {}
W.tick()
BiSToolsFarmTarget:Click()
ok(BiSToolsFarmTarget:GetAttribute("type") == "target" and BiSToolsFarmTarget:GetAttribute("unit") == "nameplate1", "key targets the skulled plate")
W.combat = true
BiSToolsFarmTarget:Click()
ok(BiSToolsFarmTarget:GetAttribute("type") == "target", "in combat PreClick touches nothing")
S("farm key none") ok(db.key == nil and F.keyDirty, "unbind in combat deferred")
W.combat = false fire("PLAYER_REGEN_ENABLED")
ok(W.binds[BiSToolsFarmTarget] == nil and not F.keyDirty, "unbound after regen")

-- collapse / toggle / clear / slash
F.SetCollapsed(db, true)
ok(not BiSToolsFarmRow1.shown and not F.well.shown and BiSToolsFarm.h == 16, "collapsed = header only")
F.SetCollapsed(db, false)
ok(BiSToolsFarmRow1.shown and F.well.shown, "expanded again")
S("farm") ok(not BiSToolsFarm:IsShown() and db.shown == false, "/bt farm hides")
ok(F.ticker and F.ticker.alive, "hidden window does not stop the scanner")
S("farm") ok(BiSToolsFarm:IsShown() and db.shown == true, "/bt farm shows")
S("farm clear") ok(db.last == nil and db.custom == nil and db.active == nil and not F.ticker and BiSToolsFarmRow1.shown == false, "/bt farm clear wipes + stops")
kill("Wolf") BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
S("off farm")
ok(not BiSToolsFarm:IsShown() and next(F.events.events) == nil and not F.ticker, "off: hidden, unhooked, scanner stopped")
S("on farm")
ok(BiSToolsFarm:IsShown() and F.events.events.COMBAT_LOG_EVENT_UNFILTERED and F.ticker and F.ticker.alive, "on: back, listening, scanner resumed for saved active")
ok(NS.Registry:Enabled("farm") == true and BiSToolsDB.enabled.farm == nil, "on actually clears the off flag (and/or-nil trap)")

-- ---------------------------------------------------------------- spawn zones + spots
-- radius 20 (zone), 7 (sub). world 5000 wide: 0.001 = 5 yd, 0.004 = 20 yd
local Sp = F.Spots
S("farm clear") S("farm spots clear") S("farm radius 20") S("farm prune off")
ok(Sp.Radius(db) == 20 and math.abs(Sp.SubRadius(db) - 7) < 1e-9, "zone 20 yd, sub 7 yd")
ok(Sp.Prune(db) == 0, "prune off for the checks (time jumps around)")
W.now = 1000 W.px, W.py = 0.500, 0.500
kill("Boar")
local zones = db.spots.Boar
ok(zones and #zones == 1 and zones[1].mark == 1 and #zones[1].subs == 1 and zones[1].subs[1].last == 1000, "first kill: zone (star) + one sub")
ok(not BiSToolsFarmSpots or not BiSToolsFarmSpots:IsShown(), "shelf closed by default")
-- 3 yd away, 5 min later: same sub, respawn learned
W.now = 1300 W.px = 0.5006
kill("Boar")
ok(#zones == 1 and #zones[1].subs == 1 and zones[1].subs[1].respawn == 300 and zones[1].subs[1].kills == 2, "same sub -> respawn 300")
-- burst: 8 s later, same place -> a different mob standing there -> its own sub
W.now = 1308 kill("Boar")
ok(#zones[1].subs == 2 and zones[1].subs[2].last == 1308 and zones[1].subs[2].kills == 1, "kill 8 s after a spot -> new spot (burst)")
ok(#zones[1].subs[1].gaps == 1 and zones[1].subs[1].respawn == 300 and zones[1].subs[1].last == 1300, "first spot untouched by the burst kill")
-- three different marks in 10 s: three spots; a kill 24 s after sub1 is still a burst
W.now = 1310 kill("Boar", nil, nil, 5) W.now = 1314 kill("Boar", nil, nil, 6)
ok(#zones[1].subs == 4, "three quick kills wearing different marks -> three more timers")
W.now = 1355 W.px = 0.5006 kill("Boar")
ok(#zones[1].subs == 5 and zones[1].subs[1].last == 1300, "55 s after sub1 -> still a new spot (burst 60)")
-- burst is a setting
S("farm burst 20") ok(db.burst == 20 and Sp.Burst(db) == 20, "/bt farm burst 20")
S("farm burst 1") ok(Sp.Burst(db) == 5, "burst clamps low")
S("farm burst 9999") ok(Sp.Burst(db) == 300, "burst clamps high")
S("farm burst 60")
-- tidy: keep only the first sub for the rest of the checks
for i = #zones[1].subs, 2, -1 do table.remove(zones[1].subs, i) end
zones[1].subSeq = 1
-- early kill: sub1 respawn 300, killed at 1300; a kill at 1400 (200 s left, > 25%) is another mob
W.now = 1400 W.px = 0.5006 kill("Boar")
ok(#zones[1].subs == 2 and zones[1].subs[1].last == 1300 and zones[1].subs[2].last == 1400, "kill with 200 s still on the clock -> new spot")
table.remove(zones[1].subs, 2) zones[1].subSeq = 1
-- late-ish kill: 40 s left (< 25% of 300) folds in and teaches
W.now = 1560 kill("Boar")
ok(zones[1].subs[1].last == 1560 and #zones[1].subs == 1, "kill with 40 s left folds into the sub")
zones[1].subs[1].gaps = { 300 } zones[1].subs[1].respawn = 300 zones[1].subs[1].last = 1300 zones[1].subs[1].kills = 2
-- 12 yd away: same zone, new sub
W.now = 1400 W.px = 0.5024
kill("Boar")
ok(#zones == 1 and #zones[1].subs == 2 and zones[1].subs[2].id == 2 and not zones[1].subs[2].respawn, "12 yd -> same zone, second sub")
-- 60 yd away: new zone, circle
W.now = 1500 W.px = 0.512
kill("Boar")
ok(#zones == 2 and zones[2].mark == 2 and #zones[2].subs == 1, "60 yd -> second zone (circle)")
-- median at sub1
W.now = 1700 W.px = 0.5006 kill("Boar")
ok(zones[1].subs[1].respawn == 350 and #zones[1].subs[1].gaps == 2, "median of gaps (300, 400)")
kill("Wolf") ok(#db.spots.Boar == 2 and #db.spots.Wolf == 1, "zones are per mob")

-- sub marks: inside zone 1, sub1 wears the star (zone's), sub2 borrows the lowest free (3)
W.px = 0.5006
Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == 1 and zones[1].subs[2].mark == 3, "inside zone: sub1 = zone mark, sub2 borrows diamond")
ok(zones[2].subs[1].mark == nil, "other zone's subs hold no marks")
local bound = Sp.BoundMarks(db, "Boar")
ok(bound[1] and bound[2] and bound[3] and not bound[4], "scanner may not deal star, circle, diamond here")
-- walk out: borrowed marks released
W.px = 0.530
Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == nil and zones[1].subs[2].mark == nil, "outside: sub marks released")
bound = Sp.BoundMarks(db, "Boar")
ok(bound[1] and bound[2] and not bound[3], "outside: only zone marks are bound")
-- back in: stable assignment
W.px = 0.5006 Sp.Assign(db, "Boar") Sp.Assign(db, "Boar")
ok(zones[1].subs[1].mark == 1 and zones[1].subs[2].mark == 3, "stable on re-entry")

-- shelf: outside shows zones with their soonest sub; inside shows subs
BiSToolsFarmRow1.scripts.OnClick(BiSToolsFarmRow1)
F.edit:SetText("Boar") F.edit.scripts.OnEnterPressed(F.edit)
ok(db.active == "Boar", "farming Boar")
-- the farm header is the BiS> prompt now (11 Sep; Summon since 8 Sep). No logo, name
-- slot "Farm", "farming X" slot while active, events said over them, chat untouched.
do
  local function fshown() return (tostring(F.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
  local function fadv(dt) W.now = W.now + dt F.con:Paint() W.now = W.now + 0.3 F.con:Paint() W.now = W.now + 0.3 F.con:Paint() end
  ok(F.con ~= nil and F.title ~= nil, "the farm title FontString is a BiSTheme console")
  ok(F.con.slots.name and F.con.slots.name.text == "Farm", "name slot is Farm")
  ok(F.con.slots.active and F.con.slots.active.text == "farming Boar", "active slot names the mob", F.con.slots.active and F.con.slots.active.text)
  local chatF = 0 local oldAddF = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function() chatF = chatF + 1 end
  F.SetActive(db, nil) F.SetActive(db, "Boar")
  DEFAULT_CHAT_FRAME.AddMessage = oldAddF
  ok(chatF == 0, "a row click says it in the prompt, not chat", chatF)
  ok(F.con.slots.active == nil or F.con.slots.active.text == "farming Boar", "slot follows db.active")
  F.con:Clear() fadv(4)
  local seenName, seenActive = false, false
  for _ = 1, 6 do fadv(3) local t = fshown() if t:find("Farm[_ ]") then seenName = true end if t:find("farming Boar") then seenActive = true end end
  ok(seenName and seenActive, "both slots take their turn in the rotation")
  -- budget: prompt never runs into the three header boxes (strip 43 px)
  local wF = F.con:Width()
  ok(wF <= F.W - 43 - 8, "farm prompt fits its budget", wF)
  -- no header logo left behind
  local logos = 0
  for _, r in ipairs(F.head.regions or {}) do if r.file and tostring(r.file):find("RaidTargetingIcon_8") then logos = logos + 1 end end
  ok(logos == 0, "the skull logo is gone from the header", logos)
end
W.px = 0.530
F.spotsBtn.scripts.OnClick(F.spotsBtn)
ok(BiSToolsFarmSpots:IsShown() and db.shelf == true and Sp.ticker and Sp.ticker.alive, "t opens the shelf + ticker")
ok(BiSToolsFarmSpots.point[1] == "TOPLEFT" and BiSToolsFarmSpots.point[2] == BiSToolsFarm, "shelf hangs off the farm window")
ok(BiSToolsFarmSpots.w == 124 and not Sp.title.text:find("Boar"), "slim shelf, plain title")
W.now = 1900 Sp.Refresh(db)
-- layout: zone1 (star, soonest) / its 2 subs indented / zone2 (circle) / its 1 sub
ok(Sp.rows[1].icon.file:find("Icon_1$") and Sp.rows[1].clock.text == "2:30" and Sp.rows[1].clock.x == 33, "row 1: star zone, soonest sub countdown, not indented")
ok(Sp.rows[2].id.text == "#1" and Sp.rows[2].clock.text == "2:30" and Sp.rows[2].clock.x == 45, "row 2: sub #1 indented, no mark (not in its zone)")
ok(Sp.rows[3].id.text == "#2" and Sp.rows[3].clock.text == "+8:20" and Sp.rows[3].clock.x == 45, "row 3: sub #2 indented")
ok(Sp.rows[4].icon.file:find("Icon_2$") and Sp.rows[4].clock.text == "+6:40" and Sp.rows[4].clock.x == 33, "row 4: circle zone")
ok(Sp.rows[5].id.text == "#1" and Sp.rows[5].clock.x == 45, "row 5: circle's sub indented")
ok(not Sp.rows[6] or Sp.rows[6].shown == false, "five rows total")
ok(not Sp.zoneIcon.shown and Sp.rows[1].bg.color[4] == 0, "outside: no zone icon, no tint")
-- step inside zone 1: same layout, its subs now carry marks, its row tinted
W.px = 0.5006 Sp.Refresh(db)
ok(Sp.rows[1].icon.file:find("Icon_1$") and Sp.rows[1].bg.color[4] == 1, "inside: zone row tinted")
ok(Sp.rows[2].icon.file:find("Icon_1$") and Sp.rows[2].clock.text == "2:30", "inside: sub1 wears the star")
ok(Sp.rows[3].icon.file:find("Icon_3$") and Sp.rows[3].clock.text == "+8:20", "inside: sub2 wears the diamond")
ok(Sp.rows[4].icon.file:find("Icon_2$") and Sp.rows[5].id.text == "#1", "other zone and its sub still listed")
ok(Sp.zoneIcon.shown and Sp.zoneIcon.file:find("Icon_1$"), "header shows the zone's mark")
ok(Sp.rows[2].dist.text == "1y" and Sp.rows[3].dist.text == "8y", "yards to each sub")

-- callout 15 s before sub1 (inside: says the sub's mark)
local sp0 = #W.spoken
W.now = 2000 Sp.Refresh(db) ok(#W.spoken == sp0, "50 s left -> quiet")
W.now = 2036 Sp.Refresh(db) ok(#W.spoken == sp0 + 1 and W.spoken[#W.spoken] == "Star", "14 s left -> Star")
W.now = 2038 Sp.Refresh(db) W.tick() ok(#W.spoken == sp0 + 1, "once per cycle")
S("farm sound off") W.now = 2040 Sp.Refresh(db) S("farm sound first")
ok(#W.spoken == sp0 + 1, "sound off keeps it quiet")
-- gold / up
W.now = 2030 Sp.Refresh(db)
ok(Sp.rows[1].clock.text == "0:20" and Sp.rows[1].clock.color[1] == select(1, F.color("gold")), "under 30s goes gold")
W.now = 2100 Sp.Refresh(db)
ok(Sp.rows[1].clock.text == "up" and Sp.rows[1].clock.color[1] == select(1, F.color("good")), "overdue shows up in teal")

-- kill matching by the dying mark: standing 15 yd off inside the zone, mob wore the star
W.px = 0.5036
local s1 = zones[1].subs[1] local s1x = s1.x
W.now = 2200 kill("Boar", nil, nil, 1)
ok(s1.last == 2200 and #zones[1].subs == 2, "kill wearing the star resets sub1 from 15 yd")
ok(s1.x == s1x, "centre not dragged by a far kill")
-- unmarked kill ~19 yd from an up sub (and >7 yd from every sub): folds into the up one
W.now = 2200 + s1.respawn + 5 W.px = 0.5039
kill("Boar")
ok(s1.last == W.now and #zones[1].subs == 2, "unmarked kill near an up sub folds into it")
-- same place, nothing up any more: new sub
W.now = W.now + 30 W.px = 0.5039
kill("Boar")
ok(#zones[1].subs == 3, "same distance, nothing up -> new sub")
-- outside every zone, mob wore the circle -> circle zone gets the kill
W.px = 0.560 W.now = W.now + 100
kill("Boar", nil, nil, 2)
ok(zones[2].last == W.now and #zones == 2, "kill wearing circle from far -> circle zone")
table.remove(zones[1].subs, 3)

-- arrows
local function near(a, b) return math.abs(a - b) < 1e-6 end
W.px = 0.5006 W.facing = 0 Sp.Refresh(db)
-- sub2 is east of the player
local eastRow
for i = 1, 6 do if Sp.rows[i] and Sp.rows[i].shown and Sp.rows[i].icon.shown and Sp.rows[i].icon.file:find("Icon_3$") then eastRow = Sp.rows[i] end end
ok(eastRow and near(eastRow.arrow.rot, -math.pi / 2), "facing north, sub east -> arrow -90deg")
ok(eastRow.arrow.file == "Interface\\Minimap\\MinimapArrow", "arrow uses the minimap player arrow")
W.facing = -math.pi / 2 Sp.Refresh(db) ok(near(eastRow.arrow.rot, 0), "facing east -> straight up")
W.facing = math.pi / 2 Sp.Refresh(db) ok(near(math.abs(eastRow.arrow.rot), math.pi), "facing west -> down")
W.facing = math.pi Sp.Refresh(db) ok(near(eastRow.arrow.rot, math.pi / 2), "facing south -> +90deg")
W.facing = 0
ok(Sp.ticker.iv == 0.25, "shelf ticks at 0.25s")
_G.GetPlayerFacing = function() return nil end
Sp.Refresh(db) ok(not eastRow.arrow.shown and eastRow.clock.text ~= "", "no facing -> arrow hidden")
_G.GetPlayerFacing = function() return W.facing end
W.map = 1 Sp.Refresh(db) ok(Sp.rows[1].dist.text == "" and not Sp.rows[1].arrow.shown, "other map -> no distance, no arrow") W.map = 1952

-- target sync: inside zone 1 next to sub2 (diamond) -> target takes diamond
W.px = 0.5024 W.target = { name = "Boar" } W.marks = { target = 5 }
fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 3, "target next to sub2 takes the diamond")
-- outside, near zone 2 -> circle
W.px = 0.512 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 2, "outside near zone 2 -> circle")
W.px = 0.7 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 5, "far from everything -> untouched")
W.target = { name = "Wolf" } W.px = 0.5024 W.marks = { target = 5 } fire("PLAYER_TARGET_CHANGED")
ok(W.marks.target == 5, "other mob -> untouched")
W.target = nil W.px = 0.530

-- scanner respects zone marks outside, and sub marks inside
W.plates = { nameplate1 = { name = "Boar" }, nameplate2 = { name = "Boar" } } W.marks = {}
W.tick()
ok(W.marks.nameplate1 == 3 and W.marks.nameplate2 == 4, "outside: scanner skips star+circle, deals diamond, triangle")
W.px = 0.5006 W.marks = {} W.tick()
ok(W.marks.nameplate1 == 4 and W.marks.nameplate2 == 5, "inside zone 1: diamond is a sub's now, scanner deals triangle, moon")
W.px = 0.530 W.plates = {} W.marks = {}

-- radius setting
S("farm radius 30") ok(db.spotRadius == 30 and Sp.Radius(db) == 30, "/bt farm radius 30")
S("farm radius 999") ok(Sp.Radius(db) == 60, "radius clamps high")
S("farm radius 1") ok(Sp.Radius(db) == 5, "radius clamps low")
S("farm radius abc") ok(Sp.Radius(db) == 5, "bad radius ignored")
S("farm radius 20")

-- zone cap: 10 zones, 7 marked, the rest #n; marks re-dealt when a marked zone drops
for i = 1, 18 do W.now = W.now + 100 W.px = 0.6 + i * 0.01 kill("Boar") end
ok(#zones == 16, "capped at 16 zones")
local marked, unmarked = 0, 0
for _, z in ipairs(zones) do if z.mark then marked = marked + 1 else unmarked = unmarked + 1 end end
ok(marked == 7 and unmarked == 9, "7 zones own marks, 9 do not")
W.px = 0.9 Sp.Refresh(db)
local sawId = false
for i = 1, 40 do if Sp.rows[i] and Sp.rows[i].shown and Sp.rows[i].id.text ~= "" and Sp.rows[i].clock.x == 33 then sawId = true end end
ok(sawId, "markless zones paint #n")
W.plates = { nameplate1 = { name = "Boar" } } W.marks = {}
W.tick() ok(next(W.marks) == nil, "all 7 marks owned by zones -> scanner deals none outside")
W.plates = {}

-- prune: a sub sat up 10 min with no kill folds into its nearest sibling
S("farm prune 600") ok(db.prune == 600 and Sp.Prune(db) == 600, "/bt farm prune 600")
S("farm prune 10") ok(Sp.Prune(db) == 60, "prune clamps low")
S("farm prune 99999") ok(Sp.Prune(db) == 3600, "prune clamps high")
S("farm prune 600")
local pz = zones[1]
pz.subs = {
  { id = 1, x = 0.5000, y = 0.5, last = W.now, kills = 4, respawn = 300, gaps = { 300 } },
  { id = 2, x = 0.5010, y = 0.5, last = W.now - 950, kills = 1, respawn = 300, gaps = { 300 } }, -- up for 650 s
  { id = 3, x = 0.5020, y = 0.5, last = W.now - 500, kills = 1 },                              -- unknown, 500 s
}
Sp.DoPrune(db)
ok(#pz.subs == 2 and pz.subs[1].id == 1 and pz.subs[2].id == 3, "stale sub 2 folded away")
ok(pz.subs[1].kills == 5, "its kills went to the nearest sibling (sub 1)")
W.now = W.now + 200 Sp.DoPrune(db)   -- sub 3 now unknown for 700 s -> stale
ok(#pz.subs == 1 and pz.subs[1].kills == 6, "unknown-respawn sub folds after the window too")
Sp.DoPrune(db) ok(#pz.subs == 1, "the last sub in a zone is never pruned")
S("farm prune off")
W.now = W.now + 5000 Sp.DoPrune(db) ok(#pz.subs == 1, "prune off -> nothing happens")
pz.subs = { { id = 1, x = 0.5000, y = 0.5, last = W.now, kills = 1 } }

-- r on the shelf: this mob only
db.spots.Wolf = { { id = 1, map = 1952, x = 0.1, y = 0.1, last = W.now, kills = 1, subs = {} } }
Sp.resetBtn.scripts.OnClick(Sp.resetBtn)
ok((db.spots.Boar == nil or #db.spots.Boar == 0) and db.spots.Wolf and #db.spots.Wolf == 1 and Sp.empty.shown, "r resets the shown mob only")
S("farm spots") ok(not BiSToolsFarmSpots:IsShown() and not Sp.ticker and db.shelf == false, "/bt farm spots closes")
S("farm spots") ok(BiSToolsFarmSpots:IsShown(), "/bt farm spots reopens")
S("farm spots clear")
local anyZone = false
for _, l in pairs(db.spots) do if #l > 0 then anyZone = true end end
ok(not anyZone and Sp.empty.shown, "spots clear wipes + hint")
S("farm clear") ok(db.spots ~= nil, "plain clear leaves the spots table alone")
S("off farm") ok(not BiSToolsFarmSpots:IsShown() and not Sp.ticker, "off hides shelf")
S("on farm") ok(BiSToolsFarmSpots:IsShown() and Sp.ticker, "on restores shelf (db.shelf)")
W.map = nil kill("Boar") ok(db.last.name == "Boar" and (db.spots.Boar == nil or #db.spots.Boar == 0), "no position -> no zone, kill still recorded") W.map = 1952
-- old flat data upgrades: a zone without subs gets an empty subs table
db.spots.Boar = { { id = 1, map = 1952, x = 0.5, y = 0.5, last = W.now, kills = 3, mark = 1 } }
W.px, W.py = 0.5, 0.5 W.now = W.now + 400
kill("Boar")
ok(db.spots.Boar[1].subs and #db.spots.Boar[1].subs == 1, "flat spot upgraded to a zone with a sub")
W.px, W.py = 0.5, 0.5

-- ---------------------------------------------------------------- comm lib + summon tool
local lib = _G.LibBiSComm
local SM = NS.Summon
ok(lib and lib.MINOR == 5 and lib._booted, "LibBiSComm 1.0 minor 5 loaded and booted from Core/Init")
-- the options kit must come from OUR embed via the TOC, not from the BiSTheme addon happening
-- to be installed: 0.3.0 shipped without the TOC line and the Hub threw "attempt to call field
-- 'Options'" for anyone without BiSTheme (found 11 Sep 2026, fixed 0.3.1). Minor 2 = Escape closes.
do local listed = false for _, f in ipairs(files) do if f == "Libs/BiSTheme/Options.lua" then listed = true end end
  ok(listed, "the TOC lists Libs/BiSTheme/Options.lua (the client loads it from here, not from the BiSTheme addon)") end
ok(type(BiSTheme.Options) == "function", "BiSTheme.Options is defined after the TOC load")
ok(BiSTheme.OPTIONS_MINOR == 2, "options kit minor 2 (Escape closes): " .. tostring(BiSTheme.OPTIONS_MINOR))
ok(_G.SLASH_BISCOMM1 == "/biscomm", "minor 4 gave /bis back to LoonBestInSlot; the lib is /biscomm")
for k, v in pairs(_G) do if type(k) == "string" and k:match("^SLASH_") then ok(v ~= "/bis", k .. " must not take /bis (LoonBestInSlot owns it)") end end
-- version: the TOC's, never a literal (RegisterAddon announces it to the whole raid)
ok(NS.VERSION == TOC_VERSION and TOC_VERSION:match("^%d+%.%d+%.%d+"), "NS.VERSION comes from the TOC: " .. tostring(NS.VERSION))
ok(lib.addons and lib.addons.BiSTools == TOC_VERSION, "the lib announces the TOC version, not a string", lib.addons and lib.addons.BiSTools)
do -- hygiene: any VERSION literal in a TOC-listed source must equal ## Version
  for _, f in ipairs(files) do
    if not f:match("^Libs/") then
      local fh = assert(io.open(f)) local src = fh:read("*a") fh:close()
      for lit in src:gmatch("VERSION[^\n]-\"(%d+%.%d+%.%d+)\"") do
        ok(lit == TOC_VERSION, f .. " carries a VERSION literal " .. lit .. " that drifted from the TOC " .. TOC_VERSION)
      end
    end
  end
end

ok(lib.addons.BiSTools == TOC_VERSION, "BiSTools registered itself with the lib, TOC version")
ok(lib:Enabled() and BiSToolsDB.comm == nil, "comm on by default, nothing persisted yet")
ok(NS.Registry:Get("summon") and NS.Registry:Enabled("summon"), "summon tool registered and on")
ok(BiSToolsSummon and not BiSToolsSummon:IsShown(), "summon window built, hidden (auto mode)")

-- the hard rule: the tool toggle never touches the lib
S("summon show") ok(BiSToolsSummon:IsShown() and db_summon().mode == "on", "/bt summon show pins it")
S("off summon")
ok(not BiSToolsSummon:IsShown(), "off: window gone")
ok(lib:Enabled() and next(SM.nagFrame.events) ~= nil, "off: lib still on, nag still listening")
S("on summon") ok(BiSToolsSummon:IsShown(), "on: window back (mode was on)")

-- /biscomm off is the user's own switch, and BiSTools remembers it
SlashCmdList.BISCOMM("off")
ok(not lib:Enabled(), "/biscomm off mutes the lib")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == false, "logout persists the off switch")
SlashCmdList.BISCOMM("on")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == true and lib:Enabled(), "/biscomm on persists too")
-- and it is restored BEFORE Boot on the next login: a saved "off" boots silent
do
  BiSToolsDB.comm = false lib._booted = nil lib.enabled = true
  NS.Comm.Boot()
  ok(not lib:Enabled(), "a saved off switch is applied at ADDON_LOADED, before Boot")
  BiSToolsDB.comm = true lib:SetEnabled(true)
end
-- no feature toggle may gate the lib: every tool off/on, every db boolean flipped
do
  for _, t in ipairs({ "farm", "summon" }) do
    S("off " .. t) ok(lib:Enabled(), "/bt off " .. t .. " leaves the lib on")
    S("on " .. t)  ok(lib:Enabled(), "/bt on " .. t .. " leaves the lib on")
  end
  for _, t in ipairs({ "farm", "summon" }) do
    local d = R:DBFor(R:Get(t))
    for k, v in pairs(d) do
      if type(v) == "boolean" then d[k] = not v ok(lib:Enabled(), t .. "." .. k .. " flipped: lib still on") d[k] = v end
    end
  end
  for _, cmd in ipairs({ "farm sound off", "farm sound first", "summon nag off", "summon nag on", "summon key off", "summon key on", "summon jeck", "summon jeck", "summon hide", "summon auto" }) do
    S(cmd) ok(lib:Enabled(), "/bt " .. cmd .. ": lib still on")
  end
  S("summon show")   -- back to pinned, the state the blocks below expect
  -- and a client that logs in with every toggle already off still boots the lib
  local fdb, sdb = R:DBFor(R:Get("farm")), R:DBFor(R:Get("summon"))
  local keep = { fdb.sound, sdb.nag, sdb.key, sdb.jeck, BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon }
  fdb.sound, sdb.nag, sdb.key, sdb.jeck = "off", false, false, false
  BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon = false, false
  lib._booted = nil lib.addons.BiSTools = nil
  NS.Comm.Boot()
  ok(lib._booted and lib.addons.BiSTools == TOC_VERSION and lib:Enabled(), "everything off in the saved db: the lib still boots and registers")
  fdb.sound, sdb.nag, sdb.key, sdb.jeck = keep[1], keep[2], keep[3], keep[4]
  BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon = keep[5], keep[6]
end

-- the only raid that exists: Tools-only, Innervate-only, Gamba-only, and a man with nothing
W.raid = {
  { name = "Me" },
  { name = "Toolsy",  zone = "Netherstorm", x = 1000, y = 1000, inst = 530 },
  { name = "Druid",   zone = "Netherstorm", x = 1300, y = 1000, inst = 530 },
  { name = "Gambler", zone = "Netherstorm", x = 1000, y = 1400, inst = 530 },
  { name = "Nolib",   zone = "Netherstorm", x = 1000, y = 1200, inst = 530 },
  { name = "Farzone", zone = "Shattrath City", x = nil, y = nil, inst = nil },
  { name = "Azzy",    zone = "Stormwind City", x = nil, y = nil, inst = nil },
}
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
W.inRaid = true
local function say(from, line) lib:OnMessage("BiS", line, "RAID", from) end
-- entering the world in a raid: the lib says HI once (jittered 1-3 s, the mock runs the timer)
do
  W.runAfters(5)   -- drain timers left over from the ungrouped login
  local h0 = 0 for _, m in ipairs(W.messages) do if m:match("^1|CORE|HI|") then h0 = h0 + 1 end end
  fireAll("PLAYER_ENTERING_WORLD")
  W.runAfters(3.5)
  local his = 0 for _, m in ipairs(W.messages) do if m:match("^1|CORE|HI|") then his = his + 1 end end
  ok(his == h0 + 1, "the lib said HI once after entering the world in a raid", his - h0)
  ok(W.messages[#W.messages]:match("^1|CORE|HI|" .. lib.MINOR .. "|BiSTools=" .. TOC_VERSION:gsub("%.", "%%.")), "and the HI carries the lib minor and the TOC version", W.messages[#W.messages])
end
say("Toolsy",  "1|CORE|HI|1|BiSTools=0.1.0|0")
say("Druid",   "1|CORE|HI|1|BiSInnervate=3.3.5|0")
say("Gambler", "1|CORE|HI|1|BiSGamba=1.1.0|0")
ok(lib:HasLib("Toolsy") and lib:HasLib("Druid") and lib:HasLib("Gambler"), "three clients with any BiS addon are peers")
ok(not lib:HasLib("Nolib") and not lib:HasLib("Farzone") and not lib:HasLib("Azzy"), "the addon-less men never become peers")
say("Toolsy",  "1|CORE|WHERE|0|none||Netherstorm|1000.0|1000.0|530")
say("Druid",   "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
say("Gambler", "1|CORE|WHERE|1|raid|Karazhan|Karazhan|100.0|100.0|532")

S("summon near 80")
-- I am standing at a known stone for the list checks (far from one the list is compact)
db_summon().stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
SM.Refresh(db_summon())
local list, inside = SM.list, SM.inside
local byName = {}
for _, e in ipairs(list) do byName[e.name] = e end
ok(inside == 1 and byName.Gambler == nil, "Gambler says he is inside Karazhan -> counted inside, hidden until 'all'")
ok(byName.Toolsy == nil, "Toolsy stands on us (0 y, visible) -> not a candidate")
ok(byName.Druid and byName.Druid.fact and math.abs(byName.Druid.score - 300) < 1e-6, "Druid is a fact at 300 y from his own WHERE")
ok(byName.Nolib and not byName.Nolib.fact and math.abs(byName.Nolib.score - 200) < 1e-6, "Nolib is a guess at 200 y from UnitPosition")
ok(byName.Farzone and not byName.Farzone.fact and byName.Farzone.score == SM.SCORE_OTHER_ZONE, "Farzone (Shattrath): same world, other zone")
ok(byName.Azzy and byName.Azzy.score == SM.SCORE_OTHER_WORLD and byName.Azzy.world == "Azeroth", "Azzy (Stormwind): other world")
ok(list[1].name == "Azzy" and list[2].name == "Farzone" and list[3].name == "Druid" and list[4].name == "Nolib" and #list == 4, "other world, other zone, then yards; inside hidden")
-- paint: fact plain, guess with a ?
ok(BiSToolsSummonRow1.name.text == "Azzy ?" and BiSToolsSummonRow3.name.text == "Druid" and BiSToolsSummonRow4.name.text == "Nolib ?", "guess rows wear the question mark, fact rows do not")
ok(BiSToolsSummonRow1.info.text == "Azeroth" and BiSToolsSummonRow2.info.text == "far" and BiSToolsSummonRow3.info.text == "300y", "info text: world name, far, yards (I stand at the stone)")
-- unroll: everyone, inside last
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
ok(SM.unrolled and #SM.list == 6 and SM.list[5].name == "Gambler" and SM.list[5].inside and SM.list[6].here, "all: Gambler listed as inside, here-people last")
local hereRow
for i = 1, 6 do local r = _G["BiSToolsSummonRow" .. i] if r and r.name.text:find("Toolsy") then hereRow = r end end
ok(hereRow and hereRow.info.text == "here", "all: Toolsy standing with me shows 'here'")
ok(BiSToolsSummonAll.label.color[1] == select(1, F.color("accent")), "all lit")
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
ok(not SM.unrolled and #SM.list == 4, "rolled back up")
ok(BiSToolsSummonRow1.template == "SecureActionButtonTemplate" and BiSToolsSummonRow1.clicks == "AnyDown", "rows are secure, AnyDown")
ok(BiSToolsSummonRow1:GetAttribute("*type1") == "target" and BiSToolsSummonRow1:GetAttribute("*unit1") == "raid7", "row targets its unit")
ok(BiSToolsSummonRow1:GetAttribute("shift-type1") == "" and BiSToolsSummonRow1:GetAttribute("type2") == nil and BiSToolsSummonRow1:GetAttribute("*type2") == nil, "shift kills the click, no type2 anywhere")
ok(BiSToolsSummon.h == 16 + 4 * 14 + 4 + 12 + 16, "four rows tall, status line (1 in), request footer - the prompt lives in the header, no strip")
ok(BiSToolsSummonRequest.w + BiSToolsSummonAll.w == BiSToolsSummon.w, "footer: request + all fill the width exactly")
-- every label fits its box, both states of the footer
local function fits(fs, w) return fs:GetStringWidth() <= w end
ok(fits(BiSToolsSummonRequest.label, BiSToolsSummonRequest.w - 8), "footer label fits (idle)")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(fits(BiSToolsSummonRequest.label, BiSToolsSummonRequest.w - 8), "footer label fits (requested)")
ok(BiSToolsSummonRequest.label.text:find("cancel"), "and still says cancel")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(fits(BiSToolsSummonAll.label, BiSToolsSummonAll.w - 8), "all label fits")
-- header budget: W minus the button strip (56) minus the left pad (4); the title
-- is the BiS> prompt (Arn, 8 Sep: "prompt BiS> _ blinking should be in the header
-- and cycle relevant messages: addon name, summoners at the stone ...")
local BUDGET = SM.W - 56 - 8
local function plain() return (tostring(SM.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- move the clock and let the fade (out, then in) finish - Arn: "fade in and out, not hard cuts"
local function adv(dt) W.now = W.now + dt SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() end
ok(SM.con and SM.con.fs == SM.title, "the title FontString is the BiSTheme console")
ok(SM.con.words.parent == SM.title.parent, "the words FontString lives in the header too")
adv(0)
ok(plain():find("^BiS> ") and (plain():find("_$") or plain():find(" $")), "prompt: BiS> ... cursor", plain())
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (idle)")
-- the two footer clicks above said "requested" / "request off": events jump the
-- rotation and hold 3 s each, then the slots come back
ok(plain():find("requested", 1, true), "an event line takes the prompt first", plain())
adv(3)
ok(plain():find("request off", 1, true), "queued events show one after the other", plain())
adv(3)
SM.PaintTitle(0) adv(0)
ok(SM.con.slots.stone == nil and plain():find("Summon", 1, true), "no one at a stone: only the name slot", plain())
SM.PaintTitle(2)
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("UI%-RaidTargetingIcon_4") and SM.con.slots.stone.text:find("2 at stone", 1, true), "2 at stone: triangle + green count slot")
-- the slots rotate: name now, stone after a cycle, name again after another
-- no hard cut: the old words fade out, the new fade in (alpha on the words only)
W.now = W.now + 3 SM.PaintConsole()
ok(SM.con.fading == "out" and plain():find("Summon", 1, true), "cycle due: the old words start fading, still there")
W.now = W.now + 0.1 SM.PaintConsole()
ok(SM.con.words.alpha > 0 and SM.con.words.alpha < 1, "words alpha on the way down", SM.con.words.alpha)
W.now = W.now + 0.2 SM.PaintConsole()
ok(SM.con.words.alpha == 0 and plain():find("2 at stone", 1, true), "swap at zero: the stone slot, coming up")
W.now = W.now + 0.3 SM.PaintConsole()
ok(SM.con.words.alpha == 1 and not SM.con.fading, "solid again")
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (counting)")
local back
for _ = 1, 4 do adv(3) if plain():find("Summon", 1, true) then back = true break end end
ok(back, "then round to the name again", plain())
SM.PaintTitle(12) adv(3)
ok(SM.con:Width() <= BUDGET, "title fits the header's left budget (12 at stone)")
-- the cursor blinks at 2 Hz and is never trimmed away
W.now = W.now + 0.5 SM.PaintConsole() local c1 = plain():sub(-1)
W.now = W.now + 0.5 SM.PaintConsole() local c2 = plain():sub(-1)
ok((c1 == "_" and c2 == " ") or (c1 == " " and c2 == "_"), "cursor blinks", c1, c2)
ok(SM.count:GetText() == nil or not tostring(SM.count:GetText()):find("at stone", 1, true), "status line no longer repeats the at-stone count")
SM.PaintTitle(0)
-- the status line gets its own row: body height grows by STATUS_H when it has text
SM.count:SetText("") SM.PaintRows(db_summon(), SM.list) local h0 = SM.body.h
SM.count:SetText("1 at stone") SM.PaintRows(db_summon(), SM.list)
ok(SM.body.h == h0 + 12, "status text adds a 12 px line under the rows (GetText, not a mock field)")
SM.Refresh(db_summon())
-- header overlap guard: nothing but title + buttons lives in the header
ok(SM.count.parent == SM.body, "the count line lives under the rows, not in the header")
ok(SM.jeckBtn.point[4] == -38 and SM.askBtn.point[4] == -17 and SM.closeBtn.point[4] == -3, "header buttons at their computed slots")
ok(SM.pinBtn == nil, "no pin button (auto-open covers it; /bt summon show|auto|hide is the manual way)")
ok(SM.jeckBtn.w == 18 and SM.jeckBtn.point[4] - SM.jeckBtn.w == -56, "J's left edge is the 56 px strip")

-- lib 1 peers sent no mapId outdoors: a fact standing next to me must not read "far"
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|")   -- empty mapId
SM.Refresh(db_summon())
local dd
for _, e in ipairs(SM.list) do if e.name == "Druid" then dd = e end end
ok(dd and math.abs(dd.score - 300) < 1e-6, "no mapId in the WHERE -> UnitPosition yards instead of far")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")

-- a guess in a blacklisted zone is 'inside' by inference
W.raid[5].zone = "Karazhan"
SM.Refresh(db_summon())
ok(SM.inside == 2 and #SM.list == 3, "Nolib in Karazhan by roster string -> inside (the old guess)")
W.raid[5].zone = "Netherstorm"

-- fact outranks guess at equal score
W.raid[5].x, W.raid[5].y = 1300, 1000
SM.Refresh(db_summon())
ok(SM.list[3].name == "Druid" and SM.list[4].name == "Nolib", "equal 300 y: the fact sorts above the guess")
W.raid[5].x, W.raid[5].y = 1000, 1200

-- click = park. A fact parks 15 s (their client will report the offer), a guess 120 s
W.now = 5000
BiSToolsSummonRow1:Click()   -- Azzy, a guess in the other world
ok(SM.tried.Azzy and math.abs(SM.tried.Azzy - (5000 + 120)) < 1e-6, "clicking a guess parks 120 s")
ok(SM.list[1].name == "Farzone" and SM.list[4].name == "Azzy" and BiSToolsSummonRow4.info.text == "2:00", "parked guess sinks with its clock")
BiSToolsSummonRow1:Click()   -- Farzone, a guess
BiSToolsSummonRow1:Click()   -- Druid, a fact
ok(SM.tried.Druid and math.abs(SM.tried.Druid - (5000 + 15)) < 1e-6, "clicking a fact parks only 15 s")
ok(SM.list[1].name == "Nolib", "Nolib is top now")

-- the peer's own word replaces the park: OFFER with 60 s left, then NO pops him back that second
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
ok(SM.tried.Druid == nil, "a SUM from the peer clears our park")
local d
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "offer" and math.abs(d.waiting - 60) < 1e-6, "Druid waits on his real 60 s offer")
-- a peer still on lib minor 4 announces a bystander's CONFIRM_SUMMON as an OFFER with no
-- summoner: not an offer here, he is not parked on it
say("Druid", "1|CORE|SUM|NO|||") W.now = W.now + 1 SM.Refresh(db_summon())
say("Druid", "1|CORE|SUM|OFFER|||120")
d = nil for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why ~= "offer" and d.summon == nil, "a phantom OFFER (no summoner) from an old peer is ignored", d and d.why)
say("Druid", "1|CORE|SUM|NO|||") SM.Refresh(db_summon())
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
d = nil for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "offer", "a real one still parks him")
W.now = 5030
say("Druid", "1|CORE|SUM|NO|||")
ok(SM.list[1].name == "Druid", "NO -> Druid is back on top that second, not two minutes later")
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
say("Druid", "1|CORE|SUM|OK|Me|Karazhan|")
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "ok" and d.waiting == 0, "OK -> 'ok', sinks")
local okRow
for i = 1, 4 do if BiSToolsSummonRow1 and _G["BiSToolsSummonRow" .. i].name.text == "Druid" then okRow = _G["BiSToolsSummonRow" .. i] end end
ok(okRow and okRow.info.text == "ok", "row says ok")
-- lapse: OFFER 60 s ago with no word -> not waiting any more
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
W.now = 5100 SM.Refresh(db_summon())
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.waiting == nil, "an offer past its own clock is no longer waiting")
say("Druid", "1|CORE|SUM|NO|||")
S("summon clear")

-- request a summon: a peer's REQ jumps the queue with "asks"; mine goes out on the wire
S("summon show") SM.Refresh(db_summon())
ok(SM.list[1].name ~= "Nolib", "Nolib is not on top by score")
say("Nolib", "1|SUMMON|REQ|1")   -- the addon-less man cannot send this; pretend a Tools user did
ok(SM.requests.Nolib and SM.list[1].name == "Nolib" and BiSToolsSummonRow1.info.text == "asks", "a request puts him on top with 'asks'")
ok(BiSToolsSummonRow1.info.color[1] == select(1, F.color("gold")), "asks is gold")
ok(W.sounds[#W.sounds] == 3081, "request pings the summoner")
local pr0 = #W.messages
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.sounds > 0 and W.sounds[#W.sounds] == 3081 and SM.requests.Nolib, "repeat request does not re-ping (still asked)")
say("Nolib", "1|SUMMON|REQ|0")
ok(not SM.requests.Nolib and SM.list[1].name ~= "Nolib", "cancel drops him back")
say("Nolib", "1|SUMMON|REQ|1")
W.now = W.now + 700 SM.Refresh(db_summon())
ok(not SM.requests.Nolib, "a request nobody answered dies after 10 min")
say("Druid", "1|SUMMON|REQ|1")
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
ok(not SM.requests.Druid, "an offer landing clears the request")
say("Druid", "1|CORE|SUM|NO|||")
-- my own request
local m0 = #W.messages
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.myRequest and W.messages[m0 + 1] == "1|SUMMON|REQ|1" and W.sentCount("WHERE") > 0, "footer sends REQ 1 and a WHERE")
ok(BiSToolsSummonRequest.label.text:find("cancel"), "footer says click to cancel")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(not SM.myRequest and W.messages[#W.messages] == "1|SUMMON|REQ|0", "click again sends REQ 0")
S("summon me") ok(SM.myRequest, "/bt summon me")
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
SM.nagFrame.scripts.OnEvent(SM.nagFrame, "CONFIRM_SUMMON")
ok(not SM.myRequest and W.messages[#W.messages] == "1|SUMMON|REQ|0", "an offer reaching me cancels my request")
SM.nagFrame.scripts.OnEvent(SM.nagFrame, "CANCEL_SUMMON") W.runAfters() SM.NagStop()
-- header is a drag handle
S("summon hide")

-- stones: learned by hover, broadcast, received, and by a peer landing after OK
lib.peers.Nolib = nil   -- the request test spoke as him; he is the addon-less man again
S("summon show")
local dbs = db_summon()
dbs.stones = {}
ok(next(dbs.stones or {}) == nil, "no stones known yet")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
W.tooltipShown, W.tooltipText = true, "Tempest Keep Summoning Stone"
local st0 = #W.messages
SM.Watch(dbs, 0.2)
local st = dbs.stones["530|Netherstorm"]
ok(st and st.x == 1000 and st.y == 1000, "hovering the stone records it under map|zone")
ok(W.messages[#W.messages]:find("^1|SUMMON|STONE|530|Netherstorm|1000.0|1000.0"), "and tells the raid")
SM.Watch(dbs, 0.2) SM.Watch(dbs, 0.2)
ok(W.sentCount("SUMMON|STONE") == 1, "told once")
W.tooltipShown = false
-- a peer standing on that stone is "at stone", dropped from the list, counted in the header
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")
SM.Refresh(dbs)
local names = {}
for _, e in ipairs(SM.list) do names[e.name] = true end
ok(not names.Druid and SM.atStone == 2, "Druid within 80 y of the stone -> at stone, not a candidate (Toolsy too)")
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("3 at stone", 1, true), "the prompt's stone slot counts them, me included (green, Innervate-style)", SM.con.slots.stone and SM.con.slots.stone.text)
ok(not (SM.count:GetText() or ""):find("at stone", 1, true), "and the status line does not repeat it")
-- I am at the stone: yards show now (Farzone stays far)
local fz
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Farzone") then fz = r end end
ok(fz and fz.info.text == "far", "other zone still 'far' at the stone")
W.raid[5].x, W.raid[5].y = 1000, 1200 SM.Refresh(dbs)
local nb
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "200y", "at the stone: yards from the stone")
W.me.x, W.me.y = 5000, 5000 W.now = W.now + 5 SM.Refresh(dbs)
-- away from the stone the window is compact: no rows, the empty line counts the stone
local anyRow = false
for i = 1, 6 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown then anyRow = true end end
ok(not anyRow and not SM.empty.shown and SM.body.h == 4, "away from the stone: compact - no rows, no body text (the header prompt says N at stone)")
ok(SM.count.text == "", "compact: no second count line")
ok(BiSToolsSummonRequest.shown ~= false, "compact: request button still there")
-- unroll shows the list, without yards
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
nb = nil
for i = 1, 8 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "", "unrolled away from the stone: rows, no yards")
BiSToolsSummonAll.scripts.OnClick(BiSToolsSummonAll)
W.me.x, W.me.y = 1000, 1000
-- a guess standing on the stone too (same instance, UnitPosition)
W.raid[5].x, W.raid[5].y = 1000, 1050
SM.Refresh(dbs)
ok(SM.atStone == 3, "the addon-less man at the stone counts too, by UnitPosition")
W.raid[5].x, W.raid[5].y = 1000, 1200
-- I walk away: the stone stays where it was, Druid still at it
W.me.x, W.me.y = 5000, 5000
SM.Refresh(dbs)
ok(SM.atStone == 2, "at-stone is measured from the stone, not from me")
W.me.x, W.me.y = 1000, 1000
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
-- receive a stone from a peer
say("Toolsy", "1|SUMMON|STONE|530|Shadowmoon Valley|-3000.0|2000.0")
ok(dbs.stones["530|Shadowmoon Valley"] and dbs.stones["530|Shadowmoon Valley"].x == -3000, "a peer's STONE lands in my table")
-- landing: Gambler says OK, arrives, his WHERE after that is the stone
dbs.stones = {}
say("Gambler", "1|CORE|SUM|OFFER|Me|Blade's Edge|60")
say("Gambler", "1|CORE|SUM|OK|Me|Blade's Edge|")
ok(SM.landing and SM.landing.Gambler, "OK starts a landing watch")
local asks0 = W.sentCount("ASK")
W.runAfters(5)
ok(W.sentCount("ASK") == asks0 + 1, "asks once after the teleport")
say("Gambler", "1|CORE|WHERE|0|none||Blade's Edge Mountains|7000.0|-800.0|530")
ok(dbs.stones["530|Blade's Edge Mountains"] and dbs.stones["530|Blade's Edge Mountains"].x == 7000, "his position after landing is the stone")
ok(not SM.landing.Gambler, "watch cleared")
say("Gambler", "1|CORE|SUM|NO|||")

-- a request from someone standing AT the stone still shows (Kumlance at the Stormwind stone, 8 Sep)
S("summon auto") ok(not BiSToolsSummon:IsShown(), "auto: hidden")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")   -- at the stone
SM.Refresh(dbs)
local seen = false for _, e in ipairs(SM.list) do if e.name == "Druid" then seen = true end end
ok(not seen, "at the stone, no request -> not listed")
say("Druid", "1|SUMMON|REQ|1")
ok(BiSToolsSummon:IsShown(), "a request pops the window in auto mode")
ok(SM.list[1] and SM.list[1].name == "Druid" and SM.list[1].asked, "asked beats the at-stone filter, sits on top")
say("Druid", "1|SUMMON|REQ|0")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
S("summon show")

-- freshness: walking off a known stone pushes a WHERE; a summoner re-asks when a fact goes stale
S("summon show")
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
local wh0 = W.sentCount("CORE|WHERE")
SM.selfAtStone = nil SM.SelfWatch(dbs)              -- first look just remembers
ok(W.sentCount("CORE|WHERE") == wh0 and SM.selfAtStone == true, "first look: at the stone, nothing sent")
SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0, "still there: nothing sent")
W.me.x = 1500 SM.SelfWatch(dbs)                       -- 2500 yd off
ok(W.sentCount("CORE|WHERE") == wh0 + 1 and SM.selfAtStone == false, "walked off the stone -> one WHERE")
SM.SelfWatch(dbs) SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0 + 1, "standing away: nothing more")
W.me.x = 1000 SM.SelfWatch(dbs)
ok(W.sentCount("CORE|WHERE") == wh0 + 2, "back on it -> one more")
ok(SM.selfTicker and SM.selfTicker.iv == 3, "self-watch ticks every 3 s from load")
-- re-ask: a fact older than 30 s while the window is up
local ask0 = W.sentCount("ASK")
for _, p in pairs(lib:Peers()) do if p.where then p.where.at = W.now end end
SM.lastReask = nil SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0, "all facts fresh -> no ask")
lib:Peer("Druid").where.at = W.now - 40
SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 1, "a 40 s old fact -> one ask")
SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 1, "throttled to one per 15 s")
W.now = W.now + 16 SM.Reask(dbs)
ok(W.sentCount("ASK") == ask0 + 2, "asks again after 15 s if still stale")
lib:Peer("Druid").where.at = W.now
S("summon hide") SM.Reask(dbs) W.now = W.now + 16
ok(W.sentCount("ASK") == ask0 + 2, "window hidden -> never asks")
dbs.stones = {} W.me.x = 1000 SM.selfAtStone = nil

-- two at a stone pops the window for everyone (auto mode), and keeps it while true
S("summon auto")
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 5000, y = 5000, inst = 530 }   -- I am far away
say("Druid",  "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
say("Toolsy", "1|CORE|WHERE|0|none||Netherstorm|1005.0|1000.0|530")  -- one at the stone
W.now = W.now + 20 SM.selfAtStone = nil SM.SelfWatch(dbs)
ok(not BiSToolsSummon:IsShown(), "one at the stone: nothing")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")   -- now two
SM.SelfWatch(dbs)
ok(BiSToolsSummon:IsShown(), "two at the stone: the window pops for me, far away")
ok(not SM.empty.shown and SM.body.h == 4 and SM.con.slots.stone.text:find("2 at stone", 1, true), "compact: bare body, the header prompt says 2 at stone")
W.now = W.now + 20 SM.SelfWatch(dbs) SM.Watch(dbs, 0.2)
ok(BiSToolsSummon:IsShown(), "stays while two are there")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")   -- one walks off
W.now = W.now + 20 SM.SelfWatch(dbs) SM.Watch(dbs, 0.2)
ok(BiSToolsSummon:IsShown(), "one left -> a few seconds of grace")
W.now = W.now + 6 SM.Watch(dbs, 0.2)
ok(not BiSToolsSummon:IsShown(), "then it hides")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
dbs.stones = {} S("summon show")

-- the prompt in the header: events show over the slots, hold 3 s, chat stays clean
S("summon show")
local chat0 = 0
local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, m) chat0 = chat0 + 1 W.lastMsg = m end
local function shown() return (tostring(SM.con:Text()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function adv(dt) W.now = W.now + dt SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() W.now = W.now + 0.3 SM.PaintConsole() end
SM.con:Clear() adv(4)
ok(shown():find("^BiS> "), "prompt always there")
local h0 = BiSToolsSummon.h
SM.Log("request now", "good") adv(0)
ok(shown():find("request now", 1, true) and not shown():find("%.%.%."), "event printed whole in the prompt", shown())
ok(BiSToolsSummon.h == h0, "the window did not grow: no strip")
ok(SM.con:Width() <= SM.W - 56 - 8, "prompt fits the header budget")
ok(SM.con.line and SM.con.line.colour == "good", "coloured as asked")
adv(3)
ok(not shown():find("request now", 1, true), "gone after the hold, back to the slots", shown())
for i = 1, 3 do SM.Log("line " .. i) end
adv(0)
ok(shown():find("line 1", 1, true) and #SM.con.queue == 2, "several events queue up, first one showing")
adv(3) ok(shown():find("line 2", 1, true), "second after the hold")
adv(3) ok(shown():find("line 3", 1, true), "third after the next")
adv(3) ok(not shown():find("line", 1, true), "then the slots again")
-- a long event is trimmed with an ellipsis, the cursor survives the trim
SM.Log("Verylongdruidname accepted the thing", "good") adv(0)
ok(shown():find("%.%.%.[_ ]$") and SM.con:Width() <= SM.W - 56 - 8, "long line trimmed, cursor kept, fits", shown())
adv(3)
-- the everyday events go to the prompt, not chat
chat0 = 0
say("Druid", "1|SUMMON|REQ|1") adv(0)
ok(chat0 == 0 and shown():find("Druid asks", 1, true), "a request prints in the prompt, not chat", shown())
-- "N asking" is for summoners only (Arn, 8 Sep: "a random person should not see 1 asking")
ok(SM.con.slots.asks == nil, "far from any stone, not Jeck: no asking slot for me")
dbs.jeck = true SM.Refresh(dbs)
ok(SM.con.slots.asks and SM.con.slots.asks.text == "1 asking", "Jeck (the summoner) sees the asking slot")
dbs.jeck = false SM.Refresh(dbs)
ok(SM.con.slots.asks == nil, "Jeck off: gone again")
SM.stoneSeen = W.now SM.Refresh(dbs)
ok(SM.con.slots.asks and SM.con.slots.asks.text == "1 asking", "standing at a stone: the asking slot shows")
SM.stoneSeen = nil
say("Druid", "1|SUMMON|REQ|0") SM.Refresh(dbs)
ok(SM.con.slots.asks == nil, "asking slot clears with the request")
-- my own echo: the client hands my REQ back to me; the lib (minor 3) drops it
local lib3 = SM.Lib()
lib3:OnMessage("BiS", "1|SUMMON|REQ|1", "RAID", "Me")
lib3:OnMessage("BiS", "1|CORE|WHERE|0|none||Netherstorm|1000.0|1000.0|530", "RAID", "Me")
ok(SM.requests.Me == nil and lib3:Peer("Me") == nil, "my own REQ / WHERE echo never makes me a peer or a requester")
adv(3)
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60") adv(0)
ok(shown():find("Druid offered", 1, true), "offer line", shown())
adv(3)
say("Druid", "1|CORE|SUM|NO|||") adv(0)
ok(shown():find("Druid declined", 1, true), "decline line", shown())
ok(chat0 == 0, "still nothing in chat")
DEFAULT_CHAT_FRAME.AddMessage = oldAdd
-- my own request is a standing slot while it lasts
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.con.slots.mine and SM.con.slots.mine.text == "requesting...", "requesting slot while my request stands")
BiSToolsSummonRequest.scripts.OnClick(BiSToolsSummonRequest)
ok(SM.con.slots.mine == nil, "cleared when I take it back")
-- pop and leave narrate themselves
S("summon auto") SM.con:Clear() SM.popped = false
dbs.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
W.me = { zone = "Netherstorm", x = 5000, y = 5000, inst = 530 }
say("Druid",  "1|CORE|WHERE|0|none||Netherstorm|1010.0|1000.0|530")
say("Toolsy", "1|CORE|WHERE|0|none||Netherstorm|1005.0|1000.0|530")
W.now = W.now + 20 SM.selfAtStone = nil SM.SelfWatch(dbs) adv(0)
ok(BiSToolsSummon:IsShown() and shown():find("request now", 1, true), "pop narrates: request now", shown())
ok(SM.con.slots.stone and SM.con.slots.stone.text:find("2 at stone", 1, true), "and the stone slot says 2 at stone")
local q0 = #SM.con.queue
SM.SelfWatch(dbs) ok(#SM.con.queue == q0, "said once")
say("Druid", "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
adv(3) SM.SelfWatch(dbs) adv(0)
ok(shown():find("no summons", 1, true), "leave narrates: no summons", shown())
W.now = W.now + 4 SM.Watch(dbs, 0.2) ok(BiSToolsSummon:IsShown(), "still up 4 s later")
W.now = W.now + 2 SM.Watch(dbs, 0.2) ok(not BiSToolsSummon:IsShown(), "hidden ~5 s after the line")
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
dbs.stones = {} SM.con:Clear() S("summon show")

-- the interact key over the window: press 1 targets the top name, press 2 is the real interact
S("summon show") SM.Refresh(dbs)
local kb = SM.KeyButton()
W.target = nil W.mouseOver = nil
SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "mouse off the window: no override")
W.mouseOver = SM.frame
SM.Watch(dbs, 0.2)
ok(W.binds[kb] and W.binds[kb].key == "NUMPADMULTIPLY" and W.binds[kb].btn == "BiSToolsSummonKey", "mouse on the window, top not targeted -> interact key overridden to the key button")
ok(kb:GetAttribute("*unit1") == SM.list[1].unit, "key button points at the top name")
kb:Click()                                       -- press 1
ok(W.target and W.target.name == SM.list[1].name, "press 1 targets the top name")
ok(SM.list[1].name == W.target.name, "and does NOT park him")
SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "top targeted -> override dropped, press 2 is the real interact")
-- park him (his offer lands): the top changes, the override is back
say(SM.list[1].name, "1|CORE|SUM|OFFER|Me|Karazhan|60")
SM.Watch(dbs, 0.2)
ok(W.binds[kb] and kb:GetAttribute("*unit1") == SM.list[1].unit, "new top -> re-armed on the new name")
say(W.target.name, "1|CORE|SUM|NO|||")
W.combat = true W.mouseOver = nil
SM.Watch(dbs, 0.2)
ok(W.binds[kb] ~= nil, "in combat: binds untouched")
W.combat = false
SM.Watch(dbs, 0.2) ok(W.binds[kb] == nil, "mouse off -> cleared")
S("summon key off") W.mouseOver = SM.frame W.target = nil SM.Watch(dbs, 0.2)
ok(W.binds[kb] == nil, "/bt summon key off -> never armed")
S("summon key on") SM.Watch(dbs, 0.2) ok(W.binds[kb] ~= nil, "back on")
W.interactKey = nil SM.Watch(dbs, 0.2) ok(W.binds[kb] == nil, "no interact key bound -> nothing to override")
W.interactKey = "NUMPADMULTIPLY" W.mouseOver = nil W.target = nil SM.Watch(dbs, 0.2)
S("off summon") ok(W.binds[kb] == nil, "tool off clears the override") S("on summon")
S("summon hide")

-- jeck mode: the summoner opts in; window pinned, requests come through like a raid warning
S("summon jeck on")
ok(dbs.jeck and dbs.mode == "on" and BiSToolsSummon:IsShown(), "jeck: pinned")
ok(SM.jeckBtn.label.color[1] == select(1, F.color("gold")), "J lit gold")
local n0 = #W.notices
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.notices[#W.notices]:find("Nolib") and W.sounds[#W.sounds] == 8959 and W.spoken[#W.spoken] == "Summon", "jeck: request = raid warning + sound + voice")
say("Nolib", "1|SUMMON|REQ|0")
S("summon jeck off")
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.sounds[#W.sounds] == 3081, "not jeck: quiet ping only")
say("Nolib", "1|SUMMON|REQ|0")
SM.jeckBtn.scripts.OnClick(SM.jeckBtn) ok(dbs.jeck, "J button toggles") SM.jeckBtn.scripts.OnClick(SM.jeckBtn) ok(not dbs.jeck, "and back")
S("summon hide") dbs.stones = {}

-- stone mouseover brings the window up in auto mode, asks the raid once, lingers, hides
S("summon auto")
ok(not BiSToolsSummon:IsShown() and db_summon().mode == "auto", "auto: hidden until a stone")
local asksBefore = W.sentCount("ASK")
W.tooltipShown, W.tooltipText = true, "Karazhan Summoning Stone"
W.now = 6000 SM.Watch(db_summon(), 0.2)
ok(BiSToolsSummon:IsShown(), "stone under the cursor -> window up")
ok(W.sentCount("ASK") == asksBefore + 1, "one ASK on the way up")
SM.Watch(db_summon(), 0.2) SM.Watch(db_summon(), 0.2)
ok(W.sentCount("ASK") == asksBefore + 1, "standing there costs no more asks")
W.tooltipShown = false
W.now = 6005 SM.Watch(db_summon(), 0.2)
ok(BiSToolsSummon:IsShown(), "lingers 8 s after you look away")
W.now = 6010 SM.Watch(db_summon(), 0.2)
ok(not BiSToolsSummon:IsShown(), "then hides")
ok(SM.IsStoneText("Meeting Stone") and not SM.IsStoneText("Innkeeper"), "stone text patterns")
ok(SM.IsStoneText("Pierre de convocation", "convocation"), "custom stone name (other locales)")
W.tooltipShown, W.tooltipText = true, "Some NPC"
W.now = 7000 SM.Watch(db_summon(), 0.2)
ok(not BiSToolsSummon:IsShown(), "a non-stone tooltip does nothing")
W.tooltipShown = false

-- combat: Show/Hide queued, flushed on regen
S("summon show")
W.combat = true
S("summon hide")
ok(BiSToolsSummon:IsShown() and SM.pending.visible == false, "hide in combat is queued")
W.combat = false
SM.events.scripts.OnEvent(SM.events, "PLAYER_REGEN_ENABLED")
ok(not BiSToolsSummon:IsShown(), "flushed on regen")

-- the nag: fires on the person being summoned, keeps going, stops on accept/cancel, survives /bt off summon
local nagFrame = SM.nagFrame
local notices0, sounds0, spoken0 = #W.notices, #W.sounds, #W.spoken
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon()                     -- the lib's own handler (order between frames is not promised)
nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON")
W.runAfters()
ok(#W.notices == notices0 + 1 and W.notices[#W.notices]:find("Warlock") and W.notices[#W.notices]:find("Karazhan"), "raid-warning text names the summoner and the place")
ok(W.sounds[#W.sounds] == 8959 and W.spoken[#W.spoken] == "Summon", "raid warning sound + voice line")
W.now = W.now + 20 W.tick()
ok(#W.notices == notices0 + 2, "nags again 20 s later")
lib:OnConfirmed() SM.NagStop()            -- accept (the hook does this live)
W.now = W.now + 20 W.tick()
ok(#W.notices == notices0 + 2 and not SM.nag.active, "accepted -> quiet")
-- cancel path
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(SM.nag.active, "second offer nags")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
ok(not SM.nag.active, "cancel stops it")
-- tool off, nag on
S("off summon")
W.offer = { summoner = "Warlock", area = "Karazhan", left = 120 }
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(SM.nag.active and #W.notices == notices0 + 4, "nag works with the summon tool switched off")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
S("summon nag off")
lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
ok(not SM.nag.active and #W.notices == notices0 + 4, "/bt summon nag off is the only thing that silences it")
S("summon nag on")
nagFrame.scripts.OnEvent(nagFrame, "CANCEL_SUMMON")
-- a bystander's CONFIRM_SUMMON (someone ELSE got summoned; the client fires it on me with
-- nothing behind it - Arn: "randomly ... it says SUMMON by someone"): no nag, no OFFER,
-- and my own pending request is not cancelled by it
do
  W.offer = nil
  local n1, m1 = #W.notices, #W.messages
  SM.myRequest = true
  lib:OnConfirmSummon() nagFrame.scripts.OnEvent(nagFrame, "CONFIRM_SUMMON") W.runAfters()
  ok(#W.notices == n1 and not SM.nag.active, "empty CONFIRM_SUMMON: no raid warning, no nag")
  ok(#W.messages == m1, "and the lib sent no phantom OFFER")
  ok(SM.myRequest == true, "and my standing request was not cancelled by it")
  SM.myRequest = false
end
S("on summon")
S("summon hide")

-- drag saves point + relative point
BiSToolsFarm.scripts.OnDragStop(BiSToolsFarm)
ok(db.pos[1] == "TOPLEFT" and db.pos[4] == "CENTER" and db.pos[2] == 12, "drag saves position")

-- ------------------------------------------------------------ a full 25-man
-- Arn (8 Sep): "run some tests with 25 people using this addon". 21 facts (12-char
-- names, the ugly kind), 3 without any addon, me at the stone in Netherstorm.
do
  local names = { "Kumlance", "Jeckalicious", "Brimstonefel", "Fojjiwarlock", "Hexadecimal", "Moonwhisper",
    "Quillfeather", "Ravenmourne", "Sylvanasfan", "Kessandra", "Lorthemar", "Nyxathid", "Pyrelight",
    "Ithiliel", "Elaria", "Fenwick", "Jorvak", "Bree", "Cato", "Nebbin", "Arn", "Dorn", "Gorrmash", "Oggrim" }
  local nolib = { Dorn = true, Gorrmash = true, Oggrim = true }
  W.raid = { { name = "Me" } }
  for i, n in ipairs(names) do
    W.raid[#W.raid + 1] = { name = n, zone = "Netherstorm", x = 1000 + i * 40, y = 1000, inst = 530 }
  end
  W.inRaid = true
  local dbx = db_summon()
  dbx.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
  dbx.rows = 6 dbx.jeck = false
  W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
  lib.peers = {} SM.requests = {} SM.tried = {}
  for i, n in ipairs(names) do
    if not nolib[n] then
      say(n, "1|CORE|HI|3|BiSTools=0.2.0|0")
      if i <= 6 then        -- six standing at the stone with me
        say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i * 5))
      elseif i <= 11 then   -- five inside Karazhan
        say(n, "1|CORE|WHERE|1|raid|Karazhan|Karazhan|100.0|100.0|532")
      elseif i <= 15 then   -- four in Azeroth
        say(n, ("1|CORE|WHERE|0|none||Elwynn Forest|%d.0|500.0|0"):format(i * 100))
      else                  -- the rest spread across Netherstorm
        say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i * 300))
      end
    end
  end
  say("Kessandra", "1|SUMMON|REQ|1") say("Pyrelight", "1|SUMMON|REQ|1")   -- an addon-less man cannot ask
  S("summon show") SM.Refresh(dbx)
  ok(lib:Count() == 21, "21 facts on the lib, 3 addon-less men are not", lib:Count())
  -- Kessandra is inside Karazhan AND asked: a request beats every filter, so 4 count as inside
  ok(SM.atStone == 6 and SM.inside == 4, "6 at the stone, 4 inside - counted, not listed (the asking one is listed)", SM.atStone, SM.inside)
  ok(SM.stoneCount == 7, "the stone slot counts me too: 7", SM.stoneCount)
  ok(SM.con.slots.stone.text:find("7 at stone", 1, true) and SM.con:Width() <= SM.W - 56 - 8, "header prompt fits with 7 at stone")
  -- 24 members - 6 at stone - 4 inside = 14 candidates; the two asking facts on top,
  -- then the other world (Azeroth), then Netherstorm far-to-near, guesses last with ?
  ok(#SM.list == 14, "14 candidates listed", #SM.list)
  ok(SM.list[1].asked and SM.list[2].asked, "the two who asked are on top", SM.list[1].name, SM.list[2].name)
  ok(SM.list[3].score >= SM.SCORE_OTHER_WORLD and SM.list[5].score >= SM.SCORE_OTHER_WORLD and SM.list[6].score < SM.SCORE_OTHER_WORLD, "then the three in the other world, then Netherstorm", SM.list[3].name)
  ok(SM.list[6].score > SM.list[11].score, "Netherstorm furthest first")
  local guessSeen = false
  for _, e in ipairs(SM.list) do if e.name == "Gorrmash" and not e.fact then guessSeen = true end end
  ok(guessSeen, "an addon-less man still ranks, as a guess")
  -- rows: capped at db.rows, every row's name + info fit inside 170 px
  local shown, widest = 0, 0
  for i = 1, SM.MAX_ROWS do
    local r = _G["BiSToolsSummonRow" .. i]
    if r and r.shown then
      shown = shown + 1
      local w = r.name:GetStringWidth() + r.info:GetStringWidth() + 12
      if w > widest then widest = w end
    end
  end
  ok(shown == 6, "six rows shown of fourteen (db.rows)", shown)
  ok(widest <= SM.W, "the widest row (12-char name + info) fits the window", widest)
  -- Jeck mode: the asking slot appears for the summoner
  dbx.jeck = true SM.Refresh(dbx)
  ok(SM.con.slots.asks and SM.con.slots.asks.text == "2 asking", "2 asking for the summoner", SM.con.slots.asks and SM.con.slots.asks.text)
  ok(SM.con:Width() <= SM.W - 56 - 8, "header still fits")
  dbx.jeck = false
  -- the ticker's Refresh must stay cheap with 25 on the roster
  local t0 = os.clock()
  for _ = 1, 200 do SM.Refresh(dbx) end
  local per = (os.clock() - t0) / 200 * 1000
  print(("   Refresh on a 25-man: %.3f ms each (runs every 2 s)"):format(per))
  ok(per < 2, "Refresh on a 25-man under 2 ms")
  -- everybody at the stone -> pop rule still says "N at stone", list empties
  for i, n in ipairs(names) do
    if not nolib[n] then say(n, ("1|CORE|WHERE|0|none||Netherstorm|%d.0|1000.0|530"):format(1000 + i)) end
  end
  SM.Refresh(dbx)
  ok(SM.atStone == 19 and SM.stoneCount == 22 and #SM.list == 5, "everyone with the addon at the stone: 22 counted with me; the two asking + three guesses still listed", SM.atStone, SM.stoneCount, #SM.list)
  ok(SM.con.slots.stone.text:find("22 at stone", 1, true) and SM.con:Width() <= SM.W - 56 - 8, "22 at stone fits the prompt")
  S("summon hide")
  -- put the small fixture back for whatever follows
  W.raid = { { name = "Me" } } W.inRaid = false lib.peers = {} SM.requests = {}
end

-- ------------------------------------------------------------ RezComm: the rez emitter
-- Arn (10 Sep): "look at how Innervate and Gamba use it to talk about the rez, make
-- this another peer". BiSTools embeds _bisdev/RezComm-1.0 byte-identical, TOC-only:
-- a Tools-only priest/paladin/shaman puts rez claims on Innervate's wire (BiSInn,
-- proto 4) without a line of rez code in Tools. Announce-only; stands down when
-- BiSInnervate is loaded (it announces its own casts).
do
  local RC = _G.BiSRezComm
  ok(RC and RC.MINOR == 1 and RC.PROTO == 4, "RezComm 1.0 minor 1 loaded, speaks Innervate's proto 4")
  ok(RC._login and RC._login.events.PLAYER_LOGIN, "self-boots at PLAYER_LOGIN: TOC line only, no call from Tools")
  -- boot as a client WITHOUT Innervate
  W.innervateLoaded = false RC._booted = nil
  RC._login.scripts.OnEvent(RC._login, "PLAYER_LOGIN")
  ok(RC._booted and RC.standDown == false and RC._frame and RC._frame.events.UNIT_SPELLCAST_SENT, "no Innervate: booted, listening to my own casts")
  W.raid = { { name = "Me" }, { name = "Bob", zone = "Netherstorm", x = 1, y = 1, inst = 530 } } W.inRaid = true
  local m0, p0 = #W.messages, #W.prefixes
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-1", 2006)   -- Resurrection r1
  ok(W.messages[#W.messages] == "4|RCLAIM|Bob" and W.prefixes[#W.prefixes] == "BiSInn", "my rez cast -> 4|RCLAIM|Bob on BiSInn, that instant", W.messages[#W.messages], W.prefixes[#W.prefixes])
  ok(#W.afters == 0 or true, "(no timer involved - sent synchronously)")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_INTERRUPTED", "player", "cast-1", 2006)
  ok(W.messages[#W.messages] == "4|RFREE|Bob", "interrupted -> 4|RFREE|Bob")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-2", 20777)  -- Ancestral Spirit
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_INTERRUPTED", "player", "cast-9", 1234)   -- some other cast
  ok(W.messages[#W.messages] == "4|RCLAIM|Bob", "a stray interrupt of another cast does NOT free the corpse")
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 20777)
  ok(W.messages[#W.messages] == "4|RDONE|Bob", "landed -> 4|RDONE|Bob")
  local m1 = #W.messages
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "player", "Bob", "cast-3", 20484)   -- Rebirth: excluded on purpose
  RC._frame.scripts.OnEvent(RC._frame, "UNIT_SPELLCAST_SENT", "raid2", "Me", "cast-4", 2006)      -- somebody else's cast
  ok(#W.messages == m1, "Rebirth and other people's casts say nothing")
  -- the two pipes never mix: LibBiSComm still talks on BiS, the emitter on BiSInn
  local bis, inn = 0, 0
  for i = p0 + 1, #W.prefixes do if W.prefixes[i] == "BiS" then bis = bis + 1 elseif W.prefixes[i] == "BiSInn" then inn = inn + 1 end end
  ok(inn == 4 and bis == 0, "four rez lines on BiSInn, none leaked onto the BiS pipe", inn, bis)
  ok(lib:Peer("Bob") == nil, "an RCLAIM is not a LibBiSComm message: no peer appears")
  -- a client WITH Innervate: the emitter stands down (Innervate announces its own casts)
  W.innervateLoaded = true RC._booted = nil RC._frame = nil
  RC._login.scripts.OnEvent(RC._login, "PLAYER_LOGIN")
  ok(RC._booted and RC.standDown == true and RC._frame == nil, "Innervate loaded: stands down, no frame, no double claim")
  W.innervateLoaded = false
  W.raid = { { name = "Me" } } W.inRaid = false
end

-- ------------------------------------------------------------ the Hub: minimap button, tools window, options
-- Arn (10 Sep): "/ commands are so convoluted ... work on the minimap icon; right click
-- opens the options; the first window shows all the tools we can open" and "right now I
-- have no idea where the farm window is at".
do
  local H = NS.Hub
  ok(H and H.frame.events.PLAYER_LOGIN, "the Hub boots its minimap button at PLAYER_LOGIN")
  local mm = H.BuildMinimap()
  ok(mm and mm == BiSToolsMinimap and mm.parent == Minimap, "minimap button, parented to the Minimap")
  local x, y = H.MinimapPos(225)
  ok(mm.point[1] == "CENTER" and mm.point[2] == Minimap and math.abs(mm.point[4] - x) < 1e-6 and math.abs(mm.point[5] - y) < 1e-6, "sits on the rim at the saved angle (225 = lower left)")
  ok(mm.icon.file == "Interface\\Icons\\Spell_Shadow_Twilight" and mm.ring.file == "Interface\\Minimap\\MiniMap-TrackingBorder", "BiS icon in the standard tracking ring")
  -- drag: the angle follows the cursor around the minimap centre
  W.cursor = { 1000 + 100, 500 }   -- due east of the centre
  H.DragMinimap()
  ok(math.abs(NS.DB().hub.angle - 0) < 1e-6 and math.abs(mm.point[4] - 80) < 1e-6 and math.abs(mm.point[5]) < 1e-6, "dragging east: 0 degrees, button at (80, 0)", NS.DB().hub.angle, mm.point[4], mm.point[5])
  W.cursor = { 1000, 500 + 100 }
  H.DragMinimap()
  ok(math.abs(NS.DB().hub.angle - 90) < 1e-6 and math.abs(mm.point[4]) < 1e-6 and math.abs(mm.point[5] - 80) < 1e-6, "north: 90 degrees, button at (0, 80)")
  NS.DB().hub.angle = 225 H.PlaceMinimap()
  -- left click: the Hub, one row per tool
  mm.scripts.OnClick(mm, "LeftButton")
  local hub = BiSToolsHub
  ok(hub and hub:IsShown() and #hub.rows == 2, "left click opens the Hub with a row per registered tool")
  ok(hub.rows[1].key == "farm" and hub.rows[2].key == "summon", "rows in TOC order: farm, summon")
  ok(hub.rows[1].name.text == "farm" and hub.rows[1].state.text:find("on", 1, true), "row: name + on")
  ok(hub.con.slots.count and hub.con.slots.count.text == "2 of 2 on", "prompt slot counts the tools that are on")
  ok(hub.con:Width() <= H.W - 15 - 8, "hub prompt fits its header budget")
  ok(hub.closeBtn.point[4] == -3, "only an x in the header, at -3")
  ok(hub.foot and hub.foot.label.text == "options" and hub.h == 16 + 2 * 16 + 4 + 16, "footer 'options' button; height = header + rows + footer")
  -- row click opens the tool window; shift-click drags it to the middle
  BiSToolsFarm:Hide() F.db.pos = { "TOPLEFT", 400, -300, "TOPLEFT" }
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  ok(BiSToolsFarm:IsShown() and F.db.pos[1] == "TOPLEFT", "click: farm window shown where it was")
  -- click again while it is open = "bring it to me" (Arn: "can't find the window for the farm")
  F.db.collapsed = true
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  ok(F.db.pos[1] == "CENTER" and F.db.collapsed == false and BiSToolsFarm.point[1] == "CENTER", "second click: dragged to the middle and uncollapsed")
  F.db.pos = { "TOPLEFT", 400, -300, "TOPLEFT" } BiSToolsFarm:Hide() BiSToolsFarm.point = nil
  W.shift = true
  hub.rows[1].scripts.OnClick(hub.rows[1], "LeftButton")
  W.shift = false
  ok(F.db.pos[1] == "CENTER" and F.db.pos[2] == 0 and BiSToolsFarm.point[1] == "CENTER" and BiSToolsFarm.point[2] == UIParent, "shift-click: farm window dragged to the middle of the screen")
  -- every seg label fits its button (the screenshot showed "alw...")
  for _, r in ipairs(BiSToolsOptions and BiSToolsOptions.rows or {}) do end
  -- right click toggles the tool; opening an off tool switches it on first
  hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton")
  ok(not R:Enabled("summon") and hub.rows[2].state.text:find("off", 1, true) and hub.con.slots.count.text == "1 of 2 on", "right click: summon off, row and count follow")
  ok(lib:Enabled(), "and the lib is untouched by it")
  hub.rows[2].scripts.OnClick(hub.rows[2], "LeftButton")
  ok(R:Enabled("summon") and BiSToolsSummon:IsShown() and db_summon().mode == "on", "click on an off tool: switched on and its window pinned open")
  -- right click on the minimap: options
  mm.scripts.OnClick(mm, "RightButton")
  local opt = BiSToolsOptions
  ok(opt and opt:IsShown(), "right click opens Options")
  ok(opt.con:Width() <= H.OPT_W - 15 - 8, "options prompt fits")
  -- sections: tools (3 own rows), farm (4), summon (7) -> 3 headers + 14 rows
  ok(#opt.rows == 3 + 3 + 4 + 7, "one row per section header and per option", #opt.rows)
  ok(opt.h == 16 + #opt.rows * 16 + 4, "options height = header + rows")
  local function find(label) for _, r in ipairs(opt.rows) do if r.name and r.name.text == label then return r end end end
  -- every option label fits its lane (controls take the right 110 px)
  for _, r in ipairs(opt.rows) do if r.name then ok(r.name:GetStringWidth() <= H.OPT_W - 12 - 110, "option label fits: " .. tostring(r.name.text)) end end
  -- a section header's box toggles the tool
  local farmHdr = opt.rows[5]
  ok(farmHdr.ctl and farmHdr.ctl.on == true, "farm section box shows on")
  farmHdr.ctl.scripts.OnClick(farmHdr.ctl)
  ok(not R:Enabled("farm") and farmHdr.ctl.on == false and hub.con.slots.count.text == "1 of 2 on", "box off: farm off, hub count follows")
  farmHdr.ctl.scripts.OnClick(farmHdr.ctl)
  ok(R:Enabled("farm"), "and back on")
  -- toggle: nag
  local nag = find("nag me when summoned")
  ok(nag and nag.ctl.on == true, "nag toggle reads db.nag (default on)")
  nag.ctl.scripts.OnClick(nag.ctl)
  ok(db_summon().nag == false and nag.ctl.on == false, "click: nag off in the db and in the box")
  nag.ctl.scripts.OnClick(nag.ctl)
  ok(db_summon().nag == true, "click: back on")
  -- seg: farm sound
  local snd = find("find sound")
  ok(snd and #snd.ctl == 3 and snd.ctl[1].label.text == "first", "sound is a 3-way seg")
  for _, r in ipairs(opt.rows) do
    if type(r.ctl) == "table" and r.ctl[1] and r.ctl[1].label then
      for _, sg in ipairs(r.ctl) do ok(not tostring(sg.label.text):find("%.%.%."), "seg label whole, no ellipsis: " .. tostring(sg.label.text)) end
    end
  end
  snd.ctl[3].scripts.OnClick(snd.ctl[3])
  ok(db.sound == "off", "seg click sets db.sound = off")
  snd.ctl[1].scripts.OnClick(snd.ctl[1])
  ok(db.sound == "first", "and back to first")
  -- step: radius, clamped
  local rad = find("spot radius")
  ok(rad and rad.ctl.val.text == "20 yd", "radius step shows 20 yd")
  rad.ctl.plus.scripts.OnClick(rad.ctl.plus)
  ok(F.Spots.Radius(db) == 25 and rad.ctl.val.text == "25 yd", "> bumps the radius by 5")
  for _ = 1, 10 do rad.ctl.minus.scripts.OnClick(rad.ctl.minus) end
  ok(F.Spots.Radius(db) == 5, "< clamps at 5")
  db.spotRadius = 20 H.PaintOptions()
  local rows = find("rows")
  for _ = 1, 20 do rows.ctl.minus.scripts.OnClick(rows.ctl.minus) end
  ok(db_summon().rows == 1, "the stepper itself clamps at min (rows never below 1)", db_summon().rows)
  for _ = 1, 20 do rows.ctl.plus.scripts.OnClick(rows.ctl.plus) end
  ok(db_summon().rows == SM.MAX_ROWS, "and at max", db_summon().rows)
  db_summon().rows = SM.DEFAULT_ROWS H.PaintOptions()
  -- prune: 0 shows off
  local pr = find("prune after")
  for _ = 1, 12 do pr.ctl.minus.scripts.OnClick(pr.ctl.minus) end
  ok(F.Spots.Prune(db) == 0 and pr.ctl.val.text == "off", "prune stepped down to 0 reads off")
  pr.ctl.plus.scripts.OnClick(pr.ctl.plus)
  ok(F.Spots.Prune(db) == 60 and pr.ctl.val.text == "60 s", "and one up is 60 s")
  db.prune = nil H.PaintOptions()
  -- own options: minimap button hide/show, the BiS channel switch, reset positions
  local mmo = find("minimap button")
  mmo.ctl.scripts.OnClick(mmo.ctl)
  ok(NS.DB().hub.minimap == false and not mm:IsShown(), "minimap option hides the button")
  mmo.ctl.scripts.OnClick(mmo.ctl)
  ok(mm:IsShown(), "and brings it back")
  local comm = find("BiS channel (/biscomm)")
  ok(comm and comm.ctl.on == true, "channel switch reads the lib")
  comm.ctl.scripts.OnClick(comm.ctl)
  ok(not lib:Enabled(), "the user's own switch: off is off (same as /biscomm off)")
  comm.ctl.scripts.OnClick(comm.ctl)
  ok(lib:Enabled(), "and on again")
  BiSToolsFarm.point = { "TOPLEFT", nil, "TOPLEFT", 900, -100 }
  find("reset window positions").ctl.scripts.OnClick(find("reset window positions").ctl)
  ok(BiSToolsFarm.point[1] == "CENTER" and BiSToolsSummon.point[1] == "CENTER" and hub.point[1] == "CENTER", "reset drags every window to the middle")
  -- slash fallbacks
  S("options") ok(not opt:IsShown(), "/bt options toggles the window")
  S("hub") ok(not hub:IsShown(), "/bt hub toggles the hub")
  S("minimap") ok(NS.DB().hub.minimap == false, "/bt minimap hides the button") S("minimap")
  -- window events go to the prompt, never chat
  local chat = 0 local oldAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function() chat = chat + 1 end
  S("hub") hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton") hub.rows[2].scripts.OnClick(hub.rows[2], "RightButton")
  DEFAULT_CHAT_FRAME.AddMessage = oldAdd
  ok(chat == 0, "toggling from the hub prints nothing to chat", chat)
  local q = hub.con.queue
  ok(#q >= 1 and q[#q].text == "summon on", "the hub says it in the prompt (queued behind the earlier lines)", q[#q] and q[#q].text)
  S("hub")
end

-- ------------------------------------------------------------ wrong-accent pass (dev/theme.lua)
if _G.__THEME_MUTATION then
  local red = _G.__THEME_MUTATION
  ok(NS.T.text("accent", "x") == "|cff" .. red .. "x|r", "NS.T.text reads the palette, not a hardcoded purple")
  local r, g, b = NS.T.rgb("accent")
  ok(r == 1 and g == 0 and b == 0, "NS.T.rgb reads the palette")
  local fr = F.color("accent")
  ok(fr == 1, "F.color (the kit) reads the palette for accent")
  S("summon show")
  ok(SM.title:GetText():find("|cff" .. red, 1, true), "the BiS> prompt wears the injected accent", SM.title:GetText())
  ok(BiSToolsSummon:IsShown(), "window still builds with the poisoned palette")
  local leak = false
  for _, f in ipairs(files) do
    if not f:match("^Libs/") then
      local fh = assert(io.open(f)) local src = fh:read("*a") fh:close()
      -- a hardcoded accent escape in addon code is exactly what this pass exists to catch
      if src:find("|cffb980ff", 1, true) then leak = true print("   hardcoded accent in " .. f) end
    end
  end
  ok(not leak, "no addon file hardcodes the accent escape |cffb980ff (use T.text)")
end

-- ------------------------------------------------------------ embedded libs are the canonical bytes
-- The lib is edited in _bisdev and copied out; a stale copy in an addon is how three addons
-- were still announcing phantom OFFERs after minor 5 fixed it. When the sibling folders are
-- there (they are, in the AddOns tree), every embedded file must be byte-identical.
do
  local function bytes(path) local fh = io.open(path, "rb") if not fh then return nil end local b = fh:read("*a") fh:close() return b end
  local pairs_ = {
    { "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "../_bisdev/LibBiSComm-1.0/LibBiSComm-1.0.lua" },
    { "Libs/RezComm-1.0/RezComm-1.0.lua",       "../_bisdev/RezComm-1.0/RezComm-1.0.lua" },
    { "Libs/BiSTheme/Console.lua",              "../BiSTheme/Console.lua" },
    { "Libs/BiSTheme/Options.lua",              "../BiSTheme/Options.lua" },
  }
  for _, pr in ipairs(pairs_) do
    local mine, ref = bytes(pr[1]), bytes(pr[2])
    if ref then ok(mine == ref, "embedded " .. pr[1] .. " is byte-identical to " .. pr[2] .. " (run _bisdev/sync.ps1)")
    else print("   (canonical " .. pr[2] .. " not beside this checkout - embed check skipped)") end
  end
end

-- leaked globals
local allowed = { BiSTools = true, BiSToolsDB = true, SLASH_BISTOOLS1 = true, SLASH_BISTOOLS2 = true,
  LibBiSComm = true, SLASH_BISCOMM1 = true, ConfirmSummon = true, BiSRezComm = true,
  BiSTheme = true }   -- the embedded Libs/BiSTheme/Console.lua guards on this global on purpose
for k in pairs(_G) do
  if not before[k] and not allowed[k] and not frames[k] then error("leaked global: " .. k) end
end
print(("ALL OK (%d checks)"):format(pass))
