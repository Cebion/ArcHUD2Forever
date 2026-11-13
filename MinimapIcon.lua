-- Minimap access to the ArcHUD menu (new in the Forever port; the 1.12 addon only had /archud config).
--   * A classic draggable minimap button (position and visibility saved per character)
--   * An entry in Blizzard's addon compartment (functions named in the TOC)
local addonName, ns = ...
local ArcHUD = ArcHUD

local ICON = "Interface\\AddOns\\ArcHUD2\\Icons\\ArcHUDIcon"

local function ShowTooltip(owner, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
	GameTooltip:SetText("ArcHud 2 Forever", 1, 0.82, 0)
	GameTooltip:AddLine("Click: open options", 1, 1, 1)
	if owner == ArcHUD.minimapButton then
		GameTooltip:AddLine("Drag: move this icon", 1, 1, 1)
	end
	GameTooltip:Show()
end

local function OpenMenu()
	GameTooltip:Hide()
	ns.SafeCall(ArcHUD.OpenConfigMenu, ArcHUD)
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local function UpdatePosition(button)
	local angle = math.rad(ArcHUD.db.profile.MinimapAngle or 225)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate(button)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	ArcHUD.db.profile.MinimapAngle = math.deg(math.atan2(py - my, px - mx)) % 360
	UpdatePosition(button)
end

local function CreateMinimapButton()
	-- Named so minimap button collector addons can find it
	local button = CreateFrame("Button", "ArcHUDMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(19, 19)
	icon:SetTexture(ICON)
	icon:SetPoint("TOPLEFT", 6, -6)
	button.icon = icon

	button:SetScript("OnClick", function(self)
		-- Releasing the mouse after a drag must not open the menu
		if self.dragStoppedAt and GetTime() - self.dragStoppedAt < 0.3 then return end
		OpenMenu()
	end)
	button:SetScript("OnEnter", function(self)
		if not self.dragging then ShowTooltip(self, "ANCHOR_LEFT") end
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 7, -7) end)
	button:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 6, -6) end)
	button:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:LockHighlight()
		GameTooltip:Hide()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self)
		self.dragging = false
		self.dragStoppedAt = GetTime()
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		icon:SetPoint("TOPLEFT", 6, -6)
	end)

	return button
end

-- Called from OnProfileEnable (login, setting changes, reset)
function ArcHUD:UpdateMinimapIcon()
	if not self.minimapButton then
		self.minimapButton = CreateMinimapButton()
	end
	UpdatePosition(self.minimapButton)
	self.minimapButton:SetShown(self.db.profile.MinimapIcon and true or false)
end

---------------------------------------------------------------------------
-- Addon compartment (Blizzard's addon list button on the minimap).
-- These globals are named in ArcHUD2.toc; Blizzard calls them with (addonName, mouseButton or button frame).
---------------------------------------------------------------------------
function ArcHUD_OnAddonCompartmentClick()
	OpenMenu()
end

function ArcHUD_OnAddonCompartmentEnter(_, button)
	ShowTooltip(button, "ANCHOR_LEFT")
end

function ArcHUD_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
