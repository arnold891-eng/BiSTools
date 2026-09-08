--[[
  BiSTheme / Console.lua  --  the "BiS> _" prompt every BiS window carries in its header.

  Arn, 8 Sep 2026: "prompt `BiS> _` blinking should be in the header and cycle
  relevant messages: addon name, summoners at the stone, receiving summon,
  requesting summon, etc." Chat stays clean: what the addon is doing is said
  here, not in the chat frame. Chat is for /slash answers only.

  The title FontString of the window IS the console. It shows

      BiS> <text>_            cursor blinking at 2 Hz

  where <text> is either a standing SLOT (the addon's name, "2 at stone",
  "requesting...") - the slots rotate every `cycle` seconds - or a transient
  line pushed with Say ("Druid asks", "Druid accepted"), which jumps the queue,
  holds for `hold` seconds, then the rotation resumes.

  Usage from any addon:

      local con = BiSTheme.Console(titleFontString, { width = 110 })
      con:Set("name", "Summon")                 -- slot 1: always the addon's name
      con:Set("stone", "2 at stone", "good")    -- a state slot; nil text clears it
      con:Say("Druid asks", "gold")             -- an event line, shown once
      con:Paint()                               -- from a ~0.2 s ticker: blink, rotate, expire

  Slots rotate in the order they were first Set. Pick words that fit the box:
  T.Fit trims with an ellipsis as the net, not the plan.

  Self-guarded like LibBiSComm: an addon may ship a copy under Libs\BiSTheme\ so
  the prompt works without BiSTheme installed. Newest CONSOLE_MINOR wins; the
  canonical file lives in the BiSTheme addon and is copied out, never edited in
  place. If BiSTheme itself is absent the palette falls back inline.
]]

BiSTheme = BiSTheme or {}
local T = BiSTheme
if (T.CONSOLE_MINOR or 0) >= 2 then return end
T.CONSOLE_MINOR = 2

-- palette fallback: only when this file is embedded and BiSTheme.lua never ran
if not T.rgb then
  local FALLBACK = {
    bg = "121020", surface = "1a1730", sunken = "221d3c", line = "2a2446",
    line2 = "3a3260", ink = "ece8f6", ink2 = "c6bedd", muted = "968ead",
    accent = "b980ff", accentSoft = "2c2148", good = "4fd0cf", warn = "f08cb0",
    gold = "e5c04a", slate = "8fb4d6", dim = "8e86a6",
  }
  T.hex = T.hex or FALLBACK
  local cache = {}
  function T.rgb(name)
    local hex = T.hex[name] or T.hex.ink
    local c = cache[hex]
    if c then return c[1], c[2], c[3] end
    c = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
    cache[hex] = c
    return c[1], c[2], c[3]
  end
  function T.rgba(name, a) local r, g, b = T.rgb(name) return r, g, b, a or 1 end
  function T.text(name, s) return "|cff" .. (T.hex[name] or T.hex.ink) .. tostring(s) .. "|r" end
end

-- defaults; an addon may override per console through opts
T.CONSOLE = {
  cycle  = 3,       -- seconds a standing slot shows before the next one
  hold   = 3,       -- seconds a Say line holds before the rotation resumes
  prompt = "BiS> ",
}

--- A label must fit its box: shrink with an ellipsis until GetStringWidth says so.
--- (Arn, 8 Sep: "summon requested - click to cancel" ran into the "all" button.)
--- Pick text that fits outright; the ellipsis is the net, not the plan.
function T.Fit(fs, text, width)
  fs:SetText(text)
  if not width or not fs.GetStringWidth then return text end
  local t = text
  while fs:GetStringWidth() > width and #t > 1 do
    t = t:sub(1, -2)
    fs:SetText(t .. "...")
  end
  return fs:GetText()
end

local Con = {}
Con.__index = Con

--- Wrap a FontString (the window's title) as the prompt.
function T.Console(fs, opts)
  opts = opts or {}
  local D = T.CONSOLE
  local c = setmetatable({}, Con)
  c.fs, c.width = fs, opts.width
  c.cycle, c.hold = opts.cycle or D.cycle, opts.hold or D.hold
  c.slots, c.order, c.queue = {}, {}, {}
  c.idx, c.since = 1, GetTime()
  if fs.GetStringWidth then
    fs:SetText("_") c.curW = fs:GetStringWidth()
    fs:SetText(D.prompt) c.promptW = fs:GetStringWidth()
  end
  c:Paint()
  return c
end

--- A standing slot: shown in rotation while it has text. nil clears it.
function Con:Set(key, text, colour)
  if text == nil or text == "" then
    self.slots[key] = nil
  else
    if not self.slots[key] then self.order[#self.order + 1] = key end
    self.slots[key] = { text = tostring(text), colour = colour or "ink" }
  end
  self:Paint()
end

--- An event line: jumps the rotation, holds `hold` seconds, then the slots resume.
--- Several in a row queue up and show one after the other.
function Con:Say(text, colour)
  local q = self.queue
  q[#q + 1] = { text = tostring(text), colour = colour or "ink2" }
  self:Paint()
end

function Con:Clear()
  self.queue = {}
  self:Paint()
end

-- the slot in rotation right now, skipping cleared keys
function Con:Current(now)
  local live = {}
  for _, k in ipairs(self.order) do if self.slots[k] then live[#live + 1] = self.slots[k] end end
  if #live == 0 then return nil end
  if now - self.since >= self.cycle then
    self.idx = self.idx + 1
    self.since = now
  end
  if self.idx > #live then self.idx = 1 end
  return live[self.idx]
end

--- Blink the cursor, rotate the slots, expire the said line. Call from a ticker.
function Con:Paint()
  local now = GetTime()
  local line
  if self.saying then
    if now - self.saidAt >= self.hold then
      self.saying = nil
      self.since = now   -- the slot after a Say gets its full cycle
    else
      line = self.saying
    end
  end
  if not line and #self.queue > 0 then
    self.saying = table.remove(self.queue, 1)
    self.saidAt = now
    line = self.saying
  end
  if not line then line = self:Current(now) end
  self.line = line
  local blink = math.floor(now * 2) % 2 == 0
  local cur = blink and "_" or " "
  local words = line and line.text or ""
  if self.width and line then
    -- trim the plain words only (never inside a colour escape); prompt and
    -- cursor keep their own width outside the trim
    words = T.Fit(self.fs, words, self.width - (self.curW or 0) - (self.promptW or 0))
  end
  self.fs:SetText(T.text("accent", T.CONSOLE.prompt) .. (line and T.text(line.colour, words) or "") .. cur)
end
