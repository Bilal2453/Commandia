return function (v)
	local t = type(v)
	return t == 'table' and v.__name or t
end
