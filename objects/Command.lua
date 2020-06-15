local discordia = require 'discordia'
local err = require '../include/utils'.assertError
local ids = 0

local function get(self, property, index)
	local values = {}
	for k, v in pairs(self[property] or {}) do
		if v then
			table.insert(values, k)
		end
	end
	return index and values[index] or values
end

local function set(self, property, index, invert, disable)
	self[property] = self[property] or {}
	self = self[property]

	local function exp(a, b, c)
		if a then return b else return c end
	end

	disable = exp(disable, false, nil)
	invert = invert and true or false

	local value = not invert and true or disable
	disable = value == disable and true or disable

	if type(index) == "string" then
		self[index] = value
	elseif type(index) == "table" then
		for k, v in pairs(index) do
			if type(k) == "number" then
				self[v] = value
			else
				self[k] = exp(v, value, disable)
			end
		end
	end
end

-- if the object is already defined just return the defined one
local definedCommand = discordia.class.classes.Command
if definedCommand then return definedCommand end

local Command, getters, setters = discordia.class("Command")

--*[[ Defining Class Constructor ]]

function Command:__init(manager, name, callback, perms, aliases, args)
	self.permissions = perms or {}
	self.arguments = args or {}
  self._manager = err(1, "Command", "CommandsManager", manager)
	self.callback = callback or function() end
	self.aliases = aliases or {}
	self.name = err(2, "Command", "string", name)

	ids = ids + 1
	self._id = ids
end

--*[[ Defining Class Setters ]]

function setters:name(n)
	self:setName(n)
end

function setters:arguments(v)
	self:setArguments(v or {})
end

function setters:aliases(v)
	self:setAliases(v or {})
end

function setters:permissions(v)
	self:setPermissions(v or {})
end

function setters:callback(v)
	self:setCallback(v or function() end)
end

--*[[ Defining Class Getters ]]

function getters:name()
	return self._name
end

function getters:arguments()
	return self._arguments
end

function getters:aliases(i)
	return get(self, '_aliases', i)
end

function getters:permissions(i)
	return get(self, '_permissions', i)
end

function getters:callback()
	return self._callback
end

--*[[ Defining Members Methods ]]

function Command:setName(n)
	local reged = self._manager._commands[self._name]

	if reged then self:unregister() end
	self._name = err(1, "setName", "string", n)
	if reged then self:register() end

  return self
end

-- TODO: Simplify this method as much as possible and needed. it's silly!!
function Command:setArguments(name, argType, shortflag, fullflag, eatArgs, optional, output)
	self._arguments = self._arguments or {}

	name = err(2, "setArguments", {"string", "table"}, name)

	local function setArgs(args)
		shortflag = args.shortflag
		fullflag = args.fullflag
		optional = args.optional
		eatArgs = args.eatArgs
		argType = args.type
		output = args.output
		name = args.name or ""
	end

	if type(name) == "table" then
		for argName, arg in pairs(name) do
			if type(argName) == "number" then
				self:setArguments(arg)
			elseif type(argName) == "string" and type(arg) == "table" then
				arg.name = arg.name or argName
				self:setArguments(arg)
			elseif type(argName) == "string" and type(arg) ~= "table" then
				setArgs(name)
				break
			end
		end
	end

	if argType == false then
		self._arguments[name] = nil; return self
	end

	self._arguments[name] = {
		name = name,
		type = argType,

		shortflag = shortflag,
		fullflag = fullflag,

		eatArgs = eatArgs,
		optional = optional,

		output = output,
  }

  return self
end

-- TODO: removeArguments

function Command:setAliases(a)
	set(self, '_aliases', a)
  return self
end

function Command:removeAliases(a)
	set(self, '_aliases', a, true)
  return self
end

function Command:setPermissions(p)
  set(self, '_permissions', p, false, true)
  return self
end

function Command:removePermissions(p)
	set(self, '_permissions', p, true)
  return self
end

function Command:setCallback(c)
  self._callback = err(1, "setCallback", "function", c)
  return self
end

function Command:register()
  self._manager:registerCommand(self)
end

function Command:unregister()
  self._manager:unregisterCommand(self)
end

function Command:hasPermissions(member, channel)
	err(1, "hasPermissions", {"Message", "Member"}, member)
	channel = member.channel or channel
	member = member.member or member
	err(2, "hasPermissions", {"GuildTextChannel", "PrivateChannel"}, channel)

	-- Is it a PrivateChannel?
	if not member or not member.guild then return true end

	local enums = discordia.enums.permission
	local isEnum = function (e)
		for i, _ in pairs(enums) do
			if i == e then return true end
		end
	end

	local commandsPerms = self._permissions
	local memberPerms = member:getPermissions(channel)
	-- TODO: Allow to the user to tinker with the customized perms + add their own
	local specialPerms = {
		["guildOwner"] = channel.guild.owner.id == member.id,
		["botOwner"] = self._manager._client.owner.id == member.id,
	}

	-- This will allow to the owner(s) of the bot to bypass all command's perms
	-- If you don't want this to happen (idk why would you tho) just comment the following line
	-- TODO: make disabling this available as an option while initing manager
	if specialPerms.botOwner then return true end

	local function isValid(hasPerm, value)
		return not hasPerm == not value
	end

	-- Checking command's perms against member's
	-- Check if the member does have official discord permissions (if any)
	for perm, v in pairs(commandsPerms) do
		if isEnum(perm) and not isValid(memberPerms:has(perm), v) then
			return false
		end
	end

	-- Check if the member does have the customized permissions (if any)
	for perm, v in pairs(specialPerms) do
		if commandsPerms[perm] ~= nil and not isValid(v, commandsPerms[perm]) then
			return false
		end
	end

	return true
end

return Command
