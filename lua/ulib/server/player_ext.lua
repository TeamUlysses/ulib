local meta = FindMetaTable( "Player" )

ULib.spawnWhitelist = -- Tool white list for tools that don't spawn things
{
	"colour",
	"material",
	"paint",
	"ballsocket",
	"ballsocket_adv",
	"weld",
	"keepupright",
	"nocollide",
	"eyeposer",
	"faceposer",
	"statue",
	"weld_ez",
	"axis",
}

-- Return if there's nothing to add on to
if not meta then return end

function meta:DisallowNoclip( bool )
	self.NoNoclip = bool
end

function meta:DisallowSpawning( bool )
	self.NoSpawning = bool
end

function meta:DisallowVehicles( bool )
	self.NoVehicles = bool
end

local function tool( ply, tr, toolmode )
	if not ply or not ply:IsValid() then return end

	if ply.NoSpawning then
		if not table.HasValue( ULib.spawnWhitelist, toolmode ) then
			return false
		end
	end
end
hook.Add( "CanTool", "ULibPlayerToolCheck", tool, HOOK_HIGH )

local function noclip( ply )
	if not ply or not ply:IsValid() then return end
	if ply.NoNoclip then return false end
end
hook.Add( "PlayerNoClip", "ULibNoclipCheck", noclip, HOOK_HIGH )

local function spawnblock( ply )
	if not ply or not ply:IsValid() then return end
	if ply.NoSpawning then return false end
end
hook.Add( "PlayerSpawnObject", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnEffect", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnProp", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnNPC", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnVehicle", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnRagdoll", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnSENT", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerGiveSWEP", "ULibSpawnBlock", spawnblock )

local function vehicleblock( ply, ent )
	if not ply or not ply:IsValid() then return end
	if ply.NoVehicles then
		return false
	end
end
hook.Add( "CanPlayerEnterVehicle", "ULibVehicleBlock", vehicleblock, HOOK_HIGH )
hook.Add( "CanDrive", "ULibVehicleDriveBlock", vehicleblock, HOOK_HIGH )
