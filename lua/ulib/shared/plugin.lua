--[[
	Title: Plugin Helpers

	Some useful functions for ULib plugins to use for doing plugin-type things.
]]

ULib.plugins = {} -- Any registered plugins go here


--[[
	Function: registerPlugin

	TODO
]]
function ULib.registerPlugin( name, pluginData )
	if not ULib.plugins[ name ] then
		ULib.plugins[ name ] = pluginData
	else
		table.Merge( ULib.plugins[ name ], pluginData )
		pluginData = ULib.plugins[ name ]
	end
	--ULib.plugins[ name ] = { version=version, isRelease=isRelease, author=author,
	-- url=url, workshopid=workshopid, build=build, hideBuild=hideBuild, buildURL=buildURL, buildCallback=buildCallback }

	if pluginData.workshopid then
		-- Get workshop information, if available
		local addons = engine.GetAddons()
		for i=1, #addons do
			local addon = addons[i]
			-- Ideally we'd use the "wsid" from this table
			-- But, as of 19 Nov 2015, that is broken, so we'll work around it
			if addon.mounted and addon.file:find(tostring(pluginData.workshopid)) then
				ULib.plugins[ name ].usingWorkshop = true
			end
		end
	end

	if SERVER then
		ULib.clientRPC( nil, "ULib.registerPlugin", name, pluginData )
	end
end


if SERVER then
	local function sendRegisteredPlugins( ply )
		for name, pluginData in pairs (ULib.plugins) do
			ULib.clientRPC( ply, "ULib.registerPlugin", name, pluginData )
		end
	end
	hook.Add( "PlayerInitialSpawn", "ULibSendRegisteredPlugins", sendRegisteredPlugins )
end


local ulibDat = {
	version       = string.format( "%.2f", ULib.VERSION ),
	isRelease     = ULib.RELEASE,
	author        = "Team Ulysses",
	url           = "http://ulyssesmod.net",
	workshopid    = 557962238,
	build         = tonumber(ULib.fileRead( "ulib.build" )),
	buildURL      = ULib.RELEASE and "https://teamulysses.github.io/ulib/ulib.build" or "https://raw.githubusercontent.com/TeamUlysses/ulib/master/ulib.build",
	--buildCallback = nil
}
ULib.registerPlugin( "ULib", ulibDat )


--[[
	Function: pluginVersionStr

	TODO
]]
function ULib.pluginVersionStr( name )
	local dat = ULib.plugins[ name ]
	if not dat then return nil end

	if dat.isRelease then
		return string.format( "v%s", dat.version )

	elseif dat.usingWorkshop then
		return string.format( "v%sw", dat.version )

	elseif dat.build and not dat.hideBuild then -- It's not release and it's not workshop
		local build = dat.build
		if build > 1400000000 and build < 5000000000 then -- Probably a date -- between 2014 and 2128
			build = os.date( "%x", build )
		end
		return string.format( "v%sd (%s)", dat.version, build )

	else -- Not sure what this version is, but it's not a release
		return string.format( "v%sd", dat.version )
	end
end

local function receiverFor( plugin )
	local function receiver( body, len, headers, httpCode )
		local buildOnline = tonumber( body )
		if not buildOnline then return end

		plugin.buildOnline = buildOnline
		if plugin.buildCallback then
			plugin.buildCallback( plugin.build, buildOnline )
		end
	end
	return receiver
end


--[[
	Function: updateCheck

	TODO
]]
function ULib.updateCheck( name, url )
	local plugin = ULib.plugins[ name ]
	if not plugin then return nil end
	if plugin.buildOnline then return nil end

	http.Fetch( url, receiverFor( plugin ) )
	return true
end

local function httpCheck( body, len, headers, httpCode )
	if httpCode ~= 200 then
		return
	end

	timer.Remove( "ULibPluginUpdateChecker" )
	hook.Remove( "Initialize", "ULibPluginUpdateChecker" )

	-- Okay, the HTTP library is functional and we can reach out. Let's check for updates.
	for name, plugin in pairs (ULib.plugins) do
		if plugin.buildURL then
			ULib.updateCheck( name, plugin.buildURL )
		end
	end
end

local function httpErr()
	-- Assume major problem and give up
	timer.Remove( "ULibPluginUpdateChecker" )
	hook.Remove( "Initialize", "ULibPluginUpdateChecker" )
end

local function downloadForUlibUpdateCheck()
	http.Fetch( "http://google.com", httpCheck, httpErr )
end

if ULib.AUTOMATIC_UPDATE_CHECKS then
	hook.Add( "Initialize", "ULibPluginUpdateChecker", downloadForUlibUpdateCheck )
	timer.Create( "ULibPluginUpdateChecker", 9, 10, downloadForUlibUpdateCheck )
end
