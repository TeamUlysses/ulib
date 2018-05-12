--[[
	Title: Utilities

	Some utility functions. Unlike the functions in misc.lua, this file only holds HL2 specific functions.
]]

local dataFolder = "data"
--[[
	Function: fileExists

	Checks for the existence of a file by path.

	Parameters:

		f - The path to check, rooted at the garry's mod root directory.
		noMount - *(Optional)* If true, will not look in mounted directories.

	Returns:

		True if the file exists, false otherwise.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
		v2.70 - Added noMount parameter to *only* look in mod directory.
]]
function ULib.fileExists( f, noMount )
	if noMount then return file.Exists( f, "MOD" ) end

	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) ~= dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	return file.Exists( f, "GAME" ) or (isDataFolder and file.Exists( fWoData, "DATA" ))
end

--[[
	Function: fileRead

	Reads a file and returns the contents. This function is not very forgiving on providing oddly formatted filepaths.

	Parameters:

		f - The file to read, rooted at the garrysmod directory.
		noMount - *(Optional)* If true, will not look in mounted directories.

	Returns:

		The file contents or nil if the file does not exist.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
		v2.70 - Added noMount parameter to *only* look in mod directory.
]]
function ULib.fileRead( f, noMount )
	local existsWoMount = ULib.fileExists( f, true )

	if noMount then
		if not existsWoMount then
			return nil
		end

		return file.Read( f, "MOD" )
	end

	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) == dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	if not existsWoMount and not ULib.fileExists( f ) then
		return nil
	end

	if not isDataFolder then
		return file.Read( f, "GAME" )
	else
		-- We want to prefer any data files at the root, but allow for mounted directories
		if existsWoMount then
			return file.Read( fWoData, "DATA" )
		else
			return file.Read( f, "GAME" )
		end
	end
end

--[[
	Function: fileWrite

	Writes file content.

	Parameters:

		f - The file path to write to, rooted at the garrysmod directory.
		content - The content to write.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
]]
function ULib.fileWrite( f, content )
	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) == dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	if not isDataFolder then return nil end

	file.Write( fWoData, content )
end


--[[
	Function: fileAppend

	Append to file content.

	Parameters:

		f - The file path to append to, rooted at the garrysmod directory.
		content - The content to append.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
]]
function ULib.fileAppend( f, content )
	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) == dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	if not isDataFolder then return nil end

	file.Append( fWoData, content )
end


--[[
	Function: fileCreateDir

	Create a directory.

	Parameters:

		f - The directory path to create, rooted at the garrysmod directory.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
]]
function ULib.fileCreateDir( f )
	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) == dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	if not isDataFolder then return nil end

	file.CreateDir( fWoData )
end


--[[
	Function: fileDelete

	Delete file contents.

	Parameters:

		f - The file path to delete, rooted at the garrysmod directory.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
]]
function ULib.fileDelete( f )
	local isDataFolder = f:lower():sub( 1, dataFolder:len() ) == dataFolder
	fWoData = f:sub( dataFolder:len() + 2 ) -- +2 removes path seperator

	if not isDataFolder then return nil end

	file.Delete( fWoData )
end


--[[
	Function: fileIsDir

	Is file a directory?

	Parameters:

		f - The file path to check, rooted at the garrysmod directory.
		noMount - *(Optional)* If true, will not look in mounted directories.

	Returns:

		True if dir, false otherwise.

	Revisions:

		v2.51 - Initial revision (tired of Garry changing his API all the time).
		v2.70 - Added noMount parameter to *only* look in mod directory.
]]
function ULib.fileIsDir( f, noMount )
	if not noMount then
		return file.IsDir( f, "GAME" )
	else
		return file.IsDir( f, "MOD" )
	end
end


--[[
	Function: execFile

	Executes a file on the console. Use this instead of the "exec" command when the config lies outside the cfg folder.

	Parameters:

		f - The file, relative to the garrysmod folder.
		queueName - The queue name to ULib.namedQueueFunctionCall to use.
		noMount - *(Optional)* If true, will not look in mounted directories.

	Revisions:

		v2.40 - No longer strips comments, removed ability to execute on players.
		v2.50 - Added option to conform to Garry's API changes and queueName to specify queue name to use.
		v2.51 - Removed option parameter.
		v2.70 - Added noMount parameter to *only* look in mod directory.
]]
function ULib.execFile( f, queueName, noMount )
	if not ULib.fileExists( f, noMount ) then
		ULib.error( "Called execFile with invalid file! " .. f )
		return
	end

	ULib.execString( ULib.fileRead( f, noMount ), queueName )
end


--[[
	Function: execString

	Just like <execFile>, except acts on newline-delimited strings.

	Parameters:

		f - The string.
		queueName - The queue name to ULib.namedQueueFunctionCall to use.

	Revisions:

		v2.40 - Initial.
		v2.50 - Added queueName to specify queue name to use. Removed ability to execute on players.
]]
function ULib.execString( f, queueName )
	local lines = string.Explode( "\n", f )

	local buffer = ""
	local buffer_lines = 0
	local exec = "exec "
	for _, line in ipairs( lines ) do
		line = string.Trim( line )
		if line:lower():sub( 1, exec:len() ) == exec then
			local dummy, dummy, cfg = line:lower():find( "^exec%s+([%w%.]+)%s*/?/?.*$")
			if not cfg:find( ".cfg", 1, true ) then cfg = cfg .. ".cfg" end -- Add it if it's not there
			ULib.execFile( "cfg/" .. cfg, queueName )
		elseif line ~= "" then
			buffer = buffer .. line .. "\n"
			buffer_lines = buffer_lines + 1

			if buffer_lines >= 10 then
				ULib.namedQueueFunctionCall( queueName, ULib.consoleCommand, buffer )
				buffer_lines = 0
				buffer = ""
			end
		end
	end

	if buffer_lines > 0 then
		ULib.namedQueueFunctionCall( queueName, ULib.consoleCommand, buffer )
	end
end


--[[
	Function: execFileULib

	Just like <execFile>, except only for ULib-defined commands. It avoids the source engine
	command queue, and has an additional option to only execute commands marked as "safe" (up to the
	command author to properly define these).

	Parameters:

		f - The file, relative to the garrysmod folder.
		safeMode - If set to true, does not run "unsafe" commands.
		noMount - *(Optional)* If true, will not look in mounted directories.

	Revisions:

		v2.62 - Initial.
]]
function ULib.execFileULib( f, safeMode, noMount )
	if not ULib.fileExists( f, noMount ) then
		ULib.error( "Called execFileULib with invalid file! " .. f )
		return
	end

	ULib.execStringULib( ULib.fileRead( f, noMount ), safeMode )
end


--[[
	Function: execStringULib

	Just like <execString>, except only for ULib-defined commands. It avoids the source engine
	command queue, and has an additional option to only execute commands marked as "safe" (up to the
	command author to properly define these).

	Parameters:

		f - The string.
		safeMode - If set to true, does not run "unsafe" commands.

	Revisions:

		v2.62 - Initial.
]]
function ULib.execStringULib( f, safeMode )
	local lines = string.Explode( "\n", f )
	local srvPly = Entity( -1 ) -- Emulate the console callback object

	for _, line in ipairs( lines ) do
		line = string.Trim( line )
		if line ~= "" then
			local argv = ULib.splitArgs( line )
			local commandName = table.remove( argv, 1 )
			local cmdTable, commandName, argv = ULib.cmds.getCommandTableAndArgv( commandName, argv )

			if not cmdTable then
				Msg( "Error executing " .. tostring( commandName ) .. "\n" )
			elseif cmdTable.__unsafe then
				Msg( "Not executing unsafe command " .. commandName .. "\n" )
			else
				ULib.cmds.execute( cmdTable, srvPly, commandName, argv )
			end
		end
	end
end


--[[
	Function: serialize

	Serializes a variable. It basically converts a variable into a runnable code string. It works correctly with inline tables.

	Parameters:

		v - The variable you wish to serialize

	Returns:

		The string of the serialized variable

	Revisions:

		v2.40 - Can now serialize entities and players
]]
function ULib.serialize( v )
	local t = type( v )
	local str
	if t == "string" then
		str = string.format( "%q", v )
	elseif t == "boolean" or t == "number" then
		str = tostring( v )
	elseif t == "table" then
		str = table.ToString( v )
	elseif t == "Vector" then
		str = "Vector(" .. v.x .. "," .. v.y .. "," .. v.z .. ")"
	elseif t == "Angle" then
		str = "Angle(" .. v.pitch .. "," .. v.yaw .. "," .. v.roll .. ")"
	elseif t == "Player" then
		str = tostring( v )
	elseif t == "Entity" then
		str = tostring( v )
	elseif t == "nil" then
		str = "nil"
	else
		ULib.error( "Passed an invalid parameter to serialize! (type: " .. t .. ")" )
		return
	end
	return str
end


--[[
	Function: isSandbox

	Returns true if the current gamemode is sandbox or is derived from sandbox.
]]
function ULib.isSandbox()
	return GAMEMODE.IsSandboxDerived
end


local function insertResult( files, result, relDir )
	if not relDir then
		table.insert( files, result )
	else
		table.insert( files, relDir .. "/" .. result )
	end
end

--[[
	Function: filesInDir

	Returns files in directory.

	Parameters:

		dir - The dir to look for files in.
		recurse - *(Optional, defaults to false)* If true, searches directories recursively.
		noMount - *(Optional)* If true, will not look in mounted directories.
		root - *INTERNAL USE ONLY* This helps with recursive functions.

	Revisions:

		v2.10 - Initial (But dragged over from GM9 archive).
		v2.40 - Fixed (was completely broken).
		v2.50 - Now assumes paths relative to base folder.
		v2.60 - Fix for Garry API-changes
		v2.70 - Added noMount parameter to *only* look in mod directory.
]]
function ULib.filesInDir( dir, recurse, noMount, root )
	if not ULib.fileIsDir( dir ) then
		return nil
	end

	local files = {}
	local relDir
	if root then
		relDir = dir:gsub( root .. "[\\/]", "" )
	end
	root = root or dir

	local resultFiles, resultFolders = file.Find( dir .. "/*", not noMount and "GAME" or "MOD" )

	for i=1, #resultFiles do
		insertResult( files, resultFiles[ i ], relDir )
	end

	for i=1, #resultFolders do
		if recurse then
			files = table.Add( files, ULib.filesInDir( dir .. "/" .. resultFolders[ i ], recurse, noMount, root ) )
		else
			insertResult( files, resultFolders[ i ], relDir )
		end
	end

	return files
end


-- Helper function for <queueFunctionCall()>
local stacks = {}
local function onThink()
	local remove = true
	for queueName, stack in pairs( stacks ) do
		local num = #stack
		if num > 0 then
			remove = false
			local b, e = pcall( stack[ 1 ].fn, unpack( stack[ 1 ], 1, stack[ 1 ].n ) )
			if not b then
				ErrorNoHalt( "ULib queue error: " .. tostring( e ) .. "\n" )
			end
			table.remove( stack, 1 ) -- Remove the first inserted item. This is FIFO
		end
	end

	if remove then
		hook.Remove( "Think", "ULibQueueThink" )
	end
end


--[[
	Function: queueFunctionCall

	Adds a function call to the queue to be called. Guaranteed to be called sometime after the current frame. Very handy
	when you need to delay a call for some reason. Uses a think hook, but it's only hooked when there's stuff in the queue.

	Parameters:

		fn - The function to call
		... - *(Optional)* The parameters to pass to the function

	Revisions:

		v2.40 - Initial (But dragged over from UPS).
]]
function ULib.queueFunctionCall( fn, ... )
	if type( fn ) ~= "function" then
		error( "queueFunctionCall received a bad function", 2 )
		return
	end

	ULib.namedQueueFunctionCall( "defaultQueueName", fn, ... )
end

--[[
	Function: namedQueueFunctionCall

	Exactly like <queueFunctionCall()>, but allows for separately running queues to exist.

	Parameters:

		queueName - The unique name of the queue (the queue group)
		fn - The function to call
		... - *(Optional)* The parameters to pass to the function

	Revisions:

		v2.50 - Initial.
]]
function ULib.namedQueueFunctionCall( queueName, fn, ... )
	queueName = queueName or "defaultQueueName"
	if type( fn ) ~= "function" then
		error( "queueFunctionCall received a bad function", 2 )
		return
	end

	stacks[ queueName ] = stacks[ queueName ] or {}
	table.insert( stacks[ queueName ], { fn=fn, n=select( "#", ... ), ... } )
	hook.Add( "Think", "ULibQueueThink", onThink, HOOK_MONITOR_HIGH )
end


--[[
	Function: backupFile

	Copies a file to a backup file. If a backup file already exists, makes incrementing numbered backup files.

	Parameters:

		f - The file to backup, rooted in the garrysmod directory.

	Returns:

		The pathname of the file it was backed up to.

	Revisions:

		v2.40 - Initial.
]]
function ULib.backupFile( f )
	local contents = ULib.fileRead( f )
	local filename = f:GetFileFromFilename():sub( 1, -5 ) -- Remove '.txt'
	local folder = f:GetPathFromFilename()

	local num = 1
	local targetPath = folder .. filename .. "_backup.txt"
	while ULib.fileExists( targetPath ) do
		num = num + 1
		targetPath = folder .. filename .. "_backup" .. num .. ".txt"
	end

	-- We now have a filename that doesn't yet exist!
	ULib.fileWrite( targetPath, contents )

	return targetPath
end

--[[
	Function: nameCheck

	Calls all ULibPlayerNameChanged hooks if a player changes their name.

	Revisions:

		2.20 - Initial
]]
function ULib.nameCheck( data )
	hook.Call( ULib.HOOK_PLAYER_NAME_CHANGED, nil, Player(data.userid), data.oldname, data.newname )
end
gameevent.Listen( "player_changename" )
hook.Add( "player_changename", "ULibNameCheck", ULib.nameCheck )

--[[
	Function: getPlyByUID

	Parameters:

		uid - The uid to lookup.

	Returns:

		The player that has the specified unique id, nil if none exists.

	Revisions:

		v2.40 - Initial.
]]
function ULib.getPlyByUID( uid )
	local players = player.GetAll()
	for _, ply in ipairs( players ) do
		if ply:UniqueID() == uid then
			return ply
		end
	end

	return nil
end


--[[
	Function: pcallError

	An adaptation of a function that used to exist before GM13, allows you to
	call functions safely and print errors (if it errors).

	Parameters:

		... - Arguments to pass to the function

	Returns:

		The same thing regular pcall returns

	Revisions:

		v2.50 - Initial.
]]
function ULib.pcallError( ... )
	local returns = { pcall( ... ) }

	if not returns[ 1 ] then -- The status flag
		ErrorNoHalt( returns[ 2 ] ) -- The error message
	end

	return unpack( returns )
end
