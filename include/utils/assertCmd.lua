local ae = require './assertError'

return function (success, mesg, obj, reac)
	if type(success) ~= "boolean" then
		reac = obj
		obj = mesg
		mesg = success
		success = false
	end

	obj = ae(3, 'assertCmd', {'Message','nil'}, obj) or {}
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
