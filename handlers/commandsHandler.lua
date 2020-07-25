local loader = require '../include/loader'.loadDirec
local FILES_PATT = '%.command%.lua$'

local baseErrorMsg = 'Error loading command "%s" : %s'

return function (manager)
  local env = setmetatable({
    manager = manager,
    Command = function(...) return manager:createCommand(...) end,
    require = require,
  }, {
    __index = _G
  })

  ---* Unloading event
  local function onUnload(n) manager._commands[n] = nil end

  ---* Loading event
  local function onLoad(n, c)
    if type(c) == 'function' then

      local success, err = pcall(c, manager)
      if not success then
        manager._logger:log(1, baseErrorMsg, n, err); return
      end

      if type(err) == 'table' and err.__name == 'Command' then
        success, err = pcall(manager.registerCommand, manager, err)
      elseif err then -- Not nil?
        manager._logger:log(1, baseErrorMsg, n,
          ('expected return value of "Command" got "%s"'):format(type(err)))
        return
      end

      if not success and err then
        manager._logger:log(1, baseErrorMsg, n, err)
        return
      end

    elseif type(c) == 'table' and c.__name == 'Command' or not c then

      local s, e = c and pcall(manager.registerCommand, manager, c)

      if not s and e then
        manager._logger:log(1, baseErrorMsg, n, e); return
      end

    else
      manager._logger:log(1, baseErrorMsg, n, ('expected return value of "Command" got "%s"'):format(type(c)))
      return
    end

    manager._logger:log(3, 'Successfully loaded "%s" command', n)
  end

  ---* Error event
  local function onErr(n, err)
    manager._logger:log(1, baseErrorMsg, n, err)
  end

  -- Load commands and auto-reload on changes
  loader(manager._commandsPath, FILES_PATT, env, {
    onErr = onErr,
    onLoad = onLoad,
    onUnload = onUnload,
  })
end