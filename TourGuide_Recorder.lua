

local al = DongleStub("Astrolabe-0.4")
local currentquests, oldquests, currentboards, oldboards, titles, firstscan, abandoning, db = {}, {}, {}, {}, {}, true
local qids = setmetatable({}, {
	__index = function(t,i)
		local v = tonumber(i:match("|Hquest:(%d+):"))
		t[i] = v
		return v
	end,
})


local function Debug(msg) ChatFrame6:AddMessage(tostring(msg)) end

local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")


function f:ADDON_LOADED(event, addon)
	if addon ~= "TourGuide_Recorder" then return end

	TourGuide_RecorderDB = TourGuide_RecorderDB or ""
	db = TourGuide_RecorderDB

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	self:RegisterEvent("QUEST_LOG_UPDATE")
end


local function Save(val)
	TourGuide_RecorderDB = TourGuide_RecorderDB..val
	Debug(val:gsub("|", "||"):gsub("\n", ""))
end

function f:QUEST_LOG_UPDATE()
--~ 	Debug("QUEST_LOG_UPDATE")
	currentquests, oldquests = oldquests, currentquests
	currentboards, oldboards = oldboards, currentboards
	for i in pairs(currentquests) do currentquests[i] = nil end
	for i in pairs(currentboards) do currentboards[i] = nil end

	for i=1,GetNumQuestLogEntries() do
		local link = GetQuestLink(i)
		local qid = link and qids[link]
		if qid then
			currentquests[qid] = true
			titles[qid] = GetQuestLogTitle(i)

			for j=1,GetNumQuestLeaderBoards(i) do
				local text, objtype, finished = GetQuestLogLeaderBoard(j, i)
				if finished then
					currentboards[qid.."."..j] = text
				end
			end
		end
	end

	if firstscan then
		firstscan = nil
		return
	end

	local _, _, x, y = al:GetCurrentPlayerPosition()

	for qidboard,text in pairs(currentboards) do
		if not oldboards[qidboard] then
			Save(string.format("\n- |QID|%s| |QO|%s| |N|%s, %s (%.2f, %.2f)|", qidboard, text, GetZoneText(), GetSubZoneText(), x*100, y*100))
		end
	end

	for qid in pairs(oldquests) do
		if not currentquests[qid] then
			local action = abandoning and "Abandoned quest" or "Turned in quest"
			if not abandoning then Save(string.format("\nT %s |QID|%s| |N|%s, %s (%.2f, %.2f)|", titles[qid], qid, GetZoneText(), GetSubZoneText(), x*100, y*100)) end
			abandoning = nil
			return
		end
	end

	for qid in pairs(currentquests) do
		if not oldquests[qid] then
			Save(string.format("\nA %s |QID|%s| |N|%s, %s (%.2f, %.2f)|", titles[qid], qid, GetZoneText(), GetSubZoneText(), x*100, y*100))
			return
		end
	end
end


local orig = AbandonQuest
function AbandonQuest(...)
	abandoning = true
	return orig(...)
end


local used = {}
hooksecurefunc("UseContainerItem", function(bag, slot, ...)
	if MerchantFrame:IsVisible() then return end
	local link = GetContainerItemLink(bag, slot)
	if link and not used[link] then
		used[link] = true
		local _, _, x, y = al:GetCurrentPlayerPosition()
		Save(string.format("\nU %s |N|%s, %s (%.2f, %.2f)|", link, GetZoneText(), GetSubZoneText(), x*100, y*100))
	end
end)


SLASH_TGR1 = "/tgr"
function SlashCmdList.TGR(msg)
	local _, _, x, y = al:GetCurrentPlayerPosition()
	Save(string.format("\nN %s |N|%s, %s (%.2f, %.2f)|", msg or "No note", GetZoneText(), GetSubZoneText(), x*100, y*100))
end
