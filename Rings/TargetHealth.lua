local addonName, ns = ...
local IsTrue = ns.IsTrue

local module = ArcHUD:NewModule("TargetHealth")
module.unit = "target"
module.defaults = {
	Enabled = true,
	Outline = true,
	ShowPerc = true,
	Side = 1,
	Level = 1,
}
module.options = {
	{name = "ShowPerc", text = "SHOWPERC", tooltip = "SHOWPERC"},
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

	self.HPPerc = self:CreateFontString(self.f, "BACKGROUND", {40, 12}, 11, "RIGHT", {1.0, 1.0, 1.0}, {"TOPLEFT", self.f, "BOTTOMLEFT", -100, -115})
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

	-- Clear all points for the ring
	self.f:ClearAllPoints()

	-- Clear all points for the percentage display
	self.HPPerc:ClearAllPoints()
	self.f:SetValue(0)
	if(self.db.profile.Side == 1) then
		-- Attach to left side
		self.f:SetPoint("TOPLEFT", self.parent:GetModule("Anchors").Left, "TOPLEFT", self.db.profile.Level * -15, 0)
		self.HPPerc:SetPoint("TOPLEFT", self.f, "BOTTOMLEFT", -100, -115)
		self.f.BG:SetReversed(false)
		self.f:SetReversed(false)
	else
		-- Attach to right side
		self.f:SetPoint("TOPRIGHT", self.parent:GetModule("Anchors").Right, "TOPRIGHT", self.db.profile.Level * 15, 0)
		self.HPPerc:SetPoint("TOPLEFT", self.f, "BOTTOMLEFT", 50, -115)
		self.f.BG:SetReversed(true)
		self.f:SetReversed(true)
	end
	if(UnitExists(self.unit)) then
		self.f:SetValue(UnitHealth(self.unit))
	end
	self.f.BG:SetAngle(180)
end

function module:Enable()
	self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
	if not UnitExists(self.unit) then
		self.f:SetMax(100)
		self.f:SetValue(0)
		self.HPPerc:SetText("")
	else
		local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
		self.f:SetMax(max)
		self.f:SetValue(cur)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
	end

	-- Register the events we will use
	self:RegisterUnitEvent("UNIT_HEALTH",		"UpdateHealth", self.unit)
	self:RegisterUnitEvent("UNIT_MAXHEALTH",	"UpdateHealth", self.unit)
	self:RegisterEvent("PLAYER_TARGET_CHANGED")

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

function module:PLAYER_TARGET_CHANGED()
	self.f.alphaState = -1
	if not UnitExists(self.unit) then
		self.f.pulse = false
		self.f:SetMax(100)
		self.f:SetValue(0)
		self.HPPerc:SetText("")
	else
		self.f.pulse = false
		self.tapped = false
		self.friend = false
		self.f:SetMax(UnitHealthMax(self.unit))
		if(UnitIsDead(self.unit)) then
			self.f:GhostMode(false, self.unit)
			self.f:SetValue(0)
			self.HPPerc:SetText("Dead")
		elseif(UnitIsGhost(self.unit)) then
			self.f:GhostMode(true, self.unit)
		else
			self.f:GhostMode(false, self.unit)
			-- UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) became UnitIsTapDenied(unit)
			if (IsTrue(UnitIsTapDenied(self.unit))) then
				self.f:UpdateColor({["r"] = 0.5, ["g"] = 0.5, ["b"] = 0.5})
				self.tapped = true
			elseif (IsTrue(UnitIsFriend("player", self.unit))) then
				self.f:UpdateColor({["r"] = 0, ["g"] = 0.5, ["b"] = 1})
				self.friend = true
			else
				self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
			end
			local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
			self.f:SetValue(cur)
			self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
		end
	end
end

function module:UpdateHealth(event, unit)
	if(unit ~= self.unit) then return end
	if(UnitIsDead(self.unit)) then
		self.f:GhostMode(false, self.unit)
		self.f:SetValue(0)
		self.HPPerc:SetText("Dead")
	elseif(UnitIsGhost(self.unit)) then
		self.f:GhostMode(true, self.unit)
	else
		self.f:GhostMode(false, self.unit)

		-- Update ring color based on target status
		-- (the original's mid-fight "tapped" re-check could never be true and is left out)
		local friend = IsTrue(UnitIsFriend("player", self.unit))
		if(not self.friend and friend) then
			self.f:UpdateColor({["r"] = 0, ["g"] = 0.5, ["b"] = 1})
			self.friend = true
		elseif(self.friend and not friend) then
			self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
			self.friend = false
		end

		local cur, max = UnitHealth(self.unit), UnitHealthMax(self.unit)
		self.HPPerc:SetText(ns.PercentText(cur, max, HealthPercent))
		if (event == "UNIT_MAXHEALTH") then
			self.f:SetMax(max)
		else
			self.f:SetValue(cur)
		end
	end
end
