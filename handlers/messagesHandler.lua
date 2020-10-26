local parse = require('../include/parser')

local errMsg = 'Error running command "%s" : %s.'
local f = string.format
local logger, mgr, msg

local function call(cmd, flags, args)
  if type(cmd) ~= 'table' or cmd.__name ~= 'Command' then return end

  if not cmd:hasPermissions(msg) then
    return false, f(errMsg, cmd.name, "Not enough permissions")
  end

  local success, failure, err = pcall(cmd.callback, cmd, msg, flags, args)

  if not success then
    if cmd._manager._unregisterCommandOnErr then
			cmd:unregister()
			logger:log(2, 'Command "%s" has been unloaded due to an error', cmd.name)
    end
    return false, f(errMsg, cmd.name, failure)
  elseif not failure then
    return false, f(errMsg, cmd.name, err)
  end

  return true
end

local function replySuccess(success, info)
  local me = msg.guild.me or msg.guild:getMember(msg.client.user.id)
  local reactions = {
    [true]  = type(mgr._replyWithReactionOnErr) == 'string' and mgr._replyWithReactionOnErr or '\u{2705}', -- 0x2705 = WHITE_HEAVY_CHECK_MARK
    [false] = '\u{274c}' -- 0x274c = CROSS_MARK
  }

  if me:hasPermissions('addReactions') and mgr._replyWithReactionOnErr then
    msg:addReaction(reactions[success])
  end

  if me:hasPermissions('sendMessages') and info then
    msg:reply(mgr._replyHeader .. info)
  end
end

-- TODO: Make the Manager options that accepts a string value and boolean one
-- to be able to use the custom string when it is not a boolean.

return function (mgr, msg)
  --- Initial checks. May depend on user configurations.

  -- Never respond to the current bot messages
	if mgr._client.user.id == msg.author.id then return end
  -- If the bot should not respond to other bots, return
  if not mgr._respondToBots and msg.author.bot then return end
  -- If the bot should not respond to DMs, return
  if not mgr._respondToDMs and msg.channel.type == 1 then return end

  -- Expose to other helper functions as up-values
  logger, mgr, msg = mgr._logger, mgr, msg

  -- Parse the message
	local parsed, cmd = parse(msg.content, mgr._commands)
  if parsed == false and cmd then -- Parsing error
    replySuccess(false, cmd)
  elseif not cmd then -- should never happen
    if mgr.replyToUndefinedCommands then
      replySuccess(false, f(errMsg, cmd.name, 'Command does not exists.'))
    end
  end

  -- Execute the command, and handle responses
  local success, err = call(cmd, parsed.flags, parsed.args)
  if not success then
    replySuccess(false, err)
  else
    replySuccess(true)
  end
end
