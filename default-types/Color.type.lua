return function(v, _, m)
  local hex = v:match('#?%x+')
  local RGB = {v:match('[rRgGbB]%s*%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)%s*')}
  local HSL = {v:match('[hHsSlL]%s*%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)%s*')}
  local HSV = {v:match('[hHsSvV]%s*%(%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*%)%s*')}
  local num = tonumber(v:match('%S+'))

  local function sc(...)
    local s = select(2, pcall(...))
    return type(s) == 'table' and s
  end

  local Color, c = m._discordia.Color

  if #RGB == 3 then
    c = sc(Color.fromRGB, RGB[1], RGB[2], RGB[3])
  elseif #HSL == 3 then
    c = sc(Color.fromHSL, HSL[1], HSL[2], HSL[3])
  elseif #HSV == 3 then
    c = sc(Color.fromHSV, HSV[1], HSV[2], HSV[3])
  elseif hex then
    c = sc(Color.fromHex, hex)
  elseif num then
    c = sc(Color, num)
  else
    return
  end

  return c and c or nil
end
