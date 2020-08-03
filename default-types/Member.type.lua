return function(v, msg)
	local mention = v:match('<@%!?(%d+)>')
	local memberID = v:match('%d+')

	local id = mention or memberID
	if not isSnowflake(id) then return end

	-- TODO: Search for names instead of just using IDs
	return msg.guild and msg.guild:getMember(id)
end
