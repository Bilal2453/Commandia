local new_fs_event = require 'uv'.new_fs_event
local pathJoin = require 'pathjoin'.pathJoin
local fs = require 'fs'

local exists, readfile, mkdir = fs.existsSync, fs.readFileSync, fs.mkdirSync
local stat, scandir = fs.statSync, fs.scandirSync

local function call(c, ...)
	if type(c) == "function" then
		return pcall(c, ...)
	end
end

local function read(p, ...)
	for _, v in ipairs{...} do
		p = pathJoin(p, v)
	end

	local data, err = readfile(p)

	if not data then
		return false, err
	end

	return data
end

local function copy(t)
	local new = {}
	for k, v in pairs(t) do
		new[k] = v
	end
	return new
end


local function watch(path, callback, events)
	events = events or {}
	local stats, oldStat = {}, stat(path)
	local isFile = oldStat.type == 'file'
	local function rPath(p, n) return isFile and p or pathJoin(p, n) end

	if isFile then
		stats[path] = oldStat
	else
		local joined
		for name in scandir(path) do
			joined = pathJoin(path, name)
			stats[joined] = stat(joined)
		end
	end

	local fsEvent = new_fs_event()
	fsEvent:start(path, {}, function(err, name, event)
		if err then return end
		local filePath = rPath(path, name)

		if not event.change then
			local newName = not events.patt and filePath or filePath:match(events.patt)

			if not exists(filePath) and stats[filePath] then -- File Deleted?
				stats[filePath] = nil -- Remove old stats
				if newName then call(events.onDeleted, newName, name) end
			else -- File Created?
				stats[filePath] = stat(filePath) -- Add the new stats
				if newName then call(events.onCreated, newName, name) end
			end

			return
		end

		local old = stats[filePath]
		local new = stat(filePath)

		if new.size ~= 0 and (old.mtime.sec ~= new.mtime.sec or old.mtime.nsec ~= new.mtime.nsec) then
			stats[filePath] = new
			return callback(name)
		end
	end)

	return fsEvent
end

local function loadDir(direc, loadingPatt, env, events)
	events = events or {}
	events.doWatch = events.doWatch == nil and true or events.doWatch

	if not exists(direc) then assert(mkdir(direc)) end

	local envCopy = copy(env)
	local function loadFile(name, first)
		local filePath = pathJoin(direc, name)
		local oName = name
		name = name:match(loadingPatt)

		if not exists(filePath) then
			call(events.onErr, name, ('Attempt to find "%s"'):format(name))
			return
		end

		call(events.onUnload, name)

		local chunkString, errReading = read(filePath)
		if not chunkString then
			call(events.onErr, name, ('Attempt to read "%s" : %s'):format(filePath, errReading))
			return
		end

		-- Refresh the env with a copy of the original one
		-- The original copy does not have the user-defined globals & user-defined env
		-- This is useful to erase user-defined env on reload, so in case the user
		-- removed a global then reloaded, this code will make sure it is actually removed
		if not first then
			for k, _ in pairs(env) do
				env[k] = envCopy[k]
			end
		end

		local runtimeSuccess, loader, errMesg = call(load, chunkString, oName, 't', env)
		if runtimeSuccess then call(events.onBeforeload, name, loader) end
		local succ, result = call(loader)

		runtimeSuccess = runtimeSuccess and loader
		if not (runtimeSuccess and succ) then
			local msg = (runtimeSuccess and result or loader or errMesg)
			call(events.onErr, name, msg); return
		end

		local _, r = call(events.onLoad, name, result, loader)
		if r == false then return end -- a loading error, don't continue

		if not first then call(events.onReloaded, name);
		else call(events.onFirstload, name) end
	end

	local function loadAll(...)
		for path in scandir(direc) do
			if path:find(loadingPatt) then
				loadFile(path, ...)
			end
		end
	end

	loadAll(true)

	-- Watch for changes and reload
	if events.doWatch then
		events.patt = loadingPatt

		local oldOnCreated = events.onCreated
		events.onCreated = function (n, fullname)
			loadFile(fullname, true)
			if type(oldOnCreated) == 'function' then
				return oldOnCreated(n, fullname)
			end
		end

		watch(direc, function(name)
			if not name:find(loadingPatt) then return end
			if not exists(pathJoin(direc, name)) then return end

			loadFile(name)
		end, events)
	end
end


return {
	loadDir = loadDir,
	watch = watch
}
