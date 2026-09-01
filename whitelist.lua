local CODE_LENGTH = 8

local DEBUG_COLOR   = Color(61, 79, 242)
local INFO_COLOR    = Color(42, 235, 49)
local WARNING_COLOR = Color(209, 237, 28)
local ERROR_COLOR   = Color(194, 10, 10)

local GRADIENT = {
	Color(127, 146, 255), Color(138, 144, 255), Color(149, 142, 255),
	Color(160, 140, 255), Color(171, 137, 255), Color(182, 135, 255),
	Color(193, 132, 255), Color(204, 130, 255), Color(214, 127, 255)
}

local PREFIX_CHARS = {"T", "r", "u", "s", "t", "l", "e", "s", "s"}

-- Return the first argument of the table and remove it.
---@param args table Arguments args passed from a concommand
---@return string|nil Argument or nil
local function shift_args(args)
	return table.remove(args, 1)
end

-- Return whether a given string is a valid steamid64.
---@param sid64 any SteamID64 The string to validate.
---@return boolean IsValid Whether the string provided is a valid SteamID64.
local function is_valid_steamid(sid64)
	if TypeID(sid64) ~= TYPE_STRING then
		return false
	end

	local len = #sid64
	if len ~= 17 then
		return false
	end

	local start = sid64:sub(1, 7)
	if start ~= "7656119" then
		return false
	end

	return true
end

---@class WhitelistManager
---@field whitelist_enabled boolean
---@field whitelist table<string, string>
---@field blacklist_enabled boolean
---@field blacklist table<string, string>
---@field password_enabled boolean
---@field debug_mode boolean
local WhitelistManager = {}
WhitelistManager.__index = WhitelistManager

-- Get the defaults for WhitelistManager.
---@return table Defaults Default configuration for WhitelistManager.
function WhitelistManager.GetDefaults()
	return {
		whitelist_enabled = true,
		whitelist = {},

		blacklist_enabled = true,
		blacklist = {},

		debug_mode = false,
		password_enabled = true
	}
end

-- Return an instance of WhitelistManager.
---@return WhitelistManager
function WhitelistManager.new()
	return setmetatable(WhitelistManager.GetDefaults(), WhitelistManager)
end

-- Return a string consisting of random uppercase characters
---@param length integer
---@return string String A string consisting of random uppercase characters.
function WhitelistManager:GenerateRandomString(length)
	-- Tiny lua StringBuilder based on (https://github.com/GomeyDoge/simple-stringbuilder)
	--- Testing on my standalone version shows about a 527.5x speed up
	local chars = {}

	for i = 1, length do
		chars[i] = string.char(math.random(65, 90)) -- A-Z
	end

	return table.concat(chars)
end

-- Internal function for printing to console with a fancy format.
---@param level string Level tag to put in brackets.
---@param level_color Color The color of the level tag.
---@param fmt string The format string to use.
---@vararg string The format strings.
---@return nil Nothing This function doesn't return anything... just prints to console.
function WhitelistManager:_print(level, level_color, fmt, ...)
	MsgC(color_white, "[")
	for i = 1, #PREFIX_CHARS do
		MsgC(GRADIENT[i] or color_white, PREFIX_CHARS[i])
	end
	MsgC(color_white, "][")
	MsgC(level_color, level)

	local text = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
	MsgC(color_white, "] " .. text .. "\n")
end

-- I wanted a corny ass ascii art
---@return nil Nothing This function doesn't return anything... just prints ascii art.
function WhitelistManager:_branding()
	self:Info("")
	self:Info("___________                      __  .____                         ")
	self:Info("\\__    ___/______ __ __  _______/  |_|    |    ____   ______ ______")
	self:Info("  |    |  \\_  __ \\  |  \\/  ___/\\   __\\    |  _/ __ \\ /  ___//  ___/")
	self:Info("  |    |   |  | \\/  |  /\\___ \\  |  | |    |__\\  ___/ \\___ \\ \\___ \\ ")
	self:Info("  |____|   |__|  |____//____  > |__| |_______ \\___  >____  >____  >")
	self:Info("                            \\/               \\/   \\/     \\/     \\/ ")
	self:Info("")
	self:Info("\tVersion 1.0.0 | Written by @thedogfiles | 8 / 25 / 2026")
	self:Info("")
	self:Info("Server protected by Trustless Whitelist Manager.")
	self:Info("")
end

-- Wrapper to print debug messages.
---@vararg string The message(s) to display
---@return nil Nothing This function returns nothing... just prints to console.
function WhitelistManager:Debug(...)
	if self.debug_mode then self:_print("DEBUG", DEBUG_COLOR, ...) end
end

-- Wrapper to print info messages.
---@vararg string The message(s) to display
---@return nil Nothing This function returns nothing... just prints to console.
function WhitelistManager:Info(...) self:_print("INFO", INFO_COLOR, ...) end

-- Wrapper to print warning messages.
---@vararg string The message(s) to display
---@return nil Nothing This function returns nothing... just prints to console.
function WhitelistManager:Warning(...) self:_print("WARNING", WARNING_COLOR, ...) end

-- Wrapper to print error messages.
---@vararg string The message(s) to display
---@return nil Nothing This function returns nothing... just prints to console.
function WhitelistManager:Error(...) self:_print("ERROR", ERROR_COLOR, ...) end

-- Set the debug_mode variable in the state of the WhitelistManager.
---@param debug_mode boolean The new value to set debug_mode to.
---@return nil Nothing This function returns nothing... just sets the debug_mode state.
function WhitelistManager:SetDebugMode(debug_mode)
	self.debug_mode = debug_mode
	self:Save()
end

-- Sets the password_enabled field to true, causing your server to have a lock on it.
---@param password_enabled boolean The new value to set password_enabled to.
---@return nil Nothing This function returns nothing... just sets the password_enabled state.
function WhitelistManager:SetPasswordEnabled(password_enabled)
	self.password_enabled = password_enabled
	self:Save()
end

-- Returns the internal state of the WhitelistManager instance.
---@return table State The internal state of the WhitelistManager.
function WhitelistManager:GetState()
	return {
		whitelist = self.whitelist,
		whitelist_enabled = self.whitelist_enabled,
		blacklist = self.blacklist,
		blacklist_enabled = self.blacklist_enabled,
		debug_mode = self.debug_mode,
		password_enabled = self.password_enabled
	}
end

-- Returns the encoded save-ready representation of the internal state of the WhitelistManager.
---@return string Data Compressed JSON representation of the internal state.
function WhitelistManager:EncodeData()
	local raw_json = util.TableToJSON(self:GetState(), true) or "{}"
	return util.Compress(raw_json)
end

-- Decodes the saved state from the encoded file.
---@param data string Compressed data from the save file.
---@return table? Data Returns the table version of the compressed data.
function WhitelistManager:DecodeData(data)
	local decompressed = util.Decompress(data)
	return decompressed and util.JSONToTable(decompressed, false, true)
end

-- Save the internal state of the WhitelistManager to a file.
---@return boolean
function WhitelistManager:Save()
	if not file.Exists("trustless", "DATA") then
		self:Info("`trustless` directory missing from `data` folder. Creating it now...")
		file.CreateDir("trustless")
	end

	local handle = file.Open("trustless/data.dat", "wb", "DATA")
	if not handle then
		self:Error("Failed to open file `trustless/data.dat` for writing.")
		return false
	end

	local data = self:EncodeData()
	
	-- Language server is missing these functions for some reason.
	---@diagnostic disable-next-line: undefined-field
	handle:Write(data)
	---@diagnostic disable-next-line: undefined-field
	handle:Close()

	self:Debug("Successfully saved state to trustless/data.dat")
	return true
end

-- Load the state of the WhitelistManager from file.
---@return boolean
function WhitelistManager:Load()
	if not file.Exists("trustless/data.dat", "DATA") then
		self:Warning("No saved state found. Applying default configuration.")
		table.Merge(self, WhitelistManager.GetDefaults())
		return false
	end

	-- These two blocks look very similar but are slightly different.
	--- The first block will be called on the first server boot and use default data.
	--- The second block will be called in the case that for some reason we can't read the file.
	--- To my knowledge the second block should never be called?
	local handle = file.Open("trustless/data.dat", "rb", "DATA")
	if not handle then
		self:Error("Failed to open file `trustless/data.dat` for reading. Applying defaults.")
		table.Merge(self, WhitelistManager.GetDefaults())
		return false
	end

	-- Language server is missing these functions for some reason.
	---@diagnostic disable-next-line: undefined-field
	local file_content = handle:Read()
	---@diagnostic disable-next-line: undefined-field
	handle:Close()

	if not file_content or #file_content == 0 then
		self:Error("Saved file was empty. Applying defaults")
		table.Merge(self, WhitelistManager.GetDefaults())
		return false
	end

	local data = self:DecodeData(file_content)
	if not data then
		self:Error("Failed to parse JSON data from store. Applying defaults.")
		table.Merge(self, WhitelistManager.GetDefaults())
		return false
	end

	table.Merge(self, WhitelistManager.GetDefaults())
	table.Merge(self, data)

	self:Debug("Successfully loaded state from storage.")
	return true
end

-- Blacklist a player from joining the server.
---@param sid64 string The SteamID64 of the player.
---@param reason string The reason the player is being blacklisted.
---@param auto_save? boolean Whether we should automatically save the file.
---@return nil
function WhitelistManager:BlacklistPlayer(sid64, reason, auto_save)
	self.blacklist[sid64] = reason
	self:Info("Player: `%s` was blacklisted for reason: %s", sid64, reason)
	if auto_save then self:Save() end
end

-- Unblacklist a player from joining the server.
--- I highly recommend never calling this function.
--- If a player is auto-blacklisted they should never be unblacklisted.
--- Players on this list betrayed you by leaking their personal access code.
---@param sid64 string The SteamID64 of the player.
---@param auto_save? boolean Whether we should automatically save the file.
---@return nil
function WhitelistManager:UnblacklistPlayer(sid64, auto_save)
	if self.blacklist[sid64] then
		self.blacklist[sid64] = nil
		self:Warning("Unsafe function :UnblacklistPlayer called on player: `%s`", sid64)
		if auto_save then self:Save() end
	end
end

-- Whitelist a player to join the server.
---@param sid64 string The SteamID64 of the player.
---@param auto_save? boolean Whether we should automatically save the file.
---@return nil
function WhitelistManager:WhitelistPlayer(sid64, auto_save)
	local code = self:GenerateRandomString(CODE_LENGTH)
	self.whitelist[sid64] = code
	self:Info("%s can now connect with command: `password %s; connect %s`", sid64, code, game.GetIPAddress())
	if auto_save then self:Save() end
end

-- Unwhitelist a player from joining the server.
---@param sid64 string The SteamID64 of the player.
---@param auto_save? boolean Whether we should automatically save the file.
---@return nil
function WhitelistManager:UnwhitelistPlayer(sid64, auto_save)
	if self.whitelist[sid64] then
		self.whitelist[sid64] = nil
		self:Info("Player: `%s` was removed from the whitelist.", sid64)
		if auto_save then self:Save() end
	end
end

-- Checks if the player is joining using a leaked code.
---@param sid64 string The SteamID64 of the player.
---@param provided string The code provided by the player.
---@return boolean Leaked Whether the player joined using a leaked code.
function WhitelistManager:CheckForLeakedCode(sid64, provided)
	local deferred_return = false
	local bad_actors = {}

	for leaker, code in pairs(self.whitelist) do
		if provided == code and leaker ~= sid64 then
			bad_actors[sid64] = "Attempted entry using a leaked access code."
			bad_actors[leaker] = "Personal access code was leaked."
			deferred_return = true
		end
	end

	if table.Count(bad_actors) > 0 then
		for sid64, reason in pairs(bad_actors) do
			self:UnwhitelistPlayer(sid64)
			self:BlacklistPlayer(sid64, reason)
		end

		self:Save()
	end

	return deferred_return
end

---@param should_lock boolean Whether we should enable the lock on the server.
---@param first_load? boolean Whether this function is being called by the initial server load.
---@return nil Nothing This function doesn't return anything...
function WhitelistManager:HandleServerLock(should_lock, first_load)
	if not first_load then -- No need to save to the file right on server boot
		self.password_enabled = should_lock
		self:Save()
	end

	if should_lock then
		RunConsoleCommand("sv_password", self.random_server_password)
		self:Info("Server lock is currently enabled.")
	else
		RunConsoleCommand("sv_password", "")
		self:Info("Server lock is currently disabled.")
	end
end

-- Set up the WhitelistManager for operations. This can only be called once.
---@return nil Nothing This function doesn't return anything...
function WhitelistManager:Init()
	if _G.WhitelistManagerExists then
		self:Info("WhitelistManager instance already initialized.")
		return
	end

	self:_branding()

	math.randomseed(os.time() + SysTime())
	self.random_server_password = self:GenerateRandomString(32) -- Note: This will not persist through restarts!
	self:Debug("Server random password set to: `%s`", self.random_server_password)

	self:Load()
	self:HandleServerLock(self.password_enabled, true)

	-- The CheckPassword hook callback. Don't touch.
	---@param sid64 string The SteamID64 of the player.
	---@param provided string The password provided by the player.
	---@return boolean, string Allowed Whether the player is allowed to connect.
	hook.Add("CheckPassword", "WhitelistManager::CheckPassword", function(sid64, _, _, provided)
		if self:CheckForLeakedCode(sid64, provided) then
			return false, "Blacklisted: Using leaked access code."
		end

		if provided == self.random_server_password then
			-- I don't really know what to do here...
			--- This player may have a backdoor?
			self:Warning("Security alert: Player: `%s` attempted connection with internal server password!", sid64)
			return false, "Authentication error."
		end

		if self.blacklist_enabled and self.blacklist[sid64] then
			return false, "Blacklisted: " .. self.blacklist[sid64]
		end

		if self.whitelist_enabled then
			local expected_code = self.whitelist[sid64]

			if not expected_code then
				return false, "You are not whitelisted on this server."
			end

			if provided ~= expected_code then
				return false, "Invalid access code provided."
			end
		end

		-- Maybe at some point I'll hook.Run CheckPassword to make sure we're not breaking other addons by returning true
		--- However... Players should not be running other whitelisting systems at the same time.
		self:Debug("Player: `%s` successfully connected with code: `%s`", sid64, provided)
		return true
	end)

	concommand.Add("trustless", function(ply, _, args)
		if IsValid(ply) then
			ply:ChatPrint("This command can only be run by console.")
			return
		end

		local subcommand = string.lower(shift_args(args) or "")
		if subcommand == "help" then
			self:Info("Valid commands:")
			self:Info("help        - Show this command list.")
			self:Info("whitelist   - Add a player to the whitelist | Usage `trustless whitelist 76561198362949858`")
			self:Info("unwhitelist - Remove a player from the whitelist | Usage `trustless unwhitelist 76561198362949858`")
			self:Info("blacklist   - Add a player to the blacklist | Usage `trustless blacklist 76561198362949858 REASON`")
			self:Info("unblacklist - Remove a player from the blacklist | Usage `trustless unblacklist 76561198362949858`")
			self:Info("toggle_lock - Toggle the server lock | Usage `trustless toggle_lock`")
			self:Info("reset       - Reset Trustless to its default state (WARNING WILL WIPE ALL DATA) | Usage `trustless reset CONFIRM`")
		elseif subcommand == "whitelist" then
			local sid64 = shift_args(args)
			if not is_valid_steamid(sid64) then
				self:Info("Invalid SteamID64 entered! Run `trustless help` for help.")
				return
			end

			-- We handle the nil check in the steamid check, however the language server doesn't understand.
			---@diagnostic disable-next-line: param-type-mismatch
			self:WhitelistPlayer(sid64, true)
		elseif subcommand == "unwhitelist" then
			local sid64 = shift_args(args)
			if not is_valid_steamid(sid64) then
				self:Info("Invalid SteamID64 entered! Run `trustless help` for help.")
				return
			end

			-- We handle the nil check in the steamid check, however the language server doesn't understand.
			---@diagnostic disable-next-line: param-type-mismatch
			self:UnwhitelistPlayer(sid64, true)
		elseif subcommand == "blacklist" then
			local sid64 = shift_args(args)
			if not is_valid_steamid(sid64) then
				self:Info("Invalid SteamID64 entered! Run `trustless help` for help.")
				return
			end

			local reason = shift_args(args)
			if not reason then
				reason = "Unspecified reason"
			end

			-- We handle the nil check in the steamid check, however the language server doesn't understand.
			---@diagnostic disable-next-line: param-type-mismatch
			self:BlacklistPlayer(sid64, reason, true)
		elseif subcommand == "unblacklist" then
			local sid64 = shift_args(args)
			if not is_valid_steamid(sid64) then
				self:Info("Invalid SteamID64 entered! Run `trustless help` for help.")
				return
			end

			-- We handle the nil check in the steamid check, however the language server doesn't understand.
			---@diagnostic disable-next-line: param-type-mismatch
			self:UnblacklistPlayer(sid64, true)
		elseif subcommand == "toggle_lock" then
			self:HandleServerLock(not self.password_enabled)
		elseif subcommand == "reset" then
			local confirmation = shift_args(args)
			if confirmation == "CONFIRM" then
				table.Merge(self, WhitelistManager.GetDefaults(), true)
				self:Save()
				self:Info("Reset Trustless configuration to default settings.")
			else
				self:Info("Additional confirmation needed! | type `trustless reset CONFIRM` to confirm.")
			end
		else
			self:Info("Invalid subcommand entered! Run `trustless help` for help.")
		end

	end)

	-- Dump the internal state of the WhitelistManager
	--- I have chosen to redact the codes however, to protect leaking over screenshare.
	---@param ply Player
	---@return nil
	concommand.Add("trustless_dump_state", function(ply)
		if IsValid(ply) then return end
		if not self.debug_mode then return end

		self:Info("")
		self:Info("whitelist_enabled = %s", self.whitelist_enabled)

		if table.Count(self.whitelist) > 0 then
			self:Info("whitelist = {")

			for sid64, _ in pairs(self.whitelist) do
				self:Info("\t`%s` = `%s`", sid64, string.rep("█", CODE_LENGTH))
			end

			self:Info("}")
		else
			self:Info("whitelist = {}")
		end

		self:Info("")
		self:Info("blacklist_enabled = %s", self.blacklist_enabled)

		if table.Count(self.blacklist) > 0 then
			self:Info("blacklist = {")

			for sid64, reason in pairs(self.blacklist) do
				self:Info("\t`%s` = `%s`", sid64, reason)
			end

			self:Info("}")
		else
			self:Info("blacklist = {}")
		end

		self:Info("")
		self:Info("debug_mode = %s", self.debug_mode)
		self:Info("password_enabled = %s", self.password_enabled)
		self:Info("random_server_password = %s", self.random_server_password)
		self:Info("")
	end)

	_G.WhitelistManagerExists = true
end

if not _G.WhitelistManagerExists then
	WhitelistManager.new():Init()
end
