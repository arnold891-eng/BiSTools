--[[
  BiSTools :: Tools/ThreatWindow.lua - the threat tool's customization window.

  Arn, 13 Oct 2026, after the guild's ideas (Ariarie: a colour for every situation, "customizable
  colors would be peak"; Gnomerpills: the left side of the bar, a miniature DBM glow): "think we
  need a customization window". The shared options window has only toggles, segments and steppers,
  so this is the threat tool's own:

    Look       crosshair | marker | glow
    Watch as   auto | tank | dps
    a row per situation (Tools/Threat.lua T.STATES): on/off box, its colour swatch(es) - a click
    opens a 16-colour palette; our own colours, not Blizzard's picker, so nothing of theirs is used
    Show from / Flash from steppers, a preview on a fake plate, reset colours

  /bist threat opens it (and the Hub's row). Escape closes it. It costs nothing while closed; the
  preview's ticker runs only while the preview is on and the window shown.
]]
local _, NS = ...
local T = NS.Threat
local RC = NS.Recap
local K = NS.Farm

local U = {}
T.UI = U

U.W = 300
U.HEADER = 16
U.ROW = 18
U.PAD = 8
U.SWATCH = 12
U.PREVIEW_STEP = 1.2               -- seconds each situation shows in the preview

-- 16 colours, picked to read on a dark world and on each other
U.PALETTE = {
  { 0.73, 0.50, 1.00 }, { 0.55, 0.30, 0.95 }, { 0.30, 0.55, 1.00 }, { 0.30, 0.85, 1.00 },
  { 0.31, 0.82, 0.81 }, { 0.30, 0.85, 0.40 }, { 0.65, 0.95, 0.25 }, { 1.00, 0.85, 0.15 },
  { 0.90, 0.75, 0.29 }, { 1.00, 0.45, 0.05 }, { 1.00, 0.12, 0.12 }, { 0.75, 0.05, 0.25 },
  { 1.00, 0.45, 0.75 }, { 1.00, 1.00, 1.00 }, { 0.62, 0.62, 0.66 }, { 0.25, 0.25, 0.28 },
}

local function box(parent, w, h, shade, edge)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  K.tex(b, "BACKGROUND", shade or "field", 0.95)
  b.edge = K.border(b, edge or "edge", 1)
  return b
end

--- A row of buttons, one per value; the chosen one is lit.
local function seg(parent, y, label, values, get, set)
  local l = K.fs(parent, label, 9, "muted")
  l:SetPoint("TOPLEFT", parent, "TOPLEFT", U.PAD, y - 3)
  local btns = {}
  local w = math.floor((U.W - 80 - U.PAD - 2 * (#values - 1)) / #values)
  for i, v in ipairs(values) do
    local b = box(parent, w, 14)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 80 + (i - 1) * (w + 2), y)
    b.text = K.fs(b, v, 8, "muted")
    b.text:SetPoint("CENTER")
    b.value = v
    b:SetScript("OnClick", function() set(v) end)
    btns[i] = b
  end
  local s = { btns = btns, get = get }
  function s.Paint()
    for _, b in ipairs(btns) do
      local on = get() == b.value
      b.edge:set(on and "accent" or "edge", 1)
      b.text:SetTextColor(K.color(on and "ink" or "muted"))
    end
  end
  return s
end

--- [-] value [+]
local function stepper(parent, x, y, label, get, set, lo, hi, step)
  local l = K.fs(parent, label, 9, "muted")
  l:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
  local minus = box(parent, 14, 14)
  minus:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 62, y)
  K.fs(minus, "-", 9, "ink"):SetPoint("CENTER")
  local val = K.fs(parent, "", 9, "ink")
  val:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 80, y - 3)
  local plus = box(parent, 14, 14)
  plus:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 108, y)
  K.fs(plus, "+", 9, "ink"):SetPoint("CENTER")
  local s = { minus = minus, plus = plus, val = val }
  minus:SetScript("OnClick", function() set(math.max(lo, get() - step)) end)
  plus:SetScript("OnClick", function() set(math.min(hi, get() + step)) end)
  function s.Paint() val:SetText(get() .. "%") end
  return s
end

----------------------------------------------------------------- palette --

function U.Palette()
  if U.pal then return U.pal end
  local p = CreateFrame("Frame", nil, U.frame)
  U.pal = p
  local S = U.SWATCH + 4
  p:SetSize(4 * S + 6, 4 * S + 6)
  p:SetFrameLevel((U.frame:GetFrameLevel() or 1) + 20)
  K.tex(p, "BACKGROUND", "frame", 1)
  K.border(p, "accent", 1)
  p.cells = {}
  for i, c in ipairs(U.PALETTE) do
    local b = CreateFrame("Button", nil, p)
    b:SetSize(U.SWATCH + 2, U.SWATCH + 2)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", 3 + ((i - 1) % 4) * S, -(3 + math.floor((i - 1) / 4) * S))
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(b)
    t:SetColorTexture(c[1], c[2], c[3], 1)
    b.colour = c
    b:SetScript("OnClick", function()
      if p.target then T.SetColour(T.db, p.target.key, p.target.i, c) end
      p:Hide()
    end)
    p.cells[i] = b
  end
  p:Hide()
  return p
end

--- Open the palette by a swatch (a second click on the same swatch closes it).
function U.Pick(sw)
  local p = U.Palette()
  if p:IsShown() and p.target == sw then p:Hide() return end
  p.target = sw
  p:ClearAllPoints()
  p:SetPoint("TOPRIGHT", sw, "BOTTOMRIGHT", 0, -2)
  p:Show()
end

------------------------------------------------------------------ window --

function U.Build(db)
  if U.frame then return U.frame end
  local f = CreateFrame("Frame", "BiSToolsThreat", UIParent)
  U.frame = f
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    T.db.winPos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  local pos = db.winPos
  if type(pos) == "table" and type(pos[1]) == "string" then
    f:SetPoint(pos[1], UIParent, pos[4] or pos[1], tonumber(pos[2]) or 0, tonumber(pos[3]) or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  end
  if UISpecialFrames then table.insert(UISpecialFrames, "BiSToolsThreat") end
  K.tex(f, "BACKGROUND", "frame", 0.96)
  K.border(f, "edge", 0.6)
  f:SetWidth(U.W)

  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(U.HEADER)
  K.tex(head, "BACKGROUND", "header", 1)
  f.title = K.fs(head, "", 8, "ink")
  f.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  -- 300 wide: prompt from 4, one 12 px button at -3 -> 300 - 20 - 8 = 272 for the words
  if BiSTheme and BiSTheme.Console then
    f.con = BiSTheme.Console(f.title, { width = U.W - 20 - 8 })
    f.con:Set("name", "threat", "accent")
  end
  f.closeBtn = K.HeaderButton(head, -3, "x", "Close", "/bist threat opens it again.", function() U.Toggle(T.db, false) end, "warn")

  local y = -(U.HEADER + 6)
  U.look = seg(f, y, "Look", T.LOOKS, function() return T.Look(T.db) end,
    function(v) T.db.look = v T.Refresh() end)
  y = y - U.ROW
  U.role = seg(f, y, "Watch as", T.ROLES, function() return T.db.role or "auto" end,
    function(v) T.db.role = v T.Refresh() end)
  y = y - U.ROW - 4

  U.rows = {}
  local section
  for _, s in ipairs(T.STATES) do
    if s.role ~= section then
      section = s.role
      local h = K.fs(f, section == "tank" and "TANK" or "DPS / HEALER", 8, "accent")
      h:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD, y - 2)
      y = y - 14
    end
    local row = { key = s.key }
    local check = box(f, 12, 12)
    check:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD, y - 2)
    check.mark = K.fs(check, "x", 8, "good")
    check.mark:SetPoint("CENTER")
    check:SetScript("OnClick", function() T.SetOn(T.db, s.key, not T.IsOn(T.db, s.key)) end)
    row.check = check
    row.label = K.fs(f, s.label, 9, "ink")
    row.label:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD + 18, y - 2)
    row.swatches = {}
    local n = s.colours and 3 or 1
    for i = 1, n do
      local sw = box(f, U.SWATCH, U.SWATCH, "frame", "edge")
      sw:SetPoint("TOPLEFT", f, "TOPLEFT", 170 + (i - 1) * (U.SWATCH + 4), y - 2)
      sw.fill = sw:CreateTexture(nil, "ARTWORK")
      sw.fill:SetPoint("TOPLEFT", sw, "TOPLEFT", 1, -1)
      sw.fill:SetPoint("BOTTOMRIGHT", sw, "BOTTOMRIGHT", -1, 1)
      sw.key, sw.i = s.key, s.colours and i or nil
      sw:SetScript("OnClick", function(self) U.Pick(self) end)
      row.swatches[i] = sw
    end
    local note = s.flash and "flashes" or (s.curve and "the curve" or "")
    row.note = K.fs(f, note, 8, "muted")
    row.note:SetPoint("TOPLEFT", f, "TOPLEFT", 230, y - 3)
    U.rows[#U.rows + 1] = row
    y = y - U.ROW
  end
  y = y - 4
  U.from = stepper(f, U.PAD, y, "Show from", function() return T.From(T.db) end,
    function(v) T.db.from = v T.Refresh() end, 30, 90, 5)
  U.flash = stepper(f, U.PAD + 140, y, "Flash from", function() return T.FlashAt(T.db) end,
    function(v) T.db.flashAt = v T.Refresh() end, 70, 100, 5)
  y = y - U.ROW - 6

  -- the preview: a fake plate, each situation that is on drawn on it in turn
  U.plate = CreateFrame("Frame", nil, f)
  U.plate:SetSize(120, 10)
  U.plate:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD + 14, y - 8)
  K.tex(U.plate, "BACKGROUND", "edge", 1)
  local hp = U.plate:CreateTexture(nil, "ARTWORK")
  hp:SetPoint("TOPLEFT", U.plate, "TOPLEFT", 1, -1) hp:SetPoint("BOTTOMRIGHT", U.plate, "BOTTOMRIGHT", -30, 1)
  hp:SetColorTexture(0.75, 0.15, 0.15, 1)
  U.plateName = K.fs(U.plate, "Defias Thug", 8, "ink")
  U.plateName:SetPoint("BOTTOM", U.plate, "TOP", 0, 1)
  U.previewText = K.fs(f, "", 9, "muted")
  U.previewText:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD + 150, y - 8)
  y = y - 34

  U.previewBtn = box(f, 80, 14)
  U.previewBtn:SetPoint("TOPLEFT", f, "TOPLEFT", U.PAD, y)
  U.previewBtn.text = K.fs(U.previewBtn, "preview", 8, "ink")
  U.previewBtn.text:SetPoint("CENTER")
  U.previewBtn:SetScript("OnClick", function() U.SetPreview(not U.previewing) end)
  U.resetBtn = box(f, 90, 14)
  U.resetBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -U.PAD, y)
  U.resetBtn.text = K.fs(U.resetBtn, "reset colours", 8, "ink")
  U.resetBtn.text:SetPoint("CENTER")
  U.resetBtn:SetScript("OnClick", function() T.ResetColours(T.db) end)
  y = y - 14 - U.PAD
  f:SetHeight(-y)

  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)
    acc = acc + (dt or 0)
    if acc >= 0.1 then
      acc = 0
      if f.con then f.con:Paint() end
    end
    if U.previewing then U.PreviewTick(dt or 0) end
  end)
  f:SetScript("OnHide", function() U.SetPreview(false) if U.pal then U.pal:Hide() end end)
  f:Hide()
  return f
end

function U.Paint()
  if not U.frame then return end
  local db = T.db
  U.look.Paint()
  U.role.Paint()
  for _, row in ipairs(U.rows) do
    local on = T.IsOn(db, row.key)
    row.check.mark:SetText(on and "x" or "")
    row.label:SetTextColor(K.color(on and "ink" or "muted"))
    for _, sw in ipairs(row.swatches) do
      local c = T.ColourOf(db, sw.key, sw.i)
      sw.fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
  end
  U.from.Paint()
  U.flash.Paint()
  U.previewBtn.text:SetText(U.previewing and "stop preview" or "preview")
  if U.previewing then U.PreviewDraw() end
end

------------------------------------------------------------------ preview --

--- The situations that are on, in order.
function U.PreviewList()
  local list = {}
  for _, s in ipairs(T.STATES) do if T.IsOn(T.db, s.key) then list[#list + 1] = s end end
  return list
end

function U.PreviewDraw()
  local list = U.PreviewList()
  local s = list[((U.previewAt or 1) - 1) % math.max(1, #list) + 1]
  local look = T.Look(T.db)
  if U.mark and U.mark.look ~= look then U.mark:Hide() U.mark = nil end
  if not s then
    if U.mark then U.mark:Hide() end
    U.previewText:SetText("nothing is switched on")
    return
  end
  if not U.mark then
    if look == "crosshair" and RC.NewMark then
      U.mark = RC.NewMark("threat")
      U.mark.look = "crosshair"
      U.mark:SetParent(U.frame)
      U.mark:SetScale(0.45)
      U.mark:ClearAllPoints()
      U.mark:SetPoint("TOP", U.plate, "BOTTOM", 0, -2)
      U.mark:SetSize(120, RC.MARK_H)
    else
      U.mark = T.NewIndicator(look == "crosshair" and "marker" or look)
      U.mark.look = look
      U.mark:SetParent(U.frame)
      T.Place(U.mark, U.plate)
    end
  end
  -- a curve is shown three quarters of the way up, the way it looks closing in
  local r, g, b, alpha, flash = T.Style(T.db, s.key, s.curve and 0.75 or 1, s.curve and 90 or 100)
  local parts = U.mark.parts or {}
  for _, t in ipairs(parts) do t:SetColorTexture(r, g, b, t.ringAlpha or 1) end
  if U.mark.pulse then
    if flash then U.mark.pulse:Play() else U.mark.pulse:Stop() end
  end
  if not flash then U.mark:SetAlpha(alpha) end
  U.mark:Show()
  U.previewText:SetText(s.label .. (flash and " (flashes)" or ""))
end

function U.PreviewTick(dt)
  U.previewAcc = (U.previewAcc or 0) + dt
  if U.previewAcc >= U.PREVIEW_STEP then
    U.previewAcc = 0
    U.previewAt = (U.previewAt or 1) + 1
    U.PreviewDraw()
  end
end

function U.SetPreview(on)
  U.previewing = on and true or false
  U.previewAt, U.previewAcc = 1, 0
  if not on then
    if U.mark then
      if U.mark.pulse then U.mark.pulse:Stop() end
      U.mark:Hide()
    end
    if U.previewText then U.previewText:SetText("") end
  end
  if U.previewBtn then U.previewBtn.text:SetText(U.previewing and "stop preview" or "preview") end
  if on then U.PreviewDraw() end
end

------------------------------------------------------------- open / close --

function U.IsOpen() return U.frame ~= nil and U.frame:IsShown() end

function U.Open(db, recenter)
  U.Build(db)
  if recenter then
    U.frame:ClearAllPoints()
    U.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    db.winPos = { "CENTER", 0, 0, "CENTER" }
  end
  U.frame:Show()
  U.Paint()
end

function U.Toggle(db, want)
  U.Build(db)
  if want == nil then want = not U.frame:IsShown() end
  if want then U.Open(db) else U.frame:Hide() end
end
