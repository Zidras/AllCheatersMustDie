local date, GetTime = date, GetTime
local print = print
local tinsert, tremove, tContains = table.insert, table.remove, tContains
local AddIgnore, IsIgnored = AddIgnore, IsIgnored
local UnitName = UnitName

ACMD = {}
local SettingsDB
local ACMDframe = CreateFrame("Frame", "ACMDFrame")
ACMDframe:RegisterEvent("ADDON_LOADED")
ACMDframe:SetScript("OnEvent", function(_, _, addon)
	if addon == "AllCheatersMustDie" then
		ACMD.Initialized = true
		-- Initialize Database
		if not AllCheatersMustDieDB then
			AllCheatersMustDieDB = {
				cheaters = {},
				settings = {
					whisperOnly = false,
					debugEnabled = false
				}
			}
		end
		-- Repair Database from v1.0
		if not AllCheatersMustDieDB.settings then
			AllCheatersMustDieDB.settings = {
				whisperOnly = true,
				debugEnabled = false
			}
		end
		SettingsDB = AllCheatersMustDieDB.settings
	end
end)

-- Slash commands
SLASH_ALLCHEATERSMUSTDIE1 = "/acmd"
SlashCmdList["ALLCHEATERSMUSTDIE"] = function(msg)
	if msg == "whisper" then
		SettingsDB.whisperOnly = SettingsDB.whisperOnly == false and true or false
		print("|cff00ff00[All Cheaters Must Die]|r: Whisper only mode is now "..(SettingsDB.whisperOnly and "enabled" or "disabled"))
	elseif msg == "debug" then
		SettingsDB.debugEnabled = SettingsDB.debugEnabled == false and true or false
		print("|cff00ff00[All Cheaters Must Die]|r: Debug mode is now "..(SettingsDB.debugEnabled and "enabled" or "disabled"))
	elseif msg == "reset" then
		AllCheatersMustDieDB.cheaters = {}
		print("|cff00ff00[All Cheaters Must Die]|r: Cheaters list has been reset")
	else
		print("|cff00ff00[All Cheaters Must Die]|r has the following commands:\n-|cff00ff00whisper|r : If enabled, all addon comms from channels other than \"WHISPER\" (so \"GUILD\", \"PARTY\", \"RAID\", ...) are considered safe.\n-|cff00ff00debug|r : Print all incoming addon comms in chat.\n-|cff00ff00reset|r : Clear all recorded cheaters in the database.")
	end
end

local msgDB, tempCheaters = {}, {}
local processor
local function antiCheat(_, _, prefix, message, channel, sender)
	if not ACMD.Initialized then return end

	if SettingsDB.debugEnabled then
		print("|cff00ff00[All Cheaters Must Die]|r sender: " .. sender, ", with the following prefix: ", prefix, ", and message: ", message, ", on channel: ", channel)
	end

	if UnitName("player") == sender then return end
	if IsIgnored(sender) then return end
	if tContains(tempCheaters, sender) then return end
	if SettingsDB.whisperOnly and channel ~= "WHISPER" then return end

	local currentTime, currentDate = GetTime(), date()
	if sender and sender ~= "" then -- sender == "" is a Warmane specific server-side message
		if not msgDB[sender] then
			msgDB[sender] = {
				channel = channel,
				count = 0,
				date = currentDate,
				time = currentTime,
				message = message,
				prefix = prefix,
				spamCount = 0,
				timestamps = {},
			}
		end

		ACMD.Processor = msgDB -- Pass this table to the global table if it needs to be accessed
		processor = msgDB[sender]

		-- update sender table and raise event counter
		processor.channel = channel
		processor.count = processor.count + 1
		processor.date = currentDate
		processor.time = currentTime
		processor.message = message
		processor.prefix = prefix
		tinsert(processor.timestamps, {
			channel = channel,
			count = processor.count,
			date = currentDate,
			time = currentTime,
			message = message,
			prefix = prefix,
			spamCount = 0
		})

		if #processor.timestamps > 25 then
			tremove(processor.timestamps, 1)
		end

		-- compare timestamps
		local tableIndex = #processor.timestamps or 1
		if tableIndex > 1 then
			if processor.timestamps[tableIndex].time - processor.timestamps[tableIndex - 1].time < 0.05 then
				processor.spamCount = processor.spamCount + 1
			else
				processor.spamCount = 0
			end
		end
		processor.timestamps[tableIndex].spamCount = processor.spamCount -- add spamCount to the timestamps table for logging purposes

		-- check for potential attack
		-- if event counter is greater than 20, add to cheaters list
		if processor.spamCount > 20 then
			AllCheatersMustDieDB.cheaters[sender] = processor -- add cheater and log to database
			tinsert(tempCheaters, sender) -- needed because IsIgnored API was not returning in real time
			AddIgnore(sender)
			print("|cff00ff00[All Cheaters Must Die]|r Detected and ignored potential DoS attacker: ", sender,", with the following prefix: ", prefix, ", and message: ", message)
		end
	end
end

-- Log CHAT_MSG_ADDON messages
local antiCheatFrame = CreateFrame("Frame")
antiCheatFrame:RegisterEvent("CHAT_MSG_ADDON")
antiCheatFrame:SetScript("OnEvent", antiCheat)