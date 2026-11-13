local addonName, ns = ...

local module = ArcHUD:NewModule("PetMana")
module.unit = "pet"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowPerc = true,
}
module.options = {
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
}
module.localized = true

local function PowerPercent(curve)
	return UnitPowerPercent(module.unit, nil, false, curve)
end

local function HealthPercent(curve)
	return UnitHealthPercent(module.unit, true, curve)
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetSecretSource(PowerPercent)

	self.f.BG:SetReversed(true)
	self.f.BG:SetAngle(180)

	self.f:SetReversed(true)
	self.f:SetAlpha(0)
	self.f:SetScale(0.6)

	self.f:SetPoint("TOPLEFT", self.parent:GetModule("Anchors").Right, "LEFT", 0, 90)

	self.MPPerc = self:CreateFontString(self.f, "BACKGROUND", {100, 17}, 16, "LEFT", {1.0, 1.0, 1.0}, {"BOTTOMLEFT", self.f, "BOTTOMLEFT", 65, -125})
end

function module:Update()
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
end

function module:Enable()
	self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
	self.f:SetMax(10)
	self.f:SetValue(10)

	if(UnitExists(self.unit)) then
		-- (the original showed the pet's health percentage here until the first mana update)
		self.MPPerc:SetText(ns.PercentText(UnitHealth(self.unit), UnitHealthMax(self.unit), HealthPercent))
		self.f:SetMax(UnitPowerMax(self.unit))
		self.f:SetValue(UnitPower(self.unit))
	else
		self.MPPerc:SetText("")
		self.f:SetValue(0)
	end

	-- Register the events we will use
	self:RegisterEvent("PET_UI_UPDATE",					"UpdatePet")
	self:RegisterUnitEvent("UNIT_PET",					"UpdatePet", "player")
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT",		"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_MAXPOWER",				"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_DISPLAYPOWER",			nil, self.unit)

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:UNIT_DISPLAYPOWER()
	self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
	self.f:SetMax(UnitPowerMax(self.unit))
end

function module:UpdatePet(event, unit)
	if(event == "UNIT_PET" and unit ~= "player") then return end
	if(UnitExists(self.unit)) then
		local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
		self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
		self.f:SetMax(max)
		self.f:SetValue(cur)
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
		self.f:Show()
	else
		self.f:Hide()
	end
end

function module:UpdateMana(event, unit)
	if(unit ~= self.unit) then return end
	local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
	if(event == "UNIT_MAXPOWER") then
		self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
		self.f:SetMax(max)
	else
		self.f:SetValue(cur)
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
	end
end
