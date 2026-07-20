local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local function debugPrint(message, ...)
    if not Config.Debug then return end
    print(('[Nt_Fishing:server] ' .. message):format(...))
end

local pendingAttempts = {}
local fishByHash = {}

for modelName, species in pairs(Config.FishByModelName) do
    fishByHash[GetHashKey(modelName)] = {
        species = species,
        item = string.lower(modelName),
        displayName = Config.fishData[modelName] and Config.fishData[modelName][1] or species.name,
    }
end

local largeFish = {
    [GetHashKey('A_C_FISHLAKESTURGEON_01_LG')] = true,
    [GetHashKey('A_C_FISHLONGNOSEGAR_01_LG')] = true,
    [GetHashKey('A_C_FISHMUSKIE_01_LG')] = true,
    [GetHashKey('A_C_FISHNORTHERNPIKE_01_LG')] = true,
}

local mediumFish = {
    [GetHashKey('A_C_FISHLARGEMOUTHBASS_01_LG')] = true,
    [GetHashKey('A_C_FISHLARGEMOUTHBASS_01_MS')] = true,
    [GetHashKey('A_C_FISHSALMONSOCKEYE_01_LG')] = true,
    [GetHashKey('A_C_FISHSALMONSOCKEYE_01_ML')] = true,
    [GetHashKey('A_C_FISHSALMONSOCKEYE_01_MS')] = true,
    [GetHashKey('A_C_FISHSMALLMOUTHBASS_01_LG')] = true,
    [GetHashKey('A_C_FISHSMALLMOUTHBASS_01_MS')] = true,
    [GetHashKey('A_C_FISHRAINBOWTROUT_01_LG')] = true,
    [GetHashKey('A_C_FISHRAINBOWTROUT_01_MS')] = true,
}

local function copyTable(value)
    if type(value) ~= 'table' then return {} end
    return json.decode(json.encode(value)) or {}
end

local function getFishWeight(fishModel)
    if largeFish[fishModel] then
        return math.random(350, 500) / 100
    elseif mediumFish[fishModel] then
        return math.random(100, 150) / 100
    end

    return math.random(13, 75) / 100
end

local function getAttraction(tackleName, fishModel)
    local fish = fishByHash[fishModel]
    if not fish then return 0 end
    return tonumber(fish.species.attraction[tackleName]) or 0
end

local function showItemBox(src, itemName, action)
    local item = RSGCore.Shared.Items[itemName]
    if item then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, item, action, 1)
    end
end

local function returnHeldTackle(src, attempt)
    if not attempt or not attempt.held then return true end

    local added = exports['rsg-inventory']:AddItem(
        src,
        attempt.tackle,
        1,
        nil,
        copyTable(attempt.held.info),
        'fishing-tackle-return'
    )

    attempt.held = nil
    return added ~= false
end

local function settleAttempt(src, lineSnapped)
    local attempt = pendingAttempts[src]
    pendingAttempts[src] = nil
    if not attempt then return true end

    local tackle = Config.Tackle[attempt.tackle]
    if not tackle then
        return returnHeldTackle(src, attempt)
    end

    local consumed = tackle.natural and attempt.baitTaken or (not tackle.natural and lineSnapped == true)
    if consumed then
        showItemBox(src, attempt.tackle, 'remove')
        attempt.held = nil
        return true
    end

    return returnHeldTackle(src, attempt)
end

local function holdTackle(src, tackleName)
    local item = exports['rsg-inventory']:GetItemByName(src, tackleName)
    if not item or (item.amount or 0) < 1 then return nil end

    local held = {
        slot = item.slot,
        info = copyTable(item.info),
    }

    local removed = exports['rsg-inventory']:RemoveItem(
        src,
        tackleName,
        1,
        item.slot,
        'fishing-tackle-hold'
    )

    if not removed then return nil end
    return held
end

local function rewardFish(src, fishModel, weight)
    local Player = RSGCore.Functions.GetPlayer(src)
    local fish = fishByHash[fishModel]
    if not Player or not fish then return false end

    local fishWeight = string.format('%.2f', weight)
    local added = exports['rsg-inventory']:AddItem(
        src,
        fish.item,
        1,
        nil,
        { weight = fishWeight },
        'fishing-catch'
    )
    if added == false then return false end

    showItemBox(src, fish.item, 'add')
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('sv_you_got_fish_name') .. ' ' .. fish.displayName,
        type = 'success',
        duration = 5000,
    })

    local charinfo = Player.PlayerData.charinfo
    TriggerEvent(
        'rsg-log:server:CreateLog',
        'fishing',
        locale('sv_discord_b'),
        'green',
        charinfo.firstname .. ' ' .. charinfo.lastname .. ' ' .. locale('sv_discord_c') .. ' ' .. fishWeight .. 'KG ' .. fish.displayName
    )

    return true
end

local function initTackle()
    for _, tackleName in ipairs(Config.TackleOrder) do
        local itemName = tackleName
        RSGCore.Functions.CreateUseableItem(itemName, function(source, item)
            debugPrint(
                'Usable tackle callback: player=%s, registeredItem=%s, receivedItem=%s.',
                source,
                tostring(itemName),
                tostring(item and item.name)
            )
            if not item or item.name ~= itemName then
                debugPrint('Rejected usable tackle callback because its item data did not match.')
                return
            end
            debugPrint('Sending usebait event for %s to player %s.', tostring(itemName), source)
            TriggerClientEvent('rsg-fishing:client:usebait', source, itemName)
        end)
        debugPrint('Registered usable tackle item: %s.', tostring(itemName))
    end
end

lib.callback.register('rsg-fishing:server:startAttempt', function(source, tackleName, fishModel)
    if pendingAttempts[source] or not Config.Tackle[tackleName] then return false end

    fishModel = tonumber(fishModel)
    local fish = fishModel and fishByHash[fishModel]
    if not fish or getAttraction(tackleName, fishModel) <= 0 then return false end

    local held = holdTackle(source, tackleName)
    if not held then return false end

    local weight = getFishWeight(fishModel)
    pendingAttempts[source] = {
        tackle = tackleName,
        fishModel = fishModel,
        weight = weight,
        difficulty = fish.species.difficulty,
        startedAt = os.time(),
        biteOccurred = false,
        baitTaken = false,
        held = held,
    }

    return {
        accepted = true,
        weight = weight,
        difficulty = fish.species.difficulty,
    }
end)

lib.callback.register('rsg-fishing:server:markBite', function(source)
    local attempt = pendingAttempts[source]
    if not attempt or attempt.biteOccurred then return false end

    local minimumDuration = math.max(1, math.floor(Config.BiteDelayMin / 1000))
    if os.time() - attempt.startedAt < minimumDuration then return false end

    attempt.biteOccurred = true
    attempt.baitTaken = Config.Tackle[attempt.tackle].natural == true
    return true
end)

lib.callback.register('rsg-fishing:server:finishAttempt', function(source, result)
    local attempt = pendingAttempts[source]
    if not attempt then return false end

    if result == 'cancelled' then
        return settleAttempt(source, false)
    end

    if result == 'line_snapped' then
        if not attempt.biteOccurred then return false end
        return settleAttempt(source, true)
    end

    if result ~= 'success' or not attempt.biteOccurred then return false end

    local elapsed = os.time() - attempt.startedAt
    local maximumDuration = math.ceil((Config.BiteDelayMax + Config.FishingGame.Timeout + 10000) / 1000)
    if elapsed > maximumDuration then
        settleAttempt(source, false)
        return false
    end

    if not fishByHash[attempt.fishModel] or getAttraction(attempt.tackle, attempt.fishModel) <= 0 then
        settleAttempt(source, false)
        return false
    end

    local fishModel = attempt.fishModel
    local weight = attempt.weight
    if not settleAttempt(source, false) then return false end
    return rewardFish(source, fishModel, weight)
end)

RegisterNetEvent('rsg-fishing:server:cancelAttempt', function()
    settleAttempt(source, false)
end)

AddEventHandler('RSGCore:Server:PlayerDropped', function(Player)
    if Player and Player.PlayerData then
        settleAttempt(Player.PlayerData.source, false)
    end
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    settleAttempt(src, false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local sources = {}
    for src in pairs(pendingAttempts) do
        sources[#sources + 1] = src
    end
    for _, src in ipairs(sources) do
        settleAttempt(src, false)
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        initTackle()
    end
end)
