-- Minimal replacement for AceLocale-2.0, so the original locale files keep their content.
-- Supports the call styles ArcHUD uses: L"KEY", L("KEY") and L("GROUP", "KEY").
local addonName, ns = ...

local currentLocale = GetLocale()
local locales = {}

local LocaleMethods = {}

-- Only enUS (the base) and the client locale are kept.
function LocaleMethods:RegisterTranslations(locale, func)
	if locale ~= "enUS" and locale ~= currentLocale then
		return
	end
	local data = func()
	if locale == "enUS" then
		self.base = data
	else
		self.translated = data
	end
end

local function lookup(tbl, a, b)
	if not tbl then return nil end
	local v = tbl[a]
	if b ~= nil then
		if type(v) == "table" then
			v = v[b]
		else
			v = nil
		end
	end
	if v == true then
		-- AceLocale shorthand: ["Version: "] = true means "use the key"
		v = b or a
	end
	return v
end

local LocaleMeta = {
	__index = LocaleMethods,
	__call = function(self, a, b)
		local v = lookup(self.translated, a, b)
		if v == nil then v = lookup(self.base, a, b) end
		if v == nil then v = b or a end
		return v
	end,
}

-- ns.Locale("ArcHUD_Core") returns the same object every time for a given name.
function ns.Locale(name)
	if not locales[name] then
		locales[name] = setmetatable({}, LocaleMeta)
	end
	return locales[name]
end
