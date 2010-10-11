
local myname, ns = ...

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

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
end


local function Save(val)
	TourGuide_RecorderDB = TourGuide_RecorderDB..val
	Debug(val:gsub("|", "||"):gsub("\n", ""))
end

local function coords()
	local x, y = GetPlayerMapPosition("player")
	return x * 100, y * 100
end

function f:PLAYER_LEVEL_UP(event, level)
	Save("\nN Level up! ".. level)
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

	for qidboard,text in pairs(currentboards) do
		if not oldboards[qidboard] then
			Save(string.format("\n- |QID|%s| |QO|%s| |N|%s, %s (%.2f, %.2f)|", qidboard, text, GetZoneText(), GetSubZoneText(), coords()))
		end
	end

	for qid in pairs(oldquests) do
		if not currentquests[qid] then
			local action = abandoning and "Abandoned quest" or "Turned in quest"
			if not abandoning then Save(string.format("\nT %s |QID|%s| |N|%s, %s (%.2f, %.2f)|", titles[qid], qid, GetZoneText(), GetSubZoneText(), coords())) end
			abandoning = nil
			return
		end
	end

	for qid in pairs(currentquests) do
		if not oldquests[qid] then
			Save(string.format("\nA %s |QID|%s| |N|%s, %s (%.2f, %.2f)|", titles[qid], qid, GetZoneText(), GetSubZoneText(), coords()))
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
		Save(string.format("\nU %s |N|%s, %s (%.2f, %.2f)|", link, GetZoneText(), GetSubZoneText(), coords()))
	end
end)


local panel = ns.tekPanelAuction(nil, "TourGuide Recorder log")

SLASH_TGR1 = "/tgr"
function SlashCmdList.TGR(msg)
	if msg:trim() == "" then ShowUIPanel(panel)
	else Save(string.format("\nN %s |N|%s, %s (%.2f, %.2f)|", msg or "No note", GetZoneText(), GetSubZoneText(), coords())) end
end


local LINEHEIGHT, maxoffset, offset = 12, 0, 0


local scroll = CreateFrame("ScrollFrame", nil, panel)
scroll:SetPoint("TOPLEFT", 21, -73)
scroll:SetPoint("BOTTOMRIGHT", -10, 38)
local HEIGHT = scroll:GetHeight()


local editbox = CreateFrame("EditBox", nil, scroll)
scroll:SetScrollChild(editbox)
editbox:SetPoint("TOP")
editbox:SetPoint("LEFT")
editbox:SetPoint("RIGHT")
editbox:SetHeight(1000)
editbox:SetFontObject(GameFontHighlightSmall)
editbox:SetTextInsets(2,2,2,2)
editbox:SetMultiLine(true)
editbox:SetAutoFocus(false)
local function SetEditbox()
	editbox:SetText(TourGuide_RecorderDB:trim():gsub("|N", "||N"):gsub("|H(item:%d+):%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+", "%1 "):gsub("|cff......", ""):gsub("|r", ""))
	editbox:HighlightText()
end
editbox:SetScript("OnShow", function(self)
	self:SetFocus()
	SetEditbox()
end)
editbox:SetScript("OnEscapePressed", function() HideUIPanel(panel) end)
editbox:SetScript("OnTextChanged", function(self, user) if user then SetEditbox() end end)


local function doscroll(v)
	offset = math.max(math.min(v, 0), maxoffset)
	scroll:SetVerticalScroll(-offset)
	editbox:SetPoint("TOP", 0, offset)
end

editbox:SetScript("OnCursorChanged", function(self, x, y, width, height)
	LINEHEIGHT = height
	if offset < y then
		doscroll(y)
	elseif math.floor(offset - HEIGHT + height*2) > y then
		local v = y + HEIGHT - height*2
		maxoffset = math.min(maxoffset, v)
		doscroll(v)
	end
end)

scroll:UpdateScrollChildRect()
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, val) doscroll(offset + val*LINEHEIGHT*3) end)


StaticPopupDialogs["TOURGUIDE_RECORDER_RESET"] = {
	text = "Really erase TourGuide Recorder's log?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function() TourGuide_RecorderDB = ""; SetEditbox() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

local b = CreateFrame("Button", nil, panel)
b:SetPoint("TOPRIGHT", scroll, "BOTTOMRIGHT", 3, -1)
b:SetWidth(80) b:SetHeight(22)

-- Fonts --
b:SetDisabledFontObject(GameFontDisable)
b:SetHighlightFontObject(GameFontHighlight)
b:SetNormalFontObject(GameFontNormal)

-- Textures --
b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
b:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
b:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
b:GetPushedTexture():SetTexCoord(0, 0.625, 0, 0.6875)
b:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)
b:GetDisabledTexture():SetTexCoord(0, 0.625, 0, 0.6875)
b:GetHighlightTexture():SetBlendMode("ADD")

b:SetText("Clear")
b:SetScript("OnCLick", function() StaticPopup_Show("TOURGUIDE_RECORDER_RESET") end)
