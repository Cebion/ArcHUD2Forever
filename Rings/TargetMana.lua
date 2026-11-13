local addonName, ns = ...
local Readable = ns.Readable

local module = ArcHUD:NewModule("TargetMana")
module.unit = "target"
module.defaults = {
	Enabled = false,
	Outline = true,
	ShowPerc = true,
	Side = 2,
	Level = 2,
}
module.options = {
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
	attach = true,
}
module.localized = true

local function PowerPercent(curve)
	return UnitPowerPercent(module.unit, nil, false, curve)
end

-- "UnitManaMax(unit) > 0" with a secret maximum counts as "has power"
local function HasPower(max)
	return not Readable(max) or max > 0
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)
	self.f:SetSecretSource(PowerPercent)

	self.MPPerc = self:CreateFontString(self.f, "BACKGROUND", {40, 12}, 11, "RIGHT", {1.0, 1.0, 1.0}, {"TOPLEFT", self.f, "BOTTOMLEFT", -100, -115})
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

	-- Clear all points for the ring
	self.f:ClearAllPoints()

	-- Clear all points for the percentage display
	self.MPPerc:ClearAllPoints()
	self.f:SetValue(0)
	if(self.db.profile.Side == 1) then
		-- Attach to left side
		self.f:SetPoint("TOPLEFT", self.parent:GetModule("Anchors").Left, "TOPLEFT", self.db.profile.Level * -15, 0)
		self.MPPerc:SetPoint("TOPLEFT", self.f, "BOTTOMLEFT", -100, -115)
		self.f.BG:SetReversed(false)
		self.f:SetReversed(false)
	else
		-- Attach to right side
		self.f:SetPoint("TOPRIGHT", self.parent:GetModule("Anchors").Right, "TOPRIGHT", self.db.profile.Level * 15, 0)
		self.MPPerc:SetPoint("TOPLEFT", self.f, "BOTTOMLEFT", 50, -115)
		self.f.BG:SetReversed(true)
		self.f:SetReversed(true)
	end
	if(UnitExists(self.unit)) then
		self.f:SetValue(UnitPower(self.unit))
	end
	self.f.BG:SetAngle(180)
end

function module:Enable()
	self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
	if not UnitExists(self.unit) then
		self.f:SetMax(100)
		self.f:SetValue(0)
		self.MPPerc:SetText("")
	else
		local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
		self.f:SetMax(max)
		self.f:SetValue(cur)
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
	end

	-- Register the events we will use (UNIT_MANA/ENERGY/RAGE/FOCUS and MAX variants were merged)
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT",	"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_MAXPOWER",		"UpdateMana", self.unit)
	self:RegisterUnitEvent("UNIT_DISPLAYPOWER",	nil, self.unit)
	self:RegisterEvent("PLAYER_TARGET_CHANGED")

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:PLAYER_TARGET_CHANGED()
	self.f.alphaState = -1
	if(not UnitExists(self.unit)) then
		self.f:SetMax(100)
		self.f:SetValue(0)
		self.MPPerc:SetText("")
	else
		self.f.pulse = false
		local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
		self.f:SetMax(max)
		self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
		if(UnitIsDead(self.unit) or UnitIsGhost(self.unit) or not HasPower(max)) then
			self.f:SetValue(0)
			self.MPPerc:SetText("")
		else
			self.f:SetValue(cur)
			self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
		end
	end
end

function module:UNIT_DISPLAYPOWER(event, unit)
	if(unit ~= self.unit) then return end

	local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
	self.f:UpdateColor(ns.GetPowerColor(UnitPowerType(self.unit)))
	self.f:SetValue(cur)
	self.f:SetMax(max)

	if(HasPower(max)) then
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
	else
		self.MPPerc:SetText("")
	end
end

function module:UpdateMana(event, unit)
	if(unit ~= self.unit) then return end
	local cur, max = UnitPower(self.unit), UnitPowerMax(self.unit)
	if(event == "UNIT_MAXPOWER") then
		self.f:SetMax(max)
	else
		self.f:SetValue(cur)
	end
	if(HasPower(max)) then
		self.MPPerc:SetText(ns.PercentText(cur, max, PowerPercent))
	else
		self.MPPerc:SetText("")
	end
end
