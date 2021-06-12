--[[
	Title: Utilities

	Some client-side utilties
]]

local function ULibRPC()
	local fn_string = net.ReadString()
	local args = net.ReadTable()
	local success, fn = ULib.findVar( fn_string )
	if not success or type( fn ) ~= "function" then return error( "Received bad RPC, invalid function (" .. tostring( fn_string ) .. ")!" ) end

	-- Since the table length operator can't always be trusted if there are holes in it, find the length by ourself
	local max = 0
	for k, v in pairs( args ) do
		local n = tonumber( k )
		if n and n > max then
			max = n
		end
	end

	fn( unpack( args, 1, max ) )
end
net.Receive( "URPC", ULibRPC )


-- This will play sounds client side

net.Receive( "ulib_sound", function( ln )
	local str = net.ReadString()
	if not ULib.fileExists( "sound/" .. str ) then
		Msg( "[LC ULib ERROR] Received invalid sound\n" )
		return
	end

	if LocalPlayer():IsValid() then
		LocalPlayer():EmitSound( Sound( str ) )
	end
end )

local cvarinfo = {} -- Stores the client cvar object indexed by name of the server cvar
local reversecvar = {} -- Stores the name of server cvars indexed by the client cvar

-- When our client side cvar is changed, notify the server to change it's cvar too.
local function clCvarChanged( cl_cvar, oldvalue, newvalue )
	if not reversecvar[ cl_cvar ] then -- Error
		return
	elseif reversecvar[ cl_cvar ].ignore then -- ignore
		reversecvar[ cl_cvar ].ignore = nil
		return
	end

	local sv_cvar = reversecvar[ cl_cvar ].sv_cvar
	RunConsoleCommand( "ulib_update_cvar", sv_cvar, newvalue )
end

-- This is the counterpart to <replicatedWithWritableCvar>. See that function for more info. We also add callbacks from here.

net.Receive( "ulib_repWriteCvar", function( len )

	local sv_cvar = net.ReadString()
	local cl_cvar = net.ReadString()
	local default_value = net.ReadString()
	local current_value = net.ReadString()

	cvarinfo[ sv_cvar ] = GetConVar( cl_cvar ) or CreateClientConVar( cl_cvar, default_value, false, false ) -- Make sure it's created one way or another (second case is most common)
	reversecvar[ cl_cvar ] = { sv_cvar=sv_cvar }

	ULib.queueFunctionCall( function() -- Queued to ensure we don't overload the client console
		hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, cl_cvar, nil, nil, current_value )
		if cvarinfo[ sv_cvar ]:GetString() ~= current_value then
			reversecvar[ cl_cvar ].ignore = true -- Flag so hook doesn't do anything. Flag is removed at hook.
			RunConsoleCommand( cl_cvar, current_value )
		end
	end )
	
	cvars.AddChangeCallback( cl_cvar, clCvarChanged )
	
end )


-- This is called when they've attempted to change a cvar they don't have access to.

net.Receive( "ulib_repChangeCvar", function( len )
	local ply = net.ReadEntity()
	local cl_cvar = net.ReadString()
	local oldvalue = net.ReadString()
	local newvalue = net.ReadString()
	local changed = oldvalue ~= newvalue

	if not reversecvar[ cl_cvar ] then -- Error!
		return
	end

	local sv_cvar = reversecvar[ cl_cvar ].sv_cvar

	ULib.queueFunctionCall( function() -- Queued so we won't overload the client console and so that changes are always going to be called via the hook AFTER the initial hook is called
		if changed then
			hook.Call( ULib.HOOK_REPCVARCHANGED, _, sv_cvar, cl_cvar, ply, oldvalue, newvalue )
		end

		if GetConVarString( cl_cvar ) ~= newvalue then
			reversecvar[ cl_cvar ].ignore = true -- Flag so hook doesn't do anything. Flag is removed at hook.
			RunConsoleCommand( cl_cvar, newvalue)
		end
	end )
end )
