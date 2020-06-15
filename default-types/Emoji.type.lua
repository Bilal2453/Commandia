return function (v, msg)
  local id = v:match('<a?:%S+:(%d+)>')
  if not isSnowflake(id) then return end

  return msg.mentionedEmojis:get(id)
end
