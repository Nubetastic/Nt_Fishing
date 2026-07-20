Config = {}

Config.Debug = false
Config.FishScanRadius = 20.0
Config.BiteDelayMin = 10000
Config.BiteDelayMax = 30000

Config.FishingGame = {
    RequiredWins = 3,
    RequiredLosses = 3,
    MaxRounds = 5,
    Timeout = 20000,
    SpeedIncreasePerRound = 2,
    StruggleCheckInterval = 500,
    StruggleCooldown = 3000,
    JitterJumpTime = 50, -- milliseconds between jumps; duration / this value controls the approximate jump count
}

Config.StruggleMethods = {
    Jitter = true,  -- every struggle jitters first; disabling this disables struggles
    Reverse = true, -- after jitter, may reverse the marker's direction
    Jump = true,    -- after jitter, may jump without changing travel direction
}

Config.Difficulties = {
    easy = {
        targetWidth = 16,
        markerSpeed = 50,
        struggleChance = 30,
        struggleDuration = 500,
        struggleDistanceMin = 2,
        struggleDistanceMax = 8,
    },
    standard = {
        targetWidth = 14,
        markerSpeed = 60,
        struggleChance = 40,
        struggleDuration = 1000,
        struggleDistanceMin = 2,
        struggleDistanceMax = 10,
    },
    hard = {
        targetWidth = 12,
        markerSpeed = 70,
        struggleChance = 50,
        struggleDuration = 1500,
        struggleDistanceMin = 2,
        struggleDistanceMax = 12,
    },
    veryHard = {
        targetWidth = 10,
        markerSpeed = 80,
        struggleChance = 60,
        struggleDuration = 2000,
        struggleDistanceMin = 2,
        struggleDistanceMax = 14,
    },
}

Config.FishEagleEye = {
    Enabled = true,
    Range = 35.0,
    RefreshRate = 1000,
    Tint = { 80, 160, 255 },
}

Config.TackleOrder = {
    "p_baitbread01x",
    "p_baitcorn01x",
    "p_baitcheese01x",
    "p_baitworm01x",
    "p_baitcricket01x",
    "p_crawdad01x",
    "p_finishedragonfly01x",
    "p_finisdfishlure01x",
    "p_finishdcrawd01x",
    "p_finishedragonflylegendary01x",
    "p_finisdfishlurelegendary01x",
    "p_finishdcrawdlegendary01x",
    "p_lgoc_spinner_v4",
    "p_lgoc_spinner_v6",
}

Config.Tackle = {
    p_baitbread01x = { label = "Bread Bait", image = "p_baitbread01x.png", natural = true },
    p_baitcorn01x = { label = "Corn Bait", image = "p_baitcorn01x.png", natural = true },
    p_baitcheese01x = { label = "Cheese Bait", image = "p_baitcheese01x.png", natural = true },
    p_baitworm01x = { label = "Worm Bait", image = "p_baitworm01x.png", natural = true },
    p_baitcricket01x = { label = "Cricket Bait", image = "p_baitcricket01x.png", natural = true },
    p_crawdad01x = { label = "Crawfish Bait", image = "p_crawdad01x.png", natural = true },
    p_finishedragonfly01x = { label = "Dragonfly Lure (River)", image = "p_finishedragonfly01x.png", natural = false },
    p_finisdfishlure01x = { label = "Fish Lure (Lake)", image = "p_finisdfishlure01x.png", natural = false },
    p_finishdcrawd01x = { label = "Crawfish Lure (Swamp)", image = "p_finishdcrawd01x.png", natural = false },
    p_finishedragonflylegendary01x = { label = "Legendary Dragonfly Lure", image = "p_finishedragonflylegendary01x.png", natural = false },
    p_finisdfishlurelegendary01x = { label = "Legendary Fish Lure", image = "p_finisdfishlurelegendary01x.png", natural = false },
    p_finishdcrawdlegendary01x = { label = "Legendary Crawfish Lure", image = "p_finishdcrawdlegendary01x.png", natural = false },
    p_lgoc_spinner_v4 = { label = "Spinner", image = "p_lgoc_spinner_v4.png", natural = false },
    p_lgoc_spinner_v6 = { label = "Improved Spinner", image = "p_lgoc_spinner_v6.png", natural = false },
}

-- Attraction values follow Config.TackleOrder. Zero means the combination is invalid.
local function attraction(values)
    local result = {}
    for index = 1, #Config.TackleOrder do
        local weight = values[index] or 0
        if weight > 0 then
            result[Config.TackleOrder[index]] = weight
        end
    end
    return result
end

--[[
    ATTRACTION GUIDE

    Each number in attraction({ ... }) matches a tackle in Config.TackleOrder.
    Keep all 14 values in this exact left-to-right order when adding or editing fish.

    These values are relative selection weights, not percentages:
      0   = this tackle cannot catch the fish
      1-34  = low attraction
      35-69 = medium attraction
      70-100 = high attraction

    Example: if two nearby fish have weights 100 and 50 for the equipped tackle,
    the first fish is twice as likely to be selected. Values may exceed 100, but
    using 0-100 makes the guide and catch matrix easier to understand.

    Horizontal reference (position and short name):

      1 Bread | 2 Corn | 3 Cheese | 4 Worm | 5 Cricket | 6 Crawdad | 7 Dragonfly
      8 FishLure | 9 CrawfishLure | 10 LegDragonfly | 11 LegFishLure
      12 LegCrawfish | 13 Spinner | 14 ImprovedSpinner

    Copy-ready template:

    {
        id = "fish_id", name = "Fish Name", image = "fish_image.png", difficulty = "standard",
        models = { "A_C_FISH_MODEL" },
        preferred = { "p_baitworm01x" },
        --                          Bread,  Corn,   Cheese, Worm,   Cricket,    Crawdad,    Dragonfly,  FishLure,   CrawfishLure,   LegDragonfly,   LegFishLure,    LegCrawfish,    Spinner,    ImprovedSpinner
        attraction = attraction({   0,      0,      0,      0,      0,          0,          0,          0,          0,              0,              0,              0,              0,          0 }),
    },

    Full tackle-name reference:
      1  p_baitbread01x
      2  p_baitcorn01x
      3  p_baitcheese01x
      4  p_baitworm01x
      5  p_baitcricket01x
      6  p_crawdad01x
      7  p_finishedragonfly01x
      8  p_finisdfishlure01x
      9  p_finishdcrawd01x
      10 p_finishedragonflylegendary01x
      11 p_finisdfishlurelegendary01x
      12 p_finishdcrawdlegendary01x
      13 p_lgoc_spinner_v4
      14 p_lgoc_spinner_v6
]]

Config.FishSpecies = {
    {
        id = "bluegill", name = "Bluegill", image = "a_c_fishbluegil_01_ms.png", difficulty = "easy",
        models = { "A_C_FISHBLUEGIL_01_MS", "A_C_FISHBLUEGIL_01_SM" },
        preferred = { "p_baitcheese01x" },
        attraction = attraction({ 35, 35, 100, 20, 20, 5, 5, 5, 5, 10, 10, 10, 20, 30 }),
    },
    {
        id = "bullhead_catfish", name = "Bullhead Catfish", image = "a_c_fishbullheadcat_01_ms.png", difficulty = "easy",
        models = { "A_C_FISHBULLHEADCAT_01_MS", "A_C_FISHBULLHEADCAT_01_SM" },
        preferred = { "p_baitcorn01x" },
        attraction = attraction({ 35, 100, 35, 20, 10, 10, 5, 5, 10, 10, 10, 20, 20, 30 }),
    },
    {
        id = "chain_pickerel", name = "Chain Pickerel", image = "a_c_fishchainpickerel_01_ms.png", difficulty = "easy",
        models = { "A_C_FISHCHAINPICKEREL_01_MS", "A_C_FISHCHAINPICKEREL_01_SM" },
        preferred = { "p_baitcorn01x" },
        attraction = attraction({ 25, 100, 25, 20, 15, 10, 15, 10, 10, 25, 20, 20, 30, 40 }),
    },
    {
        id = "channel_catfish", name = "Channel Catfish", image = "a_c_fishchannelcatfish_01_lg.png", difficulty = "veryHard",
        models = { "A_C_FISHCHANNELCATFISH_01_LG", "A_C_FISHCHANNELCATFISH_01_XL" },
        preferred = { "p_finishdcrawd01x" },
        attraction = attraction({ 0, 0, 0, 5, 5, 15, 10, 20, 100, 20, 30, 100, 55, 75 }),
    },
    {
        id = "lake_sturgeon", name = "Lake Sturgeon", image = "a_c_fishlakesturgeon_01_lg.png", difficulty = "hard",
        models = { "A_C_FISHLAKESTURGEON_01_LG" },
        preferred = { "p_finisdfishlure01x" },
        attraction = attraction({ 0, 0, 0, 10, 10, 25, 20, 100, 40, 30, 100, 55, 60, 80 }),
    },
    {
        id = "largemouth_bass", name = "Largemouth Bass", image = "a_c_fishlargemouthbass_01_ms.png", difficulty = "standard",
        models = { "A_C_FISHLARGEMOUTHBASS_01_LG", "A_C_FISHLARGEMOUTHBASS_01_MS" },
        preferred = { "p_crawdad01x" },
        attraction = attraction({ 5, 5, 5, 35, 35, 100, 45, 65, 45, 60, 80, 60, 65, 85 }),
    },
    {
        id = "longnose_gar", name = "Longnose Gar", image = "a_c_fishlongnosegar_01_lg.png", difficulty = "veryHard",
        models = { "A_C_FISHLONGNOSEGAR_01_LG" },
        preferred = { "p_finishdcrawd01x" },
        attraction = attraction({ 0, 0, 0, 5, 5, 20, 10, 20, 100, 20, 30, 100, 55, 75 }),
    },
    {
        id = "muskie", name = "Muskie", image = "a_c_fishmuskie_01_lg.png", difficulty = "veryHard",
        models = { "A_C_FISHMUSKIE_01_LG" },
        preferred = { "p_finisdfishlure01x" },
        attraction = attraction({ 0, 0, 0, 10, 10, 20, 30, 100, 20, 45, 100, 30, 60, 80 }),
    },
    {
        id = "northern_pike", name = "Northern Pike", image = "a_c_fishnorthernpike_01_lg.png", difficulty = "veryHard",
        models = { "A_C_FISHNORTHERNPIKE_01_LG" },
        preferred = { "p_finishedragonfly01x" },
        attraction = attraction({ 0, 0, 0, 10, 15, 20, 100, 40, 20, 100, 55, 30, 60, 80 }),
    },
    {
        id = "perch", name = "Perch", image = "a_c_fishperch_01_ms.png", difficulty = "easy",
        models = { "A_C_FISHPERCH_01_MS", "A_C_FISHPERCH_01_SM" },
        preferred = { "p_baitbread01x" },
        attraction = attraction({ 100, 35, 35, 20, 20, 5, 10, 15, 5, 20, 25, 10, 25, 35 }),
    },
    {
        id = "redfin_pickerel", name = "Redfin Pickerel", image = "a_c_fishredfinpickerel_01_ms.png", difficulty = "easy",
        models = { "A_C_FISHREDFINPICKEREL_01_MS", "A_C_FISHREDFINPICKEREL_01_SM" },
        preferred = { "p_baitbread01x" },
        attraction = attraction({ 100, 35, 35, 20, 20, 5, 15, 5, 10, 25, 10, 20, 25, 35 }),
    },
    {
        id = "rock_bass", name = "Rock Bass", image = "a_c_fishrockbass_01_ms.png", difficulty = "standard",
        models = { "A_C_FISHROCKBASS_01_MS", "A_C_FISHROCKBASS_01_SM" },
        preferred = { "p_baitcheese01x" },
        attraction = attraction({ 35, 35, 100, 60, 60, 25, 25, 35, 15, 35, 50, 25, 40, 55 }),
    },
    {
        id = "smallmouth_bass", name = "Smallmouth Bass", image = "a_c_fishsmallmouthbass_01_ms.png", difficulty = "standard",
        models = { "A_C_FISHSMALLMOUTHBASS_01_LG", "A_C_FISHSMALLMOUTHBASS_01_MS" },
        preferred = { "p_baitcricket01x" },
        attraction = attraction({ 5, 5, 5, 60, 100, 35, 100, 40, 20, 100, 55, 30, 65, 85 }),
    },
    {
        id = "sockeye_salmon", name = "Sockeye Salmon", image = "a_c_fishsalmonsockeye_01_ms.png", difficulty = "hard",
        models = { "A_C_FISHSALMONSOCKEYE_01_LG", "A_C_FISHSALMONSOCKEYE_01_ML", "A_C_FISHSALMONSOCKEYE_01_MS" },
        preferred = { "p_finishedragonfly01x" },
        attraction = attraction({ 0, 0, 0, 35, 35, 10, 100, 25, 10, 100, 40, 20, 60, 80 }),
    },
    {
        id = "steelhead_trout", name = "Steelhead Trout", image = "a_c_fishrainbowtrout_01_ms.png", difficulty = "standard",
        models = { "A_C_FISHRAINBOWTROUT_01_LG", "A_C_FISHRAINBOWTROUT_01_MS" },
        preferred = { "p_baitworm01x" },
        attraction = attraction({ 5, 5, 5, 100, 35, 15, 60, 100, 25, 75, 100, 40, 65, 85 }),
    },
}

Config.FishByModelName = {}

for _, species in ipairs(Config.FishSpecies) do
    for _, modelName in ipairs(species.models) do
        Config.FishByModelName[modelName] = species
    end
end

-- Existing game labels retained for compatibility with the native fishing prompts.
Config.fishData = {
    A_C_FISHBLUEGIL_01_MS        = { "Blue Gil (Medium)", "PROVISION_FISH_BLUEGILL", "PROVISION_BLUEGILL_DESC" },
    A_C_FISHBLUEGIL_01_SM        = { "Blue Gil (Small)", "PROVISION_FISH_BLUEGILL", "PROVISION_BLUEGILL_DESC" },
    A_C_FISHBULLHEADCAT_01_MS    = { "Bullhead Cat (Medium)", "PROVISION_FISH_BULLHEAD_CATFISH", "PROVISION_BLUEGILL_DESC" },
    A_C_FISHBULLHEADCAT_01_SM    = { "Bullhead Cat (Small)", "PROVISION_FISH_BULLHEAD_CATFISH", "PROVISION_BLUEGILL_DESC" },
    A_C_FISHCHAINPICKEREL_01_MS  = { "Chain Pickerel (Medium)", "PROVISION_FISH_CHAIN_PICKEREL", "PROVISION_CHNPKRL_DESC" },
    A_C_FISHCHAINPICKEREL_01_SM  = { "Chain Pickerel (Small)", "PROVISION_FISH_CHAIN_PICKEREL", "PROVISION_CHNPKRL_DESC" },
    A_C_FISHCHANNELCATFISH_01_LG = { "Channel Catfish (Large)", "PROVISION_FISH_CHANNEL_CATFISH", "PROVISION_CHNCATFSH_DESC" },
    A_C_FISHCHANNELCATFISH_01_XL = { "Channel Catfish (Extra Large)", "PROVISION_FISH_CHANNEL_CATFISH", "PROVISION_CHNCATFSH_DESC" },
    A_C_FISHLAKESTURGEON_01_LG   = { "Lake Sturgeon (Large)", "PROVISION_FISH_LAKE_STURGEON", "PROVISION_LKSTURG_DESC" },
    A_C_FISHLARGEMOUTHBASS_01_LG = { "Large Mouth Bass (Large)", "PROVISION_FISH_LARGEMOUTH_BASS", "PROVISION_LRGMTHBASS_DESC" },
    A_C_FISHLARGEMOUTHBASS_01_MS = { "Large Mouth Bass (Medium)", "PROVISION_FISH_LARGEMOUTH_BASS", "PROVISION_LRGMTHBASS_DESC" },
    A_C_FISHLONGNOSEGAR_01_LG    = { "Long Nose Gar (Large)", "PROVISION_FISH_LONGNOSE_GAR", "PROVISION_LNGNOSEGAR_DESC" },
    A_C_FISHMUSKIE_01_LG         = { "Muskie (Large)", "PROVISION_FISH_MUSKIE", "PROVISION_MUSKIE_DESC" },
    A_C_FISHNORTHERNPIKE_01_LG   = { "Northern Pike (Large)", "PROVISION_FISH_NORTHERN_PIKE", "PROVISION_NPIKE_DESC" },
    A_C_FISHPERCH_01_MS          = { "Perch (Medium)", "PROVISION_FISH_PERCH", "PROVISION_PERCH_DESC" },
    A_C_FISHPERCH_01_SM          = { "Perch (Small)", "PROVISION_FISH_PERCH", "PROVISION_PERCH_DESC" },
    A_C_FISHRAINBOWTROUT_01_LG   = { "Rainbow Trout (Large)", "PROVISION_FISH_STEELHEAD_TROUT", "PROVISION_FISH_STHDTROUT_DESC" },
    A_C_FISHRAINBOWTROUT_01_MS   = { "Rainbow Trout (Medium)", "PROVISION_FISH_STEELHEAD_TROUT", "PROVISION_FISH_STHDTROUT_DESC" },
    A_C_FISHREDFINPICKEREL_01_MS = { "Red Fin Pickerel (Medium)", "PROVISION_FISH_REDFIN_PICKEREL", "PROVISION_RDFNPCKREL_DESC" },
    A_C_FISHREDFINPICKEREL_01_SM = { "Red Fin Pickerel (Small)", "PROVISION_FISH_REDFIN_PICKEREL", "PROVISION_RDFNPCKREL_DESC" },
    A_C_FISHROCKBASS_01_MS       = { "Rock Bass (Medium)", "PROVISION_FISH_ROCK_BASS", "PROVISION_ROCKBASS_DESC" },
    A_C_FISHROCKBASS_01_SM       = { "Rock Bass (Small)", "PROVISION_FISH_ROCK_BASS", "PROVISION_ROCKBASS_DESC" },
    A_C_FISHSALMONSOCKEYE_01_LG  = { "Salmon Sockeye (Large)", "PROVISION_FISH_SOCKEYE_SALMON_LEGENDARY", "PROVISION_SCKEYESAL_DESC" },
    A_C_FISHSALMONSOCKEYE_01_ML  = { "Salmon Sockeye (Medium-Large)", "PROVISION_FISH_SOCKEYE_SALMON", "PROVISION_SCKEYESAL_DESC" },
    A_C_FISHSALMONSOCKEYE_01_MS  = { "Salmon Sockeye (Medium)", "PROVISION_FISH_SOCKEYE_SALMON", "PROVISION_SCKEYESAL_DESC" },
    A_C_FISHSMALLMOUTHBASS_01_LG = { "Small Mouth Bass (Large)", "PROVISION_FISH_SMALLMOUTH_BASS", "PROVISION_SMLMTHBASS_DESC" },
    A_C_FISHSMALLMOUTHBASS_01_MS = { "Small Mouth Bass (Medium)", "PROVISION_FISH_SMALLMOUTH_BASS", "PROVISION_SMLMTHBASS_DESC" },
}
