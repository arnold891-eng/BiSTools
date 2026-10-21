-- BiSTools / Tools / Rides.lua
-- THE RIDES TOOL: a little card with the zeppelins and boats from where you stand (21 Oct 2026).
--
-- Arn: "if you have BiS Tools installed, do you get a little card when you're in Orgrimmar in the top left side of
-- the screen, something that just says Zeppelin arriving, leaving in X amount of time" - and then "the timer lives
-- in the libraries, so somebody that has BiS Healing and leaves can start the timer and someone that is not on the
-- Zeppelin will get [it] ... somebody with BiS Tools ... their card will say ... Zeppelin just arrived, leaving for
-- Undercity" - "everybody with the library does not show the clock by default. BiS Tools enables the card and
-- more options live in BiS Tools" - "the library still draws nothing".
--
-- So the CLOCK is LibBiSComm's (minor 15, RIDE): every BiS addon learns a ride by watching you ride it and shares it
-- with your guild and group. This tool only SHOWS it: on a map with a zeppelin or a boat - or in its capital,
-- Orgrimmar for Durotar's tower - a card at the top left, one line per ride from here ("Zeppelin to Undercity -
-- arrives in 3:10", gold while it waits: "here now, leaves in 0:45"), and who timed it. Anywhere else, and in an
-- instance, nothing. It repaints once a second while it shows; nothing ticks while it is hidden. It also hands
-- the lib its saved table (db.clock), so the clock outlives a logout.
local _, NS = ...
local T, R = NS.T, NS.Registry

local RD = { W = 300, LINE = 16, TOP = 22, EVERY = 1 }
NS.Rides = RD

function RD.Lib()
  local lib = _G.LibBiSComm
  if lib and lib.RidesAt then return lib end
  return nil
end

local function plainNum(v)
  if v == nil or type(v) ~= "number" then return nil end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, v)
    if not ok or yes then return nil end
  end
  return v
end

--- Where you stand: the map the client says (a capital is its own map; the lib counts it as its zone's).
function RD.Map()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
  return ok and plainNum(map) or nil
end

function RD.Inside()
  if not IsInInstance then return false end
  local ok, inside = pcall(IsInInstance)
  if not ok then return true end
  if issecretvalue then
    local ok2, yes = pcall(issecretvalue, inside)
    if not ok2 or yes then return true end
  end
  return inside and true or false
end

--------------------------------------------------------------------
-- the card
--------------------------------------------------------------------

function RD.Build()
  if RD.frame then return RD.frame end
  local F = NS.Farm
  local f = CreateFrame("Frame", "BiSToolsRides", UIParent)
  RD.frame = f
  f:SetSize(RD.W, 40)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if RD.db then RD.db.pos = { p, rp, x, y } end
  end)
  F.tex(f, "BACKGROUND", "frame", 0.88)
  F.border(f, "edge", 1)
  f.title = F.fs(f, "BiS> rides from here", 10, "accent")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -6)
  f.lines = {}
  f.foot = F.fs(f, "", 9, "dim")
  f:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText("BiS> rides")
    GameTooltip:AddLine("Every zeppelin and boat runs a fixed loop. Anyone with a BiS addon who rides one times it, "
      .. "and your guild and group get the clock - so one rider sets it for everyone.", 0.8, 0.8, 0.8, true)
    GameTooltip:AddLine("Drag to move it. /bist rides off hides it.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:Hide()
  RD.Place()
  return f
end

function RD.Place()
  local f, pos = RD.frame, RD.db and RD.db.pos
  if not f then return end
  f:ClearAllPoints()
  if type(pos) == "table" and type(pos[1]) == "string" then
    f:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
  else
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -140)
  end
end

function RD.Hide()
  local f = RD.frame
  if not f then return end
  f:SetScript("OnUpdate", nil)
  f:Hide()
end

--- The card now: shown where a ride is (its map or its capital), hidden anywhere else. Answers its lines.
function RD.Paint(now)
  local lib, db = RD.Lib(), RD.db
  if not (lib and db and R:Enabled("rides") and db.card ~= false) then return RD.Hide() end
  if RD.Inside() then return RD.Hide() end
  local map = RD.Map()
  local here = map and lib:RidesAt(map, now) or {}
  if #here == 0 then return RD.Hide() end
  local F = NS.Farm
  local f = RD.Build()
  local shown, newest = {}, nil
  for i, e in ipairs(here) do
    local fs = f.lines[i]
    if not fs then
      fs = F.fs(f, "", 11, "ink")
      fs:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -RD.TOP - (i - 1) * RD.LINE)
      fs:SetWidth(RD.W - 16)
      fs:SetJustifyH("LEFT")
      f.lines[i] = fs
    end
    local text = lib:RideLine(e.stop, e.sched)
    fs:SetText(text)
    local r, g, b = F.color((e.sched and e.sched.docked) and "gold" or (e.sched and "ink" or "dim"))
    fs:SetTextColor(r, g, b, 1)
    fs:Show()
    shown[#shown + 1] = text
    if e.sched and (not newest or e.sched.age < newest.age) then newest = e.sched end
  end
  for i = #here + 1, #f.lines do f.lines[i]:Hide() end
  local h = RD.TOP + #here * RD.LINE
  f.foot:ClearAllPoints()
  f.foot:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -h - 1)
  local foot = ""
  if newest and db.who ~= false then
    foot = ("timed by %s%s, %s ago"):format(tostring(newest.by or "?"),
      newest.via and (" - " .. newest.via) or "", lib.RideClock(math.max(0, newest.age)))
  elseif not newest then
    foot = "ride one once - your guild gets the clock"
  end
  f.foot:SetText(foot)
  if foot ~= "" then f.foot:Show() else f.foot:Hide() end
  f:SetHeight(h + (foot ~= "" and 16 or 6))
  if not f:IsShown() then f:Show() end
  -- once a second while it shows (the countdown); nothing ticks while it is hidden
  if not f:GetScript("OnUpdate") then
    RD.wait = RD.EVERY
    f:SetScript("OnUpdate", function(_, elapsed)
      RD.wait = RD.wait - (tonumber(elapsed) or 0)
      if RD.wait > 0 then return end
      RD.wait = RD.EVERY
      RD.Paint()
    end)
  end
  return shown
end

--------------------------------------------------------------------
-- events, the tool
--------------------------------------------------------------------

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
  ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function() if RD.db then RD.Paint() end end)
RD.events = ev

--- The lib's saved place: BiS Tools' table, so the clock survives a logout (the lib has no SavedVariables).
function RD.Keep(db)
  local lib = RD.Lib()
  if not lib then return nil end
  if type(db.clock) ~= "table" then db.clock = {} end
  pcall(lib.RideStore, lib, db.clock)
  if not RD.hooked and lib.RegisterCallback then
    RD.hooked = true
    lib:RegisterCallback("RIDE", function() if RD.db then RD.Paint() end end)   -- a sighting heard: repaint
  end
  return db.clock
end

R:Register({
  name = "rides",
  desc = "a card with the zeppelins and boats from where you stand, timed by your guild",
  usage = "/bist rides [on | off | who | reset]",
  defaults = { card = true, who = true },
  options = {
    { kind = "toggle", label = "the card", help = "On a map with a zeppelin or a boat - or in its capital - a little card at the top left: each ride from here, arriving or leaving, timed by your guild.",
      get = function(db) return db.card ~= false end,
      set = function(db, on) db.card = on and true or false RD.Paint() end },
    { kind = "toggle", label = "who timed it", help = "The card's last line: who timed the ride, with which BiS addon, and how long ago.",
      get = function(db) return db.who ~= false end,
      set = function(db, on) db.who = on and true or false RD.Paint() end },
    { kind = "button", label = "the card's place", button = "reset", help = "Back to the top left.",
      action = function(db) db.pos = nil RD.Place() end },
  },
  OnInit = function(_, db)
    RD.db = db
    RD.Keep(db)
  end,
  OnLogin = function(_, db)
    RD.db = db
    RD.Keep(db)
    RD.Paint()
  end,
  OnEnable = function(_, db) RD.db = db RD.Paint() end,
  -- the Hub's "reset window positions" (recenter) puts the card back at the top left too
  OnOpen = function(_, db, recenter)
    RD.db = db
    if recenter then db.pos = nil RD.Place() end
    RD.Paint()
  end,
  OnDisable = function() RD.Hide() end,
  OnSlash = function(_, db, args)
    RD.db = db
    if args == "on" or args == "off" then
      db.card = args == "on"
      RD.Paint()
      return NS.Print("the ride card: %s", db.card and "on" or "off")
    elseif args == "who" then
      db.who = db.who == false
      RD.Paint()
      return NS.Print("who timed it: %s", db.who and "shown" or "hidden")
    elseif args == "reset" then
      db.pos = nil
      RD.Place()
      return NS.Print("the ride card is back at the top left")
    end
    local lib = RD.Lib()
    if not lib then return NS.Print("the shared BiS lib is too old for the ride clock") end
    local map = RD.Map()
    local here = map and lib:RidesAt(map) or {}
    if #here == 0 then return NS.Print("no zeppelin or boat from here - the card shows where one is") end
    for _, e in ipairs(here) do NS.Print("%s", lib:RideLine(e.stop, e.sched)) end
  end,
})
