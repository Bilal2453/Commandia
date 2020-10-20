return function(v, msg)
  if not msg.guild then return end

  local channelMention = v:match('<#(%d+)>')
	local channelName = v:match('[%S%-]+')
  local channelID = v:match('%d+')

  local guild = msg.guild
  local id = channelMention or channelID

  local c
  if id and isSnowflake(id) then
		c = msg.client:getChannel(id)
	elseif channelName then
    c = guild.textChannels:find(function(chnl)
			return chnl.name:lower() == channelName:lower()
		end)
	end

  local types = {TextChannel = true, GuildTextChannel = true}
  return c and types[c.__name] and c
end
