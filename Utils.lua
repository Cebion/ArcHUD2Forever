local addonName, ns = ...
local Readable = ns.Readable

function ArcHUD:SplitString(s, p, n)
	local l, sp, ep = {}, 0
	while(sp) do
		sp, ep = strfind(s, p)
		if(sp) then
			tinsert(l, strsub(s, 1, sp-1))
			s = strsub(s, ep+1)
		else
			tinsert(l, s)
			break
		end
		if(n) then n = n-1 end
		if(n and (n == 0)) then tinsert(l, s) break end
	end
	return unpack(l)
end

function ArcHUD:strcap(str)
	return strupper(strsub(str, 1, 1)) .. strlower(strsub(str, 2))
end

---------------------------------------------------------------------------
-- Port helpers
---------------------------------------------------------------------------

-- Locale font. The old zhCN font (FZLBJW.TTF) is not shipped by modern clients,
-- so any non-Latin locale font falls back to the client's standard font.
function ns.FontPath(fontFile)
	if fontFile == "FRIZQT__.TTF" or not STANDARD_TEXT_FONT then
		return "Fonts\\" .. fontFile
	end
	return STANDARD_TEXT_FONT
end

-- Percentage text, same output as floor(cur/max*100).."%".
-- pctFunc(curve) must return UnitHealthPercent/UnitPowerPercent; it is used when values are secret
-- (the client formats the secret; Lua never reads it).
function ns.PercentText(cur, max, pctFunc)
	if Readable(cur) and Readable(max) then
		if max == 0 then return "0%" end
		return floor((cur/max)*100).."%"
	end
	if pctFunc and CurveConstants and CurveConstants.ScaleTo100 then
		return string.format("%d%%", pctFunc(CurveConstants.ScaleTo100))
	end
	return ""
end

-- Value text "cur/max". Concatenating secrets is allowed and yields a secret string for SetText.
function ns.ValueText(cur, max)
	return cur .. "/" .. max
end

-- Blizzard frames ArcHUD can replace are hidden by moving them into a hidden parent (taint free;
-- PlayerFrame, PetFrame and TargetFrame are secure, so this waits until combat ends if needed).
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParents = {}

function ns.SetBlizzardFrameHidden(frame, hide)
	if not frame then return end
	local key = "blizz_" .. (frame:GetName() or tostring(frame))
	-- The player cast bar sits in Blizzard's managed bottom layout: switch it off via its own API instead
	if frame == PlayerCastingBarFrame and frame.SetUnit then
		if hide then
			frame:SetUnit(nil)
		else
			frame:SetUnit("player", true, false)
		end
		return
	end
	ns.RunOutOfCombat(key, function()
		if hide then
			if frame:GetParent() ~= hiddenParent then
				originalParents[frame] = frame:GetParent()
				frame:SetParent(hiddenParent)
			end
		elseif originalParents[frame] then
			frame:SetParent(originalParents[frame])
			originalParents[frame] = nil
		end
	end)
end
