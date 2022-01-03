if hook.GetULibTable then return end	-- Prevent autorefresh reloading this file

local gmod			= gmod
local pairs			= pairs
local isfunction	= isfunction
local isstring		= isstring
local isnumber		= isnumber
local math			= math
local IsValid		= IsValid
local setmetatable = setmetatable
local insert = table.insert
--[[
local concommand = concommand
local print = print
local PrintTable = PrintTable
local tostring = tostring
local assert = assert
local table = table--]]

do
	_G.HOOK_MONITOR_HIGH = -2
	_G.HOOK_HIGH = -1
	_G.HOOK_NORMAL = 0
	_G.HOOK_LOW = 1
	_G.HOOK_MONITOR_LOW = 2
end

HOOK_MONITOR_HIGH = -2
HOOK_HIGH = -1
HOOK_NORMAL = 0
HOOK_LOW = 1
HOOK_MONITOR_LOW = 2


local HOOK_MONITOR_HIGH = HOOK_MONITOR_HIGH
local HOOK_HIGH = HOOK_HIGH
local HOOK_NORMAL = HOOK_NORMAL
local HOOK_LOW = HOOK_LOW
local HOOK_MONITOR_LOW = HOOK_MONITOR_LOW


-- Grab all previous hooks from the pre-existing hook module.
local OldHooks = hook.GetTable()

module( "hook" )

local Hooks = {}
local BackwardsHooks = {} -- A table fully to garry's spec for aVoN

--
-- For access to the Hooks table.. for some reason.
--
function GetTable() return BackwardsHooks end
function GetULibTable() return Hooks end

-- Replaced with Srlions hook library. https://github.com/Srlion/Hook-Library


local events = {}

local function find_hook(event, name)
	for i = 1, event.n, 4 do
		local _name = event[i]
		if _name and _name == name then
			return i
		end
	end
end

--[[
	we are making a new event table so we don't mess up anything
	when adding/removing hooks while hook.Call is running, this is how it works:
	1- When (adding/removing a hook)/(editing a hook priority), we create a new event table to avoid messing up hook.Call call order if it's running,
	and the old event table will be shadowed and can only be accessed from hook.Call if it's running
	2- We make old event table have __index method to make sure if any hook got removed/edited we (stop it from running)/(run the new function)
]]
local function copy_event(event, event_name)
	local new_event = {}
	do
		for i = 1, event.n do
			local v = event[i]
			if v then
				insert(new_event, v)
			end
		end
		new_event.n = #new_event
	end

	-- we use proxies here just to make __index work
	-- https://stackoverflow.com/a/3122136
	local proxy = {}
	do
		for i = 1, event.n do
			proxy[i] = event[i]
			event[i] = nil
		end
		proxy.n = event.n
		event.n = nil
	end

	setmetatable(event, {
		__index = function(_, key)
			-- make event.n work
			if isstring(key) then
				return proxy[key]
			end

			local name = proxy[key - 1]
			if not name then return end

			local parent = events[event_name]

			-- if hook got removed then don't run it
			local pos = find_hook(parent, name)
			if not pos then return end

			-- if hook priority changed then it should be treated as a new hook, don't run it
			if parent[pos + 3 --[[priority]]] ~= proxy[key + 2 --[[priority]]] then return end

			return parent[pos + 1]
		end
	})

	return new_event
end

--[[---------------------------------------------------------
	Name: Add
	Args: string hookName, any identifier, function func
	Desc: Add a hook to listen to the specified event.
-----------------------------------------------------------]]
function Add(event_name, name, func, priority)
	if not isstring(event_name) then return end
	if not isfunction(func) then return end
	if not name then return end

	local real_func = func
	if not isstring(name) then
		func = function(...)
			local isvalid = name.IsValid
			if isvalid and isvalid(name) then
				return real_func(name, ...)
			end

			Remove(event_name, name)
		end
	end

	if not isnumber(priority) then
		priority = HOOK_NORMAL
	elseif priority < HOOK_MONITOR_HIGH then
		priority = HOOK_MONITOR_HIGH
	elseif priority > HOOK_MONITOR_LOW then
		priority = HOOK_MONITOR_LOW
	end

	-- disallow returning in monitor hooks
	if priority == HOOK_MONITOR_HIGH or priority == HOOK_MONITOR_LOW then
		local _func = func
		func = function(...)
			_func(...)
		end
	end

	local event = events[event_name]
	if not event then
		event = {
			n = 0,
		}
		events[event_name] = event
	end

	local pos
	if event then
		local _pos = find_hook(event, name)
		-- if hook exists and priority changed then remove the old one because it has to be treated as a new hook
		if _pos and event[_pos + 3] ~= priority then
			Remove(event_name, name)
		else
			-- just update the hook here because nothing changed but the function
			pos = _pos
		end
	end

	event = events[event_name]

	if pos then
		event[pos + 1] = func
		event[pos + 2] = real_func
		return
	end

	if priority == HOOK_MONITOR_LOW then
		local n = event.n
		event[n + 1] = name
		event[n + 2] = func
		event[n + 3] = real_func
		event[n + 4] = priority
	else
		local event_pos = 4
		for i = 4, event.n, 4 do
			local _priority = event[i]
			if priority < _priority then
				if i < event_pos then
					event_pos = i
				end
			elseif priority >= _priority then
				event_pos = i + 4
			end
		end
		insert(event, event_pos - 3, name)
		insert(event, event_pos - 2, func)
		insert(event, event_pos - 1, real_func)
		insert(event, event_pos, priority)
	end

	event.n = event.n + 4
end

--[[---------------------------------------------------------
	Name: Remove
	Args: string hookName, identifier
	Desc: Removes the hook with the given indentifier.
-----------------------------------------------------------]]
function Remove(event_name, name)
	local event = events[event_name]
	if not event then return end

	local pos = find_hook(event, name)
	if pos then
		event[pos] = nil --[[name]]
		event[pos + 1] = nil --[[func]]
		event[pos + 2] = nil --[[real_func]]
		event[pos + 3] = nil --[[priority]]
	end

	events[event_name] = copy_event(event, event_name)
end

--[[---------------------------------------------------------
	Name: GetTable
	Desc: Returns a table of all hooks.
-----------------------------------------------------------]]
function GetTable()
	local new_events = {}

	for event_name, event in pairs(events) do
		local hooks = {}
		for i = 1, event.n, 4 do
			local name = event[i]
			if name then
				hooks[name] = event[i + 2] --[[real_func]]
			end
		end
		new_events[event_name] = hooks
	end

	return new_events
end

--[[---------------------------------------------------------
	Name: Call
	Args: string hookName, table gamemodeTable, vararg args
	Desc: Calls hooks associated with the hook name.
-----------------------------------------------------------]]
function Call(event_name, gm, ...)
	local event = events[event_name]
	if event then
		local i, n = 2, event.n
		::loop::
		local func = event[i]
		if func then
			local a, b, c, d, e, f = func(...)
			if a ~= nil then
				return a, b, c, d, e, f
			end
		end
		i = i + 4
		if i <= n then
			goto loop
		end
	end

	--
	-- Call the gamemode function
	--
	if not gm then return end

	local GamemodeFunction = gm[event_name]
	if not GamemodeFunction then return end

	return GamemodeFunction(gm, ...)
end

--[[---------------------------------------------------------
	Name: Run
	Args: string hookName, vararg args
	Desc: Calls hooks associated with the hook name.
-----------------------------------------------------------]]
function Run(name, ...)
	return Call(name, gmod and gmod.GetGamemode() or nil, ...)
end

-- Bring old hooks

for event_name, t in pairs( OldHooks ) do
	for name, func in pairs( t ) do
		Add( event_name, name, func )
	end
end