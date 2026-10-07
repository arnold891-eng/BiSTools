-- BiSTools / Core / Registry.lua
-- Every tool registers here. A tool is a table:
--   { name = "foo", desc = "one line", usage = "/bist foo [args]",
--     defaults = {...},            -- per-tool saved settings
--     OnInit = function(tool, db) end,   -- ADDON_LOADED, db is tool's sub-table
--     OnLogin = function(tool, db) end,  -- PLAYER_LOGIN
--     OnSlash = function(tool, db, args) end,
--     OnEnable / OnDisable = function(tool, db) end,  -- /bist on|off <name>
--     OnOpen = function(tool, db, recenter) end,  -- the Hub: show your window (recenter: to the middle)
--     options = { { kind = "toggle"|"seg"|"step"|"button", label, get(db), set(db, v),
--                   values (seg) | min, max, step, show(db) (step) | button, action(db) } },
--     slashWhenOff = true }   -- OnSlash still runs while the tool is off
local _, NS = ...
local R = { tools = {}, order = {} }
NS.Registry = R

function R:Register(tool)
  assert(tool and tool.name, "BiSTools: tool needs a name")
  local key = tool.name:lower()
  if self.tools[key] then error("BiSTools: duplicate tool '" .. key .. "'") end
  self.tools[key] = tool
  self.order[#self.order + 1] = key
  return tool
end

function R:Get(name)
  return name and self.tools[name:lower()]
end

function R:Enabled(name)
  local en = NS.DB().enabled[name:lower()]
  if en == nil then return true end
  return en
end

function R:SetEnabled(name, on)
  local key = name:lower()
  local was = self:Enabled(key)
  -- not "on and nil or false": that is false both ways (Lua's and/or with nil)
  if on then NS.DB().enabled[key] = nil else NS.DB().enabled[key] = false end
  local tool = self.tools[key]
  if tool and was ~= (on and true or false) then
    local h = on and tool.OnEnable or tool.OnDisable
    if h then h(tool, self:DBFor(tool)) end
  end
end

function R:DBFor(tool)
  local all = NS.DB().tools
  local key = tool.name:lower()
  all[key] = all[key] or {}
  local db = all[key]
  if tool.defaults then
    for k, v in pairs(tool.defaults) do
      if db[k] == nil then db[k] = v end
    end
  end
  return db
end

function R:InitAll()
  for _, key in ipairs(self.order) do
    local tool = self.tools[key]
    if tool.OnInit then tool:OnInit(self:DBFor(tool)) end
  end
end

function R:Fire(handler, ...)
  for _, key in ipairs(self.order) do
    local tool = self.tools[key]
    if tool[handler] and self:Enabled(key) then
      tool[handler](tool, self:DBFor(tool), ...)
    end
  end
end

function R:Each()
  local i = 0
  return function()
    i = i + 1
    local key = self.order[i]
    if key then return key, self.tools[key] end
  end
end
