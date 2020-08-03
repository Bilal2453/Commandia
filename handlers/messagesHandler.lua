local assertCmd = require '../include/utils'.assertCmd
local gmatch = require 'rex'.gmatch

local remove, insert = table.remove, table.insert
local f = string.format

local baseErrorMsg = 'Error executing command\'s callback "%s" : %s'

-- Parsing

local function getFlag(n, c)
	for _, a in pairs(c.arguments) do
		for _, v in pairs(a) do
			if v == n then
				return a
			end
		end
	end
end

local function split(str)
	local args = {}

	for i in gmatch(str, [[(?|"(.+?)"|'(.+?)'|(\S+))]]) do
		table.insert(args, i)
	end

	return args
end

local function argsParser(str, command)
	local splitMesg = split(str)
	remove(splitMesg, 1)

	local args = {}
	local flags = {}

	local function valid(i, q)
		return type(splitMesg[i + q]) == 'string' and not splitMesg[i + q]:match('^(%-%-?)')
	end

	local lastIndexedFlagArg = 0
	local fm, name, flag

	for i, v in ipairs(splitMesg) do
		fm, name = v:match('^(%-%-?)(%S+)')

		if fm then
			flag = getFlag(name, command)

			if not flag then return nil, fm.. name end

			flags[flag.name] = {}

			for q = 1, (flag.eatArgs == -1 and #splitMesg) or flag.eatArgs or 1 do
				if valid(i, q) then
					insert(flags[flag.name], splitMesg[i + q])
					lastIndexedFlagArg = i + q
				else
					break
				end
			end

		elseif i > lastIndexedFlagArg then
			insert(args, v)
		end
	end

	return {flags = flags, args = args}
end

-- Preparing for calling commands

local function reply(msg, m, baseMsg, formats)
	local i = m[formats.index]
	formats.index = nil

	if not i then return
	elseif type(i) == 'string' then baseMsg = i
	end

	formats.m = m._replyWithMentionUser and (formats.m and formats.m or msg.member.mentionString).. ' ' or ''
	if not baseMsg:find('%m', 1, true) then baseMsg = '%m'..baseMsg end

	baseMsg = baseMsg:gsub('%%(.)', formats)
	baseMsg = m._replyHeader.. baseMsg

	msg:reply(baseMsg)

	local sr = m._replyWithReactionOnErr
	sr = sr and (type(sr) == 'string' and sr or '❌')
	if sr then pcall(msg.addReaction, msg, sr) end
end

local function fi(t, c, ...)
	local success, e
	for k, v in pairs(t) do
		success, e = pcall(c, v, ...)
		if not success then return false, e end
		t[k] = e
	end

	-- Call the callback at least once even when the table is empty
	if not next(t) and success == nil then
		success, e = pcall(c, nil, ...)
		if not success then return false, e end
		insert(t, e)
	end

	return true
end

local function callCommand(command, msg)
	if type(command) ~= 'table'
		or command.__name ~= 'Command' then return end

	local splitMsg = split(msg.content)
	remove(splitMsg, 1)

	local commandsArgs, err = argsParser(msg.content, command)

	local manager = command._manager
	local logger = command._manager._logger
	local types = manager._types

	-- One of the inputed arguments can't be found
	if not commandsArgs and err then
		reply(msg, manager, 'Unknown command\'s flag `%f`', {
			index = "_replyToUndefinedArguments",
			f = err
		})

		return
	end

	local flags = commandsArgs.flags
	local args = commandsArgs.args

	-- Process and convert the arguments to their assigned types
	local flag, sucs, errmsg, tyn, ty
	for flagname, flagargs in pairs(flags) do
		flag = getFlag(flagname, command)

		-- Call the 'output' callback if any
		-- meant to format the data before the type conversion
		if type(flag.output) == 'function' then
			sucs, errmsg = pcall(flag.output, flagargs)

			if sucs then
				flagargs = errmsg
			else
				return nil, f('Error in "%s" Flag\'s output handler : %s', flagname, errmsg), 1
			end
		end

		tyn, ty = flag.type, types[flag.type]
		if ty then

			sucs, errmsg = fi(flagargs, ty, msg, manager)
			if not sucs then return nil, f('Error in "%s" type handler : %s', tyn, errmsg), 1 end

		elseif type(tyn) == 'function' then

			sucs, errmsg = fi(flagargs, tyn, msg, manager)
			if not sucs then return nil, f('Error in "%s" type\'s custom handler : %s', flagname, errmsg), 1 end

		end

		if #flagargs <= 1 then flags[flagname] = flagargs[1] end
	end

	local s, e, m
	if command:hasPermissions(msg) then
		s, e, m = pcall(command.callback, command, msg, flags, args, splitMsg)
	else
		reply(msg, manager, 'You don\'t have enough permissions to use "%c" command', {
			index = "_replyToUnauthorized",
			c = command.name
		})
		return true
	end

	if not s then
		if command._manager._unregisterCommandOnErr then
			command:unregister()
			logger:log(2, 'Command "%s" has been unloaded due to an error', command.name)
		end

		return nil, f(baseErrorMsg, command.name, e)
			or f('Unknown error while executing "%s" command', command.name), 1
	end

	if e then
		assertCmd(true, m, msg)
	elseif e ~= nil or not e and m then
		assertCmd(tostring(m), msg)
	end

	return true
end

-- Actual command calling

local function log(logger, s, l, m, ...)
	if not s and m then logger:log(l, m, ...) end
end

-- pr = getPerfix
local function pr(prefix, msg, logger)
	if type(prefix) == 'function' then
		local s, e = pcall(prefix, msg.guild, msg)
		if not s then
			logger:log(1, 'Error calling prefix\'s callback : %s', e)
		else
			return e
		end
	else
		return prefix
	end
end

local function call(name, msg, m, command, n)
	if name == (n or command.name) then
		local succ, err, level = callCommand(command, msg)

		log(m._logger, succ, level, err)
		return true
	end
end

-- The initial callback

return function(manager, msg)
	if not manager or not msg then return end
	if not manager._respondToBots and msg.author.bot then return end
	if msg.author == manager._client.user then return end
	if not manager._respondToDMs and not msg.guild then return end

	local cmdName = split(msg.content)[1]
	if not cmdName then return end

	local prefix = pr(manager._prefix, msg, manager._logger)
	if not cmdName:find(prefix, 1, true) then return end
	cmdName = cmdName:sub(#prefix+1) -- subtract the prefix from the command name. can be cheaper than not subtracting

	for _, command in pairs(manager._commands) do
		if #command.aliases < 1 then
			if call(cmdName, msg, manager, command) then return end
		else
			for _, name in pairs(command.aliases or {}) do
				if call(cmdName, msg, manager, command, name) then return end
			end
		end
	end

	reply(msg, manager, 'Cannot find "%c" command', {
		index = "_replyToUndefinedCommands",
		c = cmdName
	})
end
