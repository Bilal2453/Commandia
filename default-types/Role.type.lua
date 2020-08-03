return function(v, msg)
  local roleMention = v:match('<@&(%d+)>')
  local roleID = v:match('%d+')
  local name = v:match('.+')
  local id = roleMention or roleID

  if name and not id and msg.guild then
    return msg.guild.roles:find(function(r)
      return r.name:lower():find(name:lower(), 1, true)
    end)
  end

  return msg.client:getRole(id) or (msg.guild and msg.guild:getRole(id)) or nil
end
