-- BiSTools / Tools / FarmPins.lua
-- The farm spots on the MINIMAP and the WORLD MAP (6 Oct 2026).
--
-- Arn, having installed Questie: "can we see how questie puts marks on the minimap and can we do
-- that?" Questie draws with HereBeDragons-Pins, and so does this: every recorded spot of the mob
-- being farmed shows as its own raid mark - the skull, the cross - where it was recorded.
--
--   bright   it is up: the respawn timer has run out, go there
--   dim      it is waiting to respawn (the tooltip says how long)
--
-- Only positions the PLAYER recorded are drawn. Where another unit stands is not something the
-- client tells an addon, so a live mob can never be a pin - the spots are what this tool knows.
--
-- HereBeDragons is BSD (Nevcairiel), embedded unmodified under Libs/ - see Libs/THIRD-PARTY.txt.
-- Without it (a stripped copy, a client it refuses), this file does nothing and says nothing.
local _, NS = ...
local F = NS.Farm
local S = F and F.Spots
local T = NS.T

local P = { pins = {}, pool = {} }
F.Pins = P

P.ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
P.SIZE = 14
P.DOT = 7
P.DIM, P.BRIGHT = 0.45, 1.0

local function lib()
  return LibStub and LibStub("HereBeDragons-Pins-2.0", true)
end

-- One small button per pin, reused. A button so the tooltip can be read by hovering.
local function newPin()
  local b = table.remove(P.pool)
  if b then return b end
  b = CreateFrame("Button", nil, UIParent)
  b:SetSize(P.SIZE, P.SIZE)
  b.tex = b:CreateTexture(nil, "OVERLAY")
  b.tex:SetAllPoints()
  b:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.info then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.info.name)
    GameTooltip:AddLine(self.info.state, 1, 1, 1)
    GameTooltip:AddLine(("%d kill%s here"):format(self.info.kills, self.info.kills == 1 and "" or "s"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function release(b)
  b.info = nil
  b:Hide()
  P.pool[#P.pool + 1] = b
end

function P.Clear()
  local H = lib()
  if H then
    H:RemoveAllMinimapIcons(P)
    H:RemoveAllWorldMapIcons(P)
  end
  for _, pair in pairs(P.pins) do release(pair.mini) release(pair.world) end
  P.pins = {}
end

--- Every spot worth a pin: the zones, and the subs inside them, each with its own mark.
function P.Spots(db)
  local out = {}
  local mob = S and S.Shown(db)
  if not mob or not db.spots or not db.spots[mob] then return out, mob end
  for _, z in ipairs(db.spots[mob]) do
    -- EVERY spot, marked or not (6 Oct 2026). There are only eight raid marks and Arn's lion had
    -- seventeen zones: the first version pinned only the marked ones, so #9 to #17 were missing
    -- from the map. An unmarked spot is a small gold dot.
    if type(z.map) == "number" and type(z.x) == "number" and type(z.y) == "number" then
      out[#out + 1] = z
    end
    for _, sb in ipairs(z.subs or {}) do
      local map = sb.map or z.map
      if type(map) == "number" and type(sb.x) == "number" and type(sb.y) == "number" then
        out[#out + 1] = sb
      end
    end
  end
  return out, mob
end

--- Draw what is recorded now. Pins are keyed by the spot TABLE, so a spot that moves or goes keeps
--- its own pins and nothing else is touched.
---
--- TWO FRAMES PER SPOT, one per map (6 Oct 2026). The first version handed ONE frame to both maps,
--- every add answered true, and Arn saw nothing on either: HereBeDragons reparents a pin's frame
--- into whichever map draws it (the minimap on add; a world-map pin when that map draws; Hide and
--- back to UIParent when it lets go), so the two maps fought over one frame. Every addon that uses
--- the library gives each map its own frame.
function P.Update(db)
  local H = lib()
  if not H or db.pins == false then return P.Clear() end
  local spots, mob = P.Spots(db)
  local now = time()
  local seen = {}
  for _, sp in ipairs(spots) do
    seen[sp] = true
    local pair = P.pins[sp]
    if not pair then
      local parent = sp.map and sp or nil
      if not parent then
        for _, z in ipairs(db.spots[mob]) do
          for _, x in ipairs(z.subs or {}) do if x == sp then parent = z end end
        end
      end
      local map = sp.map or (parent and parent.map)
      local mark = sp.mark or (parent and parent.mark)
      pair = { mini = newPin(), world = newPin(), map = map, mark = mark }
      P.pins[sp] = pair
      for _, b in pairs({ pair.mini, pair.world }) do
        if mark then
          b:SetSize(P.SIZE, P.SIZE)
          b.tex:SetTexture(P.ICON .. mark)
        else
          b:SetSize(P.DOT, P.DOT)
          b.tex:SetColorTexture(1.0, 0.82, 0.2, 1)     -- gold dot: a spot with no mark of its own
        end
      end
      -- each add answers false for coordinates it cannot place; kept for /bist farm pins why
      P.lastMini = H:AddMinimapIconMap(P, pair.mini, map, sp.x, sp.y, true, false)
      P.lastWorld = H:AddWorldMapIconMap(P, pair.world, map, sp.x, sp.y, HBD_PINS_WORLDMAP_SHOW_PARENT)
    end
    local text, _, key = S.Describe(sp, now)
    local up = key and key < 0
    local info = { name = mob, kills = sp.kills or 0,
                   state = up and "up now" or (sp.respawn and ("back in " .. text) or ("last kill " .. text .. " ago")) }
    for _, b in pairs({ pair.mini, pair.world }) do
      b:SetAlpha(up and P.BRIGHT or P.DIM)
      b.info = info
    end
  end
  for sp, pair in pairs(P.pins) do
    if not seen[sp] then
      H:RemoveMinimapIcon(P, pair.mini)
      H:RemoveWorldMapIcon(P, pair.world)
      release(pair.mini) release(pair.world)
      P.pins[sp] = nil
    end
  end
end

-- Once a second is plenty: a respawn timer is counted in seconds, and the pins only change colour.
function P.Start(db)
  if P.ticker then P.ticker:Cancel() end
  P.ticker = C_Timer.NewTicker(1, function() P.Update(db) end)
  P.Update(db)
end

function P.Stop()
  if P.ticker then P.ticker:Cancel() P.ticker = nil end
  P.Clear()
end

-- ride the farm tool's own switch: on with it (here), off with it (its OnDisable calls P.Stop)
local hook = F.Hook
function F.Hook(db)
  hook(db)
  P.Start(db)
end

--- /bist farm pins why - every step between a recorded spot and a pin on the map, printed, so a
--- "nothing shows" is one paste instead of an evening of guessing (6 Oct 2026, Arn: "pins do not
--- show on minimap or big map").
function P.Why(db)
  local say = NS.Print
  local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
  local H = lib()
  local iface = select(4, GetBuildInfo())
  say("pins: HereBeDragons %s, Pins %s", HBD and ("minor " .. tostring(select(2, LibStub:GetLibrary("HereBeDragons-2.0", true)))) or "NOT LOADED",
      H and "loaded" or "NOT LOADED")
  say("pins: client interface %s, WOW_PROJECT_ID %s, WOW_PROJECT_CAMELOT %s, WOW_PROJECT_CLASSIC %s",
      tostring(iface), tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_CAMELOT), tostring(WOW_PROJECT_CLASSIC))
  say("pins: setting %s, ticker %s, drawn now %d",
      db.pins == false and "OFF" or "on", P.ticker and "running" or "STOPPED", (function() local n = 0 for _ in pairs(P.pins) do n = n + 1 end return n end)())
  local spots, mob = P.Spots(db)
  local all = mob and db.spots and db.spots[mob]
  say("pins: mob %s, zones recorded %d, pinnable spots %d", tostring(mob), all and #all or 0, #spots)
  local sp = spots[1]
  if sp then
    local map = sp.map or (all and all[1] and all[1].map)
    say("pins: first spot map %s at %.3f, %.3f, mark %s", tostring(map), sp.x or -1, sp.y or -1, tostring(sp.mark))
    if HBD and HBD.GetWorldCoordinatesFromZone then
      local ok, wx, wy, inst = pcall(HBD.GetWorldCoordinatesFromZone, HBD, sp.x, sp.y, map)
      say("pins: its world position %s", ok and (wx and ("%.1f, %.1f in instance %s"):format(wx, wy, tostring(inst)) or "NONE - HereBeDragons does not know this map") or ("error: " .. tostring(wx)))
    end
  end
  if HBD and HBD.GetPlayerZone then
    local ok, m = pcall(HBD.GetPlayerZone, HBD)
    say("pins: HereBeDragons says you are on map %s", ok and tostring(m) or ("error: " .. tostring(m)))
  end
  if HBD and HBD.GetPlayerWorldPosition then
    local ok, x, y, inst = pcall(HBD.GetPlayerWorldPosition, HBD)
    say("pins: your world position %s", ok and (x and ("%.1f, %.1f in instance %s"):format(x, y, tostring(inst)) or "NONE") or ("error: " .. tostring(x)))
  end
  local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  say("pins: the client says you are on map %s", tostring(map))
  say("pins: last add - minimap %s, world map %s", tostring(P.lastMini), tostring(P.lastWorld))
end

--- /bist farm pins [on|off]
function P.Set(db, want)
  if want == nil then want = db.pins == false end
  db.pins = want and true or false
  if want then P.Start(db) else P.Stop() end
  return db.pins
end
