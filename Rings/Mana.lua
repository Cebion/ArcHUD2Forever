local addonName, ns = ...

local module = ArcHUD:NewModule("Mana")
module.unit = "player"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowText = true,
	ShowPerc = true,
	Side = 2,
	Level = 0,
}
module.options = {
	{name = "ShowText", text = "SHOWTEXT", tooltip = "SHOWTEXT"},
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
	attach = true,
}
module.localized = true

local function PowerPercent(curve)
	return UnitPowerPercent(module.unit, nil, false, curve)
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)
	self.f:SetSecretSource(PowerPercent)

	self.MPText = self:CreateFontString(self.f, "BACKGROUND", {150, 15}, 14, "LEFT", {1.0, 1.0, 0.0}, {"TOPLEFT", ArcHUDFrameCombo, "TOPRIGHT", 0, 0})
	self.MPPerc = self:CreateFontString(self.f, "BACKGROUND", {40, 14}, 12, "LEFT", {1.0, 1.0, 1.0}, {"TOPLEFT", self.MPText, "BOTTOMLEFT", 0, 0})
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
	self.f:SetValue(UnitPower(self.unit))
	self.f.BG:SetAngle(180)
end

local function TextColor(unit)
	if (UnitPowerType(unit) == 0) then
		return { r = 0.00, g = 1.00, b = 1.00 }
	end
	return ns.GetPowerColor(UnitPowerType(unit))
end

function module:Enable()
	self.f.pulse = false

	if(UnitIsGhost(self.unit)) then
		self.f:GhostMode(true, self.unit)
	else
		self.f:GhostMode(false, self.unit)

		local info = TextColor(self.unit)
		self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
		self.MPText:SetVertexColor(info.r, info.g, info.b)

		local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
		self.f:SetMax(max)
		self.f:SetValue(cur)
		self.MPText:SetText(ns.ValueText(cur, max))
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
	end

	-- Register the events we will use (UNIT_MANA/RAGE/ENERGY and their MAX events were merged)
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT",	"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_MAXPOWER",		"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_DISPLAYPOWER",	"UpdateMana", self.unit)
	self:RegisterEvent("PLAYER_ALIVE",			"UpdateMana")
	self:RegisterEvent("PLAYER_LEVEL_UP")

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:PLAYER_LEVEL_UP()
	self.f:SetMax(UnitPowerMax(self.unit))
end

function module:UpdateMana(event, unit)
	-- PLAYER_ALIVE has no unit argument
	if(event ~= "PLAYER_ALIVE" and unit ~= self.unit) then return end

	if(UnitIsGhost(self.unit) or (UnitIsDead(self.unit) and event == "PLAYER_ALIVE")) then
		self.f:GhostMode(true, self.unit)
	else
		self.f:GhostMode(false, self.unit)

		if(event == "UNIT_DISPLAYPOWER") then
			local info = TextColor(self.unit)
			self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
			self.MPText:SetVertexColor(info.r, info.g, info.b)
		end

		local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
		self.MPText:SetText(ns.ValueText(cur, max))
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))

		self.f:SetMax(max)
		self.f:SetValue(cur)
	end
end
