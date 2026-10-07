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
-- Window / Fit / Box / Control USED TO LIVE HERE. Arn, 10 Sep: "this is
-- beautiful ... I want all option windows to look like this", so they moved out
-- to Libs\BiSTheme\Options.lua and this file kept only what is actually about
-- BiSTools: the minimap button, the tools list, and which option belongs to
-- which tool. See claude/bis-options.md for the law, and note the copy under
-- Libs\ is byte-identical to BiSTheme's - never edit it in place.
-- ---------------------------------------------------------------- the Hub
function H.BuildHub()
  if H.hub then return H.hub end
  -- The list is not an options list, but it is the same chrome: the kit builds
  -- the frame, the prompt header and the 16 px rows, and the Hub decorates them.
  local f = BiSTheme.Options("BiSToolsHub", H.W, "Tools")
  H.hub = f
  f:Recenter(120)
  local i = 0
  for key, tool in R:Each() do
    i = i + 1
    local r = f:AddRow("Button", "BiSToolsHubRow" .. i)
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
  f:Fit(K.HEADER)   -- the footer is the Hub's own; an options window has none
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
  H.PaintHub()   -- the kit's Paint walks r.paint; the tool rows are painted here
  f:Toggle(want)
end

-- ---------------------------------------------------------------- Options
-- The four control kinds - toggle / seg / step / button - are the kit's now.
-- A setting that fits none of them is a slash command, not a fifth kind.

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
  if H.hub then H.hub:Recenter(120) end
  if H.opt then H.opt:Recenter(60) end
end

function H.BuildOptions()
  if H.opt then return H.opt end
  local f = BiSTheme.Options("BiSToolsOptions", H.OPT_W, "Options")
  H.opt = f
  f:Recenter(60)
  -- the tools list shows on/off too, so it repaints whenever a section box does
  f.onChange = function() H.PaintHub() end

  f:Section("tools")
  for _, opt in ipairs(H.OwnOptions()) do f:Row(opt, nil) end
  for key, tool in R:Each() do
    f:Section(tool.name, {
      get = function() return R:Enabled(key) end,
      set = function(on) R:SetEnabled(key, on) end,
    })
    for _, opt in ipairs(tool.options or {}) do f:Row(opt, R:DBFor(tool)) end
  end
  f:Fit()
  return f
end

function H.PaintOptions()
  if H.opt then H.opt:Paint() end
end

function H.ToggleOptions(want)
  H.BuildOptions():Toggle(want)
end

-- ---------------------------------------------------------------- boot
-- at login, after every tool registered (this file is last in the TOC)
H.frame = CreateFrame("Frame")
H.frame:RegisterEvent("PLAYER_LOGIN")
H.frame:SetScript("OnEvent", function()
  H.BuildMinimap()
end)

-- /bist hub | /bist options  (the slash is the fallback; the button is the way)
NS.HubSlash = function(cmd)
  if cmd == "options" or cmd == "opt" or cmd == "config" then H.ToggleOptions() return true end
  if cmd == "hub" or cmd == "tools" or cmd == "show" then H.ToggleHub() return true end
  if cmd == "minimap" then H.DB().minimap = not (H.DB().minimap ~= false) H.ApplyMinimap()
    NS.Print("minimap button %s", H.DB().minimap and T.text("good", "on") or T.text("warn", "off")) return true end
  return false
end
