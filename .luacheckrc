std = "lua51"

max_line_length = false
self = false

exclude_files = { ".release/", "dist/" }

read_globals = {
	-- Lua/WoW additions
	"strsplit", "wipe", "format", "tinsert", "table", "string", "select", "type",
	"tonumber", "tostring", "pairs", "ipairs", "setmetatable", "unpack",

	-- WoW API
	"CreateFrame",
	"UIParent",
	"STANDARD_TEXT_FONT",
	"ceil",
	"GetTime",
	"GetServerTime",
	"DEFAULT_CHAT_FRAME",
	"GetLocale",
	"UnitGUID",
	"UnitName",
	"C_Timer",
	"C_GossipInfo",
	"C_QuestLog",
	"GetGossipOptions",
	"GetGossipText",
	"CloseGossip",
	"SelectGossipOption",
	"SelectGossipAvailableQuest",
	"SelectGossipActiveQuest",
	"GetQuestLogIndexByID",
	"IsQuestFlaggedCompleted",
	"GetQuestID",
	"AcceptQuest",
	"CompleteQuest",
	"IsQuestCompletable",
	"GetNumQuestChoices",
	"GetQuestReward",
}

globals = {
	"TimelessQuestionDB",
	"SLASH_TIMELESSQUESTION1",
	"SLASH_TIMELESSQUESTION2",
	"SlashCmdList",
}
