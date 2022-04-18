--[[
	File: CAMI

	Implements CAMI version "20150902.1".

	The CAMI API is designed by Falco "FPtje" Peijnenburg, but this source code
	remains under the same licensing as the rest of ULib.

	To update the shared FPtje CAMI logic, run the following in the
	appropriate directory...
	: wget https://raw.githubusercontent.com/glua/CAMI/master/sh_cami.lua -O cami_global.lua
]]

CAMI.ULX_TOKEN = "ULX"

local function playerHasAccess( actorPly, priv, callback, targetPly, extra )
	local priv = priv:lower()
	local result = ULib.ucl.query( actorPly, priv, true )
	-- CAMI does not support floating access like ULX -- meaning that in ULX the
	-- access does not have to be tied to a group, but CAMI requires an access to
	-- be tied to a group. To work around this, ULX cannot defer an access
	-- decision, but has to give an authoritative answer to each query.
	callback(not not result) -- double not converts a nil to a false
	return true
end
hook.Add( "CAMI.PlayerHasAccess", "ULXCamiPlayerHasAccess", playerHasAccess )

local function steamIDHasAccess( steamid, priv, callback, targetPly, extra )
	local priv = priv:lower()
	steamid = steamid:upper()

	if not ULib.isValidSteamID( steamid ) then return end

	local connectedPly = ULib.getPlyByID( steamid )
	if connectedPly then return playerHasAccess( connectedPly, priv, callback, targetPly, extra ) end

	-- ULib currently doesn't support looking up permissions for users that aren't connected. Maybe in the future?
end
hook.Add( "CAMI.SteamIDHasAccess", "ULXCamiSteamidHasAccess", steamIDHasAccess )

-- Registering/deleting groups on client not necessary for ULib since we pass
-- that data around from the server
if CLIENT then return end

local function onGroupRegistered( camiGroup, originToken )
	-- Ignore if ULX is the source, or if we receive bad data from another addon
	if originToken == CAMI.ULX_TOKEN then return end
	if ULib.findInTable( {"superadmin", "admin", "user"}, camiGroup.Name ) then return end

	if not ULib.ucl.groups[ camiGroup.Name ] then
		ULib.ucl.addGroup( camiGroup.Name, nil, camiGroup.Inherits, true )
	--else
		--ULib.ucl.setGroupInheritance( camiGroup.Name, camiGroup.Inherits, true )
		-- We used to set inheritance according to what CAMI passed to us, but DarkRP/FAdmin
		-- passes us bad data by design, so we have to ignore this for sanity
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

local function onSteamIDUserGroupChanged( id, oldGroup, newGroup, originToken )
	if originToken == CAMI.ULX_TOKEN then return end

	if newGroup == ULib.ACCESS_ALL then
		-- If they are becoming a regular user, and they had access, then remove them
		if ULib.ucl.users[ id ] then
			ULib.ucl.removeUser( id, true )
		end
	else
		if not ULib.ucl.groups[ newGroup ] then -- Just in case we were never notified of this group
			local camiGroup = CAMI.GetUsergroup(usergroupName)
			local inherits = camiGroup and camiGroup.Inherits
			ULib.ucl.addGroup( newGroup, nil, inherits, true )
		end
		ULib.ucl.addUser( id, nil, nil, newGroup, true )
	end
end
hook.Add( "CAMI.SteamIDUsergroupChanged", "ULXCamiSteamidUserGroupChanged", onSteamIDUserGroupChanged )

local function onPlayerUserGroupChanged( ply, oldGroup, newGroup, originToken )
	if not ply or not ply:IsValid() then return end -- Seems like we get called after a player disconnects sometimes
	if originToken == CAMI.ULX_TOKEN then return end

	local id = ULib.ucl.getUserRegisteredID( ply )
	if not id then id = ply:SteamID() end

	onSteamIDUserGroupChanged( id, oldGroup, newGroup, originToken )
end
hook.Add( "CAMI.PlayerUsergroupChanged", "ULXCamiPlayerUserGroupChanged", onPlayerUserGroupChanged )

local function onPrivilegeRegistered( camiPriv )
	local priv = camiPriv.Name:lower()
	ULib.ucl.registerAccess( priv, camiPriv.MinAccess, "A privilege from CAMI", "CAMI" )
end
hook.Add( "CAMI.OnPrivilegeRegistered", "ULXCamiPrivilegeRegistered", onPrivilegeRegistered )

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
