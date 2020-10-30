local parser = require('../include/parser')
local parse, ERRORS = parser.parse, parser.ERRORS

local errMsg = 'Error running command "%s" : %s.'
local f = string.format
local logger, mgr, msg
local formats = {}

local function call(cmd, flags, args)
  if type(cmd) ~= 'table' or cmd.__name ~= 'Command' then return end

  if not cmd:hasPermissions(msg) then
    return false, f(errMsg, cmd.name, "Not enough permissions"), -1
  end

  local success, failure, err = pcall(cmd.callback, cmd, msg, flags, args)

  if not success then
    if cmd._manager._unregisterCommandOnErr then
			cmd:unregister()
			logger:log(2, 'Command "%s" has been unloaded due to an error', cmd.name)
    end
    return false, f(errMsg, cmd.name, failure), -2
  elseif success and not failure then
    return false, f(errMsg, cmd.name, err), -3
  end

  return true
end

local function optionValue(index, str, els)
  local o = mgr[index]
  local formatter = function(captured)
    return (formats[index] or {})[captured] or formats[captured]
  end

  if type(o) == 'string' then
    o = o:gsub('$([^$%s%p]+)', formatter)
    return o
  else
    str = str:gsub('$([^$%s%p]+)', formatter)
    return (o and str) or (els and str)
  end
end

local function optionFailure(index, err, errCode)
  return errCode == ERRORS[err][2] and mgr[index]
end

local function replySuccess(success, info)
  local me = msg.guild.me or msg.guild:getMember(msg.client.user.id)
  local reactions = {
    [true]  = optionValue('_replyWithReactionOnErr', '\u{2705}', true), -- 0x2705 = WHITE_HEAVY_CHECK_MARK
    [false] = '\u{274c}' -- 0x274c = CROSS_MARK
  }

  if me:hasPermissions('addReactions') and mgr._replyWithReactionOnErr then
    msg:addReaction(reactions[success])
  end

  if me:hasPermissions('sendMessages') and info then
    msg:reply(mgr._replyHeader .. info)
  end
end

local function buildFormatters(cmd, args)
  formats = {
    m = mgr._replyWithMentionUser and msg.author.mentionString or '',
    ['_replyToUndefinedCommands'] = {
      c = cmd.name
    },
    ['_replyToUndefinedArguments'] = {
      f = args[1]
    },
    ['_replyToUnauthorized'] = {
      c = cmd.name
    }
  }
end

return function (cMgr, cMsg)
  --- Initial checks. May depend on user configurations.
  -- Never respond to the current bot messages
	if cMgr._client.user.id == cMsg.author.id then return end
  -- If the bot should not respond to other bots, return
  if not cMgr._respondToBots and cMsg.author.bot then return end
  -- If the bot should not respond to DMs, return
  if not cMgr._respondToDMs and cMsg.channel.type == 1 then return end

  -- Expose to other helper functions as up-values
  logger, mgr, msg = cMgr._logger, cMgr, cMsg

  -- Parse the message
  local parsed, cmd, errCode, errArgs = parse(msg.content, mgr._commands)
  if parsed == nil then return end -- Not a command

  -- Define the replies formats of the current command
  buildFormatters(cmd, errArgs)

  -- Handle any parsing errors
  if parsed == false and cmd then -- Parsing error
    if optionFailure('_replyToUndefinedCommands', 'COMMAND_NOT_FOUND', errCode) then
      replySuccess(false, optionValue('_replyToUndefinedCommands', cmd))
    elseif optionFailure('_replyToUndefinedArguments', 'UNKNOWN_ARGUMENT', errCode) then
      replySuccess(false, optionValue('_replyToUndefinedArguments', cmd))
    end
  elseif not cmd then -- should never happen
    if optionFailure('_replyToUndefinedCommands', 'COMMAND_NOT_FOUND', errCode) then
      replySuccess(false, optionValue('_replyToUndefinedArguments', cmd))
    end
  end

  -- Execute the command
  local success, err
  success, err, errCode = call(cmd, parsed.flags, parsed.args)

  -- Handle unsuccessful command runs
  if not success then
    if errCode == -3 or errCode == -2 then -- runtime error
      replySuccess(false, err)
    elseif errCode == -1 then -- not enough permissions
      if mgr._replyToUnauthorized then
        replySuccess(false, optionValue('_replyToUnauthorized', err))
      end
    else -- should never happen
      replySuccess(false, 'UNKNOWN ERROR : '.. err)
    end
  else
    replySuccess(true)
  end
end
