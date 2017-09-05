--[[
	Title: Player

	Holds some helpful player functions.
]]

--[[
	Table: slapSounds

	These are the sounds used for slaps.
]]
local slapSounds = {
	"physics/body/body_medium_impact_hard1.wav",
	"physics/body/body_medium_impact_hard2.wav",
	"physics/body/body_medium_impact_hard3.wav",
	"physics/body/body_medium_impact_hard5.wav",
	"physics/body/body_medium_impact_hard6.wav",
	"physics/body/body_medium_impact_soft5.wav",
	"physics/body/body_medium_impact_soft6.wav",
	"physics/body/body_medium_impact_soft7.wav",
}


--[[
	Function: slap

	Slaps an entity, can be a user or any entity.

	Parameters:

		ent - The target ent.
		damage - *(Optional, defaults to 0)* The amount of damage to inflict on the entity.
		power - *(Optional, defaults to 30)* The power of the slap.
		nosound - *(Optional, defaults to false)* If true, no sound will be played.
]]
function ULib.slap( ent, damage, power, nosound )
	if ent:GetMoveType() == MOVETYPE_OBSERVER then return end -- Nothing we can do.

	damage = damage or 0
	power = power or 500

	if ent:IsPlayer() then
		if not ent:Alive() then
			return -- Nothing we can do.
		end

		if ent:InVehicle() then
			ent:ExitVehicle()
		end

		if ent:GetMoveType() == MOVETYPE_NOCLIP then
			ent:SetMoveType( MOVETYPE_WALK )
		end
	end

	if not nosound then -- Play a slap sound
		local sound_num = math.random( #slapSounds ) -- Choose at random
		ent:EmitSound( slapSounds[ sound_num ] )
	end

	local direction = Vector( math.random( 20 )-10, math.random( 20 )-10, math.random( 20 )-5 ) -- Make it random, slightly biased to go up.
	ULib.applyAccel( ent, power, direction )

	local angle_punch_pitch = math.Rand( -20, 20 )
	local angle_punch_yaw = math.sqrt( 20*20 - angle_punch_pitch * angle_punch_pitch )
	if math.random( 0, 1 ) == 1 then
		angle_punch_yaw = angle_punch_yaw * -1
	end
	ent:ViewPunch( Angle( angle_punch_pitch, angle_punch_yaw, 0 ) )

	local newHp = ent:Health() - damage
	if newHp <= 0 then
		if ent:IsPlayer() then
			ent:Kill()
		else
			ent:Fire( "break", 1, 0 )
		end
		return
	end
	ent:SetHealth( newHp )
end


--[[
	Function: kick

	Kicks a user.

	Parameters:

		ply - The player to kick.
		reason - *(Optional)* The reason to give for kicking.
		calling_ply - *(Optional)* The player doing the kicking.

	Revisions:

		v2.60 - Fixed a bug with the parameters if you didn't pass reason and calling_ply together.
]]
function ULib.kick( ply, reason, calling_ply )
	local nick = calling_ply and calling_ply:IsValid() and
		(string.format( "%s(%s)", calling_ply:Nick(), calling_ply:SteamID() ) or "Console")
	local steamid = ply:SteamID()
	if reason and nick then
		ply:Kick( string.format( "Kicked by %s - %s", nick, reason ) )
	elseif nick then
		ply:Kick( "Kicked by " .. nick )
	else
		ply:Kick( reason or "[ULX] Kicked from server" )
	end
	hook.Call( ULib.HOOK_USER_KICKED, _, steamid, reason or "[ULX] Kicked from server", calling_ply )
end


--[[
	Function: getSpawnInfo

	Grabs and returns player information that can be used to respawn player with same health/armor as before the spawn.

	Parameters:

		ply - The player to grab information for.


	Returns:

		Updates player object to store health and armor. Has no effect unless ULib.Spawn is used later.
]]
function ULib.getSpawnInfo( player )
	local result = {}

	local t = {}
	player.ULibSpawnInfo = t
	t.health = player:Health()
	t.armor = player:Armor()
	if player:GetActiveWeapon():IsValid() then
		t.curweapon = player:GetActiveWeapon():GetClass()
	end

	local weapons = player:GetWeapons()
	local data = {}
	for _, weapon in ipairs( weapons ) do
		printname = weapon:GetClass()
		data[ printname ] = {}
		data[ printname ].clip1 = weapon:Clip1()
		data[ printname ].clip2 = weapon:Clip2()
		data[ printname ].ammo1 = player:GetAmmoCount( weapon:GetPrimaryAmmoType() )
		data[ printname ].ammo2 = player:GetAmmoCount( weapon:GetSecondaryAmmoType() )
	end
	t.data = data
end

-- Helper function for ULib.spawn()
local function doWeapons( player, t )
	if not player:IsValid() then return end -- Drat, missed 'em.

	player:StripAmmo()
	player:StripWeapons()

	for printname, data in pairs( t.data ) do
		player:Give( printname )
		local weapon = player:GetWeapon( printname )
		weapon:SetClip1( data.clip1 )
		weapon:SetClip2( data.clip2 )
		player:SetAmmo( data.ammo1, weapon:GetPrimaryAmmoType() )
		player:SetAmmo( data.ammo2, weapon:GetSecondaryAmmoType() )
	end

	if t.curweapon then
		player:SelectWeapon( t.curweapon )
	end
end


--[[
	Function: spawn

	Enhanced spawn player. Can spawn player and return health/armor to status before the spawn. (Only IF ULib.getSpawnInfo was used previously.)
	Clears previously set values that were stored from ULib.getSpawnInfo.

	Parameters:

		ply - The player to grab information for.
		bool - If true, spawn will set player information to values stored using ULib.SpawnInfo

	Returns:

		Spawns player. Sets health/armor to stored defaults if ULib.getSpawnInfo was used previously. Clears SpawnInfo table afterwards.
]]
function ULib.spawn( player, bool )
	player:Spawn()

	if bool and player.ULibSpawnInfo then
		local t = player.ULibSpawnInfo
		player:SetHealth( t.health )
		player:SetArmor( t.armor )
		timer.Simple( 0.1, function() doWeapons( player, t ) end )
		player.ULibSpawnInfo = nil
	end
end
