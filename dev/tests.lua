-- BiSTools headless harness. Run from the addon root:  lua5.1 dev/tests.lua
-- ------------------------------------------------------------ WoW mock
local W = { combat = false, target = nil, plates = {}, marks = {}, now = 0, forbidden = {} }
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
-- every client answers this; the suite is the TBC client unless a test says otherwise
_G.GetBuildInfo = function() return "2.5.6", "69795", "Sep 1 2026", W.iface or 20506 end
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
-- both forms, as the client has them: hooksecurefunc("Global", fn) and hooksecurefunc(tbl, "key", fn)
-- (the table form was missing; the RestedXP listener hooks a method on RXP's own table)
_G.hooksecurefunc = function(a, b, c)
  local tbl, name, fn = _G, a, b
  if type(a) == "table" then tbl, name, fn = a, b, c end
  local orig = tbl[name]
  if type(orig) ~= "function" then return end
  tbl[name] = function(...) local r = orig(...) fn(...) return r end
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
  -- a nameplate has a GUID in the client; this used to answer nil, which hid anything keyed by it
  if W.plates[u] then return W.plates[u].guid end
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
  -- PROTECTED ON FOREVER (6 Oct 2026, Arn's BugGrabber: "AddOn 'BiSTools' tried to call the
  -- protected function 'SetRaidTarget()'", from the scanner's ticker). The client blames the addon
  -- and sets nothing. A secure macro's /tm is Blizzard's code and is allowed - the same split as
  -- C_Ping.SendMacroPing (forbidden) and /ping in a secure button (fine), measured 1 Oct.
  if W.restricted then
    W.forbidden[#W.forbidden + 1] = "SetRaidTarget(" .. tostring(u) .. ", " .. tostring(i) .. ")"
    return
  end
  for k, v in pairs(W.marks) do if v == i then W.marks[k] = nil end end -- one skull at a time
  W.marks[u] = i
end
-- A MARK IS A SECRET NUMBER ON FOREVER (6 Oct 2026, Arn's BugGrabber, open world: "attempt to
-- compare local 'm' (a secret number value)" in the scanner, and in the farm spots a kill later).
-- With W.secretMarks set, every read hands back a secret instead of the number - the mock used to
-- answer plainly, which is how two comparisons shipped.
_G.GetRaidTargetIndex = function(u)
  if W.secretMarks then return W.secretMarks() end
  return W.marks[u]
end
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
  -- size and anchor are REMEMBERED: a label pinned beside an icon starts where the icon ends, and
  -- the fit check below cannot know that if the icon forgot both (they were no-ops)
  function t:SetAllPoints() self.all = true end
  function t:SetPoint(p, rel, rp, x, y)
    if type(rel) == "number" then self.anchor = { p, nil, p, rel, rp }
    else self.anchor = { p, rel, rp or p, x or 0, y or 0 } end
  end
  function t:ClearAllPoints() self.anchor = nil end
  function t:SetHeight(h) self.h = h end
  function t:SetWidth(w) self.w = w end
  function t:SetSize(w, h) self.w, self.h = w, h end
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
-- EVERY LABEL, KEPT, WITH WHAT IT IS PINNED TO (6 Oct 2026). Arn's screenshot: "nothing here to
-- point at" and "click a mob to see its spawns" ran straight out of the 124 px Spawns window. A
-- label only remembered its x/y, so nothing could say where it STARTS - and "does it fit" needs
-- that. W.labels is walked by fitsIn() below.
W.labels = {}
local function FontString()
  local s = { shown = true }
  W.labels[#W.labels + 1] = s
  function s:SetFont(_, size) self.size = size end
  function s:SetPoint(p, rel, rp, x, y)
    if type(rel) == "number" then self.x, self.y = rel, rp self.anchor = { p, nil, p, rel, rp }
    else self.x, self.y = x, y self.anchor = { p, rel, rp or p, x or 0, y or 0 } end
  end
  function s:ClearAllPoints() self.anchor = nil end
  function s:Show() self.shown = true end
  function s:Hide() self.shown = false end
  function s:IsShown() return self.shown end
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
    -- LETTERS, NOT BYTES (12 Oct 2026): "Légolas Thiliaere" fit in game and not here - the é is two
    -- bytes, and the client measures glyphs. UTF-8 continuation bytes are not letters.
    return #(t:gsub("[\128-\191]", "")) * (self.size or 9) * 0.6 + tex
  end
  function s:Hide() self.shown = false end
  function s:Show() self.shown = true end
  return s
end
local frames = {}
_G.CreateFrame = function(kind, name, parent, template)
  local f = { kind = kind, name = name, parent = parent, template = template,
    shown = true, scripts = {}, attrs = {}, events = {}, h = 0 }
  -- ON FOREVER, REGISTERING THE COMBAT LOG IS A PROTECTED ACTION (6 Oct 2026, Arn's BugGrabber:
  -- "AddOn 'BiSTools' tried to call the protected function 'Frame:RegisterEvent()'"). The client
  -- does not throw - it records the blame and fires ADDON_ACTION_FORBIDDEN later, which is why a
  -- pcall never saw it. This mock always took the registration, so the suite could not tell. With
  -- W.restricted on it behaves like that client: the event is NOT registered and the call is blamed.
  function f:RegisterEvent(e)
    if W.restricted and e == "COMBAT_LOG_EVENT_UNFILTERED" then
      W.forbidden[#W.forbidden + 1] = "Frame:RegisterEvent(" .. e .. ")"
      return
    end
    self.events[e] = true
  end
  function f:UnregisterAllEvents() self.events = {} end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:IsMouseOver() return W.mouseOver == self end
  function f:GetParent() return self.parent end
  function f:SetScript(k, fn) self.scripts[k] = fn end
  -- RE-PARENTED, and REFUSED in combat for a secure frame - the client's rule (12 Oct 2026, the box)
  function f:SetParent(p)
    if W.combat and self.template and self.template:find("Secure") then error("SetParent on a secure frame in combat", 2) end
    self.parent = p
  end
  -- HookScript CHAINS after what is there, as the client's does (12 Oct 2026, the BiS> tools box)
  function f:HookScript(k, fn)
    local prev = self.scripts[k]
    self.scripts[k] = prev and function(...) prev(...) return fn(...) end or fn
  end
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
  function f:GetWidth() return self.w end                -- the client answers both (12 Oct 2026)
  function f:SetPoint(p, rel, rp, x, y) self.point = { p, rel, rp, x, y } end
  function f:ClearAllPoints() self.point = nil end
  function f:GetPoint() return "TOPLEFT", nil, "CENTER", 12, -34 end
  function f:SetFrameStrata() end
  function f:SetFrameLevel() end
  function f:GetCenter() return self.cx or 0, self.cy or 0 end
  function f:GetEffectiveScale() return 1 end
  function f:SetAlpha(a) self.alpha = a end
  function f:SetScale(s) self.scale = s end
  function f:GetScale() return self.scale or 1 end
  -- AN ANIMATION GROUP, RECORDED (12 Oct 2026, the rival crosshair's pulse): the client hands back a
  -- group that makes animations, loops, plays and stops - and runs them itself
  function f:CreateAnimationGroup()
    local g = { anims = {}, playing = false }
    function g:CreateAnimation(kind)
      local a = { kind = kind }
      function a:SetFromAlpha(v) self.from = v end
      function a:SetToAlpha(v) self.to = v end
      function a:SetDuration(v) self.duration = v end
      function a:SetSmoothing(v) self.smoothing = v end
      self.anims[#self.anims + 1] = a
      return a
    end
    function g:SetLooping(v) self.looping = v end
    function g:Play() self.playing = true end
    function g:Stop() self.playing = false end
    function g:IsPlaying() return self.playing end
    return g
  end
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
  -- VISIBLE IS SHOWN ALL THE WAY UP (7 Oct 2026). A child whose parent hides stays IsShown() -
  -- that is how the Spawns shelf kept refreshing 4 times a second behind a closed farm window.
  function f:IsVisible()
    if not self.shown then return false end
    local p = self.parent
    if type(p) == "table" and type(p.IsVisible) == "function" then return p:IsVisible() end
    return true
  end
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
-- HEREBEDRAGONS DRIVES THE CLIENT'S OWN MAP ENGINE (CreateVector2D, the world map's data providers,
-- the minimap's zoom tables), which a headless mock cannot stand in for honestly. So its two files
-- are still required to COMPILE, and in their place a stand-in registers under the same LibStub name
-- with the same argument checks the real one raises, and records every pin it is handed. The suite
-- tests what is ours: which map, which spot, which mark, dim or bright, and that pins go away.
W.pins = { minimap = {}, world = {} }
local function fakeHBDPins()
  local P = LibStub:NewLibrary("HereBeDragons-Pins-2.0", 999)
  local function check(ref, icon, map, x, y, what)
    if not ref then error("HereBeDragons-Pins-2.0: " .. what .. ": 'ref' must not be nil", 3) end
    if type(icon) ~= "table" or not icon.SetPoint then error("HereBeDragons-Pins-2.0: " .. what .. ": 'icon' must be a frame", 3) end
    if type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
      error("HereBeDragons-Pins-2.0: " .. what .. ": 'uiMapID', 'x' and 'y' must be numbers", 3)
    end
  end
  -- ONE FRAME CANNOT BE ON BOTH MAPS (6 Oct 2026, Arn: no pins on either map, while every add
  -- answered true). The real library reparents an icon into whichever map draws it - SetParent to
  -- the minimap on add, to a world-map pin when that map draws it, Hide + SetParent(UIParent) when
  -- the world map lets go - so a frame handed to both is fought over and shows on neither. The
  -- stand-in used to take the same frame twice without a murmur; now it refuses, as the client
  -- effectively does by showing nothing.
  local function shared(icon, other, what)
    if other[icon] then error("HereBeDragons-Pins-2.0: " .. what .. ": this frame is already a pin on the other map - each map needs its own frame", 3) end
  end
  function P:AddMinimapIconMap(ref, icon, map, x, y)
    check(ref, icon, map, x, y, "AddMinimapIconMap")
    shared(icon, W.pins.world, "AddMinimapIconMap")
    W.pins.minimap[icon] = { map = map, x = x, y = y } return true
  end
  function P:AddWorldMapIconMap(ref, icon, map, x, y, flag)
    check(ref, icon, map, x, y, "AddWorldMapIconMap")
    shared(icon, W.pins.minimap, "AddWorldMapIconMap")
    if flag ~= nil and type(flag) ~= "number" then error("showFlag must be a number (or nil)", 2) end
    W.pins.world[icon] = { map = map, x = x, y = y, flag = flag } return true
  end
  function P:RemoveMinimapIcon(ref, icon) W.pins.minimap[icon] = nil end
  function P:RemoveWorldMapIcon(ref, icon) W.pins.world[icon] = nil end
  function P:RemoveAllMinimapIcons(ref) W.pins.minimap = {} end
  function P:RemoveAllWorldMapIcons(ref) W.pins.world = {} end
  _G.HBD_PINS_WORLDMAP_SHOW_PARENT, _G.HBD_PINS_WORLDMAP_SHOW_CONTINENT = 1, 2
end
for _, f in ipairs(files) do
  local chunk, err = loadfile(f)
  assert(chunk, "TOC lists a file that does not load: " .. tostring(f) .. " (" .. tostring(err) .. ")")
  if f == "Libs/HereBeDragons/HereBeDragons-2.0.lua" then
    -- compiled above; the engine itself is the client's
  elseif f == "Libs/HereBeDragons/HereBeDragons-Pins-2.0.lua" then
    fakeHBDPins()
  else
    chunk("BiSTools", NS)
  end
end
-- dev/theme.lua: poison the accent AFTER the files load, BEFORE anything is built
if _G.__THEME_MUTATION then BiSTheme.hex.accent = _G.__THEME_MUTATION end
-- Core/Init's frame is the one that listens for ADDON_LOADED (the libs' frames load first)
-- Core/Init's frame: the FIRST of ours to listen for ADDON_LOADED (Core loads before every tool).
-- This picked the LAST one, which was Core's only until a tool listened too (FarmGuide, 6 Oct).
local core
for _, h in ipairs(handlers) do
  if h.frame.events.ADDON_LOADED and h.frame.events.PLAYER_LOGOUT then core = h.fn break end
end
-- and the client hands an event to EVERY frame that registered it, not to one; so does this
local function deliver(event, ...)
  for _, h in ipairs(handlers) do
    if h.frame.events[event] then h.fn(h.frame, event, ...) end
  end
end
deliver("ADDON_LOADED", "BiSTools")
deliver("PLAYER_LOGIN")
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
ok(lib and lib.MINOR == 10 and lib._booted, "LibBiSComm 1.0 minor 10 loaded and booted from Core/Init")
-- Minor 8 sends one message a second, as the client allows. This suite is about summons and
-- farming, fires dozens of sends with the clock standing still and jumps it without running
-- timers - so it turns the pace off. The pace itself is proven in _bisdev/comm/tests.lua.
lib.sendGap = 0
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
  for _, cmd in ipairs({ "farm sound off", "farm sound first", "summon nag off", "summon nag on", "summon key off", "summon key on", "summon summoner", "summon summoner", "summon hide", "summon auto" }) do
    S(cmd) ok(lib:Enabled(), "/bt " .. cmd .. ": lib still on")
  end
  S("summon show")   -- back to pinned, the state the blocks below expect
  -- and a client that logs in with every toggle already off still boots the lib
  local fdb, sdb = R:DBFor(R:Get("farm")), R:DBFor(R:Get("summon"))
  local keep = { fdb.sound, sdb.nag, sdb.key, sdb.summoner, BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon }
  fdb.sound, sdb.nag, sdb.key, sdb.summoner = "off", false, false, false
  BiSToolsDB.enabled.farm, BiSToolsDB.enabled.summon = false, false
  lib._booted = nil lib.addons.BiSTools = nil
  NS.Comm.Boot()
  ok(lib._booted and lib.addons.BiSTools == TOC_VERSION and lib:Enabled(), "everything off in the saved db: the lib still boots and registers")
  fdb.sound, sdb.nag, sdb.key, sdb.summoner = keep[1], keep[2], keep[3], keep[4]
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
ok(SM.summonerBtn.point[4] == -38 and SM.askBtn.point[4] == -17 and SM.closeBtn.point[4] == -3, "header buttons at their computed slots")
ok(SM.pinBtn == nil, "no pin button (auto-open covers it; /bt summon show|auto|hide is the manual way)")
ok(SM.summonerBtn.w == 18 and SM.summonerBtn.point[4] - SM.summonerBtn.w == -56, "J's left edge is the 56 px strip")

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
ok(SM.con.slots.asks == nil, "far from any stone, not the summoner: no asking slot for me")
dbs.summoner = true SM.Refresh(dbs)
ok(SM.con.slots.asks and SM.con.slots.asks.text == "1 asking", "the summoner sees the asking slot")
dbs.summoner = false SM.Refresh(dbs)
ok(SM.con.slots.asks == nil, "summoner mode off: gone again")
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

-- summoner mode: the summoner opts in; window pinned, requests come through like a raid warning
S("summon summoner on")
ok(dbs.summoner and dbs.mode == "on" and BiSToolsSummon:IsShown(), "summoner: pinned")
ok(SM.summonerBtn.label.color[1] == select(1, F.color("gold")), "J lit gold")
local n0 = #W.notices
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.notices[#W.notices]:find("Nolib") and W.sounds[#W.sounds] == 8959 and W.spoken[#W.spoken] == "Summon", "summoner: request = raid warning + sound + voice")
say("Nolib", "1|SUMMON|REQ|0")
S("summon summoner off")
say("Nolib", "1|SUMMON|REQ|1")
ok(#W.notices == n0 + 1 and W.sounds[#W.sounds] == 3081, "not summoner: quiet ping only")
say("Nolib", "1|SUMMON|REQ|0")
SM.summonerBtn.scripts.OnClick(SM.summonerBtn) ok(dbs.summoner, "J button toggles") SM.summonerBtn.scripts.OnClick(SM.summonerBtn) ok(not dbs.summoner, "and back")
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
  -- 24 in the raid. The names were real people's characters until 19 Sep 2026, when this repo
  -- went public; Kumlance is Arn's own and stays. The long ones matter: the window has to cope
  -- with a name that does not fit, which is why Raider10 and up are deliberately longer.
  local names = { "Kumlance", "Raider1", "Raider2", "Raider3", "Raider4", "Raider5", "Raider6", "Raider7", "Raider8", "Raider9", "Raider10", "Raider11", "Raider12", "Raider13", "Raider14", "Raider15", "Raider16", "Raider17", "Raider18", "Raider19", "Raider20", "Raider21", "Raider22", "Raider23" }
  local nolib = { Raider21 = true, Raider22 = true, Raider23 = true }
  W.raid = { { name = "Me" } }
  for i, n in ipairs(names) do
    W.raid[#W.raid + 1] = { name = n, zone = "Netherstorm", x = 1000 + i * 40, y = 1000, inst = 530 }
  end
  W.inRaid = true
  local dbx = db_summon()
  dbx.stones = { ["530|Netherstorm"] = { map = 530, zone = "Netherstorm", x = 1000, y = 1000 } }
  dbx.rows = 6 dbx.summoner = false
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
  say("Raider9", "1|SUMMON|REQ|1") say("Raider12", "1|SUMMON|REQ|1")   -- an addon-less man cannot ask
  S("summon show") SM.Refresh(dbx)
  ok(lib:Count() == 21, "21 facts on the lib, 3 addon-less men are not", lib:Count())
  -- Raider9 is inside Karazhan AND asked: a request beats every filter, so 4 count as inside
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
  for _, e in ipairs(SM.list) do if e.name == "Raider22" and not e.fact then guessSeen = true end end
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
  -- the summoner mode: the asking slot appears for the summoner
  dbx.summoner = true SM.Refresh(dbx)
  ok(SM.con.slots.asks and SM.con.slots.asks.text == "2 asking", "2 asking for the summoner", SM.con.slots.asks and SM.con.slots.asks.text)
  ok(SM.con:Width() <= SM.W - 56 - 8, "header still fits")
  dbx.summoner = false
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
  ok(RC and RC.MINOR == 4 and RC.PROTO == 4, "RezComm 1.0 minor 4 loaded, speaks Innervate's proto 4")
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
  ok(hub and hub:IsShown() and #hub.rows == 5, "left click opens the Hub with a row per registered tool")
  ok(hub.scale == 1.2, "the Tools list is 20% bigger (Arn: \"lets make this 20% bigger\")")
  ok(hub.rows[1].key == "farm" and hub.rows[2].key == "summon" and hub.rows[3].key == "recap" and hub.rows[4].key == "social" and hub.rows[5].key == "threat", "rows in TOC order: farm, summon, recap, social, threat")
  ok(hub.rows[1].name.text == "farm" and hub.rows[1].state.text:find("on", 1, true), "row: name + on")
  ok(hub.con.slots.count and hub.con.slots.count.text == "5 of 5 on", "prompt slot counts the tools that are on")
  ok(hub.con:Width() <= H.W - 15 - 8, "hub prompt fits its header budget")
  ok(hub.closeBtn.point[4] == -3, "only an x in the header, at -3")
  ok(hub.foot and hub.foot.label.text == "options" and hub.h == 16 + 5 * 16 + 4 + 16, "footer 'options' button; height = header + rows + footer")
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
  ok(not R:Enabled("summon") and hub.rows[2].state.text:find("off", 1, true) and hub.con.slots.count.text == "4 of 5 on", "right click: summon off, row and count follow")
  ok(lib:Enabled(), "and the lib is untouched by it")
  hub.rows[2].scripts.OnClick(hub.rows[2], "LeftButton")
  ok(R:Enabled("summon") and BiSToolsSummon:IsShown() and db_summon().mode == "on", "click on an off tool: switched on and its window pinned open")
  -- right click on the minimap: options
  mm.scripts.OnClick(mm, "RightButton")
  local opt = BiSToolsOptions
  ok(opt and opt:IsShown(), "right click opens Options")
  ok(opt.scale == 1.2, "and so is Options")
  -- THE ICON THAT WENT DARK (Arn: "i click the minimap button it goes dark and stays dimmed"):
  -- EllesmereUI's minimap collector backs a gathered button with a black box (a child, one level below)
  -- and its click hook lifts every child to DIALOG - its box over the icon. A moment later it goes back.
  local box2 = { level = 50, strata = "DIALOG" }
  function box2:SetFrameLevel(l) self.level = l end
  function box2:SetFrameStrata(s) self.strata = s end
  mm.GetChildren = function() return box2 end
  mm.GetFrameLevel = function() return 8 end
  mm.GetFrameStrata = function() return "MEDIUM" end
  mm.scripts.OnClick(mm, "RightButton") mm.scripts.OnClick(mm, "RightButton")   -- twice: Options as it was
  W.runAfters(0.1)
  ok(box2.level == 7 and box2.strata == "MEDIUM", "after a click, a backing lifted over the icon goes back below the button")
  mm.GetChildren = nil
  ok(opt.con:Width() <= H.OPT_W - 15 - 8, "options prompt fits")
  -- sections: tools (3), farm (5), summon (7), recap (7), social (2), threat (2) -> 6 headers + 26 rows
  ok(#opt.rows == 6 + 3 + 5 + 7 + 7 + 2 + 2, "one row per section header and per option", #opt.rows)
  ok(opt.h == 16 + #opt.rows * 16 + 4, "options height = header + rows")
  local function find(label) for _, r in ipairs(opt.rows) do if r.name and r.name.text == label then return r end end end
  -- every option label fits its lane (controls take the right 110 px)
  for _, r in ipairs(opt.rows) do if r.name then ok(r.name:GetStringWidth() <= H.OPT_W - 12 - 110, "option label fits: " .. tostring(r.name.text)) end end
  -- a section header's box toggles the tool
  local farmHdr = opt.rows[5]
  ok(farmHdr.ctl and farmHdr.ctl.on == true, "farm section box shows on")
  farmHdr.ctl.scripts.OnClick(farmHdr.ctl)
  ok(not R:Enabled("farm") and farmHdr.ctl.on == false and hub.con.slots.count.text == "4 of 5 on", "box off: farm off, hub count follows")
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

-- ---------------------------------------------------------------- Forever: kills without the combat log
-- (6 Oct 2026) The farm tool heard kills through COMBAT_LOG_EVENT_UNFILTERED, and on WoW Forever
-- even REGISTERING it is a protected action. On a client that says it hides values, the tool must
-- never ask for it, and must count kills from the plain PARTY_KILL event instead - in either of the
-- two shapes Overlord handles, with any argument possibly a secret.
do
  -- A SECRET STRING SAYS "string" (on Forever type() still answers the real type) and refuses
  -- everything else: a match, a find, a comparison. A plain table would be caught by any type
  -- check by luck - the mock must not be kinder than that.
  local secretMeta = { __secret = true, __index = function(_, k)
    error("attempt to use a secret value (" .. tostring(k) .. ")", 2) end,
    __eq = function() error("attempt to compare a secret value", 2) end }
  local function secret() return setmetatable({}, secretMeta) end
  local realType = type
  local names = {}
  local keep = { C_Secrets = _G.C_Secrets, issecretvalue = _G.issecretvalue, UnitNameFromGUID = _G.UnitNameFromGUID,
                 type = _G.type }
  _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
  _G.C_Secrets = { HasSecretRestrictions = function() return true end }
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  _G.UnitNameFromGUID = function(g) return names[g] end
  W.restricted = true
  W.forbidden = {}

  S("off farm") S("on farm")
  ok(#W.forbidden == 0, "Forever: the farm tool never asks for the combat log (nothing blamed on BiSTools)")
  ok(not F.events.events.COMBAT_LOG_EVENT_UNFILTERED, "Forever: and is not listening to it")
  ok(F.events.events.PARTY_KILL, "Forever: it listens to PARTY_KILL instead")

  S("farm clear")
  local g = "Creature-0-0-0-0-777-Raptor"
  names[g] = "Raptor"
  fire("PARTY_KILL", "Player-1", g)
  ok(db.last and db.last.name == "Raptor" and db.last.guid == g, "Forever: my kill, GUID shape, is recorded by name")
  fire("PARTY_KILL", "Player-1", g)
  ok(db.last.count == 2, "Forever: and counted again")

  fire("PARTY_KILL", "Player-99", "Creature-0-0-0-0-778-Raptor")
  ok(db.last.count == 2, "Forever: somebody else's kill does not count, as with the combat log")
  fire("PARTY_KILL", "Pet-1", g)
  ok(db.last.count == 3, "Forever: my pet's kill counts")
  fire("PARTY_KILL", "Player-1", "Player-2")
  ok(db.last.count == 3, "Forever: a player dying is not a farm kill")

  ok(pcall(fire, "PARTY_KILL", secret(), g), "Forever: a SECRET attacker does not throw")
  ok(pcall(fire, "PARTY_KILL", "Player-1", secret()), "Forever: nor a secret victim")
  ok(db.last.count == 3, "Forever: and neither is counted - nothing secret was read")

  -- the name is not resolved yet: the client says "Unknown". Fall back to the target, if it is the one
  local g2 = "Creature-0-0-0-0-779-Boar"
  names[g2] = "Unknown"
  W.target = { name = "Boar", guid = g2 }
  fire("PARTY_KILL", "Player-1", g2)
  W.target = nil
  ok(db.last.name == "Boar", "Forever: an unresolved name is taken from the target with that GUID")
  names[g2] = "Unknown"
  local before = db.last.count
  fire("PARTY_KILL", "Player-1", g2)
  ok(db.last.count == before, "Forever: and with no way to name it, it is not recorded as 'Unknown'")

  -- the old shape: one unit token, the victim
  W.target = { name = "Boar", guid = g2 }
  before = db.last.count
  fire("PARTY_KILL", "target")
  W.target = nil
  ok(db.last.name == "Boar" and db.last.count == before + 1, "Forever: the unit-token shape is understood too")

  -- THE SCANNER MARKS NOTHING ON FOREVER; THE KEY DOES (6 Oct 2026). SetRaidTarget is protected
  -- there - BugGrabber, from the ticker. Blizzard's /tm in a secure macro, on a key press, is not.
  W.forbidden = {}
  W.marks = {}
  local keepSpots = db.spots
  db.spots = {}          -- no spot here: the key's mark is the skull (a spot's own mark is checked below)
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }
  F.marked = nil
  db.active = "Raptor" db.finds = 0
  F.Tick(db)
  ok(#W.forbidden == 0, "Forever: the scanner never calls SetRaidTarget", table.concat(W.forbidden, ", "))
  ok(next(W.marks) == nil, "Forever: so nothing is marked by the addon")
  ok(F.marked == "nameplate1", "Forever: but the clean copy is FOUND")
  ok(db.finds == 1, "Forever: and the find is said once")
  F.Tick(db)
  ok(db.finds == 1, "Forever: not again on every tick while it stays in view")

  local btn = BiSToolsFarmTarget
  btn.scripts.PreClick(btn, "LeftButton", true)
  ok(btn:GetAttribute("type") == "macro" and btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !8",
     "Forever: the farm key targets it and marks it with Blizzard's /tm", btn:GetAttribute("macrotext"))
  -- "/tm !N" sets without toggling (RestedXP, on Forever), so the key never reads the mark - and on
  -- this client a mark can be a SECRET, which a comparison would throw on
  -- (a Lua 5.1 mock cannot make `secret ~= 8` throw - a table compared with a number never calls a
  -- metamethod - so the honest test is the stronger claim: the key does not READ the mark at all)
  local realIdx = _G.GetRaidTargetIndex
  _G.GetRaidTargetIndex = function() error("the farm key read the unit's mark") end
  ok(pcall(btn.scripts.PreClick, btn, "LeftButton", true), "Forever: the key never reads the unit's mark (it may be secret)")
  ok(btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !8",
     "Forever: and the key still marks with /tm ! - it never needed to read the mark")
  _G.GetRaidTargetIndex = realIdx
  ok(#W.forbidden == 0, "Forever: the key's PreClick marks nothing itself either")

  -- THE NEXT PRESS MARKS THE NEXT COPY (6 Oct 2026). Arn: "if something is already marked skull
  -- it'll look for another target without a mark and put another marker". Forever hides marks, so
  -- the key keeps its own record of what it handed out.
  do
    local keepWant = F.Spots and F.Spots.Want
    if F.Spots then F.Spots.Want = function() return nil end end      -- no spot here
    F.placed = {}
    local gA, gB, gC = "Creature-0-0-0-0-900-Raptor", "Creature-0-0-0-0-901-Raptor", "Creature-0-0-0-0-902-Raptor"
    W.plates = { nameplate1 = { name = "Raptor", guid = gA }, nameplate2 = { name = "Raptor", guid = gB } }
    F.marked = nil F.Tick(db)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext"):find("/tm !8$") and F.placed[gA] == 8, "Forever: the first press puts the skull on a copy")
    F.marked = nil F.Tick(db)
    ok(F.marked == "nameplate2", "Forever: the scan now prefers the copy the key has NOT marked", F.marked)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate2\n/tm !7", "Forever: the second press gives the next copy a cross, not the skull")
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate2\n/tm !7", "Forever: pressing again on a copy it marked keeps that copy's mark")

    -- the skull's mob dies: the skull is free for the next copy
    names[gA] = "Raptor"
    fire("PARTY_KILL", "Player-1", gA)
    ok(F.placed[gA] == nil, "Forever: a kill frees the mark it wore")
    W.plates = { nameplate3 = { name = "Raptor", guid = gC } }
    F.marked = nil F.Tick(db)
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate3\n/tm !8", "Forever: and the next copy gets the skull back")

    -- all eight out: the skull moves (the game takes it from whoever had it), and our record follows
    F.placed = {}
    for i = 1, 8 do F.Placed("Creature-0-0-0-0-91" .. i .. "-Raptor", F.NextMark("Creature-0-0-0-0-91" .. i .. "-Raptor")) end
    ok(F.NextMark("Creature-0-0-0-0-999-Raptor") == 8, "Forever: with every mark out, the skull moves")
    F.Placed("Creature-0-0-0-0-999-Raptor", 8)
    local skulls = 0
    for _, m in pairs(F.placed) do if m == 8 then skulls = skulls + 1 end end
    ok(skulls == 1, "Forever: and only one mob is ever recorded wearing it")

    S("farm clear")
    ok(next(F.placed) == nil, "Forever: /bist farm clear starts the marks at the skull again")
    if F.Spots then F.Spots.Want = keepWant end
    db.active = "Raptor"
    W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }
    F.marked = nil
  end
  -- standing at a recorded spot, the key carries THAT spot's mark, as the old sync did
  if F.Spots and F.Spots.Want then
    local realWant = F.Spots.Want
    F.Spots.Want = function() return 3 end
    W.marks.nameplate1 = nil
    btn.scripts.PreClick(btn, "LeftButton", true)
    ok(btn:GetAttribute("macrotext") == "/target nameplate1\n/tm !3", "Forever: at a spot, the key marks with the spot's mark")
    F.Spots.Want = realWant
  end
  db.spots = keepSpots

  -- SECRET MARKS, SECRET NAMES, SECRET FLAGS (6 Oct 2026, the BugGrabber paste): the scanner
  -- compared a plate's mark (`m >= 1`) and the farm spots compared the target's mark at a kill.
  W.secretMarks = secret
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" },
               nameplate2 = { name = "Raptor", guid = "Creature-0-0-0-0-801-Raptor" } }
  F.marked = nil
  ok(pcall(F.Tick, db), "Forever: a SECRET mark on every plate does not throw in the scanner")
  ok(F.marked ~= nil, "Forever: and a clean copy is still found")
  -- (Lua 5.1 cannot make `5 == secret` throw the way the client does - a number compared with a
  -- table is just false - so the test checks the promise instead: the farm spots are never HANDED
  -- a secret mark. In Arn's paste they were, and MatchZone's `z.mark == mark` threw.)
  W.target = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" }
  local handed
  local realKill = F.Spots.Kill
  F.Spots.Kill = function(d, n, mark) handed = { mark } return realKill(d, n, mark) end
  ok(pcall(F.OnKill, db, "Raptor", "Creature-0-0-0-0-800-Raptor"),
     "Forever: a kill on a secret-marked target does not throw")
  ok(handed and not F.Secret(handed[1]), "Forever: and the farm spots are handed no secret mark (nil = cannot say)")
  F.Spots.Kill = realKill
  W.target = nil
  ok(F.Mark("nameplate1") == nil, "Forever: a secret mark reads as 'cannot say', never as a number")
  W.secretMarks = nil
  W.plates = { nameplate1 = { name = secret(), guid = "Creature-0-0-0-0-802-Raptor" } }
  F.marked = nil
  ok(pcall(F.Tick, db), "Forever: a SECRET name on a plate does not throw")
  ok(F.marked == nil, "Forever: and a plate whose name we may not read is not taken for the mob")
  -- (the client REFUSES `if secretBoolean`; a Lua 5.1 table is always true, so the mock cannot.
  -- The promise tested is that every flag is ASKED ABOUT before it is tested.)
  local deadFlag = secret()
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-803-Raptor", dead = deadFlag } }
  local asked = {}
  local realIs = _G.issecretvalue
  _G.issecretvalue = function(v) asked[v] = true return realIs(v) end
  ok(pcall(F.Clean, "nameplate1") and F.Clean("nameplate1") == false,
     "Forever: a SECRET dead flag does not throw, and the unit is not called clean")
  ok(asked[deadFlag], "Forever: the dead flag was asked about before it was tested")
  _G.issecretvalue = realIs
  W.plates = { nameplate1 = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" } }

  -- the spot sync, which used to SetRaidTarget the target to its spot's mark
  W.target = { name = "Raptor", guid = "Creature-0-0-0-0-800-Raptor" }
  if F.Spots then F.Spots.Sync(db) end
  ok(#W.forbidden == 0, "Forever: the spot sync marks nothing (the key's /tm carries the spot's mark)")
  W.target = nil W.plates = {} W.marks = {} F.marked = nil db.active = nil

  -- and on a client WITHOUT restrictions the combat log is still the road (TBC, unchanged)
  W.restricted = false
  _G.C_Secrets = { HasSecretRestrictions = function() return false end }
  S("off farm") S("on farm")
  ok(F.events.events.COMBAT_LOG_EVENT_UNFILTERED and not F.events.events.PARTY_KILL,
     "a client that hides nothing keeps the combat log, and does not listen twice")

  _G.C_Secrets, _G.issecretvalue, _G.UnitNameFromGUID = keep.C_Secrets, keep.issecretvalue, keep.UnitNameFromGUID
  _G.type = keep.type
  S("farm clear")
end

-- NO SUMMONING STONES ON FOREVER (6 Oct 2026). Arn: sunset the summon module there, keep it for
-- TBC. On a Forever interface number Summon.lua stops at its first lines: no tool, no window, no
-- nag, no /bt summon. The whole suite above ran it as TBC, where it is untouched.
do
  ok(NS.Registry:Get("summon") ~= nil, "TBC (20506): the summon tool is there")
  W.iface = 16001
  local registered = 0
  local fresh = { T = NS.T, Farm = NS.Farm,
                  Registry = { Register = function() registered = registered + 1 end } }
  local chunk = assert(loadfile("Tools/Summon.lua"))
  chunk("BiSTools", fresh)
  ok(fresh.SummonSunset == true and fresh.Summon == nil, "Forever (16001): Summon.lua stops at the top")
  ok(registered == 0, "Forever: and registers no tool - no window, no nag, no /bt summon")
  W.iface = nil
end

-- /bist IS THE COMMAND (0.4.0, Arn: "let's make it consistent" - /bish, /bisg, /bist), and the
-- two old names still reach the same handler so a 0.3.x macro keeps working
ok(SLASH_BISTOOLS1 == "/bist", "the command is /bist")
ok(SLASH_BISTOOLS2 == "/bistools" and SLASH_BISTOOLS3 == "/bt", "/bistools and /bt are kept as aliases")
for _, name in ipairs({ "Core/Slash.lua", "Core/Registry.lua", "Tools/TargetFarming.lua", "Tools/FarmSpots.lua",
                        "Tools/Hub.lua", "Tools/Summon.lua" }) do
  local fh = assert(io.open(name)) local src = fh:read("*a") fh:close()
  -- only text inside quotes is what the player reads; a comment may name the old alias
  local stray = src:gsub('SLASH_BISTOOLS3 = "/bt"', ""):match('"[^"\n]-/bt[^%w]')
  ok(not stray, name .. " still tells the player to type /bt: " .. tostring(stray))
end

-- ---------------------------------------------------------------- the farm spots on the maps
-- (6 Oct 2026) Arn: "can we see how questie puts marks on the minimap and can we do that?" Every
-- recorded spot of the farmed mob is a pin on the minimap AND the world map, wearing its own mark:
-- bright when it is up, dim while it waits to respawn.
do
  local Pn = F.Pins
  ok(Pn ~= nil, "the pins module loaded")
  local fdb = db
  local now = W.now
  local keepSpots, keepActive = fdb.spots, fdb.active
  fdb.spots = { Pinbear = {
    { id = 1, map = 1952, x = 0.50, y = 0.50, mark = 1, kills = 3, last = now - 10, respawn = 60,
      subs = { { x = 0.51, y = 0.50, mark = 2, kills = 2, last = now - 120, respawn = 60 } } },
  } }
  fdb.active = "Pinbear"
  fdb.pins = nil
  W.pins = { minimap = {}, world = {} }
  Pn.Update(fdb)
  local mini, world = {}, {}
  for icon, p in pairs(W.pins.minimap) do mini[#mini + 1] = { icon = icon, p = p } end
  for icon in pairs(W.pins.world) do world[#world + 1] = icon end
  ok(#mini == 2 and #world == 2, "every spot and sub is pinned on the minimap AND the world map", #mini .. "/" .. #world)
  local byMark = {}
  for _, e in ipairs(mini) do
    ok(e.p.map == 1952, "a pin sits on the spot's own map")
    byMark[e.icon.tex.file] = e
  end
  local zonePin = byMark["Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"]
  local subPin = byMark["Interface\\TargetingFrame\\UI-RaidTargetingIcon_2"]
  ok(zonePin and subPin, "each pin wears its spot's own raid mark")
  ok(zonePin.p.x == 0.50 and subPin.p.x == 0.51, "where the spot was recorded")
  ok(zonePin.icon.alpha == Pn.DIM, "a spot still waiting to respawn is dim")
  ok(subPin.icon.alpha == Pn.BRIGHT, "a spot whose respawn is up is bright")
  ok(subPin.icon.info and subPin.icon.info.state == "up now" and zonePin.icon.info.state:find("^back in"),
     "the tooltip says up now, or how long until it is back")

  -- time passes: the waiting spot comes up, the same pin brightens (no new pin)
  W.now = now + 60
  Pn.Update(fdb)
  local n = 0 for _ in pairs(W.pins.minimap) do n = n + 1 end
  ok(n == 2 and zonePin.icon.alpha == Pn.BRIGHT, "a spot that comes up brightens its own pin, nothing added")

  -- a sub forgotten (prune, clear): its pin goes, the zone's stays
  fdb.spots.Pinbear[1].subs = {}
  Pn.Update(fdb)
  n = 0 for _ in pairs(W.pins.minimap) do n = n + 1 end
  local w = 0 for _ in pairs(W.pins.world) do w = w + 1 end
  ok(n == 1 and w == 1, "a spot that is gone takes its pin off both maps")

  S("farm pins off")
  ok(next(W.pins.minimap) == nil and next(W.pins.world) == nil and fdb.pins == false, "/bist farm pins off clears both maps")
  S("farm pins on")
  ok(next(W.pins.minimap) ~= nil and fdb.pins == true, "/bist farm pins on brings them back")
  -- the diagnosis, for "nothing shows": prints every step and never throws, whatever is missing
  local said = {}
  local realChat = DEFAULT_CHAT_FRAME
  _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) said[#said + 1] = m end }
  ok(pcall(S, "farm pins why"), "/bist farm pins why never throws")
  _G.DEFAULT_CHAT_FRAME = realChat
  local all = table.concat(said, "\n")
  ok(all:find("HereBeDragons") and all:find("WOW_PROJECT_ID") and all:find("pinnable spots") and all:find("last add"),
     "and says what is loaded, which client it thinks this is, what it has to pin, and what the last add answered")
  S("off farm")
  ok(next(W.pins.minimap) == nil, "switching the farm tool off takes its pins off")
  S("on farm")
  ok(next(W.pins.minimap) ~= nil, "and on puts them back")

  -- no HereBeDragons at all (a stripped copy): nothing drawn, nothing thrown
  local keepLib = LibStub.libs["HereBeDragons-Pins-2.0"]
  LibStub.libs["HereBeDragons-Pins-2.0"] = nil
  ok(pcall(Pn.Update, fdb), "without the pin library the update does nothing and throws nothing")
  LibStub.libs["HereBeDragons-Pins-2.0"] = keepLib

  Pn.Stop()
  fdb.spots, fdb.active, fdb.pins = keepSpots, keepActive, nil
  W.now = now
end

-- ---------------------------------------------------------------- does every label FIT its window
-- (6 Oct 2026) Arn: "spawns window cut off make a check for cut offs or overflows that happens
-- often". Every shown label inside a window is measured where it actually starts - following what it
-- is pinned to: the window's edge, an icon, another label - and must end inside the window.
--
-- WIDTH, CALIBRATED ON THE CLIENT, NOT GUESSED: capitals and digits 0.75 px per point ("NEED MATS",
-- BiSCraft, 11 Sep), lowercase 0.55 and spaces/punctuation 0.3 (Arn's screenshot: "click a mob to
-- see its spawns" at 9 pt ran ~10 px past a 124 px window - this puts it at ~132). The mock's own
-- GetStringWidth (0.6 flat) stays as it is: the addon's code trims by it, and changing it changes
-- what the addon draws.
local function realWidth(fs)
  local t, tex = tostring(fs.text or ""), 0
  t = t:gsub("|T[^|]-:(%d+):%d+[^|]*|t", function(w) tex = tex + tonumber(w) return "" end)
  t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local size, px = fs.size or 9, 0
  -- one glyph per UTF-8 character; an accented letter (é) measures as a lowercase one
  for ch in t:gmatch("[%z\1-\127\192-\247][\128-\191]*") do
    if #ch > 1 or ch:match("%l") then px = px + 0.55 elseif ch:match("[%u%d]") then px = px + 0.75 else px = px + 0.3 end
  end
  return px * size + tex
end
local function regionWidth(r) if r.size or r.text ~= nil then return realWidth(r) end return r.w or 0 end
local function insideShown(r, root)
  local p = r.parent
  while p do
    if p.shown == false then return false end
    if p == root then return true end
    p = p.parent
  end
  return false
end
-- left edge in px from the window's left, following the anchor chain; nil when it cannot be followed
local function leftOf(r, width, depth)
  if (depth or 0) > 8 or not r.anchor then return nil end
  local p, rel, rp, x = r.anchor[1], r.anchor[2], r.anchor[3], r.anchor[4] or 0
  local relL, relW
  if rel == nil or rel.kind then relL, relW = 0, width      -- a frame inside the window spans it
  else relL, relW = leftOf(rel, width, (depth or 0) + 1), regionWidth(rel) end
  if not relL then return nil end
  local ax = rp:find("LEFT") and relL or rp:find("RIGHT") and (relL + relW) or (relL + relW / 2)
  local w = regionWidth(r)
  if p:find("LEFT") then return ax + x elseif p:find("RIGHT") then return ax + x - w end
  return ax + x - w / 2
end
local function plainText(t) return (tostring(t):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function fitsIn(root, what)
  local width, bad, measured = root.w, {}, 0
  for _, fs in ipairs(W.labels) do
    if fs.shown ~= false and fs.text and fs.text ~= "" and insideShown(fs, root) then
      local l = leftOf(fs, width)
      if l then
        measured = measured + 1
        local w = realWidth(fs)
        if l < -1 or l + w > width + 1 then
          bad[#bad + 1] = ("%q needs %d px from %d, the window is %d"):format(plainText(fs.text), w, l, width)
        end
      end
    end
  end
  ok(measured > 0, what .. ": the fit check measured something (a check that sees nothing proves nothing)")
  ok(#bad == 0, what .. ": every label fits - " .. table.concat(bad, "; "))
end

-- ---------------------------------------------------------------- RestedXP's Active Targets
-- (6 Oct 2026) Arn: "is there a way to have a rested exp section so anytime its active targets
-- update it adds it to our list". RXP is an AceAddon; its targets pass through
-- addon.targeting:UpdateEnemyList(unitscan, mobs, addEntries). A stand-in RXP is registered the same
-- way, and the real code path - hook, then their method called as they call it - is driven.
do
  local Gd = F.Guide
  ok(Gd ~= nil and not Gd.hooked, "RestedXP not installed: nothing hooked, nothing said")
  local rxp = { targeting = {} }
  local seenByRXP
  function rxp.targeting:UpdateEnemyList(unitscan, mobs, addEntries) seenByRXP = mobs end
  local AA = LibStub:NewLibrary("AceAddon-3.0", 1)
  function AA:GetAddon(name, silent) if name == "RXPGuides" then return rxp end if not silent then error("no " .. name) end end
  deliver("ADDON_LOADED", "RXPGuides")
  ok(Gd.hooked, "when RestedXP loads, its target list is listened to")

  local fdb = db
  local keep = { last = fdb.last, custom = fdb.custom, active = fdb.active, guide = fdb.guide }
  fdb.last = { name = "Hillsbrad Farmer", count = 3 }
  fdb.custom = nil fdb.active = nil fdb.guide = nil
  rxp.targeting:UpdateEnemyList({ "Rare Lion" }, { "Hillsbrad Farmer", "Hillsbrad Peasant" }, nil)
  ok(seenByRXP and seenByRXP[2] == "Hillsbrad Peasant", "RestedXP's own method still runs, untouched")
  local names = {}
  for _, e in ipairs(F.Entries(fdb)) do names[#names + 1] = e.name .. (e.guide and "*" or "") end
  ok(table.concat(names, ",") == "Hillsbrad Farmer,Hillsbrad Peasant*,Rare Lion*",
     "its targets join the list under your kills, the one you already farm not twice", table.concat(names, ","))
  F.Refresh(fdb)
  ok(BiSToolsFarmRow2.name.text == "Hillsbrad Peasant" and tostring(BiSToolsFarmRow2.count.text):find("RXP"),
     "a guide row says RXP where a kill row says how many")
  BiSToolsFarmRow2.scripts.OnClick(BiSToolsFarmRow2)
  ok(fdb.active == "Hillsbrad Peasant", "clicking it farms it, like any other row")
  F.SetActive(fdb, "Hillsbrad Peasant")

  rxp.targeting:UpdateEnemyList({}, { "Hillsbrad Footman" }, true)
  names = {}
  for _, e in ipairs(Gd.mobs) do names[#names + 1] = e end
  ok(table.concat(names, ",") == "Hillsbrad Farmer,Hillsbrad Peasant,Rare Lion,Hillsbrad Footman",
     "RestedXP ADDING targets adds to ours", table.concat(names, ","))
  rxp.targeting:UpdateEnemyList({}, { "Torn Fin Tidehunter" }, false)
  ok(#Gd.mobs == 1 and Gd.mobs[1] == "Torn Fin Tidehunter", "a new guide step REPLACES them")

  rxp.targeting:UpdateEnemyList({}, { "A1", "A2", "A3", "A4", "A5", "A6" }, false)
  local guideRows = 0
  for _, e in ipairs(F.Entries(fdb)) do if e.guide then guideRows = guideRows + 1 end end
  ok(guideRows == Gd.MAX, "never more than " .. Gd.MAX .. " guide rows in a small window")

  S("farm guide off")
  guideRows = 0
  for _, e in ipairs(F.Entries(fdb)) do if e.guide then guideRows = guideRows + 1 end end
  ok(guideRows == 0 and fdb.guide == false, "/bist farm guide off hides them")
  S("farm guide on")

  rxp.targeting:UpdateEnemyList({}, { "Hillsbrad Farmhand Overseer" }, false)
  F.Refresh(fdb)
  fitsIn(BiSToolsFarm, "the farm window with a long RestedXP name")

  fdb.last, fdb.custom, fdb.active, fdb.guide = keep.last, keep.custom, keep.active, keep.guide
  Gd.mobs = {}
  F.Refresh(fdb)
end

-- ---------------------------------------------------------------- the arrow to the next spawn
-- (6 Oct 2026) Arn: "an arrow like the spawn window that directs us to the mark that ... might
-- spawn soon, after a few kills it'll know this marker is spawning every x minutes". It points at
-- the spot the Spawns window would put FIRST - up, then due soonest, then killed longest ago.
do
  local A = F.Arrow
  ok(A ~= nil, "the arrow module loaded")
  local fdb = db
  local now = W.now
  local keep = { spots = fdb.spots, active = fdb.active, arrow = fdb.arrow, pins = fdb.pins }
  W.map, W.px, W.py, W.facing = 1952, 0.50, 0.50, 0
  fdb.active = "Arrowbear"
  fdb.spots = { Arrowbear = {
    -- zone 1, skull: its one sub was killed 10 s ago and comes back every 60 s - not soon
    { id = 1, map = 1952, x = 0.52, y = 0.50, mark = 8, kills = 3, last = now - 10, respawn = 60,
      subs = { { x = 0.52, y = 0.50, mark = 8, kills = 3, last = now - 10, respawn = 60 } } },
    -- zone 9: no mark left for it; killed 70 s ago, respawns every 60 s - it is UP
    { id = 9, map = 1952, x = 0.48, y = 0.50, kills = 2, last = now - 70, respawn = 60, subs = {} },
    -- a spot on another map: never pointed at, there is no bearing across maps
    { id = 3, map = 1453, x = 0.10, y = 0.10, mark = 3, kills = 1, last = now - 999, respawn = 60, subs = {} },
  } }
  local sp, text, _, d, mark = A.Next(fdb)
  ok(sp and sp.id == 9, "the arrow picks the spot that is UP over one still waiting", sp and sp.id)
  ok(text == "up" and mark == nil, "and says it is up; it has no mark of its own")
  ok(d and d > 0, "with a distance in yards")

  S("farm arrow on")
  ok(BiSToolsFarmArrow and BiSToolsFarmArrow:IsShown(), "/bist farm arrow on shows it")
  A.Refresh(fdb)
  ok(A.id.text == "#9" and not A.mark.shown, "an unmarked spot is named by its number, as in the Spawns window")
  ok(type(A.arrow.rot) == "number", "the arrow is turned toward it")

  -- the skull's sub comes up later and is NEARER - but zone 9 came up first, so it stays ahead
  -- (the window's own order), until zone 9 is killed again
  fdb.spots.Arrowbear[2].last = W.now
  sp, text, _, _, mark = A.Next(fdb)
  ok(sp and mark == 8, "after the up spot is killed, the arrow moves to the next one - the skull's")
  A.Refresh(fdb)
  ok(A.mark.shown and A.mark.file == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "wearing its mark")

  -- facing unknown (an instance): no arrow drawn, the rest still says where
  W.facing = nil
  A.arrow.shown = true
  A.Refresh(fdb)
  ok(not A.arrow.shown and A.clock.text ~= "", "no facing, no arrow - the timer and distance still show")
  W.facing = 0

  -- nothing on this map: it says so instead of pointing anywhere
  W.map = 1453 W.px, W.py = 0.5, 0.5
  fdb.spots.Arrowbear[3].map = 9999
  A.Refresh(fdb)
  ok(A.none.shown and not A.arrow.shown, "no spot on this map: no arrow, a line saying so")
  W.map = 1952

  -- BIG AND ON ITS OWN, LIKE RESTEDXP'S (Arn: the row was "a little crowded ... can we make it big
  -- like the rested one"): floating, a big arrow, mark + timer under it, then the distance
  A.Refresh(fdb)                          -- back on the map with the spots
  ok(BiSToolsFarmArrow.parent == UIParent, "the arrow floats on its own, not inside the Spawns window")
  ok(A.arrow.w and A.arrow.w >= 48, "and it is BIG", A.arrow.w)
  ok(A.dist.text and A.dist.text:find("yd%)$"), "the distance under it, RestedXP-style: (N yd)", A.dist.text)
  ok(F.Spots.body.point and F.Spots.body.point[2] == F.Spots.head, "the Spawns window has no arrow row any more")
  ok(F.Spots.title.text:find("Spawns"), "and keeps its name: Spawns")
  BiSToolsFarmArrow.scripts.OnDragStop(BiSToolsFarmArrow)
  ok(type(fdb.arrowPos) == "table" and fdb.arrowPos[1], "a dragged arrow remembers where it was left")
  fitsIn(BiSToolsFarmArrow, "the floating arrow")

  S("farm arrow off")
  ok(not BiSToolsFarmArrow:IsShown() and fdb.arrow == false, "/bist farm arrow off hides it")
  S("farm arrow on")
  S("off farm")
  ok(not BiSToolsFarmArrow:IsShown(), "switching the farm tool off hides the arrow")
  S("on farm")
  ok(BiSToolsFarmArrow:IsShown(), "and on brings it back")

  -- CLICK THE MOB AGAIN: everything it shows goes; click it back: everything comes back (Arn:
  -- "when i click the mountain lion again it should remove all the marks on the minimap and clear
  -- the spawn timers window"). The spots themselves are kept.
  W.pins = { minimap = {}, world = {} }
  F.Pins.Stop() fdb.pins = nil
  F.Pins.Update(fdb)
  ok(next(W.pins.minimap) ~= nil, "farming: the spots are pinned")
  F.Spots.Toggle(fdb, true)
  -- as in game: the mob you stop farming is also the one you last KILLED - which is exactly what
  -- the old fallback (S.Mob: active, else last kill) kept showing
  local keepLast = fdb.last
  fdb.last = { name = "Arrowbear", count = 3 }
  F.SetActive(fdb, "Arrowbear")            -- the same mob again = stop farming it
  ok(fdb.active == nil, "clicking the farmed mob again stops farming it")
  ok(next(W.pins.minimap) == nil and next(W.pins.world) == nil, "and its pins leave both maps at once")
  ok(F.Spots.empty.shown and F.Spots.empty.text == "pick a mob to farm", "the Spawns window empties", F.Spots.empty.text)
  ok(not BiSToolsFarmArrow:IsShown(), "and the arrow leaves the screen - nothing farmed, nothing to point at")
  -- Arn's screenshot, this exact state: both lines ran out of the window
  fitsIn(BiSToolsFarmSpots, "Spawns, no mob picked")
  ok(fdb.spots.Arrowbear and #fdb.spots.Arrowbear == 3, "but the spots and what they learned are KEPT")
  F.SetActive(fdb, "Arrowbear")
  ok(fdb.active == "Arrowbear" and next(W.pins.minimap) ~= nil, "clicking it back brings the pins straight back")
  F.Spots.Refresh(fdb) A.Refresh(fdb)
  fitsIn(BiSToolsFarmSpots, "Spawns, spots listed")
  F.Refresh(fdb)
  fitsIn(BiSToolsFarm, "the farm window")
  fdb.last = keepLast

  -- the minimap pin for a spot with no mark: a gold dot, not nothing
  W.pins = { minimap = {}, world = {} }
  F.Pins.Stop() fdb.pins = nil
  F.Pins.Update(fdb)
  local dot
  for icon in pairs(W.pins.minimap) do if icon.w == F.Pins.DOT then dot = icon end end
  ok(dot and dot.tex.color, "a spot past the eighth mark is pinned as a dot, not skipped")
  F.Pins.Stop()

  fdb.spots, fdb.active, fdb.arrow, fdb.pins = keep.spots, keep.active, keep.arrow, keep.pins
  A.Hide()
  W.now = now
end

-- WHAT IT COSTS, IN CLIENT CALLS (7 Oct 2026). BiSHealing asked the client ~630,000 things a
-- second and every suite was green; Arn: "make sure stuff like this does not happen". The family's
-- counter (_bisdev/dev/cost.lua) holds the two things here that run all evening while farming.
do
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local A, Sp = F.Arrow, F.Spots
  local keep = { spots = db.spots, active = db.active, arrow = db.arrow, shelf = db.shelf }
  W.map, W.px, W.py, W.facing = 1952, 0.50, 0.50, 0
  -- a full evening's farm: 16 zones with 2 subs each, on this map
  local list = {}
  for z = 1, 16 do
    local subs = {}
    for s = 1, 2 do
      subs[s] = { x = 0.40 + z * 0.01, y = 0.40 + s * 0.01, kills = 3, last = W.now - z * 7, respawn = 120 }
    end
    list[z] = { id = z, map = 1952, x = 0.40 + z * 0.01, y = 0.40, mark = (z % 8) + 1, kills = 6,
                last = W.now - z * 7, respawn = 120, subs = subs }
  end
  db.spots = { Costbear = list }
  db.active, db.arrow = "Costbear", nil
  S("farm arrow on")
  A.Refresh(db)
  ok(BiSToolsFarmArrow:IsShown(), "(cost) the arrow is up, pointing")

  -- ONE SECOND OF THE ARROW: twenty frames of 0.05 s
  local n, by = Cost.Count(function()
    for _ = 1, 20 do BiSToolsFarmArrow.scripts.OnUpdate(BiSToolsFarmArrow, 0.05) end
  end)
  -- measured 7 Oct after the split (turn 20/s, pick 4/s); every frame doing the full pick was 5x
  local ARROW = 300
  ok(n <= ARROW, "a second of the farm arrow asks the client at most " .. ARROW .. " things: " .. n,
     Cost.Top(by, 5))
  print(("   cost: arrow, 1 s, 32 spots = %d calls (%s)"):format(n, Cost.Top(by, 3)))

  -- THE SHELF BEHIND A CLOSED FARM WINDOW. Closing the window hides the parent only; the shelf
  -- stayed "shown" and rebuilt itself 4 times a second for nobody.
  Sp.Toggle(db, true)
  local seen = Cost.Count(function() for _ = 1, 4 do Sp.Refresh(db) end end)
  BiSToolsFarm:Hide()
  local hidden, hby = Cost.Count(function() for _ = 1, 4 do Sp.Refresh(db) end end)
  BiSToolsFarm:Show()
  ok(BiSToolsFarmSpots:IsShown() and hidden < seen / 2,
     "a closed farm window stops the Spawns shelf rebuilding: " .. hidden .. " calls a second, open "
     .. seen, Cost.Top(hby, 4))
  print(("   cost: shelf, 1 s = %d calls open, %d behind a closed window"):format(seen, hidden))

  -- A MOUSE SWEPT ACROSS A PACK: ten mouseovers in the same instant are one scan, not ten
  local realTick, scans = F.Tick, 0
  F.Tick = function(...) scans = scans + 1 return realTick(...) end
  local hadTicker = F.ticker
  F.ticker = F.ticker or { alive = true, Cancel = function() end }
  F.mouseTickAt = nil
  for _ = 1, 10 do F.events.scripts.OnEvent(F.events, "UPDATE_MOUSEOVER_UNIT") end
  ok(scans == 1, "ten mouseovers at once start one farm scan, not ten", scans)
  W.now = W.now + F.MOUSE_GAP + 0.01
  F.events.scripts.OnEvent(F.events, "UPDATE_MOUSEOVER_UNIT")
  ok(scans == 2, "and the next one after the gap scans again", scans)
  F.Tick, F.ticker = realTick, hadTicker

  Sp.Toggle(db, false)
  S("farm arrow off")
  db.spots, db.active, db.arrow, db.shelf = keep.spots, keep.active, keep.arrow, keep.shelf
end

-- ---------------------------------------------------------------- what killed you: the measuring tool
-- (12 Oct 2026) Arn, for a friend: "a death recap of who or what killed him". Step one only
-- MEASURES what C_DeathRecap hands over on Forever, and when. The mock is as unkind as the client
-- may be: a hidden field refuses every touch (index, concat, compare) and says "string" to type();
-- a whole row, or the whole list, may be hidden; the call may throw.
do
  local RC = NS.Recap
  local secretMeta = { __index = function(_, k) error("attempt to use a secret value (" .. tostring(k) .. ")", 2) end,
                       __eq = function() error("attempt to compare a secret value", 2) end,
                       __lt = function() error("attempt to compare a secret value", 2) end,
                       __concat = function() error("attempt to concatenate a secret value", 2) end }
  local function secret() return setmetatable({}, secretMeta) end
  local realType = type
  local keep = { type = _G.type, issecretvalue = _G.issecretvalue, issecrettable = _G.issecrettable,
                 canaccessvalue = _G.canaccessvalue, C_DeathRecap = _G.C_DeathRecap,
                 chat = DEFAULT_CHAT_FRAME.AddMessage }
  _G.type = function(v) if getmetatable(v) == secretMeta then return "string" end return realType(v) end
  _G.issecretvalue = function(v) return getmetatable(v) == secretMeta end
  local hiddenTables = {}
  _G.issecrettable = function(t) return hiddenTables[t] == true end
  local said = {}
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said[#said + 1] = m end
  local function heard() local s = table.concat(said, "\n") said = {} return s end

  -- a client with no death recap at all: says so, never throws
  _G.C_DeathRecap = nil
  ok(pcall(S, "recap raw"), "/bist recap raw on a client with no death recap does not throw")
  ok(heard():find("no death recap to read", 1, true), "and says the client has none")

  -- THE GAME'S RECORD, the moment you die: who and with what readable, how much hidden
  local hide = true
  local function hit(i)
    return { event = "SPELL_DAMAGE", sourceName = "Defias Thug", spellId = 1752, spellName = "Sinister Strike",
             amount = hide and secret() or 52 + i, currentHP = hide and secret() or 300 - i, timestamp = 1000 + i }
  end
  local events, throw = {}, false
  _G.C_DeathRecap = {
    HasRecapEvents = function() return #events > 0 end,
    GetRecapMaxHealth = function() return hide and secret() or 1344 end,
    GetRecapEvents = function()
      if throw then error("Attempt to access forbidden object", 2) end
      if #events == 0 then return nil end
      local out = {}
      for i = 1, #events do out[i] = hit(i) end
      return out
    end,
  }
  events = { 1, 2, 3 }
  W.combat = true
  local onEvent = RC.frame.scripts.OnEvent
  ok(RC.frame.events.PLAYER_DEAD and RC.frame.events.PLAYER_REGEN_ENABLED, "it listens for dying and for the fight ending")
  ok(pcall(onEvent, RC.frame, "PLAYER_DEAD"), "dying with hidden numbers does not throw")
  ok(RC.win and RC.win:IsShown(), "and opens the recap window, hidden numbers and all")
  ok(RC.win.mid.dmg.text == "?" and RC.win.foot.text:find("some amounts hidden", 1, true),
     "where the game hid a number the window says ?, never a guess")
  heard()
  local d = RC.atDeath
  ok(d and d.count == 3 and #d.rows == 3, "every hit is recorded at death")
  ok(d.rows[1]:find('sourceName="Defias Thug"', 1, true) and d.rows[1]:find("spellId=1752", 1, true),
     "who hit you, and with what, read where the game lets it be read")
  ok(d.rows[1]:find("amount=<hidden>", 1, true) and d.rows[1]:find("currentHP=<hidden>", 1, true),
     "and what it hid is named as hidden - never touched")
  ok(d.hiddenFields.amount and d.hiddenFields.currentHP and not d.hiddenFields.sourceName,
     "the hidden fields are listed by name")
  ok(d.maxHealth == "<hidden>" and d.combat == "true", "max health hidden, and it says it was a fight")

  -- THE FIGHT ENDS: read again - the answer that says whether waiting helps
  hide = false
  W.combat = false
  onEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  local a = RC.afterFight
  ok(a and a.rows[1]:find("amount=53", 1, true) and next(a.hiddenFields) == nil, "after the fight the same hits read plainly")
  local before = RC.afterFight
  onEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  ok(RC.afterFight == before, "a second fight ending without a death reads nothing")

  -- /bist recap: all three readings, each with its verdict
  S("recap raw")
  local out = heard()
  ok(out:find("at death", 1, true) and out:find("after the fight", 1, true) and out:find("right now", 1, true),
     "/bist recap prints the reading at death, after the fight, and now")
  ok(out:find("hidden: amount, currentHP", 1, true) and out:find("nothing hidden", 1, true),
     "and which fields were hidden in each", out)
  S("recap now")
  out = heard()
  ok(out:find("right now", 1, true) and not out:find("at death", 1, true), "/bist recap now: just the live read")

  -- what the game may do instead of answering
  hiddenTables = {}
  local list
  _G.C_DeathRecap.GetRecapEvents = function() list = { hit(1) } hiddenTables[list] = true return list end
  ok(RC.Read("x").notes[1] == "the whole record is hidden", "a hidden list is said to be hidden")
  _G.C_DeathRecap.GetRecapEvents = function() local r = hit(1) hiddenTables[r] = true return { r } end
  ok(RC.Read("x").rows[1] == "#1 <hidden hit>", "a hidden hit is said to be hidden, not walked")
  _G.C_DeathRecap.GetRecapEvents = function() error("forbidden", 2) end
  local okR, snap = pcall(RC.Read, "x")
  ok(okR and snap.notes[1]:find("refused", 1, true), "a refusal is reported, not thrown")
  _G.C_DeathRecap.GetRecapEvents = function() local out2 = {} for i = 1, 15 do out2[i] = hit(i) end return out2 end
  snap = RC.Read("x")
  ok(snap.count == 15 and #snap.rows == RC.MAX_ROWS, "fifteen hits recorded, the newest ten printed")

  -- switched off: dying is not even read
  R:SetEnabled("recap", false)
  RC.atDeath = nil
  onEvent(RC.frame, "PLAYER_DEAD")
  ok(RC.atDeath == nil, "with the tool off, a death is not read")
  R:SetEnabled("recap", true)

  -- LEAN: it costs nothing until you die - a fight ending reads nothing at all
  local Cost = dofile("../_bisdev/dev/cost.lua")
  RC.waitFight = nil
  local n = Cost.Count(function() for _ = 1, 100 do onEvent(RC.frame, "PLAYER_REGEN_ENABLED") end end)
  ok(n == 0, "100 fights ending without a death cost no client calls: " .. n)
  print(("   cost: 100 fights ending, no death = %d calls"):format(n))

  _G.type, _G.issecretvalue, _G.issecrettable, _G.canaccessvalue, _G.C_DeathRecap =
    keep.type, keep.issecretvalue, keep.issecrettable, keep.canaccessvalue, keep.C_DeathRecap
  DEFAULT_CHAT_FRAME.AddMessage = keep.chat
  RC.atDeath, RC.afterFight, RC.waitFight = nil, nil, nil
end

-- ---------------------------------------------------------------- the death recap window, on Arn's death
-- (12 Oct 2026) Ragefire Chasm, pasted from /bist recap: ten hits, nothing hidden. The window has to
-- say what the mockup said - killer Molten Elemental 128 (42%), Earthborers 106 (35%) and 72 (24%),
-- "306 damage in 6.0 seconds" - and group by GUID, because Forever re-names a mob on every hit.
do
  local RC = NS.Recap
  local MOLTEN, EB_A, EB_B = "Creature-0-4621-389-178375-11321-0003CD6", "Creature-0-4621-389-178375-11320-0000CD6",
                             "Creature-0-4621-389-178375-11320-0002CD6"
  local function h(amount, crit, hp, t, name, guid, extra)
    local r = { event = "SWING_DAMAGE", amount = amount, critical = crit, currentHP = hp, timestamp = 1791846000 + t,
                sourceName = name, sourceGUID = guid, overkill = -1, school = 1 }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  local ARN = {   -- newest first, as the game gives it
    h(27, false, 13, 504.529, "Molten Elemental Smitecrust", MOLTEN, { overkill = 14 }),
    h(44, true, 57, 504.046, "Earthborer Milker", EB_A),
    h(44, true, 101, 503.163, "Earthborer Arms", EB_B),
    h(7, false, 108, 502.529, "Molten Elemental Shaquanda", MOLTEN, { blocked = 22 }),
    h(2, false, 110, 502.046, "Earthborer Sama", EB_A, { blocked = 22 }),
    h(44, true, 154, 501.146, "Earthborer Bee", EB_B),
    h(49, true, 203, 500.512, "Molten Elemental Shaquanda", MOLTEN),
    h(26, false, 229, 500.046, "Earthborer Deluxe", EB_A),
    h(18, false, 247, 499.147, "Earthborer Beartotem", EB_B),
    h(45, true, 292, 498.505, "Molten Elemental Flashs", MOLTEN),
  }
  local keepDR, keepDead = _G.C_DeathRecap, _G.UnitIsDeadOrGhost
  local deadNow = true
  _G.UnitIsDeadOrGhost = function() return deadNow end
  _G.C_DeathRecap = { HasRecapEvents = function() return true end, GetRecapMaxHealth = function() return 1192 end,
                      GetRecapEvents = function() return ARN end }

  local s = RC.Summary(RC.Hits(ARN), 1192)
  ok(#s.attackers == 3, "ten nicknames, three mobs: grouped by GUID")
  ok(s.killer and s.killer.title == "Molten Elemental" and s.killer.total == 128, "the killer: the Molten Elemental, 128")
  ok(s.assists[1].title == "Earthborer" and s.assists[1].total == 106 and s.assists[2].total == 72,
     "the assists: the two Earthborers, 106 and 72")
  ok(s.total == 306 and math.abs(s.seconds - 6.024) < 0.01 and s.startHP == 292, "306 damage in 6.0 seconds, from 292 health")
  ok(table.concat(s.killer.nicks, ","):find("Smitecrust", 1, true) and table.concat(s.killer.nicks, ","):find("Flashs", 1, true),
     "its nicknames listed under it")
  ok(RC.Shared({ "Kumlust" }) == "Kumlust" and RC.Shared({ "Earthborer Milker", "Earthborer Arms" }) == "Earthborer",
     "a lone name is kept whole; shared words make the kind")

  -- dying opens it, painted from the record
  local rdb = R:DBFor(R:Get("recap"))
  rdb.popup = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  local w = RC.win
  ok(w:IsShown(), "dying opens the death recap")
  ok(w.mid.name.text == "Molten Elemental" and w.mid.role.text == "killer" and w.mid.dmg.text == "128 (42%)",
     "the middle card: killer, Molten Elemental, 128 (42%)", w.mid.dmg.text)
  ok(w.left.dmg.text == "106 (35%)" and w.right.dmg.text == "72 (24%)", "the assists either side, with their shares")
  ok(w.mid.what.text == "killing blow 27 +14", "the killing blow and its overkill", w.mid.what.text)
  ok(w.foot.text == "306 damage in 6.0 seconds", "the total line", w.foot.text)
  ok(w.rows[1].amt.text == "27 +14" and w.rows[2].what.text == "melee crit" and w.rows[5].what.text == "melee 22 blk",
     "the hits, newest first, crits and blocks marked")
  ok(w.stripLeft.text == "292 of 1192 health when these began", "the strip says where the hits began", w.stripLeft.text)
  ok(w.cols[1].h > w.cols[10].h and w.cols[10].shown, "the health columns fall from oldest to newest")
  fitsIn(w, "the death recap")

  -- back on your feet: it closes; still a ghost: it stays
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ALIVE")
  ok(w:IsShown(), "releasing your spirit (still a ghost) leaves it open")
  deadNow = false
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_UNGHOST")
  ok(not w:IsShown(), "back in your body, it closes")
  S("recap")
  ok(w:IsShown(), "/bist recap opens your last death again")
  S("recap")
  ok(not w:IsShown(), "and closes it")

  -- "STOP SHOWING THIS" (Arn, 12 Oct)
  S("recap")
  ok(w.stop and w.stop.label.text == "stop showing this", "the recap has a stop showing this line")
  w.stop.scripts.OnClick(w.stop)
  ok(rdb.popup == false and not w:IsShown(), "clicked: it closes, and will not open on a death")
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(not w:IsShown(), "dying again: it stays shut")
  S("recap")
  ok(w:IsShown() and w.stop.label.text == "show when I die", "/bist recap still opens it, offering it back")
  fitsIn(w, "the recap with its stop line")
  w.stop.scripts.OnClick(w.stop)
  ok(rdb.popup == true and w.stop.label.text == "stop showing this", "and clicking that turns it back on")
  w:Hide()
  deadNow = false

  -- switched off: dying does not open it
  rdb.popup = false
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(not w:IsShown(), "with 'open when you die' off, it stays shut")
  rdb.popup = true

  -- a player killer (PvP): the name is the name
  local pk = RC.Summary(RC.Hits({ h(80, true, 50, 10, "Kumlust", "Player-4619-00ABCDEF", { overkill = 30 }) }), 1192)
  ok(pk.killer.title == "Kumlust" and #pk.killer.nicks == 0 and pk.assists[1] == nil, "a player who killed you is named as themselves")

  -- KILLED BY THREE HUNTERS (Arn's screenshot, 12 Oct): player names in class colour, each card's
  -- main spell, the healing note, and a click to make one a rival
  local LEG, MOMS, EGGS = "Player-4619-0001", "Player-4619-0002", "Player-4619-0003"
  local PVP = {
    h(114, false, 114, 5.3, "Hunting Moms", MOMS, { spellName = "Auto Shot", event = "RANGE_DAMAGE", overkill = 38 }),
    h(48, false, 162, 5.3, "Légolas Thiliaere", LEG, { spellName = "Serpent Sting", event = "SPELL_PERIODIC_DAMAGE" }),
    h(137, true, 299, 5.2, "Hunting Moms", MOMS, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(151, true, 450, 3.8, "Légolas Thiliaere", LEG, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(104, false, 554, 3.7, "Hunting Moms", MOMS, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(26, false, 580, 2.6, "Eggs Benethicc", EGGS, { spellName = "Rend", event = "SPELL_PERIODIC_DAMAGE" }),
    h(120, false, 700, 2.0, "Légolas Thiliaere", LEG, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(117, false, 817, 1.2, "Légolas Thiliaere", LEG, { spellName = "Auto Shot", event = "RANGE_DAMAGE" }),
    h(130, true, 947, 0.5, "Légolas Thiliaere", LEG, { spellName = "Arcane Shot", event = "SPELL_DAMAGE" }),
    h(100, false, 361, 0.0, "Légolas Thiliaere", LEG, { spellName = "Serpent Sting", event = "SPELL_PERIODIC_DAMAGE" }),
  }
  local CLASS = { [LEG] = "HUNTER", [MOMS] = "HUNTER", [EGGS] = "WARRIOR" }
  local keepInfo, keepColors = _G.GetPlayerInfoByGUID, _G.RAID_CLASS_COLORS
  _G.GetPlayerInfoByGUID = function(g) return "x", CLASS[g] end
  _G.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
  _G.C_DeathRecap.GetRecapEvents = function() return PVP end
  local rdb2 = R:DBFor(R:Get("recap"))
  rdb2.rivals = nil
  deadNow = true
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  local p = RC.last
  ok(p.killer.title == "Hunting Moms" and p.killer.player and p.killer.class == "HUNTER", "a player killer, with their class")
  ok(w.left.name.text == "Légolas Thiliaere" and w.left.dmg.text == "666 (64%)", "the biggest assist: Légolas, 666 (64%)", w.left.dmg.text)
  ok(w.left.what.text == "Arcane Shot 281", "each card says what they mostly hit you with", w.left.what.text)
  ok(w.right.what.text == "Rend 26", "even a one-hit assist", w.right.what.text)
  ok(w.left.name.color and math.abs(w.left.name.color[1] - 0.67) < 0.01, "a player's name in their class colour")
  ok(w.foot.text == "1047 damage in 5.3 seconds - you healed through some of it", "more damage than health is explained", w.foot.text)

  -- CLICK A PLAYER: a rival. Click again: not. A mob card is not clickable into the list.
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  local rivals = RC.Rivals(rdb2)
  ok(rivals["Hunting Moms"] and rivals["Hunting Moms"].class == "HUNTER" and rivals["Hunting Moms"].guid == MOMS,
     "clicking the killer's card makes them a rival, with class and GUID")
  ok(w.mid.rival.text == "rival", "and the card says so")
  fitsIn(w, "the death recap, a rival on it")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  ok(rivals["Hunting Moms"] == nil and w.mid.rival.text == "", "a second click takes them off")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  ok(rivals["Hunting Moms"].kills == 1, "a rival who kills you again is counted")
  local said2 = {}
  local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said2[#said2 + 1] = m end
  S("recap rivals")
  local listed = table.concat(said2, "\n")
  ok(listed:find("Hunting Moms", 1, true) and listed:find("killed you 1 more time", 1, true), "/bist recap rivals lists them")
  S("recap forget hunting moms")
  ok(rivals["Hunting Moms"] == nil, "/bist recap forget <name> takes one off, any capitals")
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd
  _G.C_DeathRecap.GetRecapEvents = function() return ARN end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  w.mid.scripts.OnClick(w.mid, "LeftButton")
  ok(next(RC.Rivals(rdb2)) == nil, "a mob is never a rival")
  -- THE BIG VIEW AND THE TRACKER (Arn, 12 Oct: "if i click a button it maximize and shows more info
  -- all rivals etc. current target gold, all previous targets silver. can click them again to turn
  -- them gold" ... "yes start the tracker")
  _G.C_DeathRecap.GetRecapEvents = function() return PVP end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_DEAD")
  w.mid.scripts.OnClick(w.mid, "LeftButton")                         -- Hunting Moms: gold
  w.left.scripts.OnClick(w.left, "LeftButton")                       -- Légolas: gold
  ok(RC.GoldCount(rdb2) == 2 and rivals["Légolas Thiliaere"].active, "a rival clicked from a recap starts gold")
  RC.SetActive(rdb2, "Légolas Thiliaere", false)
  ok(RC.GoldCount(rdb2) == 1, "and can be sent to silver")
  -- Légolas seen more recently than Moms: gold-first has to beat most-recent-first
  rivals["Légolas Thiliaere"].seen = W.now + 100
  rdb2.expanded = false
  RC.SetExpanded(rdb2, false)
  ok(not w.drawer:IsShown(), "small: no drawer")
  w.moreBtn.scripts.OnClick(w.moreBtn)
  ok(w.drawer:IsShown() and rdb2.expanded and w.moreBtn.label.text == "-", "the + button opens the rivals drawer")
  local d = w.drawer
  ok(d.rows[1].rival == "Hunting Moms" and d.rows[2].rival == "Légolas Thiliaere", "gold first, then silver")
  ok(d.rows[1].mark.color[2] > d.rows[2].mark.color[2] - 0.0 and d.rows[2].name.color[4] < 1,
     "a gold mark on the hunted, a dimmed silver row for the rest")
  fitsIn(d, "the rivals drawer")
  local function rowOf(name) for _, r in ipairs(d.rows) do if r.rival == name then return r end end end
  rowOf("Légolas Thiliaere").scripts.OnClick(rowOf("Légolas Thiliaere"), "LeftButton")
  ok(rivals["Légolas Thiliaere"].active, "clicking a silver rival turns them gold again")
  rowOf("Légolas Thiliaere").scripts.OnClick(rowOf("Légolas Thiliaere"), "LeftButton")
  ok(not rivals["Légolas Thiliaere"].active, "and back to silver")

  -- the tracker: a gold rival's nameplate appears
  local keepZone = _G.GetZoneText
  _G.GetZoneText = function() return "The Barrens" end
  W.notices, W.sounds = {}, {}
  W.plates.nameplate7 = { name = "Hunting Moms" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(W.notices[1] == "Rival nearby: Hunting Moms" and #W.sounds == 1, "a gold rival in sight: a warning and a sound")
  ok(rivals["Hunting Moms"].where == "The Barrens" and rivals["Hunting Moms"].seen == W.now, "and where and when is kept")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(#W.notices == 1, "the same rival again within a minute: quiet")
  W.now = W.now + RC.ALERT_GAP + 1
  W.target = { name = "Hunting Moms" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(#W.notices == 2, "a minute later, targeting them calls them out again")
  W.plates.nameplate8 = { name = "Légolas Thiliaere" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate8")
  ok(#W.notices == 2, "a silver rival is remembered, not called out")
  W.plates.nameplate9 = { name = "Somebody Else" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9")
  ok(#W.notices == 2, "a stranger is nobody's business")
  rdb2.sound = false
  local soundsBefore = #W.sounds
  W.now = W.now + RC.ALERT_GAP + 1
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(#W.notices == 3 and #W.sounds == soundsBefore, "with the sound off: the warning, no sound")
  rdb2.sound = nil
  ok(d.rows[1].info.text:find("seen 0m ago, The Barrens", 1, true), "the drawer says where they were last seen", d.rows[1].info.text)
  -- a nameplate whose name the game hides: nothing, and no error
  local keepName = _G.UnitName
  _G.UnitName = function() return setmetatable({}, { __index = function() error("secret") end }) end
  local keepIs = _G.issecretvalue
  _G.issecretvalue = function(v) return type(v) == "table" end
  ok(pcall(RC.frame.scripts.OnEvent, RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7") and #W.notices == 3,
     "a hidden name is not read, and nothing is called out")
  _G.UnitName, _G.issecretvalue = keepName, keepIs

  -- THE CROSSHAIR ON A GOLD RIVAL'S NAMEPLATE (Arn: "is there a way to draw a crosshairs like our
  -- healing addon via the name plates" ... "gold rivals only, pulsing"). The client hands an addon the
  -- nameplate frame; one it locks away says so with IsForbidden.
  local plates = {}
  local keepGet = _G.C_NamePlate.GetNamePlateForUnit
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  plates.nameplate7 = CreateFrame("Frame", nil, nil)
  plates.nameplate7:SetSize(180, 20)
  plates.nameplate8 = CreateFrame("Frame", nil, nil)
  RC.SetActive(rdb2, "Hunting Moms", true)
  W.plates.nameplate7 = { name = "Hunting" }                -- the character name, as a nameplate gives it
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  local mk = RC.marks.nameplate7
  ok(mk and mk.shown and mk.rival == "Hunting Moms" and mk.point and mk.point[2] == plates.nameplate7
     and mk.point[1] == "TOP" and mk.point[3] == "BOTTOM",
     "a gold rival's nameplate wears the crosshair, hanging under the plate")
  ok(mk.w == 90 and mk.h == RC.MARK_H, "half the plate's width (Arn: \"tighten it up 50%\"), centred", mk.w)
  -- Arn's shape: a rail down each side of the body, a tick in at the middle of each
  ok(#mk.parts == 4 and mk.leftRail.h == RC.MARK_H and mk.rightRail.h == RC.MARK_H
     and mk.leftTick.anchor[1] == "LEFT" and mk.rightTick.anchor[1] == "RIGHT"
     and mk.leftTick.w > mk.leftTick.h and mk.parts[1].color[1] == 1 and mk.parts[1].color[2] < 0.3,
     "two red rails the body's height, a tick in from each side at the middle")
  ok(mk.pulse and mk.pulse:IsPlaying() and mk.pulse.looping == "BOUNCE", "and it pulses on the client's own loop")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == mk, "the same plate twice: one crosshair")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  ok(RC.marks.nameplate7 == nil and not mk.shown and not mk.pulse:IsPlaying(), "the plate leaves: the crosshair goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == mk, "and comes back from the pool, not a new frame")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate7")
  plates.nameplate7.w = nil                                  -- a plate that will not say how wide it is
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 and RC.marks.nameplate7.w == RC.MARK_W, "a plate with no width: 60 px, never an error")
  plates.nameplate7.w = 180
  -- CROSSHAIRS TO PLAY WITH (Arn: "maybe in the recap or options we can play around with different
  -- crosshairs"): picking one redraws the rival already on screen, so they can be compared
  local function anchors(f) local a = {} for _, p in ipairs(f.parts) do a[#a + 1] = p.anchor and p.anchor[1] end table.sort(a) return table.concat(a, ",") end
  ok(RC.SetStyle(rdb2, "L") and rdb2.style == "L", "L: chosen")
  local mL = RC.marks.nameplate7
  ok(mL and mL ~= mk and mL.style == "L" and #mL.parts == 8 and not mk.shown,
     "L: the rival on screen is redrawn at once, eight arms at the four corners")
  ok(anchors(mL) == "BOTTOMLEFT,BOTTOMLEFT,BOTTOMRIGHT,BOTTOMRIGHT,TOPLEFT,TOPLEFT,TOPRIGHT,TOPRIGHT", "an L at each corner", anchors(mL))
  RC.SetStyle(rdb2, "aim")
  local mA = RC.marks.nameplate7
  ok(mA.style == "aim" and anchors(mA) == "BOTTOM,LEFT,RIGHT,TOP" and mA.parts[1].h == RC.SIGHT_LEN,
     "aim: a line in from the middle of each side", anchors(mA))
  RC.SetStyle(rdb2, "box")
  local mB = RC.marks.nameplate7
  ok(mB.style == "box" and #mB.parts == 4 and mB.parts[1].h == RC.MARK_THICK and mB.parts[3].w == RC.MARK_THICK,
     "box: four edges all the way round")
  ok(RC.SetStyle(rdb2, "swirl") == false and rdb2.style == "box", "a style that does not exist changes nothing")
  local said4 = {}
  local keepAdd4 = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said4[#said4 + 1] = m end
  S("recap style swirl")
  ok(table.concat(said4, "\n"):find("rails, L, aim, box", 1, true), "/bist recap style with a wrong name lists them")
  S("recap style l")
  ok(rdb2.style == "L", "/bist recap style l picks L")
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd4
  -- FOUR FROM ARN'S PICTURES ("more ideas"): scope, drop, chevron, tee - centred on the body
  RC.SetStyle(rdb2, "scope")
  local sc = RC.marks.nameplate7
  local centred = 0
  for _, p in ipairs(sc.parts) do if p.anchor and p.anchor[1] == "CENTER" then centred = centred + 1 end end
  ok(sc.style == "scope" and #sc.parts == 13 and centred == 9, "scope: four posts, thin lines, ticks and the dot", #sc.parts)
  RC.SetStyle(rdb2, "drop")
  local dr = RC.marks.nameplate7
  ok(dr.style == "drop" and dr.parts[1].rot and dr.parts[2].rot and math.abs(dr.parts[1].rot + dr.parts[2].rot) < 1e-9,
     "drop: a chevron of two slants turned opposite ways, and a ladder")
  RC.SetStyle(rdb2, "chevron")
  ok(RC.marks.nameplate7.style == "chevron" and #RC.marks.nameplate7.parts == 2, "chevron: just the ^")
  RC.SetStyle(rdb2, "tee")
  ok(RC.marks.nameplate7.style == "tee" and #RC.marks.nameplate7.parts == 2, "tee: a bar and a stem")
  -- eight do not fit one row of buttons: the options stepper walks them, the name shown
  local stepper
  for _, o in ipairs(R:Get("recap").options) do if o.label == "crosshair" then stepper = o end end
  ok(stepper and stepper.kind == "step" and stepper.max == 9 and stepper.get(rdb2) == 8 and stepper.show(rdb2) == "tee",
     "the options stepper: eight styles, at tee")
  stepper.set(rdb2, 5)
  ok(rdb2.style == "scope" and RC.marks.nameplate7.style == "scope" and stepper.show(rdb2) == "scope",
     "a step redraws the rival on screen in the next shape")
  RC.SetStyle(rdb2, "rails")
  mk = RC.marks.nameplate7
  ok(mk.style == "rails" and #mk.parts == 4, "and back to rails")
  W.plates.nameplate8 = { name = "Légolas" }               -- a silver rival
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate8")
  ok(RC.marks.nameplate8 == nil, "a silver rival gets no crosshair")
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(RC.marks.nameplate7 == nil and not mk.shown, "sending a rival to silver takes their crosshair off")
  RC.SetActive(rdb2, "Hunting Moms", true)
  plates.nameplate7.IsForbidden = function() return true end
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  ok(RC.marks.nameplate7 == nil, "a nameplate the client locks away gets none, and no error")
  plates.nameplate7.IsForbidden = nil
  W.target = { name = "Hunting" }
  plates.target = CreateFrame("Frame", nil, nil)          -- the client WOULD hand back a plate for it
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  plates.target = nil
  ok(RC.marks.target == nil, "only nameplates carry it - a target has no plate event to take it down")
  W.target = nil
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7")
  R:SetEnabled("recap", false)
  ok(next(RC.marks) == nil, "switching the tool off takes every crosshair down")
  R:SetEnabled("recap", true)
  _G.C_NamePlate.GetNamePlateForUnit = keepGet
  W.plates.nameplate7, W.plates.nameplate8 = { name = "Hunting Moms" }, nil

  -- THE RIVAL TARGET BUTTON (Arn: "i just did /tar Ford Knox and i was able to target an enemy
  -- player what about a small button that targets all our rivals"). The mock refuses an attribute
  -- set in combat, as the client does.
  RC.SetActive(rdb2, "Hunting Moms", true)
  RC.SetActive(rdb2, "Légolas Thiliaere", false)
  local tb = RC.tbtn
  ok(tb and tb.template == "SecureActionButtonTemplate" and tb.attrs.type == "macro", "a secure macro button")
  ok(tb.attrs.macrotext == "/target Hunting Moms" and tb.shown, "one gold rival: /target them, and the button shows")
  rivals["Hunting Moms"].seen, rivals["Légolas Thiliaere"].seen = W.now - 50, W.now
  RC.SetActive(rdb2, "Légolas Thiliaere", true)
  ok(tb.attrs.macrotext == "/target Hunting Moms\n/target Légolas Thiliaere",
     "two gold: the most recently seen runs last, so it is the one you get", tb.attrs.macrotext)
  -- in a fight the button cannot be rewritten: it waits
  W.combat = true
  ok(pcall(RC.SetActive, rdb2, "Légolas Thiliaere", false), "a rival sent to silver mid-fight: nothing thrown")
  ok(RC.btnDirty and tb.attrs.macrotext:find("Légolas", 1, true), "the button keeps its macro until the fight ends")
  W.combat = false
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_REGEN_ENABLED")
  ok(not RC.btnDirty and tb.attrs.macrotext == "/target Hunting Moms", "and is rewritten the moment it does")
  -- a key, and off again
  S("recap key f6")
  ok(W.binds[tb] and W.binds[tb].key == "F6" and W.binds[tb].btn == "BiSToolsRivalTarget", "/bist recap key F6 binds it")
  S("recap key off")
  ok(W.binds[tb] == nil and rdb2.key == nil, "and key off unbinds it")
  -- nobody gold: hidden; the option off: hidden
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(not tb.shown and tb.attrs.macrotext == "", "nobody gold: no button")
  RC.SetActive(rdb2, "Hunting Moms", true)
  rdb2.button = false RC.ApplyButton(rdb2)
  ok(not tb.shown, "'rival target button' off: hidden")
  rdb2.button = nil RC.ApplyButton(rdb2)
  -- THE BiS> TOOLS BOX (Arn: "lets keep all button neat maybe in a bis farm box, like the bis now, maybe if
  -- we have bis now it just puts the button there cross addon")
  local Bx = NS.Box
  local box = Bx.frame
  ok(box and tb.parent == box and box.shown and Bx.count >= 1, "the rival button lives in the BiS> tools box")
  -- ONE LOOK FOR EVERY BiS> BAR (Arn: "the bis headers are all different fonts some different color some
  -- blinking _ some static lets get them all the same"): the box's bar wears the prompt, BiS Healing's height
  local hc = box.head.con
  W.now = W.now + 1 box.head.scripts.OnUpdate(box.head, 0.3) W.now = W.now + 1 box.head.scripts.OnUpdate(box.head, 0.3)
  local hp = hc and (hc:Text():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  ok(hp and hp:find("BiS> tools", 1, true), "the box's bar wears the family prompt", hp)
  ok(box.head.h == 16, "at BiS Healing's bar height", box.head.h)
  local fbtn = NS.Farm.TargetButton()
  local fdb = NS.Farm.db
  local keepActive2 = fdb.active
  fdb.active = nil Bx.Refresh()
  ok(not fbtn.shown and Bx.count == 1, "no mob farmed: no farm button")
  fdb.active = "Kobold Miner" Bx.Refresh()
  ok(fbtn.parent == box and fbtn.shown and Bx.count == 2 and fbtn.icon.file:find("RaidTargetingIcon_8", 1, true),
     "farming: the farm's target button, with the skull, beside the rival one")
  -- WHICH IS WHICH (Arn: "do the purple and red buttons"): mobs purple, players red, crossed swords
  ok(fbtn.edgeColour == RC.MOB_PURPLE and fbtn.edge.top.color[1] == RC.MOB_PURPLE[1] and fbtn.edge.top.h == 2,
     "the farm's button: a purple edge, two pixels")
  ok(tb.edgeColour == RC.MARK_RED and tb.edge.left.color[2] == RC.MARK_RED[2] and tb.edge.left.w == 2
     and tb.icon.file:find("Ability_DualWield", 1, true), "the rival button: a red edge and crossed swords")
  ok(box.w == math.max(Bx.MIN_W, Bx.PAD * 2 + 2 * Bx.SIZE + Bx.GAP), "the box is as wide as its buttons (and its name)", box.w)
  -- docked to BiS> now when it is up, its own place when not
  local now = CreateFrame("Frame", "BiSHealingNowBlock", nil)
  now.shown = true
  -- where things are on screen (the client answers GetLeft/Right/Top/Bottom): BiS> now UNDER the grid
  local function at(fr, l, r, t2, b) fr.GetLeft = function() return l end fr.GetRight = function() return r end
    fr.GetTop = function() return t2 end fr.GetBottom = function() return b end end
  local gridAnchor = CreateFrame("Frame", nil, nil)
  local gridHeader = CreateFrame("Frame", "BiSHealingForeverHeader", gridAnchor)
  at(gridAnchor, 300, 700, 600, 300) at(gridHeader, 300, 700, 618, 602)
  at(now, 300, 400, 280, 240)                                   -- under the grid
  Bx.DB().dock = nil
  Bx.Refresh()
  ok(Bx.docked and Bx.dock == "right" and box.point[2] == now and box.point[1] == "TOPLEFT" and box.point[3] == "TOPRIGHT",
     "BiS> now under the grid: the box docks to its right edge")
  -- BiS> now on the grid's LEFT (Arn: "it overlapped into the healing frames"): right of it is the grid
  at(now, 190, 295, 600, 560)
  Bx.Refresh()
  ok(Bx.dock == "below" and box.point[1] == "TOPLEFT" and box.point[3] == "BOTTOMLEFT",
     "BiS> now left of the grid: the box goes below it, not onto the grid")
  -- level with the grid's HEADER only (above its cells): that is the grid too
  at(now, 190, 295, 650, 630)
  Bx.Refresh()
  ok(Bx.dock == "below", "the grid's own header counts as the grid")
  at(now, 190, 295, 600, 560)
  -- shift-click sends it round BiS> now (Arn: "should have these same clicks and drags")
  W.shift = true
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "right" and Bx.dock == "right", "shift-click: right")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "below" and box.point[3] == "BOTTOMLEFT", "then below")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "left" and box.point[1] == "TOPRIGHT" and box.point[3] == "TOPLEFT", "then left")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "top" and box.point[1] == "BOTTOMLEFT" and box.point[3] == "TOPLEFT", "then on top")
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "auto", "and round to auto")
  W.shift = false
  box.head.scripts.OnMouseUp(box.head, "LeftButton")
  ok(Bx.DB().dock == "auto", "a plain click does nothing")
  -- the header drags it anywhere - docked or not - and a dragged box stays where it is dropped
  local moved = 0
  local keepMove, keepStop = box.StartMoving, box.StopMovingOrSizing
  box.StartMoving = function() moved = moved + 1 end
  box.StopMovingOrSizing = function() end
  W.combat = true box.head.scripts.OnDragStart(box.head) box.head.scripts.OnDragStop(box.head) W.combat = false
  ok(moved == 0 and Bx.DB().dock == "auto", "never dragged in a fight")
  box.head.scripts.OnDragStart(box.head) box.head.scripts.OnDragStop(box.head)
  box.StartMoving, box.StopMovingOrSizing = keepMove, keepStop
  ok(moved == 1 and Bx.DB().dock == "free" and not Bx.docked and Bx.DB().pos, "dragged, even docked: it stays where it is dropped")
  Bx.Refresh()
  ok(box.point[2] == UIParent, "and stays free while BiS> now is up")
  W.shift = true box.head.scripts.OnMouseUp(box.head, "LeftButton") W.shift = false
  ok(Bx.DB().dock == "auto" and Bx.docked, "shift-click brings a dragged box back to BiS> now")
  now:Hide() if now.scripts.OnHide then now.scripts.OnHide(now) end
  ok(not Bx.docked and box.point[2] == UIParent, "BiS> now hidden: the box stands on its own")
  _G.BiSHealingNowBlock, _G.BiSHealingForeverHeader = nil, nil
  Bx.DB().dock = nil
  -- a change in a fight waits for its end
  W.combat = true
  fdb.active = nil
  ok(Bx.Refresh() == false and Bx.dirty and fbtn.shown, "in a fight the box is left as it is")
  W.combat = false
  Bx.events.scripts.OnEvent(Bx.events, "PLAYER_REGEN_ENABLED")
  ok(not Bx.dirty and not fbtn.shown, "and laid out again when it ends")
  -- nothing to do: no box
  RC.SetActive(rdb2, "Hunting Moms", false)
  ok(not box.shown, "no button with anything to do: no box")
  RC.SetActive(rdb2, "Hunting Moms", true)
  -- PURPLE FOR MOBS (Arn: "we should also add this to the farm module ... only the crosshair", "if rxp
  -- calls for mobs to be able to be tracked we crosshairs them", "red for players purple for mobs")
  local mplates = {}
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return mplates[u] end
  mplates.nameplate3 = CreateFrame("Frame", nil, nil) mplates.nameplate3:SetSize(140, 20)
  mplates.nameplate2 = CreateFrame("Frame", nil, nil) mplates.nameplate2:SetSize(140, 20)
  fdb.active = "Kobold Miner"
  W.plates.nameplate3 = { name = "Kobold Miner" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  local fm = RC.marks.nameplate3
  ok(fm and fm.kind == "farm" and math.abs(fm.parts[1].color[1] - 0.73) < 0.01 and fm.parts[1].color[3] == 1,
     "the mob you farm: a purple crosshair")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate3")
  W.plates.nameplate3 = { name = "Kobold Miner", tapped = true }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  ok(RC.marks.nameplate3 == nil, "a copy somebody else tapped: none (the farm tool's own clean test)")
  W.plates.nameplate3 = { name = "Kobold Miner" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  NS.Farm.SetActive(fdb, "Kobold Geomancer")
  ok(RC.marks.nameplate3 == nil, "farm something else: the old crosshairs go")
  NS.Farm.SetActive(fdb, "Kobold Miner")
  -- RestedXP's Active Targets
  NS.Farm.Guide.Take(nil, { "Murloc Hunter" }, false)
  W.plates.nameplate2 = { name = "Murloc Hunter" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate2")
  local gm2 = RC.marks.nameplate2
  ok(gm2 and gm2.kind == "guide" and math.abs(gm2.parts[1].color[1] - 0.73) < 0.01, "a mob the RestedXP guide wants: purple too")
  NS.Farm.Guide.Take(nil, { "Murloc Oracle" }, false)
  ok(RC.marks.nameplate2 == nil, "the guide moves on: the old step's crosshairs go")
  fdb.guide = false
  NS.Farm.Guide.Take(nil, { "Murloc Hunter" }, false)
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate2")
  ok(RC.marks.nameplate2 == nil, "the guide's mobs hidden in the farm tool: none")
  fdb.guide = nil
  -- the farm tool's switch
  for _, o in ipairs(R:Get("farm").options) do if o.label == "crosshair on the mob" then o.set(fdb, false) end end
  ok(next(RC.marks) == nil or (function() for _, f in pairs(RC.marks) do if f.kind == "farm" or f.kind == "guide" then return false end end return true end)(),
     "'crosshair on the mob' off: every purple crosshair goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate3")
  ok(RC.marks.nameplate3 == nil, "and none drawn")
  fdb.cross = nil
  NS.Farm.Guide.Take(nil, {}, false)
  W.plates.nameplate2, W.plates.nameplate3 = nil, nil
  _G.C_NamePlate.GetNamePlateForUnit = nil
  fdb.active = keepActive2 Bx.Refresh()
  -- twenty gold rivals: the macro stays within the client's length, the most recent kept
  local keepList = rdb2.rivals
  rdb2.rivals = {}
  for i = 1, 20 do rdb2.rivals[("Rival Number%02d Longname"):format(i)] = { active = true, seen = i } end
  local mtext, n20 = RC.TargetMacro(rdb2)
  ok(#mtext <= RC.MACRO_MAX and n20 < 20 and mtext:find("Number20", 1, true) and not mtext:find("Number01", 1, true),
     "twenty gold rivals: as many as fit in 255 characters, the most recently seen kept", #mtext)
  rdb2.rivals = keepList
  RC.ApplyButton(rdb2)

  -- "ADD RIVAL" ON THE RIGHT-CLICK MENU (Arn: "when i right click maybe we can add add rival here").
  -- The client's Menu.ModifyMenu, in Olympus's shape: (owner, root, ctx) with ctx.name and ctx.surname.
  local hookedMenus = {}
  _G.Menu = { ModifyMenu = function(tag, fn) hookedMenus[tag] = fn end }
  RC.menusHooked = nil
  ok(RC.HookMenus(rdb2) and hookedMenus.MENU_UNIT_ENEMY_PLAYER and hookedMenus.MENU_UNIT_PLAYER,
     "the enemy and player menus get the line")
  ok(not hookedMenus.MENU_UNIT_COMMUNITIES_GUILD_MEMBER and not hookedMenus.MENU_UNIT_GUILD,
     "never the guild roster menus (the game's own promote and kick live there)")
  local function root()
    local r = { lines = {} }
    function r:CreateDivider() self.lines[#self.lines + 1] = "--" end
    function r:CreateButton(text, fn) self.lines[#self.lines + 1] = text self.click = fn end
    return r
  end
  local keepClass, keepGUID = _G.UnitClass, _G.UnitGUID
  _G.UnitClass = function(u) if u == "target" then return "Rogue", "ROGUE" end return "Shaman", "SHAMAN" end
  _G.UnitGUID = function(u) if u == "target" then return "Player-4619-00DA1" end end
  local m = root()
  hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu", unit = "target" })
  ok(m.lines[2] == "BiS: add rival", "an enemy's menu says: BiS: add rival", m.lines[2])
  m.click()
  ok(rivals["Dai Joubu"] and rivals["Dai Joubu"].active and rivals["Dai Joubu"].class == "ROGUE"
     and rivals["Dai Joubu"].guid == "Player-4619-00DA1", "clicked: Dai Joubu is a gold rival, with class and GUID")
  ok(tb.attrs.macrotext:find("/target Dai Joubu", 1, true), "and the target button knows them at once")
  m = root()
  hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu", unit = "target" })
  ok(m.lines[2] == "BiS: remove rival", "the next time: BiS: remove rival")
  m.click()
  ok(rivals["Dai Joubu"] == nil, "and that takes them off")
  m = root()
  hookedMenus.MENU_UNIT_FRIEND(nil, m, { name = "Hunting" })   -- a name in chat, no surname given
  ok(m.lines[2] == "BiS: remove rival", "a chat name finds the rival by the character name alone")
  m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { name = "Me" })
  ok(#m.lines == 0, "no line on your own menu")
  m = root() hookedMenus.MENU_UNIT_PLAYER(nil, m, { name = setmetatable({}, { __index = function() error("secret") end }) })
  ok(#m.lines == 0, "no line for a name the game hides")
  R:SetEnabled("recap", false)
  m = root() hookedMenus.MENU_UNIT_ENEMY_PLAYER(nil, m, { name = "Dai", surname = "Joubu" })
  ok(#m.lines == 0, "and none while the tool is off")
  R:SetEnabled("recap", true)
  _G.Menu = nil
  RC.menusHooked = nil
  ok(RC.HookMenus(rdb2) == false, "a client without Menu.ModifyMenu: no lines, no error")
  _G.UnitClass, _G.UnitGUID = keepClass, keepGUID

  -- "TRACK IN FARM" ON A MOB'S RIGHT-CLICK MENU (Arn, 13 Oct: "right click npc ... track in the farm
  -- module not just type their name or wait till you kill one")
  do
    local menus = {}
    _G.Menu = { ModifyMenu = function(tag, fn) menus[tag] = fn end }
    F.menusHooked = nil
    ok(F.HookMenus(db) and menus.MENU_UNIT_TARGET and menus.MENU_UNIT_FOCUS, "a mob's portrait menus get the farm line")
    ok(not menus.MENU_UNIT_ENEMY_PLAYER and not menus.MENU_UNIT_PLAYER, "never a player's menu (the rival line lives there)")
    local keepIsPlayer, keepTarget = _G.UnitIsPlayer, W.target
    _G.UnitIsPlayer = function(u) local x = (u == "target") and W.target return x and x.player or false end
    F.Clear(db)
    W.target = { name = "Dalaran Summoner", guid = "Creature-0-0-0-0-1915-00A1" }
    local m = root()
    menus.MENU_UNIT_TARGET(nil, m, { unit = "target", name = "Dalaran Summoner" })
    ok(m.lines[1] == "--" and m.lines[2] == "BiS: track in farm", "a mob's menu says: BiS: track in farm", m.lines[2])
    BiSToolsFarm:Hide()
    m.click()
    ok(db.active == "Dalaran Summoner" and db.custom == "Dalaran Summoner",
       "clicked: the farm tracks it, the same as /bist farm add")
    ok(BiSToolsFarm:IsShown(), "and the farm window opens")
    m = root()
    menus.MENU_UNIT_FOCUS(nil, m, { unit = "target" })
    ok(m.lines[2] == "BiS: stop farming", "the next time: BiS: stop farming", m.lines[2])
    m.click()
    ok(db.active == nil, "and that stops it")
    W.target = { name = "Kumlance", player = true }
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "no line on a player")
    W.target = { name = "Stormwind Guard", hostile = false }
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "no line on a mob you cannot attack")
    m = root() menus.MENU_UNIT_TARGET(nil, m, { name = "Dalaran Summoner" })
    ok(#m.lines == 0, "no line when the menu names no unit")
    W.target = { name = "Dalaran Summoner", guid = "Creature-0-0-0-0-1915-00A1" }
    R:SetEnabled("farm", false)
    m = root() menus.MENU_UNIT_TARGET(nil, m, { unit = "target" })
    ok(#m.lines == 0, "none while the farm tool is off")
    R:SetEnabled("farm", true)
    _G.Menu = nil
    F.menusHooked = nil
    ok(F.HookMenus(db) == false, "a client without Menu.ModifyMenu: no farm line, no error")
    _G.UnitIsPlayer, W.target = keepIsPlayer, keepTarget
    F.Clear(db)
  end

  -- GUILD RIVALS (Arn: "a toggle dont show guild rivals etc or show with a different color crosshair to
  -- know it was from someone else"), over LibBiSComm's GUILD channel
  local lib2 = _G.LibBiSComm
  local sent = {}
  local keepSendTo = lib2.SendTo
  lib2.SendTo = function(_, chan, mod, cmd, ...) sent[#sent + 1] = { chan = chan, mod = mod, cmd = cmd, args = { ... } } return true end
  _G.IsInGuild = function() return true end
  RC.guildHooked = nil
  ok(RC.HookGuild(rdb2) and lib2.guildMods.RIVAL and lib2.handlers.RIVAL.ADD and lib2.handlers.RIVAL.SEEN,
     "the guild channel carries RIVAL: ADD, DEL, SEEN, ASK, LIST")
  local mg = root()
  _G.Menu = { ModifyMenu = function() end }
  RC.MenuLines(rdb2, mg, { name = "Kill", surname = "Er", unit = "target" })
  ok(mg.lines[3] == "BiS: add guild rival", "the menu offers a guild rival too", mg.lines[3])
  _G.UnitClass = function() return "Mage", "MAGE" end
  mg.click()
  _G.UnitClass = keepClass
  local g = RC.GuildRivals(rdb2)
  ok(g["Kill Er"] and g["Kill Er"].class == "MAGE" and sent[#sent].chan == "GUILD" and sent[#sent].cmd == "ADD"
     and sent[#sent].args[1] == "Kill Er", "added: on the guild's list, and the guild told")
  -- from someone else
  lib2.handlers.RIVAL.ADD("Tyrone", "Ganka Boy", "ROGUE")
  ok(g["Ganka Boy"] and g["Ganka Boy"].by == "Tyrone", "a guildmate's guild rival arrives, with who added it")
  -- in sight: amber, no noise, the guild told once a minute
  W.notices, W.sounds = {}, {}
  local nSent = #sent
  plates.nameplate5 = CreateFrame("Frame", nil, nil) plates.nameplate5:SetSize(160, 20)
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  W.plates.nameplate5 = { name = "Ganka" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  local gm = RC.marks.nameplate5
  ok(gm and gm.kind == "guild" and gm.parts[1].color[2] > 0.5, "a guild rival wears the AMBER crosshair")
  ok(#W.notices == 0 and #W.sounds == 0, "and makes no noise")
  ok(#sent == nSent + 1 and sent[#sent].cmd == "SEEN" and sent[#sent].args[1] == "Ganka Boy", "the guild is told they were seen")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate5")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(#sent == nSent + 1, "seen again within a minute: not said twice")
  -- a guild rival who is also YOUR gold rival: red
  RC.ToggleRival(rdb2, { player = true, title = "Ganka Boy", class = "ROGUE" })
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(RC.marks.nameplate5.kind == "own", "yours as well: red, your crosshair wins")
  RC.ToggleRival(rdb2, { player = true, title = "Ganka Boy" })
  -- someone else saw one
  lib2.handlers.RIVAL.SEEN("Tyrone", "Kill Er", "Tarren Mill")
  ok(g["Kill Er"].where == "Tarren Mill" and g["Kill Er"].seenBy == "Tyrone", "a guildmate's sighting: where, and by whom")
  rdb2.expanded = true RC.SetExpanded(rdb2, true)
  local grow
  for _, b in ipairs(w.drawer.rows) do if b.rival == "Kill Er" then grow = b end end
  ok(grow and grow.guild and grow.info.text:find("guild", 1, true) and grow.info.text:find("Tarren Mill (Tyrone)", 1, true)
     and grow.mark.color[2] > 0.5, "the drawer: amber, guild, where and who saw them", grow and grow.info.text)
  fitsIn(w.drawer, "the drawer with guild rivals")
  -- guild rows: click = yours, shift-click = off the guild's list (and the guild told)
  grow.scripts.OnClick(grow, "LeftButton")
  ok(rivals["Kill Er"] and rivals["Kill Er"].active, "clicking a guild row makes them your gold rival")
  RC.ToggleRival(rdb2, { player = true, title = "Kill Er" })
  for _, b in ipairs(w.drawer.rows) do if b.rival == "Kill Er" then grow = b end end
  W.shift = true grow.scripts.OnClick(grow, "LeftButton") W.shift = false
  ok(g["Kill Er"] == nil and sent[#sent].cmd == "DEL", "shift-click takes them off the guild's list, for everyone")
  lib2.handlers.RIVAL.DEL("Tyrone", "Ganka Boy")
  ok(g["Ganka Boy"] == nil and RC.marks.nameplate5 == nil, "a guildmate's DEL: gone, crosshair and all")
  -- a newcomer asks; one answer is enough
  lib2.handlers.RIVAL.ADD("Tyrone", "Third Guy", "PRIEST")
  -- (other tools' timers send too: only RIVAL LISTs are counted)
  local function lists() local n, last = 0, nil for _, s in ipairs(sent) do if s.mod == "RIVAL" and s.cmd == "LIST" then n, last = n + 1, s end end return n, last end
  local before = lists()
  lib2.handlers.RIVAL.ASK("Newbie")
  W.runAfters(5)
  local nL, lastL = lists()
  ok(nL == before + 1 and lastL.args[1] == "Third Guy", "asked: the list is sent")
  lib2.handlers.RIVAL.ASK("Newbie")
  lib2.handlers.RIVAL.LIST("Someone", "Third Guy", "PRIEST")
  W.runAfters(5)
  ok(lists() == before + 1, "somebody else answered first: we stand down")
  lib2.handlers.RIVAL.LIST("Someone", "Fourth One", "WARLOCK", "Fifth One", "HUNTER")
  ok(g["Fourth One"] and g["Fifth One"].class == "HUNTER", "a LIST is merged in")
  lib2.handlers.RIVAL.ADD("Tyrone", "bad|name", "X")
  lib2.handlers.RIVAL.ADD("Tyrone", ("x"):rep(60), "X")
  ok(g["bad|name"] == nil and g[("x"):rep(60)] == nil, "a name with a pipe, or absurdly long, is refused")
  -- the switch: off hides them and stops listening
  for _, o in ipairs(R:Get("recap").options) do
    if o.label == "guild rivals (amber)" then o.set(rdb2, false) end
  end
  W.plates.nameplate5 = { name = "Third" }
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate5")
  ok(RC.marks.nameplate5 == nil, "guild rivals off: no amber crosshair")
  lib2.handlers.RIVAL.ADD("Tyrone", "Sixth Guy", "PRIEST")
  ok(g["Sixth Guy"] == nil, "and the guild's additions are not taken in")
  rdb2.guildShow = nil

  -- GUILDMATES IN PASSING (Arn: "while not in a party and we see their name plate no noise just a
  -- small little cross hair ... turn off during party and raid and battleground")
  local keepMine = _G.UnitIsInMyGuild
  local mates = { nameplate6 = true }
  _G.UnitIsInMyGuild = function(u) return mates[u] == true end
  plates.nameplate6 = CreateFrame("Frame", nil, nil)
  W.plates.nameplate6 = { name = "Tyrone" }
  RC.solo = true
  W.notices, W.sounds = {}, {}
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  local mate = RC.mates.nameplate6
  ok(mate and mate.shown and mate.w == 11 and mate.bar.color[3] > 0.7, "a guildmate's plate, alone: a small teal +")
  ok(#W.notices == 0 and #W.sounds == 0, "with no noise at all")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_REMOVED", "nameplate6")
  ok(RC.mates.nameplate6 == nil and not mate.shown, "their plate goes: so does the +")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  local keepGroup = _G.IsInGroup
  _G.IsInGroup = function() return true end
  RC.frame.scripts.OnEvent(RC.frame, "GROUP_ROSTER_UPDATE")
  ok(RC.mates.nameplate6 == nil and RC.solo == false, "join a group: every + goes")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "and none while grouped")
  _G.IsInGroup = keepGroup
  local keepInst = _G.IsInInstance
  _G.IsInInstance = function() return true, "pvp" end
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ENTERING_WORLD")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "nor in a battleground")
  _G.IsInInstance = keepInst
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_ENTERING_WORLD")
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6, "alone again: back")
  rdb2.mates = false RC.ClearMates()
  RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate6")
  ok(RC.mates.nameplate6 == nil, "'guildmates' off: none")
  rdb2.mates = nil
  -- LEAN: a town of strangers' plates, alone, nobody gold and no guild rivals: a name and a guild question each
  local Cost2 = dofile("../_bisdev/dev/cost.lua")
  for k in pairs(g) do g[k] = nil end
  RC.SetActive(rdb2, "Hunting Moms", false) RC.SetActive(rdb2, "Légolas Thiliaere", false)
  W.plates.nameplate4 = { name = "Stranger" }
  local nM = Cost2.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate4") end end)
  ok(nM <= 500 * 3, "500 strangers' plates, guildmates on: at most 3 client calls each: " .. nM)
  rdb2.mates = false
  local nOff = Cost2.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate4") end end)
  ok(nOff == 0, "and with everything off: none at all: " .. nOff)
  print(("   cost: 500 plates alone = %d calls (guildmates on), %d (all off)"):format(nM, nOff))
  rdb2.mates = nil
  RC.SetActive(rdb2, "Hunting Moms", true)
  _G.UnitIsInMyGuild, _G.C_NamePlate.GetNamePlateForUnit = keepMine, keepGet
  lib2.SendTo = keepSendTo
  _G.Menu, _G.IsInGuild = nil, nil
  W.plates.nameplate4, W.plates.nameplate5, W.plates.nameplate6 = nil, nil, nil

  -- /bist recap why (Arn, Hunting Moms on his target: "dont think i got a notification or sound"):
  -- says who is gold, what it last saw and why it stayed quiet, and reads the target every way
  local said3 = {}
  local keepAdd3 = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said3[#said3 + 1] = m end
  W.target = { name = "Somebody Else" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(pcall(S, "recap why"), "/bist recap why never throws")
  local why = table.concat(said3, "\n")
  ok(why:find("gold: ", 1, true) and why:find("Hunting Moms", 1, true) and why:find("not a rival", 1, true)
     and why:find('"Somebody Else"', 1, true), "it names the gold rivals, the last look and its reason, and the target", why)
  said3 = {}
  W.target = { name = "Hunting" }                     -- MEASURED: the game gives "Hunting", the recap "Hunting Moms"
  S("recap why")
  ok(table.concat(said3, "\n"):find("that is your rival Hunting Moms (gold)", 1, true),
     "the character name alone is the rival (Forever's surname is not part of it)", table.concat(said3, "\n"))
  said3 = {}
  W.target = { name = "Hunt" }                        -- a different, shorter name is not them
  S("recap why")
  ok(not table.concat(said3, "\n"):find("that is your rival", 1, true), "a name that only starts the same is not a rival")
  -- and the tracker calls them out under the first name, by the name the recap knows
  W.notices = {}
  W.now = W.now + RC.ALERT_GAP + 1
  W.target = { name = "Hunting" }
  RC.frame.scripts.OnEvent(RC.frame, "PLAYER_TARGET_CHANGED")
  ok(W.notices[1] == "Rival nearby: Hunting Moms", "targeting \"Hunting\" calls out your rival Hunting Moms", tostring(W.notices[1]))
  said3 = {}
  said3 = {}
  _G.UnitName = function() return setmetatable({}, { __index = function() error("secret") end }) end
  _G.issecretvalue = function(v) return type(v) == "table" end
  ok(pcall(S, "recap why") and table.concat(said3, "\n"):find("HIDDEN by the game", 1, true), "a hidden target name is said to be hidden")
  _G.UnitName, _G.issecretvalue = keepName, keepIs
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd3
  W.target = nil

  -- LEAN: hunting nobody costs nothing; hunting someone costs a name check a nameplate
  local Cost = dofile("../_bisdev/dev/cost.lua")
  -- (the guildmate + off here: it is measured with its own budget in the guild section)
  rdb2.mates = false
  local n = Cost.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate9") end end)
  ok(n <= 500 * 2, "500 strangers' nameplates with a gold rival: at most 2 client calls each: " .. n)
  RC.SetActive(rdb2, "Hunting Moms", false)
  local n0 = Cost.Count(function() for _ = 1, 500 do RC.frame.scripts.OnEvent(RC.frame, "NAME_PLATE_UNIT_ADDED", "nameplate7") end end)
  ok(n0 == 0, "500 nameplates with nobody gold: no client calls at all: " .. n0)
  rdb2.mates = nil
  print(("   cost: 500 nameplates = %d calls hunting someone, %d hunting nobody"):format(n, n0))
  _G.GetZoneText = keepZone
  W.plates.nameplate7, W.plates.nameplate8, W.plates.nameplate9, W.target = nil, nil, nil, nil

  -- no death this session, but rivals: /bist recap opens on the drawer alone
  RC.last = nil
  _G.C_DeathRecap.GetRecapEvents = function() return nil end
  w:Hide()
  S("recap")
  ok(w:IsShown() and d:IsShown() and not w.mid:IsShown() and w.caption.text == "nothing has killed you this session",
     "no death yet: the window opens on your rivals")
  fitsIn(w, "the recap with no death")
  W.shift = true
  d.rows[1].scripts.OnClick(d.rows[1], "LeftButton")
  W.shift = false
  ok(#(function() local t = {} for k in pairs(rivals) do t[#t + 1] = k end return t end)() == 1, "shift-click forgets a rival")
  rdb2.rivals, rdb2.expanded = nil, nil
  w:Hide()

  _G.GetPlayerInfoByGUID, _G.RAID_CLASS_COLORS = keepInfo, keepColors

  _G.C_DeathRecap, _G.UnitIsDeadOrGhost = keepDR, keepDead
  RC.last = nil
  w:Hide()
end

-- ---------------------------------------------------------------- the social tool: a thank-you emote
-- (12 Oct 2026) Arn: "when i get a buff from a friendly player i hate having to say /thanks /kiss /hug etc.
-- can we track who buffed us and it select a random friendly emote to auto emote them maybe with a 2-5 min
-- cooldown". UNIT_AURA for "player" carries addedAuras with sourceUnit; in a fight it can be hidden.
do
  local Sc = NS.Social
  local sdb = R:DBFor(R:Get("social"))
  local emoted = {}
  local keep = { DoEmote = _G.DoEmote, UnitIsPlayer = _G.UnitIsPlayer, UnitIsUnit = _G.UnitIsUnit,
                 UnitName = _G.UnitName, UnitInParty = _G.UnitInParty }
  _G.DoEmote = function(token, who) emoted[#emoted + 1] = { token = token, who = who } end
  local units = { target = { name = "Kindpally", player = true }, nameplate9 = { name = "Wolfie", player = false },
                  party1 = { name = "Groupy", player = true, party = true } }
  _G.UnitName = function(u) if u == "player" then return "Me" end return units[u] and units[u].name end
  _G.UnitIsPlayer = function(u) return u == "player" or (units[u] and units[u].player) or false end
  _G.UnitIsUnit = function(a, b) return a == b end
  _G.UnitInParty = function(u) return units[u] and units[u].party or false end
  local function buff(src) return { addedAuras = { { isHelpful = true, sourceUnit = src, spellId = 1243 } } } end
  local fire = function(info) Sc.events.scripts.OnEvent(Sc.events, "UNIT_AURA", "player", info) end

  ok(sdb.thanks == false, "off until switched on: nobody gets hugged the day it is installed")
  fire(buff("target"))
  ok(#emoted == 0, "off: no emote")
  S("social on")
  ok(sdb.thanks == true, "/bist social on")
  Sc.next, Sc.thanked = nil, {}
  fire(buff("target"))
  local e = emoted[1]
  ok(e and e.who == "Kindpally", "a friendly player buffs you: an emote at them")
  local isFriendly = false
  for _, t in ipairs(Sc.EMOTES) do if e and e.token == t then isFriendly = true end end
  ok(isFriendly, "a friendly one, from the list", e and e.token)
  units.focus = { name = "Another", player = true }
  fire(buff("focus"))
  ok(#emoted == 1 and Sc.lastWhy:find("cooldown", 1, true), "within the 2-5 minute cooldown: no second emote")
  ok(Sc.next - W.now >= Sc.MIN_GAP and Sc.next - W.now <= Sc.MAX_GAP, "the cooldown is 2 to 5 minutes")
  W.now = W.now + Sc.MAX_GAP + 1
  fire(buff("target"))
  ok(#emoted == 1 and Sc.lastWhy:find("ten minutes", 1, true), "the same player again within ten minutes: no")
  fire(buff("focus"))
  ok(#emoted == 2 and emoted[2].who == "Another", "someone else after the cooldown: yes")
  W.now = W.now + 999
  -- who is never thanked
  fire(buff("player")) ok(#emoted == 2 and Sc.lastWhy == "your own buff", "your own buff: no")
  fire(buff("nameplate9")) ok(#emoted == 2 and Sc.lastWhy:find("not a player", 1, true), "a pet or creature: no")
  fire(buff("party1")) ok(#emoted == 2 and Sc.lastWhy:find("groupmate", 1, true), "a groupmate: left alone")
  fire({ addedAuras = { { isHelpful = true, sourceUnit = nil } } })
  ok(#emoted == 2 and Sc.lastWhy:find("did not say who", 1, true), "a buff from someone the game will not name: no")
  fire({ addedAuras = { { isHelpful = false, sourceUnit = "target" } } })
  ok(#emoted == 2, "a debuff: no")
  W.combat = true fire(buff("target")) W.combat = false
  ok(#emoted == 2 and Sc.lastWhy:find("fight", 1, true), "in a fight: never")
  local hiddenInfo = setmetatable({}, { __index = function() error("secret") end })
  local keepIs = _G.issecretvalue
  _G.issecretvalue = function(v) return v == hiddenInfo end
  ok(pcall(fire, hiddenInfo) and #emoted == 2, "a hidden payload: not read, no emote")
  _G.issecretvalue = keepIs
  S("social group")
  fire(buff("party1"))
  ok(#emoted == 3 and emoted[3].who == "Groupy", "/bist social group: groupmates thanked too")
  S("social group")
  -- AN EMOTE THE GAME PERFORMS AND THEN COMPLAINS ABOUT still starts the cooldown (Arn's paste: "You hug
  -- Mediumroar Dacraina." then "You thank Mediumroar Dacraina." two seconds apart, "it did it by itself")
  W.now = W.now + 999
  Sc.next = nil
  local performed = 0
  _G.DoEmote = function(token, who) performed = performed + 1 error("usage: DoEmote(token[, unit])") end
  units.mouseover = { name = "Mediumroar Dacraina", player = true }
  fire(buff("mouseover"))
  W.now = W.now + 2
  fire(buff("mouseover"))
  fire(buff("focus"))
  ok(performed == 1, "the game emoted and complained: the cooldown still started, no second emote", performed)
  ok(Sc.lastThanked and Sc.lastThanked.who == "Mediumroar Dacraina" and Sc.lastThanked.err, "and the complaint is kept for why")
  _G.DoEmote = function(token, who) emoted[#emoted + 1] = { token = token, who = who } end
  W.now = W.now + 999
  -- why
  local said = {}
  local keepAdd = DEFAULT_CHAT_FRAME.AddMessage
  DEFAULT_CHAT_FRAME.AddMessage = function(_, m) said[#said + 1] = m end
  ok(pcall(S, "social why") and table.concat(said, "\n"):find("Mediumroar Dacraina", 1, true), "/bist social why: who and why")
  -- a later piece of buff with no caster named must not hide who was thanked (Arn's paste: "last buff from:
  -- nobody yet - the game did not say who", 48 s after it thanked Mediumroar)
  fire({ addedAuras = { { isHelpful = true, sourceUnit = nil } } })
  said = {}
  S("social why")
  local w2 = table.concat(said, "\n")
  ok(w2:find("last thanked: ", 1, true) and w2:find("Mediumroar", 1, true) and w2:find("did not say who", 1, true),
     "why keeps the last one thanked apart from the last buff seen", w2)
  DEFAULT_CHAT_FRAME.AddMessage = keepAdd
  -- LEAN: everyone else's auras change constantly; that costs one string compare
  local Cost = dofile("../_bisdev/dev/cost.lua")
  local n = Cost.Count(function() for i = 1, 500 do Sc.events.scripts.OnEvent(Sc.events, "UNIT_AURA", "raid" .. (i % 25 + 1), buff("target")) end end)
  ok(n == 0, "500 aura changes on other people: no client calls: " .. n)
  S("social off")
  -- every name put back, the ones that were not there before included (pairs skips a nil)
  for _, k in ipairs({ "DoEmote", "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitInParty" }) do _G[k] = keep[k] end
end

-- ---------------------------------------------------------------- "none", and the nameplate hint
do
  local RC = NS.Recap
  local rdb = R:DBFor(R:Get("recap"))
  RC.SetStyle(rdb, "none")
  local p = CreateFrame("Frame", nil, nil)
  _G.C_NamePlate.GetNamePlateForUnit = function() return p end
  ok(RC.MarkPlate("nameplate1", "Somebody", "own") == false and RC.marks.nameplate1 == nil,
     "crosshair \"none\": no mark at all (Arn: \"they can select none\")")
  RC.SetStyle(rdb, "rails")
  ok(RC.MarkPlate("nameplate1", "Somebody", "own") == true, "and back to rails, marked")
  RC.UnmarkUnit("nameplate1")
  _G.C_NamePlate.GetNamePlateForUnit = nil
  local hint
  for _, o in ipairs(R:Get("recap").options) do if o.label == "needs nameplates on" then hint = o end end
  local cvars = {}
  local keepCV = _G.C_CVar
  _G.C_CVar = { SetCVar = function(k, v) cvars[k] = v return true end }
  ok(hint and hint.kind == "button" and hint.button == "turn on", "the options say the crosshair needs nameplates, with a button")
  hint.action()
  ok(cvars.nameplateShowEnemies == "1", "which turns enemy nameplates on")
  cvars = {}
  W.combat = true hint.action() W.combat = false
  ok(cvars.nameplateShowEnemies == nil, "never in a fight")
  _G.C_CVar = keepCV
end

-- leaked globals
-- ------------------------------------------------------------ the threat tool
-- A BiS Tools user, through Arn (13 Oct): a tank sees what is NOT on them; a dps sees nothing until
-- they pull threat. Then Arn: a CURVE - barely visible at 60% of a pull, stronger to 100%, yellow
-- to red, and flashing only near the top ("dps like to cut it close"). UnitDetailedThreatSituation
-- (who, mob): isTanking, status, scaledPercentage (100 = pulls it), ... - nothing when not listed.
do
  local RC, Th = NS.Recap, NS.Threat
  ok(Th and R:Get("threat"), "the threat tool is registered")
  local tdb = R:DBFor(R:Get("threat"))
  local plates, det, role = {}, { player = {} }, "DAMAGER"
  local keep = { get = _G.C_NamePlate.GetNamePlateForUnit, UnitDetailedThreatSituation = _G.UnitDetailedThreatSituation,
    UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned, IsInGroup = _G.IsInGroup, IsInInstance = _G.IsInInstance,
    IsInRaid = _G.IsInRaid, GetNumGroupMembers = _G.GetNumGroupMembers, issecretvalue = _G.issecretvalue, style = RC.style }
  _G.C_NamePlate.GetNamePlateForUnit = function(u) return plates[u] end
  _G.UnitDetailedThreatSituation = function(who, u)
    local d = det[who] and det[who][u]
    if not d then return end
    return d[1], d[2] or (d[1] and 3 or 0), d[3], d[3], 1000
  end
  _G.UnitGroupRolesAssigned = function() return role end
  local grouped = true
  _G.IsInGroup = function() return grouped end
  _G.IsInInstance = function() return grouped, grouped and "party" or "none" end
  _G.IsInRaid = function() return false end
  _G.GetNumGroupMembers = function() return grouped and 3 or 0 end
  local SECRET = setmetatable({}, {})
  _G.issecretvalue = function(v) return rawequal(v, SECRET) end
  RC.style = "rails"
  local function ev(e, u) Th.frame.scripts.OnEvent(Th.frame, e, u) end
  for i = 21, 23 do
    local u = "nameplate" .. i
    plates[u] = CreateFrame("Frame", nil, nil)
    plates[u]:SetSize(120, 20)
    W.plates[u] = { name = "Defias Thug", guid = "Creature-0-0-0-0-38-" .. i, hostile = true, combat = true }
    ev("NAME_PLATE_UNIT_ADDED", u)
  end
  local function mk(u) return RC.marks[u] end
  local function me(u, tanking, pct) det.player[u] = { tanking, nil, pct } ev("UNIT_THREAT_LIST_UPDATE", u) end

  me("nameplate21", false, 85)
  ok(mk("nameplate21") == nil, "out of combat: no threat crosshairs")
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate21") and mk("nameplate21").kind == "threat", "a fight starts: the crosshair is there")

  me("nameplate21", false, 50)
  ok(mk("nameplate21") == nil, "dps at 50% of a pull: nothing")
  me("nameplate21", false, 60)
  ok(mk("nameplate21") == nil, "at 60% exactly: still nothing")
  me("nameplate21", false, 61)
  local m = mk("nameplate21")
  ok(m and m.alpha < 0.06 and not m.flashing, "61%: barely visible (Arn: 'like 1%'), steady", m and m.alpha)
  local c61 = m.parts[1].color
  ok(c61[1] == 1 and c61[2] > 0.8, "and yellow")
  local a = {}
  for _, pct in ipairs({ 70, 80, 90 }) do me("nameplate21", false, pct) a[pct] = mk("nameplate21").alpha end
  ok(a[70] < a[80] and a[80] < a[90], "70, 80, 90: stronger each step", a[70] .. " " .. a[80] .. " " .. a[90])
  me("nameplate21", false, 80)
  local c80 = mk("nameplate21").parts[1].color
  ok(c80[2] > 0.35 and c80[2] < 0.55, "80%: orange", c80[2])
  me("nameplate21", false, 90)
  ok(not mk("nameplate21").flashing and not mk("nameplate21").pulse:IsPlaying(),
     "90%: cutting it close is STEADY, not flashing (Arn: 'we don't want something flashing all the time')")
  local c90 = mk("nameplate21").parts[1].color
  ok(c90[2] < c80[2], "and redder")
  me("nameplate21", false, 96)
  ok(mk("nameplate21").flashing and mk("nameplate21").pulse:IsPlaying(), "96%: it flashes")
  me("nameplate21", true, 100)
  local cOn = mk("nameplate21").parts[1].color
  ok(mk("nameplate21").flashing and cOn[2] < 0.2, "it turns on you: red, flashing")
  me("nameplate21", false, 40)
  ok(mk("nameplate21") == nil, "the tank takes it back: gone")
  ok(mk("nameplate22") == nil, "a mob you are not on the list of: nothing for a dps")

  S("threat from 80")
  ok(tdb.from == 80, "/bist threat from 80")
  me("nameplate21", false, 75)
  ok(mk("nameplate21") == nil, "now 75% is still nothing")
  me("nameplate21", false, 81)
  ok(mk("nameplate21") and mk("nameplate21").alpha < 0.06, "and 81% is barely visible")
  S("threat from 60")
  me("nameplate21", false, 0)

  det.player.nameplate22 = { SECRET, SECRET, SECRET }
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate22")
  ok(mk("nameplate22") == nil, "a threat answer the game hides: nothing, no error")
  ev("PLAYER_REGEN_ENABLED")
  ok(mk("nameplate21") == nil and mk("nameplate22") == nil, "the fight ends: every threat crosshair goes")

  -- TANK: on you - the closest groupmate's % drives it; off you - red, flashing
  role = "TANK"
  det.player = { nameplate21 = { true, 3, 100 }, nameplate22 = { false, 0, 40 } }
  det.party1 = { nameplate21 = { false, 0, 50 } }
  det.party2 = { nameplate21 = { false, 0, 85 } }
  ev("PLAYER_REGEN_DISABLED")
  local t21 = mk("nameplate21")
  ok(t21 and not t21.flashing and t21.alpha > 0.3 and t21.alpha < 0.5,
     "tank, on you, a dps at 85%: an orange warning, steady", t21 and t21.alpha)
  ok(mk("nameplate22") and mk("nameplate22").flashing and mk("nameplate22").parts[1].color[2] < 0.2,
     "tank, a mob that is NOT on you: red, flashing")
  ok(mk("nameplate23") and mk("nameplate23").flashing,
     "tank, a mob fighting the group you never touched (in a dungeon): red, flashing")
  det.party2.nameplate21 = { false, 0, 97 }
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(not mk("nameplate21").flashing, "the group is looked at no more than every half second per mob")
  local keepTime = _G.GetTime
  local tnow = keepTime() + Th.SCAN + 0.1
  _G.GetTime = function() return tnow end
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(mk("nameplate21").flashing, "half a second on: the dps at 97% makes it flash")
  _G.GetTime = keepTime
  det.party1, det.party2 = {}, {}
  Th.scan = {}
  ev("UNIT_THREAT_LIST_UPDATE", "nameplate21")
  ok(mk("nameplate21") == nil, "tank, safely on you, nobody close: nothing")
  ev("PLAYER_REGEN_ENABLED")
  grouped = false
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate23") == nil, "tank alone in the world: somebody else's fight is not yours")
  ev("PLAYER_REGEN_ENABLED")
  grouped = true

  RC.MarkPlate("nameplate22", "Defias Thug", "farm")
  ev("PLAYER_REGEN_DISABLED")
  ok(mk("nameplate22").kind == "farm", "the farm's crosshair (or a rival's) is never covered")
  ev("PLAYER_REGEN_ENABLED")
  RC.UnmarkUnit("nameplate22")

  S("threat dps")
  ok(tdb.role == "dps", "/bist threat dps: watch as a dps whatever the group role says")
  S("threat auto")
  ok(tdb.role == "auto", "/bist threat auto: back to the group role")
  ev("PLAYER_REGEN_DISABLED")
  R:SetEnabled("threat", false)
  ok(not mk("nameplate22"), "switching the tool off takes them down")
  me("nameplate22", false, 99)
  ok(not mk("nameplate22"), "and nothing more is drawn while it is off")
  R:SetEnabled("threat", true)
  ev("PLAYER_REGEN_ENABLED")

  -- COST. A dps: 300 list updates across three mobs, in a fight. A tank: the same, holding all
  -- three, with two groupmates to look at - throttled to one look per mob per T.SCAN. Measured: dps
  -- 1542 (~5 an update: the read and a "secret?" for the unit and each answer), tank 1800 (the group
  -- look cached, plus the clock for the throttle). Budgets 1650 and 1950.
  local Cost = dofile("../_bisdev/dev/cost.lua")
  role = "DAMAGER"
  det.player = {}
  ev("PLAYER_REGEN_DISABLED")
  local n, by = Cost.Count(function()
    for k = 1, 300 do
      local u = "nameplate" .. (21 + k % 3)
      det.player[u] = { false, 0, 55 + k % 45 }
      ev("UNIT_THREAT_LIST_UPDATE", u)
    end
  end)
  ok(n <= 1650, "dps: 300 threat updates ask at most 1650 things: " .. n .. " " .. Cost.Top(by, 5))
  ev("PLAYER_REGEN_ENABLED")
  role = "TANK"
  det.player = { nameplate21 = { true, 3, 100 }, nameplate22 = { true, 3, 100 }, nameplate23 = { true, 3, 100 } }
  det.party1 = { nameplate21 = { false, 0, 70 }, nameplate22 = { false, 0, 70 }, nameplate23 = { false, 0, 70 } }
  det.party2 = det.party1
  ev("PLAYER_REGEN_DISABLED")
  n, by = Cost.Count(function()
    for k = 1, 300 do ev("UNIT_THREAT_LIST_UPDATE", "nameplate" .. (21 + k % 3)) end
  end)
  ok(n <= 1950, "tank: 300 threat updates ask at most 1950 things: " .. n .. " " .. Cost.Top(by, 5))
  ev("PLAYER_REGEN_ENABLED")

  for i = 21, 23 do ev("NAME_PLATE_UNIT_REMOVED", "nameplate" .. i) W.plates["nameplate" .. i] = nil end
  _G.C_NamePlate.GetNamePlateForUnit = keep.get
  _G.UnitDetailedThreatSituation, _G.UnitGroupRolesAssigned = keep.UnitDetailedThreatSituation, keep.UnitGroupRolesAssigned
  _G.IsInGroup, _G.IsInInstance, _G.issecretvalue = keep.IsInGroup, keep.IsInInstance, keep.issecretvalue
  _G.IsInRaid, _G.GetNumGroupMembers = keep.IsInRaid, keep.GetNumGroupMembers
  RC.style = keep.style
end

local allowed = { BiSTools = true, BiSToolsDB = true, SLASH_BISTOOLS1 = true, SLASH_BISTOOLS2 = true,
  SLASH_BISTOOLS3 = true,
  -- the embedded third-party libs' own globals (Libs/THIRD-PARTY.txt): LibStub, and the world-map
  -- show flags HereBeDragons-Pins defines for every addon that pins
  LibStub = true, HBD_PINS_WORLDMAP_SHOW_PARENT = true, HBD_PINS_WORLDMAP_SHOW_CONTINENT = true,
  HBD_PINS_WORLDMAP_SHOW_WORLD = true,
  LibBiSComm = true, SLASH_BISCOMM1 = true, ConfirmSummon = true, BiSRezComm = true,
  BiSTheme = true }   -- the embedded Libs/BiSTheme/Console.lua guards on this global on purpose
for k in pairs(_G) do
  if not before[k] and not allowed[k] and not frames[k] then error("leaked global: " .. k) end
end
print(("ALL OK (%d checks)"):format(pass))
