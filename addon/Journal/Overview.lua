-- The Overview tab. With no boss picked it describes the instance: difficulties with your
-- lockout on each, what it takes to get in, where the entrance is, your era lock and its quests.
-- With a boss picked it shows the boss's model (drag to turn it), level, health on the chosen
-- difficulty, the creatures fought in the encounter, its enrage timer, what it gives besides its
-- loot and whether you killed it this lockout.

local J = Journal
local setShown = J.SetShown

local pane = CreateFrame("Frame")
local scroll = J.CreateScrollArea(pane)
scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -22, 0)
scroll:SetScript("OnMouseWheel", function (self, delta)
	local max = math.max(0, self.content:GetHeight() - self:GetHeight())
	self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
end)
local c = scroll.content

-----------------------------------------
-- building blocks, laid out top to bottom

local texts = J.CreatePool(function ()
	local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	return fs
end)
local icons = J.CreatePool(function () return c:CreateTexture(nil, "OVERLAY") end)
local buttons = J.CreatePool(function () return J.CreateButton(c, "", 160, 22) end)

local y, width

local function reset()
	texts:Reset()
	icons:Reset()
	buttons:Reset()
	y = 4
	width = math.max(200, scroll:GetWidth() - 8)
end

local function text(str, font, color, indent, gap)
	local fs = texts:Get()
	fs:SetFontObject(font or GameFontHighlight)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + (indent or 0), -y)
	fs:SetWidth(width - (indent or 0))
	fs:SetText(str)
	if color then fs:SetTextColor(color[1], color[2], color[3]) else fs:SetTextColor(1, 1, 1) end
	y = y + fs:GetStringHeight() + (gap or 6)
	return fs
end

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.62, 0.62, 0.62 }
local RED = { 1, 0.35, 0.35 }
local GREEN = { 0.3, 1, 0.3 }

local function heading(str)
	y = y + 6
	text(str, GameFontNormalLarge, GOLD, 0, 4)
	-- A gold rule under it with DragonUI; plain headings, as the stock quest log has, without.
	if J.dragon then
		local rule = icons:Get()
		rule:SetTexture(1, 0.82, 0, 0.35)
		rule:ClearAllPoints()
		rule:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -y)
		rule:SetSize(width, 1)
	end
	y = y + 6
end

-- A line with a ready-check tick or cross in front.
-- Met reads grey, missing red; a shortcut not taken yet (optional) white.
local function check(ok, str, optional)
	local icon = icons:Get()
	icon:SetTexture(ok and "Interface\\RaidFrame\\ReadyCheck-Ready"
		or optional and "Interface\\RaidFrame\\ReadyCheck-Waiting" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
	icon:SetSize(14, 14)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -y + 1)
	text(str, GameFontHighlight, ok and GREY or (not optional and RED) or nil, 22, 4)
end

local function button(label, onClick, x)
	local b = buttons:Get()
	b:SetText(label)
	b:SetWidth(math.max(120, b:GetFontString():GetStringWidth() + 30))
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", c, "TOPLEFT", 4 + (x or 0), -y)
	b:SetScript("OnClick", onClick)
	return b
end

-- One line of "To enter": what it is, then where to get it and buttons that take you there.
local function requirement(r)
	local what
	if r.kind == "L" then what = "Level " .. r.id
	elseif r.kind == "I" then what = "Carry " .. (GetItemInfo(r.id) or r.name)
	elseif r.kind == "Q" then what = "Complete the quest " .. r.name
	elseif r.kind == "A" then what = "Achievement: " .. r.name end
	if not what then return end
	if r.optional then
		what = "Optional shortcut: " .. what:sub(1, 1):lower() .. what:sub(2) .. (r.note ~= "" and (" - " .. r.note) or "")
	end
	check(r.have, what, r.optional)

	local line
	local actions = {}
	-- The quest itself shows its giver on the map.
	local function questActions(questId, ofThisInstance)
		table.insert(actions, { "Show quest", function ()
			if ofThisInstance then J.Show({ tab = "quests" }) else Journal.OpenQuest(questId) end
		end })
	end
	local function at(where) return where ~= "" and (", " .. where) or "" end
	if r.source == "G" then
		line = "Given by " .. r.sourceName .. at(r.where)
		questActions(r.sourceId, r.inst == 1)
	elseif r.source == "S" then
		line = "Starts from the item " .. r.sourceName .. ", which drops from " .. r.text .. at(r.where)
		questActions(r.sourceId, false)
		if r.inst > 0 and r.boss > 0 then
			table.insert(actions, { "Show boss", function ()
				J.Show({ page = "instance", instance = r.inst, boss = r.boss, tab = "loot" })
			end })
		elseif r.boss > 0 and J.Has(J.HELLO_MAP_PINS) then
			table.insert(actions, { "Show on map", function () J.ShowOnMap("C", r.boss) end })
		end
	elseif r.source == "Q" then
		line = "Reward from the quest " .. r.sourceName .. (r.where ~= "" and (" (" .. r.where .. ")") or "")
		questActions(r.sourceId, r.inst == 1)
	elseif r.source == "D" then
		line = "Drops from " .. r.sourceName .. at(r.where)
		if r.inst > 0 and r.boss > 0 then
			table.insert(actions, { "Show boss", function ()
				J.Show({ page = "instance", instance = r.inst, boss = r.boss, tab = "loot" })
			end })
		elseif J.Has(J.HELLO_MAP_PINS) then
			table.insert(actions, { "Show on map", function () J.ShowOnMap("C", r.sourceId) end })
		end
	elseif r.source == "V" then
		line = "Sold by " .. r.sourceName .. at(r.where) .. (r.text ~= "" and (", needs " .. r.text) or "")
		if J.Has(J.HELLO_MAP_PINS) then
			table.insert(actions, { "Show on map", function () J.ShowOnMap("C", r.sourceId) end })
		end
	elseif r.source == "B" then
		line = "Defeat " .. r.sourceName .. " first"
		table.insert(actions, { "Show boss", function ()
			J.Show({ page = "instance", instance = r.inst, boss = r.boss, tab = "overview" })
		end })
	end
	if r.kind == "A" then
		table.insert(actions, { "Show achievement", function ()
			if not AchievementFrame and AchievementFrame_LoadUI then AchievementFrame_LoadUI() end
			if AchievementFrame and AchievementFrame_SelectAchievement then
				ShowUIPanel(AchievementFrame)
				AchievementFrame_SelectAchievement(r.id)
			end
		end })
	end
	if line then text(line, GameFontHighlightSmall, GREY, 22, 4) end
	if #actions > 0 then
		local x = 18
		for _, a in ipairs(actions) do
			local b = button(a[1], a[2], x)
			x = x + b:GetWidth() + 6
		end
		y = y + 28
	end
end

-----------------------------------------
-- the boss model

-- It sits above the scroll area, not in it: the 3.3.5 client draws a model inside a scroll
-- frame in the wrong place, on top of the boss list and the text.
-- A DressUpModel, not a PlayerModel: the 3.3.5 client only skins a character-model creature (a
-- humanoid boss built from a race model) in a DressUpModel; a PlayerModel draws it white.
local MODEL_HEIGHT = 250
local model = CreateFrame("DressUpModel", nil, pane)
model:SetPoint("TOPLEFT", pane, "TOPLEFT", 4, -4)
model:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -26, -4)
model:SetHeight(MODEL_HEIGHT)
model:SetScript("OnHide", function (self) self.shownEntry = nil end)
ModelViewLib.Wire(model, 0.4)
local modelBg = pane:CreateTexture(nil, "BACKGROUND")
modelBg:SetPoint("TOPLEFT", model, "TOPLEFT")
modelBg:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT")
modelBg:SetTexture("Interface\\LFGFrame\\UI-LFG-BACKGROUND-QUESTPAPER")
modelBg:SetTexCoord(0, 0.6, 0, 0.55)
modelBg:SetVertexColor(0.35, 0.32, 0.3)
ModelViewLib.AddHint(model)

-- Shows or hides the model; the scroll area starts below it while it shows.
local function setModelShown(shown)
	setShown(model, shown)
	setShown(modelBg, shown)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, shown and -(MODEL_HEIGHT + 10) or 0)
	scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -22, 0)
end
setModelShown(false)

-----------------------------------------
-- instance overview

local serial = 0

local function instanceOverview(ctx)
	local inst, variant = ctx.inst, ctx.variant
	local mine = serial

	text(inst.name, GameFontNormalHuge, GOLD, 0, 2)
	local minLevel, maxLevel, best = J.TierLevels(inst, J.view.tier)
	text((inst.raid and "Raid" or "Dungeon") .. " for level " .. (minLevel == maxLevel and minLevel or (minLevel .. "-" .. maxLevel))
		.. (best and (", best at level " .. best) or ""), GameFontHighlight, GREY)

	local st = ctx.status and ctx.status.inst == inst.id and ctx.status.value or nil

	-- The tab's name says its size ("20 Player"); the level it lets you in at is under "To enter".
	heading("Difficulty")
	for _, v in ipairs(J.VariantsFor(inst, J.view.tier)) do
		local line = v.label
		local vs = st and st.variants[v.id]
		if J.IsLocked(v) then
			line = line .. "  |cffff5555locked: progression stage " .. v.reqState .. " (you: " .. (J.state or 0) .. ")|r"
		elseif vs and vs.saved then
			local killed, total = 0, 0
			for _, b in ipairs(ctx.bosses or {}) do
				if not b.rare and J.BossOnVariant(b, v) then
					total = total + 1
					if J.Killed(st, v, b) then killed = killed + 1 end
				end
			end
			local left = math.max(0, (vs.resetIn or 0) - (GetTime() - (vs.at or GetTime())))
			line = line .. "  |cff80c0ffsaved, " .. killed .. "/" .. total .. " defeated"
				.. (left > 0 and (", resets in " .. J.Duration(left)) or "") .. "|r"
		end
		text(line, GameFontHighlight, nil, 6, 4)
	end

	local reqs = st and st.requirements[variant.id]
	if reqs and #reqs > 0 then
		heading("To enter")
		for _, r in ipairs(reqs) do requirement(r) end
	end

	if J.IsLocked(variant) then
		heading("Progression")
		text("Your character hasn't reached this part of the game yet. It opens at progression stage "
			.. variant.reqState .. "; you are at stage " .. (J.state or 0) .. ".", GameFontHighlight, RED)
	end

	heading("Entrance")
	if inst.zone ~= "" then
		text(inst.zone, GameFontHighlight)
		if J.Has(J.HELLO_MAP_PINS) then
			button("Show on map", function () J.ShowOnMap("E", inst.id) end)
			y = y + 28
		end
	else
		text("Unknown", GameFontHighlight, GREY)
	end

	if #inst.wings > 0 then
		heading("Wings")
		for _, w in ipairs(inst.wings) do
			text("|cffffd200" .. w.name .. "|r  level " .. (w.minLevel == w.maxLevel and w.minLevel or (w.minLevel .. "-" .. w.maxLevel))
				.. ((w.targetLevel or 0) > 0 and (", best ~" .. w.targetLevel) or ""), GameFontHighlight, nil, 6, 4)
		end
	end

	heading("Quests")
	local questLine = text("Loading...", GameFontHighlight, GREY)
	J.LoadQuests(inst, function (quests)
		if not quests or mine ~= serial then return end
		quests = J.QuestsForTier(inst, J.view.tier, quests)
		local available, active, done = 0, 0, 0
		for _, q in ipairs(quests) do
			if q.state == J.QUEST.AVAILABLE then available = available + 1
			elseif q.state == J.QUEST.ACTIVE or q.state == J.QUEST.COMPLETE then active = active + 1
			elseif q.state == J.QUEST.DONE then done = done + 1 end
		end
		if #quests == 0 then
			questLine:SetText("No quests for this instance.")
		else
			questLine:SetText(string.format("%d quests: |cffffd200%d to pick up|r, |cff80c0ff%d in your log|r, %d done.",
				#quests, available, active, done))
			questLine:SetTextColor(1, 1, 1)
		end
	end)
	button("See quests", function () J.Show({ tab = "quests" }) end)
	y = y + 28
end

-----------------------------------------
-- boss overview

local RANKS = { [0] = "", [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }

local function bossOverview(ctx)
	local inst, boss, variant = ctx.inst, ctx.boss, ctx.variant
	local mine = serial
	local st = ctx.status and ctx.status.inst == inst.id and ctx.status.value or nil

	if boss.display and boss.display > 0 then
		J.ShowCreature(model, pane.unit or boss.display)
	end

	text(boss.name, GameFontNormalHuge, GOLD, 0, 2)
	local killed = J.Killed(st, variant, boss)
	if boss.rare then
		text("Rare spawn: it isn't there every run.", GameFontHighlight, { 0.75, 0.75, 1 })
	elseif killed then
		text("Defeated this lockout (" .. variant.label .. ")", GameFontHighlight, GREEN)
	end

	local unitsAt = y
	local placeholder = text("Loading...", GameFontHighlight, GREY)
	J.LoadAbilities(inst, boss, variant, function (units)
		if not units or mine ~= serial then return end
		placeholder:Hide()
		y = unitsAt
		local abilities = 0
		local mains = {}
		for _, u in ipairs(units) do
			if not u.add then table.insert(mains, u) end
			for _, s in ipairs(u.spells) do
				if J.AbilityDescription(s) or s.note then abilities = abilities + 1 end
			end
		end
		for _, u in ipairs(mains) do
			local rank = RANKS[u.rank] or ""
			local skull = u.rank == 3 and "|TInterface\\TargetingFrame\\UI-TargetingFrame-Skull:14|t " or ""
			local line = skull .. "|cffffd200" .. u.name .. "|r  " .. (u.rank == 3 and "Level ??" or ("Level " .. u.level))
				.. (rank ~= "" and (" " .. rank) or "")
			if u.health and u.health > 0 then line = line .. "  -  " .. J.Number(u.health) .. " health" end
			text(line, GameFontHighlight, nil, 0, 4)
			if #mains > 1 and boss.display and boss.display > 0 then
				local b = button("Show " .. u.name, function () pane.unit = u.entry ; J.ShowCreature(model, u.entry) end, 12)
				b:SetHeight(20)
				y = y + 24
			end
		end
		local enraged = {}
		for _, u in ipairs(mains) do
			local e = u.enrage
			local key = e and (e.spell .. ":" .. e.seconds)
			if e and not enraged[key] then
				enraged[key] = true
				local name = GetSpellInfo(e.spell) or "Enrage"
				text("|cffff5020" .. name .. "|r after " .. J.EnrageTime(e.seconds)
					.. (#mains > 1 and (" (" .. u.name .. ")") or ""), GameFontHighlight, nil, 0, 4)
			end
		end
		if units.rewards and #units.rewards > 0 then
			y = y + 2
			for _, r in ipairs(units.rewards) do
				text("|cffffd200Also rewards:|r " .. r, GameFontHighlight, nil, 0, 4)
			end
		end
		y = y + 6
		local summary = abilities == 1 and "1 ability" or (abilities .. " abilities")
		button("Abilities (" .. abilities .. ")", function () J.Show({ tab = "abilities" }) end)
		button("Loot", function () J.Show({ tab = "loot" }) end, 170)
		y = y + 30
		if abilities == 0 and J.Has(J.HELLO_LEARNING) then
			text("No abilities known yet: the journal learns them as this boss is fought.", GameFontHighlightSmall, GREY)
		end
		text(summary .. " on " .. variant.label .. ".", GameFontHighlightSmall, GREY)
		scroll:SetContentHeight(y)
	end)
end

function pane:Refresh(ctx)
	serial = serial + 1
	setModelShown(ctx.boss and ctx.boss.display and ctx.boss.display > 0 and true or false)
	reset()
	if not ctx.boss then pane.unit = nil end
	if pane.lastBoss ~= (ctx.boss and ctx.boss.key) then
		pane.unit = nil
		pane.lastBoss = ctx.boss and ctx.boss.key
		scroll:ScrollToTop()
	end
	if ctx.boss then bossOverview(ctx) else instanceOverview(ctx) end
	scroll:SetContentHeight(y)
end

J.On("STATUS", function () if pane:IsShown() and J.ctx then pane:Refresh(J.ctx) end end)

J.RegisterPane("overview", pane)
