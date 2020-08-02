local loader = require '../include/loader'.loadDir
local type = require '../include/utils'.classType

local Command = require '../objects/Command'

--- TODO: Expose FILES_PATT to the end-user, allowing customizing
local FILES_PATT = '([^%/]+)%.command%.lua$'
local baseErr = 'Commands Loader (Command "%s") | %s'

return function (manager)
  local env = {
    manager = manager,
    require = require, --- NOTE: is this needed anymore?
    __index = _G
  }

  env.Command = function(cb, perms, aliases, args)
    return Command(manager, env.command_name,
      cb or env.cb,
      perms or env.perms,
      aliases or env.aliases,
      args or env.args
    )
  end
  env = setmetatable(env, env)

  local function log(level, n, msg, ...)
    msg = msg:format(...)
    manager._logger:log(level, baseErr, n, msg)
  end

  ---* Before loading event
  local function onBeforeload(n, l)
    local loaderEnv = getfenv(l)

    loaderEnv.command_name = n -- Used by Commandia, should not be manually defined

    setfenv(l, loaderEnv)
  end

  ---* Loading event
  local function onLoad(n, r, c)
    local commandEnv, g = getfenv(c), {}

    local globalsmap = {
      aliases = {"table", "string"},

      permissions = {"table", "string"},
      perms = {"table", "string"},

      arguments = {"table"},
      args = {"table"},

      callback = {"function"},
      cb = {"function"}
    }

    for k, _ in pairs(globalsmap) do
      g[k] = commandEnv[k]
    end

    --- NOTE: In Luvit a global (args) is used instead of the global (arg)
    -- which might cause conflicting with Commandia's global (args)
    -- this code will asure no conflicting happens.
    -- If user defined a global args with index 0 then conflicting will happen
    -- **an index 0 for `args` must never be defined**.
    if type(g.args) == "table" and g.args[0] then
      g.args = nil
    end

    do -- Check if provided globals are valid
      local i, isValid

      for global, types in pairs(globalsmap) do
        i, isValid = g[global]

        for _, t in ipairs(types) do
          if type(i) == t then isValid = true end
        end

        if i ~= nil and not isValid then
          log(1, n, 'bad value for global "%s" (expected %s, got %s)',
            global, table.concat(types, '|'), type(i)
          ); return false
        end
      end
    end

    local aliases = g.aliases
    local perms = g.permissions or g.perms
    local args = g.arguments or g.args
    local cb = g.callback or g.cb

    local returnType = type(r)
    if returnType == 'function' then
      manager._commands[n] = manager:createCommand(n, r, perms, aliases, args, false)
    elseif returnType == 'table' then

      manager._commands[n] = manager:createCommand(
        n, r.callback or cb,
        r.permissions or r.perms or perms,
        r.aliases,
        r.arguments or r.args or args,
        false
      )

    elseif returnType == 'Command' then
      if not r.callback and not cb then
        log(1, n, 'bad argument #1 to "Command" (expected function|global "callback", got no value)')
        return false
      end

      manager._commands[n] = r
    elseif not r and cb then
      manager._commands[n] = manager:createCommand(n, cb, perms, aliases, args, false)
      p(aliases, manager._commands[n].arguments)
    elseif next(g) then
      log(1, n, 'A callback is required but got no callback '..
        '(you can either define a global "callback", and/or return a function value. See wiki for more info.)'
      ); return false

    else
      log(1, n, 'bad return value for command "%s" (expected %s, got %s)',
        n, "function|table|Command", returnType
      ); return false
    end
  end

  ---* First load event
  local function onFirstload(n)
    log(3, n, 'Command has been successfully loaded')
  end

  ---* Reloaded event
  local function onReloaded(n)
    log(3, n, 'Command has been successfully reloaded')
  end

  ---* Unloading event
  local function onUnload(n)
    manager._commands[n] = nil
  end

  ---* Deleting event (renaming/moving/deletion)
  local function onDeleted(n)
    log(2, n, 'Command has been unloaded due to Command\'s file inaccessibility')
    manager._commands[n] = nil
  end

  ---* Error event
  local function onErr(n, err)
    log(1, n, err)
  end

  -- Load commands and auto-reload on changes
  loader(manager._commandsPath, FILES_PATT, env, {
    onErr = onErr,
    onLoad = onLoad,
    onUnload = onUnload,
    onDeleted = onDeleted,
    onReloaded = onReloaded,
    onFirstload = onFirstload,
    onBeforeload = onBeforeload,
  })
end