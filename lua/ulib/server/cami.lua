--[[
	File: CAMI

	Implements CAMI version "beta".

	The CAMI API is designed by Falco "FPtje" Peijnenburg, but this source code
	remains under the same licensing as the rest of ULib.

	To update the across-addons shared CAMI logic, run the following in the
	appropriate directory...
	: wget https://raw.githubusercontent.com/glua/CAMI/master/sh_cami.lua -O cami_global.lua
]]

CAMI.ULX_TOKEN = "ULX"

local function onGroupRegistered( camiGroup, originToken )
	-- Ignore if ULX is the source, or if we receive bad data from another addon
	if originToken == CAMI.ULX_TOKEN then return end
	if ULib.findInTable( {"superadmin", "admin", "user"}, camiGroup.Name ) then return end

	if not ULib.ucl.groups[ camiGroup.Name ] then
		ULib.ucl.addGroup( camiGroup.Name, nil, camiGroup.Inherits, true )
	else
		ULib.ucl.setGroupInheritance( camiGroup.Name, camiGroup.Inherits )
	end
end
hook.Add( "CAMI.OnUsergroupRegistered", "ULXCamiGroupRegistered", onGroupRegistered )

local function onGroupRemoved( camiGroup, originToken )
	-- Ignore if ULX is the source, or if we receive bad data from another addon
	if originToken == CAMI.ULX_TOKEN then return end
	if ULib.findInTable( {"superadmin", "admin", "user"}, camiGroup.Name ) then return end

	ULib.ucl.removeGroup( camiGroup.Name, true )
end
hook.Add( "CAMI.OnUsergroupUnregistered", "ULXCamiGroupRemoved", onGroupRemoved )

local function onUsersGroupChanged( ply, oldGroup, newGroup, originToken )
	if originToken == CAMI.ULX_TOKEN then return end

	local id = ULib.ucl.getUserRegisteredID( ply )
	if not id then id = target_ply:SteamID() end

	if newGroup == ULib.ACCESS_ALL then
		ULib.ucl.removeUser( id, true )
	else
		if not ULib.ucl.groups[ newGroup ] then -- Just in case we were never notified of this group
			local camiGroup = CAMI.GetUsergroup(usergroupName)
			local inherits = camiGroup and camiGroup.Inherits
			ULib.ucl.addGroup( newGroup, nil, inherits, true )
		end
		ULib.ucl.addUser( id, nil, nil, newGroup, true )
	end
end
hook.Add( "CAMI.PlayerUsergroupChanged", "ULXCamiUsersGroupChanged", onUsersGroupChanged )

local function onPrivilegeRegistered( camiPriv )
	local priv = camiPriv.Name:lower()
	ULib.ucl.registerAccess( priv, camiPriv.MinAccess, "A privilege from CAMI", "CAMI" )
end
hook.Add( "CAMI.OnPrivilegeRegistered", "ULXCamiPrivilegeRegistered", onPrivilegeRegistered )

local function playerHasAccess( actorPly, priv, callback, targetPly, extra )
	local priv = priv:lower()
	local result = ULib.ucl.query( actorPly, priv, true )
	if result ~= nil then
		callback(result)
		return true
	end
end
hook.Add( "CAMI.PlayerHasAccess", "ULXCamiPlayerHasAccess", playerHasAccess )

-- Someday, implement this too.
--[[
local function steamIDHasAccess( steamid, priv, callback, targetPly, extra )
	local priv = priv:lower()
	callback(result)
end
hook.Add( "CAMI.SteamIDHasAccess", "ULXCamiSteamidHasAccess", steamIDHasAccess )
]]

-- Register anything already loaded
for _, camiPriv in pairs(CAMI.GetPrivileges()) do
	onPrivilegeRegistered( camiPriv )
end

for name, camiGroup in pairs(CAMI.GetUsergroups()) do
	onGroupRegistered( camiGroup )
end
-- End register anything already loaded

-- Register ULib things into CAMI
for name, data in pairs(ULib.ucl.groups) do
	if not ULib.findInTable( {"superadmin", "admin", "user"}, name ) then
		CAMI.RegisterUsergroup( {Name=name, Inherits=(data.inherit_from or "user")}, CAMI.ULX_TOKEN )
	end
end
-- End register ULib things into CAMI
