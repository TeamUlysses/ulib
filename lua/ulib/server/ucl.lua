--[[
	Title: UCL

	ULib's Access Control List

	Formatting Details:

		Format of admin account in users.txt--
		"<steamid|ip|unique id>"
		{
			"group" "superadmin"
			"allow"
			{
				"ulx kick"
				"ulx ban"
			}
			"deny"
			{
				"ulx cexec"
			}
		}

		Example of a superadmin--
		"STEAM_0:1:123456"
		{
			"group" "superadmin"
			"allow"
			{
			}
			"deny"
			{
			}
		}

		Format of group that gets the same allows as a superadmin in groups.txt--
		"<group_name>"
		{
			"allow"
			{
				"ulx kick"
				"ulx ban"
			}
			"inherit_from" "superadmin"
		}
]]

local ucl = ULib.ucl -- Make it easier for us to refer to

local backups_to_keep = 30

local defaultGroupsText = -- To populate initially or when the user deletes it
[["operator"
{
	"allow"
	{
	}
	"can_target"    "!%admin"
}

"admin"
{
	"allow"
	{
	}
	"inherit_from"	"operator"
	"can_target"    "!%superadmin"
}

"superadmin"
{
	"allow"
	{
	}
	"inherit_from"	"admin"
}

"user"
{
	"allow"
	{
	}
}
]]

local accessStrings = ULib.parseKeyValues( ULib.fileRead( ULib.UCL_REGISTERED ) or "" ) or {}
local accessCategories = {}
ULib.ucl.accessStrings = accessStrings
ULib.ucl.accessCategories = accessCategories

if not ULib.fileExists( ULib.UCL_GROUPS, true ) then
	ULib.fileWrite( ULib.UCL_GROUPS, defaultGroupsText )

	if ULib.fileExists( ULib.UCL_REGISTERED ) then
		ULib.fileDelete( ULib.UCL_REGISTERED ) -- Since we're regnerating we'll need to remove this
	end
	table.Empty( accessStrings )
	table.Empty( accessCategories )
end

-- Helper function to save access string registration to misc_registered.txt
local function saveAccessStringRegistration()
	ULib.fileWrite( ULib.UCL_REGISTERED, ULib.makeKeyValues( accessStrings ) )
end

-- Save what we've got with ucl.groups so far!
function ucl.saveGroups()
	for _, groupInfo in pairs( ucl.groups ) do
		table.sort( groupInfo.allow )
	end

	ULib.fileWrite( ULib.UCL_GROUPS, ULib.makeKeyValues( ucl.groups ) )
end

function ucl.saveUsers()
	for steamid, userInfo in pairs( ucl.users ) do
		ucl.saveUser(steamid, userInfo)
	end
end

local isFirstTimeDBSetup = false
local function generateUserDB()
	if not sql.TableExists("ulib_users") then
		sql.Query([[
			CREATE TABLE IF NOT EXISTS ulib_users (
				steamid TEXT NOT NULL PRIMARY KEY,
				name TEXT NULL,
				usergroup TEXT NOT NULL DEFAULT "user",
				allow TEXT,
				deny TEXT
			);
		]])
		isFirstTimeDBSetup = true
	end
end
generateUserDB()

local function escape(str)
	return sql.SQLStr(str, true)
end

function ucl.saveUser( steamid, userInfo )
	if not userInfo then
		userInfo = ucl.users[ steamid ]
	end

	table.sort( userInfo.allow )
	table.sort( userInfo.deny )
	local allow, deny = util.TableToJSON( userInfo.allow ), util.TableToJSON( userInfo.deny )

	sql.Query(string.format([[
		REPLACE INTO ulib_users
			(steamid, name, usergroup, allow, deny)
		VALUES
			('%s', '%s', '%s', '%s', '%s');
	]], escape( steamid ), escape( userInfo.name or "" ), escape( userInfo.group ), escape( allow ), escape( deny )))
end

function ucl.deleteUser( steamid )
	sql.Query(string.format([[
		DELETE FROM
			ulib_users
		WHERE
			steamid = '%s'
	]], escape( steamid )))
end

function ucl.deleteUsers()
	sql.Query([[DELETE FROM ulib_users;]])
end

local function reloadGroups()
	-- Try to read from the safest locations first
	local noMount = true
	local path = ULib.UCL_GROUPS
	if not ULib.fileExists( path, noMount ) then
		ULib.fileWrite( path, defaultGroupsText )

		if ULib.fileExists( ULib.UCL_REGISTERED ) then
			ULib.fileDelete( ULib.UCL_REGISTERED ) -- Since we're regnerating we'll need to remove this
		end
		table.Empty( accessStrings )
		table.Empty( accessCategories )
	end

	local needsBackup = false
	local err
	ucl.groups, err = ULib.parseKeyValues( ULib.removeCommentHeader( ULib.fileRead( path, noMount ) or "", "/" ) )

	if not ucl.groups or not ucl.groups[ ULib.ACCESS_ALL ] then
		needsBackup = true
		-- Totally messed up! Clear it.
		local err2
		ucl.groups, err2 = ULib.parseKeyValues( ULib.removeCommentHeader( defaultGroupsText, "/" ) )

		if ULib.fileExists( ULib.UCL_REGISTERED ) then
			ULib.fileDelete( ULib.UCL_REGISTERED ) -- Since we're regnerating we'll need to remove this
		end
		table.Empty( accessStrings )
		table.Empty( accessCategories )

	else
		-- Check to make sure it passes a basic validity test
		ucl.groups[ ULib.ACCESS_ALL ].inherit_from = nil -- Ensure this is the case
		for groupName, groupInfo in pairs( ucl.groups ) do
			if type( groupName ) ~= "string" then
				needsBackup = true
				ucl.groups[ groupName ] = nil
			else

				if type( groupInfo ) ~= "table" then
					needsBackup = true
					groupInfo = {}
					ucl.groups[ groupName ] = groupInfo
				end

				if type( groupInfo.allow ) ~= "table" then
					needsBackup = true
					groupInfo.allow = {}
				end

				local inherit_from = groupInfo.inherit_from
				if inherit_from and inherit_from ~= "" and not ucl.groups[ groupInfo.inherit_from ] then
					needsBackup = true
					groupInfo.inherit_from = nil
				end

				-- Check for cycles
				local group = ucl.groupInheritsFrom( groupName )
				while group do
					if group == groupName then
						needsBackup = true
						groupInfo.inherit_from = nil
					end
					group = ucl.groupInheritsFrom( group )
				end

				if groupName ~= ULib.ACCESS_ALL and not groupInfo.inherit_from or groupInfo.inherit_from == "" then
					groupInfo.inherit_from = ULib.ACCESS_ALL -- Clean :)
				end

				-- Lower case'ify
				for k, v in pairs( groupInfo.allow ) do
					if type( k ) == "string" and k:lower() ~= k then
						groupInfo.allow[ k:lower() ] = v
						groupInfo.allow[ k ] = nil
					else
						groupInfo.allow[ k ] = v
					end
				end
			end
		end
	end

	if needsBackup then
		Msg( "Groups file was not formatted correctly. Attempting to fix and backing up original\n" )
		if err then
			Msg( "Error while reading groups file was: " .. err .. "\n" )
		end
		Msg( "Original file was backed up to " .. ULib.backupFile( ULib.UCL_GROUPS ) .. "\n" )
		ucl.saveGroups()
	end
end
reloadGroups()

local function loadUsersFromDB()
	-- No cap, the sqlite errors should always be reset when making a new query.
	sql.m_strError = nil
	local users = sql.Query( "SELECT * FROM ulib_users;" )
	if not users then
		local err = sql.LastError()
		if err then
			Msg( "The users database failed to load.\n" )
			Msg( "Error while querying database was: " .. err .. "\n" )
			return false
		else
			return {}
		end
	end

	local out = {}
	for _, row in ipairs(users) do
		out[row.steamid] = {name = row.name, group = row.usergroup, allow = util.JSONToTable(row.allow) or {}, deny = util.JSONToTable(row.deny) or {}}
	end

	return out
end

local function reloadUsers()
	local runningFromDB = false
	local needsBackup = false
	local err

	-- Start by trying to read from the DB.
	if not isFirstTimeDBSetup then
		ucl.users = loadUsersFromDB()
		if ucl.users then
			runningFromDB = true
		end
	end

	-- Next, read from the users file.
	if not runningFromDB then
		local noMount = true
		local path = ULib.UCL_USERS

		if not ULib.fileExists( path, noMount ) then
			ULib.fileWrite( path, "" )
		end

		ucl.users, err = ULib.parseKeyValues( ULib.removeCommentHeader( ULib.fileRead( path, noMount ) or "", "/" ) )
	end

	-- Check to make sure it passes a basic validity test
	if not ucl.users then
		needsBackup = true
		-- Totally messed up! Clear it.
		ucl.users = {}
		if runningFromDB then
			ucl.deleteUsers()
		end
	else
		for id, userInfo in pairs( ucl.users ) do
			if type( id ) ~= "string" then
				needsBackup = true
				ucl.users[ id ] = nil
			else

				if type( userInfo ) ~= "table" then
					needsBackup = true
					userInfo = {}
					ucl.users[ id ] = userInfo
				end

				if type( userInfo.allow ) ~= "table" then
					needsBackup = true
					userInfo.allow = {}
				end

				if type( userInfo.deny ) ~= "table" then
					needsBackup = true
					userInfo.deny = {}
				end

				if userInfo.group and type( userInfo.group ) ~= "string" then
					needsBackup = true
					userInfo.group = nil
				end

				if userInfo.name and type( userInfo.name ) ~= "string" then
					needsBackup = true
					userInfo.name = nil
				end

				if userInfo.group == "" then userInfo.group = nil end -- Clean :)

				-- Lower case'ify
				for k, v in pairs( userInfo.allow ) do
					if type( k ) == "string" and k:lower() ~= k then
						userInfo.allow[ k:lower() ] = v
						userInfo.allow[ k ] = nil
					else
						userInfo.allow[ k ] = v
					end
				end

				for k, v in ipairs( userInfo.deny ) do
					if type( k ) == "string" and type( v ) == "string" then -- This isn't allowed here
						table.insert( userInfo.deny, k )
						userInfo.deny[ k ] = nil
					else
						userInfo.deny[ k ] = v
					end
				end
			end
		end
	end

	if needsBackup then
		if runningFromDB then
			Msg( "There was bad data returned from the database. Attempting to fix, though some data may be lost.\n" )
			ucl.deleteUsers()
		else
			Msg( "Users file was not formatted correctly. Attempting to fix and backing up original\n" )
			if err then
				Msg( "Error while reading users file was: " .. err .. "\n" )
			end
			Msg( "Original file was backed up to " .. ULib.backupFile( ULib.UCL_USERS ) .. "\n" )
		end
		ucl.saveUsers()
	elseif isFirstTimeDBSetup then
		isFirstTimeDBSetup = false
		Msg( "Migrating users file to users database.\n" )
		ucl.saveUsers()
	end
end
reloadUsers()

-- === UCL users backup (startup + on-demand, debug) ===
-- Writes to data/ulib_backups/users_YYYYMMDD_HHMMSS.txt
-- Keeps the newest 10 backups.

if SERVER then
	_G.__UCL_USERS_BACKUP_DONE = _G.__UCL_USERS_BACKUP_DONE or false

	local function log(msg) MsgN("[ULib UCL] " .. msg) end

	local function serializeUsers(tbl)
		-- Prefer ULib's KeyValues for human-readable snapshots,
		-- but fall back to JSON if anything goes weird.
		local ok, out = pcall(function() return ULib.makeKeyValues(tbl or {}) end)
		if ok and type(out) == "string" and #out > 0 then return out end
		log("KeyValues serialization failed, falling back to JSON.")
		return util.TableToJSON(tbl or {}, true) or "{}"
	end

	local function doBackup()
		log("Starting users backup…")

		-- Ensure directory exists in DATA
		local dir = "ulib_backups"
		if not file.IsDir(dir, "DATA") then
			log("Creating data/" .. dir .. " …")
			file.CreateDir(dir)
		end

		-- Prepare content
		if type(ucl.users) ~= "table" then
			log("Warning: ucl.users is not a table; writing empty snapshot.")
		end
		local snapshot = serializeUsers(ucl.users)

		-- Timestamped filename (UTC to keep names sortable + stable)
		local stamp = os.date("!%Y%m%d_%H%M%S")
		local rel   = string.format("%s/users_%s.txt", dir, stamp)

		-- Write file (with error guard)
		local ok, err = pcall(function() file.Write(rel, snapshot) end)
		if not ok then
			log("ERROR: file.Write failed: " .. tostring(err))
			return
		end

		log("Backup written: data/" .. rel)

		-- Prune old backups, keep newest
		local files = file.Find(dir .. "/users_*.txt", "DATA") or {}
		table.sort(files, function(a, b)
			local ta = file.Time(dir .. "/" .. a, "DATA") or 0
			local tb = file.Time(dir .. "/" .. b, "DATA") or 0
			if ta ~= tb then return ta > tb end
			return a > b
		end)

		for i = backups_to_keep + 1, #files do
			file.Delete(dir .. "/" .. files[i])
		end
		if #files > backups_to_keep then
			log("Pruned " .. tostring(#files - backups_to_keep) .. " old backup(s).")
		end
	end

	local function backupUsersOnce(force)
		if force then
			log("Force flag detected; bypassing once-per-boot guard.")
			doBackup()
			return
		end
		if _G.__UCL_USERS_BACKUP_DONE then
			log("Skipping: backup already performed this boot. Use 'ucl_backup_users force' to override.")
			return
		end
		_G.__UCL_USERS_BACKUP_DONE = true
		doBackup()
	end

	-- Run once on startup/file load
	backupUsersOnce(false)

	-- Server console OR listen-server host only
	concommand.Add("ucl_backup_users", function(ply, cmd, args, argStr)
		-- Dedicated server console: ply == nil
		-- Listen server host: valid ply, ply:IsListenServerHost() == true
		if IsValid(ply) and not ply:IsListenServerHost() then
			ply:PrintMessage(HUD_PRINTCONSOLE, "[ULib UCL] This command can only be run by the SERVER CONSOLE or the LISTEN SERVER HOST.\n")
			log(("Denied non-host player '%s' from running %s"):format(ply:Nick(), cmd))
			return
		end

		local a = (args[1] or ""):lower()
		local force = (a == "force" or a == "1" or a == "true" or a == "yes")

		log(("Command received from %s; force=%s"):format(IsValid(ply) and "listen-server host" or "server console", tostring(force)))
		backupUsersOnce(force)
	end, nil, "Back up UCL users to data/ulib_backups (server console or listen server host only).")
end

-- === UCL users restore (from data/ulib_backups) ===
-- Usage:
--   ucl_restore_users latest
--   ucl_restore_users users_YYYYMMDD_HHMMSS.txt
-- Notes:
--   - Overwrites in-memory ULib.ucl.users
--   - Clears DB rows, then saves backup to DB via ucl.saveUsers()
--   - Re-probes connected players for correct live permissions

if SERVER then
	-- Reuse the same dir as the backup block
	local UCL_BACKUP_DIR = "ulib_backups"

	-- If the earlier block defined a log() helper, reuse it; otherwise define a minimal one
	local function _default_log(msg) MsgN("[ULib UCL] " .. msg) end
	local log = rawget(_G, "__UCL_USERS_LOG") or _default_log

	-- Helper: list backups newest-first
	local function listBackupsSorted()
		local files = file.Find(UCL_BACKUP_DIR .. "/users_*.txt", "DATA") or {}
		table.sort(files, function(a, b)
			local ta = file.Time(UCL_BACKUP_DIR .. "/" .. a, "DATA") or 0
			local tb = file.Time(UCL_BACKUP_DIR .. "/" .. b, "DATA") or 0
			if ta ~= tb then return ta > tb end
			return a > b
		end)
		return files
	end

	-- Helper: parse a backup file (KeyValues first, JSON fallback)
	local function parseBackup(relpath)
		local full = relpath
		local contents = file.Read(full, "DATA")
		if not contents or contents == "" then
			return nil, "file empty or unreadable"
		end

		-- Try KeyValues (what ULib.makeKeyValues wrote)
		do
			local ok, tbl = pcall(function()
				-- Backups have no comment header, but remove anyway (safe)
				return ULib.parseKeyValues(ULib.removeCommentHeader(contents, "/"))
			end)
			if ok and type(tbl) == "table" then
				return tbl
			end
		end

		-- Fallback: JSON (what we write if KV failed on backup)
		do
			local ok, tbl = pcall(function()
				return util.JSONToTable(contents)
			end)
			if ok and type(tbl) == "table" then
				return tbl
			end
		end

		return nil, "unrecognized format (neither KeyValues nor JSON)"
	end

	-- Helper: very light validation/sanitization
	local function sanitizeUsersTable(t)
		if type(t) ~= "table" then return {} end
		for id, info in pairs(t) do
			if type(id) ~= "string" or type(info) ~= "table" then
				t[id] = nil
			else
				if type(info.allow) ~= "table" then info.allow = {} end
				if type(info.deny)  ~= "table" then info.deny  = {} end
				if info.group ~= nil and type(info.group) ~= "string" then info.group = nil end
				if info.name  ~= nil and type(info.name)  ~= "string" then info.name  = nil end
				-- canonicalize case on allow/deny
				for k, v in pairs(info.allow) do
					if type(v) == "string" then info.allow[k] = v:lower() end
				end
				for k, v in pairs(info.deny) do
					if type(v) == "string" then info.deny[k] = v:lower() end
				end
			end
		end
		return t
	end

	-- Restore procedure
	local function restoreFromBackup(filename)
		if not file.IsDir(UCL_BACKUP_DIR, "DATA") then
			return false, "backup directory does not exist"
		end

		local targetRel
		if not filename or filename == "" or filename == "latest" then
			local ordered = listBackupsSorted()
			if #ordered == 0 then
				return false, "no backups found"
			end
			targetRel = UCL_BACKUP_DIR .. "/" .. ordered[1]
		else
			-- sanitize slashes; only allow files under our dir
			filename = filename:gsub("\\", "/")
			if not filename:find("^users_%d+_%d+%.txt$") then
				-- allow either "users_YYYYMMDD_HHMMSS.txt" or full relative with dir
				filename = filename:match("users_%d+_%d+%.txt") or filename
			end
			targetRel = UCL_BACKUP_DIR .. "/" .. filename
			if not file.Exists(targetRel, "DATA") then
				return false, ("backup file not found: %s"):format(filename)
			end
		end

		log("Restoring users from data/" .. targetRel .. " …")

		-- Load + parse
		local tbl, perr = parseBackup(targetRel)
		if not tbl then
			return false, "parse failed: " .. tostring(perr)
		end
		tbl = sanitizeUsersTable(tbl)

		-- Overwrite in-memory users table
		ULib.ucl.users = tbl
		ucl.users = tbl -- alias in this file’s scope

		-- Reset DB and save fresh snapshot
		if ucl.deleteUsers then
			ucl.deleteUsers()
		end

		-- saveUsers() sorts allow lists and writes DB rows via ucl.saveUser()
		ucl.saveUsers()

		-- Re-probe connected players so live permissions update immediately
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				ucl.probe(ply)
			end
		end

		log("Restore complete. Users table loaded and database updated.")
		return true
	end

	-- Console command: server console OR listen-server host only
	--   ucl_restore_users latest
	--   ucl_restore_users users_YYYYMMDD_HHMMSS.txt
	concommand.Add("ucl_restore_users", function(ply, cmd, args, argStr)
		-- Dedicated server: ply == nil
		-- Listen host: valid ply AND ply:IsListenServerHost()
		if IsValid(ply) and not ply:IsListenServerHost() then
			ply:PrintMessage(HUD_PRINTCONSOLE, "[ULib UCL] This command can only be run by the SERVER CONSOLE or the LISTEN SERVER HOST.\n")
			log(("Denied non-host player '%s' from running %s"):format(ply:Nick(), cmd))
			return
		end

		local which = args[1] or "latest"
		log(("Restore command from %s; target=%s"):format(IsValid(ply) and "listen-server host" or "server console", which))

		local ok, err = restoreFromBackup(which)
		if not ok then
			log("RESTORE ERROR: " .. tostring(err))
			if IsValid(ply) then
				ply:PrintMessage(HUD_PRINTCONSOLE, "[ULib UCL] Restore failed: " .. tostring(err) .. "\n")
			end
			return
		end

		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "[ULib UCL] Restore complete.\n")
		end
	end, nil, "Restore UCL users from a backup file (server console or listen server host only).")
end

-- === Drop UCL users database table (with confirmation) ===
-- Usage: ucl_drop_users_db CONFIRM
-- Effect: Drops the SQLite table `ulib_users`
--         On next reload, it will be re-imported from users.txt
-- Security: Only dedicated server console or listen-server host may run this

if SERVER then
	local function dropUsersTable()
		MsgN("[ULib UCL] Dropping ulib_users table …")
		local ok, err = pcall(function()
			sql.Query("DROP TABLE IF EXISTS ulib_users;")
		end)
		if not ok then
			MsgN("[ULib UCL] ERROR while dropping users table: " .. tostring(err))
			return false
		end
		MsgN("[ULib UCL] ulib_users table dropped successfully.")
		return true
	end

	concommand.Add("ucl_drop_users_db", function(ply, cmd, args, argStr)
		-- Dedicated server console: ply == nil
		-- Listen server host: valid ply and ply:IsListenServerHost()
		if IsValid(ply) and not ply:IsListenServerHost() then
			ply:PrintMessage(HUD_PRINTCONSOLE,
				"[ULib UCL] This command can only be run by the SERVER CONSOLE or the LISTEN SERVER HOST.\n")
			MsgN("[ULib UCL] Denied non-host player '" .. ply:Nick() .. "' from running " .. cmd)
			return
		end

		-- Require explicit CONFIRM
		if (args[1] or ""):upper() ~= "CONFIRM" then
			MsgN("[ULib UCL] Refusing to drop table. You must run: ucl_drop_users_db CONFIRM")
			if IsValid(ply) then
				ply:PrintMessage(HUD_PRINTCONSOLE,
					"[ULib UCL] Refusing to drop table. You must run: ucl_drop_users_db CONFIRM\n")
			end
			return
		end

		local ok = dropUsersTable()
		if ok and IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE,
				"[ULib UCL] ulib_users table dropped. Restart or reload to re-import from legacy users.txt\n")
		end
	end, nil, "Drop the ulib_users table (requires CONFIRM).")
end




--[[
	Function: ucl.addGroup

	Adds a new group to the UCL. Automatically saves.

	Parameters:

		name - A string of the group name. (IE: superadmin)
		allows - *(Optional, defaults to empty table)* The allowed access for the group.
		inherit_from - *(Optional)* A string of a valid group to inherit from
		from_CAMI - *(Optional)* An indicator for this group coming from CAMI.

	Revisions:

		v2.10 - acl is now an options parameter, added inherit_from.
		v2.40 - Rewrite, changed parameter list around.
		v2.60 - Added CAMI support and parameter.
]]
function ucl.addGroup( name, allows, inherit_from, from_CAMI )
	ULib.checkArg( 1, "ULib.ucl.addGroup", "string", name )
	ULib.checkArg( 2, "ULib.ucl.addGroup", {"nil","table"}, allows )
	ULib.checkArg( 3, "ULib.ucl.addGroup", {"nil","string"}, inherit_from )
	allows = allows or {}
	inherit_from = inherit_from or "user"

	if ucl.groups[ name ] then return error( "Group already exists, cannot add again (" .. name .. ")", 2 ) end
	if inherit_from then
		if inherit_from == name then return error( "Group cannot inherit from itself", 2 ) end
		if not ucl.groups[ inherit_from ] then return error( "Invalid group for inheritance (" .. tostring( inherit_from ) .. ")", 2 ) end
	end

	-- Lower case'ify
	for k, v in ipairs( allows ) do allows[ k ] = v:lower() end

	ucl.groups[ name ] = { allow=allows, inherit_from=inherit_from }
	ucl.saveGroups()

	hook.Call( ULib.HOOK_GROUP_CREATED, _, name, ucl.groups[ name ] )
	hook.Call( ULib.HOOK_UCLCHANGED )

	-- CAMI logic
	if not from_CAMI and not ULib.findInTable( {"superadmin", "admin", "user"}, name ) then
		CAMI.RegisterUsergroup( {Name=name, Inherits=inherit_from}, CAMI.ULX_TOKEN )
	end
end


--[[
	Function: ucl.groupAllow

	Adds or removes an access tag in the allows for a group. Automatically reprobes, automatically saves.

	Parameters:

		name - A string of the group name. (IE: superadmin)
		access - The string of the access or a table of accesses to add or remove. Access tags can be specified in values in the table for allows.
		revoke - *(Optional, defaults to false)* A boolean of whether access should be granted or revoked.

	Returns:

		A boolean stating whether you changed anything or not.

	Revisions:

		v2.40 - Initial.
]]
function ucl.groupAllow( name, access, revoke )
	ULib.checkArg( 1, "ULib.ucl.groupAllow", "string", name )
	ULib.checkArg( 2, "ULib.ucl.groupAllow", {"string","table"}, access )
	ULib.checkArg( 3, "ULib.ucl.groupAllow", {"nil","boolean"}, revoke )

	if type( access ) == "string" then access = { access } end
	if not ucl.groups[ name ] then return error( "Group does not exist for changing access (" .. name .. ")", 2 ) end

	local allow = ucl.groups[ name ].allow

	local changed = false
	for k, v in pairs( access ) do
		local access = v:lower()
		local accesstag
		if type( k ) == "string" then
			accesstag = v
			access = k:lower()
		end

		if not revoke and (allow[ access ] ~= accesstag or (not accesstag and not ULib.findInTable( allow, access ))) then
			changed = true
			if not accesstag then
				table.insert( allow, access )
				allow[ access ] = nil -- Ensure no access tag
			else
				allow[ access ] = accesstag
				if ULib.findInTable( allow, access ) then -- Ensure removal of non-access tag version
					table.remove( allow, ULib.findInTable( allow, access ) )
				end
			end
		elseif revoke and (allow[ access ] or ULib.findInTable( allow, access )) then
			changed = true

			allow[ access ] = nil -- Remove any accessTags
			if ULib.findInTable( allow, access ) then
				table.remove( allow, ULib.findInTable( allow, access ) )
			end
		end
	end

	if changed then
		for id, userInfo in pairs( ucl.authed ) do
			local ply = ULib.getPlyByID( id )
			if ply and ply:CheckGroup( name ) then
				ULib.queueFunctionCall( hook.Call, ULib.HOOK_UCLAUTH, _, ply ) -- Inform the masses
			end
		end

		ucl.saveGroups()

		hook.Call( ULib.HOOK_GROUP_ACCESS_CHANGE, _, name, access, revoke )
		hook.Call( ULib.HOOK_UCLCHANGED )
	end

	return changed
end


--[[
	Function: ucl.renameGroup

	Renames a group in the UCL. Automatically moves current members, automatically renames inheritances, automatically saves.

	Parameters:

		orig - A string of the original group name. (IE: superadmin)
		new - A string of the new group name. (IE: owner)

	Revisions:

		v2.40 - Initial.
		v2.60 - Added CAMI support.
]]
function ucl.renameGroup( orig, new )
	ULib.checkArg( 1, "ULib.ucl.renameGroup", "string", orig )
	ULib.checkArg( 2, "ULib.ucl.renameGroup", "string", new )

	if orig == ULib.ACCESS_ALL then return error( "This group (" .. orig .. ") cannot be renamed!", 2 ) end
	if not ucl.groups[ orig ] then return error( "Group does not exist for renaming (" .. orig .. ")", 2 ) end
	if ucl.groups[ new ] then return error( "Group already exists, cannot rename (" .. new .. ")", 2 ) end

	for id, userInfo in pairs( ucl.users ) do
		if userInfo.group == orig then
			userInfo.group = new
		end
	end

	for id, userInfo in pairs( ucl.authed ) do
		local ply = ULib.getPlyByID( id )
		if ply and ply:CheckGroup( orig ) then
			if ply:GetUserGroup() == orig then
				ULib.queueFunctionCall( ply.SetUserGroup, ply, new ) -- Queued so group will be removed
			else
				ULib.queueFunctionCall( hook.Call, ULib.HOOK_UCLAUTH, _, ply ) -- Inform the masses
			end
		end
	end

	ucl.groups[ new ] = ucl.groups[ orig ] -- Copy!
	ucl.groups[ orig ] = nil

	for _, groupInfo in pairs( ucl.groups ) do
		if groupInfo.inherit_from == orig then
			groupInfo.inherit_from = new
		end
	end

	ucl.saveUsers()
	ucl.saveGroups()

	hook.Call( ULib.HOOK_GROUP_RENAMED, _, orig, new )
	hook.Call( ULib.HOOK_UCLCHANGED )

	-- CAMI logic
	if not ULib.findInTable( {"superadmin", "admin", "user"}, orig ) then
		CAMI.UnregisterUsergroup( orig, CAMI.ULX_TOKEN )
	end
	if not ULib.findInTable( {"superadmin", "admin", "user"}, new ) then
		CAMI.RegisterUsergroup( {Name=new, Inherits=ucl.groups[ new ].inherit_from}, CAMI.ULX_TOKEN )
	end
end


--[[
	Function: ucl.setGroupInheritance

	Sets a group's inheritance in the UCL. Automatically reprobes current members, automatically saves.

	Parameters:

		group - A string of the group name. (IE: superadmin)
		inherit_from - Either a string of the new inheritance group name or nil to remove inheritance. (IE: admin)
		from_CAMI - *(Optional)* An indicator for this group coming from CAMI.

	Revisions:

		v2.40 - Initial.
		v2.60 - Added CAMI support and parameter.
]]
function ucl.setGroupInheritance( group, inherit_from, from_CAMI )
	ULib.checkArg( 1, "ULib.ucl.renameGroup", "string", group )
	ULib.checkArg( 2, "ULib.ucl.renameGroup", {"nil","string"}, inherit_from )
	inherit_from = inherit_from or "user"

	if group == ULib.ACCESS_ALL then return error( "This group (" .. group .. ") cannot have its inheritance changed!", 2 ) end
	if not ucl.groups[ group ] then return error( "Group does not exist (" .. group .. ")", 2 ) end
	if inherit_from and not ucl.groups[ inherit_from ] then return error( "Group for inheritance does not exist (" .. inherit_from .. ")", 2 ) end

	-- Check for cycles
	local old_inherit = ucl.groups[ group ].inherit_from
	ucl.groups[ group ].inherit_from = inherit_from -- Temporary!
	local groupCheck = ucl.groupInheritsFrom( group )
	while groupCheck do
		if groupCheck == group then -- Got back to ourselves. This is bad.
			ucl.groups[ group ].inherit_from = old_inherit -- Set it back
			error( "Changing group \"" .. group .. "\" inheritance to \"" .. inherit_from .. "\" would cause cyclical inheritance. Aborting.", 2 )
		end
		groupCheck = ucl.groupInheritsFrom( groupCheck )
	end
	ucl.groups[ group ].inherit_from = old_inherit -- Set it back

	if old_inherit == inherit_from then return end -- Nothing to change

	for id, userInfo in pairs( ucl.authed ) do
		local ply = ULib.getPlyByID( id )
		if ply and ply:CheckGroup( group ) then
			ULib.queueFunctionCall( hook.Call, ULib.HOOK_UCLAUTH, _, ply ) -- Queued so group will be changed
		end
	end

	ucl.groups[ group ].inherit_from = inherit_from

	ucl.saveGroups()

	hook.Call( ULib.HOOK_GROUP_INHERIT_CHANGE, _, group, inherit_from, old_inherit )
	hook.Call( ULib.HOOK_UCLCHANGED )

	-- CAMI logic
	if not from_CAMI and not ULib.findInTable( {"superadmin", "admin", "user"}, group ) then
		CAMI.UnregisterUsergroup( group, CAMI.ULX_TOKEN )
		CAMI.RegisterUsergroup( {Name=group, Inherits=inherit_from}, CAMI.ULX_TOKEN )
	end
end


--[[
	Function: ucl.setGroupCanTarget

	Sets what a group is allowed to target in the UCL. Automatically saves.

	Parameters:

		group - A string of the group name. (IE: superadmin)
		can_target - Either a string of who the group is allowed to target (IE: !%admin) or nil to clear the restriction.

	Revisions:

		v2.40 - Initial.
]]
function ucl.setGroupCanTarget( group, can_target )
	ULib.checkArg( 1, "ULib.ucl.setGroupCanTarget", "string", group )
	ULib.checkArg( 2, "ULib.ucl.setGroupCanTarget", {"nil","string"}, can_target )
	if not ucl.groups[ group ] then return error( "Group does not exist (" .. group .. ")", 2 ) end

	if ucl.groups[ group ].can_target == can_target then return end -- Nothing to change
	local old = ucl.groups[ group ].can_target
	ucl.groups[ group ].can_target = can_target

	hook.Call( ULib.HOOK_GROUP_CANTARGET_CHANGE, _, group, can_target, old )

	ucl.saveGroups()

	hook.Call( ULib.HOOK_UCLCHANGED )
end


--[[
	Function: ucl.removeGroup

	Removes a group from the UCL. Automatically removes this group from members in it, automatically patches inheritances, automatically saves.

	Parameters:

		name - A string of the group name. (IE: superadmin)
		from_CAMI - *(Optional)* An indicator for this group coming from CAMI.

	Revisions:

		v2.10 - Initial.
		v2.40 - Rewrite, removed write parameter.
		v2.60 - Added CAMI support and parameter.
]]
function ucl.removeGroup( name, from_CAMI )
	ULib.checkArg( 1, "ULib.ucl.removeGroup", "string", name )

	if name == ULib.ACCESS_ALL then return error( "This group (" .. name .. ") cannot be removed!", 2 ) end
	if not ucl.groups[ name ] then return error( "Group does not exist for removing (" .. name .. ")", 2 ) end

	local inherits_from = ucl.groupInheritsFrom( name )
	if inherits_from == ULib.ACCESS_ALL then inherits_from = nil end -- Easier

	for id, userInfo in pairs( ucl.users ) do
		if userInfo.group == name then
			userInfo.group = inherits_from
		end
	end

	for id, userInfo in pairs( ucl.authed ) do
		local ply = ULib.getPlyByID( id )
		if ply and ply:CheckGroup( name ) then
			if ply:GetUserGroup() == name then
				ULib.queueFunctionCall( ply.SetUserGroup, ply, inherits_from or ULib.ACCESS_ALL ) -- Queued so group will be removed
			else
				ULib.queueFunctionCall( hook.Call, ULib.HOOK_UCLAUTH, _, ply ) -- Inform the masses
			end
		end
	end
	local oldgroup = table.Copy( ucl.groups[ name ] )
	ucl.groups[ name ] = nil
	for _, groupInfo in pairs( ucl.groups ) do
		if groupInfo.inherit_from == name then
			groupInfo.inherit_from = inherits_from
		end
	end

	ucl.saveUsers()
	ucl.saveGroups()

	hook.Call( ULib.HOOK_GROUP_REMOVED, _, name, oldgroup )
	hook.Call( ULib.HOOK_UCLCHANGED )

	-- CAMI logic
	if not from_CAMI and not ULib.findInTable( {"superadmin", "admin", "user"}, name ) then
		CAMI.UnregisterUsergroup( name, CAMI.ULX_TOKEN )
	end
end

--[[
	Function: ucl.getUserRegisteredID

	Returns the SteamID, IP, or UniqueID of a player if they're registered under any of those IDs under ucl.users. Checks in order. Returns nil if not registered.

	Parameters:

		ply - The player object you wish to check.

	Revisions:

		v2.41 - Initial.
]]

function ucl.getUserRegisteredID( ply )
	local id = ply:SteamID()
	local uid = ply:UniqueID()
	local ip = ULib.splitPort( ply:IPAddress() )
	local checkIndexes = { id, ip, uid }
	for _, index in ipairs( checkIndexes ) do
		if ULib.ucl.users[ index ] then
			return id
		end
	end
end

--[[
	Function: ucl.getUserInfoFromID

	Returns a table containing the name and group of a player in the UCL table of users if they exist.

	Parameters:

		id - The SteamID, IP, or UniqueID of the user you wish to check.
]]

function ucl.getUserInfoFromID( id )

	ULib.checkArg( 1, "ULib.ucl.addUser", "string", id )
	id = id:upper() -- In case of steamid, needs to be upper case

	if ucl.users[ id ] then
		return ucl.users[ id ]
	else
		return nil
	end

end

--[[
	Function: ucl.addUser

	Adds a user to the UCL. Automatically probes for the user, automatically saves.

	Parameters:

		id - The SteamID, IP, or UniqueID of the user you wish to add.
		allows - *(Optional, defaults to empty table)* The list of access you wish to give this user.
		denies - *(Optional, defaults to empty table)* The list of access you wish to explicitly deny this user.
		group - *(Optional)* The string of the group this user should belong to. Must be a valid group.
		from_CAMI - *(Optional)* An indicator for this information coming from CAMI.

	Revisions:

		v2.10 - No longer makes a group if it doesn't exist.
		v2.40 - Rewrite, changed the arguments all around.
		v2.60 - Added support for CAMI and parameter.
]]
function ucl.addUser( id, allows, denies, group, from_CAMI )
	ULib.checkArg( 1, "ULib.ucl.addUser", "string", id )
	ULib.checkArg( 2, "ULib.ucl.addUser", {"nil","table"}, allows )
	ULib.checkArg( 3, "ULib.ucl.addUser", {"nil","table"}, denies )
	ULib.checkArg( 4, "ULib.ucl.addUser", {"nil","string"}, group )

	id = id:upper() -- In case of steamid, needs to be upper case
	allows = allows or {}
	denies = denies or {}
	if allows == ULib.DEFAULT_GRANT_ACCESS.allow then allows = table.Copy( allows ) end -- Otherwise we'd be changing all guest access
	if denies == ULib.DEFAULT_GRANT_ACCESS.deny then denies = table.Copy( denies ) end -- Otherwise we'd be changing all guest access
	if group and not ucl.groups[ group ] then return error( "Group does not exist for adding user to (" .. group .. ")", 2 ) end

	-- This doesn't do anything?
	for k, v in ipairs( allows ) do allows[ k ] = v end
	for k, v in ipairs( denies ) do denies[ k ] = v end

	local name, oldgroup
	if ucl.users[ id ] and ucl.users[ id ].name then name = ucl.users[ id ].name end -- Preserve name
	if ucl.users[ id ] and ucl.users[ id ].group then oldgroup = ucl.users[ id ].group end
	ucl.users[ id ] = { allow=allows, deny=denies, group=group, name=name }

	ucl.saveUser( id, ucl.users[ id ] )

	local ply = ULib.getPlyByID( id )
	if ply then
		if not from_CAMI then
			CAMI.SignalUserGroupChanged( ply, oldgroup, group or "user", CAMI.ULX_TOKEN )
		end

		hook.Call( ULib.HOOK_USER_GROUP_CHANGE, _, id, allows, denies, group, oldgroup )
		ucl.probe( ply )
	else -- Otherwise this gets called twice
		if not from_CAMI then
			CAMI.SignalSteamIDUserGroupChanged( id, oldgroup, group or "user", CAMI.ULX_TOKEN )
		end
		hook.Call( ULib.HOOK_UCLCHANGED )
		hook.Call( ULib.HOOK_USER_GROUP_CHANGE, _, id, allows, denies, group, oldgroup )
	end
end


--[[
	Function: ucl.userAllow

	Adds or removes an access tag in the allows or denies for a user. Automatically reprobes, automatically saves.

	Parameters:

		id - The SteamID, IP, or UniqueID of the user to change. Must be a valid, existing ID, or an ID of a connected player.
		access - The string of the access or a table of accesses to add or remove. Access tags can be specified in values in the table for allows.
		revoke - *(Optional, defaults to false)* A boolean of whether the access tag should be added or removed
			from the allow or deny list. If true, it's removed.
		deny - *(Optional, defaults to false)* If true, the access is added or removed from the deny list,
			if false it's added or removed from the allow list.

	Returns:

		A boolean stating whether you changed anything or not.

	Revisions:

		v2.40 - Initial.
		v2.50 - Relaxed restrictions on id parameter.
		v2.51 - Fixed this function not working on disconnected players.
]]
function ucl.userAllow( id, access, revoke, deny )
	ULib.checkArg( 1, "ULib.ucl.userAllow", "string", id )
	ULib.checkArg( 2, "ULib.ucl.userAllow", {"string","table"}, access )
	ULib.checkArg( 3, "ULib.ucl.userAllow", {"nil","boolean"}, revoke )
	ULib.checkArg( 4, "ULib.ucl.userAllow", {"nil","boolean"}, deny )

	id = id:upper() -- In case of steamid, needs to be upper case
	if type( access ) == "string" then access = { access } end

	local uid = id
	if not ucl.authed[ uid ] then -- Check to see if it's a steamid or IP
		local ply = ULib.getPlyByID( id )
		if ply and ply:IsValid() then
			uid = ply:UniqueID()
		end
	end

	local userInfo = ucl.users[ id ] or ucl.authed[ uid ] -- Check both tables
	if not userInfo then return error( "User id does not exist for changing access (" .. id .. ")", 2 ) end

	-- If they're connected but don't exist in the ULib user database, add them.
	-- This can be the case if they're only using the default garrysmod file to pull in users.
	if userInfo.guest then
		local allows = {}
		local denies = {}
		if not revoke and not deny then allows = access
		elseif not revoke and deny then denies = access end

		ucl.addUser( id, allows, denies )
		return true -- And we're done
	end

	local accessTable = userInfo.allow
	local otherTable = userInfo.deny
	if deny then
		accessTable = userInfo.deny
		otherTable = userInfo.allow
	end

	local changed = false
	for k, v in pairs( access ) do
		local access = v:lower()
		local accesstag
		if type( k ) == "string" then
			access = k:lower()
			if not revoke and not deny then -- Not valid to have accessTags unless this is the case
				accesstag = v
			end
		end

		if not revoke and (accessTable[ access ] ~= accesstag or (not accesstag and not ULib.findInTable( accessTable, access ))) then
			changed = true
			if not accesstag then
				table.insert( accessTable, access )
				accessTable[ access ] = nil -- Ensure no access tag
			else
				accessTable[ access ] = accesstag
				if ULib.findInTable( accessTable, access ) then -- Ensure removal of non-access tag version
					table.remove( accessTable, ULib.findInTable( accessTable, access ) )
				end
			end

			-- If it's on the other table, remove
			if deny then
				otherTable[ access ] = nil -- Remove any accessTags
			end
			if ULib.findInTable( otherTable, access ) then
				table.remove( otherTable, ULib.findInTable( otherTable, access ) )
			end

		elseif revoke and (accessTable[ access ] or ULib.findInTable( accessTable, access )) then
			changed = true

			if not deny then
				accessTable[ access ] = nil -- Remove any accessTags
			end
			if ULib.findInTable( accessTable, access ) then
				table.remove( accessTable, ULib.findInTable( accessTable, access ) )
			end
		end
	end

	if changed then
		local ply = ULib.getPlyByID( id )
		if ply then
			ULib.queueFunctionCall( hook.Call, ULib.HOOK_UCLAUTH, _, ply ) -- Inform the masses
		end

		local saveId
		if ucl.users[ id ] then
			saveId = id
		else
			local data = ucl.authed[ uid ]
			for checkId, check in pairs( ucl.users ) do
				if check == data then
					saveId = checkId
					break
				end
			end
		end

		if saveId then
			ucl.saveUser( id, ucl.users[ id ] )
		else
			Msg( "There was an error while changing user access.\n" )
			Msg( "The user ID could not be found, so the user could not be saved\n" )
		end


		hook.Call( ULib.HOOK_USER_ACCESS_CHANGE, _, id, access, revoke, deny )
		hook.Call( ULib.HOOK_UCLCHANGED )
	end

	return changed
end


--[[
	Function: ucl.removeUser

	Removes a user from the UCL. Automatically probes for the user, automatically saves.

	Parameters:

		id - The SteamID, IP, or UniqueID of the user you wish to remove. Must be a valid, existing ID.
			The unique id of a connected user is always valid.
		from_CAMI - *(Optional)* An indicator for this information coming from CAMI.

	Revisions:

		v2.40 - Rewrite, removed the write argument.
		v2.60 - Added CAMI support and parameter.
]]
function ucl.removeUser( id, from_CAMI )
	ULib.checkArg( 1, "ULib.ucl.addUser", "string", id )
	id = id:upper() -- In case of steamid, needs to be upper case

	local userInfo = ucl.users[ id ] or ucl.authed[ id ] -- Check both tables
	if not userInfo then return error( "User id does not exist for removing (" .. id .. ")", 2 ) end

	local changed = false

	if ucl.authed[ id ] and not ucl.users[ id ] then -- Different ids between offline and authed
		local ply = ULib.getPlyByID( id )
		if not ply then return error( "SANITY CHECK FAILED!" ) end -- Should never be invalid

		local ip = ULib.splitPort( ply:IPAddress() )
		local checkIndexes = { ply:UniqueID(), ip, ply:SteamID() }

		for _, index in ipairs( checkIndexes ) do
			if ucl.users[ index ] then
				changed = index
				ucl.users[ index ] = nil
				break -- Only match the first one
			end
		end
	else
		changed = id
		ucl.users[ id ] = nil
	end

	if changed then -- If the user is only added to the default garry file, then nothing changed
		ucl.deleteUser( changed )
		hook.Call( ULib.HOOK_USER_REMOVED, _, id, userInfo )
	end

	local ply = ULib.getPlyByID( id )
	if ply then
		if not from_CAMI then
			CAMI.SignalUserGroupChanged( ply, ply:GetUserGroup(), ULib.ACCESS_ALL, CAMI.ULX_TOKEN )
		end

		ply:SetUserGroup( ULib.ACCESS_ALL, true )
		ucl.probe( ply ) -- Reprobe
	else -- Otherwise this is called twice
		if not from_CAMI then
			CAMI.SignalSteamIDUserGroupChanged( id, userInfo.group, ULib.ACCESS_ALL, CAMI.ULX_TOKEN )
		end
		hook.Call( ULib.HOOK_UCLCHANGED )
	end
end


--[[
	Function: ucl.registerAccess

	Inform UCL about the existence of a particular access string, optionally make it have a certain default access,
	optionally give a help message along with it. The use of this function is optional, it is not required in order
	to query an access string, but it's use is highly recommended.

	Parameters:

		access - The access string (IE, "ulx slap" or "ups deletionAccess").
		groups - *(Optional, defaults to no access)* Either a string of a group or a table of groups to give the default access to.
		comment - *(Optional)* A brief description of what this access string is granting access to.
		category - *(Optional)* Category  for the access string (IE, "Command", "CVAR", "Limits")

	Revisions:

		v2.40 - Rewrite.
]]
function ucl.registerAccess( access, groups, comment, category )
	ULib.checkArg( 1, "ULib.ucl.registerAccess", "string", access )
	ULib.checkArg( 2, "ULib.ucl.registerAccess", {"nil","string","table"}, groups )
	ULib.checkArg( 3, "ULib.ucl.registerAccess", {"nil","string"}, comment )
	ULib.checkArg( 4, "ULib.ucl.registerAccess", {"nil","string"}, category )

	access = access:lower()
	comment = comment or ""
	if groups == nil then groups = {} end
	if type( groups ) == "string" then
		groups = { groups }
	end

	accessCategories[ access ] = category
	if accessStrings[ access ] ~= comment then -- Only if not already registered or if the comment has changed
		accessStrings[ access ] = comment

		-- Create a named timer so no matter how many times this function is called in a frame, it's only saved once.
		timer.Create( "ULibSaveAccessStrings", 1, 1, saveAccessStringRegistration ) -- 1 sec delay, 1 rep

		-- Double check to make sure this isn't already registered with some group somewhere before re-adding it
		for _, groupInfo in pairs( ucl.groups ) do
			if table.HasValue( groupInfo.allow, access ) then return end -- Found, don't add again
		end

		for _, group in ipairs( groups ) do
			-- Create group if it doesn't exist
			if not ucl.groups[ group ] then ucl.addGroup( group ) end

			table.insert( ucl.groups[ group ].allow, access )
		end

		timer.Create( "ULibSaveGroups", 1, 1, function() -- 1 sec delay, 1 rep
			ucl.saveGroups()
			hook.Call( ULib.HOOK_UCLCHANGED )
			hook.Call( ULib.HOOK_ACCESS_REGISTERED )
		end )
	end
end


--[[
	Function: ucl.probe

	Probes the user to assign access appropriately.
	*DO NOT CALL THIS DIRECTLY, UCL HANDLES IT.*

	Parameters:

		ply - The player object to probe.

	Revisions:

		v2.40 - Rewrite.
]]
function ucl.probe( ply )
	local ip = ULib.splitPort( ply:IPAddress() )
	local uid = ply:UniqueID()
	local checkIndexes = { uid, ip, ply:SteamID() }

	local match = false
	for _, index in ipairs( checkIndexes ) do
		if ucl.users[ index ] then
			ucl.authed[ uid ] = ucl.users[ index ] -- Setup an ALIAS

			-- If they have a group, set it
			local group = ucl.authed[ uid ].group
			if group and group ~= "" then
				ply:SetUserGroup( group, true )
			end

			-- Update their name
			ucl.authed[ uid ].name = ply:Nick()

			local sid = ply:SteamID()
			ucl.saveUser( sid )

			match = true
			break
		end
	end

	if not match then
		ucl.authed[ ply:UniqueID() ] = ULib.DEFAULT_GRANT_ACCESS
		if ply.tmp_group then
			ply:SetUserGroup( ply.tmp_group, true ) -- Make sure they keep the group
			ply.tmp_group = nil
		end
	end

	hook.Call( ULib.HOOK_UCLCHANGED )
	hook.Call( ULib.HOOK_UCLAUTH, _, ply )
end
-- Note that this function is hooked into "PlayerAuthed", below.

local function setupBot( ply )
	if not ply or not ply:IsValid() then return end

	if not ucl.authed[ ply:UniqueID() ] then
		ply:SetUserGroup( ULib.ACCESS_ALL, true ) -- Give it a group!
		ucl.probe( ply )
	end
end

local function botCheck( ply )
	if ply:IsBot() then
		-- We have to call this twice because the uniqueID will change for NextBots
		setupBot( ply )
		ULib.queueFunctionCall( setupBot, ply )
	end
end
hook.Add( "PlayerInitialSpawn", "ULibSendAuthToClients", botCheck, HOOK_MONITOR_HIGH )

local function sendAuthToClients( ply )
	ULib.clientRPC( _, "authPlayerIfReady", ply, ply:UserID() ) -- Call on client
end
hook.Add( ULib.HOOK_UCLAUTH, "ULibSendAuthToClients", sendAuthToClients, HOOK_MONITOR_LOW )

local function sendUCLDataToClient( ply )
	ULib.clientRPC( ply, "ULib.ucl.initClientUCL", ucl.authed, ucl.groups ) -- Send all UCL data (minus offline users) to all loaded users
	ULib.clientRPC( ply, "hook.Call", ULib.HOOK_UCLCHANGED ) -- Call hook on client
	ULib.clientRPC( ply, "authPlayerIfReady", ply, ply:UserID() ) -- Call on client
end
hook.Add( ULib.HOOK_LOCALPLAYERREADY, "ULibSendUCLDataToClient", sendUCLDataToClient, HOOK_MONITOR_HIGH )

local function playerDisconnected( ply )
	-- We want to perform these actions after everything else has processed through, but we need high priority hook to ensure we don't get sniped.
	local uid = ply:UniqueID()
	ULib.queueFunctionCall( function()
		ucl.authed[ uid ] = nil
		hook.Call( ULib.HOOK_UCLCHANGED )
	end )
end
hook.Add( "PlayerDisconnected", "ULibUCLDisconnect", playerDisconnected, HOOK_MONITOR_HIGH )

local function UCLChanged()
	ULib.clientRPC( _, "ULib.ucl.initClientUCL", ucl.authed, ucl.groups ) -- Send all UCL data (minus offline users) to all loaded users
	ULib.clientRPC( _, "hook.Call", ULib.HOOK_UCLCHANGED ) -- Call hook on client
end
hook.Add( ULib.HOOK_UCLCHANGED, "ULibSendUCLToClients", UCLChanged )

--[[
-- The following is useful for debugging since Garry changes client bootstrapping so frequently
hook.Add( ULib.HOOK_UCLCHANGED, "UTEST", function() print( "HERE HERE: UCL Changed" ) end )
hook.Add( "PlayerInitialSpawn", "UTEST", function() print( "HERE HERE: Initial Spawn" ) end )
hook.Add( "PlayerAuthed", "UTEST", function() print( "HERE HERE: Player Authed" ) end )
]]

---------- Modify

-- Move garry's auth function so it gets called sooner
local playerAuth = hook.GetTable().PlayerInitialSpawn.PlayerAuthSpawn
hook.Remove( "PlayerInitialSpawn", "PlayerAuthSpawn" ) -- Remove from original spot

local function newPlayerAuth( ply, ... )
	ucl.authed[ ply:UniqueID() ] = nil -- If the player ent is removed before disconnecting, we can have this hanging out there.
	playerAuth( ply, ... ) -- Put here, slightly ahead of ucl.
	ucl.probe( ply, ... )
end
hook.Add( "PlayerAuthed", "ULibAuth", newPlayerAuth, HOOK_MONITOR_HIGH )

local meta = FindMetaTable( "Player" )
if not meta then return end

local oldSetUserGroup = meta.SetUserGroup
function meta:SetUserGroup( group, dontCall )
	if not ucl.groups[ group ] then ULib.ucl.addGroup( group ) end

	local oldGroup = self:GetUserGroup()
	oldSetUserGroup( self, group )

	if ucl.authed[ self:UniqueID() ] then
		if ucl.authed[ self:UniqueID() ] == ULib.DEFAULT_GRANT_ACCESS then
			ucl.authed[ self:UniqueID() ] = table.Copy( ULib.DEFAULT_GRANT_ACCESS )
		end
		ucl.authed[ self:UniqueID() ].group = group
	else
		self.tmp_group = group
	end

	if not dontCall and self:GetUserGroup() ~= oldGroup then -- Changed! Inform the masses of the change
		hook.Call( ULib.HOOK_UCLCHANGED )
		hook.Call( ULib.HOOK_UCLAUTH, _, self )
	end
end
