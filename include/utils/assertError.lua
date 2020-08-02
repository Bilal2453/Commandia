local ct = require './classType'

return function (nth, to, expected, value, level)
	expected = type(expected) ~= "table" and {expected} or expected

	local s
	for _, v in ipairs(expected) do
		if ct(value) == v then
			s = true; break
		end
	end

	if not s then
		nth = nth and ' #'..nth or ''
		return error(('bad argument%s to "%s" (%s expected, got %s)'):format(
			nth, to, table.concat(expected, '|'), ct(value)
		), level)
  end

  return value
end
