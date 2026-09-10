-- BiSTools / Core / Slash.lua
-- /bt              list tools
-- /bt <tool> ...   hand the rest to that tool
-- /bt on|off <tool>
local _, NS = ...
local T, R = NS.T, NS.Registry

local function List()
  NS.Print("v%s - tools:", NS.VERSION)
  for key, tool in R:Each() do
    local state = R:Enabled(key) and T.text("good", "on") or T.text("warn", "off")
    DEFAULT_CHAT_FRAME:AddMessage(("  %s %s - %s  %s"):format(
      state, T.text("accent", key), tool.desc or "", T.text("muted", tool.usage or "")))
  end
  DEFAULT_CHAT_FRAME:AddMessage(T.text("muted", "  /bt on|off <tool> to toggle  |  /bt hub | options | minimap  (or the minimap button)"))
end

SLASH_BISTOOLS1 = "/bt"
SLASH_BISTOOLS2 = "/bistools"
SlashCmdList.BISTOOLS = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$")
  if msg == "" then return List() end
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "on" or cmd == "off" then
    local tool = R:Get(rest)
    if not tool then return NS.Print("no tool '%s'", rest) end
    R:SetEnabled(rest, cmd == "on")
    return NS.Print("%s %s", tool.name, cmd == "on" and T.text("good", "on") or T.text("warn", "off"))
  end
  if NS.HubSlash and NS.HubSlash(cmd) then return end
  local tool = R:Get(cmd)
  if not tool then return NS.Print("no tool '%s' - /bt for the list", cmd) end
  -- a tool may keep its slash alive while off (summon: the nag switch must
  -- reach through, the nag is not the tool's window)
  if not R:Enabled(cmd) and not tool.slashWhenOff then return NS.Print("%s is off - /bt on %s", tool.name, cmd) end
  if not tool.OnSlash then return NS.Print("%s has no commands", tool.name) end
  tool:OnSlash(R:DBFor(tool), rest)
end
