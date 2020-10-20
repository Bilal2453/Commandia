return function(v)
	v = tostring((v or ' ')):lower()
	local trueWords = {
		t = true,
		y = true,
		on = true,
		yes = true,
		['1'] = true
	}
	return (trueWords[v] or v:match('^%s*$')) and true or false
end
