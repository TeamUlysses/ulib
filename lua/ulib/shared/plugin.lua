--[[
	Title: Plugin Helpers

	Some useful functions for ULib plugins to use for doing plugin-type things.
]]


--[[
	Table: plugins

	Holds plugin data for plugins that have registered themselves with ULib.

	Fields:

		Name - A string of the name of the plugin.
		Version - A string or number of the version of the plugin.
		IsRelease - An optional boolean specifying if this is a release (non-beta) version
		Author - An optional string of the author of the plugin.
		URL - An optional string of the URL for the plugin.
		WorkshopID - An optional number specifying the workshopid for the plugin.
		BuildNumLocal - An optional number specifying the build number for this plugin.
		BuildHidden - An optional boolean; if true, the build is not shown in the version string.
		BuildNumRemoteURL - An optional string specifying the URL to visit to retrieve the latest published build number for the plugin.
		BuildNumRemoteReceivedCallback - An optional function to callback when the latest published build number is received.

		WorkshopMounted - A generated boolean which is true only if WorkshopID was specified and that ID is currently mounted.
		BuildNumRemote - A generated number of the retrieved latest published build number.
]]
ULib.plugins = {} -- Any registered plugins go here


--[[
	Function: registerPlugin

	Parameters:

		pluginData - A table of plugin data in the format documented in <plugins>, above.
]]
function ULib.registerPlugin( pluginData )
	local name = pluginData.Name
	if not ULib.plugins[ name ] then
		ULib.plugins[ name ] = pluginData
	else
		table.Merge( ULib.plugins[ name ], pluginData )
		pluginData = ULib.plugins[ name ]
	end

	if pluginData.WorkshopID then
		-- Get workshop information, if available
		local addons = engine.GetAddons()
		for i=1, #addons do
			local addon = addons[i]
			-- Ideally we'd use the "wsid" from this table
			-- But, as of 19 Nov 2015, that is broken, so we'll work around it
			if addon.mounted and addon.file:find(tostring(pluginData.WorkshopID)) then
				pluginData.WorkshopMounted = true
			end
		end
	end

	if SERVER then
		ULib.clientRPC( nil, "ULib.registerPlugin", pluginData )
	end
end


if SERVER then
	local function sendRegisteredPlugins( ply )
		for name, pluginData in pairs (ULib.plugins) do
			ULib.clientRPC( ply, "ULib.registerPlugin", pluginData )
		end
	end
	hook.Add( "PlayerInitialSpawn", "ULibSendRegisteredPlugins", sendRegisteredPlugins )
end

local ulibBuildNumURL = ULib.RELEASE and "https://teamulysses.github.io/ulib/ulib.build" or "https://raw.githubusercontent.com/TeamUlysses/ulib/master/ulib.build"
ULib.registerPlugin{
	Name          = "ULib",
	Version       = string.format( "%.2f", ULib.VERSION ),
	IsRelease     = ULib.RELEASE,
	Author        = "Team Ulysses",
	URL           = "http://ulyssesmod.net",
	WorkshopID    = 557962238,
	--WorkshopMounted = true,
	BuildNumLocal = tonumber(ULib.fileRead( "ulib.build" )),
	--BuildHidden = true,
	BuildNumRemoteURL = ulibBuildNumURL,
	--BuildNumRemote = 123,
	--BuildNumRemoteReceivedCallback = nil,
}


--[[
	Function: pluginVersionStr

	Returns a human-readable version string for plugins in a consistent format.
	The string tells users if they're using a development build (with build number/date), workshop, or release version.

	Parameters:

		name - The string of the plugin name you are querying about.

	Returns:

		A string of the version information for the specified plugin.
]]
function ULib.pluginVersionStr( name )
	local dat = ULib.plugins[ name ]
	if not dat then return nil end

	if dat.WorkshopMounted then
		return string.format( "v%sw", dat.Version )

	elseif dat.IsRelease then
		return string.format( "v%s", dat.Version )

	elseif dat.BuildNumLocal and not dat.BuildHidden then -- It's not release and it's not workshop
		local build = dat.BuildNumLocal
		if build > 1400000000 and build < 5000000000 then -- Probably a date -- between 2014 and 2128
			build = os.date( "%x", build )
		end
		return string.format( "v%sd (%s)", dat.Version, build )

	else -- Not sure what this version is, but it's not a release
		return string.format( "v%sd", dat.Version )
	end
end

local function receiverFor( plugin )
	local function receiver( body, len, headers, httpCode )
		local buildOnline = tonumber( body )
		if not buildOnline then return end

		plugin.BuildNumRemote = buildOnline
		if plugin.BuildNumRemoteReceivedCallback then
			plugin.BuildNumRemoteReceivedCallback( plugin.BuildNumLocal, buildOnline )
		end
	end
	return receiver
end


--[[
	Function: updateCheck

	Check for updates for a named plugin at a given URL (usually you will want to
	use the URL specified in registerPlugin). Note that this is an asynchronous check.

	Parameters:

		name - The name of the plugin.
		url - The URL to check.
]]
function ULib.updateCheck( name, url )
	local plugin = ULib.plugins[ name ]
	if not plugin then return nil end
	if plugin.BuildNumRemote then return nil end

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
		if plugin.BuildNumRemoteURL then
			ULib.updateCheck( name, plugin.BuildNumRemoteURL )
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
