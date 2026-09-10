-- BiSTools / Tools / Hub.lua
-- The minimap button and the two windows behind it. Not a Registry tool: it is
-- how you reach the tools, so it cannot be switched off.
--
-- Arn (10 Sep 2026): "the / commands are so convoluted between all the addons
-- ... work on the minimap icon; right click opens the options we haven't built;
-- the first window shows all the tools we can open" and "right now I have no
-- idea where the farm window is at".
--
--   minimap button   left-click  -> the Hub (every tool, click one to open it)
--                    right-click -> Options
--                    drag        -> slides around the minimap rim (angle saved)
--   Hub row          left-click  -> open that tool's window (and switch it on)
--                    shift-click -> open it AND bring it to the middle of the screen
--                    right-click -> switch the tool on / off
--   Options          on/off per tool, then each tool's `options` list: toggles,
--                    3-way segs, steppers. "reset positions" drags every window
--                    back to the middle.
--
-- A tool takes part by giving the Registry `OnOpen(tool, db, recenter)` and an
-- `options` list (see Registry.lua). Windows use the Farm kit (K.*) and the
-- BiSTheme prompt, like Summon.
local _, NS = ...
local T = NS.T
local K = NS.Farm
local R = NS.Registry
local H = {}
NS.Hub = H

H.W, H.OPT_W = 170, 230
H.ROW = 16
H.SEG_W, H.STEP_W, H.BOX = 36, 18, 10   -- seg: "always" at 8 pt is ~29 px, keep 36

-- ---------------------------------------------------------------- db
function H.DB()
  local db = NS.DB()
  db.hub = db.hub or {}
  local h = db.hub
  if h.angle == nil then h.angle = 225 end
  if h.minimap == nil then h.minimap = true end
  return h
end

-- ---------------------------------------------------------------- minimap
-- Hand-rolled, no LibDBIcon: a 31 px round button riding the minimap rim at
-- db.hub.angle degrees (0 = east, counter-clockwise), like every other minimap
-- button the raid already has. Drag it and the angle follows the cursor.
function H.MinimapPos(angle)
  local r = 80
  local a = math.rad(angle or 225)
  return math.cos(a) * r, math.sin(a) * r
end

function H.PlaceMinimap()
  local b = H.mm
  if not b then return end
  local x, y = H.MinimapPos(H.DB().angle)
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function H.DragMinimap()
  -- angle from the minimap centre to the cursor, in the minimap's own scale
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  cx, cy = cx / scale, cy / scale
  local angle = math.deg(math.atan2(cy - my, cx - mx))
  H.DB().angle = angle
  H.PlaceMinimap()
end

function H.BuildMinimap()
  if H.mm or not Minimap then return H.mm end
  local b = CreateFrame("Button", "BiSToolsMinimap", Minimap)
  H.mm = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER", b, "CENTER", 0, 1)
  icon:SetTexture("Interface\\Icons\\Spell_Shadow_Twilight")
  if icon.SetTexCoord then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  b.icon = icon
  local ring = b:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b.ring = ring
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetSize(31, 31) hl:SetPoint("CENTER")
  hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then H.ToggleOptions() else H.ToggleHub() end
  end)
  b:SetScript("OnDragStart", function(self) self.dragging = true self:SetScript("OnUpdate", H.DragMinimap) end)
  b:SetScript("OnDragStop", function(self) self.dragging = nil self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(T.text("accent", "BiS") .. " Tools " .. T.text("muted", NS.VERSION))
    GameTooltip:AddLine("left: the tools  |  right: options  |  drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  H.PlaceMinimap()
  H.ApplyMinimap()
  return b
end

function H.ApplyMinimap()
  if not H.mm then return end
  if H.DB().minimap == false then H.mm:Hide() else H.mm:Show() end
end

-- ---------------------------------------------------------------- shared bits
local function Window(name, w, title)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, K.HEADER)
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true) f:EnableMouse(true) f:SetClampedToScreen(true)
  K.tex(f, "BACKGROUND", "frame", K.BODY_A)
  K.border(f, "edge", 0.35)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT") head:SetHeight(K.HEADER)
  K.tex(head, "BACKGROUND", "header", K.HEAD_A)
  local hair = head:CreateTexture(nil, "BORDER")
  hair:SetPoint("BOTTOMLEFT") hair:SetPoint("BOTTOMRIGHT") hair:SetHeight(1)
  do local r, g, b = K.color("edge") hair:SetColorTexture(r, g, b, 1) end
  -- header budget: 4 + prompt (<= w - 15 - 8) | x(12)@-3. Nothing else.
  local fs = K.fs(head, "", 8, "ink")
  fs:SetPoint("LEFT", head, "LEFT", 4, 0)
  local con = BiSTheme.Console(fs, { width = w - 15 - 8 })
  con:Set("name", title, "accent")
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
  head:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  local close = K.HeaderButton(head, -3, "x", "Close", nil, function() f:Hide() end, "warn")
  local body = CreateFrame("Frame", nil, f)
  body:SetPoint("TOPLEFT", head, "BOTTOMLEFT") body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
  body:SetHeight(1)
  f.head, f.body, f.con, f.title, f.closeBtn = head, body, con, fs, close
  f:Hide()   -- a new frame is shown by default; the toggle decides
  f:SetScript("OnUpdate", function(_, dt)
    f.elapsed = (f.elapsed or 0) + dt
    if f.elapsed >= 0.1 then f.elapsed = 0 con:Paint() end
  end)
  return f
end

local function Fit(f, bodyH, footH)
  f.body:SetHeight(math.max(bodyH, 1))
  f:SetHeight(K.HEADER + math.max(bodyH, 1) + (footH or 0))
end

-- a 10 px on/off box: filled accent when on, empty edge when off
local function Box(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(H.BOX, H.BOX)
  b.fill = K.tex(b, "BACKGROUND", "accent", 1)
  b.edge = K.border(b, "edge", 1)
  function b:Set(on)
    self.on = on and true or false
    if self.on then self.fill:Show() self.edge:set("accent", 1) else self.fill:Hide() self.edge:set("edge", 1) end
  end
  b:Set(false)
  return b
end

-- ---------------------------------------------------------------- the Hub
function H.BuildHub()
  if H.hub then return H.hub end
  local f = Window("BiSToolsHub", H.W, "Tools")
  H.hub = f
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  f.rows = {}
  local i = 0
  for key, tool in R:Each() do
    i = i + 1
    local r = CreateFrame("Button", "BiSToolsHubRow" .. i, f.body)
    r:SetHeight(H.ROW)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * H.ROW)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * H.ROW)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.bg = K.tex(r, "BACKGROUND", "sunken", 0)
    r.name = K.fs(r, tool.name, 9, "ink")
    r.name:SetPoint("LEFT", 6, 0)
    r.state = K.fs(r, "", 8, "muted")
    r.state:SetPoint("RIGHT", -6, 0)
    r.key, r.tool = key, tool
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        R:SetEnabled(self.key, not R:Enabled(self.key))
        f.con:Say(self.key .. (R:Enabled(self.key) and " on" or " off"), R:Enabled(self.key) and "good" or "warn")
      else
        H.Open(self.key, IsShiftKeyDown and IsShiftKeyDown())
      end
      H.PaintHub()
    end)
    r:SetScript("OnEnter", function(self)
      self.bg:SetAlpha(0.9)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tool.name)
        GameTooltip:AddLine(self.tool.desc or "", 1, 1, 1, true)
        GameTooltip:AddLine("click: open (again: bring it to the middle)  |  shift-click: open in the middle  |  right-click: on/off", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function(self) self.bg:SetAlpha(0) if GameTooltip then GameTooltip:Hide() end end)
    f.rows[i] = r
  end
  -- footer: one button, full width
  local foot = CreateFrame("Button", "BiSToolsHubOptions", f)
  foot:SetPoint("BOTTOMLEFT") foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(K.HEADER)
  K.tex(foot, "BACKGROUND", "field", 0.9)
  foot.edge = K.border(foot, "edge", 1)
  foot.label = K.fs(foot, "options", 9, "ink2")
  foot.label:SetPoint("CENTER")
  foot:SetScript("OnClick", function() H.ToggleOptions() end)
  foot:SetScript("OnEnter", function() foot.edge:set("accent", 1) end)
  foot:SetScript("OnLeave", function() foot.edge:set("edge", 1) end)
  f.foot = foot
  Fit(f, #f.rows * H.ROW + 4, K.HEADER)
  H.PaintHub()
  return f
end

function H.PaintHub()
  local f = H.hub
  if not f then return end
  local on = 0
  for _, r in ipairs(f.rows) do
    local en = R:Enabled(r.key)
    if en then on = on + 1 end
    local cr, cg, cb = K.color(en and "accent" or "muted")
    r.name:SetTextColor(cr, cg, cb, 1)
    r.state:SetText(en and T.text("good", "on") or T.text("warn", "off"))
  end
  f.con:Set("count", on .. " of " .. #f.rows .. " on", "ink2")
end

-- open a tool's window: switch it on if it was off, then hand it to the tool.
-- recenter = true drags the window to the middle of the screen. Clicking a tool
-- whose window is ALREADY open means "bring it to me" (Arn, 10 Sep: "this is
-- beautiful but I can't find the window for the farm") - so that recenters too.
function H.Open(key, recenter)
  local tool = R:Get(key)
  if not tool then return false end
  if not R:Enabled(key) then R:SetEnabled(key, true) end
  local db = R:DBFor(tool)
  if not recenter and tool.IsOpen and tool:IsOpen(db) then recenter = true end
  if tool.OnOpen then tool:OnOpen(db, recenter and true or false) return true end
  return false
end

function H.ToggleHub(want)
  local f = H.BuildHub()
  if want == nil then want = not f:IsShown() end
  if want then H.PaintHub() f:Show() else f:Hide() end
end

-- ---------------------------------------------------------------- Options
-- one row per option. Kinds:
--   toggle  { label, get(db), set(db, on) }
--   seg     { label, values = {...}, get, set }         3 small buttons, the live one accent
--   step    { label, min, max, step, unit, get, set }   < value >
--   button  { label, action(db) }
local function Control(row, opt, db, f)
  local kind = opt.kind
  if kind == "toggle" then
    local b = Box(row)
    b:SetPoint("RIGHT", -6, 0)
    b:SetScript("OnClick", function()
      opt.set(db, not opt.get(db))
      H.PaintOptions()
      f.con:Say(opt.label .. (opt.get(db) and " on" or " off"), opt.get(db) and "good" or "warn")
    end)
    row.ctl = b
    row.paint = function() b:Set(opt.get(db) and true or false) end
  elseif kind == "seg" then
    local segs = {}
    for i, v in ipairs(opt.values) do
      local s = CreateFrame("Button", nil, row)
      s:SetSize(H.SEG_W, 12)
      s:SetPoint("RIGHT", -6 - (#opt.values - i) * (H.SEG_W + 2), 0)
      K.tex(s, "BACKGROUND", "field", 0.9)
      s.edge = K.border(s, "edge", 1)
      s.label = K.fs(s, v, 8, "muted")
      s.label:SetPoint("CENTER")
      BiSTheme.Fit(s.label, v, H.SEG_W - 4)
      s:SetScript("OnClick", function() opt.set(db, v) H.PaintOptions() f.con:Say(opt.label .. ": " .. v, "ink2") end)
      segs[i] = s
    end
    row.ctl = segs
    row.paint = function()
      local cur = opt.get(db)
      for i, s in ipairs(segs) do
        local on = opt.values[i] == cur
        s.edge:set(on and "accent" or "edge", 1)
        local r, g, b = K.color(on and "accent" or "muted")
        s.label:SetTextColor(r, g, b, 1)
      end
    end
  elseif kind == "step" then
    local plus = CreateFrame("Button", nil, row)
    plus:SetSize(H.STEP_W, 12) plus:SetPoint("RIGHT", -6, 0)
    K.tex(plus, "BACKGROUND", "field", 0.9) plus.edge = K.border(plus, "edge", 1)
    plus.label = K.fs(plus, ">", 8, "muted") plus.label:SetPoint("CENTER")
    local val = K.fs(row, "", 8, "ink2")
    val:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    local minus = CreateFrame("Button", nil, row)
    minus:SetSize(H.STEP_W, 12) minus:SetPoint("RIGHT", plus, "LEFT", -46, 0)
    K.tex(minus, "BACKGROUND", "field", 0.9) minus.edge = K.border(minus, "edge", 1)
    minus.label = K.fs(minus, "<", 8, "muted") minus.label:SetPoint("CENTER")
    local function bump(dir)
      local v = tonumber(opt.get(db)) or opt.min
      v = v + dir * opt.step
      if v < opt.min then v = opt.min elseif v > opt.max then v = opt.max end
      opt.set(db, v)
      H.PaintOptions()
      f.con:Say(opt.label .. ": " .. opt.show(db), "ink2")
    end
    plus:SetScript("OnClick", function() bump(1) end)
    minus:SetScript("OnClick", function() bump(-1) end)
    for _, b in ipairs({ plus, minus }) do
      b:SetScript("OnEnter", function() b.edge:set("accent", 1) end)
      b:SetScript("OnLeave", function() b.edge:set("edge", 1) end)
    end
    row.ctl = { minus = minus, plus = plus, val = val }
    row.paint = function() BiSTheme.Fit(val, opt.show(db), 40) end
  elseif kind == "button" then
    local b = CreateFrame("Button", nil, row)
    b:SetSize(60, 12) b:SetPoint("RIGHT", -6, 0)
    K.tex(b, "BACKGROUND", "field", 0.9) b.edge = K.border(b, "edge", 1)
    b.label = K.fs(b, opt.button or "go", 8, "muted") b.label:SetPoint("CENTER")
    BiSTheme.Fit(b.label, opt.button or "go", 56)
    b:SetScript("OnClick", function() opt.action(db) H.PaintOptions() f.con:Say(opt.label, "ink2") end)
    b:SetScript("OnEnter", function() b.edge:set("accent", 1) end)
    b:SetScript("OnLeave", function() b.edge:set("edge", 1) end)
    row.ctl = b
    row.paint = function() end
  end
end

-- the Hub's own options, listed under "tools"
function H.OwnOptions()
  return {
    { kind = "toggle", label = "minimap button", get = function() return H.DB().minimap ~= false end,
      set = function(_, on) H.DB().minimap = on and true or false H.ApplyMinimap() end },
    { kind = "toggle", label = "BiS channel (/biscomm)", get = function() local l = _G.LibBiSComm return l and l:Enabled() end,
      set = function(_, on) local l = _G.LibBiSComm if l then l:SetEnabled(on and true or false) end end },
    { kind = "button", label = "reset window positions", button = "reset", action = function() H.ResetPositions() end },
  }
end

function H.ResetPositions()
  for key, tool in R:Each() do
    if tool.OnOpen and R:Enabled(key) then tool:OnOpen(R:DBFor(tool), true) end
  end
  for _, f in ipairs({ H.hub, H.opt }) do
    if f then f:ClearAllPoints() f:SetPoint("CENTER", UIParent, "CENTER", 0, 120) end
  end
end

function H.BuildOptions()
  if H.opt then return H.opt end
  local f = Window("BiSToolsOptions", H.OPT_W, "Options")
  H.opt = f
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f.rows = {}
  local y = 0
  local function row(name)
    local r = CreateFrame("Frame", name, f.body)
    r:SetHeight(H.ROW)
    r:SetPoint("TOPLEFT", 0, -y) r:SetPoint("TOPRIGHT", 0, -y)
    y = y + H.ROW
    f.rows[#f.rows + 1] = r
    return r
  end
  local function section(title, key)
    local r = row()
    r.bg = K.tex(r, "BACKGROUND", "header", 0.6)
    r.name = K.fs(r, T.text("accent", title), 9, "ink")
    r.name:SetPoint("LEFT", 6, 0)
    if key then
      local b = Box(r)
      b:SetPoint("RIGHT", -6, 0)
      b:SetScript("OnClick", function()
        R:SetEnabled(key, not R:Enabled(key))
        H.PaintOptions() H.PaintHub()
        f.con:Say(key .. (R:Enabled(key) and " on" or " off"), R:Enabled(key) and "good" or "warn")
      end)
      r.ctl = b
      r.paint = function() b:Set(R:Enabled(key)) end
    end
    return r
  end
  local function optRow(opt, db)
    local r = row()
    r.name = K.fs(r, opt.label, 8, "ink2")
    r.name:SetPoint("LEFT", 12, 0)
    BiSTheme.Fit(r.name, opt.label, H.OPT_W - 12 - 110)
    Control(r, opt, db, f)
    return r
  end
  section("tools")
  for _, opt in ipairs(H.OwnOptions()) do optRow(opt, nil) end
  for key, tool in R:Each() do
    section(tool.name, key)
    for _, opt in ipairs(tool.options or {}) do optRow(opt, R:DBFor(tool)) end
  end
  Fit(f, y + 4, 0)
  H.PaintOptions()
  return f
end

function H.PaintOptions()
  local f = H.opt
  if not f then return end
  for _, r in ipairs(f.rows) do if r.paint then r.paint() end end
end

function H.ToggleOptions(want)
  local f = H.BuildOptions()
  if want == nil then want = not f:IsShown() end
  if want then H.PaintOptions() f:Show() else f:Hide() end
end

-- ---------------------------------------------------------------- boot
-- at login, after every tool registered (this file is last in the TOC)
H.frame = CreateFrame("Frame")
H.frame:RegisterEvent("PLAYER_LOGIN")
H.frame:SetScript("OnEvent", function()
  H.BuildMinimap()
end)

-- /bt hub | /bt options  (the slash is the fallback; the button is the way)
NS.HubSlash = function(cmd)
  if cmd == "options" or cmd == "opt" or cmd == "config" then H.ToggleOptions() return true end
  if cmd == "hub" or cmd == "tools" or cmd == "show" then H.ToggleHub() return true end
  if cmd == "minimap" then H.DB().minimap = not (H.DB().minimap ~= false) H.ApplyMinimap()
    NS.Print("minimap button %s", H.DB().minimap and T.text("good", "on") or T.text("warn", "off")) return true end
  return false
end
