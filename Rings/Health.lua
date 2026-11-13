local addonName, ns = ...
local Readable = ns.Readable

local module = ArcHUD:NewModule("Health")
module.unit = "player"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowText = true,
	ShowPerc = true,
	ShowDef = false,
	ColorFade = true,
	Side = 1,
	Level = 0,
}
module.options = {
	{name = "ShowText", text = "SHOWTEXT", tooltip = "SHOWTEXT"},
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
	{name = "ColorFade", text = "COLORFADE", tooltip = "COLORFADE"},
	{name = "ShowDef", text = "DEFICIT", tooltip = "DEFICIT"},
	attach = true,
}
module.localized = true

local function HealthPercent(curve)
	return UnitHealthPercent(module.unit, true, curve)
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)
	self.f:SetSecretSource(HealthPercent)

	self.HPText = self:CreateFontString(self.f, "BACKGROUND", {150, 15}, 14, "RIGHT", {1.0, 1.0, 0.0}, {"TOPRIGHT", ArcHUDFrameCombo, "TOPLEFT", 0, 0})
	self.HPPerc = self:CreateFontString(self.f, "BACKGROUND", {70, 14}, 12, "RIGHT", {1.0, 1.0, 1.0}, {"TOPRIGHT", self.HPText, "BOTTOMRIGHT", 0, 0})
	self.DefText = self:CreateFontString(self.f, "BACKGROUND", {70, 14}, 11, "RIGHT", {1.0, 0.2, 0.2}, {"BOTTOMRIGHT", self.HPText, "TOPRIGHT", 0, 0})
end

function module:Update()
	-- Get options and setup accordingly
	if(self.db.profile.ShowText) then
		self.HPText:Show()
	else
		self.HPText:Hide()
	end

	if(self.db.profile.ShowPerc) then
		self.HPPerc:Show()
	else
		self.HPPerc:Hide()
	end

	if(self.db.profile.ShowDef) then
		self.DefText:Show()
	else
		self.DefText:Hide()
	end

	if(self.db.profile.Outline) then
		self.f.BG:Show()
	else
		self.f.BG:Hide()
	end

	self.ColorFade = self.db.profile.ColorFade

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
	self.f:SetValue(UnitHealth(self.unit))
	self.f.BG:SetAngle(180)
end

function module:Enable()
	-- Initial setup
	self.f:UpdateColor({["r"] = 0.1, ["g"] = 0.9, ["b"] = 0.0})
	self.f:SetMax(UnitHealthMax(self.unit))

	self.f.pulse = false

	if(UnitIsGhost(self.unit)) then
		self.f:GhostMode(true, self.unit)
	else
		self.f:GhostMode(false, self.unit)
		local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
		self.f:SetValue(cur)
		self.HPText:SetText(ns.ValueText(cur, max))
		self.HPText:SetTextColor(0, 1, 0)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
		self.DefText:SetText("0")
	end

	-- Register the events we will use
	self:RegisterUnitEvent("UNIT_HEALTH", 		"UpdateHealth", self.unit)
	self:RegisterUnitEvent("UNIT_MAXHEALTH", 	"UpdateHealth", self.unit)
	self:RegisterEvent("PLAYER_LEVEL_UP")

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:PLAYER_LEVEL_UP()
	self.f:SetMax(UnitHealthMax(self.unit))
end

function module:UpdateHealth(event, unit)
	if(unit ~= self.unit) then return end

	if(UnitIsGhost(self.unit)) then
		self.f:GhostMode(true, self.unit)
		return
	end
	self.f:GhostMode(false, self.unit)

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
			self.f:UpdateColor({["r"] = r, ["g"] = g, ["b"] = 0.0})
			self.HPText:SetTextColor(r, g, 0)
		else
			self.HPText:SetTextColor(0, 1, 0)
			self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0.0})
		end

		local deficit = max - cur
		if deficit <= 0 then
			deficit = ""
		else
			deficit = "-" .. deficit
		end
		self.DefText:SetAlpha(1)
		self.DefText:SetText(deficit)
	else
		-- Secret health: same red -> yellow -> green fade, evaluated by the client from a color curve
		if(self.ColorFade) then
			local r, g, b = ArcHUDRingTemplate.UnpackCurveColor(UnitHealthPercent(self.unit, true, ArcHUDRingTemplate.GetHealthColorCurve()))
			if r then
				self.f:CallTextureMethod("SetVertexColor", r, g, b, 1)
				self.HPText:SetTextColor(r, g, b)
			end
		else
			self.HPText:SetTextColor(0, 1, 0)
			self.f:UpdateColor({["r"] = 0, ["g"] = 1, ["b"] = 0.0})
		end
		-- Deficit text is hidden at full health through a step curve instead of "if deficit <= 0"
		self.DefText:SetText("-" .. UnitHealthMissing(self.unit, true))
		self.DefText:SetAlpha(UnitHealthPercent(self.unit, true, ArcHUDRingTemplate.GetAlphaCurve(0.9999995, 1, 0)))
	end

	self.HPText:SetText(ns.ValueText(cur, max))
	self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))

	self.f:SetMax(max)
	self.f:SetValue(cur)
end
