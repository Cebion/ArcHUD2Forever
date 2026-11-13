local addonName, ns = ...

local module = ArcHUD:NewModule("MirrorTimer")
module.unit = "player"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowSpell = true,
	Side = 1,
	Level = -1,
}
module.options = {
	{name = "ShowSpell", text = "SHOWSPELL", tooltip = "SHOWSPELL"},
	attach = true,
}
module.localized = true
-- The Blizzard breath/fatigue bars this ring replaces (were MirrorTimer1-3)
module.blizzardFrames = { "MirrorTimerContainer" }

-- 1.12 globals that no longer exist
local MIRRORTIMER_NUMTIMERS = 3
local MirrorTimerColors = {
	["EXHAUSTION"] = { r = 1.00, g = 0.90, b = 0.00 },
	["BREATH"] = { r = 0.00, g = 0.50, b = 1.00 },
	["DEATH"] = { r = 1.00, g = 0.70, b = 0.00 },
	["FEIGNDEATH"] = { r = 1.00, g = 0.70, b = 0.00 },
}

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)

	self.Text = {}
	self.Text[1] = self:CreateFontString(self.f, "BACKGROUND", {140, 16}, 14, "CENTER", {1.0, 1.0, 1.0}, {"BOTTOM", "ArcHUDFrameCombo", "TOP", 0, 96})
	self.Text[2] = self:CreateFontString(self.f, "BACKGROUND", {140, 16}, 14, "CENTER", {1.0, 1.0, 1.0}, {"TOPLEFT", self.Text[1], "BOTTOMLEFT", 0, 0})
	self.Text[3] = self:CreateFontString(self.f, "BACKGROUND", {140, 16}, 14, "CENTER", {1.0, 1.0, 1.0}, {"TOPLEFT", self.Text[2], "BOTTOMLEFT", 0, 0})

	-- Override Update timer
	self:RegisterMetro(self.name .. "Update", self.UpdateTimers, 0.05, self)
end

function module:Update()
	if(self.db.profile.ShowSpell) then
		for i=1,3 do
			self.Text[i]:Show()
		end
	else
		for i=1,3 do
			self.Text[i]:Hide()
		end
	end

	if(self.db.profile.Outline) then
		self.f.BG:Show()
	else
		self.f.BG:Hide()
	end

	-- Clear all points for the ring
	self.f:ClearAllPoints()
	if(self.db.profile.Side == 1) then
		-- Attach to left side
		self.f:SetPoint("TOPLEFT", self.parent:GetModule("Anchors").Left, "TOPLEFT", self.db.profile.Level * -15, 0)
		self.f.BG:SetReversed(false)
		self.f:SetReversed(false)
	else
		-- Attach to right side
		self.f:SetPoint("TOPRIGHT", self.parent:GetModule("Anchors").Right, "TOPRIGHT", self.db.profile.Level * 15, 0)
		self.f.BG:SetReversed(true)
		self.f:SetReversed(true)
	end
	self.f.BG:SetAngle(180)
end

function module:Enable()
	self.f.fadeIn = 0.25
	self.f.fadeOut = 2

	self.f.dirty = true

	-- Register the events we will use
	self:RegisterEvent("MIRROR_TIMER_START")
	self:RegisterEvent("MIRROR_TIMER_PAUSE")
	self:RegisterEvent("MIRROR_TIMER_STOP")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Activate the timers
	self:StartMetro(self.name .. "Update")
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")

	if(not self.timers) then
		self.timers = {count = 0}
		self.timer = 0
	end

	self.f:Show()
end

function module:UpdateTimers(elapsed)
	for i=1,MIRRORTIMER_NUMTIMERS do
		if(self.timers[i] and not self.timers[i].paused) then
			self.timers[i].value = self.timers[i].value + self.timers[i].scale * elapsed*1000
			if(self.timers[i].value > self.timers[i].maxvalue) then
				self.timers[i].value = self.timers[i].maxvalue
			end
			if(self.timer == i) then
				self.f:SetMax(self.timers[i].maxvalue)
				self.f:SetValue(self.timers[i].value)
			end
			local texttime = ""
			local time_remaining = self.timers[i].value
			if((time_remaining/1000) > 60) then
				local minutes = math.floor(time_remaining/60000)
				local seconds = math.floor(((time_remaining/60000) - minutes) * 60)
				if(seconds < 10) then
					texttime = minutes..":0"..seconds
				else
					texttime = minutes..":"..seconds
				end
			else
				local intlength = string.len(string.format("%d", math.floor(time_remaining/1000)))
				texttime = strsub(string.format("%f",time_remaining/1000),1,intlength+2)
			end
			self.Text[i]:SetText(self.timers[i].label..": "..texttime)
		else
			self.Text[i]:SetText("")
		end
	end
end

function module:MIRROR_TIMER_START(event, timer, value, maxvalue, scale, paused, label)
	-- Find a free timer table
	local updTimer, newTimer
	for i=1,MIRRORTIMER_NUMTIMERS do
		if(self.timers[i] and self.timers[i].timer == timer) then
			updTimer = i
			break
		end
	end
	if(not updTimer) then
		for i=1,MIRRORTIMER_NUMTIMERS do
			if(not self.timers[i]) then
				newTimer = i
				break
			end
		end
	end

	local data = {
		timer = timer,
		value = value,
		maxvalue = maxvalue,
		scale = scale,
		paused = (paused and paused > 0) and paused or nil,
		label = label,
	}
	if(newTimer) then
		-- Add timer to table
		self.timers[newTimer] = data
		-- Switch ring color to the new timer
		self.f:UpdateColor(MirrorTimerColors[timer])
		self.timer = newTimer
		self.timers.count = self.timers.count + 1
	elseif(updTimer) then
		-- Update existing timer
		self.timers[updTimer] = data
	end
	if(ArcHUD.db.profile.FadeIC > ArcHUD.db.profile.FadeOOC) then
		self.f:SetRingAlpha(ArcHUD.db.profile.FadeIC)
	else
		self.f:SetRingAlpha(ArcHUD.db.profile.FadeOOC)
	end
end

-- 1.12 paused/unpaused every timer from arg1; the event now names the timer and the paused state
function module:MIRROR_TIMER_PAUSE(event, timer, paused)
	for i=1,MIRRORTIMER_NUMTIMERS do
		if(self.timers[i] and (timer == nil or self.timers[i].timer == timer)) then
			self.timers[i].paused = ((paused or 0) > 0 and 1 or nil)
		end
	end
end

function module:MIRROR_TIMER_STOP(event, timer)
	for i=1,MIRRORTIMER_NUMTIMERS do
		if(self.timers[i] and self.timers[i].timer == timer) then
			if(self.timers[i+1]) then
				self.timers[i] = self.timers[i+1]
				self.timers[i+1] = nil
			else
				self.timers[i] = nil
			end
			self.timers.count = self.timers.count - 1
		end
	end
	if(self.timers.count == 0) then
		self.f:SetRingAlpha(0)
	else
		if(not self.timers[self.timer]) then
			for i=MIRRORTIMER_NUMTIMERS,1,-1 do
				if(self.timers[i]) then
					self.timer = i
					self.f:UpdateColor(MirrorTimerColors[self.timers[i].timer])
					break
				end
			end
		end
	end
end

function module:PLAYER_ENTERING_WORLD()
	for i=1,MIRRORTIMER_NUMTIMERS do
		self.timers[i] = nil
	end
	self.timers.count = 0
	self.f:SetRingAlpha(0)
end
