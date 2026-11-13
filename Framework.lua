-- Plain Lua replacement for the Ace2 libraries ArcHUD used:
--   AceAddon-2.0 (lifecycle), AceEvent-2.0 (events + internal messages), AceDB-2.0 (profile + namespaces),
--   AceModuleCore-2.0 (modules), AceDebug-2.0 (LevelDebug), AceConsole-2.0 (Print), Metrognome-2.0 (timers).
-- The method names are kept so the ring modules read like the original code.
local addonName, ns = ...

-- The global ArcHUD table existed in the original addon; other addons and macros used it.
ArcHUD = ArcHUD or {}
local ArcHUD = ArcHUD
ns.ArcHUD = ArcHUD

local GetMeta = C_AddOns and C_AddOns.GetAddOnMetadata
ArcHUD.name = "ArcHUD"
ArcHUD.version = (GetMeta and GetMeta(addonName, "Version")) or "2.0"
ArcHUD.author = (GetMeta and GetMeta(addonName, "Author")) or "Uruloke/Nenie"
ArcHUD.date = (GetMeta and GetMeta(addonName, "X-Date")) or ""

---------------------------------------------------------------------------
-- Secret value helpers (Midnight 12.x / Forever addon restrictions)
---------------------------------------------------------------------------
local issecretvalue = issecretvalue

-- True when v can be used in arithmetic, comparisons and as a table key.
function ns.Readable(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

-- Boolean that is safe to truth test: a secret boolean counts as false.
function ns.IsTrue(v)
	if issecretvalue and issecretvalue(v) then
		return false
	end
	return v and true or false
end

---------------------------------------------------------------------------
-- Output and debugging (AceConsole / AceDebug)
---------------------------------------------------------------------------
local function SafeFormat(fmt, ...)
	if select("#", ...) == 0 then
		return tostring(fmt)
	end
	local ok, msg = pcall(string.format, fmt, ...)
	if ok then
		return msg
	end
	local parts = { tostring(fmt) }
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring((select(i, ...)))
	end
	return table.concat(parts, " ")
end
ns.SafeFormat = SafeFormat

function ArcHUD:Print(fmt, ...)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99ArcHUD|r: " .. SafeFormat(fmt, ...))
end

-- Debug levels: 1 warn, 2 info, 3 notice, nil off
function ArcHUD:SetDebugLevel(level)
	self.debugLevel = level
end

function ArcHUD:GetDebugLevel()
	return self.debugLevel
end

function ArcHUD:LevelDebug(level, fmt, ...)
	if self.debugLevel and level <= self.debugLevel then
		DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7fArcHUD Debug|r: " .. SafeFormat(fmt, ...))
	end
end

---------------------------------------------------------------------------
-- Error log. Every error caught by the framework is stored once per distinct message
-- (with stack, count, time, combat state) in ArcHUDDB.forever.errorLog, which the game writes
-- to WTF\Account\<account>\SavedVariables\ArcHUD2.lua on logout or /reload.
-- Only the first occurrence is shown in chat / passed to the error handler, so a per-frame
-- error can no longer flood the client.
---------------------------------------------------------------------------
local MAX_LOG_ENTRIES = 50
local pendingLog = {}
local seenErrors = {}

local function LogTable()
	return ArcHUD.errorLog or pendingLog
end

local function ErrorHandler(msg)
	if issecretvalue and issecretvalue(msg) then
		msg = "<error message was a secret value>"
	end
	msg = tostring(msg)
	local entry = seenErrors[msg]
	if entry then
		entry.count = entry.count + 1
		return
	end
	entry = {
		message = msg,
		stack = debugstack and debugstack(2, 15, 0) or "",
		count = 1,
		time = date("%Y-%m-%d %H:%M:%S"),
		inCombat = InCombatLockdown() and true or false,
		version = ArcHUD.version,
	}
	seenErrors[msg] = entry
	local log = LogTable()
	table.insert(log, entry)
	while #log > MAX_LOG_ENTRIES do
		table.remove(log, 1)
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cffff4040ArcHUD error|r (logged, see /archud errors): " .. msg)
	local handler = geterrorhandler()
	if handler then
		handler(msg)
	end
end
ns.ErrorHandler = ErrorHandler

-- Run func(...) with errors logged instead of thrown
function ns.SafeCall(func, ...)
	return xpcall(func, ErrorHandler, ...)
end

function ArcHUD:AttachErrorLog(root)
	root.errorLog = root.errorLog or {}
	-- Session marker so old and new errors can be told apart
	table.insert(root.errorLog, { message = "--- session start", time = date("%Y-%m-%d %H:%M:%S"), version = self.version, count = 0 })
	for _, entry in ipairs(pendingLog) do
		table.insert(root.errorLog, entry)
	end
	wipe(pendingLog)
	while #root.errorLog > MAX_LOG_ENTRIES do
		table.remove(root.errorLog, 1)
	end
	self.errorLog = root.errorLog
end

function ArcHUD:PrintErrors()
	local log = LogTable()
	local shown = 0
	for _, entry in ipairs(log) do
		if entry.count and entry.count > 0 then
			shown = shown + 1
			self:Print("|cffff4040%s|r x%d (%s%s)", entry.message, entry.count, entry.time or "?", entry.inCombat and ", in combat" or "")
		end
	end
	if shown == 0 then
		self:Print("No errors logged.")
	end
end

function ArcHUD:ClearErrors()
	wipe(LogTable())
	wipe(seenErrors)
	self:Print("Error log cleared.")
end

---------------------------------------------------------------------------
-- Events and internal messages (AceEvent)
---------------------------------------------------------------------------
-- WoW events call handler(obj, event, ...).
-- Internal messages (names starting with ARCHUD_) call handler(obj, ...), like AceEvent-2.0 did.
local EventMixin = {}
local messages = {} -- [message] = ordered list of { obj = obj, handler = handler }

local function CallHandler(obj, handler, ...)
	if type(handler) == "function" then
		return handler(obj, ...)
	end
	local method = obj[handler]
	if method then
		return method(obj, ...)
	end
end

local function OnEvent(frame, event, ...)
	local obj = frame.owner
	local handler = obj.eventHandlers and obj.eventHandlers[event]
	if handler then
		-- Report errors (BugSack / scriptErrors) without breaking other handlers
		xpcall(CallHandler, ErrorHandler, obj, handler, event, ...)
	end
end

local function IsMessage(event)
	return string.sub(event, 1, 7) == "ARCHUD_"
end

local function RemoveMessage(obj, event)
	local list = messages[event]
	if not list then return end
	for i = #list, 1, -1 do
		if list[i].obj == obj then
			table.remove(list, i)
		end
	end
end

function EventMixin:RegisterEvent(event, handler)
	handler = handler or event
	self.eventHandlers = self.eventHandlers or {}
	self.eventHandlers[event] = handler
	if IsMessage(event) then
		RemoveMessage(self, event)
		messages[event] = messages[event] or {}
		table.insert(messages[event], { obj = self, handler = handler })
		return
	end
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame.owner = self
		self.eventFrame:SetScript("OnEvent", OnEvent)
	end
	self.eventFrame:RegisterEvent(event)
end

-- Unit filtered registration (replaces the 1.12 "if arg1 == unit" checks).
function EventMixin:RegisterUnitEvent(event, handler, unit1, unit2)
	handler = handler or event
	self.eventHandlers = self.eventHandlers or {}
	self.eventHandlers[event] = handler
	if not self.eventFrame then
		self.eventFrame = CreateFrame("Frame")
		self.eventFrame.owner = self
		self.eventFrame:SetScript("OnEvent", OnEvent)
	end
	if unit2 then
		self.eventFrame:RegisterUnitEvent(event, unit1, unit2)
	else
		self.eventFrame:RegisterUnitEvent(event, unit1)
	end
end

function EventMixin:UnregisterEvent(event)
	if not self.eventHandlers or not self.eventHandlers[event] then return end
	self.eventHandlers[event] = nil
	if IsMessage(event) then
		RemoveMessage(self, event)
	elseif self.eventFrame then
		self.eventFrame:UnregisterEvent(event)
	end
end

function EventMixin:IsEventRegistered(event)
	return self.eventHandlers ~= nil and self.eventHandlers[event] ~= nil
end

function EventMixin:UnregisterAllEvents()
	if self.eventFrame then
		self.eventFrame:UnregisterAllEvents()
	end
	if self.eventHandlers then
		for event in pairs(self.eventHandlers) do
			if IsMessage(event) then
				RemoveMessage(self, event)
			end
		end
		wipe(self.eventHandlers)
	end
end

-- Fire an internal ARCHUD_* message. Handlers may (un)register while we iterate, so use a snapshot.
function EventMixin:TriggerEvent(message, ...)
	local list = messages[message]
	if not list or #list == 0 then return end
	local snapshot = {}
	for i, entry in ipairs(list) do
		snapshot[i] = entry
	end
	for _, entry in ipairs(snapshot) do
		if entry.obj.eventHandlers and entry.obj.eventHandlers[message] == entry.handler then
			xpcall(CallHandler, ErrorHandler, entry.obj, entry.handler, ...)
		end
	end
end

---------------------------------------------------------------------------
-- Timers (Metrognome-2.0). One shared, accumulator based OnUpdate that only runs
-- while at least one timer is active. Callbacks get (arg, elapsed).
---------------------------------------------------------------------------
local metros = {}
local metroDriver = CreateFrame("Frame")
metroDriver:Hide()
metroDriver:SetScript("OnUpdate", function(driver, elapsed)
	local anyRunning = false
	for _, m in pairs(metros) do
		if m.running then
			anyRunning = true
			m.elapsed = m.elapsed + elapsed
			if m.elapsed >= m.interval then
				local e = m.elapsed
				m.elapsed = 0
				-- One failing timer must not stop the others (they share this loop)
				xpcall(m.func, ErrorHandler, m.arg, e)
			end
		end
	end
	if not anyRunning then
		driver:Hide()
	end
end)

function EventMixin:RegisterMetro(name, func, interval, arg)
	if metros[name] then
		return false
	end
	metros[name] = { func = func, interval = interval or 0, arg = arg, owner = self, running = false, elapsed = 0 }
	return true
end

function EventMixin:UnregisterMetro(name)
	metros[name] = nil
end

function EventMixin:StartMetro(name)
	local m = metros[name]
	if not m then return false end
	m.running = true
	m.elapsed = 0
	metroDriver:Show()
	return true
end

function EventMixin:StopMetro(name)
	local m = metros[name]
	if m then
		m.running = false
	end
end

-- Returns registered, running
function EventMixin:MetroStatus(name)
	local m = metros[name]
	if not m then return false, false end
	return true, m.running
end

function EventMixin:StopAllMetros()
	for _, m in pairs(metros) do
		if m.owner == self then
			m.running = false
		end
	end
end

-- Mix event and timer functions into the core object
for k, v in pairs(EventMixin) do
	ArcHUD[k] = v
end
ns.EventMixin = EventMixin

---------------------------------------------------------------------------
-- Saved variables (AceDB-2.0 subset): per character profile + per module namespaces.
-- Layout: ArcHUDDB.forever = { version, chars = { ["Name - Realm"] = { core = {}, namespaces = {} } } }
-- The "forever" sub table never collides with an old Ace2 ArcHUDDB copied from a vanilla install.
-- Only settings are stored here, never unit data (secret values must not be saved).
---------------------------------------------------------------------------
local DB_VERSION = 1
local defaults = { profile = nil, namespaces = {} }

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

-- RegisterDefaults("profile", tbl) for the core, RegisterDefaults(namespace, "profile", tbl) for modules
function ArcHUD:RegisterDefaults(a, b, c)
	if a == "profile" then
		defaults.profile = b
		if self.db then CopyDefaults(b, self.db.profile) end
	else
		defaults.namespaces[a] = c
		if self.dbChar then
			local nsTable = self:AcquireDBNamespace(a)
			CopyDefaults(c, nsTable.profile)
		end
	end
end

function ArcHUD:InitDB()
	if type(ArcHUDDB) ~= "table" then ArcHUDDB = {} end
	local root = ArcHUDDB.forever
	if type(root) ~= "table" then
		root = { version = DB_VERSION, chars = {} }
		ArcHUDDB.forever = root
	end
	-- Future migrations go here: if root.version < 2 then ... end
	root.version = DB_VERSION
	self:AttachErrorLog(root)
	root.chars = root.chars or {}

	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "Unknown"
	local key = name .. " - " .. realm
	root.chars[key] = root.chars[key] or {}
	local char = root.chars[key]
	char.core = char.core or {}
	char.namespaces = char.namespaces or {}

	self.dbChar = char
	self.db = { profile = char.core }
	self.dbNamespaces = {}
	if defaults.profile then
		CopyDefaults(defaults.profile, self.db.profile)
	end
end

function ArcHUD:AcquireDBNamespace(name)
	if not self.dbNamespaces[name] then
		self.dbChar.namespaces[name] = self.dbChar.namespaces[name] or {}
		self.dbNamespaces[name] = { profile = self.dbChar.namespaces[name] }
		if defaults.namespaces[name] then
			CopyDefaults(defaults.namespaces[name], self.dbNamespaces[name].profile)
		end
	end
	return self.dbNamespaces[name]
end

-- Reset the current character's profile and all ring namespaces to defaults.
function ArcHUD:ResetDB()
	wipe(self.db.profile)
	if defaults.profile then CopyDefaults(defaults.profile, self.db.profile) end
	for name, nsTable in pairs(self.dbNamespaces) do
		wipe(nsTable.profile)
		if defaults.namespaces[name] then CopyDefaults(defaults.namespaces[name], nsTable.profile) end
	end
end

---------------------------------------------------------------------------
-- Modules (AceModuleCore-2.0)
---------------------------------------------------------------------------
ArcHUD.modules = {}
ArcHUD.moduleList = {}
ArcHUD.modulePrototype = {}
for k, v in pairs(EventMixin) do
	ArcHUD.modulePrototype[k] = v
end
local moduleMeta = { __index = ArcHUD.modulePrototype }

function ArcHUD:NewModule(name)
	local module = setmetatable({ name = name, parent = self, active = false }, moduleMeta)
	self.modules[name] = module
	table.insert(self.moduleList, module)
	return module
end

function ArcHUD:HasModule(name)
	return type(name) == "string" and self.modules[name] ~= nil
end

function ArcHUD:GetModule(name)
	return self.modules[name]
end

function ArcHUD:IsModuleActive(module)
	if type(module) == "string" then module = self.modules[module] end
	return module ~= nil and module.active == true
end

-- Same order as AceModuleCore-2.0: when disabling, events and timers are dropped first, then OnDisable runs
-- (OnDisable re-registers the ARCHUD_MODULE_* messages it still needs).
function ArcHUD:ToggleModuleActive(module, state)
	if type(module) == "string" then module = self.modules[module] end
	if not module then return end
	if state == nil then state = not module.active end
	if state == module.active then return end
	module.active = state
	if state then
		if module.OnEnable then module:OnEnable() end
	else
		module:UnregisterAllEvents()
		module:StopAllMetros()
		if module.OnDisable then module:OnDisable() end
	end
	return state
end

---------------------------------------------------------------------------
-- Combat lockdown queue for protected work (secure nameplates, Blizzard frame hiding)
---------------------------------------------------------------------------
local combatQueue = {}
local queueFrame = CreateFrame("Frame")
queueFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
queueFrame:SetScript("OnEvent", function()
	-- Run in order; each entry is { key, func }. Later entries with the same key replaced earlier ones.
	local list = combatQueue
	combatQueue = {}
	for _, entry in ipairs(list) do
		xpcall(entry.func, ErrorHandler)
	end
end)

-- Run func now, or after combat if the UI is locked down. A key collapses repeated requests.
function ns.RunOutOfCombat(key, func)
	if not InCombatLockdown() then
		func()
		return true
	end
	for _, entry in ipairs(combatQueue) do
		if entry.key == key then
			entry.func = func
			return false
		end
	end
	table.insert(combatQueue, { key = key, func = func })
	return false
end

---------------------------------------------------------------------------
-- Lifecycle (AceAddon-2.0): OnInitialize at ADDON_LOADED, OnEnable at PLAYER_LOGIN
---------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg)
	if event == "ADDON_LOADED" and arg == addonName then
		self:UnregisterEvent("ADDON_LOADED")
		ArcHUD:InitDB()
		if ArcHUD.OnInitialize then xpcall(ArcHUD.OnInitialize, ErrorHandler, ArcHUD) end
		for _, module in ipairs(ArcHUD.moduleList) do
			if module.OnInitialize then xpcall(module.OnInitialize, ErrorHandler, module) end
		end
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		if ArcHUD.OnEnable then xpcall(ArcHUD.OnEnable, ErrorHandler, ArcHUD) end
	end
end)
