--[[
  BiSTools :: Tools/Party.lua - the `party` tool: your usual group, one click to invite them all, one
  to break it up.

  Arn, 15 Oct 2026, reading FojjiCore 3.3.8's party helper: "the saved list to invite is nice and a
  disband button" - and, asked where the list comes from, "its own list". Then: "when in a party or
  in a raid new option to add to party list ... when right click".

  - The list: `db.names`, your group's names (at most P.MAX). Filled by `/bist party save` (whoever
    you are grouped with now), `/bist party add|remove <name>`, or "BiS: add to party list" on a
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

--- The name a list entry is compared by: no realm, any case.
function P.Key(name)
  name = plain(name)
  if type(name) ~= "string" or name == "" then return nil end
  return (name:gsub("%-.*$", "")):lower()
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
local function send(name)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if invite then pcall(invite, name) end
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
  local missing = P.Missing(db)
  if #missing == 0 then NS.Print("party list: everyone is already with you") return 0 end
  if not P.Leads() then NS.Print("party list: only the leader (or an assistant) can invite") return 0 end
  local total = #P.Members() + 1 + #missing
  if P.Grouped() and not (IsInRaid and IsInRaid()) and total > 5 then
    local convert = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
    if convert then pcall(convert) end
  end
  for _, n in ipairs(missing) do P.queue[#P.queue + 1] = n end
  NS.Print("party list: inviting %d (%s)", #missing, table.concat(missing, ", "))
  if not P.timer then P.Pump() end
  return #missing
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

------------------------------------------------------------- the right-click line --
-- "BiS: add to party list" on a party or raid member's menu (Arn, 15 Oct). The game's own
-- Menu.ModifyMenu, as the rivals' lines are; never inside an instance (RC.MenuSafe).
P.MENUS = { "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "PLAYER" }

local function field(ctx, k)
  local ok, v = pcall(function() return ctx[k] end)
  return ok and plain(v) or nil
end

function P.MenuLine(db, root, ctx)
  if not (R:Enabled("party") and root and root.CreateButton) then return end
  local RC = NS.Recap
  if RC and RC.MenuSafe and not RC.MenuSafe() then return end
  local unit = field(ctx, "unit")
  if type(unit) ~= "string" then return end
  local okIn, inGroup = pcall(function()
    return (UnitInParty and UnitInParty(unit)) or (UnitInRaid and UnitInRaid(unit))
  end)
  if not okIn or not plain(inGroup) or UnitIsUnit(unit, "player") then return end
  local name = plain(GetUnitName and GetUnitName(unit, true) or UnitName(unit))
  if not P.Key(name) then return end
  local on = P.Has(db, name)
  if root.CreateDivider then root:CreateDivider() end
  root:CreateButton(on and "BiS: remove from party list" or "BiS: add to party list", function()
    if on then P.Remove(db, name) else P.Add(db, name) end
    NS.Print("party list: %s %s (%d on it)", name, on and "removed" or "added", #P.List(db))
    if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end
  end)
end

function P.HookMenus(db)
  if P.menusHooked or not (Menu and type(Menu.ModifyMenu) == "function") then return false end
  P.menusHooked = true
  for _, kind in ipairs(P.MENUS) do
    pcall(Menu.ModifyMenu, "MENU_UNIT_" .. kind, function(_, root, ctx) P.MenuLine(db, root, ctx) end)
  end
  return true
end

------------------------------------------------------------------ the tool --

local function refresh() if NS.Box and NS.Box.Refresh then NS.Box.Refresh() end end

local ev = CreateFrame("Frame")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:SetScript("OnEvent", refresh)
P.events = ev

R:Register({
  name = "party",
  desc = "your usual group: invite them all, or disband, in one click",
  usage = "/bist party [save | add <name> | remove <name> | list | clear | invite | disband]",
  defaults = {},
  options = {
    { kind = "button", label = "save my group as the list", help = "Everyone you're grouped with now becomes your party list. The Invite button in the BiS> tools box then asks them all back in one click.",
      button = "save", action = function(db)
        local n = P.SaveGroup(db)
        NS.Print(n > 0 and ("party list: %d saved"):format(n) or "party list: you're not in a group - nobody to save")
        refresh()
      end },
    { kind = "button", label = "clear the list", help = "Empty the party list.",
      button = "clear", action = function(db) db.names = {} NS.Print("party list: cleared") refresh() end },
  },
  OnInit = function(_, db) P.db = db end,
  OnLogin = function(_, db) P.db = db P.HookMenus(db) refresh() end,
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
    elseif verb == "disband" then
      if not P.Disband() then NS.Print("party list: you're not in a group") end
    else
      local list = P.List(db)
      NS.Print("party list (%d): %s", #list, #list > 0 and table.concat(list, ", ") or "empty - /bist party save, or right-click a party member")
    end
    refresh()
  end,
})
