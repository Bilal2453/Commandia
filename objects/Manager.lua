local discordia = require 'discordia'
local pathJoin = require 'pathjoin'.pathJoin
local Command = require './Command'
local err = require '../include/utils/assertError'

local commandsHandler = require '../handlers/commandsHandler'
local messagesHandler = require '../handlers/messagesHandler'
local typesHandler = require '../handlers/typesHandler'

local class, ids = discordia.class, 0
local Manager, getters, setters = class("CommandiaManager")

local concat, insert = table.concat, table.insert
local f = string.format


local OPTIONS_TYPES = {
  replyToUndefinedArguments = {"boolean", "string"},
  replyToUndefinedCommands = {"boolean", "string"},
  replyToUnauthorized = {"boolean", "string"},

  replyWithReactionOnErr = {"boolean", "string"},
  replyWithMentionUser = "boolean",
  replyHeader = "string",

  respondToBots = "boolean",
  respondToDMs = "boolean",

  unregisterCommandOnErr = "boolean",

  commandsPath = "string",

  defaultTypesPath = "string",
  typesPath = "string",

  dateFormat = "string",
  logLevel = "number",
  client = "Client",
  prefix = {"string", "function"},
}

local OPTIONS_VALUES = {
  replyToUndefinedArguments = true,
  replyToUndefinedCommands = false,
  replyToUnauthorized = true,

  replyWithReactionOnErr = true,
  replyWithMentionUser = true,
  replyHeader = '',

  respondToBots = false,
  respondToDMs = false,

  unregisterCommandOnErr = false,

  commandsPath = "./commands/",

  defaultTypesPath = pathJoin(module.dir, "../default-types/"),
  typesPath = "./types/",

  dateFormat = '%Y-%m-%d %X',
  logLevel = 4,
  client = "NONE", -- NONE = no-defualt = required
  prefix = '!',
}

local argErr = function(name, dvalue, value, bs, l)
  local baseMsg = 'bad option "%s" for "Manager" (%s expected, got %s instead)'
  dvalue = type(dvalue) == 'table' and concat(dvalue, '|') or dvalue

  error(f(bs or baseMsg, name, dvalue, type(value)), l or 5)
end

local optionEqual = function(v1, v2)
  if type(v1) == 'table' then
    for _, v in pairs(v1) do
      if v == v2 then return true end
    end
  else
    return v1 == v2
  end
end

local checkOptionsTypes = function(o)
  local od, t, eqs = OPTIONS_TYPES

  for i, v in pairs(o) do
    t = type(v)
    if v == 'NONE' then t, v = nil end

    eqs = optionEqual(od[i], t)

    if od[i] and (not eqs and t ~= 'table' or t == 'table' and od[i] ~= v.__name) then
      argErr(i, od[i], v)
    end
  end
end

--*[[ Defining Class Constructor ]]

function Manager:__init(options)
  -- Check if the first argument's type is valid
  err(1, "Manager", {"table", "Client"}, options)

  local o = {} -- All valid options will be temp stored here

  -- Allow an optional type for the first argument
  -- (Client or table)
  if options.__name == "Client" then
    options = {client = options}
  end

  -- Make sure that all options are known
  for i, v in pairs(options) do
    if not OPTIONS_TYPES[i] then
      argErr(i, "nil", v, nil, 4)
    end
  end

  -- Assign the default value for an optional option when no value
  for i, v in pairs(OPTIONS_VALUES) do
    if options[i] ~= nil then o[i] = options[i];
    else o[i] = v end
  end

  -- Make sure all options are valid
  checkOptionsTypes(o)

  -- Define every option as self._XXX
  -- This might be changed when Discordia 3.x comes out
  for i, v in pairs(o) do
    self['_'..i] = v
  end

  -- Store the options that are already in use by this instance
  self._options = o

  -- Define static options
  self._discordia = discordia
  self._logger = discordia.Logger(self._logLevel, self._dateFormat)

  -- Handle and load commands
  self._commands = {}
  commandsHandler(self)

  -- Handle and load types
  self._types = typesHandler(self)

  -- Handle messages and respond to commands
  self._client:on("messageCreate", function(msg)
    messagesHandler(self, msg)
  end)

  -- Assign a unique ID for the current instance
  ids = ids + 1
  self._id = ids
end

--*[[ Defining Class Getters ]]

function getters:prefix()
  return self._prefix
end

function getters:commands()
  return self._commands or {}
end

function getters:commandsNames()
  local names = {}
  for _, v in pairs(self._commands) do
    insert(names, v.name)
  end
  return names
end

function getters:client()
  return self._client
end

function getters:id()
  return self._id
end

function getters:options()
  return self._options
end

--*[[ Defining Class Setters ]]

function setters:prefix(p)
  self:setPrefix(p)
end

-- TODO: changeOption method

--*[[ Defining Members Methods ]]

function Manager:createCommand(name, callback, perms, aliases, args, autoreg)
  err(1, "createCommand", "CommandiaManager", self, 2)
  err(2, "createCommand", "string", name, 2)
  err(3, "createCommand", {"nil", "function"}, callback, 2)
  err(4, "createCommand", {"nil", "table", "string"}, perms, 2)
  err(5, "createCommand", {"nil", "table", "string"}, aliases, 2)
  err(6, "createCommand", {"nil", "table"}, args, 2)
  err(7, "createCommand", {"nil", "boolean"}, autoreg, 2)

  local nc = Command(self, name, callback, perms, aliases, args)
  if autoreg or autoreg == nil then self:registerCommand(nc) end

  return nc
end

function Manager:createCommands(cmds)
  err(1, "createCommands", "CommandiaManager", self)
  err(2, "createCommands", "table", cmds)

  for i, v in pairs(cmds) do
    self:createCommand(type(i) == 'number' and v.name or i,
      v.callback, v.permissions, v.aliases, v.arguments
    )
  end
end

function Manager:getCommand(n)
  err(1, "getCommand", "CommandiaManager", self)
  err(2, "getCommand", "string", n)

  return self._commands[n]
end

function Manager:registerCommand(c, n)
  err(1, "registerCommand", "CommandiaManager", self)
  err(2, "registerCommand", "Command", c)

  local pd = self._commands[n or c.name]
  if pd and pd._id ~= c._id and pd.name == c.name then
    error(f(
      'Cannot register a new command when there\'s an already registered command with the same name "%s"',
      n or c.name
    ))
  end

  self._commands[n or c.name] = c
end

function Manager:unregisterCommand(n)
  err(1, "unregisterCommand", "CommandiaManager", self)
  err(2, "unregisterCommand", {"string", "table"}, n)
  n = type(n) ~= 'table' and {n} or n

  for _, v in ipairs(n) do
    if type(v) == 'table' and v.__name == 'Command' then
      self._commands[v.name] = nil
    else
      self._commands[n] = nil
    end
  end
end

function Manager:setPrefix(p)
  err(1, "setPrefix", "CommandiaManager", self)
  err(2, "setPrefix", {"string", "function"}, p)

  self._prefix = p
end

return Manager
