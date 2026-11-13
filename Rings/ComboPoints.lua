local addonName, ns = ...
local Readable = ns.Readable

local module = ArcHUD:NewModule("ComboPoints")
module.unit = "player"
module.defaults = {
	Enabled = true,
	Outline = true,
	Flash = true,
	Side = 2,
	Level = 1,
}
module.options = {
	{name = "Flash", text = "FLASH", tooltip = "FLASH"},
	attach = true,
}
module.localized = true

-- Combo points are a secondary resource and normally readable; this is only the secret fallback
local function ComboPercent(curve)
	return UnitPowerPercent("player", Enum.PowerType.ComboPoints, false, curve)
end

local function GetPoints()
	return GetComboPoints("player", "target")
end

function module:Initialize()
	-- Setup the frame we need
	self.f = self:CreateRing(true, ArcHUDFrame)
	self.f:SetAlpha(0)
	self.f:SetSecretSource(ComboPercent)

	-- Override Update timer (flash coloring at max combo points)
	self:RegisterMetro(self.name .. "Update", self.PulseUpdate, 0.05, self.f)
end

function module:Update()
	if(self.db.profile.Outline) then
		self.f.BG:Show()
	else
		self.f.BG:Hide()
	end

	self.Flash = self.db.profile.Flash

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
	self.f.dirty = true
	self.f.fadeIn = 0.25

	self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
	self.f:SetMax(5)
	self.f:SetValue(GetPoints())

	-- Register the events we will use (PLAYER_COMBO_POINTS became the player's power events)
	self:RegisterUnitEvent("UNIT_POWER_FREQUENT",	"UpdateComboPoints", "player")
	self:RegisterEvent("PLAYER_TARGET_CHANGED",		"UpdateComboPoints")

	-- Activate the timers
	self:StartMetro(self.name .. "Alpha")
	self:StartMetro(self.name .. "Fade")
	self:StartMetro(self.name .. "Update")

	self.f:Show()
end

-- Called with the ring frame as self
function module.PulseUpdate(self, elapsed)
	if(self.pulse) then
		self.alphaPulse = self.alphaPulse + elapsed/2
		local amt = math.sin(self.alphaPulse * self.twoPi) * 0.5 + 0.5
		self:UpdateColor({["r"] = 1, ["g"] = amt, ["b"] = amt})
	end
end

function module:UpdateComboPoints()
	local points = GetPoints()
	self.f:SetValue(points)
	if not Readable(points) then
		-- Cannot compare a secret: keep the ring visible while a target exists
		self.f.pulse = false
		self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
		if UnitExists("target") then
			if(ArcHUD.db.profile.FadeIC > ArcHUD.db.profile.FadeOOC) then
				self.f:SetRingAlpha(ArcHUD.db.profile.FadeIC)
			else
				self.f:SetRingAlpha(ArcHUD.db.profile.FadeOOC)
			end
		else
			self.f:SetRingAlpha(0)
		end
		return
	end
	if(points < 5 and points >= 0) then
		self.f.pulse = false
		self.f.alphaPulse = 0
		self.f:UpdateColor({["r"] = 1, ["g"] = 0, ["b"] = 0})
	else
		if(self.Flash) then
			self.f.pulse = true
		else
			self.f.pulse = false
		end
	end
	if(points > 0) then
		if(ArcHUD.db.profile.FadeIC > ArcHUD.db.profile.FadeOOC) then
			self.f:SetRingAlpha(ArcHUD.db.profile.FadeIC)
		else
			self.f:SetRingAlpha(ArcHUD.db.profile.FadeOOC)
		end
	else
		self.f:SetRingAlpha(0)
	end
end
