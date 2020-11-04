local discordia = require('discordia')
local Command = require('./Command')

local pathJoin = require('pathJoin').pathJoin
local err = require('../include/utils/assertError')

local commandsHandler = require('../handlers/commandsHandler')
local messagesHandler = require('../handlers/messagesHandler')
local typesHandler = require('../handlers/typesHandler')

local concat, insert = table.concat, table.insert
local f, ids = string.format, 0

local Manager, getters, setters = discordia.class("CommandiaManager")

local OPTIONS = {
  replyToUndefinedArguments = {true, {"boolean", "string"}},
  replyToUndefinedCommands = {false, {"boolean", "string"}},
  replyToUnauthorized = {true, {"boolean", "string"}},

  replyWithReactionOnErr = {true, {"boolean", "string"}},
  replyWithMentionUser = {true, {"boolean"}},
  replyHeader = {'', {"string"}},

  respondToBots = {false, {"boolean"}},
  respondToDMs = {false, {"boolean"}},

  unregisterCommandOnErr = {false, {"boolean"}},

  commandsPath = {'./commands/', {"string"}},

  defaultTypesPath = {pathJoin(module.dir, "../default-types/"), {"string"}},
  typesPath = {'./types/', {"string"}},

  dateFormat = {'%Y-%m-%d %X', {"string"}},
  logLevel = {4, {"number"}},
  client = {nil, {"Client"}},
  prefix = {'!', {"string", "function"}},
}

-----------------------------------------------

local function argErr(name, expValues, value, level)
  local baseMsg = 'bad option "%s" for "Manager" (%s expected, got %s instead)'
  expValues = type(expValues) == "table" and concat(expValues, '|') or expValues
  error(baseMsg:format(name, expValues, type(value)), level or 5)
end

local function equal(v1, v2)
  if type(v1) == "table" then
    for i=1, #v1 do
      if v1[i] == v2 then return true end
    end
  end
  return v1 == v2
end

local function checkOptionsTypes(options)
  local t
  for k, v in pairs(options) do
    t = type(v)
    if not OPTIONS[k] then
      error(f('bad option "%s" for "Manager" (no such option)', k))
    elseif not (equal(OPTIONS[k][2], t) or t == "table" and v.__name and equal(OPTIONS[k][2], v.__name)) then
      argErr(k, OPTIONS[k][2], v)
    end
  end
end

-----------------------------------------------
--*[[ Defining Class Constructor ]]*--
-----------------------------------------------

function Manager:__init(options)
  -- Check if the first argument is a valid type
  err(1, "Manager", {"table", "Client"}, options)

  -- All options will be stored here
  local tempOptions = {}

  if options.__name == "Client" then
    options = {client = options}
  end

  -- Copy options to tempOptions and default not provided options
  for k, v in pairs(OPTIONS) do
    if options[k] ~= nil then
      tempOptions[k] = options[k]
    else
      tempOptions[k] = v[1]
    end
  end

  -- Make sure all options are valid
  checkOptionsTypes(tempOptions)

  -- Define every option as self._XXX
  -- This might be changed when Discordia 3.x comes out
  for i, v in pairs(tempOptions) do
    self['_'..i] = v
  end

  -- Store the options that are already in use by this instance
  self._options = options

  -- Define static properties
  self._discordia = discordia
  self._logger = discordia.Logger(self._logLevel, self._dateFormat)


  -- Load commands
  self._commands = {}
  commandsHandler(self)

  -- Load types
  self._types = typesHandler(self)

  -- Handle messages and respond to commands
  self._client:on("messageCreate", function(msg)
    messagesHandler(self, msg)
  end)

  -- Assign a unique ID for the current instance
  ids = ids + 1
  self._id = ids
end

-----------------------------------------------
--*[[ Defining Class Getters ]]*--
-----------------------------------------------

function getters:prefix()
  return self._prefix
end

function getters:commands()
  return self._commands
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

-----------------------------------------------
--*[[ Defining Class Setters ]]*--
-----------------------------------------------

function setters:prefix(p)
  self:setPrefix(p)
end

-- TODO: changeOption method

-----------------------------------------------
--*[[ Defining Members Methods ]]*--
-----------------------------------------------

function Manager:createCommand(name, callback, args, aliases, perms, autoReg)
  err(1, "createCommand", "CommandiaManager", self, 2)
  err(2, "createCommand", "string", name, 2)
  err(3, "createCommand", {"nil", "function"}, callback, 2)
  err(4, "createCommand", {"nil", "table"}, args, 2)
  err(5, "createCommand", {"nil", "table", "string"}, aliases, 2)
  err(6, "createCommand", {"nil", "table", "string"}, perms, 2)
  err(7, "createCommand", {"nil", "boolean"}, autoReg, 2)

  local nc = Command(self, name, callback, perms, aliases, args)
  if autoReg or autoReg == nil then self:registerCommand(nc) end

  return nc
end

function Manager:createCommands(commands)
  err(1, "createCommands", "CommandiaManager", self)
  err(2, "createCommands", "table", commands)

  for k, v in pairs(commands) do
    self:createCommand(
      type(k) == 'number' and v.name or k,
      v.callback, v.arguments, v.aliases, v.permissions
    )
  end
end

function Manager:getCommand(n)
  err(1, "getCommand", "CommandiaManager", self)
  err(2, "getCommand", "string", n)
  return self._commands[n]
end

function Manager:registerCommand(c)
  err(1, "registerCommand", "CommandiaManager", self)
  err(2, "registerCommand", "Command", c)

  if self._commands[c.name] then
    error(f('A command what the same name "%s" already exists', c.name))
  end

  self._commands[c.name] = c
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
