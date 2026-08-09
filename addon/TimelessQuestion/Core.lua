local ADDON, ns = ...
local L = ns.L

local QUEST_ID = 33211 -- A Timeless Question / Éternelle question
local NPC_ID = 73570 -- Senior Historian Evelyna / Historienne en chef Evelyna

-- Bump to invalidate stored verdicts: when ns.Normalize changes shape, or when a
-- bug is found to have recorded false ones. 3 clears the bad "wrong" verdicts
-- left by the timeout that mistook a slow turn-in for a rejected answer.
local STATE_VERSION = 3

local db
local pending -- answer awaiting its verdict: { key, id, name }

local DEFAULTS = {
	enabled = true,
	autoAccept = true,
	autoAnswer = true,
	autoTurnIn = true,
	learned = {}, -- normalised option text -> true (correct) / false (ruled out)
	learnedIDs = {}, -- gossip option id -> true, once seen accepted in play
	wrongIDs = {}, -- gossip option id -> true, once rejected in play
}

local function Print(fmt, ...)
	local text = select("#", ...) > 0 and fmt:format(...) or fmt
	DEFAULT_CHAT_FRAME:AddMessage(L["PREFIX"] .. text)
end

--------------------------------------------------------------------------------
-- API compatibility
--
-- Mists of Pandaria Classic ships the modern C_GossipInfo / C_QuestLog APIs;
-- the fallbacks keep the addon working on older Classic clients.
--------------------------------------------------------------------------------

local function GetGossipOptionList()
	if C_GossipInfo and C_GossipInfo.GetOptions then
		return C_GossipInfo.GetOptions() or {}
	end
	local list, raw = {}, { GetGossipOptions() }
	for i = 1, #raw, 2 do
		list[#list + 1] = { name = raw[i] }
	end
	return list
end

local function SelectGossipOptionCompat(option, index)
	if C_GossipInfo and C_GossipInfo.SelectOption then
		C_GossipInfo.SelectOption(option.gossipOptionID or index)
	else
		SelectGossipOption(index)
	end
end

local function GetGossipQuestion()
	if C_GossipInfo and C_GossipInfo.GetText then
		return C_GossipInfo.GetText()
	end
	return GetGossipText and GetGossipText()
end

local function GetAvailableQuestList()
	if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
		return C_GossipInfo.GetAvailableQuests() or {}
	end
	return {}
end

local function GetActiveQuestList()
	if C_GossipInfo and C_GossipInfo.GetActiveQuests then
		return C_GossipInfo.GetActiveQuests() or {}
	end
	return {}
end

local function SelectAvailableQuestCompat(entry, index)
	if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
		C_GossipInfo.SelectAvailableQuest(entry and entry.questID or index)
	else
		SelectGossipAvailableQuest(index)
	end
end

local function SelectActiveQuestCompat(entry, index)
	if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
		C_GossipInfo.SelectActiveQuest(entry and entry.questID or index)
	else
		SelectGossipActiveQuest(index)
	end
end

local function IsOnQuest()
	if C_QuestLog and C_QuestLog.IsOnQuest then
		return C_QuestLog.IsOnQuest(QUEST_ID)
	end
	local index = GetQuestLogIndexByID and GetQuestLogIndexByID(QUEST_ID)
	return index and index > 0
end

local function IsReadyForTurnIn()
	if C_QuestLog and C_QuestLog.ReadyForTurnIn then
		return C_QuestLog.ReadyForTurnIn(QUEST_ID) and true or false
	end
	return false
end

local function IsDoneToday()
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		return C_QuestLog.IsQuestFlaggedCompleted(QUEST_ID) and true or false
	end
	return IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(QUEST_ID) or false
end

--------------------------------------------------------------------------------
-- Evelyna detection: NPC id from the GUID, so it is language independent.
--------------------------------------------------------------------------------

local function AtEvelyna()
	local guid = UnitGUID("npc") or UnitGUID("target")
	if not guid then return false end
	local unitType = strsplit("-", guid)
	if unitType ~= "Creature" and unitType ~= "Vehicle" then return false end
	return tonumber((select(6, strsplit("-", guid)))) == NPC_ID
end

--------------------------------------------------------------------------------
-- Answer selection
--
-- The question text is never read. Each option is resolved in order of
-- confidence, and the option id path is what makes this work in a language
-- nobody involved can read.
--------------------------------------------------------------------------------

local function ResolveAnswer(options)
	-- 1. Already seen accepted on this account: the only ground truth there is.
	for index, option in ipairs(options) do
		local key = ns.Normalize(option.name)
		if key and db.learned[key] == true then
			return option, index, key, "learned"
		end
	end

	-- 2. Server-side option id, identical in every locale.
	for index, option in ipairs(options) do
		local id = option.gossipOptionID
		local key = ns.Normalize(option.name)
		if id and (ns.CORRECT_IDS[id] or db.learnedIDs[id]) and not db.wrongIDs[id]
			and (not key or db.learned[key] ~= false) then
			return option, index, key, "id"
		end
	end

	-- 3. Shipped answer text, for clients that send no usable option id.
	local match, matchIndex, matchKey, matches = nil, nil, nil, 0
	for index, option in ipairs(options) do
		local key = ns.Normalize(option.name)
		if key and ns.CORRECT[key] and db.learned[key] ~= false then
			matches = matches + 1
			match, matchIndex, matchKey = option, index, key
		end
	end
	if matches == 1 then
		return match, matchIndex, matchKey, "db"
	end

	-- 4. One option left once every known decoy is removed.
	local remaining = {}
	for index, option in ipairs(options) do
		local key = ns.Normalize(option.name)
		if key and not ns.WRONG[key] and db.learned[key] ~= false then
			remaining[#remaining + 1] = { option = option, index = index, key = key }
		end
	end

	if #remaining == 1 then
		local only = remaining[1]
		return only.option, only.index, only.key, "elimination"
	end

	if #remaining == 0 then
		-- Everything is ruled out, so the stored verdicts must be stale. Drop
		-- them for this question rather than sit there stuck.
		for _, option in ipairs(options) do
			local key = ns.Normalize(option.name)
			if key then db.learned[key] = nil end
		end
		for index, option in ipairs(options) do
			local key = ns.Normalize(option.name)
			if key then return option, index, key, "guess" end
		end
		return nil
	end

	-- Always try something. Being wrong costs one retry and is recorded, so
	-- refusing to answer would only make the addon slower to self-correct.
	local guess = remaining[1]
	return guess.option, guess.index, guess.key, "guess"
end

local ResolvePending

local REASON_LABEL = {
	learned = L["VIA_LEARNED"],
	id = L["VIA_ID"],
	db = L["VIA_TEXT"],
	elimination = L["VIA_ELIMINATION"],
	guess = L["VIA_GUESS"],
}

local function AnswerQuestion()
	local options = GetGossipOptionList()

	-- A correct answer is acknowledged with an optionless page ("C'est exact !").
	-- Bailing out here is what keeps it from being mistaken for a new question,
	-- which would record the pending answer as wrong.
	if #options < 2 then return end

	-- A real question while an answer is still pending means that answer was
	-- rejected; ResolvePending double-checks it against the quest log.
	if pending then ResolvePending(nil) end

	local option, index, key, reason = ResolveAnswer(options)
	if not option then
		Print(L["ANSWER_UNKNOWN"])
		return
	end

	local question = GetGossipQuestion()
	if question and question ~= "" then
		Print(L["FOUND_QUESTION"], question)
	end
	Print(L["FOUND_ANSWER"], index, option.name, REASON_LABEL[reason])

	if not db.autoAnswer then
		Print(L["SUGGEST"])
		return
	end

	pending = { key = key, id = option.gossipOptionID, name = option.name }
	local snapshot = pending

	-- Deferred by one frame: selecting from inside the GOSSIP_SHOW handler can
	-- re-enter the gossip frame while it is still being built.
	C_Timer.After(0, function()
		SelectGossipOptionCompat(option, index)
	end)

	-- Drop a stale pending answer eventually, but WITHOUT recording a verdict.
	-- A timeout is not evidence: an earlier build treated it as "wrong" and
	-- blacklisted a correct answer whose quest completed a moment later.
	C_Timer.After(60, function()
		if pending == snapshot then pending = nil end
	end)
end

--------------------------------------------------------------------------------
-- Verdict tracking
--
-- The game itself decides, which is what lets a shipped mistake correct itself.
-- A confirmed answer also teaches its option id, so a question missing from the
-- shipped id table is covered from then on in every language.
--------------------------------------------------------------------------------

function ResolvePending(correct)
	if not pending then return end
	if correct == nil then
		correct = IsReadyForTurnIn() or (not IsOnQuest() and IsDoneToday())
	end

	if pending.key then
		db.learned[pending.key] = correct and true or false
	end
	-- Blacklisting by id as well as by text keeps a bad answer rejected after a
	-- language change, where the text key would no longer match.
	if pending.id then
		if correct then
			db.learnedIDs[pending.id] = true
			db.wrongIDs[pending.id] = nil
		else
			db.wrongIDs[pending.id] = true
		end
	end

	Print(correct and L["RESULT_OK"] or L["RESULT_BAD"], pending.name)
	pending = nil
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

local handlers = {}

function handlers.GOSSIP_SHOW()
	if not db.enabled or not AtEvelyna() then return end

	if db.autoTurnIn and IsReadyForTurnIn() then
		local active = GetActiveQuestList()
		for index, entry in ipairs(active) do
			if entry.questID == QUEST_ID or (#active == 1 and not entry.questID) then
				SelectActiveQuestCompat(entry, index)
				return
			end
		end
		-- She sometimes acknowledges the correct answer with a single-option
		-- dialogue before offering the turn-in; clear it.
		local options = GetGossipOptionList()
		if #options == 1 and #GetAvailableQuestList() == 0 then
			SelectGossipOptionCompat(options[1], 1)
			return
		end
	end

	if db.autoAccept and not IsOnQuest() and not IsDoneToday() then
		local available = GetAvailableQuestList()
		for index, entry in ipairs(available) do
			if entry.questID == QUEST_ID or (#available == 1 and not entry.questID) then
				SelectAvailableQuestCompat(entry, index)
				return
			end
		end
	end

	if IsOnQuest() and not IsReadyForTurnIn() then
		AnswerQuestion()
	end
end

function handlers.QUEST_DETAIL()
	if not db.enabled or not db.autoAccept or not AtEvelyna() then return end
	if GetQuestID() ~= QUEST_ID then return end
	AcceptQuest()
end

function handlers.QUEST_ACCEPTED(a, b)
	-- Modern clients pass questID; older Classic ones pass (questLogIndex, questID).
	if not db.enabled or (a ~= QUEST_ID and b ~= QUEST_ID) then return end
	Print(L["ACCEPTED"])
end

function handlers.QUEST_PROGRESS()
	if not db.enabled or not db.autoTurnIn or not AtEvelyna() then return end
	if GetQuestID() ~= QUEST_ID then return end
	if IsQuestCompletable() then CompleteQuest() end
end

function handlers.QUEST_COMPLETE()
	if not db.enabled or not db.autoTurnIn or not AtEvelyna() then return end
	if GetQuestID() ~= QUEST_ID then return end
	if GetNumQuestChoices() > 1 then return end -- never pick a reward for the player
	GetQuestReward(GetNumQuestChoices() == 1 and 1 or 0)
end

function handlers.QUEST_TURNED_IN(questID)
	if questID ~= QUEST_ID then return end
	ResolvePending(true)
	if db.enabled then Print(L["TURNED_IN"]) end
end

function handlers.UNIT_QUEST_LOG_CHANGED(unit)
	if unit ~= "player" or not pending then return end
	if IsReadyForTurnIn() then ResolvePending(true) end
end

function handlers.QUEST_LOG_UPDATE()
	if pending and IsReadyForTurnIn() then ResolvePending(true) end
end

function handlers.ADDON_LOADED(name)
	if name ~= ADDON then return end
	TimelessQuestionDB = TimelessQuestionDB or {}
	db = TimelessQuestionDB
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil then
			db[key] = type(value) == "table" and {} or value
		end
	end
	-- Rejections are the dangerous half of the state: one bad "wrong" hides a
	-- correct answer for good. So a version change clears every rejection, both
	-- the text keys (only comparable within one ns.Normalize revision) and the
	-- id blacklist. Confirmations are kept: they were positively observed.
	if db.stateVersion ~= STATE_VERSION then
		wipe(db.learned)
		wipe(db.wrongIDs)
		db.stateVersion = STATE_VERSION
		db.normalizeVersion = nil
	end
	ns.db = db
end

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	if event ~= "ADDON_LOADED" and not db then return end
	handlers[event](...)
end)

--------------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------------

local function Toggle(key, label)
	db[key] = not db[key]
	Print("%s: %s", label, db[key] and L["ON"] or L["OFF"])
end

local function PrintStatus()
	Print(L["STATUS"])
	local rows = {
		{ L["OPT_ENABLED"], db.enabled },
		{ L["OPT_ACCEPT"], db.autoAccept },
		{ L["OPT_ANSWER"], db.autoAnswer },
		{ L["OPT_TURNIN"], db.autoTurnIn },
	}
	for _, row in ipairs(rows) do
		DEFAULT_CHAT_FRAME:AddMessage(("  %s: %s"):format(row[1], row[2] and L["ON"] or L["OFF"]))
	end

	local learnedExtra = 0
	for id in pairs(db.learnedIDs) do
		if not ns.CORRECT_IDS[id] then learnedExtra = learnedExtra + 1 end
	end
	Print(L["KNOWN_COUNT"], ns.ANSWER_ID_COUNT + learnedExtra)
end

SLASH_TIMELESSQUESTION1 = "/tq"
SLASH_TIMELESSQUESTION2 = "/timelessquestion"
SlashCmdList.TIMELESSQUESTION = function(input)
	local command = (input or ""):lower():match("^%s*(%S*)")

	if command == "on" or command == "off" then
		db.enabled = (command == "on")
		Print("%s: %s", L["OPT_ENABLED"], db.enabled and L["ON"] or L["OFF"])
	elseif command == "accept" then
		Toggle("autoAccept", L["OPT_ACCEPT"])
	elseif command == "answer" then
		Toggle("autoAnswer", L["OPT_ANSWER"])
	elseif command == "turnin" then
		Toggle("autoTurnIn", L["OPT_TURNIN"])
	elseif command == "reset" then
		wipe(db.learned)
		wipe(db.learnedIDs)
		wipe(db.wrongIDs)
		Print(L["RESET_DONE"])
	elseif command == "" then
		PrintStatus()
	else
		DEFAULT_CHAT_FRAME:AddMessage(L["HELP_TITLE"])
		local lines = {
			{ "/tq", L["HELP_STATUS"] },
			{ "/tq on|off", L["HELP_ONOFF"] },
			{ "/tq accept", L["HELP_ACCEPT"] },
			{ "/tq answer", L["HELP_ANSWER"] },
			{ "/tq turnin", L["HELP_TURNIN"] },
			{ "/tq reset", L["HELP_RESET"] },
		}
		for _, line in ipairs(lines) do
			DEFAULT_CHAT_FRAME:AddMessage(("  |cffffff00%s|r - %s"):format(line[1], line[2]))
		end
	end
end
