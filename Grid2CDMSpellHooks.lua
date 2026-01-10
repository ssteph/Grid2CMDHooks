local ADDON_NAME, g2cdmhooks = ...

----------------------------------------------------------------
--- A3
----------------------------------------------------------------

CdmHookA3 = LibStub("AceAddon-3.0"):NewAddon("CdmHookA3", "AceEvent-3.0", "AceConsole-3.0")
CdmHookA3.lastSentCast = nil
CdmHookA3.watchedSpells = { }
CdmHookA3.searchCMD = true

local updateFrame = CreateFrame("FRAME")
updateFrame:HookScript("OnUpdate", function(self, elapsed)
	CdmHookA3:OnUpdate(elapsed)
end)

function CdmHookA3:OnEnable()
    self:Print("Enable CdmHookA3")

    --todo: from grid2 config
    self.watchedSpells[33763] = {
        cdmFrame = nil,
        cooldownID = -1,
        cooldownInfo = nil,
        targetUnit = nil
    }

    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterEvent("UNIT_SPELLCAST_SENT")
end

function CdmHookA3:OnInitialize()
    self:Print("Init CdmHookA3")
end

function CdmHookA3:OnUpdate(elapsed)
    --todo: do outside lockdown
    if self.searchCMD then
        self:SearchCDMBuffs()
        self.searchCMD = false
    end


    for spellID, watchData in pairs(self.watchedSpells) do
        if watchData.targetUnit then
            --self:Print("update for " .. watchData.targetUnit)
            --only update relevant frame
            Grid2:UpdateFramesOfUnit(watchData.targetUnit)
        end
    end
end

function CdmHookA3:SearchCDMBuffs()
    --self:Print("-- Search")

    local buffBarsFrame = _G["BuffBarCooldownViewer"]
    if buffBarsFrame then
        local num = select("#", buffBarsFrame:GetChildren())

        --self:Print("num " .. num)

        for i = 1, num do
            local child = select(i, buffBarsFrame:GetChildren())

            --self:Print("child " .. i .. " is " .. tostring(child))

            local cooldownID = child.cooldownID or (child.cooldownInfo and child.cooldownInfo.cooldownID)

            --self:Print("cdid is " .. tostring(cooldownID))

            if cooldownID and cooldownID > 0 then

                local info = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
                if info then
                    --self:Print("spell is" .. info.spellID)

                    local watchData = self.watchedSpells[info.spellID]

                    if watchData then
                        --self:Print("here for spell " .. info.spellID .. " frame is " .. tostring(child))

                        watchData.cdmFrame = child
                        watchData.cooldownID = cooldownID
                        watchData.cooldownInfo = info
                    end
                end
            end
        end

    end

--    for spellID, watchData in ipairs(self.watchedSpells) do

--    end
end

function CdmHookA3:UNIT_SPELLCAST_SENT(event, unit, targetName, castGUID, spellID)
    if not issecretvalue(unit) and unit == "player" then
        --self:Print("player cast SENT")
        self.lastSentCast = {
            guid = castGUID,
            target = targetName,
        }
    end
end

function CdmHookA3:UNIT_SPELLCAST_SUCCEEDED(event, unit, castGUID, spellID)
    if self.lastSentCast and not issecretvalue(unit) and unit == "player" then
        if not issecretvalue(self.lastSentCast.guid) and not issecretvalue(castGUID) then
            if self.lastSentCast.guid == castGUID then
                local watchData = self.watchedSpells[spellID]
                if watchData then
                    local targetID = self:FindUnitId(self.lastSentCast.target)
                    --self:Print("Watched spell cast on " .. self.lastSentCast.target .. " (" .. tostring(targetID) .. ")")

                    if targetID then
                        local previousTarget = watchData.targetUnit

                        watchData.targetUnit = targetID

                        self:Print("watchData.cooldownID is " .. watchData.cooldownID)

                        if watchData.cooldownID > 0 then
                            watchData.cooldownInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo(watchData.cooldownID)

                            --self:Print("watchData.cooldownInfo is " .. tostring(watchData.cooldownInfo))

                            --self:Print("spellid " .. watchData.cooldownInfo.spellID)

                            --for k,v in pairs(watchData.cooldownInfo) do
                            --    self:Print(k.." = "..tostring(v))
                            --end
                        end

                        --only update relevant frames
                        --do last
                        Grid2:UpdateFramesOfUnit(targetID)
                        if previousTarget then
                            Grid2:UpdateFramesOfUnit(previousTarget)
                        end
                    end
                end
            else
                self:Print("??????????? castguid mismatch?!")
            end
        else
            self:Print("!!!!!!!!!!!!! a castguid was secret!!")
        end
    end
end

function CdmHookA3:FindUnitId(unitNameToTest)
    if unitNameToTest == UnitName("player") then
        return "player"
    end

    local prefix = "party"
    local num = 5

    if IsInRaid() then
        prefix = "raid"
        num = GetNumRaidMembers()
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
    local watchData = self.watchedSpells[spellID]
    --self:Print("IsActive with unit " .. tostring(unit))

    if watchData and watchData.targetUnit then
        return UnitIsUnit(watchData.targetUnit, unit)
    end

    return false
end

function CdmHookA3:GetFrame(spellID, unit)
    local watchData = self.watchedSpells[spellID]

    if watchData and watchData.targetUnit then
        if UnitIsUnit(watchData.targetUnit, unit) then
            --self:Print("Returning frame " .. tostring(watchData.cdmFrame))

            --for k,v in pairs(watchData.cdmFrame) do
            --    self:Print(k.." = "..tostring(v))
            --end

            return watchData.cdmFrame
        end
    end

    return nil
end

function CdmHookA3:GetInfo(spellID, unit)
    local watchData = self.watchedSpells[spellID]
    --self:Print("IsActive with unit " .. tostring(unit))

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

--local herpderp = { }

local HookFuncs = {
    IsActive = function(self, unit)
        return CdmHookA3:IsActive(33763, unit)
    end,

    GetText = function(self, unit)
        local result = "noinfo"

        local frame = CdmHookA3:GetFrame(33763, unit)
        if frame then
            local auraInstanceId = frame.auraInstanceID
            --CdmHookA3:Print("auraid: " .. tostring(auraInstanceId))

            if auraInstanceId and type(auraInstanceId) == "number" and auraInstanceId > 0 then
                local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", auraInstanceId)

                local dur = C_UnitAuras.GetAuraDurationRemaining("player", auraInstanceId)
                result = string.format("%.1f", dur or 0)

                --if auraData then
                --    for k,v in pairs(auraData) do
                --        CdmHookA3:Print(k.." = "..tostring(v))
                --    end
                --end
                --

                --todo
                --if not C_DurationUtil or not C_DurationUtil.CreateDuration then return nil end
                --local durObj = C_DurationUtil.CreateDuration()


            end
            --works!!
            --result = frame.Bar.Duration:GetText()
        end

        --CdmHookA3:Print("res: " .. result)
        return result
    end,

    GetIcon = function(self, unit)
        return nil
    end,

    GetExpirationTime = function(self, unit)
        return nil
    end,

    GetColor = function(self, unit)
        return 1.0, 0.0, 0.0, 1.0
    end
}


Grid2.setupFunc["cdm-hook"] = function(baseKey, dbx)
    local newHook = Grid2.statusPrototype:new(baseKey, true)
    newHook:Inject(HookFuncs)
    Grid2:RegisterStatus(newHook, {"color", "icon", "text"}, baseKey, dbx)
	return newHook
end
--Grid2:DbSetStatusDefaultValue("cdm-hook", {type = "cdm-hook", color1 = {r=0,g=.6,b=1,a=.6}})


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
	    print("create with key: " .. key)

		local dbx = Grid2.CopyTable(data.dbx)
		Grid2.db.profile.statuses[key] = dbx
		local newHook = Grid2.setupFunc[dbx.type](key, dbx)
		Grid2Options:MakeStatusOptions(newHook)
		--Grid2Options:SelectGroup('statuses', Grid2Options:GetStatusCategory(status), status.name)

		--Grid2Options:RegisterStatusOptions(key, "cdm-hooks", Grid2Options.MakeStatusCustomDebuffTypeOptions, {groupOrder = 11})

		data.name = nil --reset for reuse
	end
end

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
		prefix = 'cdm-hook',
		dbx = { type = "cdm-hook", color1 = {r=0, g=1, b=0, a=1} },
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


    Grid2Options:RegisterStatusOptions( "cdm-hook", "cdm-hooks", Grid2Options.MakeStatusColorOptions, {
        isDeletable = true, displayPrefix = false
    } )

	--Grid2Options:RegisterStatusOptions("cdm-hook", "cdm-hooks", Grid2Options.MakeStatusCustomDebuffTypeOptions, {groupOrder = 11})
end )
--    function()
--    print("LoadOptions")
--	Grid2Options:RegisterStatusOptions("cdm-hook", "role", function(self, status, options)
--        Grid2Options.MakeStatusCustomDebuffTypeOptions(status, options)
--	end
--	, { groupOrder = 11 })
--end )
