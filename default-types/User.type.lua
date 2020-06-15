return function(v, msg)
	local mention = v:match('<@%!?(%d+)>')
	local userID = v:match('%d+')

	local id = mention or userID
	if not isSnowflake(id) then return end

	return msg.client:getUser(id)
end