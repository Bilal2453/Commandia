return function(v, msg)
	local guildID, channelID, messageIDLink = v:match('https?://discord[app]*%.com/channels/(%d+)/(%d+)/(%d+)')
	local messageID = v:match('%d+')

	local id = messageIDLink or messageID
	if not isSnowflake(id) then return end

	local guild = msg.guild
	local c = msg.channel

	if channelID ~= c.id or guild.id ~= guildID then
		if isSnowflake(channelID) then
			c = msg.client:getChannel(channelID)
		end

		if not c then return end
	end

	return id and c:getMessage(id)
end