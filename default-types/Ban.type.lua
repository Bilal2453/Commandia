return function(v, msg)
  if not msg.guild then return end

  local memberID = v:match('%d+')
  local mention = v:match('<@%!?(%d+)>')

  local id = mention or memberID
  if not isSnowflake(id) then return end

  -- using getBans to avoid http bad requests when the ban does not actually exists
  local bans = msg.guild:getBans()
  return bans:get(id)
end
