local meta = FindMetaTable( "Player" )
if not meta then return end

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

-- Performance optimization
local spawnWhitelist = {}
for _, v in ipairs( ULib.spawnWhitelist ) do
	spawnWhitelist[v] = true
end

local entMeta = FindMetaTable( "Entity" )
local getTable = entMeta.GetTable

-- Extended player meta and hooks
function meta:DisallowNoclip( bool )
	self.NoNoclip = bool
end

function meta:DisallowSpawning( bool )
	self.NoSpawning = bool
end

function meta:DisallowVehicles( bool )
	self.NoVehicles = bool
end

local function tool( ply, _, toolmode )
	if not ply or not ply:IsValid() then return end

	if getTable( ply ).NoSpawning and not spawnWhitelist[toolmode] then
		return false
	end
end
hook.Add( "CanTool", "ULibPlayerToolCheck", tool, HOOK_HIGH )

local function noclip( ply )
	if not ply or not ply:IsValid() then return end
	if getTable( ply ).NoNoclip then return false end
end
hook.Add( "PlayerNoClip", "ULibNoclipCheck", noclip, HOOK_HIGH )

local function spawnblock( ply )
	if not ply or not ply:IsValid() then return end
	if getTable( ply ).NoSpawning then return false end
end
hook.Add( "PlayerSpawnObject", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnEffect", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnProp", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnNPC", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnVehicle", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnRagdoll", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerSpawnSENT", "ULibSpawnBlock", spawnblock )
hook.Add( "PlayerGiveSWEP", "ULibSpawnBlock", spawnblock )

local function vehicleblock( ply )
	if not ply or not ply:IsValid() then return end
	if getTable( ply ).NoVehicles then
		return false
	end
end
hook.Add( "CanPlayerEnterVehicle", "ULibVehicleBlock", vehicleblock, HOOK_HIGH )
hook.Add( "CanDrive", "ULibVehicleDriveBlock", vehicleblock, HOOK_HIGH )
