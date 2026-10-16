--[[
  BiSTools :: Tools/Party.lua - the `party` tool: your usual group, one click to invite them all, one
  to break it up.

  Arn, 15 Oct 2026, reading FojjiCore 3.3.8's party helper: "the saved list to invite is nice and a
  disband button" - and, asked where the list comes from, "its own list". Then: "when in a party or
  in a raid new option to add to party list ... when right click".

  - The list: `db.names`, your group's names (at most P.MAX). Filled by `/bist party save` (whoever
    you are grouped with now), `/bist party add|remove <name>`, or "Add to party list" (BiS section) on a
    party or raid member's right-click menu (outside instances: inside one an addon line breaks the
    game's menu - RC.MenuSafe).
  - Two buttons in the BiS> tools box (Box.lua):
      Invite   everyone on the list who is not with you yet (solo, or leading / assisting)
      Disband  leading: everyone out; otherwise you leave
    They show when the list means something now: solo with a list, or grouped with someone on it.
  - Nothing ticks: GROUP_ROSTER_UPDATE asks the box to look again, out of combat.
]]
local ADDON, NS = ...
local R = NS.Registry

local P = {}
NS.Party = P
P.MAX = 39                       -- a raid less you
P.PER_PUMP, P.PUMP_GAP = 4, 1.2  -- invites sent at once, and the wait before the next few

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

--- The name a list entry is compared by: the first name - no surname (Forever's "Darthsidiouz
--- Sithlord" is Darthsidiouz to the game), no realm, any case.
function P.Key(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" then return nil end
  local first = name:match("^([^%s%-]+)")
  return first and first:lower() or nil
end

--- What an invite is sent to: the WHOLE name, surname and all (Arn, 15 Oct: "/invite Nebeon" did
--- nothing, and the game's own chat box completed it to "Nebeon Nolightforu" - Forever addresses a
--- player by first name and surname, as its mail does). The name exactly as the list keeps it.
function P.InviteName(name)
  return name
end

--- The short name, for the box's lines only (a surname wraps them).
function P.Short(name)
  return type(name) == "string" and (name:match("^(%S+)") or name) or name
end

function P.List(db)
  if type(db.names) ~= "table" then db.names = {} end
  return db.names
end

function P.Has(db, name)
  local k = P.Key(name)
  if not k then return false end
  for _, n in ipairs(P.List(db)) do if P.Key(n) == k then return true end end
  return false
end

--- Add a name; false (and why) when it is there already, the list is full, or it is no name.
function P.Add(db, name)
  name = plain(name)
  if not P.Key(name) then return false, "no name" end
  if P.Has(db, name) then return false, "already on the list" end
  local list = P.List(db)
  if #list >= P.MAX then return false, "the list is full" end
  list[#list + 1] = name
  return true
end

function P.Remove(db, name)
  local k, list = P.Key(name), P.List(db)
  for i = #list, 1, -1 do
    if P.Key(list[i]) == k then table.remove(list, i) return true end
  end
  return false
end

function P.Grouped() return (IsInGroup and IsInGroup()) and true or false end

function P.Leads()
  if not P.Grouped() then return true end
  local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
  local assist = IsInRaid and IsInRaid() and UnitIsGroupAssistant and plain(UnitIsGroupAssistant("player"))
  return lead == true or assist == true
end

--- Everyone grouped with you (not you): { unit, name, key }. A 40-man walk is 120 calls, so the
--- box walks it once and hands it to each question (the `members` argument below).
function P.Members()
  local out = {}
  if not P.Grouped() then return out end
  local raid = IsInRaid and IsInRaid()
  local n = raid and (GetNumGroupMembers and GetNumGroupMembers() or 0) or 4
  for i = 1, n do
    local unit = (raid and "raid" or "party") .. i
    if UnitExists(unit) and not UnitIsUnit(unit, "player") then
      local name = plain(GetUnitName and GetUnitName(unit, true) or UnitName(unit))
      local key = P.Key(name)
      if key then out[#out + 1] = { unit = unit, name = name, key = key } end
    end
  end
  return out
end

--- The names on the list who are not with you (never you).
function P.Missing(db, members)
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(members or P.Members()) do here[m.key] = true end
  local out = {}
  for _, n in ipairs(P.List(db)) do
    if not here[P.Key(n) or "?"] then out[#out + 1] = n end
  end
  return out
end

--- Does anyone on the list share your group?
function P.WithListed(db, members)
  for _, m in ipairs(members or P.Members()) do if P.Has(db, m.name) then return true end end
  return false
end

--- Whoever you are grouped with now becomes the list. The number saved.
function P.SaveGroup(db)
  local members = P.Members()
  if #members == 0 then return 0 end
  db.names = {}
  for _, m in ipairs(members) do P.Add(db, m.name) end
  return #db.names
end

------------------------------------------------------------- invite / disband --

P.queue = {}
-- SAID, NOT SWALLOWED (Arn, 15 Oct: "i dont think it is sending any invites" - the box ran, the game
-- said nothing, and the pcall had eaten whatever went wrong). A refusal lands in the box's log and
-- once in chat, with the game's own words.
local function send(name)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if not invite then P.Refused(name, "this client has no invite call") return end
  local ok, err = pcall(invite, P.InviteName(name))
  if not ok then P.Refused(name, err) end
end

function P.Refused(name, why)
  why = tostring(why or "?")
  repeat local n why, n = why:gsub("^[^%s]-:%d+: ", "") until n == 0      -- no "file.lua:12: " in front
  P.lastError = why
  P.failed = (P.failed or 0) + 1
  if P.run and P.box then P.Say(NS.T.text("warn", ("%s: the game refused (%s)"):format(P.Short(name) or "?", why))) end
  if not P.saidError then
    P.saidError = true
    NS.Print("party list: the game refused an invite - %s", why)
  end
end

--- A few at a time: a burst of invites is what gets a player's messages throttled.
function P.Pump()
  P.timer = nil
  local n = 0
  while #P.queue > 0 and n < P.PER_PUMP do
    send(table.remove(P.queue, 1))
    n = n + 1
  end
  if #P.queue > 0 and C_Timer and C_Timer.NewTimer then P.timer = C_Timer.NewTimer(P.PUMP_GAP, P.Pump) end
end

--- Invite everyone on the list who is not with you. More than a party holds: a party you lead
--- becomes a raid first (a party of five refuses the sixth).
function P.Invite(db)
  return P.InviteNames(db, P.Missing(db))
end

--- Invite these names (none of them with you already): the party list's, or a guild rank's.
function P.InviteNames(db, missing)
  if #missing == 0 then NS.Print("party list: everyone is already with you") return 0 end
  if not P.Leads() then NS.Print("party list: only the leader (or an assistant) can invite") return 0 end
  local total = #P.Members() + 1 + #missing
  if P.Grouped() and not (IsInRaid and IsInRaid()) and total > 5 then
    local convert = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if convert then pcall(convert) end
  end
  for _, n in ipairs(missing) do P.queue[#P.queue + 1] = n end
  if db.show ~= false then P.Show(missing) else
    NS.Print("party list: inviting %d (%s)", #missing, table.concat(missing, ", "))
  end
  if not P.timer then P.Pump() end
  return #missing
end

------------------------------------------------------------- the little show --
-- WATCH THE MACHINE WORK (Arn, 15 Oct: "a little progress bar of it inviting people ... the invites
-- are instant, its just a little flavor of seeing the machine do something" - and then: "not saying
-- stuff in actual chat, saying things on the window"). The SHAPE is the old Counter-Strike loading
-- box (his reference): a title, lines of text scrolling up as the machine talks to each player, a
-- sunken bar filling with chunky blocks, Cancel. The LOOK is ours (Arn: "i like our bis theme -
-- these pictures are just ideas we can do in the bis themes"): BiSTheme's surface, accent edge and
-- purple blocks, at the family's 1.43:1. Pure flavour: the invites have already gone. Nothing goes
-- to chat. OnUpdate only while it shows; Cancel or the end hides it. `db.show = false` skips it.
P.BLOCKS, P.LOG_ROWS = 14, 3
P.W, P.H = 300, 210                          -- 1.43:1
P.SHOW_MIN, P.SHOW_PER, P.SHOW_MAX, P.LINGER = 1.4, 0.45, 4.0, 1.2
-- the note under the rule, one per run (Arn's second reference: "This server is VAC-secured.
-- Cheating will result in a permanent ban.")
P.NOTES = {
  "Note: this group is BiS-secured. Standing in fire will result in a permanent wipe.",
  "Note: loot is need before greed. Needing on everything will be remembered.",
  "Note: the tank sets the pace. Pulling for the tank will result in a repair bill.",
  "Note: this group is healer-secured. Not drinking will result in a long wait.",
}
-- each player gets an opening line and a closing one, so the text keeps moving
P.OPEN = {
  "Establishing network connection to %s...",
  "Resolving %s's realm...",
  "Pinging %s... %d ms",
  "Sending invite packet to %s...",
  "Negotiating loot rules with %s...",
  "Asking %s nicely...",
}
P.CLOSE = {
  "Handshake with %s: OK",
  "%s: invite delivered",
  "%s: packet received, 0 lost",
  "%s: connection stable",
}

function P.Line(list, i, name)
  local fmt = list[(i - 1) % #list + 1]
  if fmt:find("%%d") then return fmt:format(name, math.random(3, 60)) end
  return fmt:format(name)
end

--- The whole script of one run: the lines in order, the first one before any player.
function P.Script(names)
  local out = { "Contacting the party list..." }
  for i, n in ipairs(names) do
    n = P.Short(n)                         -- the first name, on screen only: a surname wraps the line
    out[#out + 1] = P.Line(P.OPEN, i + math.random(0, #P.OPEN - 1), n)
    out[#out + 1] = P.Line(P.CLOSE, i + math.random(0, #P.CLOSE - 1), n)
  end
  return out
end

function P.BuildShow()
  if P.box then return P.box end
  local K, T = NS.Farm, NS.T
  local f = CreateFrame("Frame", "BiSToolsPartyLoading", UIParent)
  P.box = f
  f:SetSize(P.W, P.H)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 140)
  f:SetFrameStrata("DIALOG")
  K.tex(f, "BACKGROUND", "surface", 0.97)
  f.edge = K.border(f, "accent", 0.8)
  f.title = K.fs(f, T.text("accent", "BiS>") .. " invite", 13, "ink")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
  local inner = P.W - 24
  local function bar(y, w)
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(w, 16)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y)
    K.tex(b, "BACKGROUND", "sunken", 1)
    b.blocks = {}
    local step = (w - 6) / P.BLOCKS
    for i = 1, P.BLOCKS do
      local t = b:CreateTexture(nil, "ARTWORK")
      t:SetColorTexture(K.color("accent"))
      t:SetSize(step - 3, 10)
      t:SetPoint("LEFT", b, "LEFT", 3 + (i - 1) * step, 0)
      t:Hide()
      b.blocks[i] = t
    end
    return b
  end
  -- the whole run: what it is doing, and how far
  f.status = K.fs(f, "", 11, "ink2")
  f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
  f.all = bar(-46, inner)
  f.blocks = f.all.blocks
  -- the player now: the machine talking to them (the newest line at the bottom), time left, a bar
  f.log = {}
  for i = 1, P.LOG_ROWS do
    local l = K.fs(f, "", 11, i == P.LOG_ROWS and "ink2" or "muted")
    l:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70 - (i - 1) * 14)
    l:SetWidth(inner)
    l:SetJustifyH("LEFT")
    l:SetWordWrap(false)                     -- one line each, never over the line below
    f.log[i] = l
  end
  f.left = K.fs(f, "", 11, "muted")
  f.left:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70 - P.LOG_ROWS * 14)
  f.one = bar(-88 - P.LOG_ROWS * 14, inner - 66)
  local cancel = CreateFrame("Button", nil, f)
  cancel:SetSize(56, 16)
  cancel:SetPoint("LEFT", f.one, "RIGHT", 10, 0)
  K.tex(cancel, "BACKGROUND", "sunken", 1)
  K.border(cancel, "line2", 1)
  cancel.label = K.fs(cancel, "Cancel", 11, "ink2")
  cancel.label:SetPoint("CENTER", cancel, "CENTER", 0, 0)
  cancel:SetScript("OnClick", function() P.EndShow() end)
  f.cancel = cancel
  -- a rule, and the note under it (the reference's "this server is VAC-secured")
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(T.rgb("line2"))
  rule:SetSize(inner, 1)
  rule:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -114 - P.LOG_ROWS * 14)
  f.note = K.fs(f, "", 11, "ink2")
  f.note:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -122 - P.LOG_ROWS * 14)
  f.note:SetWidth(inner)
  f.note:SetJustifyH("LEFT")
  f:SetScript("OnUpdate", function(_, dt) P.Step(dt) end)
  f:Hide()
  return f
end

--- One more line at the bottom of the log; the rest move up one.
function P.Say(line)
  local f = P.box
  local shown = P.shown or {}
  shown[#shown + 1] = line
  while #shown > P.LOG_ROWS do table.remove(shown, 1) end
  P.shown = shown
  for i = 1, P.LOG_ROWS do f.log[i]:SetText(shown[i - (P.LOG_ROWS - #shown)] or "") end
end

--- Start it: the script spread over the run, the bar filling with the clock.
function P.Show(names)
  local f = P.BuildShow()
  local script = P.Script(names)
  P.run = { names = names, script = script, t = 0, said = 0,
            len = math.min(P.SHOW_MAX, P.SHOW_MIN + P.SHOW_PER * #names) }
  P.shown, P.failed, P.saidError = {}, 0, nil
  for _, b in ipairs(f.all.blocks) do b:Hide() end
  for _, b in ipairs(f.one.blocks) do b:Hide() end
  for _, l in ipairs(f.log) do l:SetText("") end
  f.status:SetText(("Inviting your party list: %d player%s..."):format(#names, #names == 1 and "" or "s"))
  f.note:SetText(P.NOTES[math.random(1, #P.NOTES)])
  f:Show()
  P.Step(0)
end

function P.Step(dt)
  local run, f = P.run, P.box
  if not (run and f) then return end
  run.t = run.t + (dt or 0)
  if run.done then
    if run.t >= run.len + P.LINGER then P.EndShow() end
    return
  end
  local frac = math.min(1, run.t / run.len)
  local function fill(bar, x)
    local lit = math.floor(x * P.BLOCKS + 0.5)
    for i, b in ipairs(bar.blocks) do if i <= lit then b:Show() else b:Hide() end end
  end
  fill(f.all, frac)
  -- the player now: their share of the run, and the seconds left of the whole
  local n = math.max(1, #run.names)
  local seg = run.len / n
  fill(f.one, frac >= 1 and 1 or ((run.t % seg) / seg))
  local left = math.ceil(run.len - run.t)
  f.left:SetText(left > 0 and ("%d second%s remaining"):format(left, left == 1 and "" or "s") or "")
  local due = math.min(#run.script, 1 + math.floor(frac * (#run.script - 1) + 0.0001))
  while run.said < due do
    run.said = run.said + 1
    P.Say(run.script[run.said])
  end
  if frac >= 1 then
    run.done = true
    local n = #run.names
    local ok = n - (P.failed or 0)
    if (P.failed or 0) > 0 then
      P.Say(("Done. %d of %d invited."):format(ok, n))
    else
      P.Say(("Done. %d invite%s sent."):format(n, n == 1 and "" or "s"))
    end
    f.status:SetText("Inviting your party list: done.")
  end
end

-- WHAT THE GAME SAYS BACK (Arn, 15 Oct: "he is in a group, should also throw an error on here").
-- The invite's real answer comes as a system message; while the box is up, a failure lands in its
-- log in the warning colour, and the last line counts it. The game's own format strings, so the
-- client's language is the one matched.
P.REPLIES = {
  { "ERR_ALREADY_IN_GROUP_S", "%s is already in a group", true },
  { "ERR_BAD_PLAYER_NAME_S", "can't find %s (offline?)", true },
  { "ERR_INVITE_PLAYER_S", "%s: invite received", false },
}
local function pattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end
function P.Heard(msg)
  if not P.run or type(msg) ~= "string" or (issecretvalue and issecretvalue(msg)) then return false end
  for _, r in ipairs(P.REPLIES) do
    local pat = pattern(_G[r[1]])
    local who = pat and msg:match(pat)
    if who then
      who = P.Short(who)
      if r[3] then
        P.failed = (P.failed or 0) + 1
        P.Say(NS.T.text("warn", r[2]:format(who)))
      else
        P.Say(r[2]:format(who))
      end
      return true
    end
  end
  return false
end
do
  local heard = CreateFrame("Frame")
  heard:RegisterEvent("CHAT_MSG_SYSTEM")
  -- a protected call refused shows up as these, not as a Lua error
  heard:RegisterEvent("ADDON_ACTION_BLOCKED")
  heard:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  heard:SetScript("OnEvent", function(_, event, msg, fn)
    if event == "CHAT_MSG_SYSTEM" then
      if P.run then P.Heard(msg) end
    elseif msg == ADDON and type(fn) == "string" and fn:lower():find("invite", 1, true) then
      P.Refused("", ("%s: %s is protected on this client"):format(event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked", fn))
    end
  end)
  P.heard = heard
end

function P.EndShow()
  P.run = nil
  if P.box then P.box:Hide() end
end

--- Leading: everyone out. Otherwise: you leave.
function P.Disband()
  if not P.Grouped() then return false end
  local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
  if lead == true then
    local uninvite = (C_PartyInfo and C_PartyInfo.UninviteUnit) or UninviteUnit
    for _, m in ipairs(P.Members()) do if uninvite then pcall(uninvite, m.name) end end
    NS.Print("party list: group disbanded")
  else
    local leave = (C_PartyInfo and C_PartyInfo.LeaveParty) or LeaveParty
    if leave then pcall(leave) end
    NS.Print("party list: you left the group")
  end
  return true
end

------------------------------------------------------------- the box buttons --

--- When the buttons mean something: solo with a list, or grouped with someone on it.
function P.ShowInvite(db, members)
  if not (db and R:Enabled("party")) or #P.List(db) == 0 then return false end
  members = members or P.Members()
  if P.Grouped() and not P.WithListed(db, members) then return false end
  return P.Leads() and #P.Missing(db, members) > 0
end
function P.ShowDisband(db, members)
  if not (db and R:Enabled("party") and P.Grouped()) then return false end
  return P.WithListed(db, members) and true or false
end

local function button(name, icon, tip, sub, onClick)
  local K = NS.Farm
  local b = CreateFrame("Button", name, UIParent)
  b:SetSize(26, 26)
  b:SetFrameStrata("MEDIUM")
  b:RegisterForClicks("LeftButtonUp")
  K.tex(b, "BACKGROUND", "field", 0.95)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 2, -2) b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexture(icon)
  b.edge = K.border(b, "accent", 1)
  b.boxed = true
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(tip)
    GameTooltip:AddLine(type(sub) == "function" and sub() or sub, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  return b
end

P.GREEN, P.RED = { 0.35, 0.85, 0.45 }, { 0.90, 0.30, 0.30 }

function P.Buttons()
  if P.ibtn then return P.ibtn, P.dbtn end
  P.ibtn = button("BiSToolsPartyInvite", "Interface\\Icons\\INV_Letter_15", "Invite your party list",
    function() return table.concat(P.Missing(P.db or {}), ", ") end,
    function() P.Invite(P.db) end)
  P.dbtn = button("BiSToolsPartyDisband", "Interface\\Icons\\Ability_Rogue_Sprint", "Disband",
    function()
      local lead = UnitIsGroupLeader and plain(UnitIsGroupLeader("player"))
      return lead == true and "Everyone out of the group." or "You leave the group (you are not the leader)."
    end,
    function() P.Disband() end)
  return P.ibtn, P.dbtn
end

------------------------------------------------------------- the window --
-- THE LIST, WHERE YOU CAN SEE IT (Arn, 15 Oct: "i dont see the party frame when i click the button
-- on the list" - the tools list opens a tool's window, and this tool had none). The farm window's
-- frame and header (the BiS> prompt, x to close), at the family's 1.43:1: the names in two columns
-- (green = with you now, x = off the list), a box to add one, and the four things you do with it.
P.WIN_W, P.WIN_H = 250, 175                  -- 1.43:1 (wide enough for five buttons)
P.WIN_SCALE = 1.2
P.ROWS, P.ROW_H, P.HEADER = 6, 14, 16

local function button(parent, label, w, colour, onClick, tip)
  local F = NS.Farm
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 16)
  F.tex(b, "BACKGROUND", "field", 0.95)
  b.edge = F.border(b, colour or "edge", 1)
  b.label = F.fs(b, label, 9, colour or "ink")
  b.label:SetPoint("CENTER")
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self)
    b.edge:set("accent", 1)
    if GameTooltip and tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() b.edge:set(colour or "edge", 1) if GameTooltip then GameTooltip:Hide() end end)
  return b
end

function P.BuildWindow(db)
  if P.win then return P.win end
  local F = NS.Farm
  local f = CreateFrame("Frame", "BiSToolsParty", UIParent)
  P.win = f
  f:SetSize(P.WIN_W, P.WIN_H)
  f:SetScale(P.WIN_SCALE)                    -- Arn, 15 Oct: "20% bigger, same aspect ratio" - all of it grows
  f:SetFrameStrata("MEDIUM")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, rel, x, y = self:GetPoint(1)
    db.pos = { point or "CENTER", x or 0, y or 0, rel or point or "CENTER" }
  end)
  F.tex(f, "BACKGROUND", "frame", F.BODY_A)
  F.border(f, "edge", 0.35)
  local head = CreateFrame("Frame", nil, f)
  head:SetPoint("TOPLEFT") head:SetPoint("TOPRIGHT")
  head:SetHeight(P.HEADER)
  F.tex(head, "BACKGROUND", "header", F.HEAD_A)
  f.title = F.fs(head, "", 8, "ink")
  f.title:SetPoint("LEFT", head, "LEFT", 4, 0)
  f.con = BiSTheme.Console(f.title, { width = P.WIN_W - 17 - 8 })
  f.con:Set("name", "Party", "accent")
  local acc = 0
  f:SetScript("OnUpdate", function(_, dt)          -- the prompt's cursor; only while shown
    acc = acc + (dt or 0)
    if acc >= 0.1 then acc = 0 f.con:Paint() end
  end)
  f.closeBtn = F.HeaderButton(head, -3, "x", "Close", "/bist party reopens it.", function() f:Hide() end, "warn")
  -- WHOLE RANKS (Arn, 15 Oct: "the guild feature will be invite all raiders button etc"): g shows
  -- the guild's ranks with someone online; a click invites that whole rank. Single guildmates go on
  -- the list from the guild window's own right-click (P.GUILD_MENUS, behind its switch).

  -- the names: two columns of P.ROWS
  f.rows = {}
  local colW = (P.WIN_W - 12) / 2
  for i = 1, P.ROWS * 2 do
    local col, row = math.floor((i - 1) / P.ROWS), (i - 1) % P.ROWS
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(colW - 4, P.ROW_H)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + col * colW, -(P.HEADER + 4) - row * P.ROW_H)
    r.name = F.fs(r, "", 9, "ink")
    r.name:SetPoint("LEFT", r, "LEFT", 2, 0)
    r.x = CreateFrame("Button", nil, r)
    r.x:SetSize(12, 12)
    r.x:SetPoint("RIGHT", r, "RIGHT", -2, 0)
    r.x.label = F.fs(r.x, "x", 8, "warn")
    r.x.label:SetPoint("CENTER")
    r.x:SetScript("OnClick", function() if r.who then P.Remove(db, r.who) P.Changed() end end)
    -- in the guild view the whole row is the button: on the list, or off it
    r.pick = CreateFrame("Button", nil, r)
    r.pick:SetAllPoints(r)
    r.pick:SetScript("OnClick", function()
      if r.rank then P.InviteRank(db, r.rank) return end
      if not r.who then return end
      if P.Has(db, r.who) then P.Remove(db, r.who) else P.Add(db, r.who) end
      P.Changed()
    end)
    r.pick:Hide()
    r:Hide()
    f.rows[i] = r
  end
  f.more = F.fs(f, "", 8, "dim")
  f.more:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(P.HEADER + 4) - P.ROWS * P.ROW_H)
  -- add a name
  local well = CreateFrame("Frame", nil, f)
  well:SetSize(P.WIN_W - 12, 16)
  well:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 26)
  F.tex(well, "BACKGROUND", "field", 0.9)
  well.edge = F.border(well, "edge", 1)
  local eb = CreateFrame("EditBox", "BiSToolsPartyAdd", well)
  eb:SetAllPoints()
  eb:SetTextInsets(4, 4, 0, 0)
  eb:SetFont(STANDARD_TEXT_FONT, 9, "")
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(48)
  local ph = F.fs(well, "add a name, Enter...", 9, "dim")
  ph:SetPoint("LEFT", 4, 0)
  eb:SetScript("OnEditFocusGained", function() ph:Hide() well.edge:set("accent", 1) end)
  eb:SetScript("OnEditFocusLost", function(self)
    well.edge:set("edge", 1)
    if (self:GetText() or "") == "" then ph:Show() end
  end)
  eb:SetScript("OnEnterPressed", function(self)
    local name = (self:GetText() or ""):match("^%s*(.-)%s*$")
    local ok, why = P.Add(db, name)
    if not ok and name ~= "" then NS.Print("party list: %s", tostring(why)) end
    self:SetText("")
    self:ClearFocus()
    P.Changed()
  end)
  eb:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
  f.add = eb
  -- what you do with the list
  -- five along the bottom (Arn, 15 Oct: "from this window a button that shows all the guild ranks,
  -- i click the ranks and it sends out invites"): ranks swaps the names for the guild's ranks
  local bw = (P.WIN_W - 12 - 12) / 5
  local acts = {
    { "save", "good", function() P.SaveGroup(db) P.Changed() end, "Save group: everyone you're grouped with now becomes the list." },
    { "invite", "good", function() P.Invite(db) end, "Invite everyone on the list who isn't with you yet." },
    { "ranks", "accent", function() P.view = (P.view == "guild") and "list" or "guild" P.PaintWindow() end,
      "Your guild's ranks with someone online: click a rank to invite all of them. Click again for your list." },
    { "disband", "warn", function() P.Disband() end, "Leading: everyone out. Otherwise: you leave." },
    { "clear", "muted", function() db.names = {} P.Changed() end, "Empty the list." },
  }
  f.buttons = {}
  for i, a in ipairs(acts) do
    local b = button(f, a[1], bw, a[2], a[3], a[4])
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6 + (i - 1) * (bw + 3), 6)
    f.buttons[a[1]] = b
  end
  f.guildBtn = f.buttons.ranks
  f:Hide()
  return f
end

--- Your guildmates online now, not you: { name (no realm), rank, rankIndex }, by name.
function P.GuildOnline()
  local out = {}
  if not (IsInGuild and IsInGuild()) then return out end
  local okN, n = pcall(GetNumGuildMembers)
  n = okN and plain(n) or 0
  local me = P.Key(UnitName("player"))
  for i = 1, (type(n) == "number" and n or 0) do
    local ok, name, rank, rankIndex, _, _, _, _, _, online = pcall(GetGuildRosterInfo, i)
    if not ok then name = nil end
    name = plain(name)
    rank = plain(rank)
    rankIndex = plain(rankIndex)
    online = plain(online)
    if type(name) == "string" and online and P.Key(name) ~= me then
      out[#out + 1] = { name = (name:gsub("%-.*$", "")), rank = type(rank) == "string" and rank or nil,
                        rankIndex = tonumber(rankIndex) or 99 }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

--- WHOLE RANKS (Arn, 15 Oct: "invite all rank <raider> and it invites anyone that has raider
--- rank"): the ranks with someone online, highest first, and how many.
function P.Ranks(online)
  local by, out = {}, {}
  for _, m in ipairs(online or P.GuildOnline()) do
    if m.rank then
      local r = by[m.rank]
      if not r then r = { rank = m.rank, index = m.rankIndex, n = 0 } by[m.rank] = r out[#out + 1] = r end
      r.n = r.n + 1
    end
  end
  table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

--- Everyone online with that rank (any case), not with you: invited, the show and all.
function P.InviteRank(db, rank)
  rank = (rank or ""):lower()
  -- a number is the rank's place in the list "/bist party rank" prints (Arn typed "rank 1")
  local nth = tonumber(rank)
  if nth then
    local r = P.Ranks()[nth]
    if not r then NS.Print("party list: no rank number %d online (/bist party rank lists them)", nth) return 0 end
    rank = r.rank:lower()
  end
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  local names, found = {}, false
  for _, m in ipairs(P.GuildOnline()) do
    if m.rank and m.rank:lower() == rank then
      found = true
      if not here[P.Key(m.name) or "?"] then names[#names + 1] = m.name end
    end
  end
  if not found then NS.Print("party list: nobody online with the rank %s", rank) return 0 end
  return P.InviteNames(db, names)
end

--- Repaint: your list (with you now = green), or the guild to pick from (on the list = green, a tick).
function P.PaintWindow()
  local f, db = P.win, P.db
  if not (f and db and f:IsShown()) then return end
  local guild = P.view == "guild"
  f.con:Set("name", guild and "Party: ranks" or "Party", "accent")
  f.guildBtn.label:SetText(guild and "list" or "ranks")
  local names, here = P.List(db), {}
  local entries
  if guild then
    entries = {}
    for _, r in ipairs(P.Ranks()) do entries[#entries + 1] = { rank = r.rank, n = r.n } end
    names = entries
  else
    for _, m in ipairs(P.Members()) do here[m.key] = true end
  end
  P.offset = 0
  for i, r in ipairs(f.rows) do
    local e = names[i + (P.offset or 0)]
    local n = guild and e and e.name or (not guild and e) or nil
    r.who, r.rank = n, guild and e and e.rank or nil
    if e then
      if r.rank then
        r.name:SetText(("invite all <%s> (%d)"):format(r.rank, e.n))
        r.name:SetTextColor(NS.Farm.color("accent"))
      else
        local on = guild and P.Has(db, n)
        r.name:SetText(on and (n .. "  " .. NS.T.text("good", "+")) or n)
        local r_, g, b = NS.Farm.color(((guild and on) or here[P.Key(n) or "?"]) and "good" or "ink")
        r.name:SetTextColor(r_, g, b, 1)
      end
      if guild then r.x:Hide() r.pick:Show() else r.x:Show() r.pick:Hide() end
      r:Show()
    else
      r:Hide()
    end
  end
  local extra = #names - #f.rows - (P.offset or 0)
  if guild then
    f.more:SetText(#names == 0 and "nobody else in your guild is online"
      or "click a rank: everyone online with it is invited")
  else
    f.more:SetText(#names == 0 and "empty - g for your guild, save your group, or right-click a player"
      or (extra > 0 and ("+%d more (/bist party list)"):format(extra) or ""))
  end
end

--- The list changed: the window and the box look again.
function P.Changed()
  P.PaintWindow()
  if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
end

function P.Toggle(db, show, recenter)
  local f = P.BuildWindow(db)
  if show == nil then show = not f:IsShown() end
  if not show then f:Hide() return end
  f:ClearAllPoints()
  local p = db.pos
  if recenter or type(p) ~= "table" then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  else f:SetPoint(p[1], UIParent, p[4] or p[1], p[2] or 0, p[3] or 0) end
  f:Show()
  P.PaintWindow()
end

------------------------------------------------------------- the right-click line --
-- "Add to party list", in the BiS section of a party or raid member's menu (Arn, 15 Oct). The game's own
-- Menu.ModifyMenu, as the rivals' lines are; never inside an instance (RC.MenuSafe).
P.MENUS = { "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "PLAYER",
  -- the Friends list too (Arn, 15 Oct, a Battle.net friend: "can it add the Darthsidiouz sithlord
  -- to the party list?" - he asked for shift-click; that would mean hooking Blizzard's own list
  -- buttons, which is what breaks the client on Forever, so it is the right-click line instead)
  "FRIEND", "FRIEND_OFFLINE", "BN_FRIEND", "BN_FRIEND_OFFLINE" }

local function field(ctx, k)
  local ok, v = pcall(function() return ctx[k] end)
  return ok and plain(v) or nil
end

function P.MenuLine(db, root, ctx, kind)
  if not (R:Enabled("party") and root and root.CreateButton) then return end
  local RC = NS.Recap
  if RC and RC.MenuSafe and not RC.MenuSafe() then return end
  local name
  if kind == "GUILD" then
    if not db.guildMenu then return end             -- switched off since: nothing until the /reload
    name = RC and RC.MenuName and RC.MenuName(ctx)
  elseif (RC and RC.FRIEND_MENUS and RC.FRIEND_MENUS[kind or ""]) or field(ctx, "bnetIDAccount") ~= nil then
    -- a friend: whoever it is (a Battle.net friend by the character they're playing in this game)
    name = RC and RC.FriendName and RC.FriendName(ctx)
  else
    -- ANY FRIENDLY PLAYER, not just your group (Arn, 15 Oct, right-clicking someone in Orgrimmar:
    -- "why cant i add them to the party list? is that only for people in the party?"). Not you,
    -- and not the other faction - you could not invite them anyway.
    local unit = field(ctx, "unit")
    if type(unit) ~= "string" then return end
    local okP, friendly = pcall(function()
      return UnitIsPlayer(unit) and UnitIsFriend("player", unit) and not UnitIsUnit(unit, "player")
    end)
    if not okP or plain(friendly) ~= true then return end
    name = plain(GetUnitName and GetUnitName(unit, true) or UnitName(unit))
  end
  if not P.Key(name) then return end
  local on = P.Has(db, name)
  if RC and RC.Section then RC.Section(root) elseif root.CreateDivider then root:CreateDivider() end
  root:CreateButton(on and "Remove from party list" or "Add to party list", function()
    if on then P.Remove(db, name) else P.Add(db, name) end
    NS.Print("party list: %s %s (%d on it)", name, on and "removed" or "added", #P.List(db))
    P.Changed()
  end)
end

-- THE GUILD WINDOW'S MENU (Arn, 15 Oct: "from the guild window to add them to the party list same
-- as from the friend list"). The one menu the family stays out of: Olympus found a line there left
-- promote / demote / remove refused for officers (RC.MenuAllowed). So it is a SWITCH, off by
-- default, and while off the menu is never even hooked; on, it hooks at once. Arn tests it once
-- (add someone, then promote or demote someone) - if Forever refuses, it stays off. Turning it
-- off takes a /reload to unhook.
P.GUILD_MENUS = { "COMMUNITIES_GUILD_MEMBER", "COMMUNITIES_WOW_MEMBER", "GUILD" }
function P.HookGuildMenus(db)
  if P.guildHooked or not db.guildMenu or not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  P.guildHooked = true
  for _, kind in ipairs(P.GUILD_MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) P.MenuLine(db, root, ctx, "GUILD") end)
  end
  return true
end

function P.HookMenus(db)
  if P.menusHooked or not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  P.menusHooked = true
  for _, kind in ipairs(P.MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) P.MenuLine(db, root, ctx, kind) end)
  end
  return true
end

------------------------------------------------------------------ the tool --

local function refresh() P.Changed() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", refresh)
P.events = ev

R:Register({
  name = "party",
  -- OFF until turned on (Arn, 15 Oct: "start with this option for the party in tools off so the BiS
  -- toolbox is not overwhelming")
  defaultOff = true,
  desc = "your usual group: invite them all, or disband, in one click",
  usage = "/bist party [save | add <name> | remove <name> | list | clear | invite | rank <rank> | disband]",
  defaults = {},
  options = {
    { kind = "button", label = "save my group as the list", help = "Everyone you're grouped with now becomes your party list. The Invite button in the BiS> tools box then asks them all back in one click.",
      button = "save", action = function(db)
        local n = P.SaveGroup(db)
        NS.Print(n > 0 and ("party list: %d saved"):format(n) or "party list: you're not in a group - nobody to save")
        refresh()
      end },
    { kind = "toggle", label = "the inviting show", help = "When you press Invite, a little loading box fills up and talks you through it in chat. Just for fun: the invites go out at once either way.",
      get = function(db) return db.show ~= false end, set = function(db, on) db.show = on and true or false end },
    { kind = "toggle", label = "add from the guild window", help = "Puts 'Add to party list' on a guildmate's right-click in the guild window. TEST IT ONCE: the game may then refuse Promote / Demote / Remove for officers until a /reload. Off by default; turning it off needs a /reload.",
      get = function(db) return db.guildMenu == true end,
      set = function(db, on) db.guildMenu = on and true or false if on then P.HookGuildMenus(db) end end },
    { kind = "button", label = "clear the list", help = "Empty the party list.",
      button = "clear", action = function(db) db.names = {} NS.Print("party list: cleared") refresh() end },
  },
  OnInit = function(_, db) P.db = db end,
  OnOpen = function(_, db, recenter) P.db = db P.Toggle(db, true, recenter) end,
  OnLogin = function(_, db) P.db = db P.HookMenus(db) P.HookGuildMenus(db) refresh() end,
  OnSlash = function(_, db, args)
    P.db = db
    local verb, rest = (args or ""):match("^(%S*)%s*(.-)%s*$")
    verb = (verb or ""):lower()
    if verb == "save" then
      local n = P.SaveGroup(db)
      NS.Print(n > 0 and ("party list: %d saved"):format(n) or "party list: you're not in a group - nobody to save")
    elseif verb == "add" then
      local ok, why = P.Add(db, rest)
      NS.Print(ok and ("party list: %s added (%d on it)"):format(rest, #P.List(db)) or ("party list: " .. tostring(why)))
    elseif verb == "remove" then
      NS.Print(P.Remove(db, rest) and ("party list: %s removed"):format(rest) or ("party list: %s is not on it"):format(rest))
    elseif verb == "clear" then
      db.names = {}
      NS.Print("party list: cleared")
    elseif verb == "invite" then
      P.Invite(db)
    elseif verb == "rank" then
      if rest == "" then
        local ranks = {}
        for i, r in ipairs(P.Ranks()) do ranks[#ranks + 1] = ("%d. %s (%d)"):format(i, r.rank, r.n) end
        NS.Print("ranks online: %s - /bist party rank <name or number> invites them all", #ranks > 0 and table.concat(ranks, ", ") or "nobody")
      else
        P.InviteRank(db, rest)
      end
    elseif verb == "disband" then
      if not P.Disband() then NS.Print("party list: you're not in a group") end
    elseif verb == "" then
      P.Toggle(db)
    else
      local list = P.List(db)
      NS.Print("party list (%d): %s", #list, #list > 0 and table.concat(list, ", ") or "empty - /bist party save, or right-click a party member")
    end
    refresh()
  end,
})
