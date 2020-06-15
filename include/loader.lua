local new_fs_event = require 'uv'.new_fs_event
local pathJoin = require 'pathjoin'.pathJoin
local fs = require 'fs'

local stat, exists, scandir, readfile, mkdir = fs.statSync, fs.existsSync, fs.scandirSync, fs.readFileSync, fs.mkdirSync
local module = {}

local function call(c, ...)
	if type(c) == "function" then
		return pcall(c, ...)
	end
end

local function read(p, ...)
	for _, v in ipairs{...} do
		p = pathJoin(p, v)
	end

	local fileData, errmsg = readfile(p)

	if not fileData then
		return false, errmsg
	end

	return fileData
end


local function watch(path, callback)
	local stats = {}
	local oldStat = stat(path)
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

		if not event.change then
			local newPath = rPath(path, name)

			if not exists(newPath) then -- File Deleted?
				stats[newPath] = nil -- Remove old stats
			else -- File Created?
				stats[newPath] = stat(newPath) -- Add the new stats
			end

			return
		end

		local filePath = rPath(path, name)
		local old = stats[filePath]
		local new = stat(filePath)

		stats[filePath] = new

		if new.size ~= 0 and (old.mtime.sec ~= new.mtime.sec or old.mtime.nsec ~= new.mtime.nsec) then
			return callback(name)
		end
	end)

	return fsEvent
end

-- TODO: Better and Cleaner loader... this one is just ugly and buggy.
local function loadDirec(direc, filesPattern, env, ops)
	ops = ops or {}
	local onReloaded = ops.onReloaded
	local onUnload = ops.onUnload
	local doWatch = ops.doWatch == nil and true or ops.doWatch
	local onLoad = ops.onLoad
	local onErr = ops.onErr

	if not exists(direc) then mkdir(direc) end

	local function loadFile(name, first)
		local filePath = pathJoin(direc, name)

		local oName = name
		name = name:gsub(filesPattern, '')

		if not exists(filePath) then
			call(onErr, name, ('Attempt to find "%s"'):format(name))
			return
		end

		call(onUnload, name)

		local succ, result = read(filePath)
		if not succ then
			call(onErr, name, ('Attempt to read "%s" : %s'):format(filePath, result))
			return
		end

		local runtimeSuccess, loader, errMesg = call(load, succ, oName, 't', env)
		succ, result = call(loader)

		runtimeSuccess = runtimeSuccess and loader
		if not (runtimeSuccess and succ) then
			local msg = (runtimeSuccess and result or loader or errMesg)
			call(onErr, name, msg); return
		end

		call(onLoad, name, result)
		if not first then call(onReloaded, name) end
	end

	local function loadAll(...)
		for filePath in scandir(direc) do
			if filePath:find(filesPattern) then
				loadFile(filePath, ...)
			end
		end
	end

	loadAll(true)

	-- Watch for changes and reload
	if doWatch then
		watch(direc, function(name)
			if not name:find(filesPattern) then return end
			if not exists(pathJoin(direc, name)) then return end

			loadFile(name)
		end)
	end
end


module.loadDirec = loadDirec
module.watch = watch

return module
