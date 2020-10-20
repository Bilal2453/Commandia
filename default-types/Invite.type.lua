return function(v, msg)
  local plain = v:match('[a-zA-Z0-9]+')
  local short = v:match('discord%.gg/([a-zA-Z0-9]+)')
  local long  = v:match('https?://discord%.gg/([a-zA-Z0-9]+)')
  local code  = plain or long or short

  return msg.client:getInvite(code)
end
