--[[
  BiSTools :: Tools/Battleground.lua - the "bg" tool: the enemy's healers and their top killer, marked.

  Arn's cousin, 13 Oct 2026: "can it auto crosshair people that cast heals". Not from their casts:
  Forever hides every other player's cast from addons in combat (measured on the beta; the cast bar
  draws, nothing can read it). But the BATTLEGROUND SCOREBOARD lists each player's healing done and
  killing blows, and its calls are on the Forever census. So, in a battleground:

    HEALERS  the enemy's top three by healing done (Arn: "on their top three heals") wear a WHITE
             NEON SABER - a white-hot core in soft glow layers, standing at the left of the plate,
             with a dark hilt (Arn: "a white neon white saber looking thing")
    KILLER   the enemy with the most killing blows wears a RED GLOW round the plate (Arn: "red cross
             hairs glowing like the threat meter on their top killing blow person") - the threat
             tool's glow, sides and bottom, open at the top so the name stays clear

  The scoreboard is asked every T.EVERY seconds while you are in a battleground (RequestBattlefield-
  ScoreData; the answer arrives as UPDATE_BATTLEFIELD_SCORE) and never outside one. Read through
  C_PvP.GetScoreInfo - named fields, so no guessing at a return order that differs between clients.
  Every field asked "hidden?" first. A player is matched to a nameplate by GUID, else by name.
  UNVERIFIED on Forever: that the scoreboard's numbers come back unhidden mid-match - /bist bg why
  prints what it read.

  Our own frames, pinned beside the plate: nothing of the game's nameplate is touched, a plate the
  client locks away gets nothing.
]]
local _, NS = ...
local R = NS.Registry
local RC = NS.Recap
local F = NS.Farm

local B = {}
NS.BG = B

B.EVERY = 10                       -- seconds between scoreboard reads, in a battleground only
B.TOP_HEALERS = 3
B.WHITE = { 0.92, 0.97, 1.00 }     -- a neon white, a breath of blue
B.RED = { 1.00, 0.12, 0.12 }
B.SABER_W, B.SABER_H = 2, 70       -- the core's width; its height, the rival crosshair's (RC.MARK_H)
B.plates = {}                      -- nameplate units in sight
B.marks, B.pool = {}, {}           -- unit -> frame, and spare frames per kind
B.healers, B.killer = {}, nil      -- guid/name -> rank (1-3), and the top killer's key
B.read = {}                        -- what the last scoreboard read saw, for why

local plain = F.Plain

local function yes(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return plain(v)
end

local function field(t, k)
  local ok, v = pcall(function() return t[k] end)
  if not ok then return nil end
  return plain(v)
end

--- A scoreboard name without its realm ("Grape-Realm" -> "Grape").
local function bare(n)
  if type(n) ~= "string" then return nil end
  return (n:match("^([^%-]+)") or n)
end

------------------------------------------------------------------- reading --

--- Every player on the scoreboard: name, guid, enemy?, healing done, killing blows. Hidden fields
--- are left out (nil), never guessed.
function B.Scores()
  local out = {}
  -- the fence's pair form: C_PvP's named table first; the old global (TBC) answers with a list in an
  -- order that differs by client, so its rows are not tables and are skipped below - never guessed at
  local G = (C_PvP and C_PvP.GetScoreInfo) or GetBattlefieldScore
  local n = yes(GetNumBattlefieldScores) or 0
  if not G or type(n) ~= "number" then return out, "no scoreboard on this client" end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local hidden = 0
  -- cost: once per scoreboard update (every B.EVERY s, in a battleground only), one row per player
  for i = 1, n do
    local ok, info = pcall(G, i)
    if ok and type(info) == "table" then
      local name, guid = field(info, "name"), field(info, "guid")
      local faction, heal, kb = field(info, "faction"), field(info, "healingDone"), field(info, "killingBlows")
      if heal == nil or kb == nil then hidden = hidden + 1 end
      out[#out + 1] = {
        name = bare(name), guid = type(guid) == "string" and guid or nil,
        enemy = (type(faction) == "number" and myFaction ~= nil) and faction ~= myFaction or nil,
        heal = type(heal) == "number" and heal or nil, kb = type(kb) == "number" and kb or nil,
      }
    end
  end
  return out, hidden > 0 and (hidden .. " row(s) with the numbers hidden") or nil
end

--- The enemy's top three healers and their top killer, from a scoreboard read.
function B.Pick(scores)
  local enemies = {}
  for _, s in ipairs(scores) do if s.enemy then enemies[#enemies + 1] = s end end
  local heals = {}
  for _, s in ipairs(enemies) do if (s.heal or 0) > 0 then heals[#heals + 1] = s end end
  table.sort(heals, function(a, b) return a.heal > b.heal end)
  local healers = {}
  for i = 1, math.min(B.TOP_HEALERS, #heals) do
    local s = heals[i]
    if s.guid then healers[s.guid] = i end
    if s.name then healers[s.name] = i end
  end
  local killer, best = nil, 0
  for _, s in ipairs(enemies) do
    if (s.kb or 0) > best then best, killer = s.kb, s end
  end
  B.read = { enemies = #enemies, heals = heals, killer = killer }
  return healers, killer
end

--- FOREVER HIDES THE NUMBERS (Arn's /bist bg raw, 14 Oct: only name, faction, class and race are
--- plain mid-match). Arn's idea, same night - "what about we can click the top heals": the game can
--- still SORT the board by a hidden column, and the names come back in that order. Proven in his
--- match: sorted by kills, the names matched the board's killing blows. So: sort, read names.
B.HEAL_CLASSES = { PRIEST = true, DRUID = true, SHAMAN = true, PALADIN = true }
B.WARMUP = 90       -- s into a match before anyone is marked: until then everyone ties at 0, in no order
B.ORDER_GAP = 5     -- s: a sort can itself fire UPDATE_BATTLEFIELD_SCORE - never read again inside this

local function sortRead(col, myFaction)
  if not pcall(SortBattlefieldScoreData, col) then return nil end
  local n = yes(GetNumBattlefieldScores) or 0
  local out = {}
  for i = 1, type(n) == "number" and n or 0 do
    local ok, info = pcall(C_PvP.GetScoreInfo, i)
    if ok and type(info) == "table" then
      local faction = field(info, "faction")
      if type(faction) == "number" and myFaction ~= nil and faction ~= myFaction then
        out[#out + 1] = { name = bare(field(info, "name")), class = field(info, "classToken") }
      end
    end
  end
  return out
end

--- The scoreboard window, if Blizzard's is open: we never re-sort what Arn is looking at.
--- Second answer: the window that exists (shown or not), for the button to sit on.
B.BOARDS = { "PVPMatchScoreboard", "WorldStateScoreFrame" }
function B.Board()
  local found
  for _, n in ipairs(B.BOARDS) do
    local f = _G[n]
    if f and f.IsShown then
      found = found or f
      local ok, shown = pcall(f.IsShown, f)
      if ok and plain(shown) == true then return f, f end
    end
  end
  return nil, found
end

--- "BiS> mark" on the scoreboard (Arn: "add a button in scoreboard"): read the board's order now,
--- even with the window open, mark, and say who. Our own button on UIParent, shown with the window
--- (hooked), placed on its bottom-right; the window's own frames are never touched.
function B.Button()
  local _, board = B.Board()
  if not board or B.button then return B.button end
  local K = NS.Farm
  local b = CreateFrame("Button", "BiSToolsBGMark", UIParent)
  b:SetSize(84, 20)
  -- 14 Oct, Arn's screenshot: "shown" on the window's own layer, yet not to be seen - under the
  -- window's inner panels. The top layer, and just UNDER the window's bottom edge, where nothing of
  -- Blizzard's sits; if its place cannot be taken (hidden rects in an instance), top of the screen.
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  if b.SetToplevel then pcall(b.SetToplevel, b, true) end
  if not pcall(b.SetPoint, b, "TOP", board, "BOTTOM", 0, -2) then
    b:SetPoint("TOP", UIParent, "TOP", 0, -120)
  end
  K.tex(b, "BACKGROUND", "frame", 0.85)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(NS.T.text("accent", "BiS>") .. " mark")
  b:SetScript("OnClick", function() B.Mark() end)
  local function show(on) if on then b:Show() else b:Hide() end end
  show(board:IsShown() and B.On())
  board:HookScript("OnShow", function() show(B.On()) end)
  board:HookScript("OnHide", function() b:Hide() end)
  B.button = b
  return b
end

--- /bist bg board: why no button - which scoreboard windows exist, and what is under the mouse.
--- Hover the scoreboard, type it: the window's real name on Forever, if B.BOARDS has it wrong.
function B.BoardWhy()
  for _, n in ipairs(B.BOARDS) do
    local f = _G[n]
    local okS, shown = pcall(function() return f and f:IsShown() end)
    local okT, strata = pcall(function() return f and f:GetFrameStrata() end)
    NS.Print("bg board: %s %s%s", n, f and "exists" or "missing",
      f and ((okS and plain(shown) and ", shown" or ", hidden") .. ", " .. tostring(okT and plain(strata) or "?")) or "")
  end
  local b = B.button
  local where = "?"
  if b then
    local okR, l, bt, w, h = pcall(b.GetRect, b)
    if okR then where = ("%s,%s %sx%s"):format(tostring(plain(l)), tostring(plain(bt)), tostring(plain(w)), tostring(plain(h))) end
  end
  NS.Print("bg board: button %s", b and ((b:IsShown() and "shown" or "hidden") .. ", " .. tostring(b:GetFrameStrata())
    .. ", at " .. where .. (b.IsVisible and (b:IsVisible() and ", visible" or ", NOT visible") or "")) or "not made yet")
  local foci = {}
  local okM, list = pcall(function() return GetMouseFoci and GetMouseFoci() end)
  for _, f in ipairs(okM and type(list) == "table" and list or {}) do
    local chain, cur = {}, f
    for _ = 1, 8 do
      if not cur then break end
      local okN, nm = pcall(cur.GetName, cur)
      chain[#chain + 1] = tostring(okN and plain(nm) or "?")
      local okP, par = pcall(cur.GetParent, cur)
      cur = okP and par or nil
    end
    foci[#foci + 1] = table.concat(chain, " < ")
  end
  NS.Print("bg board: under the mouse: %s", #foci > 0 and table.concat(foci, " | ") or "nothing named")
end

--- In a battleground, asked live (the box may lay out before B.Watch has heard the same event).
function B.InBG()
  local ok, inside, kind = pcall(IsInInstance)
  return ok and plain(inside) == true and plain(kind) == "pvp"
end

--- The same "mark" in the BiS> tools box (Arn, 14 Oct: "add that scoreboard button to the bis
--- tools") - read the board mid-fight without opening it. Its face: a little lit saber.
function B.BoxButton()
  if B.bbtn then return B.bbtn end
  local K = NS.Farm
  local b = CreateFrame("Button", "BiSToolsBGMarkBox", UIParent)
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("LeftButtonUp")
  K.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = K.border(b, "accent", 1)
  local function tex(f, layer, c, a, add)
    local t = f:CreateTexture(nil, layer)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    if add and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
    return t
  end
  for _, layer in ipairs({ { 7, 0.18 }, { 4, 0.45 }, { 2, 1 } }) do
    local t = tex(b, "ARTWORK", B.WHITE, layer[2], true)
    t:SetPoint("TOP", b, "TOP", 0, -4)
    t:SetPoint("BOTTOM", b, "BOTTOM", 0, 9)
    t:SetWidth(layer[1])
  end
  local hilt = tex(b, "OVERLAY", { 0.55, 0.57, 0.6 }, 1)
  hilt:SetPoint("BOTTOM", b, "BOTTOM", 0, 4)
  hilt:SetSize(4, 5)
  b:SetScript("OnClick", function() B.Mark() end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Mark their healers and killer")
    GameTooltip:AddLine("Reads the scoreboard now: a white saber on their top three healers, a red crosshair on their top killer. Same as /bist bg mark.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  B.bbtn = b
  return b
end

function B.Mark()
  if not B.On() then return NS.Print("bg: not in a battleground") end
  if not B.ReadOrder(true) then return NS.Print("bg: %s", (B.read and B.read.note) or "the board could not be read") end
  B.PaintAll()
  local names = {}
  for _, s in ipairs(B.read.heals or {}) do names[#names + 1] = s.name end
  NS.Print("bg: healers %s; killer %s", #names > 0 and table.concat(names, ", ") or "none",
    B.killer and B.killer.name or "none")
end

--- Top healers and killer by the board's order. `force` = the button: sort even with the window open.
function B.ReadOrder(force)
  if not (SortBattlefieldScoreData and C_PvP and C_PvP.GetScoreInfo) then return false end
  -- never sort what Arn may be looking at: the window open, OR not found at all - then we cannot
  -- know it is closed (14 Oct: the name was wrong, it sorted every 10 s under his eyes - "annoying")
  local open, exists = B.Board()
  if not force and (open or not exists) then
    if not exists then B.read = B.read or { enemies = 0, heals = {} } B.read.wait = "the scoreboard window was not found - /bist bg mark reads it, /bist bg board says why" B.read.note = B.read.wait end
    return false
  end
  local now = GetTime and GetTime() or 0
  if not force and B.lastOrder and now - B.lastOrder < B.ORDER_GAP then return false end
  local run = yes(GetBattlefieldInstanceRunTime)
  if type(run) == "number" and run < B.WARMUP * 1000 then
    B.read = { enemies = 0, heals = {}, wait = "the match has only just started - marked from " .. B.WARMUP .. " s" }
    B.read.note = B.read.wait
    return false
  end
  B.lastOrder = now
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  -- a different column first: sorting the same column twice flips it, and Arn may have clicked one
  pcall(SortBattlefieldScoreData, "name")
  local byHeal = sortRead("healing", myFaction) or {}
  local byKill = sortRead("kills", myFaction) or {}
  local heals, healers = {}, {}
  for _, s in ipairs(byHeal) do
    if s.name and B.HEAL_CLASSES[s.class or ""] and #heals < B.TOP_HEALERS then
      heals[#heals + 1] = s
      healers[s.name] = #heals
    end
  end
  local killer = byKill[1] and byKill[1].name and byKill[1] or nil
  B.healers, B.killer = healers, killer
  B.read = { enemies = #byHeal, heals = heals, killer = killer, note = "numbers hidden - read by the board's order", byOrder = true }
  B.Remember(heals, killer)
  return true
end

------------------------------------------------------------------- drawing --

local function plateOf(u)
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return nil end
  local ok, plate = pcall(get, u)
  if not ok or not plate then return nil end
  local okF, forbidden = pcall(function() return plate.IsForbidden and plate:IsForbidden() end)
  if not okF or forbidden then return nil end
  return plate
end

local function tex(f, layer, c, a, add)
  local t = f:CreateTexture(nil, layer)
  t:SetColorTexture(c[1], c[2], c[3], a or 1)
  if add and t.SetBlendMode then pcall(t.SetBlendMode, t, "ADD") end
  return t
end

local function pulse(f, low, dur)
  if not f.CreateAnimationGroup then return end
  local ok, g = pcall(f.CreateAnimationGroup, f)
  if not (ok and g) then return end
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(1) a:SetToAlpha(low) a:SetDuration(dur)
  if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
  g:SetLooping("BOUNCE")
  f.pulse = g
end

--- THE SABER: a white-hot core in two soft glow layers, a dark hilt below it.
function B.NewSaber()
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f.kind = "healer"
  f.parts = {}
  local W = B.SABER_W
  for _, layer in ipairs({ { W + 10, 0.12 }, { W + 4, 0.35 }, { W, 1 } }) do
    local t = tex(f, "ARTWORK", B.WHITE, layer[2], true)
    t:SetPoint("TOP", f, "TOP", 0, 0)
    t:SetPoint("BOTTOM", f, "BOTTOM", 0, 7)
    t:SetWidth(layer[1])
    f.parts[#f.parts + 1] = t
  end
  local hilt = tex(f, "OVERLAY", { 0.18, 0.18, 0.2 }, 1)
  hilt:SetPoint("BOTTOM", f, "BOTTOM", 0, 0)
  hilt:SetSize(W + 4, 7)
  local band = tex(f, "OVERLAY", { 0.7, 0.72, 0.75 }, 1)
  band:SetPoint("BOTTOM", hilt, "TOP", 0, 0)
  band:SetSize(W + 6, 1)
  f.hilt = hilt
  pulse(f, 0.75, 1.2)                             -- the slow hum of a lit blade
  return f
end

--- THE KILLER: a red crosshair ON THEM (Arn, 14 Oct: "the red killer one sucks has to be on them";
--- his first ask, 13 Oct: "red cross hairs glowing"). The rival tool's crosshair, in the style
--- picked there, its own deeper red, humming faster than a rival's.
function B.NewKiller()
  local RC = NS.Recap
  RC.MARK_COLOUR.bgkiller = B.RED
  local f = RC.NewMark("bgkiller")
  f.kind = "killer"
  if not f.pulse then pulse(f, 0.35, 0.45) end
  return f
end

function B.Undraw(u)
  local f = B.marks[u]
  if not f then return end
  if f.pulse then f.pulse:Stop() end
  f:Hide()
  f:ClearAllPoints()
  B.marks[u] = nil
  B.pool[f.kind] = B.pool[f.kind] or {}
  table.insert(B.pool[f.kind], f)
end

function B.Draw(u, kind)
  local f = B.marks[u]
  if f and f.kind == kind then return f end
  if f then B.Undraw(u) end
  local plate = plateOf(u)
  if not plate then return nil end
  B.pool[kind] = B.pool[kind] or {}
  f = table.remove(B.pool[kind]) or (kind == "healer" and B.NewSaber() or B.NewKiller())
  f:ClearAllPoints()
  if kind == "healer" then
    -- ON THEM, like the rival crosshair (Arn, 14 Oct: at the plate's left it sat on his nameplate
    -- addon's buff timers - "on them... like crosshairs"): upright under the plate, centred on the body
    f:SetPoint("TOP", plate, "BOTTOM", 0, -2)
    f:SetSize(B.SABER_W + 10, B.SABER_H)
  else
    -- where the rival crosshair stands: under the plate, centred, half its width (RC.MarkPlate)
    local RC = NS.Recap
    local okW, pw = pcall(plate.GetWidth, plate)
    pw = okW and plain(pw)
    if type(pw) ~= "number" or pw <= 0 then pw = RC.MARK_W / RC.MARK_WIDE end
    f:SetSize(math.floor(pw * RC.MARK_WIDE + 0.5), RC.MARK_H)
    f:SetPoint("TOP", plate, "BOTTOM", 0, -2)
  end
  f:SetAlpha(1)
  f:Show()
  if f.pulse then f.pulse:Play() end
  B.marks[u] = f
  return f
end

------------------------------------------------------------------- memory --
-- REMEMBERED ACROSS BATTLEGROUNDS (Arn, 13 Oct: "a data file that only keeps track of bgs so if we
-- go into a new bg it knows these people are healers and this guy is dangerous"). An addon cannot
-- write a file; its saved variables are the one it gets. So db.known[name] = { guid, healer = how
-- many battlegrounds they were a top-three healer in, killer = how many they were the top killer
-- in, last = when }. Counted once per battleground per player. In the next battleground a known
-- player is marked the moment their plate appears - before the scoreboard has numbers - dimmer and
-- steady, so "known from before" reads apart from "doing it right now". Not seen for B.FORGET_DAYS:
-- dropped; never more than B.KEEP players.
B.FORGET_DAYS = 30
B.KEEP = 300
B.counted = {}                     -- "name:h" / "name:k" already counted this battleground
B.onBoard = {}                     -- guid/name of every enemy this battleground's scoreboard has read

function B.Known()
  local db = R:DBFor(R:Get("bg"))
  db.known = type(db.known) == "table" and db.known or {}
  return db.known
end

function B.Remember(heals, killer)
  local known = B.Known()
  local now = time and time() or 0
  local function note(s, what)
    if not (s and s.name) then return end
    local rec = known[s.name] or { healer = 0, killer = 0 }
    rec.guid = s.guid or rec.guid
    rec.last = now
    if not B.counted[s.name .. ":" .. what] then
      B.counted[s.name .. ":" .. what] = true
      rec[what == "h" and "healer" or "killer"] = (rec[what == "h" and "healer" or "killer"] or 0) + 1
    end
    known[s.name] = rec
  end
  for i = 1, math.min(B.TOP_HEALERS, #heals) do note(heals[i], "h") end
  note(killer, "k")
end

--- Old entries out, and never more than B.KEEP (the longest unseen go first).
function B.Prune()
  local known = B.Known()
  local now = time and time() or 0
  local list = {}
  for name, rec in pairs(known) do
    if now - (rec.last or 0) > B.FORGET_DAYS * 86400 then known[name] = nil
    else list[#list + 1] = { name = name, last = rec.last or 0 } end
  end
  if #list > B.KEEP then
    table.sort(list, function(a, b) return a.last < b.last end)
    for i = 1, #list - B.KEEP do known[list[i].name] = nil end
  end
end

--- A remembered player on this plate: their record, or nil.
function B.Recall(guid, name)
  local known = B.Known()
  local rec = B.Look(known, name)
  if rec then return rec end
  if guid then
    for _, rec in pairs(known) do if rec.guid == guid then return rec end end
  end
  return nil
end

--- Who is on this plate: "killer", "healer" or nil - and whether that is remembered, not live.
--- Live (this battleground's scoreboard) first; then what earlier battlegrounds taught.
--- A plate's name, as the scoreboard writes it. Forever names have two parts ("Swig Xd"): the board
--- has both, a plate's UnitName may give only "Swig" (14 Oct: the right healers read, NO saber).
--- GetUnitName(u, false) carries the surname (as the rival tool learned); else the first part.
function B.PlateName(u)
  local full = yes(GetUnitName, u, false)
  if type(full) == "string" and full ~= "" then return bare(full) end
  return F.Name(u)
end

--- Look a name up in a table keyed by board names: exact, else a one-word name against the first
--- word of each key (cost: only for a one-word name, and these tables are a match's players).
function B.Look(tbl, name)
  if not name then return nil end
  if tbl[name] then return tbl[name] end
  if name:find(" ", 1, true) then return nil end
  for key, v in pairs(tbl) do
    if type(key) == "string" and key:match("^(%S+)") == name then return v end
  end
  return nil
end

local function sameName(a, b)
  if not (a and b) then return false end
  if a == b then return true end
  return a:match("^(%S+)") == b or b:match("^(%S+)") == a
end

function B.Which(u)
  local guid = yes(UnitGUID, u)
  local name = B.PlateName(u)
  local k = B.killer
  if k and ((guid and k.guid == guid) or sameName(k.name, name)) then return "killer" end
  if (guid and B.healers[guid]) or B.Look(B.healers, name) then return "healer" end
  if not (guid or name) then return nil end
  -- the memory is for players this battleground's scoreboard has not judged yet: once the live
  -- scoreboard has them, IT decides (a healer who fell out of the top three loses the saber)
  if (guid and B.onBoard[guid]) or B.Look(B.onBoard, name) then return nil end
  -- an enemy only: a remembered name on our own side is somebody we play with now
  if yes(UnitCanAttack, "player", u) ~= true then return nil end
  local rec = B.Recall(guid, name)
  if rec then
    if (rec.killer or 0) > 0 then return "killer", true end
    if (rec.healer or 0) > 0 then return "healer", true end
  end
  return nil
end

function B.On() return R:Enabled("bg") and B.inBG end

B.REMEMBERED_ALPHA = 0.55

function B.Paint(u)
  if not B.plates[u] then return end
  local kind, remembered
  if B.On() then kind, remembered = B.Which(u) end
  if not kind then return B.Undraw(u) end
  local f = B.Draw(u, kind)
  if not f then return end
  -- remembered: dimmer and steady; live: full and humming
  if remembered then
    if f.pulse then f.pulse:Stop() end
    f:SetAlpha(B.REMEMBERED_ALPHA)
  else
    f:SetAlpha(1)
    if f.pulse and not f.pulse:IsPlaying() then f.pulse:Play() end
  end
  f.remembered = remembered and true or false
end

function B.PaintAll() for u in pairs(B.plates) do B.Paint(u) end end

function B.ClearAll()
  for u in pairs(B.marks) do B.Undraw(u) end
  B.healers, B.killer = {}, nil
end

------------------------------------------------------------------ the loop --

--- In a battleground: ask for the scoreboard now and every B.EVERY seconds. Out of one: stop.
--- The match, kept across a /reload (Arn, 14 Oct: "fix the reload double count" - a reload is a
--- fresh load, and every healer was counted twice). A match = its zone + when it started (now -
--- the run time), within a minute. The same match: its "already counted" list comes back.
function B.SameMatch()
  local db = R:DBFor(R:Get("bg"))
  local run = yes(GetBattlefieldInstanceRunTime)
  local start = (type(run) == "number" and run > 0) and ((time and time() or 0) - math.floor(run / 1000)) or nil
  local zone = yes(GetRealZoneText)
  local m = db.match
  if start and type(m) == "table" and m.zone == zone and type(m.start) == "number"
     and math.abs(m.start - start) < 60 and type(m.counted) == "table" then
    return m.counted
  end
  local counted = {}
  db.match = start and { zone = zone, start = start, counted = counted } or nil
  return counted
end

function B.Watch()
  local ok, inside, kind = pcall(IsInInstance)
  local was = B.inBG
  -- a battleground only: an arena is 2v2/3v3, nobody needs a scoreboard to find the healer there
  B.inBG = ok and plain(inside) == true and plain(kind) == "pvp"
  if B.inBG and not was then
    B.counted = B.SameMatch()         -- a new battleground: everyone may be counted once again
    B.healers, B.killer = {}, nil     -- and nothing live yet: what is drawn now is remembered
    B.onBoard = {}
    B.ended = nil
    B.Prune()
  end
  if B.On() then
    if not B.ticker then
      B.ticker = C_Timer.NewTicker(B.EVERY, function() B.Ask() end)
    end
    B.Ask()
  else
    if B.ticker then B.ticker:Cancel() B.ticker = nil end
    B.ClearAll()
  end
end

function B.Ask()
  if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
end

function B.OnScores()
  if not B.On() then return end
  local scores, note = B.Scores()
  for _, sc in ipairs(scores) do
    if sc.enemy then
      if sc.guid then B.onBoard[sc.guid] = true end
      if sc.name then B.onBoard[sc.name] = true end
    end
  end
  if note then
    -- hidden numbers (Forever, mid-match): by the board's order instead; between reads the last stays
    if not B.ReadOrder() and not (B.read and B.read.byOrder) then
      B.healers, B.killer = {}, nil
      local enemies = 0
      for _, sc in ipairs(scores) do if sc.enemy then enemies = enemies + 1 end end
      B.read = { enemies = enemies, heals = {}, note = (B.read and B.read.wait) or note }
    end
  else
    B.healers, B.killer = B.Pick(scores)
    B.Remember(B.read.heals or {}, B.killer)
  end
  B.PaintAll()
  B.Button()
  B.AtEnd()
end

--- PROBE (14 Oct): mid-match every number on the board is hidden from addons (Arn's /bist bg raw).
--- Does the board unlock when the match is over? Once per battleground, the moment it has a
--- winner, print the raw row by itself. If the numbers come plain, B.OnScores above has already
--- written the top healers and killer into the memory - nothing else to build for that part.
function B.AtEnd()
  if B.ended or not GetBattlefieldWinner then return end
  local ok, w = pcall(GetBattlefieldWinner)
  if not ok or plain(w) == nil then return end
  B.ended = true
  NS.Print("bg: the match is over - the scoreboard as an addon reads it now:")
  B.Raw()
end

function B.OnEvent(_, event, unit)
  if event == "NAME_PLATE_UNIT_ADDED" then
    if type(unit) == "string" and plain(unit) then B.plates[unit] = true B.Paint(unit) end
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if type(unit) == "string" and plain(unit) then B.Undraw(unit) B.plates[unit] = nil end
  elseif event == "UPDATE_BATTLEFIELD_SCORE" then
    B.OnScores()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    B.Watch()
  end
end

-- registered at load, never from a timer; an event this client does not know is pcalled
B.frame = CreateFrame("Frame")
for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UPDATE_BATTLEFIELD_SCORE",
                     "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do
  pcall(B.frame.RegisterEvent, B.frame, e)
end
B.frame:SetScript("OnEvent", B.OnEvent)

function B.Why()
  local r = B.read or {}
  NS.Print("bg: %s; %s; scoreboard every %d s", R:Enabled("bg") and "on" or "off",
    B.inBG and "in a battleground" or "not in a battleground - nothing is read", B.EVERY)
  B.WhyKnown()
  if not B.inBG then return end
  local heals = {}
  for i, s in ipairs(r.heals or {}) do
    if i > B.TOP_HEALERS then break end
    heals[#heals + 1] = ("%s %s"):format(tostring(s.name or "?"), s.heal and tostring(s.heal) or ("#" .. i))
  end
  DEFAULT_CHAT_FRAME:AddMessage("  enemies on the scoreboard: " .. tostring(r.enemies or 0)
    .. (r.note and ("  (" .. r.note .. ")") or ""))
  DEFAULT_CHAT_FRAME:AddMessage("  top healers (saber): " .. (#heals > 0 and table.concat(heals, ", ") or "none read"))
  DEFAULT_CHAT_FRAME:AddMessage("  top killer (red crosshair): " .. (r.killer and (r.killer.kb
    and ("%s, %d killing blows"):format(tostring(r.killer.name or "?"), r.killer.kb)
    or (tostring(r.killer.name or "?") .. ", most killing blows")) or "none read"))
  local marked, recalled = 0, 0
  for _, f in pairs(B.marks) do marked = marked + 1 if f.remembered then recalled = recalled + 1 end end
  DEFAULT_CHAT_FRAME:AddMessage(("  marked on screen now: %d (%d remembered from earlier battlegrounds)"):format(marked, recalled))
  if yes(UnitExists, "target") == true then
    local kind, rem = B.Which("target")
    DEFAULT_CHAT_FRAME:AddMessage(("  your target reads as \"%s\" (plate %s): %s"):format(tostring(B.PlateName("target") or "?"),
      tostring(yes(UnitName, "target") or "?"), kind and (kind .. (rem and ", remembered" or "")) or "not marked"))
  end
end

--- /bist bg raw: ONE enemy row of the scoreboard, every field as the game hands it over - a value,
--- or HIDDEN. Arn's first battleground, 14 Oct: "30 row(s) with the numbers hidden" - and a missing
--- field (Forever naming it differently) and a hidden one read alike in B.Scores. This tells them
--- apart, and shows what the old positional GetBattlefieldScore answers for the same row.
function B.Raw()
  local G = C_PvP and C_PvP.GetScoreInfo
  local n = yes(GetNumBattlefieldScores) or 0
  if not (G and type(n) == "number" and n > 0) then return NS.Print("bg raw: no scoreboard rows (in a battleground? /bist bg why)") end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local pick, info
  for i = 1, n do
    local ok, row = pcall(G, i)
    if ok and type(row) == "table" then
      local f = field(row, "faction")
      if pick == nil or (type(f) == "number" and f ~= myFaction) then pick, info = i, row end
      if type(f) == "number" and f ~= myFaction then break end
    end
  end
  if not info then return NS.Print("bg raw: C_PvP.GetScoreInfo gave no table for any of %d rows", n) end
  local function show(v)
    local okS, s = pcall(issecretvalue or function() return false end, v)
    if not okS or s then return "HIDDEN" end
    if type(v) == "table" then return "{table}" end
    return tostring(v)
  end
  local keys = {}
  local okP = pcall(function() for k in pairs(info) do keys[#keys + 1] = tostring(k) end end)
  table.sort(keys)
  NS.Print("bg raw: scoreboard row %d of %d, C_PvP.GetScoreInfo%s:", pick, n, okP and "" or " (its keys could not be listed)")
  local line = {}
  for _, k in ipairs(keys) do
    local okV, v = pcall(function() return info[k] end)
    line[#line + 1] = k .. "=" .. (okV and show(v) or "refused")
    if #line == 6 then DEFAULT_CHAT_FRAME:AddMessage("  " .. table.concat(line, "  ")) line = {} end
  end
  if #line > 0 then DEFAULT_CHAT_FRAME:AddMessage("  " .. table.concat(line, "  ")) end
  if GetBattlefieldScore then
    local res = { pcall(GetBattlefieldScore, pick) }
    local out = {}
    for i = 2, math.min(#res, 17) do out[#out + 1] = (i - 1) .. ":" .. show(res[i]) end
    DEFAULT_CHAT_FRAME:AddMessage("  GetBattlefieldScore(" .. pick .. "): " .. (res[1] and table.concat(out, " ") or "refused"))
  end
end

--- PROBE /bist bg sort [healing|kills|...]: Arn's idea, 14 Oct - "what about we can click the top
--- heals". The numbers are hidden, the names are not: ask the game to SORT the board by a column,
--- then read the names in row order. Printed now and again a second later, enemies marked "E".
function B.SortProbe(col)
  col = (col and col ~= "") and col or "healing"
  if not SortBattlefieldScoreData then return NS.Print("bg sort: this client has no SortBattlefieldScoreData") end
  local okS, err = pcall(SortBattlefieldScoreData, col)
  if not okS then return NS.Print("bg sort: refused (%s)", tostring(err)) end
  local mine = yes(UnitFactionGroup, "player")
  local myFaction = mine == "Horde" and 0 or (mine == "Alliance" and 1 or nil)
  local function list(when)
    local G = C_PvP and C_PvP.GetScoreInfo
    local n = yes(GetNumBattlefieldScores) or 0
    local out = {}
    for i = 1, math.min(type(n) == "number" and n or 0, 10) do
      local ok, row = pcall(G, i)
      local name = ok and type(row) == "table" and plain(field(row, "name"))
      local f = ok and type(row) == "table" and field(row, "faction")
      out[#out + 1] = i .. "." .. tostring(name or "?") .. ((type(f) == "number" and f ~= myFaction) and " E" or "")
    end
    NS.Print("bg sort %s, %s: %s", col, when, table.concat(out, ", "))
  end
  list("now")
  C_Timer.After(1, function() list("1 s later") end)
end

--- The memory, read out: how many healers and dangerous players it knows.
function B.WhyKnown()
  local h, k, n = 0, 0, 0
  for _, rec in pairs(B.Known()) do
    n = n + 1
    if (rec.healer or 0) > 0 then h = h + 1 end
    if (rec.killer or 0) > 0 then k = k + 1 end
  end
  DEFAULT_CHAT_FRAME:AddMessage(("  remembered from earlier battlegrounds: %d players - %d healers, %d dangerous"):format(n, h, k))
end

R:Register({
  name = "bg",
  desc = "battlegrounds: a saber on their top 3 healers, a red crosshair on their top killer",
  usage = "/bist bg [why | mark | forget <name> | clear]",
  defaults = { known = {} },
  OnInit = function() end,
  OnLogin = function() B.Watch() end,
  OnEnable = function() B.Watch() end,
  OnDisable = function() B.Watch() end,
  OnSlash = function(_, _, args)
    args = args or ""
    local who = args:match("^forget%s+(.+)$")
    if who then
      local known = B.Known()
      local key
      for name in pairs(known) do if name:lower() == who:lower() then key = name end end
      if not key then return NS.Print("bg: nobody called %s is remembered", who) end
      known[key] = nil
      B.PaintAll()
      return NS.Print("bg: %s forgotten", key)
    end
    if args:lower() == "raw" then return B.Raw() end
    if args:lower() == "board" then return B.BoardWhy() end
    if args:lower() == "mark" then return B.Mark() end
    local col = args:lower():match("^sort%s*(%S*)$")
    if col then return B.SortProbe(col) end
    if args:lower() == "clear" then
      local db = R:DBFor(R:Get("bg"))
      db.known = {}
      B.PaintAll()
      return NS.Print("bg: everyone forgotten")
    end
    B.Why()
  end,
})
