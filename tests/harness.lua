-- Mock WoW client, just complete enough to exercise the gossip flow at Evelyna.
--
-- The point of this file is the dialogue sequence rather than the answer table:
-- accept, answer, dismiss her reply, hand in. Two bugs in this addon's history
-- were flow bugs that a linter cannot see, so the flow is what gets tested.

local failures, checks = 0, 0
local function check(label, cond, extra)
    checks = checks + 1
    if cond then
        print("  ok    " .. label)
    else
        failures = failures + 1
        print("  FAIL  " .. label .. (extra ~= nil and ("   [" .. tostring(extra) .. "]") or ""))
    end
end

local QUEST_ID, NPC_ID = 33211, 73570
print(("### locale: %s"):format(LOCALE_UNDER_TEST or "enUS"))

--------------------------------------------------------------------------------
-- Fake client
--------------------------------------------------------------------------------

local clock = 1000
local timers = {}
local calls = {}
local frames = {}

local function record(name, value)
    calls[#calls + 1] = { name = name, value = value }
end

local function tookAction(name)
    for _, c in ipairs(calls) do
        if c.name == name then
            if c.value == nil then return true end
            return c.value
        end
    end
    return nil
end

local function resetCalls() calls = {} end

local function runTimers()
    local due, keep = {}, {}
    for _, t in ipairs(timers) do
        if t.at <= clock then due[#due + 1] = t else keep[#keep + 1] = t end
    end
    timers = keep
    for _, t in ipairs(due) do t.fn() end
end

local function advance(seconds)
    clock = clock + seconds
    runTimers()
end

function GetLocale() return LOCALE_UNDER_TEST or "enUS" end
function GetTime() return clock end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

function strsplit(sep, str)
    local out, start = {}, 1
    while true do
        local i = string.find(str, sep, start, true)
        if not i then
            out[#out + 1] = string.sub(str, start)
            break
        end
        out[#out + 1] = string.sub(str, start, i - 1)
        start = i + #sep
    end
    return table.unpack(out)
end

DEFAULT_CHAT_FRAME = { messages = {} }
function DEFAULT_CHAT_FRAME:AddMessage(msg)
    self.messages[#self.messages + 1] = msg
end

local function chatContains(needle)
    for _, m in ipairs(DEFAULT_CHAT_FRAME.messages) do
        if string.find(m, needle, 1, true) then return m end
    end
    return nil
end

C_Timer = {}
function C_Timer.After(delay, fn)
    timers[#timers + 1] = { at = clock + delay, fn = fn }
end

function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = f
    return f
end

SlashCmdList = {}

-- Mutable client state that the tests drive.
local state = {
    guid = ("Creature-0-1-2-3-%d-000ABC"):format(NPC_ID),
    options = {},
    available = {},
    active = {},
    text = "",
    onQuest = false,
    ready = false,
    doneToday = false,
}

function UnitGUID() return state.guid end

local QUESTION_OPTIONS = {
    { name = "Gorlocs.", gossipOptionID = 130907 },
    { name = "Mur'ghouls.", gossipOptionID = 130908 },
    { name = "Wolvar.", gossipOptionID = 130909 },
    { name = "Mur'liches.", gossipOptionID = 130910 },
}
local QUESTION_TEXT = "What are undead murlocs called?"
local CORRECT_ID = 130908

C_GossipInfo = {}
function C_GossipInfo.GetOptions() return state.options end
function C_GossipInfo.GetText() return state.text end
function C_GossipInfo.GetAvailableQuests() return state.available end
function C_GossipInfo.GetActiveQuests() return state.active end
function C_GossipInfo.SelectOption(id) record("SelectOption", id) end
function C_GossipInfo.SelectAvailableQuest(id) record("SelectAvailableQuest", id) end
function C_GossipInfo.SelectActiveQuest(id) record("SelectActiveQuest", id) end
function C_GossipInfo.CloseGossip() record("CloseGossip", true) end

C_QuestLog = {}
function C_QuestLog.IsOnQuest(id) return id == QUEST_ID and state.onQuest end
function C_QuestLog.ReadyForTurnIn(id) return id == QUEST_ID and state.ready end
function C_QuestLog.IsQuestFlaggedCompleted(id) return id == QUEST_ID and state.doneToday end

function GetQuestID() return QUEST_ID end
function AcceptQuest() record("AcceptQuest") state.onQuest = true end
function CompleteQuest() record("CompleteQuest") end
function IsQuestCompletable() return true end
function GetNumQuestChoices() return 0 end
function GetQuestReward() record("GetQuestReward") end

--------------------------------------------------------------------------------
-- Load the shipped files the way WoW does: varargs (addonName, privateTable)
--------------------------------------------------------------------------------

local ns = {}
for _, pair in ipairs({
    { "Locale.lua", LOCALE_SOURCE },
    { "Answers.lua", ANSWERS_SOURCE },
    { "Core.lua", CORE_SOURCE },
}) do
    local chunk, err = load(pair[2], pair[1])
    if not chunk then
        print("  FAIL  load " .. pair[1] .. ": " .. tostring(err))
        TEST_FAILURES = 1
        return
    end
    chunk("TimelessQuestion", ns)
end

local frame = frames[1]
check("addon registered an event frame", frame ~= nil and frame.handler ~= nil)

local function fire(event, ...)
    frame.handler(frame, event, ...)
end

fire("ADDON_LOADED", "TimelessQuestion")
check("saved variables created", type(TimelessQuestionDB) == "table")
check("ships an answer for every question", ns.ANSWER_ID_COUNT == 37, ns.ANSWER_ID_COUNT)

--------------------------------------------------------------------------------
-- The whole daily, in order
--------------------------------------------------------------------------------

print("-- taking the quest")
resetCalls()
state.available = { { questID = QUEST_ID, title = "A Timeless Question" } }
fire("GOSSIP_SHOW")
check("picks the quest out of the gossip", tookAction("SelectAvailableQuest") == QUEST_ID)
fire("QUEST_DETAIL")
check("accepts it", tookAction("AcceptQuest"))

print("-- answering, block 130907-130910 where 130908 is correct")
resetCalls()
state.available = {}
state.text = QUESTION_TEXT
state.options = QUESTION_OPTIONS
fire("GOSSIP_SHOW")
runTimers()
check("clicks the answer by option id", tookAction("SelectOption") == CORRECT_ID,
    tookAction("SelectOption"))
check("prints the question it found", chatContains("undead murlocs") ~= nil)
check("prints which option it chose", chatContains("option 2") ~= nil)

print("-- her reply: a page with no options at all")
resetCalls()
state.options = {}
state.text = "Correct!"
fire("GOSSIP_SHOW")
check("closes the reply page", tookAction("CloseGossip") == true)
check("does not mistake it for a question", tookAction("SelectOption") == nil)
check("did not record the correct answer as wrong",
    TimelessQuestionDB.wrongIDs[CORRECT_ID] == nil)

print("-- handing in")
resetCalls()
state.ready = true
state.active = { { questID = QUEST_ID } }
fire("GOSSIP_SHOW")
check("selects the quest to hand in", tookAction("SelectActiveQuest") == QUEST_ID)
fire("QUEST_PROGRESS")
check("completes it", tookAction("CompleteQuest"))
fire("QUEST_COMPLETE")
check("takes the reward", tookAction("GetQuestReward"))
fire("QUEST_TURNED_IN", QUEST_ID)
check("records the answer as correct", TimelessQuestionDB.learnedIDs[CORRECT_ID] == true)

--------------------------------------------------------------------------------
-- The guards on that auto-close, which are the risky half of it
--------------------------------------------------------------------------------

print("-- guard: an optionless page long after answering is left alone")
state.onQuest, state.ready, state.active = false, false, {}
state.doneToday = true
advance(60)
resetCalls()
state.options = {}
fire("GOSSIP_SHOW")
check("idle chat with her is not closed", tookAction("CloseGossip") == nil)

print("-- guard: never close while a turn-in is on offer")
state.onQuest, state.doneToday, state.ready = true, false, false
TimelessQuestionDB.autoTurnIn = false -- the player wants to hand in by hand
state.text = QUESTION_TEXT
state.options = QUESTION_OPTIONS
resetCalls()
fire("GOSSIP_SHOW")
runTimers()
check("answers again", tookAction("SelectOption") == CORRECT_ID)
state.options = {}
state.ready = true
state.active = { { questID = QUEST_ID } }
resetCalls()
fire("GOSSIP_SHOW")
check("leaves the turn-in for the player", tookAction("CloseGossip") == nil)

print("-- guard: a wrong answer is blacklisted by id and by text")
state.onQuest, state.ready, state.active, state.doneToday = true, false, {}, false
TimelessQuestionDB.autoTurnIn = true
wipe(TimelessQuestionDB.learnedIDs)
TimelessQuestionDB.wrongIDs[CORRECT_ID] = nil
resetCalls()
state.text = QUESTION_TEXT
state.options = QUESTION_OPTIONS
fire("GOSSIP_SHOW")
runTimers()
local firstPick = tookAction("SelectOption")
-- A fresh question while the answer is still pending means it was rejected.
resetCalls()
fire("GOSSIP_SHOW")
runTimers()
check("blacklists the rejected option by id", TimelessQuestionDB.wrongIDs[firstPick] == true)
check("then tries a different option", tookAction("SelectOption") ~= firstPick,
    tookAction("SelectOption"))

print(("### %d checks, %d failures"):format(checks, failures))
TEST_FAILURES = failures
