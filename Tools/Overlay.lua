-- BiSTools / Tools / Overlay.lua
-- THE OVERLAY MAP: a see-through map over the game, Diablo style (14 Oct 2026).
--
-- Arn, 13 Oct: Diablo's overlay map - press a key, a see-through map sits over the game and you keep
-- playing through it. 14 Oct: "can we try to make the map that alpha out the useless stuff".
--
-- So: our OWN frame (never Blizzard's world map - reading or hooking it taints, Overlord 6 and 11 Oct),
-- click-through, under every other window, faint. By default it draws only the zone's EXPLORED pieces
-- (C_MapExplorationInfo - the same pieces the world map reveals): the parchment, the borders and every
-- place you have not been stay fully see-through, and the map fills in as you explore. "full" draws the
-- whole zone art instead, desaturated. On top: your arrow, and a dotted trail of where you walked.
--
-- Cost: the arrow is repainted 10 times a second ONLY while the map is up; the art is redrawn on a zone
-- change or a setting. The trail is sampled every 2 s while the tool is on and the trail is on (one
-- position question); nothing else ticks. Position or facing hidden (an instance) = no arrow, the
-- art still shows, and the corner says so.
local _, NS = ...
local T, R = NS.T, NS.Registry

local O = { TICK = 0.1, SAMPLE = 2, STEP = 0.012, TRAIL_MAX = 600, TILE = 256 }
NS.Overlay = O
O.TINT = { 0.75, 0.88, 1.0 }          -- a cold glow, so the art reads as "map", not as the world
O.ARROW = { 1.0, 0.85, 0.2 }          -- your arrow: gold, so it stands out on grey art
O.ARROW_LEN = 14

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end
local function num(v) if hidden(v) or type(v) ~= "number" then return nil end return v end

-- THE DEFAULTS ARE ARN'S PICK (14 Oct, a screenshot: "these settings keep it in a nice place"):
-- all of the map, grey, 30% of the screen's height, 50% solid
O.DEFAULT = { size = 30, alpha = 50 }
function O.Size(db) return tonumber(db.size) or O.DEFAULT.size end   -- % of the screen's height
-- Arn, 14 Oct (a world-map shot of Durotar): "a little color like this, alpha like 10%"
function O.Alpha(db) return tonumber(db.alpha) or O.DEFAULT.alpha end   -- %
function O.Grey(db) return db.grey ~= false end                 -- off: the map's own colours
function O.Mode(db) return db.mode == "explored" and "explored" or "full" end
-- Arn, 14 Oct: "also no trail its getting too busy" - off unless switched on
function O.TrailOn(db) return db.trail == true end

------------------------------------------------------------------ where am I --

function O.MapID()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and num(id) or nil
end

--- Your spot on this map, 0-1 each way, or nil (hidden, an instance, no map).
function O.Where(mapID)
  if not (mapID and C_Map and C_Map.GetPlayerMapPosition) then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
  if not ok or pos == nil or hidden(pos) then return nil end
  local ok2, x, y = pcall(function() return pos:GetXY() end)
  if ok2 then
    x = num(x)
    y = num(y)
  else
    x, y = nil, nil
  end
  if not (x and y) or (x == 0 and y == 0) then return nil end
  return x, y
end

function O.Facing()
  if not GetPlayerFacing then return nil end
  local ok, f = pcall(GetPlayerFacing)
  return ok and num(f) or nil
end

------------------------------------------------------------------ the frame --

function O.Build()
  if O.frame then return O.frame end
  local f = CreateFrame("Frame", "BiSToolsOverlayMap", UIParent)
  O.frame = f
  f:SetFrameStrata("BACKGROUND")        -- over the world, under every window
  f:EnableMouse(false)                  -- click-through: you keep playing
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  if f.SetClipsChildren then f:SetClipsChildren(true) end
  O.art, O.dots = {}, {}
  -- the arrow is OURS, three lines (Arn's screenshots, 14 Oct: the trail drew and no arrow did -
  -- the old minimap arrow file is not on Forever). A Line needs WHITE8X8 + SetVertexColor.
  O.arrow = { shown = false }
  for i = 1, 3 do
    local l = f:CreateLine(nil, "OVERLAY")
    l:SetTexture("Interface\\Buttons\\WHITE8X8")
    l:SetVertexColor(O.ARROW[1], O.ARROW[2], O.ARROW[3], 1)
    l:SetThickness(3)
    l:Hide()
    O.arrow[i] = l
  end
  O.note = f:CreateFontString(nil, "OVERLAY")
  O.note:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
  O.note:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
  f:Hide()
  -- THE TAB (Arn, 14 Oct, the Zone Map beside it: "top left, if we could do it like zone map so we
  -- can drag if we want to" - "only visible if you hover over"). The map stays click-through; this
  -- small tab at the land's top-left is the one thing that takes the mouse. It is invisible until the
  -- mouse is on it; drag it and the map follows (the map hangs off it); the spot is saved.
  local tab = CreateFrame("Button", "BiSToolsOverlayMapTab", UIParent)
  O.tab = tab
  tab:SetSize(O.TAB_W, O.TAB_H)
  tab:SetFrameStrata("LOW")
  tab:SetMovable(true)
  tab:SetClampedToScreen(true)
  tab:EnableMouse(true)
  tab:RegisterForDrag("LeftButton")
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(tab)
  bg:SetColorTexture(0.08, 0.06, 0.14, 0.9)
  local label = tab:CreateFontString(nil, "OVERLAY")
  label:SetFont(STANDARD_TEXT_FONT, 10, "")
  label:SetPoint("CENTER", tab, "CENTER", 0, 0)
  label:SetText("|cffb980ffBiS>|r map")
  tab.label = label
  tab:SetAlpha(0)
  tab:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
  tab:SetScript("OnLeave", function(self) if not self.dragging then self:SetAlpha(0) end end)
  tab:SetScript("OnDragStart", function(self) self.dragging = true self:StartMoving() end)
  tab:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.dragging = nil
    self:SetAlpha(0)
    O.SavePos(O.db)
  end)
  tab:Hide()
  return f
end

--- Where the tab sits: from the screen's top-left, x right and y down (negative). Default top-left.
O.TAB_W, O.TAB_H = 70, 16
O.POS = { 24, -80 }
function O.Pos(db)
  local p = type(db) == "table" and db.pos
  if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then return p[1], p[2] end
  return O.POS[1], O.POS[2]
end

function O.PlaceTab(db)
  local x, y = O.Pos(db)
  O.tab:ClearAllPoints()
  O.tab:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

--- After a drag: keep the tab's top-left, from the screen's top-left.
function O.SavePos(db)
  if not db then return end
  local okL, l = pcall(function() return O.tab:GetLeft() end)
  local okT, t = pcall(function() return O.tab:GetTop() end)
  local okH, h = pcall(function() return UIParent:GetHeight() end)
  l, t, h = okL and num(l), okT and num(t), okH and num(h)
  if l and t and h then db.pos = { math.floor(l + 0.5), math.floor(t - h + 0.5) } end
  O.PlaceTab(db)
end

-- one pool per draw layer: a texture is made in its layer and stays there (the base map in
-- BORDER, the explored pieces over it in ARTWORK)
O.pools = {}
local function tex(layer)
  layer = layer or "ARTWORK"
  O.pools[layer] = O.pools[layer] or {}
  local t = table.remove(O.pools[layer])
  if not t then
    t = O.frame:CreateTexture(nil, layer)
    t.layer = layer
  end
  t:Show()
  O.art[#O.art + 1] = t
  return t
end

local function clearArt()
  for i = #O.art, 1, -1 do
    local t = O.art[i]
    t:Hide()
    local p = O.pools[t.layer]
    p[#p + 1] = t
    O.art[i] = nil
  end
end

--- One texture of map art at (x, y) in the art's own pixels, w x h of it shown, out of a file fw x fh.
local function piece(file, x, y, w, h, fw, fh, layer)
  local s = O.scale
  local t = tex(layer)
  t:SetTexture(file)
  t:SetTexCoord(0, w / fw, 0, h / fh)
  t:SetSize(w * s, h * s)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", O.frame, "TOPLEFT", x * s, -y * s)
  if t.SetDesaturated then t:SetDesaturated(O.Grey(O.db or {})) end
  if O.Grey(O.db or {}) then t:SetVertexColor(O.TINT[1], O.TINT[2], O.TINT[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
  return t
end

-- the next power of two up from a piece's pixels (texture files are), at least 16
local function fileSize(px)
  local f = 16
  while f < px do f = f * 2 end
  return f
end

--- Redraw the art for this map: the explored pieces, or the whole zone.
function O.Draw(db)
  local f = O.Build()
  clearArt()
  local mapID = O.MapID()
  O.mapID = mapID
  local layers = mapID and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
  local L = type(layers) == "table" and layers[1] or nil
  local lw = L and num(L.layerWidth)
  local lh = L and num(L.layerHeight)
  if not (lw and lh and lw > 0 and lh > 0) then
    f:SetSize(400, 260)
    O.scale = 1
    O.note:SetText("no map for this place")
    return false
  end
  f:SetAlpha(O.Alpha(db) / 100)
  O.note:SetText("")
  -- 1. what to draw, in the art's own pixels
  -- a city has no explored pieces at all (the game shows it whole): there, seen = all
  -- (Arn's Orgrimmar, 14 Oct: "nothing explored here yet" over an empty map)
  local info = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
    and C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
  if type(info) ~= "table" or hidden(info) then info = {} end
  local pieces = {}
  -- "all": the base layer IS the fog of war on these maps (Arn, 14 Oct: "all setting is showing fog
  -- of war") - the world map paints the explored pieces over it, so we do too. Ground never
  -- explored stays fogged: the game hands addons only the pieces you have explored.
  if O.Mode(db) == "full" or #info == 0 then
    local tw, th = num(L.tileWidth) or O.TILE, num(L.tileHeight) or O.TILE
    local files = C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1) or {}
    local cols = math.ceil(lw / tw)
    for i, file in ipairs(files) do
      local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
      pieces[#pieces + 1] = { file, c * tw, r * th, tw, th, tw, th, "BORDER" }   -- under the pieces
    end
  end
  if #info > 0 then
    -- the explored pieces, cut the way the client cuts them: 256-pixel files, the last row and
    -- column only as big as what is left, in a file of the next power of two
    for _, e in ipairs(info) do
      local W, Hh = num(e.textureWidth), num(e.textureHeight)
      local ox, oy = num(e.offsetX) or 0, num(e.offsetY) or 0
      if W and Hh and type(e.fileDataIDs) == "table" then
        local wide, tall = math.ceil(W / O.TILE), math.ceil(Hh / O.TILE)
        for j = 1, tall do
          local ph = (j < tall) and O.TILE or (Hh - O.TILE * (tall - 1))
          for k = 1, wide do
            local pw = (k < wide) and O.TILE or (W - O.TILE * (wide - 1))
            local file = e.fileDataIDs[(j - 1) * wide + k]
            if file then
              pieces[#pieces + 1] = { file, ox + O.TILE * (k - 1), oy + O.TILE * (j - 1), pw, ph,
                (k < wide) and O.TILE or fileSize(pw), (j < tall) and O.TILE or fileSize(ph) }
            end
          end
        end
      end
    end
  end
  -- 2. the land those pieces cover (inside the map's own edges); "all" is the whole map
  local x0, y0, x1, y1 = lw, lh, 0, 0
  if O.Mode(db) == "full" then x0, y0, x1, y1 = 0, 0, lw, lh end
  for _, p in ipairs(pieces) do
    x0, y0 = math.min(x0, p[2]), math.min(y0, p[3])
    x1, y1 = math.max(x1, math.min(lw, p[2] + p[4])), math.max(y1, math.min(lh, p[3] + p[5]))
  end
  if x1 <= x0 or y1 <= y0 then x0, y0, x1, y1 = 0, 0, lw, lh end
  -- 3. size THAT land, not the canvas (Durotar sits right of the canvas's middle), and hang it from
  -- the tab: the land's top-left under the tab's bottom-left (Arn, 14 Oct: top left, draggable like
  -- the Zone Map). "map size" is the land's height as a share of the screen, never wider than it.
  local okH, sh = pcall(function() return UIParent:GetHeight() end)
  local okW, sw = pcall(function() return UIParent:GetWidth() end)
  sh = (okH and num(sh)) or 768
  sw = (okW and num(sw)) or 1024
  O.scale = math.min(sh * O.Size(db) / 100 / (y1 - y0), sw * 0.95 / (x1 - x0))
  f:SetSize(lw * O.scale, lh * O.scale)
  f:ClearAllPoints()
  O.PlaceTab(db)
  f:SetPoint("TOPLEFT", O.tab, "BOTTOMLEFT", -x0 * O.scale, y0 * O.scale)
  O.land = { x0, y0, x1, y1 }
  for _, p in ipairs(pieces) do piece(p[1], p[2], p[3], p[4], p[5], p[6], p[7], p[8]) end
  O.DrawTrail(db)
  return true
end

------------------------------------------------------------------ the trail --

function O.Trail(db, mapID)
  db.trails = type(db.trails) == "table" and db.trails or {}
  local key = tostring(mapID)
  db.trails[key] = type(db.trails[key]) == "table" and db.trails[key] or {}
  return db.trails[key]
end

--- Remember where you are, if you moved far enough since the last dot.
function O.Sample(db)
  if not O.TrailOn(db) then return false end
  local mapID = O.mapID or O.MapID()
  local x, y = O.Where(mapID)
  if not x then return false end
  local t = O.Trail(db, mapID)
  local last = t[#t]
  if last and math.abs(last[1] - x) < O.STEP and math.abs(last[2] - y) < O.STEP then return false end
  t[#t + 1] = { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
  if #t > O.TRAIL_MAX then table.remove(t, 1) end
  if O.frame and O.frame:IsShown() then O.DrawTrail(db) end
  return true
end

function O.DrawTrail(db)
  for _, d in ipairs(O.dots) do d:Hide() end
  if not (O.TrailOn(db) and O.mapID) then return end
  local W, H = O.frame:GetWidth(), O.frame:GetHeight()
  for i, p in ipairs(O.Trail(db, O.mapID)) do
    local d = O.dots[i]
    if not d then
      d = O.frame:CreateTexture(nil, "OVERLAY")
      d:SetColorTexture(1, 1, 1, 0.75)
      d:SetSize(3, 3)
      O.dots[i] = d
    end
    d:ClearAllPoints()
    d:SetPoint("CENTER", O.frame, "TOPLEFT", p[1] * W, -p[2] * H)
    d:Show()
  end
end

------------------------------------------------------------------ the arrow --

local function arrowShown(on)
  O.arrow.shown = on
  for i = 1, 3 do if on then O.arrow[i]:Show() else O.arrow[i]:Hide() end end
end

--- Your arrow: a tip ahead of you and two back corners, turned the way you face. Facing is radians
--- counter-clockwise from north; the map's up is north. A hidden facing keeps the last one.
function O.Tick()
  local x, y = O.Where(O.mapID)
  if not x then
    arrowShown(false)
    if O.note:GetText() == "" then O.note:SetText("your position is hidden here") end
    return
  end
  local face = O.Facing()
  if face then O.lastFace = face end
  face = O.lastFace or 0
  local cx, cy = x * O.frame:GetWidth(), -y * O.frame:GetHeight()
  local dx, dy = -math.sin(face), math.cos(face)            -- ahead, in screen x / up
  local px, py = dy, -dx                                    -- to your right
  local L = O.ARROW_LEN
  local tipX, tipY = cx + dx * L, cy + dy * L
  local lx, ly = cx - dx * L * 0.6 - px * L * 0.6, cy - dy * L * 0.6 - py * L * 0.6
  local rx, ry = cx - dx * L * 0.6 + px * L * 0.6, cy - dy * L * 0.6 + py * L * 0.6
  local a = O.arrow
  a.x, a.y, a.face = cx, cy, face
  a[1]:SetStartPoint("TOPLEFT", O.frame, tipX, tipY)
  a[1]:SetEndPoint("TOPLEFT", O.frame, lx, ly)
  a[2]:SetStartPoint("TOPLEFT", O.frame, tipX, tipY)
  a[2]:SetEndPoint("TOPLEFT", O.frame, rx, ry)
  a[3]:SetStartPoint("TOPLEFT", O.frame, lx, ly)
  a[3]:SetEndPoint("TOPLEFT", O.frame, rx, ry)
  arrowShown(true)
end

------------------------------------------------------------------ open / shut --

function O.Show(db, on)
  db = db or O.db
  local f = O.Build()
  if on == nil then on = not f:IsShown() end
  if on then
    O.Draw(db)
    f:Show()
    O.tab:Show()
    O.acc = 0
    f:SetScript("OnUpdate", function(_, e)
      O.acc = O.acc + e
      if O.acc >= O.TICK then O.acc = 0 O.Tick() end
    end)
    O.Tick()
  else
    f:SetScript("OnUpdate", nil)
    f:Hide()
    O.tab:Hide()
  end
  return on
end

-- the key binding (Bindings.xml: Key Bindings > BiS Tools > "Overlay map")
_G.BINDING_HEADER_BISTOOLS = "BiS Tools"
_G.BINDING_NAME_BISTOOLS_OVERLAYMAP = "Overlay map (see-through, over the game)"
function _G.BiSTools_ToggleOverlayMap()
  if not (O.db and R:Enabled("map")) then return end
  O.Show(O.db)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("ZONE_CHANGED")
ev:RegisterEvent("ZONE_CHANGED_INDOORS")
ev:SetScript("OnEvent", function()
  if O.frame and O.frame:IsShown() and O.MapID() ~= O.mapID then O.Draw(O.db) end
end)

function O.StartSampling(db)
  if O.ticker or not C_Timer or not C_Timer.NewTicker then return end
  O.ticker = C_Timer.NewTicker(O.SAMPLE, function() O.Sample(db) end)
end
function O.StopSampling()
  if O.ticker then O.ticker:Cancel() O.ticker = nil end
end

local function redraw() if O.frame and O.frame:IsShown() then O.Draw(O.db) end end

R:Register({
  name = "map",
  desc = "a see-through map over the game (pick a key in Key Bindings > BiS Tools)",
  usage = "/bist map [reset | clear]",
  defaults = {},
  options = {
    { kind = "button", label = "show / hide the map", help = "The overlay map: a faint map over the game that clicks pass through. Give it a key in the game's Key Bindings, under BiS Tools.",
      button = "map", action = function(db) O.Show(db) end },
    { kind = "seg", label = "map shows", values = { "seen", "all" },
      help = "seen: only the parts of the zone you have been to - everything else see-through, and it fills in as you explore. all: the whole zone, faint.",
      get = function(db) return O.Mode(db) == "full" and "all" or "seen" end,
      set = function(db, v) db.mode = (v == "seen") and "explored" or nil redraw() end },
    { kind = "step", label = "map size", help = "How tall the map is, as a share of your screen.", min = 30, max = 100, step = 10,
      get = function(db) return O.Size(db) end,
      set = function(db, v) db.size = v redraw() end,
      show = function(db) return O.Size(db) .. "%" end },
    { kind = "step", label = "map faintness", help = "How solid the map is: low is barely there, high is easy to read.", min = 5, max = 90, step = 5,
      get = function(db) return O.Alpha(db) end,
      set = function(db, v) db.alpha = v redraw() end,
      show = function(db) return O.Alpha(db) .. "%" end },
    { kind = "toggle", label = "grey map", help = "Off: the map in its own colours, like the world map. On: grey with a cold tint, so it reads as a map and not as the world.",
      get = function(db) return O.Grey(db) end,
      set = function(db, on) db.grey = (not on) and false or nil redraw() end },
    { kind = "toggle", label = "trail", help = "A dotted trail of where you have walked on each map, like Diablo's. /bist map clear wipes this map's.",
      get = function(db) return O.TrailOn(db) end,
      set = function(db, on)
        db.trail = on and true or false
        if on then O.StartSampling(db) else O.StopSampling() end
        redraw()
      end },
  },
  OnInit = function(_, db) O.db = db end,
  OnLogin = function(_, db) O.db = db if O.TrailOn(db) then O.StartSampling(db) end end,
  OnEnable = function(_, db) O.db = db if O.TrailOn(db) then O.StartSampling(db) end end,
  OnDisable = function() O.StopSampling() if O.frame then O.Show(O.db, false) end end,
  -- the Hub's "reset window positions" (recenter) puts the map back top-left; a plain open toggles it
  OnOpen = function(_, db, recenter)
    if recenter then
      db.pos = nil
      if O.tab then O.PlaceTab(db) end
      return
    end
    O.Show(db)
  end,
  OnSlash = function(_, db, args)
    O.db = db
    if args == "reset" then
      db.pos = nil
      if O.tab then O.PlaceTab(db) end
      return NS.Print("the map is back in the top-left corner")
    end
    if args == "clear" then
      local id = O.MapID()
      if id then O.Trail(db, id) db.trails[tostring(id)] = {} end
      redraw()
      return NS.Print("this map's trail is wiped")
    end
    O.Show(db)
  end,
})
