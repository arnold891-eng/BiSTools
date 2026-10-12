-- BiSTools / Tools / Recap.lua
-- WHAT KILLED YOU - step one: MEASURE (12 Oct 2026).
--
-- Arn, for a friend: "can we do a death recap of who or what killed him", with a League of Legends
-- death recap for the look. The combat log is closed to addons on Forever (solved.md: PARTY_KILL,
-- never the combat log). What is open is the game's own record of your last death, C_DeathRecap -
-- in the Forever census, and read by EllesmereUI's damage meters and Olympus on Arn's PC. Ellesmere's
-- note: the fields "may come back SECRET mid-combat". Nobody here knows WHICH fields, or WHEN they
-- become readable, and the whole design hangs on it: plain numbers allow totals, "48%" and "1,344
-- damage in 19 seconds"; hidden ones allow only a list the game draws for us.
--
-- So this tool does not guess. It reads the record three times - the moment you die, when the fight
-- ends, and when you ask - and `/bist recap` prints every field of every hit, as its value or as
-- <hidden>. Nothing here does arithmetic on, compares, or keys a table with anything it was handed:
-- a field is shown only after issecretvalue said it may be. No timers; two events, both rare.
local _, NS = ...
local T, R = NS.T, NS.Registry

local RC = { MAX_ROWS = 10 }
NS.Recap = RC

local function hidden(v)
  if v == nil or not issecretvalue then return false end
  local ok, yes = pcall(issecretvalue, v)
  return (not ok) or yes == true
end

-- a TABLE can be hidden as a whole; issecretvalue is not for tables (Overlord asks canaccessvalue)
local function hiddenTable(t)
  if issecrettable then
    local ok, yes = pcall(issecrettable, t)
    if not ok or yes == true then return true end
  end
  if canaccessvalue then
    local ok, yes = pcall(canaccessvalue, t)
    if not ok or yes ~= true then return true end
  end
  return false
end

--- One field as text, never touching a hidden one.
local function show(v)
  if hidden(v) then return "<hidden>" end
  local kind = type(v)
  if kind == "string" then return '"' .. v:sub(1, 40) .. '"' end
  if kind == "number" or kind == "boolean" or kind == "nil" then return tostring(v) end
  return "<" .. kind .. ">"
end
RC.Show = show

--- Read the game's record of your last death, as text. A snapshot: what the game said, when.
function RC.Read(label)
  local snap = { label = label, rows = {}, hiddenFields = {}, notes = {} }
  local D = C_DeathRecap
  if not (D and D.GetRecapEvents) then
    snap.notes[#snap.notes + 1] = "this client has no death recap to read"
    return snap
  end
  if D.HasRecapEvents then
    local ok, has = pcall(D.HasRecapEvents)
    snap.has = ok and show(has) or "refused"
  end
  if D.GetRecapMaxHealth then
    local ok, hp = pcall(D.GetRecapMaxHealth)
    snap.maxHealth = ok and show(hp) or "refused"
  end
  if IsInInstance then
    local ok, inside = pcall(IsInInstance)
    snap.instance = ok and show(inside) or "refused"
  end
  snap.combat = InCombatLockdown and show(InCombatLockdown()) or "?"

  local ok, events = pcall(D.GetRecapEvents)
  if not ok then
    snap.notes[#snap.notes + 1] = "the game refused: " .. tostring(events)
    return snap
  end
  if events == nil then
    snap.notes[#snap.notes + 1] = "the game has no record (nothing has killed you yet)"
    return snap
  end
  if hidden(events) or (type(events) == "table" and hiddenTable(events)) then
    snap.notes[#snap.notes + 1] = "the whole record is hidden"
    return snap
  end
  if type(events) ~= "table" then
    snap.notes[#snap.notes + 1] = "the game answered " .. show(events) .. ", not a list"
    return snap
  end
  local okN, n = pcall(function() return #events end)
  snap.count = okN and n or nil
  for i = 1, math.min(snap.count or 0, RC.MAX_ROWS) do
    local row = events[i]
    if type(row) ~= "table" or hiddenTable(row) then
      snap.rows[#snap.rows + 1] = ("#%d %s"):format(i, type(row) == "table" and "<hidden hit>" or show(row))
    else
      local keys = {}
      pcall(function() for k in pairs(row) do keys[#keys + 1] = k end end)
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      local parts = {}
      for _, k in ipairs(keys) do
        local okV, v = pcall(function() return row[k] end)
        local s = okV and show(v) or "<refused>"
        if s == "<hidden>" or s == "<refused>" then snap.hiddenFields[tostring(k)] = true end
        parts[#parts + 1] = tostring(k) .. "=" .. s
      end
      snap.rows[#snap.rows + 1] = ("#%d %s"):format(i, table.concat(parts, " "))
    end
  end
  return snap
end

--- Print one snapshot.
function RC.Say(snap)
  if not snap then return end
  local hiddenList = {}
  for k in pairs(snap.hiddenFields) do hiddenList[#hiddenList + 1] = k end
  table.sort(hiddenList)
  NS.Print("%s: %s hits recorded · max health %s · in instance %s · in combat %s",
    T.text("accent", snap.label), tostring(snap.count or 0), tostring(snap.maxHealth or "?"),
    tostring(snap.instance or "?"), tostring(snap.combat or "?"))
  for _, note in ipairs(snap.notes) do DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("warn", note)) end
  if snap.count and snap.count > 0 then
    DEFAULT_CHAT_FRAME:AddMessage("  " .. (#hiddenList > 0
      and T.text("warn", "hidden: " .. table.concat(hiddenList, ", "))
      or T.text("good", "nothing hidden")))
  end
  for _, line in ipairs(snap.rows) do DEFAULT_CHAT_FRAME:AddMessage("  " .. T.text("muted", line)) end
end

-- DIED: read at once, and again when the fight is over - the second answer is the one that says
-- whether waiting makes the record readable
function RC.OnEvent(_, event)
  if not R:Enabled("recap") then return end
  if event == "PLAYER_DEAD" then
    RC.atDeath, RC.afterFight = RC.Read("at death"), nil
    RC.waitFight = true
    NS.Print("you died - %s shows what the game recorded", T.text("accent", "/bist recap"))
  elseif event == "PLAYER_REGEN_ENABLED" and RC.waitFight then
    RC.waitFight = nil
    RC.afterFight = RC.Read("after the fight")
  end
end

RC.frame = CreateFrame("Frame")
RC.frame:RegisterEvent("PLAYER_DEAD")
RC.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
RC.frame:SetScript("OnEvent", RC.OnEvent)

NS.Registry:Register({
  name = "recap",
  desc = "what killed you - measuring what the game will tell us",
  usage = "/bist recap",
  OnSlash = function(_, _, args)
    if not RC.atDeath and args ~= "now" then
      NS.Print("no death since you logged in - here is what the game holds right now:")
    end
    if args ~= "now" then
      RC.Say(RC.atDeath)
      RC.Say(RC.afterFight)
    end
    RC.Say(RC.Read("right now"))
  end,
})
