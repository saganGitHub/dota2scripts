local Draw = require("Draw")
local Dict = require("Dict")

local Detect = {}

local option = Menu.AddOption({ "Awareness" }, "Detect", "Alerts you when certain abilities are used.")

local heroList = {}

-- index -> {name = Str; entity = Object; pos = Vector(), time = Int}
local posInfo = {}

-- index -> spellname
local particleInfo = {}

-- only for few cases
-- index -> heroName
local particleHero = {}

-- For particle effects that cant be tracked by OnParticleUpdateEntity(),
-- but have name info from OnParticleCreate() and position info from OnParticleUpdate()
-- (has been replaced by Dict.Phrase2HeroName())
-- spellname -> heroname 
local spellName2heroName = {}

-- know particle's index, spellname; have chance to know entity
-- Entity.GetAbsOrigin(particle.entity) is not correct. It just shows last seen position.
-- NPC.GetUnitName(particle.entity) can be useful, like know blink start position, smoke position, etc
function Detect.OnParticleCreate(particle)
    if not particle or not particle.index then return end
    local text = "1. OnParticleCreate: " .. tostring(particle.index) .. " " .. particle.name .. " " .. NPC.GetUnitName(particle.entity)
    -- Log.Write(text)
    particleInfo[particle.index] = particle.name

    if particle.entity then 
        particleHero[particle.index] = NPC.GetUnitName(particle.entity)
    end
end

-- know particle's index, position
function Detect.OnParticleUpdate(particle)
    if not particle or not particle.index then return end
    if not particleInfo[particle.index] then return end

    local spellname = particleInfo[particle.index]
    local name = Dict.Phrase2HeroName(spellname)
    if not name or name == "" then name = particleHero[particle.index] end

    text = "2. OnParticleUpdate: " .. tostring(particle.index) .. " " .. tostring(particle.position)
    -- Log.Write(text)
    Detect.Update(name, nil, particle.position, GameRules.GetGameTime())
end

-- know particle's index, position, entity
function Detect.OnParticleUpdateEntity(particle)
    if not particle then return end
    if not particle.entity or not NPC.IsHero(particle.entity) then return end

    local text = "3. OnParticleUpdateEntity: " .. tostring(particle.index) .. " " .. NPC.GetUnitName(particle.entity) .. " " .. tostring(particle.position)
    -- Log.Write(text)
    Detect.Update(NPC.GetUnitName(particle.entity), particle.entity, particle.position, GameRules.GetGameTime())
end

function Detect.Update(name, entity, pos, time)
    if not posInfo then return end

    local info = {}
    for i, val in ipairs(posInfo) do
        if val.name == name then
            if name then info.name = name end
            if entity then info.entity = entity end
            if pos then info.pos = pos end
            if time then info.time = time end
            posInfo[i] = info
            return
        end
    end

    info.name, info.entity, info.pos, info.time = name, entity, pos, time
    table.insert(posInfo, info)
end

function Detect.OnDraw()
    if not Menu.IsEnabled(option) then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    -- update hero list
    for i = 1, Heroes.Count() do
        local hero = Heroes.Get(i)
        local name = NPC.GetUnitName(hero)
        if not heroList[name] and not NPC.IsIllusion(hero) then
            heroList[name] = hero
        end
    end

    -- threshold for elapsed time
    local threshold = 3

    Draw.DrawMap()

    for i, info in ipairs(posInfo) do
        if info and info.name and info.pos and info.time and math.abs(GameRules.GetGameTime() - info.time) <= threshold then

            -- no need to draw visible enemy hero on the ground
            if not heroList[info.name] or Entity.IsDormant(heroList[info.name]) then
                Draw.DrawHeroOnGround(info.name, info.pos)
            end

            -- no need to draw ally
            if not heroList[info.name] or not Entity.IsSameTeam(myHero, heroList[info.name]) then
                Draw.DrawHeroOnMap(info.name, info.pos)
            end
        end
    end
end

return Detect