return function(v, msg)
  local snowflake = v:match('%d+')
  local name = v:match('.+')

  if snowflake and isSnowflake(snowflake) then
    return msg.client:getGuild(snowflake)
  elseif #name >= 2 and #name <= 100 then -- > 1 && < 101 is the guild's name limit
    return msg.client.guilds:find(function(g)
      return g.name:lower():find(name:lower(), 1, true)
    end)
  end
end
