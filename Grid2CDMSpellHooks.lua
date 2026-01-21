local ADDON_NAME, g2cdmhooks = ...

----------------------------------------------------------------
--- A3
----------------------------------------------------------------

CdmHookA3 = LibStub("AceAddon-3.0"):NewAddon("CdmHookA3", "AceEvent-3.0", "AceConsole-3.0")
CdmHookA3.lastSentCast = nil
CdmHookA3.watchedSpells = { }
CdmHookA3.searchCMD = true
CdmHookA3.settingsHooked = false
CdmHookA3.unitsToUpdate = {}

local updateFrame = CreateFrame("FRAME")
updateFrame:HookScript("OnUpdate", function(self, elapsed)
	CdmHookA3:OnUpdate(elapsed)
end)

function CdmHookA3:OnEnable()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_SENT")
end

function CdmHookA3:OnInitialize()
    --self:Print("Init CdmHookA3")
end

function CdmHookA3:OnUpdate(elapsed)

    if self.searchCMD and not InCombatLockdown() then
        self:ScanCDMBuffs()
        self.searchCMD = false

        if not self.settingsHooked then
            local cdmSettings = _G["CooldownViewerSettings"]
            if cdmSettings then
                cdmSettings:HookScript("OnHide", function()
                    CdmHookA3:TriggerRescan()
                end)
            end

            self.settingsHooked = true
        end
    end

    for spellID, watchData in pairs(self.watchedSpells) do
        if watchData.targetUnit then
            watchData.timeElapsed = watchData.timeElapsed + elapsed
            self.unitsToUpdate[watchData.targetUnit] = true

            if watchData.cdmFrame and not watchData.cdmFrame.auraInstanceID and watchData.timeElapsed > 1.0 then
                watchData.targetUnit = nil
            end
        end
    end

    for unit, _ in pairs(self.unitsToUpdate) do
        --only update relevant frame
        Grid2:UpdateFramesOfUnit(unit)
    end

    self.unitsToUpdate = { }
end

function CdmHookA3:TriggerRescan()
    for spellID, watchData in pairs(self.watchedSpells) do
        if watchData.targetUnit then
            self.unitsToUpdate[watchData.targetUnit] = true
        end
    end

    self.watchedSpells = {}
    self.searchCMD = true
end

function CdmHookA3:TryAddToWatchedSpells(cdmFrame)
    local cooldownID = cdmFrame.cooldownID or (cdmFrame.cooldownInfo and cdmFrame.cooldownInfo.cooldownID)

    if cooldownID and cooldownID > 0 then
        local info = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)

        if info and info.spellID and info.spellID > 0 and not self.watchedSpells[info.spellID] then
            self.watchedSpells[info.spellID] = {
                cdmFrame = cdmFrame,
                cooldownID = cooldownID,
                cooldownInfo = info,
                targetUnit = nil,
                timeElapsed = 0
            }
        end
    end
end

function CdmHookA3:ScanCDMBuffs()

    local ArcRef = _G["ArcUI_NS"]
    if ArcRef then
        local arcIcons = ArcRef.API:GetCDMAuraIcons()

        for _, arcIcon in pairs(arcIcons) do
            if arcIcon and arcIcon.frame then self:TryAddToWatchedSpells(arcIcon.frame) end
        end
    end

    local buffBarsFrame = _G["BuffBarCooldownViewer"]
    if buffBarsFrame then
        local num = select("#", buffBarsFrame:GetChildren())

        for i = 1, num do
            local child = select(i, buffBarsFrame:GetChildren())
            if child then self:TryAddToWatchedSpells(child) end
        end
    end

    local buffIconsFrame = _G["BuffIconCooldownViewer"]
    if buffIconsFrame then
        local num = select("#", buffIconsFrame:GetChildren())

        for i = 1, num do
            local child = select(i, buffIconsFrame:GetChildren())
            if child then self:TryAddToWatchedSpells(child) end
        end
    end

end

function CdmHookA3:UNIT_SPELLCAST_SENT(event, unit, targetName, castGUID, spellID)
    if not issecretvalue(unit) and unit == "player" then
        targetName = targetName or UnitName("player")
        self.lastSentCast = { guid = castGUID, target = targetName }
    end
end

function CdmHookA3:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if self.lastSentCast and not issecretvalue(unit) and unit == "player" then
        if not issecretvalue(self.lastSentCast.guid) and not issecretvalue(castGUID) then
            if self.lastSentCast.guid == castGUID then
                local watchData = self.watchedSpells[spellID]

                if watchData then
                    local targetID = self:FindUnitId(self.lastSentCast.target)
                    local previousTarget = watchData.targetUnit

                    --targetID could be nil, e.g. when casting on an NPC
                    watchData.targetUnit = targetID
                    watchData.timeElapsed = 0

                    if watchData.cooldownID > 0 then
                        watchData.cooldownInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo(watchData.cooldownID)
                    end

                    if previousTarget then
                        Grid2:UpdateFramesOfUnit(previousTarget)
                    end
                end
            else
                --self:Print("??????????? castguid mismatch?!")
            end
        else
            --self:Print("!!!!!!!!!!!!! a castguid was secret!!")
        end
    end
end

function CdmHookA3:FindUnitId(unitNameToTest)

    local num = GetNumGroupMembers()

    if unitNameToTest == UnitName("player") then
        if IsInRaid() then
            for i = 1, num do
                if UnitIsUnit("raid"..i, "player") then
                    return "raid"..i
                end
            end
        end

        return "player"
    end

    local prefix = "party"

    if IsInRaid() then
        prefix = "raid"
    end

    for i = 1, num do
        local unitID = prefix .. i
        if UnitExists(unitID) then
            local name, realm = UnitName(unitID)
            if realm == "" then realm = nil end
            local fullName = (realm and name.."-"..realm) or name

            if unitNameToTest == fullName then
                return unitID
            end
        end
    end

    return nil
end

function CdmHookA3:IsActive(spellID, unit)
    if not spellID then return nil end

    local watchData = self.watchedSpells[spellID]
    if watchData and watchData.targetUnit then
        return UnitIsUnit(watchData.targetUnit, unit)
    end

    return false
end

function CdmHookA3:GetFrame(spellID, unit)
    if not spellID then return nil end

    local watchData = self.watchedSpells[spellID]
    if watchData and watchData.targetUnit then
        if UnitIsUnit(watchData.targetUnit, unit) then
            return watchData.cdmFrame
        end
    end

    return nil
end

function CdmHookA3:GetInfo(spellID, unit)
    if not spellID then return nil end

    local watchData = self.watchedSpells[spellID]
    if watchData and watchData.targetUnit then
        if UnitIsUnit(watchData.targetUnit, unit) then
           return watchData.cooldownInfo
        end
    end

    return nil
end

----------------------------------------------------------------
--- setup
----------------------------------------------------------------

local HookFuncs = {
    IsActive = function(self, unit)
        return CdmHookA3:IsActive(self.dbx.spellID, unit)
    end,

    GetText = function(self, unit)
        local result = ""

        local frame = CdmHookA3:GetFrame(self.dbx.spellID, unit)
        if frame then
            local auraInstanceId = frame.auraInstanceID
            if auraInstanceId and type(auraInstanceId) == "number" and auraInstanceId > 0 then
                --local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceId)
                local dur = C_UnitAuras.GetAuraDuration("player", auraInstanceId)
                result = string.format("%.1f", dur and dur:GetRemainingDuration() or 0)
            end
        end

        return result
    end,

    GetIcon = function(self, unit)
        local result = nil

        local frame = CdmHookA3:GetFrame(self.dbx.spellID, unit)
        if frame then
            result = frame.Icon.Icon:GetTexture()
        end

        return result
    end,

    GetDuration = function(self, unit)
        local result = nil

        local frame = CdmHookA3:GetFrame(self.dbx.spellID, unit)
        if frame then
            local auraInstanceId = frame.auraInstanceID

            if auraInstanceId and type(auraInstanceId) == "number" and auraInstanceId > 0 then
                local dur = C_UnitAuras.GetAuraDuration("player", auraInstanceId)
                result = dur:GetTotalDuration()
            end
        end

        return result
    end,

    GetExpirationTime = function(self, unit)
        local result = nil

        local frame = CdmHookA3:GetFrame(self.dbx.spellID, unit)
        if frame then
            local auraInstanceId = frame.auraInstanceID

            if auraInstanceId and type(auraInstanceId) == "number" and auraInstanceId > 0 then
                local dur = C_UnitAuras.GetAuraDuration("player", auraInstanceId)
                result = dur:GetEndTime()
            end
        end

        return result
    end,

    GetColor = function(self, unit)
        local c = self.dbx.color1
        return c.r, c.g, c.b, c.a
    end,

    UpdateDB = function(self)
        --TODO: might be unnecessary
        --CdmHookA3:TriggerRescan()
    end,
}

Grid2.setupFunc["cdm-hook"] = function(baseKey, dbx)
    local newHook = Grid2.statusPrototype:new(baseKey, true)
    newHook:Inject(HookFuncs)
    Grid2:RegisterStatus(newHook, {"color", "icon", "text"}, baseKey, dbx)
    newHook.dbx = dbx
	return newHook
end

----------------------------------------------------------------
--- utils
----------------------------------------------------------------

local function get_new_cdmhook_key(data)
	if data.name then
		local key = data.name:gsub("[ %.\"]", "")
		if key~="" then
			key = string.format("%s-%s", data.prefix, key)
			return Grid2.statuses[key]==nil and key or nil
		end
	end
end

local function create_new_cdmhook(data)
	local key = get_new_cdmhook_key(data)
	if key then
		local dbx = Grid2.CopyTable(data.dbx)
		Grid2.db.profile.statuses[key] = dbx
		local newHook = Grid2.setupFunc[dbx.type](key, dbx)
		Grid2Options:MakeStatusOptions(newHook)
		--Grid2Options:SelectGroup('statuses', Grid2Options:GetStatusCategory(status), status.name)
		--Grid2Options:RegisterStatusOptions(key, "cdm-hooks", Grid2Options.MakeStatusCustomDebuffTypeOptions, {groupOrder = 11})

		--reset for reuse
		data.name = nil
		data.dbx.spellID = nil
	end
end

----------------------------------------------------------------
--- hook options in Grid2
----------------------------------------------------------------

Grid2:PostHookFunc( Grid2, 'LoadOptions', function()

    local L = Grid2Options.L

    Grid2Options:RegisterStatusCategory( "cdm-hooks", {
    	name  = "CDM Hooks",
    	title = "CDM Hooks",
    	desc  = "Hook individual auras or aura-bars from CDM",
    	icon  = "Interface\\Icons\\Inv_enchant_shardbrilliantsmall",
    	options = {},
    } )

   	local hook = {
        name = nil,
		prefix = 'cdm-hook',
		dbx = { type = "cdm-hook", spellID = nil, color1 = {r=1, g=1, b=1, a=1} },
	}

    Grid2Options:RegisterStatusCategoryOptions( "cdm-hooks", {
        hookName = {
    		type = "input",
    		order = 10,
    		name = "Create a new hook",
    		get = function() return hook.name or "" end,
    		set = function(info,v) hook.name = v end
    	},
        create = {
			type = "execute",
			order = 500,
			name = L["Create"],
			desc = "Create a new hook.",
			func = function()
				create_new_cdmhook(hook)
			end,
			disabled = function()
				return not hook.name or not get_new_cdmhook_key(hook)
			end,
		},
		arg = hook
    } )

    Grid2Options:RegisterStatusOptions( "cdm-hook", "cdm-hooks", function(self, status, options, optionParams)
           	options.spellID_opt = {
          		type = "input", --dialogControl = "Aura_EditBox",
          		order = 5.1,
          		width = "full",
          		name = "SpellId",
          		--usage = NewAuraUsageDescription,
          		get = function () return status.dbx.spellID and tostring(status.dbx.spellID) or "" end,
          		set = function (_, v)
    				status.dbx.spellID = tonumber(v) or 0
    				status:Refresh()
                end,
           	}

            options.color1 = {
                type = "color",
                width = "full",
                order = 5.2,
                name = L["Color"],
                get = function()
                    local c = status.dbx.color1
                    return c.r, c.g, c.b, c.a
                end,
                set = function(info, r, g, b, a)
                    local c = status.dbx.color1
                    c.r, c.g, c.b, c.a = r, g, b, a
                    status.dbx.color1 = c
                    status:Refresh()
                end,
            }
        end,
        { isDeletable = true, displayPrefix = false } )

end )
