local lpeg = require('lpeg')
local P, C, S, R, Ct = lpeg.P, lpeg.C, lpeg.S, lpeg.R, lpeg.Ct

local ERRORS = {
  NO_SUCH_CATEGORY  = {'No such category "%s" for %s "%s', -1},
  CATEGORY_REQUIRED = {'Category is required for %s "%s"', -2},

  COMMAND_NOT_FOUND = {'Command "%s" not found', -3},

  NO_SUCH_FLAG           = {'No such flag "%s" for %s "%s"', -4},
  FLAG_REQUIRED          = {'The positioned argument #%d requires %d values, got only %d value(s)', -5},
  FLAG_VALUES_NOT_ENOUGH = {'Not enough values for flag "%s" of %s "%s"', -6},

  UNKNOWN_ARGUMENT           = {'Unknown positioned argument "%s" for %s "%s" accepts #%d argument(s), got %d argument', -7},
  ARGUMENT_REQUIRED          = {'The positioned argument #%d is required for %s "%s"', -8},
  ARGUMENT_NOT_FOUND         = {'Attempt to find positioned argument #%d:"%s"', -9},
  ARGUMENT_VALUES_NOT_ENOUGH = {'The positioned argument #%d requires %d values, got only %d value(s)', -10},
}

local lexer
do
  local sep, space = S'=, ', P' '^0
  local prefix = space * P'!'
  local letter = R 'az' + R 'AZ'
  local validName = (letter^1 * (S'_-' + R'09')^0)^1

  local longFlag = C(P'--') * C(validName)
  local shortFlag = C(P'-') * C(letter)

  local arg = C((1 - (sep + '-'))^1)
  local apoArg = P"'" * C((1 - P"'")^0) * P"'"
  local quoArg = P'"' * C((1 - P'"')^0) * P'"'

  local args = ((quoArg + apoArg + arg) * sep^0)^1

  local function flagNode(pattern)
    return pattern / function(flagDash, flagName)
      return {#flagDash == 2 and true or false, flagName}
    end
  end

  local flag = Ct(flagNode(longFlag + shortFlag) * (sep * args^0)^0)

  local function node(pattern)
    return pattern / function(prefix, name, ...)
      return {
        prefix = prefix,
        command = name,
        ...
      }
    end
  end

  lexer = node(C(prefix) * C(validName) * space * (flag + Ct(args))^0)
end

-----------------------------------------------------

local function merge(t1, t2)
  -- NOTE: Originally used table.move to merge tables, now using this instead,
  -- because table.move is too verbose for just simple table merging.
  for i=1, #t2 do
    t1[#t1+1] = t2[i]
  end
end

local function err(index, ...)
  index = ERRORS[index]
  if not index then return false, 'UNKNOWN ERROR : '.. index, 0 end

  return false, index[1]:format(...), index[2]
end

local function findFlag(command, flag)
  local flags, index = command.flags, flag[1] and 'longFlags' or 'shortFlags'
  for i=1, #flags do
    if flags[i][index][flag[2]] then
      return flags[i]
    end
  end
end

local function reShift(t, size)
  local shifted, i = 0, 1
  while shifted < size do
    if t[i] ~= nil then
      t[shifted+1], t[i] = t[i], nil
      shifted = shifted + 1
    end
    i = i + 1
  end
end

local function consume(amount, part, d, size, i)
  local consumed = {}
  i, d, size = i or 1, d or 0, size or #part

  -- NOTE: Not using table.remove since it will shift the table many avoidable times
  -- manually re-shifting when consuming is done.
  while #consumed < amount and size > 0 do
    consumed[i-d], part[i] = part[i], nil
    i, size = i+1, size-1
  end

  -- Re-shifting the results, removing any holes
  reShift(part, size)

  return consumed
end

local function buildHandlers(tokens, command, parsed)
  local cmdTerm =  tokens._category and 'category' or 'command'

  local function handleCategory()
    local firstArgument = (tokens[1] or {})[1]
    local cat = firstArgument and command.categories[firstArgument]

    if not (cat or type(cat) ~= 'string' or command.categories.optional) then
      if firstArgument then
        return err('NO_SUCH_CATEGORY', firstArgument, cmdTerm, command.name)
      else
        return err('CATEGORY_REQUIRED', cmdTerm, command.name)
      end
    elseif cat then
      parsed.category = cat.name
      table.remove(tokens[1], 1)
    end

    return true
  end

  local function handleFlag(part, flagPart)
    local flag = findFlag(command, flagPart)
    if not flag then
      return err('NO_SUCH_FLAG', flagPart[2], cmdTerm, command.name)
    end

    local partSize = #part-1
    part[1] = nil

    if partSize < flag.requires then
      local a ,b , c = err('FLAG_VALUES_NOT_ENOUGH', flag.name, cmdTerm, command.name)
      p(1, a, b, c)
      return a, b ,c
    end

    local consumed = consume(flag.consumes, part, 1, partSize, 2)

    if not parsed.flags then parsed.flags = {n = 0} end
    parsed.flags[flag.name] = #consumed > 1 and consumed or consumed[1]
    parsed.flags.n = parsed.flags.n + 1

    return true
  end

  local function handleArgument(part)
    local argIndex = parsed.arguments.n + 1

    if argIndex > #command.arguments then
      return err('UNKNOWN_ARGUMENT', part[1], command.name, #command.arguments, argIndex)
    end

    -- Incase the last argument did not consume all the needed values (a flag in between for example)
    -- this should be treated as a value for that argument not as an argument.
    -- We know when this happens when the last argument can still accept more values.
    do
      local lastArgOrg = command.arguments[argIndex-1]
      local lastArg = parsed.arguments[(lastArgOrg or {}).name or '']

      if lastArg and #lastArg < lastArgOrg.consumes then
        local r = consume(lastArgOrg.consumes - #lastArg, part)
        merge(lastArg, r)
        return true
      end
    end

    local arg = command.arguments[argIndex]
    if not arg then -- should never happen
      return err('ARGUMENT_NOT_FOUND', argIndex, part[1])
    end

    local parsedArg = parsed.arguments[arg.name]
    local partSize, argValue = #part-1, part[1]
    part[1] = nil

    if not parsedArg then
      parsedArg = {argValue}
      parsed.arguments[arg.name] = parsedArg
      parsed.arguments.n = parsed.arguments.n + 1
    else
      table.insert(parsedArg, argValue)
    end

    if #parsedArg < arg.consumes then
      local consumed = consume(arg.consumes - #parsedArg, part, 1, partSize, 2)
      merge(parsedArg, consumed)
    end

    return true
  end

  return handleCategory, handleFlag, handleArgument
end

-----------------------------------------------------
-- TODO: Clean grammar mess, might use `re` instead?
-- TODO: Converting inputs (args, flags) into their user-defined types.
-- TODO: Inherited flag start, such as `-xyz value` where each letter represents a different flag all sharing same value.
-- TODO: Unlimited consuming inputs, till the next input is confirmed.
-- TODO: Customized prefix, accepting either a function or string from the user.

local function parse(str, commands)
  local tokens = type(str) == 'string' and lexer:match(str) or str
  if type(tokens) ~= 'table' then return nil end

  local command = commands[tokens.command]
  if not command then return err('COMMAND_NOT_FOUND', tokens.command) end

  -- The final output of the parser
  local parsed = {
    arguments = {n = 0},
    category = tokens._category,
    flags = {n = 0},
  }

  -- Build the actual parsing handlers
  local handleCategory, handleFlag, handleArgument = buildHandlers(tokens, command, parsed)

  -- Handle categories and possible errors
  local success, msg, errCode = handleCategory()
  if not success then return false, msg, errCode end

  -- Parse the category as a separate command allowing for recursion
  if parsed.category and not tokens._category then
    local cat = command.categories[parsed.category]
    tokens.command = cat.name
    tokens._category = cat.name

    return parse(tokens, {
      [cat.name] = cat
    })
  end

  local cmdTerm =  tokens._category and 'category' or 'command'
  local part, av

  -- Main consuming loop
  for pi = 1, #tokens do
    part = tokens[pi]

    for _ = 1, #part do
      av = part[1]

      -- Ignore any holes
      if av == nil then goto continue end

      -- Consume the value and handle possible errors
      if type(av) == 'table' then -- it is a flag
        success, msg, errCode = handleFlag(part, av)
      else -- it is an argument or an argument's value
        success, msg, errCode = handleArgument(part)
      end
      if not success then return false, msg, errCode end

      ::continue::
    end
  end

  -- Check if all required flags are provided
  local flags = command.flags
  for i=1, #flags do
    if flags[i].required and not parsed.flags[flags[i].name] then
      return err('FLAG_REQUIRED', flags[i].name, cmdTerm, command.name)
    end
  end

  --  Check if all required arguments and their required values are provided
  local arguments, ai = command.arguments
  for i=1, #arguments do
    ai = arguments[i]

    if ai.required and not parsed.arguments[ai.name] then
      return err('ARGUMENT_REQUIRED', i, cmdTerm, command.name)
    elseif ai.required and #parsed.arguments[ai.name] < ai.requires then
      return err('ARGUMENT_VALUES_NOT_ENOUGH', i, ai.requires, #parsed.arguments[ai.name])
    end
  end

  return parsed, command
end

return parse
