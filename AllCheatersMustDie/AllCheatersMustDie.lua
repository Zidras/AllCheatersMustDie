local date, GetTime = date, GetTime
local print = print
local tinsert, tremove, tContains = table.insert, table.remove, tContains
local AddIgnore, IsIgnored = AddIgnore, IsIgnored
local UnitName = UnitName

-- Initialize Database
if not AllCheatersMustDieDB then
	AllCheatersMustDieDB = {
		cheaters = {}
	}
end

local msgDB, tempCheaters = {}, {}
local function antiCheat(_, _, prefix, message, channel, sender)
--	print("|cff00ff00[CheatersMustDie]|r "..sender.." "..message)
	if UnitName("player") == sender then return end
	if IsIgnored(sender) then return end
	if tContains(tempCheaters, sender) then return end

	if sender then
		if not msgDB[sender] then
			msgDB[sender] = {
				channel = channel,
				count = 0,
				date = date(),
				message = message,
				prefix = prefix,
				spamCount = 0,
				timestamps = {},
			}
		end

		-- update sender table and raise event counter
		msgDB[sender].channel = channel
		msgDB[sender].count = msgDB[sender].count + 1
		msgDB[sender].date = date()
		msgDB[sender].message = message
		msgDB[sender].prefix = prefix
		tinsert(msgDB[sender].timestamps, GetTime())

		if #msgDB[sender].timestamps > 25 then
			tremove(msgDB[sender].timestamps, 1)
		end

		-- compare timestamps
		local tableIndex = #msgDB[sender].timestamps or 1
		if tableIndex > 1 then
			if msgDB[sender].timestamps[tableIndex] - msgDB[sender].timestamps[tableIndex - 1] < 0.1 then
				msgDB[sender].spamCount = msgDB[sender].count + 1
			else
				msgDB[sender].spamCount = 0
			end
		end

		-- check for cheater
		-- if event counter is greater than 50, add to cheaters list
		if msgDB[sender].spamCount > 50 then
			AllCheatersMustDieDB.cheaters[sender] = msgDB[sender]
			tinsert(tempCheaters, sender) -- needed because IsIgnored API was not returning in real time
			SendChatMessage("Go fuck yourself.", "WHISPER", nil, sender);
			AddIgnore(sender)
			print("|cff00ff00[CheatersMustDie] |rDetected and ignored potential DoS attacker: ", sender,", with the following prefix: ", prefix, ", and message: ", message)
		end
	end
end

-- Log CHAT_MSG_ADDON messages
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", antiCheat)