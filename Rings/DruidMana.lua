local addonName, ns = ...

local module = ArcHUD:NewModule("DruidMana")
module.unit = "player"
module.defaults = {
	Enabled = false,
	Outline = true,
	ShowText = true,
	ShowPerc = true,
	Side = 2,
	Level = 1,
}
module.options = {
	{name = "ShowText", text = "SHOWTEXT", tooltip = "SHOWTEXT"},
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
	attach = true,
}
module.localized = true

local MANA = Enum.PowerType.Mana

-- The 1.12 client hid the druid's mana in forms, so this ring needed DruidBar or SoleManax.
-- The modern API reports it directly with UnitPower("player", Enum.PowerType.Mana).
local function ManaPercent(curve)
	return UnitPowerPercent("player", MANA, false, curve)
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)
	self.f:SetSecretSource(ManaPercent)

	self.MPText = self:CreateFontString(self.f, "BACKGROUND", {150, 13}, 12, "LEFT", {0.0, 1.0, 1.0}, {"TOPLEFT", ArcHUDFrameCombo, "TOPRIGHT", 0, 14})
	self.MPPerc = self:CreateFontString(self.f, "BACKGROUND", {70, 12}, 10, "LEFT", {1.0, 1.0, 1.0}, {"TOPLEFT", self.parent:GetModule("Mana").MPPerc, "TOPRIGHT", 0, -1})

	-- Override Update timer
	self:RegisterMetro(self.name .. "Update", self.UpdateAlpha, 0.05, self)
end

function module:Update()
	if(self.db.profile.ShowText) then
		self.MPText:Show()
	else
		self.MPText:Hide()
	end

	if(self.db.profile.ShowPerc) then
		self.MPPerc:Show()
	else
		self.MPPerc:Hide()
	end

	if(self.db.profile.Outline) then
		self.f.BG:Show()
	else
		self.f.BG:Hide()
	end

	-- Clear all points for the ring
	self.f:ClearAllPoints()
	self.f:SetValue(0)
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
	self.f:UpdateColor({r=0.0, g=0.0, b=1.0})

	-- Don't go further if player is not a druid
	local _, class = UnitClass(self.unit)
	if(class ~= "DRUID") then return end

	-- Register the events we will use
	self:RegisterUnitEvent("UNIT_DISPLAYPOWER",	nil, self.unit)
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT",	"OnPower", self.unit)
	self:RegisterUnitEvent("UNIT_MAXPOWER",		"OnPower", self.unit)

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.gotAddon = true
	-- Pick up the current form right away (the original waited for the next form change)
	self:UNIT_DISPLAYPOWER(nil, self.unit)

	self.f:Show()
end

function module:UpdateAlpha()
	if(self.doUpdates) then
		local inCombat = ArcHUD.PlayerIsInCombat
		if self.f.secret then
			-- Below 100% -> FadeIC/FadeOOC, full -> hidden
			self.f:SetSecretRingAlpha(0.9999995, inCombat and ArcHUD.db.profile.FadeIC or ArcHUD.db.profile.FadeOOC, 0)
		elseif(self.f.startValue < self.f.maxValue and inCombat) then
			self.f:SetRingAlpha(ArcHUD.db.profile.FadeIC)
		elseif(self.f.startValue < self.f.maxValue and not inCombat) then
			self.f:SetRingAlpha(ArcHUD.db.profile.FadeOOC)
		else
			self.f:SetRingAlpha(0)
		end
	else
		self.f:SetRingAlpha(0)
	end
end

function module:OnPower(event, unit, powerType)
	if(event == "UNIT_POWER_FREQUENT" and powerType ~= "MANA") then return end
	self:UpdateMana(UnitPower(self.unit, MANA), UnitPowerMax(self.unit, MANA))
end

function module:UpdateMana(curMana, maxMana)
	if(self.doUpdates) then
		self.MPText:SetText(ns.ValueText(curMana, maxMana))
		self.MPPerc:SetText(ns.PercentText(curMana, maxMana, ManaPercent))
		self.f:SetMax(maxMana)
		self.f:SetValue(curMana)
	end
end

function module:UNIT_DISPLAYPOWER(event, unit)
	if(unit ~= self.unit) then return end
	local powerType = UnitPowerType(self.unit)
	if(powerType == 1 or powerType == 3 and not self.doUpdates) then
		--Bear or Cat form
		self.doUpdates = true
		self:UpdateMana(UnitPower(self.unit, MANA), UnitPowerMax(self.unit, MANA))
	elseif(powerType == 0 and self.doUpdates) then
		--player/aqua/travel
		self.doUpdates = false
	end
end
