local function classType(v)
	local t = type(v)
	return t == 'table' and v.__name or t
end

local function assertError(n, to, e, v)
	e = type(e) ~= "table" and {e} or e

	local s
	for _, value in ipairs(e) do
		if classType(v) == value then
			s = true; break
		end
	end

	if not s then
		n = n and ' #'..n or ''
		return error(('bad argument%s to "%s" (%s expected, got %s)'):format(
			n, to, table.concat(e, '|'), classType(v)))
  end

  return v
end

local function assertCmd(success, mesg, obj, reac)
	if type(success) ~= "boolean" then
		reac = obj
		obj = mesg
		mesg = success
		success = false
	end

	obj = assertError(3, 'assertCmd', {'Message','nil'}, obj) or {}
	local isMessage = obj.reply and true
	local send = isMessage and obj.reply or obj.send

	do -- Add reaction
		if not isMessage or reac then return end
		if success then
			obj:addReaction('✅')
		else
			obj:addReaction('❌')
		end
	end

	if not success then
		if isMessage then
			send(obj, mesg)
		else
			return mesg
		end
	end

	return true
end

return {
  assertError = assertError,
  assertCmd = assertCmd
}