-- ArcHUDRingTemplate_ Ring Template
----------------------------------------------------------------------
--
-- Template code for partial ring display
--
-- Divides the ring up into four quadrants:
--   Q1-TopRight Q2-BottomRight Q3-BottomLeft Q4-TopLeft
--
-- Other terminology:
--   self.radius - The outer radius of the ring (Also the texture width)
--   self.ringFactor - The ratio of inner radius/outer radius
--
-- WoW Forever port:
--   Two render paths share the same textures.
--   * Readable values: the original quadrant / chip / slice renderer below, unchanged
--     (same look, same tapered tip, same fade animation).
--   * Secret values (health / power during combat restrictions): addon code may not do math with them,
--     so the ring shows its full half-ring and a rotating MaskTexture cuts it along the radius.
--     The rotation comes from UnitHealthPercent / UnitPowerPercent evaluated against a curve on the
--     client side, so Lua never sees the number. Only the fade animation is skipped in that mode.

local addonName, ns = ...
local Readable = ns.Readable
local GetTrackedAlpha -- defined in the Alpha section below

---------------------------------------------------------------------------
-- QUADRANT MAPPING FUNCTIONS
--   The subsetting code is all written relative to the first quandrant, but
--   each quadrant has a pair of functions to manage mapping location and
--   texture operations from that 'normalized' coordinate system into the
--   appropriate one for the quadrant in question
--
-- SUBSET FUNCTION
--   self function displays a subset of a quadrant, using a subset of a
--   texture (The texture subsetting is optional, so the same function
--   can be used for slice stretching). Note self does not issue a
--   ClearAllPoints.
--
--   setSubsetFuncs[quadrant](tex, parname, radius, xlo, xhi, ylo, yhi, notex)
--
-- SLICE FUNCTION
--   self function sets the texture coordinates for a slice texture, so that
--   it's correctly oriented for the quadrant.
--
--   setSliceFuncs[quadrant](tex)
--
local setSubsetFuncs = {}
local setSliceFuncs = {}
ArcHUDRingTemplate = {}
local ArcHUDRingTemplate = ArcHUDRingTemplate

-- Q3: BOTTOM LEFT
setSubsetFuncs[1] = function(tex, parname, radius, xlo, xhi, ylo, yhi, notex)
	if (not notex) then
		tex:SetTexCoord(xhi, xlo, ylo, yhi)
	end
	tex:SetPoint("BOTTOMRIGHT", parname, "BOTTOMLEFT", -xlo*radius, -yhi*radius)
	tex:SetPoint("TOPLEFT", parname, "BOTTOMLEFT", -xhi*radius, -ylo*radius)
end

-- Q4: TOP LEFT
setSubsetFuncs[2] = function(tex, parname, radius, xlo, xhi, ylo, yhi, notex)
	if (not notex) then
		tex:SetTexCoord(yhi, ylo, xhi, xlo)
	end
	tex:SetPoint("BOTTOMLEFT", parname, "BOTTOMLEFT", -yhi*radius, xlo*radius)
	tex:SetPoint("TOPRIGHT", parname, "BOTTOMLEFT", -ylo*radius, xhi*radius)
end

-- Q1: TOP RIGHT
setSubsetFuncs[3] = function(tex, parname, radius, xlo, xhi, ylo, yhi, notex)
	if (not notex) then
		tex:SetTexCoord(xlo, xhi, yhi, ylo)
	end
	tex:SetPoint("TOPLEFT", parname, "BOTTOMLEFT", xlo*radius, yhi*radius)
	tex:SetPoint("BOTTOMRIGHT", parname, "BOTTOMLEFT", xhi*radius, ylo*radius)
end

-- Q2: BOTTOM RIGHT
setSubsetFuncs[4] = function(tex, parname, radius, xlo, xhi, ylo, yhi, notex)
	if (not notex) then
		tex:SetTexCoord(ylo, yhi, xlo, xhi)
	end
	tex:SetPoint("TOPRIGHT", parname, "BOTTOMLEFT", yhi*radius, -xlo*radius)
	tex:SetPoint("BOTTOMLEFT", parname, "BOTTOMLEFT", ylo*radius, -xhi*radius)
end

-- Slice text coord setting funcs
setSliceFuncs[1] = function(tex) tex:SetTexCoord(0, 1, 1, 0) end
setSliceFuncs[2] = function(tex) tex:SetTexCoord(1, 0, 1, 0) end
setSliceFuncs[3] = function(tex) tex:SetTexCoord(1, 0, 0, 1) end
setSliceFuncs[4] = function(tex) tex:SetTexCoord(0, 1, 0, 1) end

-- The 'Work' function, which handles subset rendering for a single
-- quadrant (normalized to Q1)
function ArcHUDRingTemplate:DoQuadrantReversed(A, T, SS)
	-- Grab local references to important textures
	local C = self.chip
	local S = self.slice

	-- If no part of self quadrant is visible, just hide all the textures
	-- and be done.
	if (A == 0) then
		T:Hide()
		C:Hide()
		S:Hide()
		return
	end

	local RF = self.ringFactor
	local OR = self.radius

	-- Drawing scheme uses three locations
	--   E (Ex,Ey) - The 'End' position (Nx=1, Ny=0)
	--   O (Ox,Oy) - Intersection of angle line with Outer edge
	--   I (Ix,Iy) - Intersection of angle line with Inner edge
	local Arad = math.rad(A)
	local Ox = math.cos(Arad)
	local Oy = math.sin(Arad)
	local Ix = Ox * RF
	local Iy = Oy * RF

	-- Treat first and last halves differently to maximize size of main
	-- texture subset.
	if (A <= 45) then
		SS(T, self, OR, Ix, 1,  0, Iy)
		SS(C, self, OR, Ox, 1, Iy, Oy)
	else
		SS(T, self, OR, Ox, 1,  0, Oy)
		SS(C, self, OR, Ix, Ox, 0, Iy)
	end
	-- Strech slice between I and O
	SS(S, self, OR, Ix, Ox, Iy, Oy, 1)
	T:Show()
	C:Show()
	S:Show()
end

function ArcHUDRingTemplate:DoQuadrant(A, T, SS)
	local C = self.chip
	local S = self.slice

	if (A == 0) then
		T:Hide()
		C:Hide()
		S:Hide()
		return
	end

	local RF = self.ringFactor
	local OR = self.radius

	-- Drawing scheme uses three locations
	--   N (Nx,Ny) - The 'Noon' position (Nx=0, Ny=1)
	--   O (Ox,Oy) - Intersection of angle line with Outer edge
	--   I (Ix,Iy) - Intersection of angle line with Inner edge
	local Arad = math.rad(A)
	local Ox = math.sin(Arad)
	local Oy = math.cos(Arad)
	local Ix = Ox * RF
	local Iy = Oy * RF

	if (A <= 45) then
		SS(T, self, OR, 0, Ix, Iy, 1)
		SS(C, self, OR, Ix, Ox, Oy, 1)
	else
		SS(T, self, OR, 0, Ox, Oy, 1)
		SS(C, self, OR, 0, Ix, Iy, Oy)
	end
	SS(S, self, OR, Ix, Ox, Iy, Oy, 1)
	T:Show()
	C:Show()
	S:Show()
end

-- Method function to set the angle to display
--  angle - The angle in degrees (0 <= angle <= 180)
function ArcHUDRingTemplate:SetAngle(angle)
	-- Bounds checking on the angle so that it's between 0 and 180 (inclusive)
	if (angle < 0) then
		angle = 0
	end
	if (angle > 180) then
		angle = 180
	end

	-- Avoid duplicate work
	if (self.angle == angle and not self.dirty) then
		return
	end

	-- Determine the quadrant, and angle within the quadrant
	-- (Quadrant 5 means 'all quadrants filled')
	local quad = math.floor(angle / 90) + 1
	local A = angle % 90
	local quadOfs = self.quadOffset or 0
	local effQuad
	if (self.reversed) then
		effQuad = ((4-quad)+quadOfs) % 4 + 1
	else
		effQuad = (quad+quadOfs-1) % 4 + 1
	end

	-- Check to see if we've changed quandrants since the last time we were
	-- called. Quadrant changes re-configure some textures.
	if (quad ~= self.lastQuad or self.dirty) then
		for i = 1, 2 do
			local T = self.quadrants[i]
			local qi
			if (self.reversed) then
				qi = ((4-i)+quadOfs) % 4 + 1
			else
				qi = (i+quadOfs-1) % 4 + 1
			end
			if (i < quad) then
				-- If self quadrant is full shown, then show all of the texture
				T:ClearAllPoints()
				setSubsetFuncs[qi](T, self, self.radius, 0.0, 1.0, 0.0, 1.0)
				T:Show()
			elseif (i == quad) then
				-- If self quadrant is partially or fully shown, begin by
				-- showing all of the texture. Also configure the slice
				-- texture's orientation.
				T:ClearAllPoints()
				setSubsetFuncs[qi](T, self, self.radius, 0.0, 0.8, 0.4, 1.0)
				T:Show()
				if (self.reversed) then
					setSliceFuncs[(qi+1) % 4 + 1](self.slice)
				else
					setSliceFuncs[qi](self.slice)
				end
			else
				-- If self quadrant is not shown at all, hide it.
				T:Hide()
			end
		end

		-- Hide the chip and slice textures, and de-anchor them (They'll be
		-- re-anchored as necessary later).
		self.chip:Hide()
		self.chip:ClearAllPoints()
		self.slice:Hide()
		self.slice:ClearAllPoints()

		self.lastQuad = quad
	end

	self.angle = angle

	-- Extra bounds check for paranoia (also handles quad 5 case)
	if ((quad < 1) or (quad > 2)) then
		return
	end

	local T = self.quadrants[quad]
	local SS = setSubsetFuncs[effQuad]

	if SS ~= nil then
		if (self.reversed) then
			self:DoQuadrantReversed(A, T, SS)
		else
			self:DoQuadrant(A, T, SS)
		end
	end
	self.dirty = false
end

---------------------------------------------------------------------------
-- Some handy method functions

-- ring:CallTextureMethod("SetVertexColor", 1.0, 0.5, 0.2, 1.0)
function ArcHUDRingTemplate:CallTextureMethod(method, ...)
	self.quadrants[1][method](self.quadrants[1], ...)
	self.quadrants[2][method](self.quadrants[2], ...)
	self.chip[method](self.chip, ...)
	self.slice[method](self.slice, ...)
end

function ArcHUDRingTemplate:SetRingTextures(ringFactor, ringTexture, sliceTexture)
	local savedAngle = self.angle
	self.angle = nil
	self.lastQuad = nil

	self.ringFactor = ringFactor

	for i = 1, 2 do
		self.quadrants[i]:SetTexture(ringTexture)
	end
	self.chip:SetTexture(ringTexture)
	self.slice:SetTexture(sliceTexture)

	if (savedAngle) then
		self:SetAngle(savedAngle)
	end
end

-- Method function to set whether or not ring growth is reversed.
function ArcHUDRingTemplate:SetReversed(isReversed)
	if (isReversed) then
		isReversed = true
	else
		isReversed = nil
	end
	if (isReversed == self.reversed) then
		return
	end
	self.reversed = isReversed
	self.dirty = true
	if self.mask then
		ArcHUDRingTemplate.LayoutMask(self)
		if self.secret then
			ArcHUDRingTemplate.UpdateSecretAngle(self)
		end
	end
end

---------------------------------------------------------------------------
-- Secret value support
---------------------------------------------------------------------------
local MASK_TEXTURE = "Interface\\AddOns\\ArcHUD2\\Icons\\RingMask.tga"
-- Texture:SetRotation is counter clockwise for positive radians.
-- If the rings ever fill from the wrong end in secret mode, flip this to -1.
local ROTATION_SIGN = 1

local curveCache = {}

-- Linear curve percent (0..1) -> mask rotation in radians
local function GetRotationCurve(reversed)
	local key = reversed and "rotR" or "rotL"
	if not curveCache[key] then
		local curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		curve:AddPoint(0, 0)
		-- Left ring fills bottom to top clockwise, right ring counter clockwise
		curve:AddPoint(1, (reversed and math.pi or -math.pi) * ROTATION_SIGN)
		curveCache[key] = curve
	end
	return curveCache[key]
end

-- Step curve for "is the ring full" alpha decisions
local function GetAlphaCurve(threshold, belowAlpha, aboveAlpha)
	local key = string.format("a%.7f_%.3f_%.3f", threshold, belowAlpha, aboveAlpha)
	if not curveCache[key] then
		local curve = C_CurveUtil.CreateCurve()
		curve:SetType(Enum.LuaCurveType.Step)
		curve:AddPoint(0, belowAlpha)
		curve:AddPoint(threshold, aboveAlpha)
		curveCache[key] = curve
	end
	return curveCache[key]
end
ArcHUDRingTemplate.GetAlphaCurve = GetAlphaCurve

-- Health color fade (red -> yellow -> green), same values as the original formula
local function GetHealthColorCurve()
	if not curveCache.healthColor then
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		curve:AddPoint(0, CreateColor(1, 0, 0, 1))
		curve:AddPoint(0.5, CreateColor(1, 1, 0, 1))
		curve:AddPoint(1, CreateColor(0, 1, 0, 1))
		curveCache.healthColor = curve
	end
	return curveCache.healthColor
end
ArcHUDRingTemplate.GetHealthColorCurve = GetHealthColorCurve

-- Unpack a color returned by a curve evaluation; the components may be secret, which SetVertexColor accepts.
function ArcHUDRingTemplate.UnpackCurveColor(color)
	if type(color) ~= "table" then return nil end
	if canaccesstable and not canaccesstable(color) then return nil end
	if color.GetRGB then
		return color:GetRGB()
	end
	return color.r, color.g, color.b
end

function ArcHUDRingTemplate:LayoutMask()
	local mask = self.mask
	local size = self.radius + 8
	mask:ClearAllPoints()
	mask:SetSize(size, size * 2)
	-- The ring center is the frame's BOTTOMLEFT corner (see setSubsetFuncs).
	if self.reversed then
		-- Right ring: mask covers the left half plane, pivots on its right edge
		mask:SetPoint("RIGHT", self, "BOTTOMLEFT", 0, 0)
		self.maskPivot = CreateVector2D(1, 0.5)
	else
		-- Left ring: mask covers the right half plane, pivots on its left edge
		mask:SetPoint("LEFT", self, "BOTTOMLEFT", 0, 0)
		self.maskPivot = CreateVector2D(0, 0.5)
	end
end

-- source(curve) must return UnitHealthPercent / UnitPowerPercent evaluated against curve.
function ArcHUDRingTemplate:SetSecretSource(source)
	self.secretSource = source
end

function ArcHUDRingTemplate:EnterSecretMode()
	if self.secret then return end
	self.secret = true
	-- Full half ring, cut by the mask
	self:SetAngle(180)
	self.chip:Hide()
	self.slice:Hide()
	self.quadrants[1]:AddMaskTexture(self.mask)
	self.quadrants[2]:AddMaskTexture(self.mask)
	self.mask:Show()
end

function ArcHUDRingTemplate:LeaveSecretMode()
	if not self.secret then return end
	self.secret = false
	self.quadrants[1]:RemoveMaskTexture(self.mask)
	self.quadrants[2]:RemoveMaskTexture(self.mask)
	self.mask:Hide()
	self.mask:SetRotation(0)
	-- Force the original renderer to rebuild every texture
	self.dirty = true
	self.angle = nil
	self.lastQuad = nil
	if self.alphaSecret then
		self.alphaSecret = false
		self:SetAlpha(GetTrackedAlpha(self))
	end
end

function ArcHUDRingTemplate:UpdateSecretAngle()
	if not self.secretSource then return end
	local rotation = self.secretSource(GetRotationCurve(self.reversed))
	if rotation ~= nil then
		self.mask:SetRotation(rotation, self.maskPivot)
	end
end

-- Alpha from a step curve: ring at or above threshold -> aboveAlpha, else belowAlpha.
-- Only used while the ring value is secret; there is no fade animation in that case.
function ArcHUDRingTemplate:SetSecretRingAlpha(threshold, belowAlpha, aboveAlpha)
	if not self.secretSource then return end
	local alpha = self.secretSource(GetAlphaCurve(threshold, belowAlpha, aboveAlpha))
	if alpha ~= nil then
		self.alphaSecret = true
		self.destAlpha = nil
		self:SetAlpha(alpha)
	end
end

---------------------------------------------------------------------------
-- Values
---------------------------------------------------------------------------
function ArcHUDRingTemplate:SetMax(max)
	if max == nil then max = 1 end
	if Readable(max) then
		self.maxSecret = false
		self.maxValue = max
	else
		-- Secret maximum: keep the last readable maxValue for the original renderer
		self.maxSecret = true
	end
end

function ArcHUDRingTemplate:SetValue(value)
	if value == nil then value = 0 end
	if not Readable(value) or self.maxSecret then
		-- Display only: hand the secret to the client through the curve driven mask
		if self.secretSource then
			ArcHUDRingTemplate.EnterSecretMode(self)
			ArcHUDRingTemplate.UpdateSecretAngle(self)
		end
		return
	end
	if self.secret then
		ArcHUDRingTemplate.LeaveSecretMode(self)
	end
	if value == 0 then
		value = self.maxValue / 10000
	end
	if self.casting == 1 then
		self.startValue = value
	end
	self.endValue = value
	self.fadeTime = 0
end

function ArcHUDRingTemplate:DoFadeUpdate(tdelta)
	if self.secret then return end
	if self.fadeTime < self.maxFadeTime then
		self.fadeTime = self.fadeTime + tdelta
		if self.fadeTime > self.maxFadeTime then
			self.fadeTime = self.maxFadeTime
		end
		local delta = self.endValue - self.startValue
		local diff = delta * (self.fadeTime / self.maxFadeTime)
		self.startValue = self.startValue + diff
		if self.maxValue == 0 then return end
		local angle = self.startValue / self.maxValue * 180
		if angle <= 90 then
			self.ringFactor = 0.9 + ((90 - angle) / (90/0.1))
		elseif angle <= 180 then
			self.ringFactor = 0.9 + ((angle - 90) / (90/0.1))
		end
		self:SetAngle((self.startValue / self.maxValue) * 180)
	end
end

---------------------------------------------------------------------------
-- Alpha
---------------------------------------------------------------------------
-- Never trust GetAlpha() on a ring: after a curve driven (secret) SetAlpha the frame keeps its
-- secret alpha aspect, and GetAlpha() keeps returning a secret that cannot be compared.
GetTrackedAlpha = function(self)
	if self.curAlpha ~= nil then
		return self.curAlpha
	end
	local a = self:GetAlpha()
	if Readable(a) then
		self.curAlpha = a
		return a
	end
	self.curAlpha = 0
	return 0
end

function ArcHUDRingTemplate:AlphaUpdate(elapsed)
	if(not self.fadeIn) then
		self.fadeIn = 1
	end
	if(not self.fadeOut) then
		self.fadeOut = 1
	end
	local destAlpha = self.destAlpha
	if (not destAlpha) then
		return
	end
	local nowAlpha = GetTrackedAlpha(self)
	if (nowAlpha < destAlpha) then
		nowAlpha = nowAlpha + (elapsed/self.fadeIn)
		if (nowAlpha > destAlpha) then
			nowAlpha = destAlpha
		end
	elseif (nowAlpha > destAlpha) then
		nowAlpha = nowAlpha - (elapsed/self.fadeOut)
		if (nowAlpha < destAlpha) then
			nowAlpha = destAlpha
		end
	end

	self.curAlpha = nowAlpha
	self:SetAlpha(nowAlpha)

	if (destAlpha == nowAlpha) then
		self.destAlpha = nil
	end
end

function ArcHUDRingTemplate:SetRingAlpha(destAlpha, instant)
	if (destAlpha < 0) then
		destAlpha = 0.0
	elseif (destAlpha > 1) then
		destAlpha = 1.0
	end

	if self.alphaSecret then
		-- Coming back from a curve driven alpha: continue from the last readable alpha
		self.alphaSecret = false
		self:SetAlpha(self.curAlpha or 0)
	end

	if (instant) then
		self.curAlpha = destAlpha
		self:SetAlpha(destAlpha)
		self.destAlpha = nil
		return
	end

	local nowAlpha = GetTrackedAlpha(self)
	if (nowAlpha == destAlpha) then
		return
	end
	if (self.destAlpha == destAlpha) then
		return
	end

	self.destAlpha = destAlpha
end

function ArcHUDRingTemplate:UpdateColor(color)
	if color == nil then
		color = {["r"] = 1, ["g"] = 0.6, ["b"] = 0.1}
	end
	if (color) then
		self:CallTextureMethod("SetVertexColor", color.r, color.g, color.b, 1)
	end
end

-- Power colors: the 1.12 ManaBarColor table became PowerBarColor (indexed by power type).
function ns.GetPowerColor(powerType)
	local color = PowerBarColor and PowerBarColor[powerType]
	if not color then
		color = { r = 0, g = 0, b = 1 }
	end
	return color
end

-- "Fullness" rules from the original UpdateAlpha. Returns:
--   "full"    -> ring is at 100% (or empty for rage, which counts as idle)
--   "notfull" -> otherwise
--   nil       -> the value is secret; the caller switches to SetSecretRingAlpha
local function RingFullState(f, rageStyle)
	if f.secret then return nil end
	if rageStyle then
		if math.floor(f.startValue) > 0 then return "notfull" end
		return "full"
	end
	if f.startValue < f.maxValue then return "notfull" end
	return "full"
end

-- Called on the ring module (self = module) by the Update timer every 0.05 seconds.
function ArcHUDRingTemplate:UpdateAlpha(elapsed)
	local isInCombat = false
	local parent = self.parent
	local profile = parent.db.profile

	if(self == parent:GetModule("PetHealth") or self == parent:GetModule("PetMana")) then
		isInCombat = parent.PetIsInCombat
	elseif(string.find(self.name, "Party")) then
		isInCombat = self.isInCombat or false
	else
		isInCombat = parent.PlayerIsInCombat
	end

	local isTargetHealth = (self == parent:GetModule("TargetHealth"))
	local isTargetMana = (self == parent:GetModule("TargetMana"))
	local isPet = (self == parent:GetModule("PetHealth") or self == parent:GetModule("PetMana"))
	local targetDead = UnitIsDead("target")
	-- maxValue 0 test (target without mana); a secret maximum counts as "has mana"
	local noMax = (not self.f.maxSecret) and self.f.maxValue == 0

	if(self.f.pulse) then
		self.f.alphaPulse = self.f.alphaPulse + (elapsed/2)
		local camt = math.cos(self.f.alphaPulse * self.f.twoPi) * 0.3
		self.f.curAlpha = 0.5-camt
		self.f:SetAlpha(0.5-camt)
		return
	end

	-- Shared "special case" rules (dead/missing target or pet)
	local function SpecialCase()
		if(isTargetHealth and targetDead) then
			self.f:SetRingAlpha(profile.FadeFull)
		elseif(isTargetMana and (targetDead or noMax)) then
			self.f:SetRingAlpha(0)
		elseif((isTargetHealth or isTargetMana) and not UnitExists("target")) then
			self.f:SetRingAlpha(0)
		elseif(isPet and not UnitExists("pet")) then
			self.f:SetRingAlpha(0)
		else
			return false
		end
		return true
	end

	if(profile.RingVisibility == 1 or profile.RingVisibility == 3) then
		if(profile.RingVisibility == 3 and isInCombat) then
			if not SpecialCase() then
				self.f:SetRingAlpha(profile.FadeIC)
			end
		else
			local unit = self.unit or "player"
			local isRageRing = string.find(self.name, "Mana") and not isPet and UnitPowerType(unit) == 1
				and (self.f.maxSecret or self.f.maxValue > 0)
			if isRageRing then
				local state = RingFullState(self.f, true)
				if state == "notfull" then
					self.f:SetRingAlpha(profile.FadeOOC)
				elseif state == "full" then
					self.f:SetRingAlpha(profile.FadeFull)
				else
					-- secret: any rage (>= 0.5%) -> FadeOOC, none -> FadeFull
					self.f:SetSecretRingAlpha(0.005, profile.FadeFull, profile.FadeOOC)
				end
			else
				if not SpecialCase() then
					local state = RingFullState(self.f, false)
					if state == "notfull" then
						self.f:SetRingAlpha(profile.FadeOOC)
					elseif state == "full" then
						self.f:SetRingAlpha(profile.FadeFull)
					else
						-- secret: 100% -> FadeFull, below -> FadeOOC (threshold just under 1 for float safety)
						self.f:SetSecretRingAlpha(0.9999995, profile.FadeOOC, profile.FadeFull)
					end
				end
			end
		end
	elseif(profile.RingVisibility == 2) then
		if not SpecialCase() then
			if(isInCombat) then
				self.f:SetRingAlpha(profile.FadeIC)
			else
				self.f:SetRingAlpha(profile.FadeFull)
			end
		end
	end
end

function ArcHUDRingTemplate:GhostMode(state, unit)
	local color = {["r"] = 0.75, ["g"] = 0.75, ["b"] = 0.75}
	local fh, fm
	if(unit == "player") then
		fh, fm = ArcHUD:GetModule("Health"), ArcHUD:GetModule("Mana")
	else
		fh, fm = ArcHUD:GetModule("TargetHealth"), ArcHUD:GetModule("TargetMana")
	end
	if(state) then
		-- Prepare health ring
		if(fh and fh.f and not fh.f.pulse) then
			fh.f:UpdateColor(color)
			fh.f.alphaPulse = 0
			fh.f:SetMax(1)
			fh.f:SetValue(1)
			if(unit == "player") then
				fh.HPText:SetText("Dead")
				fh.HPText:SetTextColor(1, 0, 0)
				fh.HPPerc:SetText("")
			else
				fh.HPPerc:SetText("Dead")
			end
			-- Enable pulsing
			fh.f.pulse = true
		end

		-- Prepare mana ring
		if(fm and fm.f and unit == "player" and not fm.f.pulse) then
			fm.f:UpdateColor(color)
			fm.f.alphaPulse = 0
			fm.f:SetMax(1)
			fm.f:SetValue(1)
			fm.MPText:SetText("")
			fm.MPPerc:SetText("")
			-- Enable pulsing
			fm.f.pulse = true
		end
	else
		if(fh and fh.f and fh.f.pulse) then
			fh.f.pulse = false
			fh.f:SetMax(UnitHealthMax(unit))
			fh.f:SetValue(UnitHealth(unit))
		end
		if(fm and fm.f and fm.f.pulse) then
			fm.f.pulse = false
			fm.f:SetMax(UnitPowerMax(unit))
			fm.f:SetValue(UnitPower(unit))
			fm.f:UpdateColor(ns.GetPowerColor(UnitPowerType(unit)))
		end
	end
end

-- The OnLoad method, call self for each template object to set it up and
-- get things going
function ArcHUDRingTemplate:OnLoad(frame)
	-- Initialize size and default texture ringFactor
	frame.radius = (frame:GetWidth() * 0.5)
	frame.ringFactor = 0.94

	-- Add ring methods
	frame.DoQuadrant				= self.DoQuadrant
	frame.DoQuadrantReversed		= self.DoQuadrantReversed
	frame.SetAngle					= self.SetAngle
	frame.CallTextureMethod			= self.CallTextureMethod
	frame.SetRingTextures			= self.SetRingTextures
	frame.SetMax					= self.SetMax
	frame.SetValue					= self.SetValue
	frame.UpdateColor				= self.UpdateColor
	frame.SetReversed				= self.SetReversed
	frame.SetRingAlpha				= self.SetRingAlpha
	frame.GhostMode					= self.GhostMode
	frame.SetSecretSource			= self.SetSecretSource
	frame.SetSecretRingAlpha		= self.SetSecretRingAlpha

	frame.startValue = 0
	frame.endValue = 0
	frame.maxValue = 0
	frame.fadeTime = 0
	frame.maxFadeTime = 1
	frame.alphaState = -1
	frame.PI = 3.14159265
	frame.twoPi = (frame.PI * 2)
	frame.pulse = false
	frame.alphaPulse = 0
	frame.curAlpha = 0
	frame:SetAlpha(0)

	-- Mask used only while values are secret
	frame.mask = frame:CreateMaskTexture()
	frame.mask:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	frame.mask:Hide()
	ArcHUDRingTemplate.LayoutMask(frame)

	-- Set angle to zero (initializes texture visibility)
	frame:SetAngle(0)
end

function ArcHUDRingTemplate:OnLoadBG(frame)
	-- Initialize size and default texture ringFactor
	frame.radius = (frame:GetWidth() * 0.5)
	frame.ringFactor = 0.94

	-- Add ring methods
	frame.DoQuadrant				= self.DoQuadrant
	frame.DoQuadrantReversed		= self.DoQuadrantReversed
	frame.SetAngle					= self.SetAngle
	frame.CallTextureMethod			= self.CallTextureMethod
	frame.UpdateColor				= self.UpdateColor
	frame.SetReversed				= self.SetReversed

	-- Set angle to 180 degrees (initializes texture visibility)
	frame:SetAngle(180)

	-- Set color and then remove the method again
	frame:UpdateColor({r = 0, g = 0, b = 0})
	frame.UpdateColor = nil
	frame.CallTextureMethod = nil
end
