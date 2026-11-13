-- /archud config: the original Dewdrop-2.0 menu, rendered with Blizzard's Menu API (MenuUtil).
-- The menu data is still ArcHUD.dewdrop_menu (core entries from Core.lua, ring entries from
-- modulePrototype:RegisterDewdropSettings), so the structure, texts and tooltips are unchanged.
local addonName, ns = ...
local ArcHUD = ArcHUD

-- {"key", value, "key", value, ...} -> { key = value }
local function ToOptions(v)
	local o = {}
	for i = 1, #v, 2 do
		o[v[i]] = v[i+1]
	end
	return o
end

local function NamespaceProfile(namespace)
	if namespace and ArcHUD:HasModule(namespace) then
		return ArcHUD:AcquireDBNamespace(namespace).profile
	end
	return ArcHUD.db.profile
end

-- Same rules as the old createDDMenu
local function IsChecked(o)
	if o.isRadio then
		if o.arg4 ~= nil then
			return NamespaceProfile(o.arg3)[o.arg2] == o.arg4
		end
		return ArcHUD.db.profile[o.arg2] == o.arg3
	end
	return NamespaceProfile(o.arg3)[o.arg2] and true or false
end

-- Dewdrop called func(arg1, arg2, arg3, arg4), stopping at the first nil argument
local function CallFunc(func, a1, a2, a3, a4, extra)
	local args = {}
	for _, v in ipairs({a1, a2, a3, a4}) do
		args[#args + 1] = v
	end
	if extra ~= nil then args[#args + 1] = extra end
	ns.SafeCall(func, unpack(args))
end

local function AddTooltip(description, o)
	if not (o.tooltipTitle or o.tooltipText) then return end
	description:SetTooltip(function(tooltip)
		tooltip:SetText(o.tooltipTitle or o.text, 1, 0.82, 0)
		if o.tooltipText then
			tooltip:AddLine(o.tooltipText, 1, 1, 1, true)
		end
	end)
end

local pendingSlider = {}

local function CreateSlider(description, o)
	local minV = o.sliderMin or 0
	local maxV = o.sliderMax or 1
	local step = o.sliderStep or 0.01
	local key = (o.sliderArg3 or "core") .. ":" .. tostring(o.sliderArg2)

	local element = description:CreateTemplate("ArcHUDMenuSliderTemplate")
	element:AddInitializer(function(frame)
		frame.Label:SetText(o.text)

		local value = NamespaceProfile(o.sliderArg3)[o.sliderArg2] or minV
		local steps = math.max(1, math.floor((maxV - minV) / step + 0.5))

		local function format(v)
			if o.sliderIsPercent then
				return string.format("%d%%", math.floor(v * 100 + 0.5))
			elseif step < 1 then
				return string.format("%.1f", v)
			end
			return tostring(math.floor(v + 0.5))
		end
		local labels = MinimalSliderWithSteppersMixin.Label
		local formatters = { [labels.Right] = format }
		if o.sliderMinText then formatters[labels.Min] = function() return o.sliderMinText end end
		if o.sliderMaxText then formatters[labels.Max] = function() return o.sliderMaxText end end

		-- Menu frames are pooled and reused. Detach the previous slider's handlers BEFORE Init,
		-- otherwise Init's SetValue fires the old callback and writes this value into the old setting.
		local control = frame.SliderControl
		control:UnregisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, frame)
		control.Slider:SetScript("OnValueChanged", nil)
		frame.initializing = true
		control:Init(value, minV, maxV, steps, formatters)
		frame.initializing = false
		control:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, v)
			if frame.initializing then return end
			v = minV + math.floor((v - minV) / step + 0.5) * step
			-- Applying a core setting re-lays out the whole HUD; do it once the slider settles
			pendingSlider[key] = v
			C_Timer.After(0.15, function()
				local newValue = pendingSlider[key]
				if newValue == nil then return end
				pendingSlider[key] = nil
				CallFunc(o.sliderFunc, o.sliderArg1, o.sliderArg2, o.sliderArg3, o.sliderArg4, newValue)
			end)
		end, frame)
	end)
end

local function Populate(description, list)
	if not list then return end
	for _, v in ipairs(list) do
		if type(v) == "table" then
			if #v == 0 then
				description:CreateDivider()
			else
				local o = ToOptions(v)
				if o.isTitle then
					description:CreateTitle(o.text)
				elseif o.notClickable then
					local button = description:CreateButton(o.text)
					button:SetEnabled(false)
				elseif o.hasSlider then
					local sub = description:CreateButton(o.text)
					AddTooltip(sub, o)
					CreateSlider(sub, o)
				elseif o.hasArrow and o.value then
					local sub = description:CreateButton(o.text)
					AddTooltip(sub, o)
					Populate(sub, ArcHUD.dewdrop_menu[o.value])
				elseif o.isRadio then
					local radio = description:CreateRadio(o.text,
						function() return IsChecked(o) end,
						function()
							CallFunc(o.func, o.arg1, o.arg2, o.arg3, o.arg4)
							return MenuResponse.Refresh
						end)
					AddTooltip(radio, o)
				elseif o.checked ~= nil then
					local check = description:CreateCheckbox(o.text,
						function() return IsChecked(o) end,
						function()
							CallFunc(o.func, o.arg1, o.arg2, o.arg3, o.arg4)
							return MenuResponse.Refresh
						end)
					AddTooltip(check, o)
				elseif o.func then
					local button = description:CreateButton(o.text, function()
						CallFunc(o.func, o.arg1, o.arg2, o.arg3, o.arg4)
					end)
					AddTooltip(button, o)
				else
					description:CreateButton(o.text)
				end
			end
		else
			ArcHUD:LevelDebug(1, "Error in menu (table expected, got %s)", type(v))
		end
	end
end

-- Opens at the cursor, like the old Dewdrop menu
function ArcHUD:OpenConfigMenu()
	if not self.dewdrop_menu then return end
	MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
		rootDescription:SetTag("MENU_ARCHUD_CONFIG")
		Populate(rootDescription, self.dewdrop_menu["L1"])
	end)
end
