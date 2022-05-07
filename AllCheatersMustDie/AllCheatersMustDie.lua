local date, GetTime = date, GetTime
local print = print
local tinsert, tremove, tContains = table.insert, table.remove, tContains
local AddIgnore, IsIgnored = AddIgnore, IsIgnored
local UnitName = UnitName

ACMD = {}

local ACMDframe = CreateFrame("Frame", "ACMDFrame")
ACMDframe:RegisterEvent("ADDON_LOADED")
ACMDframe:SetScript("OnEvent", function(self, event, addon)
	if addon == "AllCheatersMustDie" then
		ACMD.Initialized = true
		-- Initialize Database
		if not AllCheatersMustDieDB then
			AllCheatersMustDieDB = {
				cheaters = {},
				settings = {
					whisperOnly = true,
					debugEnabled = false
				}
			}
		end
	end
end)

-- Slash commands
SLASH_ALLCHEATERSMUSTDIE1 = "/acmd"
SlashCmdList["ALLCHEATERSMUSTDIE"] = function(msg)
	if msg == "help" then
		print("|cff00ff00[All Cheaters Must Die]|r has the following commands:\n-whisper\n-debug")
	elseif msg == "whisper" then
		AllCheatersMustDieDB.settings.whisperOnly = AllCheatersMustDieDB.settings.whisperOnly == false and true or false
		print("|cff00ff00[All Cheaters Must Die]|r: Whisper only mode is now "..(AllCheatersMustDieDB.settings.whisperOnly and "enabled" or "disabled"))
	elseif msg == "debug" then
		AllCheatersMustDieDB.settings.debugEnabled = AllCheatersMustDieDB.settings.debugEnabled == false and true or false
		print("|cff00ff00[All Cheaters Must Die]|r: Debug mode is now "..(AllCheatersMustDieDB.settings.debugEnabled and "enabled" or "disabled"))
	end
end

local msgDB, tempCheaters = {}, {}
local function antiCheat(_, _, prefix, message, channel, sender)
	if not ACMD.Initialized then return end

	if AllCheatersMustDieDB.settings.debugEnabled then
		print("|cff00ff00[All Cheaters Must Die]|r sender: " .. sender, ", with the following prefix: ", prefix, ", and message: ", message, ", on channel: ", channel)
	end

	if UnitName("player") == sender then return end
	if IsIgnored(sender) then return end
	if tContains(tempCheaters, sender) then return end
	if AllCheatersMustDieDB.settings.whisperOnly and channel ~= "WHISPER" then return end

	local currentTime, currentDate = GetTime(), date()
	if sender then
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

		-- update sender table and raise event counter
		msgDB[sender].channel = channel
		msgDB[sender].count = msgDB[sender].count + 1
		msgDB[sender].date = currentDate
		msgDB[sender].time = currentTime
		msgDB[sender].message = message
		msgDB[sender].prefix = prefix
		tinsert(msgDB[sender].timestamps, {
			channel = channel,
			count = msgDB[sender].count,
			date = currentDate,
			time = currentTime,
			message = message,
			prefix = prefix,
		})

		if #msgDB[sender].timestamps > 50 then
			tremove(msgDB[sender].timestamps, 1)
		end

		-- compare timestamps
		local tableIndex = #msgDB[sender].timestamps or 1
		if tableIndex > 1 then
			if msgDB[sender].timestamps[tableIndex].time - msgDB[sender].timestamps[tableIndex - 1].time < 0.05 then
				msgDB[sender].spamCount = msgDB[sender].count + 1
			else
				msgDB[sender].spamCount = 0
			end
		end

		-- check for cheater
		-- if event counter is greater than 100, add to cheaters list
		if msgDB[sender].spamCount > 100 then
			AllCheatersMustDieDB.cheaters[sender] = msgDB[sender]
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