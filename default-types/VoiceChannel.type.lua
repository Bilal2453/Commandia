return function(v, msg)
  if not msg.guild then return end

  local channelMention = v:match('<#(%d+)>') -- Currently possible, but not mentionable
	local channelName = v:match('#?([%S%-]+)')
  local channelID = v:match('%d+')

  local guild = msg.guild
  local id = channelMention or channelID

  local c
  if id and isSnowflake(id) then
		c = msg.client:getChannel(id)
	elseif channelName then
    c = guild.voiceChannels:find(function(chnl)
			return chnl.name:lower() == channelName:lower()
		end)
	end

  local types = {GuildVoiceChannel = true} -- That should be all supported types? probably...
  return c and types[c.__name] and c
end
