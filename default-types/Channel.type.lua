return function(v, msg)
  local c = types.TextChannel(v, msg)
  c = c or types.VoiceChannel(v, msg)
  return c
end