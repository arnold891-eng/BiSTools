--------------------------------------------------------------------------------
-- BiSToolsAPI: for other addons - BiS Guild first (16 Oct 2026).
--
-- Arn: "I like OpenMap, that opens its stuff via API - what do you think if we do that too" ...
-- "if installed it can API-call it", and "bisg can do its own thing if no BiS Tools". So a caller
-- never reaches into BiS Tools' insides (NS.Party, its saved table): it asks here, and here stays the
-- same while the insides change. Shaped like OpenMapAPI:
--   * BiSToolsAPI.version goes up when something is added; nothing is changed or taken away without
--     a new BiSToolsAPI.major.
--   * Nothing here changes BiS Tools' settings. Every call is safe before login (it answers nil,
--     "not ready") and with the tool switched off (nil, "party tool off").
--
-- People: a list of names (Forever's whole "Name Surname" - an invite needs it), or of tables
-- { name = , class = (shown, e.g. "Mage"), classFile = "MAGE", rank = }.
--
-- Since version 2 (21 Oct 2026, for BiS Memories - a death at a rival's hands is worth a picture):
--   IsRival(name) -> true when that name is on your rivals list (gold or silver), false when not, or
--                    nil, "not ready". Read-only; the rivals tool switched off still answers.
--------------------------------------------------------------------------------
local _, NS = ...

local API = { major = 1, version = 2 }
BiSToolsAPI = API

local function Party()
  local P = NS.Party
  if not (P and P.db) then return nil, "not ready" end
  local R = NS.Registry
  if R and R.Enabled and not R:Enabled("party") then return nil, "party tool off" end
  return P
end

-- whether the party tool can take invites now
function API.PartyReady()
  local P = Party()
  return P ~= nil
end

local function Entries(people)
  local out = {}
  for _, p in ipairs(type(people) == "table" and people or {}) do
    if type(p) == "string" and p ~= "" then
      out[#out + 1] = { name = p }
    elseif type(p) == "table" and type(p.name) == "string" and p.name ~= "" then
      out[#out + 1] = { name = p.name, class = p.class, classFile = p.classFile, rank = p.rank }
    end
  end
  return out
end

-- these people on the party tool's confirm list ("look it over, then Send"): sorted by class, an x
-- per person, the little inviting box. Whoever is with you already is shown as such, not invited.
-- Answers how many wait to be sent, or nil and why.
function API.InviteList(label, people)
  local P, why = Party()
  if not P then return nil, why end
  local here = { [P.Key(UnitName("player")) or "?"] = true }
  for _, m in ipairs(P.Members()) do here[m.key] = true end
  local go, with = {}, {}
  for _, e in ipairs(Entries(people)) do
    if here[P.Key(e.name) or "?"] then with[#with + 1] = e else go[#go + 1] = e end
  end
  if #go == 0 then return 0 end
  if not P.Leads() then return nil, "not leader" end
  P.wave = nil          -- a list from outside is its own; Refresh rechecks it (P.Recheck), never a wave
  return P.Confirm(P.db, type(label) == "string" and label or "invites", go, with)
end

-- one person, at once - the caller's click was the choice. Answers 1, or nil and why.
function API.InviteOne(name)
  local P, why = Party()
  if not P then return nil, why end
  if type(name) ~= "string" or name == "" then return nil, "no name" end
  if not P.Leads() then return nil, "not leader" end
  return P.InviteNames(P.db, { name }) > 0 and 1 or 0
end

-- is this name one of your rivals? (version 2). Read straight off the recap's rival list - never changed here.
function API.IsRival(name)
  local RC = NS.Recap
  if not (RC and RC.DB and RC.Rivals) then return nil, "not ready" end
  if type(name) ~= "string" or name == "" then return false end
  if issecretvalue then
    local ok, yes = pcall(issecretvalue, name)
    if not ok or yes then return false end
  end
  local ok, db = pcall(RC.DB)
  if not ok or type(db) ~= "table" then return nil, "not ready" end
  return RC.Rivals(db)[name] ~= nil
end
