local discordia = require 'discordia'
local loader = require '../include/loader'.loadDirec

local FILE_PATT = "%.type%.lua$"
local types = {}

local function isSnowflake(id)
	return type(id) == 'string' and #id >= 17 and #id <= 64 and not id:match('%D')
end
types.isSnowflake = isSnowflake

return function(manager)
  local env = setmetatable(
    {
      isSnowflake = isSnowflake,
      discordia = discordia,
      manager = manager,
      client = manager._client,
      types = types,
    },

    {__index = _G}
  )

  local function onErr(n, e)
    manager._logger:log(1, 'Error loading type "%s" : %s', n, e)
  end

  local function onUnload(n)
    types[n] = nil
  end

  local function onLoad(n, c)
    types[n] = c
  end

  local function onReloaded(n)
    manager._logger:log(3, 'Successfully reloaded "%s" type', n)
  end

  --- Load library defined types (default types)
  loader(manager._defaultTypesPath, FILE_PATT, env, {
    onUnload = onUnload,
    doWatch = true, -- Do not reload on change
    onLoad = onLoad,
    onErr = onErr,
  })

  --- Load user defined types (custom types)
  loader(manager._typesPath, FILE_PATT, env, {
    onReloaded = onReloaded,
    onUnload = onUnload,
    onLoad = onLoad,
    onErr = onErr,
  })

  return types
end
