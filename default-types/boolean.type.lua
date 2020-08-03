return function(v)
	v = tostring((v or ' ')):lower()
	return (v == '1' or v == 'on' or v:match('^%s*$') or v:find('^t')) and true or false
end
