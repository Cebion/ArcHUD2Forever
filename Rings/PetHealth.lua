local addonName, ns = ...
local Readable = ns.Readable

local module = ArcHUD:NewModule("PetHealth")
module.unit = "pet"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowPerc = true,
	ColorFade = true,
}
module.options = {
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
	{name = "ColorFade", text = "COLORFADE", tooltip = "COLORFADE"},
}
module.localized = true

local function HealthPercent(curve)
	return UnitHealthPercent(module.unit, true, curve)
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetSecretSource(HealthPercent)

	self.f:SetScale(0.6)
	self.f:SetAlpha(0)
	self.f:SetPoint("TOPLEFT", self.parent:GetModule("Anchors").Left, "LEFT", 0, 90)

	self.HPPerc = self:CreateFontString(self.f, "BACKGROUND", {100, 17}, 16, "RIGHT", {1.0, 1.0, 1.0}, {"BOTTOMLEFT", self.f, "BOTTOMLEFT", -165, -125})
end

function module:Update()
	if(self.db.profile.ShowPerc) then
		self.HPPerc:Show()
	else
		self.HPPerc:Hide()
	end

	if(self.db.profile.Outline) then
		self.f.BG:Show()
	else
		self.f.BG:Hide()
	end

	self.ColorFade = self.db.profile.ColorFade
end

function module:Enable()
	self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0})
	if(UnitExists(self.unit)) then
		local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
		self.f:SetMax(max)
		self.f:SetValue(cur)
	else
		self.HPPerc:SetText("")
		self.f:SetValue(0)
	end

	-- Register the events we will use (PLAYER_PET_CHANGED and PET_BAR_CHANGED no longer exist;
	-- UNIT_PET and PET_UI_UPDATE cover pet changes)
	self:RegisterEvent("PET_UI_UPDATE",					"UpdatePet")
	self:RegisterUnitEvent("UNIT_PET",					"UpdatePet", "player")
	self:RegisterUnitEvent("UNIT_HEALTH", 				"UpdateHealth", self.unit)
	self:RegisterUnitEvent("UNIT_MAXHEALTH", 			"UpdateHealth", self.unit)

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:UpdatePet(event, unit)
	if(event == "UNIT_PET" and unit ~= "player") then return end
	if(UnitExists(self.unit)) then
		self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0})
		local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
		self.f:SetMax(max)
		self.f:SetValue(cur)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
		self.f:Show()
	else
		self.f:Hide()
	end
end

function module:UpdateHealth(event, unit)
	if(unit ~= self.unit) then return end
	local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
	if Readable(cur) and Readable(max) and max > 0 then
		local p = cur/max
		local r, g = 1, 1
		if ( p > 0.5 ) then
			r = (1.0 - p) * 2
			g = 1.0
		else
			r = 1.0
			g = p * 2
		end
		if ( r < 0 ) then r = 0 elseif ( r > 1 ) then r = 1 end
		if ( g < 0 ) then g = 0 elseif ( g > 1 ) then g = 1 end
		if(self.ColorFade) then
			self.f:UpdateColor({["r"] = r, ["g"] = g, ["b"] = 0})
		else
			self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0})
		end
	elseif(self.ColorFade) then
		local r, g, b = ArcHUDRingTemplate.UnpackCurveColor(UnitHealthPercent(self.unit, true, ArcHUDRingTemplate.GetHealthColorCurve()))
		if r then
			self.f:CallTextureMethod("SetVertexColor", r, g, b, 1)
		end
	else
		self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0})
	end

	if (event == "UNIT_MAXHEALTH") then
		self.f:SetMax(max)
	else
		self.f:SetValue(cur)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
	end
end
