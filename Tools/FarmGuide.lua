-- BiSTools / Tools / FarmGuide.lua
-- RESTEDXP'S ACTIVE TARGETS, IN THE FARM WINDOW (6 Oct 2026).
--
-- Arn, with RestedXP's "Active Targets" showing Hillsbrad Farmers: "on the main bis farm window right
-- now we track our kills is there a way to have a rested exp section so anytime its active targets
-- update it adds it to our list". So the guide's mobs sit under your kills, tagged RXP, and a click
-- farms one exactly like any other row.
--
-- HOW IT HEARS THEM, without touching RestedXP: RXP registers itself with AceAddon-3.0 under its
-- folder name, so LibStub("AceAddon-3.0"):GetAddon("RXPGuides") is its addon table, and every change
-- to its Active Targets passes through addon.targeting:UpdateEnemyList(unitscan, mobs, addEntries)
-- (RXPGuides/Targeting.lua, v4.11.18). A hooksecurefunc on that method runs AFTER theirs, with the
-- lists they were handed: replace them, or - addEntries true - add to them. Read-only; nothing of
-- theirs is called or changed. No RestedXP, or a version where that method has moved: nothing
-- happens and nothing is said.
local _, NS = ...
local F = NS.Farm

local G = { mobs = {} }
F.Guide = G
G.MAX = 4                 -- the farm window is a small window; a guide step rarely names more

local function add(list, seen, name)
  if type(name) == "string" and name ~= "" and not seen[name] then
    seen[name] = true
    list[#list + 1] = name
  end
end

--- RXP's lists in, ours out: rares (unitscan) and mobs, one list, guide order, no repeats.
function G.Take(unitscan, mobs, addEntries)
  local out, seen = {}, {}
  if addEntries then
    for _, n in ipairs(G.mobs) do add(out, seen, n) end
  end
  for _, n in ipairs(type(mobs) == "table" and mobs or {}) do add(out, seen, n) end
  for _, n in ipairs(type(unitscan) == "table" and unitscan or {}) do add(out, seen, n) end
  G.mobs = out
  if F.db and F.Refresh then F.Refresh(F.db) end
end

--- The guide's mobs that are not already a row: what the farm window adds under your kills.
function G.Entries(db, already)
  local out = {}
  if db.guide == false then return out end
  for _, n in ipairs(G.mobs) do
    if not already[n] then
      out[#out + 1] = { name = n, count = 0, guide = true }
      if #out >= G.MAX then break end
    end
  end
  return out
end

function G.Hook()
  if G.hooked then return true end
  local AA = LibStub and LibStub("AceAddon-3.0", true)
  local ok, rxp = pcall(function() return AA and AA:GetAddon("RXPGuides", true) end)
  local t = ok and rxp and rxp.targeting
  if type(t) ~= "table" or type(t.UpdateEnemyList) ~= "function" or not hooksecurefunc then return false end
  hooksecurefunc(t, "UpdateEnemyList", function(_, unitscan, mobs, addEntries) G.Take(unitscan, mobs, addEntries) end)
  G.hooked = true
  return true
end

--- /bist farm guide [on|off]
function G.Set(db, want)
  if want == nil then want = db.guide == false end
  db.guide = want and true or false
  if F.Refresh then F.Refresh(db) end
  return db.guide
end

-- RestedXP loads after us (R after B), so try now, at login, and when it says it has loaded
G.Hook()
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name ~= "RXPGuides" then return end
  if G.Hook() then self:UnregisterAllEvents() end
end)
