--[[
  BiSTools :: Tools/PartyAuto.lua - the party tool's hands-off switches (21 Oct 2026). All OFF until turned on.

  Arn: "when a guild member invites you ... it'll auto accept an invite", and "if somebody whispers you a
  key word, it'll invite". Three switches in the party tool's options:

    accept from the guild     a guildmate's party invite is accepted for you
    accept from friends       so is a friend's (character or Battle.net)
    invite on a keyword       whoever whispers you the word ("inv") is invited - by default only the
                              guild and friends; "anyone" is a choice

  WHO, BY GUID. Forever has surnames, and two players can share a first name (the three Nebeons), so an
  invite or a whisper is matched by the GUID the event carries - IsGuildMember, C_FriendList.IsFriend,
  C_BattleNet.GetAccountInfoByGUID. With no GUID, only a WHOLE name ("Name Surname") counts, looked up in
  the guild roster and the friends list; a first name alone is never trusted.

  A WHISPER CAN BE SECRET. In a lockdown the whisper's text and sender are hidden from addons (Olympus,
  solved.md 7 Oct): "even a comparison raises". Both are asked first; hidden = nothing happens.

  The keyword invite goes through P.InviteNames, so past five the party still becomes a raid by itself.
  Nothing is said in chat to anyone: what happened goes to your own chat frame.
]]
local ADDON, NS = ...
local R = NS.Registry
local P = NS.Party

P.KEYWORD_GAP = 10                  -- one invite per whisperer per this many seconds

local function plain(v)
  if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
  return v
end

local function ask(fn, ...)
  if not fn then return nil end
  local ok, v = pcall(fn, ...)
  return ok and plain(v) or nil
end

local function bare(name)
  return type(name) == "string" and (name:gsub("%-[^%-]*$", "")) or nil      -- no realm
end

--- Your guildmates' and friends' WHOLE names, lowercased: the fallback when an event carries no GUID.
function P.WholeNames()
  local guild, friends = {}, {}
  if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
    for i = 1, (ask(GetNumGuildMembers) or 0) do
      local n = bare(ask(GetGuildRosterInfo, i))
      if n and n:find(" ", 1, true) then guild[n:lower()] = true end
    end
  end
  local FL = C_FriendList
  if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
    for i = 1, (ask(FL.GetNumFriends) or 0) do
      local ok, f = pcall(FL.GetFriendInfoByIndex, i)
      local n = ok and type(f) == "table" and bare(plain(f.name)) or nil
      if n and n:find(" ", 1, true) then friends[n:lower()] = true end
    end
  end
  return guild, friends
end

--- Who is this to you: "guild", "friend", or nil. GUID first; else a whole name, never a first name alone.
function P.Kin(name, guid)
  guid = plain(guid)
  if type(guid) == "string" and guid ~= "" then
    if ask(IsGuildMember, guid) then return "guild" end
    if C_FriendList and ask(C_FriendList.IsFriend, guid) then return "friend" end
    if C_BattleNet and ask(C_BattleNet.GetAccountInfoByGUID, guid) then return "friend" end
    return nil
  end
  local n = bare(plain(name))
  if not (n and n:find(" ", 1, true)) then return nil end
  local guild, friends = P.WholeNames()
  if guild[n:lower()] then return "guild" end
  if friends[n:lower()] then return "friend" end
  return nil
end

--- An invite came: accept it when the switch for who sent it is on. Answers what it did.
function P.OnInvite(db, name, guid)
  if not (db.acceptGuild or db.acceptFriends) then return nil end
  local kin = P.Kin(name, guid)
  if not ((kin == "guild" and db.acceptGuild) or (kin == "friend" and db.acceptFriends)) then return nil end
  local accept = AcceptGroup
  if not accept then return nil end
  local ok, err = pcall(accept)
  if not ok then
    NS.Print("party: could not accept %s's invite - %s", bare(plain(name)) or "?", tostring(err))
    return nil
  end
  if StaticPopup_Hide then pcall(StaticPopup_Hide, "PARTY_INVITE") end
  NS.Print("party: accepted %s's invite (%s)", bare(plain(name)) or "?", kin == "guild" and "guild" or "friend")
  return kin
end

function P.Keyword(db)
  local k = db.keywordText
  return type(k) == "string" and k ~= "" and k:lower() or P.KEYWORDS[1]
end

--- A whisper came: is it the keyword, from someone allowed? Then invite them. Answers the name invited.
function P.OnWhisper(db, text, sender, guid)
  if not db.keyword then return nil end
  text, sender = plain(text), plain(sender)
  if type(text) ~= "string" or type(sender) ~= "string" then return nil end        -- hidden in a lockdown
  local said = text:match("^%s*(.-)%s*$"):lower()
  if said ~= P.Keyword(db) then return nil end
  local name = bare(sender)
  if db.keywordFrom ~= "anyone" and not P.Kin(sender, guid) then return nil end
  local now = (GetTime and GetTime()) or 0
  P.asked = P.asked or {}
  local key = P.Key(name)
  if key and P.asked[key] and now - P.asked[key] < P.KEYWORD_GAP then return nil end
  if key then P.asked[key] = now end
  if not P.Leads() then
    NS.Print("party: %s whispered \"%s\" - only the leader (or an assistant) can invite", name, said)
    return nil
  end
  for _, m in ipairs(P.Members()) do
    if m.key == key then return nil end                                            -- already with you
  end
  NS.Print("party: %s whispered \"%s\" - invited", name, said)
  P.InviteNames(db, { name }, true)
  return name
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PARTY_INVITE_REQUEST")
ev:RegisterEvent("CHAT_MSG_WHISPER")
ev:SetScript("OnEvent", function(_, event, ...)
  local db = P.db
  if type(db) ~= "table" or not R:Enabled("party") then return end
  if event == "PARTY_INVITE_REQUEST" then
    local name, guid = ..., select(7, ...)
    P.OnInvite(db, name, guid)
  else
    local text, sender = ...
    P.OnWhisper(db, text, sender, (select(12, ...)))
  end
end)
P.autoEvents = ev
