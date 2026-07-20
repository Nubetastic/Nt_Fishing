local fishing_minigame_struct = {}
local ready = false
local fishing = false
local currentTackle = nil
local nuiAttemptStarted = false
local nuiOpen = false
local nuiResult = nil
local fishingInfoOpen = false
local promptsPrepared = false
local hasMinigameOn = false
local eagleEyeFish = {}
lib.locale()

local fishing_data = {
    prompt_prepare_fishing = { group = nil, change_bait = nil, throw_hook = nil }
}

local function debugPrint(message, ...)
    if not Config.Debug then return end
    print(('[Nt_Fishing:client] ' .. message):format(...))
end

local fishByHash = {}
for modelName, species in pairs(Config.FishByModelName) do
    local modelHash = GetHashKey(modelName)
    fishByHash[modelHash] = species
end

local function getFishingRodState()
    local rodHash = GetHashKey('WEAPON_FISHINGROD')
    local hasRod = HasPedGotWeapon(cache.ped, rodHash)
    local heldWeapon = Citizen.InvokeNative(0x8425C5F057012DAB, cache.ped)

    return hasRod or heldWeapon == rodHash, hasRod, heldWeapon, rodHash
end

local function updateNuiFocus()
    if fishingInfoOpen then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    elseif nuiOpen then
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(false)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

local function closeFishingNui()
    if not nuiOpen then return end
    SendNUIMessage({ action = 'closeGame' })
    nuiOpen = false
    updateNuiFocus()
end

local function closeFishingInfo()
    if not fishingInfoOpen then return end
    debugPrint('Closing fishing guide NUI.')
    SendNUIMessage({ action = 'closeFishingInfo' })
    fishingInfoOpen = false
    updateNuiFocus()
end

local function canOpenFishingInfo()
    return not nuiOpen and not nuiAttemptStarted
end

local function buildFishingInfo()
    local guide = {}
    local tackleGuide = {}

    for _, tackleName in ipairs(Config.TackleOrder) do
        local tackle = Config.Tackle[tackleName]
        if tackle then
            tackleGuide[#tackleGuide + 1] = {
                id = tackleName,
                name = tackle.label,
                image = tackle.image,
                type = tackle.natural and 'Bait' or 'Lure',
            }
        end
    end

    for _, species in ipairs(Config.FishSpecies) do
        local preferred = {}
        local chances = {}
        for _, tackleName in ipairs(species.preferred) do
            local tackle = Config.Tackle[tackleName]
            if tackle then
                preferred[#preferred + 1] = { name = tackle.label, image = tackle.image }
            end
        end

        for _, tackle in ipairs(tackleGuide) do
            chances[#chances + 1] = tonumber(species.attraction[tackle.id]) or 0
        end

        guide[#guide + 1] = {
            name = species.name,
            image = species.image,
            difficulty = species.difficulty,
            preferred = preferred,
            chances = chances,
        }
    end
    return guide, tackleGuide
end

local function openFishingInfo()
    if fishingInfoOpen then return end
    if not canOpenFishingInfo() then
        debugPrint('Guide open was requested, but canOpenFishingInfo returned false.')
        return
    end
    debugPrint('Opening fishing guide NUI.')
    local fishGuide, tackleGuide = buildFishingInfo()
    fishingInfoOpen = true
    SendNUIMessage({
        action = 'openFishingInfo',
        fish = fishGuide,
        tackle = tackleGuide,
        requiredLosses = Config.FishingGame.RequiredLosses,
    })
    updateNuiFocus()

    CreateThread(function()
        while fishingInfoOpen do
            if not canOpenFishingInfo() then
                debugPrint('Closing fishing guide because its availability state changed.')
                closeFishingInfo()
                return
            end
            Wait(250)
        end
    end)
end

local function resetNuiFishingCast()
    closeFishingNui()
    FISHING_SET_TRANSITION_FLAG(128)
    Wait(1500)
    SetFishingBait(cache.ped, "", 0, 1)
    fishing = false
    nuiAttemptStarted = false
end

local function selectWeightedFish(coords)
    local candidates = {}
    local totalWeight = 0

    for _, entity in pairs(GetNearbyFishs(coords, Config.FishScanRadius)) do
        local model = GetEntityModel(entity)
        local species = fishByHash[model]
        local weight = species and tonumber(species.attraction[currentTackle]) or 0
        if weight > 0 then
            totalWeight = totalWeight + weight
            candidates[#candidates + 1] = { entity = entity, model = model, weight = weight }
        end
    end

    if totalWeight <= 0 then return nil end

    local roll = math.random() * totalWeight
    local runningWeight = 0
    for _, candidate in ipairs(candidates) do
        runningWeight = runningWeight + candidate.weight
        if roll <= runningWeight then return candidate end
    end

    return candidates[#candidates]
end

local function runNuiFishingAttempt()
    local bobberHandle = FISHING_GET_BOBBER_HANDLE()
    local hookHandle = FISHING_GET_HOOK_HANDLE()
    local scanEntity = DoesEntityExist(bobberHandle) and bobberHandle or hookHandle

    if not DoesEntityExist(scanEntity) then
        lib.notify({ title = 'Fishing', description = 'The cast could not be located.', type = 'error' })
        resetNuiFishingCast()
        return
    end

    local selectedFish = selectWeightedFish(GetEntityCoords(scanEntity))
    if not selectedFish then
        lib.notify({ title = 'Fishing', description = 'No fish are interested in this tackle here.', type = 'inform' })
        resetNuiFishingCast()
        return
    end

    local selectedEntity = selectedFish.entity
    local selectedModel = selectedFish.model
    local attempt = lib.callback.await('rsg-fishing:server:startAttempt', false, currentTackle, selectedModel)
    if not attempt or not attempt.accepted or not tonumber(attempt.weight) then
        lib.notify({ title = 'Fishing', description = 'This fishing attempt could not be started.', type = 'error' })
        resetNuiFishingCast()
        return
    end

    local biteAt = GetGameTimer() + math.random(Config.BiteDelayMin, Config.BiteDelayMax)
    while fishing and GetGameTimer() < biteAt do
        if IsEntityDead(cache.ped) then fishing = false end
        Wait(100)
    end

    if not fishing then
        lib.callback.await('rsg-fishing:server:finishAttempt', false, 'cancelled')
        closeFishingNui()
        return
    end

    local biteAccepted = lib.callback.await('rsg-fishing:server:markBite', false)
    if not biteAccepted then
        lib.callback.await('rsg-fishing:server:finishAttempt', false, 'cancelled')
        lib.notify({ title = 'Fishing', description = 'The bite could not be started.', type = 'error' })
        resetNuiFishingCast()
        return
    end

    local difficultyName = attempt.difficulty or 'standard'
    local difficulty = Config.Difficulties[difficultyName] or Config.Difficulties.standard

    lib.notify({ title = 'Fishing', description = 'A fish is biting!', type = 'success', duration = 2500 })
    nuiResult = nil
    nuiOpen = true
    updateNuiFocus()
    SendNUIMessage({
        action = 'openGame',
        requiredWins = Config.FishingGame.RequiredWins,
        requiredLosses = Config.FishingGame.RequiredLosses,
        maxRounds = Config.FishingGame.MaxRounds,
        timeout = Config.FishingGame.Timeout,
        markerSpeed = difficulty.markerSpeed,
        targetWidth = difficulty.targetWidth,
        speedIncreasePerRound = Config.FishingGame.SpeedIncreasePerRound,
        struggleChance = difficulty.struggleChance,
        struggleDuration = difficulty.struggleDuration,
        struggleDistanceMin = difficulty.struggleDistanceMin,
        struggleDistanceMax = difficulty.struggleDistanceMax,
        struggleCheckInterval = Config.FishingGame.StruggleCheckInterval,
        struggleCooldown = Config.FishingGame.StruggleCooldown,
        jitterJumpTime = Config.FishingGame.JitterJumpTime,
        struggleMethods = {
            jitter = Config.StruggleMethods.Jitter == true,
            reverse = Config.StruggleMethods.Reverse == true,
            jump = Config.StruggleMethods.Jump == true,
        },
    })

    local clientTimeout = GetGameTimer() + Config.FishingGame.Timeout + 2000
    while fishing and nuiResult == nil and GetGameTimer() < clientTimeout do
        if IsEntityDead(cache.ped) then fishing = false end
        Wait(50)
    end

    local result = nuiResult or (fishing and 'failed' or 'cancelled')
    closeFishingNui()

    if result == 'success' then
        local acceptedSuccess = lib.callback.await('rsg-fishing:server:finishAttempt', false, 'success')
        if acceptedSuccess then
            resetNuiFishingCast()
            if DoesEntityExist(selectedEntity) then
                SetEntityAsMissionEntity(selectedEntity, true, true)
                DeleteEntity(selectedEntity)
            end
            lib.notify({ title = 'Fishing', description = 'You landed the fish!', type = 'success' })
            return
        end
        lib.notify({ title = 'Fishing', description = 'The fish could not be awarded.', type = 'error' })
    elseif result == 'failed' then
        lib.callback.await('rsg-fishing:server:finishAttempt', false, 'line_snapped')
        lib.notify({ title = 'Fishing', description = 'The line snapped and the fish escaped.', type = 'error' })
    else
        lib.callback.await('rsg-fishing:server:finishAttempt', false, 'cancelled')
        lib.notify({ title = 'Fishing', description = 'Fishing cancelled.', type = 'inform' })
    end

    resetNuiFishingCast()
end

RegisterNUICallback('fishingResult', function(data, cb)
    cb({ ok = true })
    if not nuiOpen or nuiResult ~= nil then return end

    local result = data and data.result
    if result == 'success' or result == 'failed' or result == 'cancelled' then
        nuiResult = result
    end
end)

RegisterNUICallback('closeFishingInfo', function(_, cb)
    cb({ ok = true })
    closeFishingInfo()
end)

RegisterNetEvent('Nt_Fishing:client:openFishingGuide', function()
    debugPrint('Radial fishing guide requested.')

    if not canOpenFishingInfo() then
        debugPrint('Radial guide request rejected because the fishing timing NUI is active.')
        return
    end

    openFishingInfo()
end)

RegisterNetEvent('rsg-fishing:client:usebait')
AddEventHandler('rsg-fishing:client:usebait', function(usableTackle)
    local rodHeld, hasRod, heldWeapon, rodHash = getFishingRodState()
    debugPrint(
        'Received bait use: tackle=%s, configured=%s, fishing=%s, nuiAttempt=%s, nuiOpen=%s, rodHeld=%s, hasPedGotRod=%s, heldWeapon=%s, rodHash=%s.',
        tostring(usableTackle),
        tostring(Config.Tackle[usableTackle] ~= nil),
        tostring(fishing),
        tostring(nuiAttemptStarted),
        tostring(nuiOpen),
        tostring(rodHeld),
        tostring(hasRod),
        tostring(heldWeapon),
        tostring(rodHash)
    )
    if not Config.Tackle[usableTackle] then
        debugPrint('Rejected bait use because the tackle is not configured.')
        return
    end
    if fishing or nuiAttemptStarted or nuiOpen then
        debugPrint('Rejected bait use because another fishing action is active.')
        lib.notify({ title = 'Fishing', description = 'Finish or cancel the current cast before changing tackle.', type = 'inform' })
        return
    end
    if not rodHeld then
        debugPrint('Rejected bait use because the fishing rod was not detected.')
        lib.notify({ title = locale('cl_error'), description = locale('cl_you_need_use_your_fishing_rod_first'), type = 'error', duration = 7000 })
        return
    end

    closeFishingInfo()
    currentTackle = usableTackle
    fishing = true
    ready = false
    nuiAttemptStarted = false
    nuiResult = nil

    CreateThread(function()
        SetCurrentPedWeapon(cache.ped, rodHash, true)
        Wait(0)
        Citizen.InvokeNative(0x1096603B519C905F, "MMFSH")
        debugPrint('Started the fishing task for tackle %s.', tostring(currentTackle))
        prepareMyPrompt()
        local previousState = nil
        local previousMinigame = nil
        local lastWaitingLog = GetGameTimer()

        while fishing do
            GET_TASK_FISHING_DATA()
            local state = FISHING_GET_MINIGAME_STATE()

            if state ~= previousState or hasMinigameOn ~= previousMinigame then
                debugPrint('Fishing state changed: state=%s, minigameOn=%s, ready=%s.', tostring(state), tostring(hasMinigameOn), tostring(ready))
                previousState = state
                previousMinigame = hasMinigameOn
            elseif not ready and GetGameTimer() - lastWaitingLog >= 5000 then
                debugPrint('Still waiting for fishing ready state 1; current state=%s, minigameOn=%s.', tostring(state), tostring(hasMinigameOn))
                lastWaitingLog = GetGameTimer()
            end

            if state == 1 and not ready then
                ready = true
                debugPrint('Applying tackle %s to the hook.', tostring(currentTackle))
                TaskSwapFishingBait(cache.ped, currentTackle, 0)
                SetFishingBait(cache.ped, currentTackle, 0, 1)
                debugPrint('TaskSwapFishingBait and SetFishingBait were called.')
            end

            if IsControlJustPressed(0, GetHashKey("INPUT_TOGGLE_HOLSTER")) then
                fishing = false
                FISHING_SET_TRANSITION_FLAG(8)
                SetFishingBait(cache.ped, "", 0, 1)
            end

            if hasMinigameOn then
                if state == 2 then
                    FISHING_SET_F_(1, math.random(25.0, 30.0))
                elseif state == 6 and not nuiAttemptStarted then
                    nuiAttemptStarted = true
                    CreateThread(runNuiFishingAttempt)
                end
            end

            -- Poll every frame until ready so the state-1 bait window is not missed.
            Wait(ready and 4 or 0)
        end

        debugPrint('Fishing bait thread ended.')
        closeFishingNui()
        if nuiAttemptStarted then
            TriggerServerEvent('rsg-fishing:server:cancelAttempt')
        end
        nuiAttemptStarted = false
    end)
end)

CreateThread(function()
    prepareMyPrompt()
    while true do
        local waitTime = 1000
        if FISHING_GET_MINIGAME_STATE() == 1 then
            waitTime = 4
            PromptSetActiveGroupThisFrame(fishing_data.prompt_prepare_fishing.group, CreateVarString(10, "LITERAL_STRING", locale('cl_ready_to_fish')))
        end
        Wait(waitTime)
    end
end)

function GET_TASK_FISHING_DATA()
    local r = exports[GetCurrentResourceName()]:GET_TASK_FISHING_DATA_EXTRA()
    hasMinigameOn = r[1]
    local outAsInt = r[2]
    local outAsFloat = r[3]

    fishing_minigame_struct = {
        f_0 = outAsInt["0"],
        f_1 = outAsFloat["2"],
        f_2 = outAsFloat["4"],
        f_3 = outAsFloat["6"],
        f_4 = outAsFloat["8"],
        f_5 = outAsInt["10"],
        f_6 = outAsInt["12"],
        f_7 = outAsInt["14"],
        f_8 = outAsFloat["16"],
        f_9 = outAsFloat["18"],
        f_10 = outAsInt["20"],
        f_11 = outAsInt["22"],
        f_12 = outAsInt["24"],
        f_13 = outAsFloat["26"],
        f_14 = outAsFloat["28"],
        f_15 = outAsFloat["30"],
        f_16 = outAsInt["32"],
        f_17 = outAsFloat["34"],
        f_18 = outAsInt["36"],
        f_19 = outAsInt["38"],
        f_20 = outAsFloat["40"],
        f_21 = outAsFloat["42"],
        f_22 = outAsFloat["44"],
        f_23 = outAsFloat["46"],
        f_24 = outAsFloat["48"],
        f_25 = outAsFloat["50"],
        f_26 = outAsFloat["52"],
        f_27 = outAsFloat["54"]
    }
end


function SET_TASK_FISHING_DATA()
    if fishing_minigame_struct.f_0 ~= nil then
        exports[GetCurrentResourceName()]:SET_TASK_FISHING_DATA_EXTRA(fishing_minigame_struct)
    end
end

function FISHING_GET_F_(f)
    return fishing_minigame_struct["f_" .. f]
end

function FISHING_GET_MINIGAME_STATE()
    return FISHING_GET_F_(0)
end

function FISHING_GET_BOBBER_HANDLE()
    return FISHING_GET_F_(11)
end

function FISHING_GET_HOOK_HANDLE()
    return FISHING_GET_F_(12)
end

function FISHING_SET_F_(f, v)
    fishing_minigame_struct["f_" .. f] = v
    SET_TASK_FISHING_DATA()
end

function FISHING_SET_TRANSITION_FLAG(v)
    FISHING_SET_F_(6, v)
end


function GetNearbyFishs(coords, radius)
    local r = {}

    local itemSet = CreateItemset(true)
    local size = Citizen.InvokeNative(0x59B57C4B06531E1E, coords, radius, itemSet, 1, Citizen.ResultAsInteger())

    if size > 0 then
        for index = 0, size - 1 do
            local entity = GetIndexedItemInItemset(index, itemSet)
            if GetEntityPopulationType(entity) == 6 and not IsPedDeadOrDying(entity, 0) then
                table.insert(r, entity)
            end
        end
    end

    if IsItemsetValid(itemSet) then
        DestroyItemset(itemSet)
    end

    return r
end

local function unregisterEagleEyeFish(entity)
    if DoesEntityExist(entity) then
        Citizen.InvokeNative(0x9DAE1380CC5C6451, PlayerId(), entity)
    end
    eagleEyeFish[entity] = nil
end

CreateThread(function()
    if not Config.FishEagleEye.Enabled then return end

    while true do
        local nearby = {}
        local playerCoords = GetEntityCoords(cache.ped)

        for _, entity in pairs(GetNearbyFishs(playerCoords, Config.FishEagleEye.Range)) do
            if fishByHash[GetEntityModel(entity)] then
                nearby[entity] = true

                if not eagleEyeFish[entity] then
                    Citizen.InvokeNative(0x543DFE14BE720027, PlayerId(), entity, false)
                    Citizen.InvokeNative(0x907B16B3834C69E2, entity, Config.FishEagleEye.Range)
                    Citizen.InvokeNative(0x62ED71E133B6C9F1, entity, table.unpack(Config.FishEagleEye.Tint))
                    eagleEyeFish[entity] = true
                end
            end
        end

        for entity in pairs(eagleEyeFish) do
            if not nearby[entity] or not DoesEntityExist(entity) then
                unregisterEagleEyeFish(entity)
            end
        end

        Wait(Config.FishEagleEye.RefreshRate)
    end
end)


function prepareMyPrompt()
    if promptsPrepared then return end
    promptsPrepared = true

    fishing_data.prompt_prepare_fishing.group = GetRandomIntInRange(0, 0xffffff)
    local prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, GetHashKey("INPUT_AIM")) -- MOUSE LEFT CLICK
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_prepare_fishing_rod')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_prepare_fishing.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_prepare_fishing.change_bait = prompt

    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0x07CE1E61) -- LEFT CONTROL
    PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", locale('cl_cast_fishing_rod')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, false)
    PromptSetGroup(prompt, fishing_data.prompt_prepare_fishing.group)
    PromptRegisterEnd(prompt)
    fishing_data.prompt_prepare_fishing.throw_hook = prompt

end


AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        closeFishingNui()
        closeFishingInfo()
        SendNUIMessage({ action = 'closeAll' })
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        local prompts = {
            fishing_data.prompt_prepare_fishing.change_bait,
            fishing_data.prompt_prepare_fishing.throw_hook,
        }

        for _, prompt in pairs(prompts) do
            if prompt then PromptDelete(prompt) end
        end

        for entity in pairs(eagleEyeFish) do
            unregisterEagleEyeFish(entity)
        end
    end
end)
