-- BiSTools headless harness. Run from the addon root:  lua5.1 dev/tests.lua
-- ------------------------------------------------------------ WoW mock
local W = { combat = false, target = nil, plates = {}, marks = {}, now = 0 }
_G.__W = W
_G.GetAddOnMetadata = function() return "test" end
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
  local function nm(u) if u == "player" then return "Me" end local i = u:match("^raid(%d+)$") return i and W.raid[tonumber(i)] and W.raid[tonumber(i)].name end
  return nm(a) == nm(b)
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
_G.IsShiftKeyDown = function() return false end
W.messages = {}
function W.sentCount(needle) local n = 0 for _, m in ipairs(W.messages) do if m:find(needle, 1, true) then n = n + 1 end end return n end
_G.C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chan) W.messages[#W.messages + 1] = msg end }
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
  function s:SetFont() end
  function s:SetPoint(p, rel, rp, x, y) if type(rel) == "number" then self.x = rel else self.x = x end end
  function s:ClearAllPoints() end
  function s:SetText(x) self.text = x end
  function s:SetTextColor(r, g, b, a)
    if not num3(r, g, b) then error("SetTextColor wants r,g,b numbers") end
    self.color = { r, g, b, a }
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
  function f:IsMouseOver() return false end
  function f:GetParent() return self.parent end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  function f:CreateTexture() return Texture() end
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
    if t == "target" then W.target = W.plates[self.attrs.unit]
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

-- ------------------------------------------------------------ load
local before = {} for k in pairs(_G) do before[k] = true end
local NS = {}
local files = { "Libs/LibBiSComm-1.0/LibBiSComm-1.0.lua", "Core/Init.lua", "Core/Registry.lua", "Core/Slash.lua", "Tools/TargetFarming.lua", "Tools/FarmSpots.lua", "Tools/Summon.lua" }
local handlers = {}
local realCF = _G.CreateFrame
_G.CreateFrame = function(...)
  local f = realCF(...)
  local ss = f.SetScript
  f.SetScript = function(self, k, fn) ss(self, k, fn) if k == "OnEvent" then handlers[#handlers + 1] = fn end end
  return f
end
for _, f in ipairs(files) do assert(loadfile(f))("BiSTools", NS) end
local core = handlers[1]
core(nil, "ADDON_LOADED", "BiSTools")
core(nil, "PLAYER_LOGIN")
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
ok(lib and lib.MINOR == 2 and lib._booted, "LibBiSComm 1.0 minor 2 loaded and booted from Core/Init")
ok(lib.addons.BiSTools == "test", "BiSTools registered itself with the lib")
ok(lib:Enabled() and BiSToolsDB.comm == nil, "comm on by default, nothing persisted yet")
ok(NS.Registry:Get("summon") and NS.Registry:Enabled("summon"), "summon tool registered and on")
ok(BiSToolsSummon and not BiSToolsSummon:IsShown(), "summon window built, hidden (auto mode)")

-- the hard rule: the tool toggle never touches the lib
S("summon show") ok(BiSToolsSummon:IsShown() and db_summon().mode == "on", "/bt summon show pins it")
S("off summon")
ok(not BiSToolsSummon:IsShown(), "off: window gone")
ok(lib:Enabled() and next(SM.nagFrame.events) ~= nil, "off: lib still on, nag still listening")
S("on summon") ok(BiSToolsSummon:IsShown(), "on: window back (mode was on)")

-- /bis off is the user's own switch, and BiSTools remembers it
SlashCmdList.BISCOMM("off")
ok(not lib:Enabled(), "/bis off mutes the lib")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == false, "logout persists the off switch")
SlashCmdList.BISCOMM("on")
core(nil, "PLAYER_LOGOUT")
ok(BiSToolsDB.comm == true and lib:Enabled(), "/bis on persists too")

-- the only raid that exists: Tools-only, Innervate-only, Gamba-only, and a man with nothing
W.raid = {
  { name = "Me" },
  { name = "Toolsy",  zone = "Netherstorm", x = 1000, y = 1000, inst = 530 },
  { name = "Druid",   zone = "Netherstorm", x = 1300, y = 1000, inst = 530 },
  { name = "Gambler", zone = "Netherstorm", x = 1000, y = 1400, inst = 530 },
  { name = "Nolib",   zone = "Netherstorm", x = 1000, y = 1200, inst = 530 },
  { name = "Farzone", zone = "Shattrath City", x = nil, y = nil, inst = nil },
}
W.me = { zone = "Netherstorm", x = 1000, y = 1000, inst = 530 }
W.inRaid = true
local function say(from, line) lib:OnMessage("BiS", line, "RAID", from) end
say("Toolsy",  "1|CORE|HI|1|BiSTools=0.1.0|0")
say("Druid",   "1|CORE|HI|1|BiSInnervate=3.3.5|0")
say("Gambler", "1|CORE|HI|1|BiSGamba=1.1.0|0")
ok(lib:HasLib("Toolsy") and lib:HasLib("Druid") and lib:HasLib("Gambler"), "three clients with any BiS addon are peers")
ok(not lib:HasLib("Nolib") and not lib:HasLib("Farzone"), "the addon-less man never becomes a peer")
say("Toolsy",  "1|CORE|WHERE|0|none||Netherstorm|1000.0|1000.0|530")
say("Druid",   "1|CORE|WHERE|0|none||Netherstorm|1300.0|1000.0|530")
say("Gambler", "1|CORE|WHERE|1|raid|Karazhan|Karazhan|100.0|100.0|532")

S("summon near 80")
SM.Refresh(db_summon())
local list, inside = SM.list, SM.inside
local byName = {}
for _, e in ipairs(list) do byName[e.name] = e end
ok(inside == 1 and byName.Gambler and byName.Gambler.inside and list[#list].name == "Gambler", "Gambler says he is inside Karazhan -> 'inside', last row, no blacklist needed")
ok(byName.Toolsy == nil, "Toolsy stands on us (0 y, visible) -> not a candidate")
ok(byName.Druid and byName.Druid.fact and math.abs(byName.Druid.score - 300) < 1e-6, "Druid is a fact at 300 y from his own WHERE")
ok(byName.Nolib and not byName.Nolib.fact and math.abs(byName.Nolib.score - 200) < 1e-6, "Nolib is a guess at 200 y from UnitPosition")
ok(byName.Farzone and not byName.Farzone.fact and byName.Farzone.score == SM.SCORE_OTHER_ZONE, "Farzone: other zone by the roster string")
ok(list[1].name == "Farzone" and list[2].name == "Druid" and list[3].name == "Nolib" and list[4].name == "Gambler", "furthest first, inside last")
-- paint: fact plain, guess with a ?
ok(BiSToolsSummonRow1.name.text == "Farzone ?" and BiSToolsSummonRow2.name.text == "Druid" and BiSToolsSummonRow3.name.text == "Nolib ?", "guess rows wear the question mark, fact rows do not")
ok(BiSToolsSummonRow2.info.text == "" and BiSToolsSummonRow1.info.text == "far" and BiSToolsSummonRow4.info.text == "inside", "info text: no yards away from a stone, far, inside")
ok(BiSToolsSummonRow1.template == "SecureActionButtonTemplate" and BiSToolsSummonRow1.clicks == "AnyDown", "rows are secure, AnyDown")
ok(BiSToolsSummonRow1:GetAttribute("*type1") == "target" and BiSToolsSummonRow1:GetAttribute("*unit1") == "raid6", "row targets its unit")
ok(BiSToolsSummonRow1:GetAttribute("shift-type1") == "" and BiSToolsSummonRow1:GetAttribute("type2") == nil and BiSToolsSummonRow1:GetAttribute("*type2") == nil, "shift kills the click, no type2 anywhere")
ok(BiSToolsSummon.h == 16 + 4 * 14 + 4 + 12 + 16, "four rows tall, status line (1 in), request footer")
-- header overlap guard: nothing but title + buttons lives in the header
ok(SM.count.parent == SM.body, "the count line lives under the rows, not in the header")
ok(SM.jeckBtn.point[4] == -52 and SM.askBtn.point[4] == -31 and SM.pinBtn.point[4] == -17 and SM.closeBtn.point[4] == -3, "header buttons at their computed slots")

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
ok(SM.inside == 2 and #SM.list == 4 and SM.list[4].inside and SM.list[3].inside, "Nolib in Karazhan by roster string -> inside (the old guess)")
W.raid[5].zone = "Netherstorm"

-- fact outranks guess at equal score
W.raid[5].x, W.raid[5].y = 1300, 1000
SM.Refresh(db_summon())
ok(SM.list[2].name == "Druid" and SM.list[3].name == "Nolib", "equal 300 y: the fact sorts above the guess")
W.raid[5].x, W.raid[5].y = 1000, 1200

-- click = park. A fact parks 15 s (their client will report the offer), a guess 120 s
W.now = 5000
BiSToolsSummonRow1:Click()   -- Farzone, a guess
ok(SM.tried.Farzone and math.abs(SM.tried.Farzone - (5000 + 120)) < 1e-6, "clicking a guess parks 120 s")
ok(SM.list[1].name == "Druid" and SM.list[3].name == "Farzone" and BiSToolsSummonRow3.info.text == "2:00", "parked guess sinks with its clock (above inside)")
BiSToolsSummonRow1:Click()   -- Druid, a fact
ok(SM.tried.Druid and math.abs(SM.tried.Druid - (5000 + 15)) < 1e-6, "clicking a fact parks only 15 s")
ok(SM.list[1].name == "Nolib", "Nolib is top now")

-- the peer's own word replaces the park: OFFER with 60 s left, then NO pops him back that second
say("Druid", "1|CORE|SUM|OFFER|Me|Karazhan|60")
ok(SM.tried.Druid == nil, "a SUM from the peer clears our park")
local d
for _, e in ipairs(SM.list) do if e.name == "Druid" then d = e end end
ok(d and d.why == "offer" and math.abs(d.waiting - 60) < 1e-6, "Druid waits on his real 60 s offer")
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
ok(SM.count.text:find("2 at stone"), "status line counts them")
-- I am at the stone: yards show now (Farzone stays far)
local fz
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Farzone") then fz = r end end
ok(fz and fz.info.text == "far", "other zone still 'far' at the stone")
W.raid[5].x, W.raid[5].y = 1000, 1200 SM.Refresh(dbs)
local nb
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "200y", "at the stone: yards from the stone")
W.me.x, W.me.y = 5000, 5000 W.now = W.now + 5 SM.Refresh(dbs)
for i = 1, 4 do local r = _G["BiSToolsSummonRow" .. i] if r and r.shown and r.name.text:find("Nolib") then nb = r end end
ok(nb and nb.info.text == "", "away from the stone: no yards")
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
S("on summon")
S("summon hide")

-- drag saves point + relative point
BiSToolsFarm.scripts.OnDragStop(BiSToolsFarm)
ok(db.pos[1] == "TOPLEFT" and db.pos[4] == "CENTER" and db.pos[2] == 12, "drag saves position")

-- leaked globals
local allowed = { BiSTools = true, BiSToolsDB = true, SLASH_BISTOOLS1 = true, SLASH_BISTOOLS2 = true,
  LibBiSComm = true, SLASH_BISCOMM1 = true, ConfirmSummon = true }
for k in pairs(_G) do
  if not before[k] and not allowed[k] and not frames[k] then error("leaked global: " .. k) end
end
print(("ALL OK (%d checks)"):format(pass))
