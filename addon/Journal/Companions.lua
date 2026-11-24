-- mod-companion-auras, for the Pets tab: the aura each companion gives while it's out, the names
-- players give their companions, and renaming them. The module talks through addon messages the
-- player whispers to themselves, prefix "CompAuras" (as the journal's own server traffic):
--   SYNC                 -> "A|creature,spell,flags;..." (chunks), "N|creature|name" each, "E|"
--   NAME|creature|name   -> "N|creature|name", or "F|creature" when the name isn't allowed
--   NAME|creature        -> "R|creature" (its normal name again)
-- flags: 1 rare, 2 world drop. The server also sends N| and R| on its own (.petname). A realm
-- without the module just echoes the request back: nothing answers, and none of this shows.

local J = Journal

local PREFIX = "CompAuras"
local FLAG_RARE = 1

local auras          -- creature -> { spell, flags }, once an E| has arrived
local pending = {}   -- the A| rows of the sync on its way
local names = {}     -- creature -> the name this character gave it

local function send(message)
	SendAddonMessage(PREFIX, message, "WHISPER", UnitName("player"))
end

-- Asks for the list (after login, and when the Pets tab opens before an answer came).
function J.SyncCompanions()
	send("SYNC")
end

-- Whether the realm runs mod-companion-auras (it answered a SYNC).
function J.HasCompanionAuras()
	return auras ~= nil
end

-- A pet's aura: spell, rare (true/false); nil when it gives none. e: a catalog entry.
function J.CompanionAura(e)
	local a = auras and e and e.creature and auras[e.creature]
	if not a then return nil end
	return a.spell, bit.band(a.flags, FLAG_RARE) ~= 0
end

-- The name this character gave a pet, or nil.
function J.CompanionCustomName(e)
	return e and e.creature and names[e.creature] or nil
end

-- Renames a pet (name nil or "": back to its normal name). The answer updates the display.
function J.RenameCompanion(e, name)
	if not (e and e.creature) then return end
	if name and name ~= "" then
		send("NAME|" .. e.creature .. "|" .. name)
	else
		send("NAME|" .. e.creature)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function (_, _, prefix, message, _, sender)
	if prefix ~= PREFIX or sender ~= UnitName("player") or type(message) ~= "string" then return end
	local kind, rest = message:match("^(%a)|(.*)$")
	if kind == "A" then
		for creature, spell, flags in rest:gmatch("(%d+),(%d+),(%d+)") do
			pending[tonumber(creature)] = { spell = tonumber(spell), flags = tonumber(flags) }
		end
	elseif kind == "E" then
		auras, pending = pending, {}
		J.Fire("COMPANION_AURAS")
	elseif kind == "N" then
		local creature, name = rest:match("^(%d+)|(.+)$")
		if creature then
			names[tonumber(creature)] = name
			J.Fire("COMPANION_AURAS")
		end
	elseif kind == "R" then
		local creature = tonumber(rest)
		if creature then
			names[creature] = nil
			J.Fire("COMPANION_AURAS")
		end
	elseif kind == "F" then
		UIErrorsFrame:AddMessage("That name isn't allowed.", 1, 0.1, 0.1)
	end
	-- Anything else (the echo of our own requests) is ignored.
end)

J.On("LOGIN", function () J.After(4, J.SyncCompanions) end)

-- Renaming: one word, letters only, up to 12 (the server checks; a refusal comes back as F|).
StaticPopupDialogs["JOURNAL_RENAME_COMPANION"] = {
	text = "New name for %s:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 12,
	OnShow = function (self, e)
		local box = _G[self:GetName() .. "EditBox"]
		box:SetText(J.CompanionCustomName(e) or "")
		box:SetFocus()
	end,
	OnAccept = function (self, e)
		local text = _G[self:GetName() .. "EditBox"]:GetText() or ""
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		if text ~= "" then J.RenameCompanion(e, text) end
	end,
	EditBoxOnEnterPressed = function (self)
		local parent = self:GetParent()
		StaticPopupDialogs["JOURNAL_RENAME_COMPANION"].OnAccept(parent, parent.data)
		parent:Hide()
	end,
	EditBoxOnEscapePressed = function (self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}
