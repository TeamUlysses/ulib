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
	default_value = tostring(default_value)

	local flags = 0
	if save then
		flags = flags + FCVAR_ARCHIVE
	end
	if notify then
		flags = flags + FCVAR_NOTIFY
	end

	local cvar_obj = GetConVar( sv_cvar ) or CreateConVar( sv_cvar, default_value, flags )
	
	
	net.Start("ulib_repWriteCvar")
		net.WriteString( sv_cvar )
		net.WriteString( cl_cvar )
		net.WriteString( default_value )
		net.WriteString( cvar_obj:GetString() )
	net.Broadcast()

	repcvars[ sv_cvar ] = { access=access, default=default_value, cl_cvar=cl_cvar, cvar_obj=cvar_obj }
	cvars.AddChangeCallback( sv_cvar, repCvarServerChanged )

	hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, cl_cvar, nil, nil, cvar_obj:GetString() )

	return cvar_obj
end

local function repCvarOnJoin( ply )
	for sv_cvar, v in pairs( repcvars ) do
	
		net.Start("ulib_repWriteCvar")
			net.WriteString( sv_cvar )
			net.WriteString( v.cl_cvar )
			net.WriteString( v.default )
			net.WriteString( v.cvar_obj:GetString() )
		net.Send( ply )
		
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
		net.Start( "ulib_repChangeCvar" )
			net.WriteEntity( ply )
			net.WriteString( repcvars[ sv_cvar ].cl_cvar )
			net.WriteString( oldvalue )
			net.WriteString( oldvalue ) -- No change
		net.Send( ply )
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
	
	net.Start( "ulib_repChangeCvar" ) -- Tell clients to reset to new value
		net.WriteEntity( repcvars[ sv_cvar ].ignore or Entity( 0 ) )
		net.WriteString( repcvars[ sv_cvar ].cl_cvar )
		net.WriteString( oldvalue )
		net.WriteString( newvalue )
	net.Broadcast()

	if repcvars[ sv_cvar ].ignore then
		repcvars[ sv_cvar ].ignore = nil
	else
		hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, repcvars[ sv_cvar ].cl_cvar, Entity( 0 ), oldvalue, newvalue )
	end
end
