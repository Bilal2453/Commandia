return function(v, msg)
  local plain = v:match('[a-zA-Z0-9]+')
  local surl = v:match('discord%.gg/([a-zA-Z0-9]+)')
  local furl = v:match('https?://discord%.gg/([a-zA-Z0-9]+)')
  local code = plain or furl or surl

  return msg.client:getInvite(code)
end