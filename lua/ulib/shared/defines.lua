--[[
	Title: Defines

	Holds some defines used on both client and server.
]]

ULib = ULib or {}

ULib.RELEASE = false -- Don't access these two directly, use ULib.pluginVersionStr("ULib")
ULib.VERSION = 2.63
ULib.AUTOMATIC_UPDATE_CHECKS = true

ULib.ACCESS_ALL = "user"
ULib.ACCESS_OPERATOR = "operator"
ULib.ACCESS_ADMIN = "admin"
ULib.ACCESS_SUPERADMIN = "superadmin"

ULib.DEFAULT_ACCESS = ULib.ACCESS_ALL

ULib.DEFAULT_TSAY_COLOR = Color( 151, 211, 255 ) -- Found by using MS Paint


--[[
	Section: Umsg Helpers

	These are ids for the ULib umsg functions, so the client knows what they're getting.
]]
ULib.TYPE_ANGLE = 1
ULib.TYPE_BOOLEAN = 2
ULib.TYPE_CHAR = 3
ULib.TYPE_ENTITY = 4
ULib.TYPE_FLOAT = 5
ULib.TYPE_LONG = 6
ULib.TYPE_SHORT = 7
ULib.TYPE_STRING = 8
ULib.TYPE_VECTOR = 9
-- These following aren't actually datatypes, we handle them ourselves
ULib.TYPE_TABLE_BEGIN = 10
ULib.TYPE_TABLE_END = 11
ULib.TYPE_NIL = 12

ULib.RPC_UMSG_NAME = "URPC"

ULib.TYPE_SIZE = {
	[ULib.TYPE_ANGLE] = 12, -- 3 floats
	[ULib.TYPE_BOOLEAN] = 1,
	[ULib.TYPE_CHAR] = 1,
	[ULib.TYPE_ENTITY] = 4, -- Found through trial and error
	[ULib.TYPE_FLOAT] = 4,
	[ULib.TYPE_LONG] = 4,
	[ULib.TYPE_SHORT] = 2,
	[ULib.TYPE_VECTOR] = 12, -- 3 floats
	[ULib.TYPE_NIL] = 0, -- Not technically a type but we handle it anyways
}

ULib.MAX_UMSG_BYTES = 255

--[[
	Section: Hooks

	These are the hooks that ULib has created that other modders are free to make use of.
]]

--[[
	Hook: UCLAuthed

	Called *on both server and client* when a player has been (re)authenticated by UCL. Called for ALL players, regardless of access.

	Parameters passed to callback:

		ply - The player that got (re)authenticated.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_UCLAUTH = "UCLAuthed"

--[[
	Hook: UCLChanged

	Called *on both server and client* when anything in ULib.ucl.users, ULib.ucl.authed, or ULib.ucl.groups changes. No parameters are passed to callbacks.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_UCLCHANGED = "UCLChanged"

--[[
	Hook: ULibReplicatedCvarChanged

	Called *on both client and server* when a replicated cvar changes or is created.

	Parameters passed to callback:

		sv_cvar - The name of the server-side cvar.
		cl_cvar - The name of the client-side cvar.
		ply - The player changing the cvar or nil on initial value.
		old_value - The previous value of the cvar, nil if this call is to set the initial value.
		new_value - The new value of the cvar.

	Revisions:

		v2.40 - Initial
		v2.50 - Removed nil on client side restriction.
]]
ULib.HOOK_REPCVARCHANGED = "ULibReplicatedCvarChanged"

--[[
	Hook: ULibLocalPlayerReady

	Called *on both client and server* when a player entity is created. (can now run commands). Only works for local
	player on the client side.

	Parameters passed to callback:

		ply - The player that's ready (local player on client side).

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_LOCALPLAYERREADY = "ULibLocalPlayerReady"

--[[
	Hook: ULibCommandCalled

	Called *on server* whenever a ULib command is run, return false to override and not allow, true to stop executing callbacks and allow.

	Parameters passed to callback:

		ply - The player attempting to execute the command.
		commandName - The command that's being executed.
		args - The table of args for the command.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_COMMAND_CALLED = "ULibCommandCalled"

--[[
	Hook: ULibPlayerTarget

	Called whenever one player is about to target another player. Called *BEFORE* any other validation
	takes place. Return false and error message to disallow target completely, return true to
	override any other validation logic and allow the target to take place, return a player to force
	the target to be the specified player.

	Parameters passed to callback:

		ply - The player attempting to execute the command.
		commandName - The command that's being executed.
		target - The proposed target of the command before any other validation logic takes place.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_PLAYER_TARGET = "ULibPlayerTarget"

--[[
	Hook: ULibPlayerTargets

	Called whenever one player is about to target another set of players. Called *BEFORE* any other validation
	takes place. Return false and error message to disallow target completely, return true to
	override any other validation logic and allow the target to take place, return a table of players to force
	the targets to be the specified players.

	Parameters passed to callback:

		ply - The player attempting to execute the command.
		commandName - The command that's being executed.
		targets - The proposed targets of the command before any other validation logic takes place.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_PLAYER_TARGETS = "ULibPlayerTargets" -- Exactly the same as the above but used when the player is using a command that can target multiple players.

--[[
	Hook: ULibPostTranslatedCommand

	*Server hook*. Called after a translated command (ULib.cmds.TranslatedCommand) has been successfully
	verified. This hook directly follows the callback for the command itself.

	Parameters passed to callback:

		ply - The player that executed the command.
		commandName - The command that's being executed.
		translated_args - A table of the translated arguments, as passed into the callback function itself.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_POST_TRANSLATED_COMMAND = "ULibPostTranslatedCommand"

--[[
	Hook: ULibPlayerNameChanged

	Called within one second of a player changing their name.

	Parameters passed to callback:

		ply - The player that changed names.
		oldName - The player's old name, before the change.
		newName - The player's new name, after the change.

	Revisions:

		v2.40 - Initial
]]
ULib.HOOK_PLAYER_NAME_CHANGED = "ULibPlayerNameChanged"

--[[
	Hook: ULibGetUsersCustomKeyword

	Called during ULib.getUsers when considering a target string for keywords.
	This could be used to create a new, custom keyword for targeting users who
	have been connected for less than five minutes, for example.
	Return nil or a table of player objects to add to the target list.

	Parameters passed to callback:

		target - A string chunk of a possibly larger target list to operate on.
		ply - The player doing the targeting, not always specified (can be nil).

	Revisions:

		v2.60 - Initial
]]
ULib.HOOK_GETUSERS_CUSTOM_KEYWORD = "ULibGetUsersCustomKeyword"

--[[
	Hook: ULibGetUserCustomKeyword

	Called during ULib.getUser when considering a target string for keywords.
	This could be used to create a new, custom keyword for always targeting a
	specific connected steamid, for example. Or, to target the shortest connected
	player.
	Return nil or a player object.

	Parameters passed to callback:

		target - A string target.
		ply - The player doing the targeting, not always specified (can be nil).

	Revisions:

		v2.60 - Initial
]]
ULib.HOOK_GETUSER_CUSTOM_KEYWORD = "ULibGetUserCustomKeyword"

--[[
	Hook: ULibPlayerKicked

	Called during ULib.kick.
	This alerts you to the player being kicked.

	Parameters passed to callback:

		steamid - String of SteamID of the kicked player.
		reason - String of kick reason or nil.
		caller - Player object of whomever did the kick or nil.

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_KICKED = "ULibPlayerKicked"

--[[
	Hook: ULibPlayerBanned

	Called during ULib.addBan.
	This alerts you to the player being banned.

	Parameters passed to callback:

		steamid - String of SteamID of the banned player.
		ban_data - The table data about the ban, exactly like it would be stored in ULib.bans.

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_BANNED = "ULibPlayerBanned"

--[[
	Hook: ULibPlayerUnBanned

	Called during ULib.unban.
	This alerts you to the player being banned.

	Parameters passed to callback:

		steamid - String of SteamID for the unbanned player.
		admin - The unbaning player object or nil.

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_UNBANNED = "ULibPlayerUnBanned"

--[[
	Hook: ULibGroupCreated

	Called during ULib.ucl.addGroup.
	This alerts you to the group being created.

	Parameters passed to callback:

		group_name - String of Group Name
		group_data - Group table as it is stored in ULib.ucl.groups[ name ].

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_CREATED = "ULibGroupCreated"

--[[
	Hook: ULibGroupRemoved

	Called during ULib.ucl.removeGroup.
	This alerts you to the group being removed.

	Parameters passed to callback:

		group_name - String of Group Name
		group_data - Group table as it is stored in ULib.ucl.groups[ name ].

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_REMOVED = "ULibGroupRemoved"

--[[
	Hook: ULibGroupAccessChanged

	Called during ULib.ucl.groupAllow.
	This alerts you to the group access being changed.

	Parameters passed to callback:

		group_name - String of Group Name
		access - String of access being changed
		revoke - Boolean, Are we adding(false/nil) or revoking(true)

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_ACCESS_CHANGE = "ULibGroupAccessChanged"

--[[
	Hook: ULibGroupRenamed

	Called during ULib.ucl.renameGroup.
	This alerts you to the group being renamed.

	Parameters passed to callback:

		old_name - String of Old Group Name
		new_name - String of New Group Name

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_RENAMED = "ULibGroupRenamed"

--[[
	Hook: ULibGroupInheritanceChanged

	Called during ULib.ucl.setGroupInheritance.
	This alerts you to the group Inheritance being changed.

	Parameters passed to callback:

		group_name - String of Group Name
		new_inherit - String of New Inheritance
		old_inherit - String of Old Inheritance

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_INHERIT_CHANGE = "ULibGroupInheritanceChanged"

--[[
	Hook: ULibGroupCanTargetChanged

	Called during ULib.ucl.setGroupCanTarget.
	This alerts you to the group CanTarget being changed.

	Parameters passed to callback:

		group_name - String of Group Name
		new_target - String of New CanTarget
		old_target - String of Old CanTarget

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_GROUP_CANTARGET_CHANGE = "ULibGroupCanTargetChanged"

--[[
	Hook: ULibUserGroupChange

	Called during ULib.ucl.addUser.
	This alerts you to the user's group being changed.

	Parameters passed to callback:

		id - String steamid of the user.
		allows - Allows Table
		denies - Denies Table
		new_group - String of New Group
		old_group - String of Old Group

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_GROUP_CHANGE = "ULibUserGroupChange"

--[[
	Hook: ULibUserAccessChange

	Called during ULib.ucl.userAllow.
	This alerts you to the user's access being changed.

	Parameters passed to callback:

	id - The string steamid of the user.
	access - The string of access being changed
	revoke - Boolean, are we adding(false/nil) or revoking(true)
	deny - Boolean, are we denying(true) or allowing(false/nil)

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_ACCESS_CHANGE = "ULibUserAccessChange"

--[[
	Hook: ULibUserRemoved

	Called during ULib.ucl.removeUser.
	This alerts you to the user's group being removed.

	Parameters passed to callback:

	id - The string steamid of the user.
	user_info - Table of old user info (group, allows, denys, etc) as stored in ULib.ucl.users[id] before the change.

	Revisions:

		v2.62 - Initial
]]
ULib.HOOK_USER_REMOVED = "ULibUserRemoved"

--[[
	Section: UCL Helpers

	These defines are server-only, to help with UCL.
]]
if SERVER then
ULib.UCL_LOAD_DEFAULT = true -- Set this to false to ignore the SetUserGroup() call.
ULib.UCL_USERS = "data/ulib/users.txt"
ULib.UCL_GROUPS = "data/ulib/groups.txt"
ULib.UCL_REGISTERED = "data/ulib/misc_registered.txt" -- Holds access strings that ULib has already registered

ULib.DEFAULT_GRANT_ACCESS = { allow={}, deny={}, guest=true }
end

--[[
	Section: Net pooled strings

	These defines are server-only, to help with the networking library.
]]
if SERVER then
	util.AddNetworkString( "URPC" )
end
