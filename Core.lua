-- The addon object is created in Framework.lua (replaces AceLibrary("AceAddon-2.0"):new(...))
local addonName, ns = ...
local ArcHUD = ArcHUD

-- Locale object
local L = ns.Locale("ArcHUD_Core")

local Readable, IsTrue = ns.Readable, ns.IsTrue
local SetContainersActive -- defined with the target aura code below

-- Debugging levels
--   1 Warning
--   2 Info
--   3 Notice
--   4 Off
local debugLevels = {"warn", "info", "notice", "off"}

-- 1.12 DebuffTypeColor values (the global no longer exists)
local DebuffTypeColor = {
	none	= { r = 0.80, g = 0, b = 0 },
	Magic	= { r = 0.20, g = 0.60, b = 1.00 },
	Curse	= { r = 0.60, g = 0.00, b = 1.00 },
	Disease	= { r = 0.60, g = 0.40, b = 0 },
	Poison	= { r = 0.00, g = 0.60, b = 0 },
}

-- Set up database defaults
ArcHUD:RegisterDefaults("profile", {
	Debug = nil,
	TargetFrame = true,
	PlayerModel = true,
	MobModel = false,
	ShowGuild = true,
	ShowClass = false,
	Width = 30,
	YLoc = 0,
	FadeFull = 0.1,
	FadeOOC = 0.5,
	FadeIC = 0.75,
	RingVisibility = 3,
	PartyLock = true,
	TargetTarget = true,
	TargetTargetTarget = true,
	NamePlates = true,
	Scale = 1.0,
	AttachTop = false,
	ShowBuffs = true,
	HoverMsg = true,
	HoverDelay = 3,
	BlizzPlayer = true,
	BlizzTarget = true,
	-- New in the Forever port
	MinimapIcon = true,
	MinimapAngle = 225,
})

---------------------------------------------------------------------------
-- Settings validation: the same ranges the menu sliders allow. Out of range values
-- (for example from the slider bug in the first Forever build) fall back to the defaults.
---------------------------------------------------------------------------
local coreRanges = {
	HoverDelay = {0, 5, 3},
	FadeFull = {0, 1, 0.1},
	FadeOOC = {0, 1, 0.5},
	FadeIC = {0, 1, 0.75},
	Width = {30, 100, 30},
	YLoc = {-50, 200, 0},
	Scale = {0.1, 2, 1.0},
	RingVisibility = {1, 3, 3},
	MinimapAngle = {0, 360, 225},
}
local moduleRanges = {
	Level = {-5, 5},
	Side = {1, 2},
}

local function InRange(v, lo, hi)
	return type(v) == "number" and v >= lo and v <= hi
end

function ArcHUD:ValidateSettings()
	local profile = self.db.profile
	for key, r in pairs(coreRanges) do
		if not InRange(profile[key], r[1], r[2]) then
			self:Print("Setting %s had an invalid value (%s), reset to %s", key, tostring(profile[key]), tostring(r[3]))
			profile[key] = r[3]
		end
	end
	for _, module in ipairs(self.moduleList) do
		if module.db and module.defaults then
			for key, r in pairs(moduleRanges) do
				local default = module.defaults[key]
				if default ~= nil and not InRange(module.db.profile[key], r[1], r[2]) then
					self:Print("%s setting %s had an invalid value (%s), reset to %s", module.name, key, tostring(module.db.profile[key]), tostring(default))
					module.db.profile[key] = default
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Chat commands (AceConsole-2.0 replacement): /archud and /ah
---------------------------------------------------------------------------
local function PrintUsage()
	ArcHUD:Print("|cffffff7f/archud|r or |cffffff7f/ah|r")
	ArcHUD:Print("  |cffffff7freset confirm|r - %s", L("CMD_RESET"))
	ArcHUD:Print("  |cffffff7fconfig|r - %s", L("CMD_OPTS_FRAME"))
	ArcHUD:Print("  |cffffff7fdebug|r [off||warn||info||notice] - %s (%s)", L("CMD_OPTS_DEBUG"), debugLevels[ArcHUD:GetDebugLevel() or 4])
	ArcHUD:Print("  |cffffff7ferrors|r [clear] - show (or clear) the logged ArcHUD errors")
end

SLASH_ARCHUD1 = "/archud"
SLASH_ARCHUD2 = "/ah"
SlashCmdList["ARCHUD"] = function(msg)
	local cmd, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
	cmd = string.lower(cmd or "")
	if cmd == "reset" then
		if string.upper(rest or "") == "CONFIRM" then
			ArcHUD:ResetOptionsConfirm()
		else
			ArcHUD:Print(L("TEXT_RESET"))
		end
	elseif cmd == "config" then
		ns.SafeCall(ArcHUD.OpenConfigMenu, ArcHUD)
	elseif cmd == "errors" then
		if string.lower(rest or "") == "clear" then
			ArcHUD:ClearErrors()
		else
			ArcHUD:PrintErrors()
		end
	elseif cmd == "debug" then
		local v = string.lower(rest or "")
		if(v == "notice") then
			ArcHUD:SetDebugLevel(3)
			ArcHUD.db.profile.Debug = 3
		elseif(v == "info") then
			ArcHUD:SetDebugLevel(2)
			ArcHUD.db.profile.Debug = 2
		elseif(v == "warn") then
			ArcHUD:SetDebugLevel(1)
			ArcHUD.db.profile.Debug = 1
		elseif(v == "off") then
			ArcHUD:SetDebugLevel(nil)
			ArcHUD.db.profile.Debug = nil
		end
		ArcHUD:Print("debug: %s", debugLevels[ArcHUD:GetDebugLevel() or 4])
	else
		PrintUsage()
	end
end

function ArcHUD.modDB(action, key, namespace, value)
	if(not action or not key) then return end
	if(namespace and not value and not ArcHUD:HasModule(namespace)) then
		value = namespace
		namespace = nil
	end

	if(action == "toggle") then
		ArcHUD:LevelDebug(3, "Toggling key '%s'", key)
		if(namespace) then
			ArcHUD:AcquireDBNamespace(namespace).profile[key] = not ArcHUD:AcquireDBNamespace(namespace).profile[key]
		else
			ArcHUD.db.profile[key] = not ArcHUD.db.profile[key]
		end
	elseif(action == "set") then
		ArcHUD:LevelDebug(3, "Setting new value for key '%s' = '%s'", key, value)
		if(namespace) then
			ArcHUD:AcquireDBNamespace(namespace).profile[key] = tonumber(value)
		else
			ArcHUD.db.profile[key] = tonumber(value)
		end
	end

	ArcHUD:ValidateSettings()

	if(namespace) then
		ArcHUD:TriggerEvent("ARCHUD_MODULE_UPDATE", namespace)
	else
		-- Re-layout touches the secure nameplates and Blizzard frames: wait for combat to end if needed
		ns.RunOutOfCombat("profileReload", function()
			ArcHUD:OnProfileDisable()
			ArcHUD:OnProfileEnable()
		end)
	end
end

function ArcHUD:OnInitialize()
	-- Set debug level
	self:SetDebugLevel(self.db.profile.Debug)

	self.ClassColor = {
		["MAGE"] =		"00FFFF",
		["WARLOCK"] =	"8D54FB",
		["PRIEST"] =	"FFFFFF",
		["DRUID"] =		"FF8A00",
		["SHAMAN"] =	"FF71A8",
		["PALADIN"] =	"FF71A8",
		["ROGUE"] =		"FFFF00",
		["HUNTER"] =	"00FF00",
		["WARRIOR"] =	"B39442",
	}

	self:LevelDebug(3, "Creating core addon menu")
	self.dewdrop_menu = {
		["L1"] = {
			{"text", L("TEXT","TITLE"), "isTitle", true},
			{"text", L("Version: ")..self.version,	"notClickable", true},
			{"text", L("Author: ")..self.author, "notClickable", true},
			{},
			{"text", L("TEXT","DISPLAY"), "hasArrow", true, "value", "L2_display"},
			{"text", L("TEXT","FADE"), "hasArrow", true, "value", "L2_fade"},
			{"text", L("TEXT","MISC"), "hasArrow", true, "value", "L2_misc"},
			{},
			{"text", L("TEXT","RINGS"), "isTitle", true},
		},
		["L2_display"] = {
			{
				"text", L("TEXT","TARGETFRAME"),
				"tooltipTitle", L("TEXT","TARGETFRAME"),
				"tooltipText", L("TOOLTIP","TARGETFRAME"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "TargetFrame"
			},
			{
				"text", L("TEXT","BLIZZPLAYER"),
				"tooltipTitle", L("TEXT","BLIZZPLAYER"),
				"tooltipText", L("TOOLTIP","BLIZZPLAYER"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "BlizzPlayer"
			},
			{
				"text", L("TEXT","BLIZZTARGET"),
				"tooltipTitle", L("TEXT","BLIZZTARGET"),
				"tooltipText", L("TOOLTIP","BLIZZTARGET"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "BlizzTarget"
			},
			{
				"text", L("TEXT","PLAYERMODEL"),
				"tooltipTitle", L("TEXT","PLAYERMODEL"),
				"tooltipText", L("TOOLTIP","PLAYERMODEL"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "PlayerModel"
			},
			{
				"text", L("TEXT","MOBMODEL"),
				"tooltipTitle", L("TEXT","MOBMODEL"),
				"tooltipText", L("TOOLTIP","MOBMODEL"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "MobModel"
			},
			{
				"text", L("TEXT","SHOWGUILD"),
				"tooltipTitle", L("TEXT","SHOWGUILD"),
				"tooltipText", L("TOOLTIP","SHOWGUILD"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "ShowGuild"
			},
			{
				"text", L("TEXT","SHOWCLASS"),
				"tooltipTitle", L("TEXT","SHOWCLASS"),
				"tooltipText", L("TOOLTIP","SHOWCLASS"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "ShowClass"
			},
			{
				"text", L("TEXT","NAMEPLATES"),
				"tooltipTitle", L("TEXT","NAMEPLATES"),
				"tooltipText", L("TOOLTIP","NAMEPLATES"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "NamePlates"
			},
			{
				"text", L("TEXT","ATTACHTOP"),
				"tooltipTitle", L("TEXT","ATTACHTOP"),
				"tooltipText", L("TOOLTIP","ATTACHTOP"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "AttachTop"
			},
			{
				"text", L("TEXT","TOT"),
				"tooltipTitle", L("TEXT","TOT"),
				"tooltipText", L("TOOLTIP","TOT"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "TargetTarget"
			},
			{
				"text", L("TEXT","TOTOT"),
				"tooltipTitle", L("TEXT","TOTOT"),
				"tooltipText", L("TOOLTIP","TOTOT"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "TargetTargetTarget"
			},
			{
				"text", L("TEXT","HOVERMSG"),
				"tooltipTitle", L("TEXT","HOVERMSG"),
				"tooltipText", L("TOOLTIP","HOVERMSG"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "HoverMsg"
			},
			{
				"text", L("TEXT","HOVERDELAY"),
				"tooltipTitle", L("TEXT","HOVERDELAY"),
				"tooltipText", L("TOOLTIP","HOVERDELAY"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderMin", 0,
				"sliderMax", 5,
				"sliderMinText", "Instant",
				"sliderMaxText", "5s",
				"sliderStep", 0.5,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "HoverDelay"
			},
		},
		["L2_fade"] = {
			{
				"text", L("TEXT","FADE_FULL"),
				"tooltipTitle", L("TEXT","FADE_FULL"),
				"tooltipText", L("TOOLTIP","FADE_FULL"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderStep", 0.01,
				"sliderIsPercent", true,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "FadeFull"
			},
			{
				"text", L("TEXT","FADE_OOC"),
				"tooltipTitle", L("TEXT","FADE_OOC"),
				"tooltipText", L("TOOLTIP","FADE_OOC"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderStep", 0.01,
				"sliderIsPercent", true,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "FadeOOC"
			},
			{
				"text", L("TEXT","FADE_IC"),
				"tooltipTitle", L("TEXT","FADE_IC"),
				"tooltipText", L("TOOLTIP","FADE_IC"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderStep", 0.01,
				"sliderIsPercent", true,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "FadeIC"
			},
		},
		["L2_misc"] = {
			{
				"text", L("TEXT","WIDTH"),
				"tooltipTitle", L("TEXT","WIDTH"),
				"tooltipText", L("TOOLTIP","WIDTH"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderMin", 30,
				"sliderMax", 100,
				"sliderStep", 1,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "Width"
			},
			{
				"text", L("TEXT","YLOC"),
				"tooltipTitle", L("TEXT","YLOC"),
				"tooltipText", L("TOOLTIP","YLOC"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderMin", -50,
				"sliderMax", 200,
				"sliderStep", 1,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "YLoc"
			},
			{
				"text", L("TEXT","SCALE"),
				"tooltipTitle", L("TEXT","SCALE"),
				"tooltipText", L("TOOLTIP","SCALE"),
				"hasArrow", true,
				"hasSlider", true,
				"sliderStep", 0.01,
				"sliderMax", 2,
				"sliderIsPercent", true,
				"sliderValue", 0,
				"sliderFunc", ArcHUD.modDB,
				"sliderArg1", "set",
				"sliderArg2", "Scale"
			},
			{
				"text", L("TEXT","RINGVIS"),
				"tooltipTitle", L("TEXT","RINGVIS"),
				"tooltipText", L("TOOLTIP","RINGVIS"),
				"hasArrow", true,
				"value", "L3_ringvis"
			},
			{
				"text", L("TEXT","MINIMAP"),
				"tooltipTitle", L("TEXT","MINIMAP"),
				"tooltipText", L("TOOLTIP","MINIMAP"),
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "toggle",
				"arg2", "MinimapIcon"
			},
		},
		["L3_ringvis"] = {
			{
				"text", L("TEXT","RINGVIS_1"),
				"tooltipTitle", L("TEXT","RINGVIS_1"),
				"tooltipText", L("TOOLTIP","RINGVIS_1"),
				"isRadio", true,
				"checked", true,
				"func", ArcHUD.modDB,
				"arg1", "set",
				"arg2", "RingVisibility",
				"arg3", 1
			},
			{
				"text", L("TEXT","RINGVIS_2"),
				"tooltipTitle", L("TEXT","RINGVIS_2"),
				"tooltipText", L("TOOLTIP","RINGVIS_2"),
				"isRadio", true,
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "set",
				"arg2", "RingVisibility",
				"arg3", 2
			},
			{
				"text", L("TEXT","RINGVIS_3"),
				"tooltipTitle", L("TEXT","RINGVIS_3"),
				"tooltipText", L("TOOLTIP","RINGVIS_3"),
				"isRadio", true,
				"checked", false,
				"func", ArcHUD.modDB,
				"arg1", "set",
				"arg2", "RingVisibility",
				"arg3", 3
			},
		},
	}

	-- Taken from Moog_Hud
	self.RepColor = { "FF4444", "DD4444", "DD7744", "BB9944", "44DD44", "55EE44", "66FF44"}

	self:LevelDebug(3, "Registering timers")
	self:RegisterMetro("UpdatePetNamePlate", self.UpdatePetNamePlate, 2, self)
	self:RegisterMetro("UpdateTargetTarget", self.UpdateTargetTarget, 1, self)
	self:RegisterMetro("CheckNamePlateMouseOver", self.CheckNamePlateMouseOver, 0.1, self)

	self:LevelDebug(3, "Setting up TargetHUD globals")
	self.TargetHUD = _G["ArcTargetHUD"]
	self.TargetHUD.frame = "ArcTargetHUD"
	self.TargetHUD.Name = _G[self.TargetHUD.frame.."Name"]
	self.TargetHUD.Level = _G[self.TargetHUD.frame.."Level"]
	self.TargetHUD.HPText = _G[self.TargetHUD.frame.."HPText"]
	self.TargetHUD.MPText = _G[self.TargetHUD.frame.."MPText"]
	self.TargetHUD.PVPIcon = _G[self.TargetHUD.frame.."PVPIcon"]
	self.TargetHUD.MLIcon = _G[self.TargetHUD.frame.."MLIcon"]
	self.TargetHUD.LeaderIcon = _G[self.TargetHUD.frame.."LeaderIcon"]
	self.TargetHUD.RaidTargetIcon = _G[self.TargetHUD.frame.."RaidTargetIcon"]
	self.TargetHUD.Combo = _G["ArcHUDFrameCombo"]
	self.TargetHUD.Model = _G["ArcPlayerModelFrame"]

	self.TargetHUD.Target = _G[self.TargetHUD.frame.."Target"]
	self.TargetHUD.Target.frame = self.TargetHUD.frame.."Target"
	self.TargetHUD.Target.Name = _G[self.TargetHUD.Target.frame.."Name"]
	self.TargetHUD.Target.HPText = _G[self.TargetHUD.Target.frame.."HPText"]
	self.TargetHUD.Target.MPText = _G[self.TargetHUD.Target.frame.."MPText"]

	self.TargetHUD.TargetTarget = _G[self.TargetHUD.frame.."TargetTarget"]
	self.TargetHUD.TargetTarget.frame = self.TargetHUD.frame.."TargetTarget"
	self.TargetHUD.TargetTarget.Name = _G[self.TargetHUD.TargetTarget.frame.."Name"]
	self.TargetHUD.TargetTarget.HPText = _G[self.TargetHUD.TargetTarget.frame.."HPText"]
	self.TargetHUD.TargetTarget.MPText = _G[self.TargetHUD.TargetTarget.frame.."MPText"]

	-- Buff and debuff buttons (were 32 XML blocks; same names, sizes and anchors)
	self:CreateAuraButtons()
	-- Same layout, drawn by Blizzard while auras are restricted (combat)
	self:CreateAuraContainers()

	self:LevelDebug(3, "Setting up NamePlate globals")
	self.NamePlates = {}
	-- Player clickable nameplate
	self.NamePlates.Player = _G["ArcHUDFramePlayerNamePlate"]
	self.NamePlates.Player.frame = "ArcHUDFramePlayerNamePlate"
	self.NamePlates.Player.unit = "player"
	self.NamePlates.Player.Text = _G[self.NamePlates.Player.frame.."Text"]

	-- Pet clickable nameplate
	self.NamePlates.Pet = _G["ArcHUDFramePetNamePlate"]
	self.NamePlates.Pet.frame = "ArcHUDFramePetNamePlate"
	self.NamePlates.Pet.unit = "pet"
	self.NamePlates.Pet.Text = _G[self.NamePlates.Pet.frame.."Text"]

	-- Target clickable nameplate
	self.NamePlates.Target = _G[self.TargetHUD.frame.."NamePlate"]
	self.NamePlates.Target.frame = self.TargetHUD.frame.."NamePlate"
	self.NamePlates.Target.unit = "target"

	-- Targettarget clickable nameplate
	self.NamePlates.TargetTarget = _G[self.TargetHUD.frame.."TargetNamePlate"]
	self.NamePlates.TargetTarget.frame = self.TargetHUD.frame.."TargetNamePlate"
	self.NamePlates.TargetTarget.unit = "targettarget"

	-- Targettargettarget clickable nameplate
	self.NamePlates.TargetTargetTarget = _G[self.TargetHUD.frame.."TargetTargetNamePlate"]
	self.NamePlates.TargetTargetTarget.frame = self.TargetHUD.frame.."TargetTargetNamePlate"
	self.NamePlates.TargetTargetTarget.unit = "targettargettarget"

	self:LevelDebug(3, "Initializing nameplates")
	self:InitNamePlate("Target")
	self:InitNamePlate("TargetTarget")
	self:InitNamePlate("TargetTargetTarget")
	self:InitNamePlate("Player")
	self:InitNamePlate("Pet")

	-- Update fonts for locale
	self:LevelDebug(3, "Updating fonts for locale")
	self:UpdateFonts(self.TargetHUD)
	self:UpdateFonts(self.NamePlates)

	self.TargetHUD.PVPIcon:GetParent():SetScale(0.6)
	self.TargetHUD.RaidTargetIcon:GetParent():SetScale(0.75)

	self:TriggerEvent("ARCHUD_LOADED")
	self:LevelDebug(2, "ArcHUD has been initialized.")
end

function ArcHUD:CreateAuraButtons()
	local hud = self.TargetHUD
	local prefix = hud.frame
	for _, kind in ipairs({"Buff", "DeBuff"}) do
		for i = 1, 16 do
			local b = CreateFrame("Button", prefix..kind..i, hud, "ArcHUDAuraTemplate")
			b:SetID(i)
			b:Hide()
			if kind == "Buff" then
				if i == 1 then
					b:SetPoint("TOPRIGHT", hud.HPText, "BOTTOMRIGHT", 0, -2)
				elseif i == 9 then
					b:SetPoint("TOPRIGHT", _G[prefix.."Buff1"], "BOTTOMRIGHT", 0, -1)
				else
					b:SetPoint("RIGHT", _G[prefix.."Buff"..(i-1)], "LEFT", -1, 0)
				end
			else
				b.isdebuff = 1
				if i == 1 then
					b:SetPoint("TOPLEFT", hud.MPText, "BOTTOMLEFT", 0, -2)
				elseif i == 9 then
					b:SetPoint("TOPLEFT", _G[prefix.."DeBuff1"], "BOTTOMLEFT", 0, -1)
				else
					b:SetPoint("LEFT", _G[prefix.."DeBuff"..(i-1)], "RIGHT", -1, 0)
				end
			end
		end
	end
end

function ArcHUD:OnEnable()
	-- All module namespaces exist by now (module OnInitialize ran at ADDON_LOADED)
	self:ValidateSettings()

	self:LevelDebug(3, "Registering events")
	-- PLAYER_COMBO_POINTS no longer exists: combo points come with the player's power events
	if not self.comboWatcher then
		self.comboWatcher = CreateFrame("Frame")
		self.comboWatcher:SetScript("OnEvent", function() ns.SafeCall(ArcHUD.UpdateComboText, ArcHUD) end)
	end
	self.comboWatcher:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	self.comboWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_ENTERING_WORLD",	"EventHandler")

	self:RegisterEvent("PLAYER_ENTER_COMBAT",	"CombatStatus")
	self:RegisterEvent("PLAYER_LEAVE_COMBAT", 	"CombatStatus")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", 	"CombatStatus")
	self:RegisterEvent("PLAYER_REGEN_DISABLED",	"CombatStatus")
	self:RegisterEvent("PET_ATTACK_START",		"CombatStatus")
	self:RegisterEvent("PET_ATTACK_STOP",		"CombatStatus")

	self:RegisterEvent("UNIT_FACTION",			"OnUnitFaction")
	self:RegisterEvent("GROUP_ROSTER_UPDATE",	"OnGroupRosterUpdate")

	self:RegisterEvent("RAID_TARGET_UPDATE",	"UpdateRaidTargetIcon")

	self:RegisterEvent("PLAYER_FLAGS_CHANGED")

	self:OnProfileEnable()

	self.Enabled = true

	ArcHUDFrame:Show()
	self:LevelDebug(3, "Triggering ring enable event")
	self:TriggerEvent("ARCHUD_MODULE_ENABLE")
	self:LevelDebug(2, "ArcHUD is now enabled")
end

function ArcHUD:OnDisable()
	self:LevelDebug(3, "Triggering ring disable event")
	self:TriggerEvent("ARCHUD_MODULE_DISABLE")

	-- Hide frame
	ArcHUDFrame:Hide()

	self.Enabled = false
	self:LevelDebug(2, "ArcHUD is now disabled")
end

-- Secure nameplates: show only while their unit exists (state driver works in combat)
local function SetPlateWatched(plate, enabled)
	ns.RunOutOfCombat("plateWatch_"..plate.unit, function()
		if enabled then
			RegisterUnitWatch(plate)
		else
			UnregisterUnitWatch(plate)
			plate:Hide()
		end
	end)
end

function ArcHUD:OnProfileEnable()
	if(self.db.profile.BlizzPlayer and self.BlizzPlayerHidden or not self.db.profile.BlizzPlayer and not self.BlizzPlayerHidden) then
		self:HideBlizzardPlayer(self.db.profile.BlizzPlayer)
	end
	if(self.db.profile.BlizzTarget and self.BlizzTargetHidden or not self.db.profile.BlizzTarget and not self.BlizzTargetHidden) then
		self:HideBlizzardTarget(self.db.profile.BlizzTarget)
	end

	if(self.db.profile.TargetFrame) then
		self:LevelDebug(3, "Targetframe enabled. Registering unit events")
		self:RegisterUnitEvent("UNIT_HEALTH",		"EventHandler", "target")
		self:RegisterUnitEvent("UNIT_MAXHEALTH",	"EventHandler", "target")
		self:RegisterUnitEvent("UNIT_POWER_UPDATE",	"EventHandler", "target")
		self:RegisterUnitEvent("UNIT_MAXPOWER",		"EventHandler", "target")
		self:RegisterUnitEvent("UNIT_DISPLAYPOWER",	"EventHandler", "target")
		if(self.db.profile.ShowBuffs) then
			self:RegisterUnitEvent("UNIT_AURA", "TargetAuras", "target")
		else
			for i=1,16 do
				_G[self.TargetHUD.frame.."Buff"..i]:Hide()
				_G[self.TargetHUD.frame.."DeBuff"..i]:Hide()
			end
			SetContainersActive(self.TargetHUD, false)
		end
		self:RegisterEvent("PLAYER_TARGET_CHANGED",	"TargetUpdate")

		-- Show target frame if we have a target
		if(UnitExists("target")) then
			self:TargetUpdate()
		end

		self:LevelDebug(3, "Enabling TargetTarget updates")
		-- Enable Target's Target('s Target) updates
		self:StartMetro("UpdateTargetTarget")

		if(self.db.profile.AttachTop) then
			self:LevelDebug(3, "Attaching targetframe to top")
			self.TargetHUD:ClearAllPoints()
			self.TargetHUD:SetPoint("BOTTOM", self.TargetHUD:GetParent(), "TOP", 0, -100)
		else
			self:LevelDebug(3, "Attaching targetframe to bottom")
			self.TargetHUD:ClearAllPoints()
			self.TargetHUD:SetPoint("TOP", self.TargetHUD:GetParent(), "BOTTOM", 0, -50)
		end

		SetPlateWatched(self.NamePlates.Target, true)
		SetPlateWatched(self.NamePlates.TargetTarget, self.db.profile.TargetTarget)
		SetPlateWatched(self.NamePlates.TargetTargetTarget, self.db.profile.TargetTargetTarget)
	else
		self:StopMetro("UpdateTargetTarget")
		self.TargetHUD:Hide()
		SetPlateWatched(self.NamePlates.Target, false)
		SetPlateWatched(self.NamePlates.TargetTarget, false)
		SetPlateWatched(self.NamePlates.TargetTargetTarget, false)
	end

	self:LevelDebug(3, "Positioning ring anchors. Width: "..self.db.profile.Width)
	-- Position the HUD according to user settings
	if(self:HasModule("Anchors")) then
		self:GetModule("Anchors").Left:ClearAllPoints()
		self:GetModule("Anchors").Left:SetPoint("TOPLEFT", ArcHUDFrame, "TOPLEFT", 0-self.db.profile.Width, 0)
		self:GetModule("Anchors").Right:ClearAllPoints()
		self:GetModule("Anchors").Right:SetPoint("TOPLEFT", ArcHUDFrame, "TOPRIGHT", self.db.profile.Width, 0)
	end

	self:LevelDebug(3, "Position frame. YLoc: "..self.db.profile.YLoc)
	ArcHUDFrame:ClearAllPoints()
	ArcHUDFrame:SetPoint("CENTER", WorldFrame, "CENTER", 0, self.db.profile.YLoc)

	self:LevelDebug(3, "Setting scale. Scale: "..self.db.profile.Scale)
	-- Scale the HUD according to user settings.
	ArcHUDFrame:SetScale(self.db.profile.Scale)
	-- The nameplates live on UIParent now (secure frames), so they get the HUD scale directly
	for _, plate in pairs(self.NamePlates) do
		ns.RunOutOfCombat("plateScale_"..plate.unit, function()
			plate:SetScale(self.db.profile.Scale)
		end)
	end

	-- Minimap button (new in the Forever port)
	self:UpdateMinimapIcon()

	-- Set initial combat flags
	self.PlayerIsInCombat = false
	self.PlayerIsRegenOn = true
	self.PetIsInCombat = false

	self:LevelDebug(3, "Setting player name to nameplate")
	-- Set playername
	self:UpdateFaction()

	-- Enable nameplate updates
	if(self.db.profile.NamePlates) then
		self:LevelDebug(3, "Nameplates enabled. Showing frames and starting update timers")
		self:UnregisterMetro("Enable_player")
		self:UnregisterMetro("Enable_pet")
		self:RegisterMetro("Enable_player", function() self:EnableDisableNameplate("Player") end, self.db.profile.HoverDelay)
		self:RegisterMetro("Enable_pet", function() self:EnableDisableNameplate("Pet") end, self.db.profile.HoverDelay)
		ns.RunOutOfCombat("playerPlateShow", function() self.NamePlates.Player:Show() end)
		SetPlateWatched(self.NamePlates.Pet, true)
		self:StartMetro("UpdatePetNamePlate")
		self:StartMetro("CheckNamePlateMouseOver")
	else
		self:LevelDebug(3, "Nameplates not enabled.")
		self:UnregisterMetro("Enable_player")
		self:UnregisterMetro("Enable_pet")
		ns.RunOutOfCombat("playerPlateShow", function() self.NamePlates.Player:Hide() end)
		SetPlateWatched(self.NamePlates.Pet, false)
	end
end

function ArcHUD:OnProfileDisable()
	self:LevelDebug(3, "Unregistering events")
	if(self:IsEventRegistered("UNIT_HEALTH")) then
		self:UnregisterEvent("UNIT_HEALTH")
		self:UnregisterEvent("UNIT_MAXHEALTH")
		self:UnregisterEvent("UNIT_POWER_UPDATE")
		self:UnregisterEvent("UNIT_MAXPOWER")
		self:UnregisterEvent("UNIT_DISPLAYPOWER")
	end
	if(self:IsEventRegistered("UNIT_AURA")) then self:UnregisterEvent("UNIT_AURA") end
	if(self:IsEventRegistered("PLAYER_TARGET_CHANGED")) then self:UnregisterEvent("PLAYER_TARGET_CHANGED") end

	self:LevelDebug(3, "Disabling timers")
	self:StopMetro("UpdateTargetTarget")
	self:StopMetro("UpdatePetNamePlate")
	self:StopMetro("CheckNamePlateMouseOver")
	self:UnregisterMetro("Enable_player")
	self:UnregisterMetro("Enable_pet")

	self:LevelDebug(3, "Hiding frames")
	for i=1,16 do
		_G[self.TargetHUD.frame.."Buff"..i]:Hide()
		_G[self.TargetHUD.frame.."DeBuff"..i]:Hide()
	end
	self.TargetHUD:Hide()
	ns.RunOutOfCombat("playerPlateShow", function() self.NamePlates.Player:Hide() end)
	SetPlateWatched(self.NamePlates.Pet, false)
end

function ArcHUD:ResetOptionsConfirm()
	self:ResetDB()
	ns.RunOutOfCombat("profileReload", function()
		self:OnProfileDisable()
		self:OnProfileEnable()
	end)
	for _, module in ipairs(self.moduleList) do
		self:TriggerEvent("ARCHUD_MODULE_UPDATE", module.name)
	end
	self:Print(L("TEXT_RESET_CONFIRM"))
end

---------------------------------------------------------------------------
-- Clickable nameplates. The 1.12 version called TargetUnit() and opened the unit dropdown from
-- OnClick; both are protected now, so the buttons use SecureUnitButtonTemplate attributes:
-- left click targets the unit, right click opens the unit menu.
---------------------------------------------------------------------------
function ArcHUD:InitNamePlate(frame)
	local plate = self.NamePlates[frame]

	local function OnEnter(button)
		if(SpellIsTargeting and SpellIsTargeting() and SpellCanTargetUnit) then
			if (SpellCanTargetUnit(button.unit)) then
				SetCursor("CAST_CURSOR")
			else
				SetCursor("CAST_ERROR_CURSOR")
			end
		end
		GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetUnit(button.unit)
		GameTooltip:Show()
	end
	local function OnLeave(button)
		if(SpellIsTargeting and SpellIsTargeting()) then
			SetCursor("CAST_ERROR_CURSOR")
		end
		if(GameTooltip:IsOwned(button)) then
			GameTooltip:Hide()
		end
	end

	-- Secure setup must happen out of combat (only matters for a /reload during combat)
	ns.RunOutOfCombat("plateInit_"..frame, function()
		-- Move off ArcHUDFrame / ArcTargetHUD so those stay movable and hideable in combat
		plate:SetParent(UIParent)
		plate:SetFrameStrata("LOW")
		plate:RegisterForClicks("AnyUp")
		plate:SetAttribute("unit", plate.unit)
		plate:SetAttribute("*type1", "target")
		plate:SetAttribute("*type2", "togglemenu")
		plate:SetScript("OnEnter", function(button) ns.SafeCall(OnEnter, button) end)
		plate:SetScript("OnLeave", function(button) ns.SafeCall(OnLeave, button) end)
		if(frame == "Player" or frame == "Pet") then
			-- Mouse input is only enabled after hovering for HoverDelay seconds (as before)
			plate:EnableMouse(false)
		end
	end)

	if(frame ~= "Target" and frame ~= "TargetTarget" and frame ~= "TargetTargetTarget") then
		self:RegisterMetro(frame.."Alpha", ArcHUDRingTemplate.AlphaUpdate, 0.01, plate)
		self:StartMetro(frame.."Alpha")

		plate.fadeIn = 0.25
		plate.fadeOut = 0.25

		ArcHUDRingTemplate.SetRingAlpha(plate, self.db.profile.FadeFull)
	else
		plate.Enabled = true
	end
end

-- Mouse enable/disable on a secure button is protected during combat: those changes wait for combat end.
local function SetPlateMouse(plate, enabled)
	ns.RunOutOfCombat("plateMouse_"..plate.unit, function()
		plate:EnableMouse(enabled)
		plate:SetToplevel(enabled)
	end)
end

function ArcHUD:CheckNamePlateMouseOver()
	if(self.NamePlates.Player:IsMouseOver()) then
		if(not self.NamePlates.Player.Started) then
			ArcHUDRingTemplate.SetRingAlpha(self.NamePlates.Player, 1.0)
			self.NamePlates.Player.Started = true
			self:StartMetro("Enable_player")
		end
	else
		if(self.NamePlates.Player.Started) then
			ArcHUDRingTemplate.SetRingAlpha(self.NamePlates.Player, self.db.profile.FadeFull)
			self:StopMetro("Enable_player")
			self.NamePlates.Player.Started = false
			SetPlateMouse(self.NamePlates.Player, false)
		end
	end

	-- Check pet nameplate
	if(not UnitExists("pet")) then
		return
	end
	if(self.NamePlates.Pet:IsMouseOver()) then
		if(not self.NamePlates.Pet.Started) then
			ArcHUDRingTemplate.SetRingAlpha(self.NamePlates.Pet, 1.0)
			self.NamePlates.Pet.Started = true
			self:StartMetro("Enable_pet")
		end
	else
		if(self.NamePlates.Pet.Started) then
			ArcHUDRingTemplate.SetRingAlpha(self.NamePlates.Pet, self.db.profile.FadeFull)
			self:StopMetro("Enable_pet")
			self.NamePlates.Pet.Started = false
			SetPlateMouse(self.NamePlates.Pet, false)
		end
	end
end

function ArcHUD:EnableDisableNameplate(unit)
	self:StopMetro("Enable_"..string.lower(unit))
	if InCombatLockdown() then
		-- Cannot enable a secure button's mouse input in combat; hover again afterwards
		return
	end
	SetPlateMouse(self.NamePlates[unit], true)
	if(self.db.profile.HoverMsg) then
		self:Print("Enabling mouse input for "..unit)
	end
end

---------------------------------------------------------------------------
-- Target HUD
---------------------------------------------------------------------------

-- PlayerModel:SetUnit needs a declassified unit identity; in restricted content it can refuse.
function ArcHUD:RefreshTargetModel(model)
	if not model:IsShown() then return end
	if not pcall(model.SetUnit, model, "target") then
		model:Hide()
	end
end

-- Readable level/classification helpers (fall back to "unknown" if Blizzard ever marks them secret)
local function TargetLevel()
	local level = UnitLevel("target")
	if Readable(level) then return level end
	return nil
end

function ArcHUD:TargetUpdate()
	-- Make sure we are targeting someone and that ArcHUD is enabled
	if (UnitExists("target") and self.db.profile.TargetFrame) then
		local isPlayer = IsTrue(UnitIsPlayer("target"))
		-- 3D target model
		if((self.db.profile.PlayerModel and isPlayer) or (self.db.profile.MobModel and not isPlayer)) then
			self.TargetHUD.Model:Show()
			self:RefreshTargetModel(self.TargetHUD.Model)
		else
			self.TargetHUD.Model:Hide()
		end
		self.TargetHUD:Show()

		if(IsTrue(UnitIsDead("target")) or IsTrue(UnitIsGhost("target"))) then
			self.TargetHUD.HPText:SetText("Dead")
		else
			-- MobHealth2/3 / MobInfo-2 support removed: the client reports real target health now
			self.TargetHUD.HPText:SetText(ns.ValueText(UnitHealth("target"), UnitHealthMax("target")))
		end

		-- Does the unit have mana? If so we want to show it
		local mpMax = UnitPowerMax("target")
		if (not Readable(mpMax) or mpMax > 0) then
			self.TargetHUD.MPText:SetText(ns.ValueText(UnitPower("target"), mpMax))
		else
			self.TargetHUD.MPText:SetText(" ")
		end

		local addtolevel = ""
		if(self.db.profile.ShowClass) then
			addtolevel = " " .. ((isPlayer and UnitClass("target")) or UnitCreatureFamily("target") or UnitCreatureType("target") or "")
			self.TargetHUD.Level:SetJustifyH("CENTER")
		else
			self.TargetHUD.Level:SetJustifyH("LEFT")
		end
		-- What kind of target is it? If UnitLevel returns negative we have a target whose
		--   level are too high to show or a boss
		local level = TargetLevel()
		local classification = UnitClassification("target")
		if not Readable(classification) then classification = "normal" end
		if (not level or level < 0) then
			if ( classification == "worldboss" ) then
				self.TargetHUD.Level:SetText("Boss" .. addtolevel)
			else
				self.TargetHUD.Level:SetText("L??" .. addtolevel)
			end
		else
			-- Make sure we mark elites with a + after the level
			if(not string.find(classification, "elite")) then
				self.TargetHUD.Level:SetText("L" .. level .. addtolevel)
			else
				self.TargetHUD.Level:SetText("L" .. level .. "+" .. addtolevel)
			end
		end

		-- Check if the target is friendly to the player
		local targetfriend = IsTrue(UnitIsFriend("player","target"))
		local playerLevel = UnitLevel("player")

		-- Color the level display based on the targets level in relation
		--  to player level
		if (targetfriend) then
			self.TargetHUD.Level:SetTextColor(1, 0.9, 0)
		elseif (IsTrue(UnitIsTrivial("target"))) then
			self.TargetHUD.Level:SetTextColor(0.7, 0.7, 0.7)
		elseif (not level or level == -1) then
			self.TargetHUD.Level:SetTextColor(1, 0, 0)
		elseif (level <= (playerLevel-3)) then
			self.TargetHUD.Level:SetTextColor(0, 0.9, 0)
		elseif (level >= (playerLevel+5)) then
			self.TargetHUD.Level:SetTextColor(1, 0, 0)
		elseif (level >= (playerLevel+3)) then
			self.TargetHUD.Level:SetTextColor(1, 0.5, 0)
		else
			self.TargetHUD.Level:SetTextColor(1, 0.9, 0)
		end

		-- Color the targets hp and mana text correctly
		local info
		if (UnitPowerType("target") == 0) then
			info = { r = 0.00, g = 1.00, b = 1.00 }
		else
			info = ns.GetPowerColor(UnitPowerType("target"))
		end
		self.TargetHUD.MPText:SetTextColor(info.r, info.g, info.b)

		if(targetfriend) then
			self.TargetHUD.HPText:SetTextColor(0, 1, 0)
		else
			self.TargetHUD.HPText:SetTextColor(1, 0, 0)
		end

		-- The name of the target should be colored differently if it's a player or if
		--   it's a mob
		local _, class = UnitClass("target")
		local color = Readable(class) and self.ClassColor[class]
		if (color and isPlayer) then
			-- Is target in a guild?
			local guild = GetGuildInfo("target")

			-- Color the target name based on class since we have a player targeted
			if(guild and ArcHUD.db.profile.ShowGuild) then
				self.TargetHUD.Name:SetText("|cff"..color..UnitName("target").." <"..guild..">".."|r")
			else
				self.TargetHUD.Name:SetText("|cff"..color..UnitName("target").."|r")
			end
		else
			-- Color the target name based on reaction (red to green) since we have a
			--   mob targeted
			local reactionIndex = UnitReaction("target","player")
			local reaction = Readable(reactionIndex) and self.RepColor[reactionIndex]
			if(reaction) then
				self.TargetHUD.Name:SetText("|cff"..reaction..UnitName("target").."|r")
			else
				self.TargetHUD.Name:SetText(UnitName("target"))
			end
		end

		if(self.db.profile.ShowBuffs) then
			-- Update buffs and debuffs for the target
			self:TargetAuras()
		end

		self:UpdateFaction("target")
		self:UpdateRaidTargetIcon()
		self:PLAYER_FLAGS_CHANGED(nil, "target")

		if(self.BlizzTargetHidden) then
			if(IsTrue(UnitIsEnemy("target", "player"))) then
				PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT)
			elseif(targetfriend) then
				PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT)
			else
				PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
			end
		end
	else
		-- We didn't have anything targeted or ArcHUD is disabled so lets hide the
		--   target frame again
		if(self.BlizzTargetHidden) then
			PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT)
		end
		self.TargetHUD:Hide()
	end
end

function ArcHUD:OnUnitFaction(event, unit)
	-- The original only reacted to the player's own faction changes here
	if(unit and unit ~= "player") then return end
	self:UpdateFaction("player")
end

function ArcHUD:OnGroupRosterUpdate()
	self:UpdateFaction()
end

function ArcHUD:UpdateFaction(unit)
	self:LevelDebug(2, "UpdateFaction: unit = %s", unit or "nil")

	if(unit and unit == "target") then
		local factionGroup = UnitFactionGroup("target")
		if(IsTrue(UnitIsPVPFreeForAll("target"))) then
			self.TargetHUD.PVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
			self.TargetHUD.PVPIcon:Show()
		elseif(Readable(factionGroup) and factionGroup and factionGroup ~= "Neutral" and IsTrue(UnitIsPVP("target"))) then
			self.TargetHUD.PVPIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-"..factionGroup)
			self.TargetHUD.PVPIcon:Show()
		else
			self.TargetHUD.PVPIcon:Hide()
		end
	else
		local factionGroup = UnitFactionGroup("player")
		local _, class = UnitClass("player")
		local color = self.ClassColor[class]
		if(UnitIsPVPFreeForAll("player")) then
			self.NamePlates.Player.Text:SetText("|cffffff00[FFA] |cff"..(color or "ffffff")..(UnitName("player") or "Unknown Entity").."|r")
		elseif(factionGroup and UnitIsPVP("player")) then
			self.NamePlates.Player.Text:SetText("|cffff0000[PVP] |cff"..(color or "ffffff")..(UnitName("player") or "Unknown Entity").."|r")
		else
			self.NamePlates.Player.Text:SetText("|cff"..(color or "ffffff")..(UnitName("player") or "Unknown Entity").."|r")
		end
	end
end

function ArcHUD:UpdateRaidTargetIcon()
	if(not UnitExists("target")) then self.TargetHUD.RaidTargetIcon:Hide() return end

	local index = GetRaidTargetIndex("target")
	if(Readable(index) and index) then
		SetRaidTargetIconTexture(self.TargetHUD.RaidTargetIcon, index)
		self.TargetHUD.RaidTargetIcon:Show()
	else
		self.TargetHUD.RaidTargetIcon:Hide()
	end
end

function ArcHUD:PLAYER_FLAGS_CHANGED(event, unit)
	if(not UnitExists("target")) then self.TargetHUD.LeaderIcon:Hide() return end

	if(unit == "target") then
		if(IsTrue(UnitIsGroupLeader("target"))) then
			self.TargetHUD.LeaderIcon:Show()
		else
			self.TargetHUD.LeaderIcon:Hide()
		end
	end
end

-- Dispel type ids (spell dispel types) -> 1.12 debuff border colors, for secret aura data
local dispelColorCurve
local function GetDispelColorCurve()
	if not dispelColorCurve and C_CurveUtil and C_CurveUtil.CreateColorCurve then
		dispelColorCurve = C_CurveUtil.CreateColorCurve()
		dispelColorCurve:SetType(Enum.LuaCurveType.Step)
		local function add(x, c) dispelColorCurve:AddPoint(x, CreateColor(c.r, c.g, c.b, 1)) end
		add(0, DebuffTypeColor.none)
		add(1, DebuffTypeColor.Magic)
		add(2, DebuffTypeColor.Curse)
		add(3, DebuffTypeColor.Disease)
		add(4, DebuffTypeColor.Poison)
		add(5, DebuffTypeColor.none)
	end
	return dispelColorCurve
end

---------------------------------------------------------------------------
-- Restricted aura display. While target auras are restricted (combat), C_UnitAuras calls from addon
-- code raise "Auras cannot be accessed when secret". Blizzard's AuraContainer displays them instead;
-- it is styled like the original 16+16 buttons (same size, border, count, 8 per row, same spacing).
---------------------------------------------------------------------------
local containerDispelColors = {
	None = CreateColor(DebuffTypeColor.none.r, DebuffTypeColor.none.g, DebuffTypeColor.none.b),
	Magic = CreateColor(DebuffTypeColor.Magic.r, DebuffTypeColor.Magic.g, DebuffTypeColor.Magic.b),
	Curse = CreateColor(DebuffTypeColor.Curse.r, DebuffTypeColor.Curse.g, DebuffTypeColor.Curse.b),
	Disease = CreateColor(DebuffTypeColor.Disease.r, DebuffTypeColor.Disease.g, DebuffTypeColor.Disease.b),
	Poison = CreateColor(DebuffTypeColor.Poison.r, DebuffTypeColor.Poison.g, DebuffTypeColor.Poison.b),
}

-- 8 icons of 16px with 1px overlap per row, like the original XML anchors
local AURA_ROW_WIDTH = 8 * 16 - 7 + 0.5

local function CreateTargetAuraContainer(parent, isDebuff)
	local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	container:SetSize(1, 1)
	container:AddAuraGroup(isDebuff and "debuffs" or "buffs", isDebuff and "HARMFUL" or "HELPFUL", {
		maxFrameCount = 16,
		templateNames = { "ArcHUDContainerAuraTemplate" },
		initializeFrame = function(button)
			button:SetIcon(button.Icon)
			if isDebuff then
				button:SetApplicationCount(button.Count)
				button:AddDispelTypeTexture(button.Border, {
					style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
					showWhenHarmful = true,
					showWithoutDispelType = true,
					customDispelColorMap = containerDispelColors,
				})
			end
		end,
		layout = { elementSpacing = -1, lineSpacing = 1 },
	})
	container:SetFlowLayoutMaximumLineSize(AURA_ROW_WIDTH)
	if isDebuff then
		-- Debuffs grow right from below the power text
		container:SetFlowLayoutAnchorPoint("TOPLEFT")
		container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
		container:SetPoint("TOPLEFT", ArcHUD.TargetHUD.MPText, "BOTTOMLEFT", 0, -2)
	else
		-- Buffs grow left from below the health text
		container:SetFlowLayoutAnchorPoint("TOPRIGHT")
		container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Left, AnchorUtil.FlowDirection.Down)
		container:SetPoint("TOPRIGHT", ArcHUD.TargetHUD.HPText, "BOTTOMRIGHT", 0, -2)
	end
	container:SetUnit("target")
	container:SetEnabled(false)
	container:Hide()
	return container
end

function ArcHUD:CreateAuraContainers()
	if not C_Secrets then return end
	local ok = ns.SafeCall(function()
		self.TargetHUD.BuffContainer = CreateTargetAuraContainer(self.TargetHUD, false)
		self.TargetHUD.DebuffContainer = CreateTargetAuraContainer(self.TargetHUD, true)
	end)
	if not ok then
		self.TargetHUD.BuffContainer, self.TargetHUD.DebuffContainer = nil, nil
	end
end

-- True when reading the target's auras from addon code would be refused
local function TargetAurasRestricted(unit)
	local secrets = C_Secrets
	if not secrets then return false end
	local restricted
	if secrets.ShouldUnitAuraIndexBeSecret then
		restricted = secrets.ShouldUnitAuraIndexBeSecret(unit, 1, "HELPFUL") or secrets.ShouldUnitAuraIndexBeSecret(unit, 1, "HARMFUL")
	elseif secrets.ShouldAurasBeSecret then
		restricted = secrets.ShouldAurasBeSecret()
	end
	if issecretvalue and issecretvalue(restricted) then
		return true
	end
	return restricted and true or false
end

SetContainersActive = function(hud, active)
	for _, container in ipairs({ hud.BuffContainer, hud.DebuffContainer }) do
		if container then
			container:SetEnabled(active)
			container:SetShown(active)
		end
	end
end

-- 1.12 UnitBuff/UnitDebuff replaced by C_UnitAuras. Aura fields may be secret during restrictions;
-- they only go into widget setters (icon file id, formatted stack count, dispel color).
function ArcHUD:TargetAuras()
	local frame = self.TargetHUD.frame
	local unit = "target"

	if TargetAurasRestricted(unit) then
		-- Hand the display to Blizzard's AuraContainer; never call C_UnitAuras here
		for i = 1, 16 do
			_G[frame.."Buff"..i]:Hide()
			_G[frame.."DeBuff"..i]:Hide()
		end
		SetContainersActive(self.TargetHUD, true)
		return
	end
	SetContainersActive(self.TargetHUD, false)

	local getAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex

	for i = 1, 16 do
		local button = _G[frame.."Buff"..i]
		local aura = getAura and getAura(unit, i, "HELPFUL")
		if (aura) then
			button.Icon:SetTexture(aura.icon)
			button.auraInstanceID = aura.auraInstanceID
			button.unit = unit
			button:Show()
		else
			button.auraInstanceID = nil
			button:Hide()
		end
	end

	for i = 1, 16 do
		local button = _G[frame.."DeBuff"..i]
		local aura = getAura and getAura(unit, i, "HARMFUL")
		if (aura) then
			button.Icon:SetTexture(aura.icon)
			button.auraInstanceID = aura.auraInstanceID
			button.unit = unit
			button.isdebuff = 1
			button:Show()
			button.Border:Show()

			local dispelName = aura.dispelName
			if not (issecretvalue and issecretvalue(dispelName)) then
				local color = DebuffTypeColor[dispelName or "none"] or DebuffTypeColor.none
				button.Border:SetVertexColor(color.r, color.g, color.b)
			else
				local curve = GetDispelColorCurve()
				local r, g, b = ArcHUDRingTemplate.UnpackCurveColor(curve and C_UnitAuras.GetAuraDispelTypeColor(unit, aura.auraInstanceID, curve))
				if r then
					button.Border:SetVertexColor(r, g, b)
				else
					button.Border:SetVertexColor(DebuffTypeColor.none.r, DebuffTypeColor.none.g, DebuffTypeColor.none.b)
				end
			end

			-- Empty string below 2 stacks, like the original "> 1" check
			button.Count:SetText(C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2))
			button.Count:Show()
		else
			button.auraInstanceID = nil
			button:Hide()
		end
	end
end

local SetAuraTooltipImpl

-- Called from the XML OnEnter script; errors go to the ArcHUD error log
function ArcHUD:SetAuraTooltip(button)
	ns.SafeCall(SetAuraTooltipImpl, button)
end

SetAuraTooltipImpl = function(button)
	if (not button:IsVisible() or not button.auraInstanceID) then return end
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
	local unit = button.unit
	if (button.isdebuff == 1) then
		GameTooltip:SetUnitDebuffByAuraInstanceID(unit, button.auraInstanceID)
	else
		GameTooltip:SetUnitBuffByAuraInstanceID(unit, button.auraInstanceID)
	end
end

function ArcHUD:UpdateComboText()
	local points = GetComboPoints("player", "target")
	if not Readable(points) then
		self.TargetHUD.Combo:SetText(points)
	elseif (points > 0) then
		self.TargetHUD.Combo:SetText(points)
	else
		self.TargetHUD.Combo:SetText("")
	end
end

function ArcHUD:EventHandler(event, unit)
	if (event == "UNIT_DISPLAYPOWER") then
		if (unit == "target") then
			local info
			if (UnitPowerType(unit) == 0) then
				info = { r = 0.00, g = 1.00, b = 1.00 }
			else
				info = ns.GetPowerColor(UnitPowerType(unit))
			end
			self.TargetHUD.MPText:SetTextColor(info.r, info.g, info.b)
		end
	elseif (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") then
		if (unit == "target") then
			self.TargetHUD.HPText:SetText(ns.ValueText(UnitHealth(unit), UnitHealthMax(unit)))
		end
	elseif(event == "PLAYER_ENTERING_WORLD") then
		self.PlayerIsInCombat = false
		self.PlayerIsRegenOn = true
	else
		if (unit == "target") then
			self.TargetHUD.MPText:SetText(ns.ValueText(UnitPower(unit), UnitPowerMax(unit)))
		end
	end
end

function ArcHUD:CombatStatus(event)
	self:LevelDebug(2, "CombatStatus: event = " .. event)
	if(event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_REGEN_DISABLED") then
		self.PlayerIsInCombat = true
		if(event == "PLAYER_REGEN_DISABLED") then
			self.PlayerIsRegenOn = false
		end
	elseif(event == "PLAYER_LEAVE_COMBAT" or event == "PLAYER_REGEN_ENABLED") then
		if(event == "PLAYER_LEAVE_COMBAT" and self.PlayerIsRegenOn) then
			self.PlayerIsInCombat = false
		elseif(event == "PLAYER_REGEN_ENABLED") then
			self.PlayerIsInCombat = false
			self.PlayerIsRegenOn = true
		end
	elseif(event == "PET_ATTACK_START") then
		self.PetIsInCombat = true
	elseif(event == "PET_ATTACK_STOP") then
		self.PetIsInCombat = false
	end

	-- Aura restrictions start and end with combat: switch between the own buttons and the AuraContainer
	if(event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED") then
		if(self.db.profile.TargetFrame and self.db.profile.ShowBuffs and UnitExists("target")) then
			self:TargetAuras()
		end
	end
end

local function GetPetHappinessCompat()
	if C_PetInfo and C_PetInfo.GetPetHappiness then
		return C_PetInfo.GetPetHappiness()
	elseif GetPetHappiness then
		return GetPetHappiness()
	end
end

function ArcHUD:UpdatePetNamePlate()
	-- Show/hide is driven by RegisterUnitWatch now (secure button)
	if(UnitExists("pet")) then
		local happiness = GetPetHappinessCompat()
		local color
		if(happiness == 1) then
			color = "ff0000"
			happiness = " :("
		elseif(happiness == 2) then
			color = "ffff00"
			happiness = " :||"
		elseif(happiness == 3) then
			color = "00ff00"
			happiness = " :)"
		else
			color = "ffffff"
			happiness = ""
		end
		self.NamePlates.Pet.Text:SetText("|cff"..color..(UnitName("pet") or "").." "..happiness.."|r")
	end
end

local function UpdateSmallTarget(self, hud, unit)
	local _, class = UnitClass(unit)
	local color = Readable(class) and self.ClassColor[class]
	if (color and IsTrue(UnitIsPlayer(unit))) then
		hud.Name:SetText("|cff"..color..UnitName(unit).."|r")
	else
		local reactionIndex = UnitReaction(unit, "player")
		local reaction = Readable(reactionIndex) and self.RepColor[reactionIndex]
		if(reaction) then
			hud.Name:SetText("|cff"..reaction..UnitName(unit).."|r")
		else
			hud.Name:SetText(UnitName(unit))
		end
	end

	local info
	if (UnitPowerType(unit) == 0) then
		info = { r = 0.00, g = 1.00, b = 1.00 }
	else
		info = ns.GetPowerColor(UnitPowerType(unit))
	end
	hud.MPText:SetTextColor(info.r, info.g, info.b)

	if(IsTrue(UnitIsFriend("player", unit))) then
		hud.HPText:SetTextColor(0, 1, 0)
	else
		hud.HPText:SetTextColor(1, 0, 0)
	end
	if(IsTrue(UnitIsDead(unit)) or IsTrue(UnitIsGhost(unit))) then
		hud.HPText:SetText("Dead")
	else
		hud.HPText:SetText(ns.PercentText(UnitHealth(unit), UnitHealthMax(unit),
			function(curve) return UnitHealthPercent(unit, true, curve) end))
	end

	local mpMax = UnitPowerMax(unit)
	if (not Readable(mpMax) or mpMax > 0) then
		hud.MPText:SetText(ns.PercentText(UnitPower(unit), mpMax,
			function(curve) return UnitPowerPercent(unit, nil, false, curve) end))
	else
		hud.MPText:SetText(" ")
	end
	hud:Show()
end

function ArcHUD:UpdateTargetTarget()
	-- Handle Target's Target
	if(UnitExists("targettarget") and self.db.profile.TargetTarget) then
		UpdateSmallTarget(self, self.TargetHUD.Target, "targettarget")
	else
		self.TargetHUD.Target:Hide()
	end

	-- Handle Target's Target's Target
	if(UnitExists("targettargettarget") and self.db.profile.TargetTargetTarget) then
		UpdateSmallTarget(self, self.TargetHUD.TargetTarget, "targettargettarget")
	else
		self.TargetHUD.TargetTarget:Hide()
	end
end

-- Only walk ArcHUD's own tables and frames, never into Blizzard frames referenced from them
local function IsOwnTable(v)
	if not v.GetObjectType then
		return true
	end
	local name = v.GetName and v:GetName()
	return name ~= nil and string.sub(name, 1, 3) == "Arc"
end

function ArcHUD:UpdateFonts(tbl, visited)
	visited = visited or {}
	if visited[tbl] then return end
	visited[tbl] = true
	local localeFont = L("FONT")
	local update = false
	for _, v in pairs(tbl) do
		if(type(v) == "table" and not visited[v]) then
			if(v.GetObjectType and v:GetObjectType() == "FontString") then
				visited[v] = true
				local fontName, fontSize, fontFlags = v:GetFont()
				if(fontName) then
					self:LevelDebug(2, "UpdateFonts: fontName = %s, localeFont = %s", fontName, localeFont)
				end
				if(fontName and not string.find(fontName, localeFont, 1, true)) then
					v:SetFont(ns.FontPath(localeFont), fontSize, fontFlags)
					update = true
				end
			elseif IsOwnTable(v) then
				self:UpdateFonts(v, visited)
			end
		end
	end
	if(update) then
		self:LevelDebug(3, "Fonts updated")
	end
end

---------------------------------------------------------------------------
-- Blizzard frames. BlizzPlayer / BlizzTarget = "visible". The old code unregistered every event of
-- PlayerFrame/TargetFrame, which taints secure frames now; they are reparented to a hidden frame instead.
---------------------------------------------------------------------------
function ArcHUD:HideBlizzardPlayer(visible)
	self.BlizzPlayerHidden = not visible
	ns.SetBlizzardFrameHidden(PlayerFrame, not visible)
	ns.SetBlizzardFrameHidden(PetFrame, not visible)
end

function ArcHUD:HideBlizzardTarget(visible)
	self.BlizzTargetHidden = not visible
	ns.SetBlizzardFrameHidden(TargetFrame, not visible)
	ns.SetBlizzardFrameHidden(ComboFrame, not visible)
end
