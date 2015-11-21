--[[
	Title: Utilities

	Has some useful server utilities
]]


--[[
	Function: clientRPC

	Think of this function as if you're calling a client function directly from the server. You state who should run it, what the name of
	the function is, and then a list of parameters to pass to that function on the client. ULib handles the rest. Parameters can be any
	data type that's allowed on the network and of any size. Send huge tables or strings, it's all the same, and it all works.

	Parameters:

		filter - The Player object, table of Player objects for who you want to send this to, nil sends to everyone.
		fn - A string of the function to run on the client. Does *not* need to be in the global namespace, "myTable.myFunction" works too.
		... - *Optional* The parameters to pass to the function.

	Revisions:

		v2.40 - Initial.
]]
function ULib.clientRPC( plys, fn, ... )
	ULib.checkArg( 1, "ULib.clientRPC", {"nil","Player","table"}, plys )
	ULib.checkArg( 2, "ULib.clientRPC", {"string"}, fn )

	net.Start( "URPC" )
	net.WriteString( fn )
	net.WriteTable( {...} )
	if plys then
		net.Send( plys )
	else
		net.Broadcast()
	end
end


--[[
	Function: umsgSend

	Makes sending umsgs a blast. You don't have to bother knowing what type you're sending, just use ULib.umsgRcv() on the client.
	Note that while you can send tables with this function, you're limited by the max umsg size. If you're sending a large amount of data,
	consider using <clientRPC()> instead.

	Parameters:

		v - The value to send.
		queue - *(For use by <clientRPC()> ONLY)* A boolean of whether the messages should be queued with RPC or not.
]]
function ULib.umsgSend( v, queue )
	local tv = type( v )
	local function call( fn, ... )
		if queue then
			queueRPC( fn, ... )
		else
			fn( ... )
		end
	end

	if tv == "string" then
		call( umsg.Char, ULib.TYPE_STRING )
		call( umsg.String, v )
	elseif tv == "number" then
		if math.fmod( v, 1 ) ~= 0 then -- It's a float
			call( umsg.Char, ULib.TYPE_FLOAT )
			call( umsg.Float, v )
		else
			if v <= 127 and v >= -127 then
				call( umsg.Char, ULib.TYPE_CHAR )
				call( umsg.Char, v )
			elseif v < 32767 and v > -32768 then
				call( umsg.Char, ULib.TYPE_SHORT )
				call( umsg.Short, v )
			else
				call( umsg.Char, ULib.TYPE_LONG )
				call( umsg.Long, v )
			end
		end
	elseif tv == "boolean" then
		call( umsg.Char, ULib.TYPE_BOOLEAN )
		call( umsg.Bool, v )
	elseif tv == "Entity" or tv == "Player" then
		call( umsg.Char, ULib.TYPE_ENTITY )
		call( umsg.Entity, v )
	elseif tv == "Vector" then
		call( umsg.Char, ULib.TYPE_VECTOR )
		call( umsg.Vector, v )
	elseif tv == "Angle" then
		call( umsg.Char, ULib.TYPE_ANGLE )
		call( umsg.Angle, v )
	elseif tv == "table" then
		call( umsg.Char, ULib.TYPE_TABLE_BEGIN )
		for key, value in pairs( v ) do
			ULib.umsgSend( key, queue )
			ULib.umsgSend( value, queue )
		end
		call( umsg.Char, ULib.TYPE_TABLE_END )
	elseif tv == "nil" then
		call( umsg.Char, ULib.TYPE_NIL )
	else
		ULib.error( "Unknown type passed to umsgSend -- " .. tv )
	end
end


--[[
	Function: play3DSound

	Plays a 3D sound, the further away from the point the player is, the softer the sound will be.

	Parameters:

		sound - The sound to play, relative to the sound folder.
		vector - The point to play the sound at.
		volume - *(Optional, defaults to 1)* The volume to make the sound.
		pitch - *(Optional, defaults to 1)* The pitch to make the sound, 1 = normal.
]]
function ULib.play3DSound( sound, vector, volume, pitch )
	volume = volume or 100
	pitch = pitch or 100

	local ent = ents.Create( "info_null" )
	if not ent:IsValid() then return end
	ent:SetPos( vector )
	ent:Spawn()
	ent:Activate()
	ent:EmitSound( sound, volume, pitch )
end


--[[
	Function: getAllReadyPlayers

	Similar to player.GetAll(), except it only returns players that have ULib ready to go.

	Revisions:

		2.40 - Initial
]]
function ULib.getAllReadyPlayers()
	local players = player.GetAll()
	for i=#players, 1, -1 do
		if not players[ i ].ulib_ready then
			table.remove( players, i )
		end
	end

	return players
end


--[[
	Function: getVersion

	TODO
]]
function ULib.getVersion()
	local versionStr
	local build = nil
	local usingWorkshop = false

	-- Get workshop information, if available
	local addons = engine.GetAddons()
	for i=1, #addons do
		-- Ideally we'd use the "wsid" from this table
		-- But, as of 19 Nov 2015, that is broken, so we'll work around it
		if addons[i].file:find(tostring(ULib.WORKSHOPID)) then
			usingWorkshop = true
		end
	end

	-- If we have good build data, set it in "build"
	if ULib.fileExists( "ulib.build" ) then
		local buildStr = ULib.fileRead( "ulib.build" )
		local buildNum = tonumber(buildStr)
		-- Make sure the time is something reasonable -- between the year 2014 and 2128
		if buildNum and buildNum > 1400000000 and buildNum < 5000000000 then
			build = buildNum
		end
	end

	if ULib.RELEASE then
		versionStr = string.format( "v%.02f", ULib.VERSION )
	elseif usingWorkshop then
		versionStr = string.format( "v%.02fw", ULib.VERSION )
	elseif build then -- It's not release and it's not workshop
		versionStr = string.format( "v%.02fd (%s)", ULib.VERSION, os.date( "%x", build ) )
	else -- Not sure what this version is, but it's not a release
		versionStr = string.format( "v%.02fd", ULib.VERSION )
	end

	return versionStr, ULib.VERSION, build, usingWorkshop
end


local function sendVersionData( ply )
	local _, _, build, workshop = ULib.getVersion()
	ULib.clientRPC( ply, "ULib.getVersionData", build, workshop )
end
hook.Add( "PlayerInitialSpawn", "ULibSendVersionData", sendVersionData )


ULib.updateAvailable = false
local function advertiseNewVersion( ply )
	if ply:IsAdmin() and ULib.updateAvailable and not ply.UlibUpdateAdvertised then
		ULib.tsay( ply, "[ULib] There is an update available" )
		ply.UlibUpdateAdvertised = true
	end
end
hook.Add( ULib.HOOK_UCLAUTH, "ULibAdvertiseUpdate", advertiseNewVersion )

local function ulibUpdateCheck( body, len, headers, httpCode )
	if httpCode ~= 200 then
		return
	end

	timer.Remove( "ULibUpdateChecker" )
	hook.Remove( "Initialize", "ULibUpdateChecker" )

	local currentBuild = tonumber(body)
	if not currentBuild then return end

	local _, _, myBuild = ULib.getVersion()
	if myBuild < currentBuild then
		ULib.updateAvailable = true
		Msg( "[ULib] There is an update available\n" )

		local players = player.GetAll()
		for i=1, #players do
			advertiseNewVersion( players[ i ] )
		end
	end
end

local function ulibUpdateErr()
	timer.Remove( "ULibUpdateChecker" )
	hook.Remove( "Initialize", "ULibUpdateChecker" )
end

local function downloadForUlibUpdateCheck()
	local _, _, myBuild, workshop = ULib.getVersion()
	if not myBuild or workshop then
		return
	end

	if ULib.RELEASE then
		http.Fetch( "https://teamulysses.github.io/ulib/ulib.build", ulibUpdateCheck, ulibUpdateErr )
	else
		http.Fetch( "https://raw.githubusercontent.com/TeamUlysses/ulib/master/ulib.build", ulibUpdateCheck, ulibUpdateErr )
	end
end
hook.Add( "Initialize", "ULibUpdateChecker", downloadForUlibUpdateCheck )
timer.Create( "ULibUpdateChecker", 9, 10, downloadForUlibUpdateCheck )


ULib.repcvars = ULib.repcvars or {} -- This is used for <ULib.replicatedWithWritableCvar> in order to keep track of valid cvars and access info.
local repcvars = ULib.repcvars
local repCvarServerChanged
--[[
	Function: replicatedWritableCvar

	This function is mainly intended for use with the menus. This function is very similar to creating a replicated cvar with one caveat:
	This function also creates a cvar on the client that can be modified and will be sent back to the server.

	Parameters:

		sv_cvar - The string of server side cvar.
		cl_cvar - The string of the client side cvar. *THIS MUST BE DIFFERENT FROM THE sv_cvar VALUE IF YOU'RE PIGGY BACKING AN EXISTING REPLICATED CVAR (like sv_gravity)*.
		default_value - The string of the default value for the cvar.
		save - Boolean of whether or not the value is persistent across map changes.
			This uses garry's way, which has lots of issues. We recommend you watch the cvar for changes and handle saving yourself.
		notify - Boolean of whether or not value changes are announced on the server
		access - The string of the access required for a client to actually change the value.

	Returns:

		The server-side cvar object.

	Revisions:

		v2.40 - Initial.
		v2.50 - Changed to not depend on the replicated cvars themselves due to Garry-breakage.
]]
function ULib.replicatedWritableCvar( sv_cvar, cl_cvar, default_value, save, notify, access )
	sv_cvar = sv_cvar:lower()
	cl_cvar = cl_cvar:lower()

	local flags = 0
	if save then
		flags = flags + FCVAR_ARCHIVE
	end
	if notify then
		flags = flags + FCVAR_NOTIFY
	end

	local cvar_obj = GetConVar( sv_cvar ) or CreateConVar( sv_cvar, default_value, flags )

	umsg.Start( "ulib_repWriteCvar" ) -- Send to everyone connected
		umsg.String( sv_cvar )
		umsg.String( cl_cvar )
		umsg.String( default_value )
		umsg.String( cvar_obj:GetString() )
	umsg.End()

	repcvars[ sv_cvar ] = { access=access, default=default_value, cl_cvar=cl_cvar, cvar_obj=cvar_obj }
	cvars.AddChangeCallback( sv_cvar, repCvarServerChanged )

	hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, cl_cvar, nil, nil, cvar_obj:GetString() )

	return cvar_obj
end

local function repCvarOnJoin( ply )
	for sv_cvar, v in pairs( repcvars ) do
		umsg.Start( "ulib_repWriteCvar", ply )
			umsg.String( sv_cvar )
			umsg.String( v.cl_cvar )
			umsg.String( v.default )
			umsg.String( v.cvar_obj:GetString() )
		umsg.End()
	end
end
hook.Add( ULib.HOOK_LOCALPLAYERREADY, "ULibSendCvars", repCvarOnJoin )


local function clientChangeCvar( ply, command, argv )
	local sv_cvar = argv[ 1 ]
	local newvalue = argv[ 2 ]

	if not sv_cvar or not newvalue or not repcvars[ sv_cvar:lower() ] then -- Bad value, ignore
		return
	end

	sv_cvar = sv_cvar:lower()
	cvar_obj = repcvars[ sv_cvar ].cvar_obj
	local oldvalue = cvar_obj:GetString()
	if oldvalue == newvalue then return end -- Agreement

	local access = repcvars[ sv_cvar ].access
	if not ply:query( access ) then
		ULib.tsayError( ply, "You do not have access to this cvar (" .. sv_cvar .. "), " .. ply:Nick() .. "." )
		umsg.Start( "ulib_repChangeCvar", ply )
			umsg.Entity( ply )
			umsg.String( repcvars[ sv_cvar ].cl_cvar )
			umsg.String( oldvalue )
			umsg.String( oldvalue ) -- No change
		umsg.End()
		return
	end

	repcvars[ sv_cvar ].ignore = ply -- Flag other hook not to go off. Flag will be removed at hook.
	RunConsoleCommand( sv_cvar, newvalue )
	hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, repcvars[ sv_cvar ].cl_cvar, ply, oldvalue, newvalue )
end
concommand.Add( "ulib_update_cvar", clientChangeCvar, nil, nil, FCVAR_SERVER_CAN_EXECUTE )
-- Adding FCVAR_SERVER_CAN_EXECUTE above prevents an odd bug where if a user hosts a listen server, this command gets registered,
-- but when they join another server they can't change any replicated cvars.

repCvarServerChanged = function( sv_cvar, oldvalue, newvalue )
	if not repcvars[ sv_cvar ] then -- Bad value or we need to ignore it
		return
	end

	umsg.Start( "ulib_repChangeCvar" ) -- Tell clients to reset to new value
		umsg.Entity( repcvars[ sv_cvar ].ignore or Entity( 0 ) )
		umsg.String( repcvars[ sv_cvar ].cl_cvar )
		umsg.String( oldvalue )
		umsg.String( newvalue )
	umsg.End()

	if repcvars[ sv_cvar ].ignore then
		repcvars[ sv_cvar ].ignore = nil
	else
		hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, repcvars[ sv_cvar ].cl_cvar, Entity( 0 ), oldvalue, newvalue )
	end
end
