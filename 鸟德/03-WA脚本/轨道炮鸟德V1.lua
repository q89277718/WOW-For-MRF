--[[
轨道炮鸟德 V2 — by时光1凌姐
优化：哀冬
==================================
全局: 保持双DOT (targetDeadTime<5s不补) / 焦点双DOT(非选民期补) / 自然之赐+愤怒≤1秒→切星火
P0   前置: 枭兽 / 自然之力(Boss,可选) / 精灵之火(Boss或>20s)
P1   构筑: 叠3/3进月蚀 > 优先愤怒叠月亮 > 自然之赐切星火
P2   月蚀: 炮好开炮 > 炮未好填充(能量平衡交替愤怒/星火) > 续能量/续DOT
P3   月民: 星落(可选)>愤怒(耗星辰,触自然之赐切星火)>星火(耗苍穹焰)>补DOT>填充

]]
if WOW_PROJECT_ID ~= WOW_PROJECT_WRATH_CLASSIC then return end
if APL_DRUID_BALANCE_RAILGUN_CATGIRL then return end; APL_DRUID_BALANCE_RAILGUN_CATGIRL = true
local WAParam = aura_env

-- ==========================================
-- 技能 / Buff ID 表
-- ==========================================
local S = {
    Moonfire     = 48463,    -- 月火术 — 瞬发DoT，给 太阳能量 +1
    InsectSwarm  = 48468,    -- 虫群   — 瞬发DoT 给 月亮能量 +1
    Starfire     = 48465,    -- 星火术 — 2.5秒读条（吃急速），给 太阳能量 +1
    FaerieFire   = 770,      -- 精灵之火 — 瞬发，持续5分钟
    Starfall     = 53201,    -- 星辰坠落 — 1.5分钟CD，瞬发AoE，给 太阳能量 +1
    Wrath        = 48461,    -- 愤怒   — 1.5秒读条（吃急速），给 月亮能量 +1
    MoonkinForm  = 24858,    -- 枭兽形态
    Railgun      = 1309397,  -- 月神轨道炮 — 5秒读条，1分钟CD，需 月蚀buff 才能施放
    Hurricane    = 48467,    -- 飓风 — 引导AoE（调试用标记）
    ForceOfNature = 33831,   -- 自然之力 — 召唤3树人
    Innervate = 29166,       -- 激活
}

-- Buff ID 表
local B = {
    SolarEnergy  = 1309555,  -- 太阳能量
    LunarEnergy  = 1309554,  -- 月亮能量
    Eclipse      = 1309556,  -- 月蚀 — 双能量同时3层触发，持续20秒
    HeavenFire   = 1309559,  -- 苍穹之焰 — 轨道炮后获得5层，星火消耗1层
    StarWrath    = 1309558,  -- 星辰之怒 — 轨道炮后获得5层，愤怒消耗1层
    MoonChosen   = 1309557,  -- 月神选民 — 轨道炮施放后获得，增伤标记
    NatureGrace  = 16886,    -- 自然之赐 — 星火/愤怒暴击触发，持续5s，+15%施法速度
}

local MAX_ENERGY = 3

-- Focus 偏移量
local FOCUS_OFFSET = 100000

-- ==========================================
-- ActionList
-- ==========================================
local ActionList = {
    {S.Moonfire,    "spell", "月火术"},
    {S.InsectSwarm, "spell", "虫群"},
    {S.Starfire,    "spell", "星火术"},
    {S.FaerieFire,  "spell", "精灵之火"},
    {S.Starfall,    "spell", "星辰坠落"},
    {S.Wrath,       "spell", "愤怒"},
    {S.Hurricane,   "spell", "飓风"},
    {S.MoonkinForm, "spell", "枭兽形态"},
    {S.ForceOfNature, "macro", "/cast [@Cursor] 自然之力\\n/petdefensive\\n/petattack", GetSpellTexture("自然之力")},
    {S.Innervate, "macro", "/cast [@player] 激活", GetSpellTexture("激活")},
    {S.Railgun, "macro", "/cqs\\n/use 10\\n/use 13\\n/use 14\\n/cast 月神轨道炮\\n/cqs", GetSpellTexture("月神轨道炮")},
    {(0-S.Railgun), "macro", "/cqs\\n/use 10\\n/cast 月神轨道炮\\n/cqs", GetSpellTexture("月神轨道炮")},
    --{-1309554, "macro", "/cancelaura 月亮能量", 236151},
    {-101, "item", 10},
    {S.InsectSwarm + FOCUS_OFFSET, "macro", "/cast [target=focus] 虫群",   GetSpellTexture("虫群")},
    {S.Moonfire    + FOCUS_OFFSET, "macro", "/cast [target=focus] 月火术", GetSpellTexture("月火术")},
    {6603, "macro", "/targetenemy [dead][noharm]"},
}

-- 玩家剩余蓝量百分比
local function PlayerManaPct()
    local mana = UnitPower("player", 0)
    local maxMana = UnitPowerMax("player", 0)
    return maxMana > 0 and (mana / maxMana) * 100 or 100
end

-- 主优先级逻辑
local function APLCallback()
    -- 读取所有状态
    local CastWindow = GetCVar("SpellQueueWindow")/1000
    local now = GetTime()
    local inCombat = UnitAffectingCombat("player")
    local inBoss = ((IsEncounterInProgress() or IsResting()) and UnitLevel("target") == -1)
    local targetDeadTime = VF_getTargetDeadTime()
    local castingSpellName, _, _, _, endTimeMs = UnitCastingInfo("player")
    local GCD = VF_getSpellCD(61304)
    if castingSpellName ~= nil then 
        GCD = math.max((endTimeMs/1000 - now), GCD)
    end
    local function cd(id) return math.max(0, VF_getSpellCD(id) - GCD) end
    
    local railgunCD = cd(S.Railgun)
    -- 每帧取含急速的读条时间（GetSpellInfo 已含急速，不额外除）
    local wrathCT = (select(4, GetSpellInfo("愤怒"))) / 1000
    local starfireCT = (select(4, GetSpellInfo("星火术"))) / 1000
    local railgunCT = (select(4, GetSpellInfo("月神轨道炮"))) / 1000
    
    -- 自身 buff
    local moonChosenDur = math.max(0, VF_getBuff("player", B.MoonChosen,  "HELPFUL|PLAYER") - GCD)
    local eclipseDur = math.max(0, VF_getBuff("player", B.Eclipse,     "HELPFUL|PLAYER") - GCD)
    local solarDur, solarStacks = VF_getBuff("player", B.SolarEnergy, "HELPFUL|PLAYER")
    local lunarDur, lunarStacks = VF_getBuff("player", B.LunarEnergy, "HELPFUL|PLAYER")
    solarDur = math.max(0, solarDur - GCD)
    lunarDur = math.max(0, lunarDur - GCD)
    local _, hStacks = VF_getBuff("player", B.HeavenFire,  "HELPFUL|PLAYER")
    local _, wStacks = VF_getBuff("player", B.StarWrath,   "HELPFUL|PLAYER")
    local natureGrace = math.max(0, VF_getBuff("player", B.NatureGrace, "HELPFUL|PLAYER") - GCD)
    
    -- 目标 debuff
    local isRem = math.max(0, VF_getDebuff("target", S.InsectSwarm, "HARMFUL|PLAYER") - math.max(0,GCD-0.1))
    local mfRem = math.max(0, VF_getDebuff("target", S.Moonfire,    "HARMFUL|PLAYER") - math.max(0,GCD-0.1))
    
    -- 焦点 debuff
    local focusIsRem = 999
    local focusMfRem = 999
    local hasValidFocus = false
    if UnitExists("focus") and not UnitIsDead("focus") and not UnitIsUnit("focus", "player")
    and UnitCanAttack("player", "focus")
    and IsSpellInRange(GetSpellInfo(S.Moonfire), "focus") == 1 then
        hasValidFocus = true
        focusIsRem = math.max(0, (VF_getDebuff("focus", S.InsectSwarm, "HARMFUL|PLAYER") or 0) - math.max(0, GCD-0.1))
        focusMfRem = math.max(0, (VF_getDebuff("focus", S.Moonfire, "HARMFUL|PLAYER") or 0) - math.max(0, GCD-0.1))
    end
    
    -- 施法期间预测
    if castingSpellName == "月神轨道炮" then
        railgunCD = 60
        eclipseDur = 0
        moonChosenDur = 20
        solarDur = 0
        solarStacks = 0
        lunarDur = 0
        lunarStacks = 0
        hStacks = 5
        wStacks = 5
    elseif castingSpellName == "星火术" then
        inCombat = true
        if solarDur > 0 then
            if solarStacks == MAX_ENERGY-1 and lunarDur > 0 and lunarStacks >= MAX_ENERGY then
                eclipseDur = 20
            end
            solarStacks = math.max(MAX_ENERGY, solarStacks+1)
        else
            solarStacks = 1
        end
        solarDur = 20
        if hStacks > 0 then
            hStacks = hStacks - 1
        end
    elseif castingSpellName == "愤怒" then
        inCombat = true
        if lunarDur > 0 then
            if lunarStacks == MAX_ENERGY-1 and solarDur > 0 and solarStacks >= MAX_ENERGY then
                eclipseDur = 20
            end
            lunarStacks = math.max(MAX_ENERGY, lunarStacks+1)
        else
            lunarStacks = 1
        end
        lunarDur = 20
        if wStacks > 0 then
            wStacks = wStacks - 1
        end
    end
    
    -- P0: 前置
    -- 非法目标检查
    if  (UnitExists("target") == nil) or (UnitCanAttack("player","target") == false) or UnitIsDead("target") then
        return 6603
    end
    
    -- 枭兽形态
    if VF_getBuff("player", S.MoonkinForm, "HELPFUL|PLAYER") <= 0 then
        return S.MoonkinForm
    end
    
    -- 星火预读（可选）
    if not inCombat and (WAParam.config and WAParam.config.Prepull) then
        return S.Starfire
    end
    
    -- 自然之力（可选）
    if (WAParam.config and WAParam.config.ForceOfNature) and inBoss and inCombat and cd(S.ForceOfNature) <= CastWindow then
        return S.ForceOfNature
    end
    
    -- 相对宽裕的冲层期丢精灵火和激活
    if eclipseDur <= 0 and moonChosenDur <= 0 then
        -- 精灵之火
        if inBoss or targetDeadTime > 20 then
            local anyFF = VF_getDebuff("target", S.FaerieFire, "HARMFUL")
            if anyFF == 0 then
                return S.FaerieFire
            end
        end
        -- 自动激活
        if WAParam.config.Innervate and cd(S.Innervate) < CastWindow and PlayerManaPct() < 50 then
            return S.Innervate
        end
    end
    
    -- 全局: DOT 维护
    local noDOT = (targetDeadTime > 0 and targetDeadTime < 5)
    if not noDOT then
        if isRem <= 0 then return S.InsectSwarm end
        if mfRem <= 0 then return S.Moonfire end
        -- 焦点 DOT 维护（优先级低于主目标，选民带强化buff期不补）
        if hStacks <= 0 and wStacks <= 0 and hasValidFocus and focusIsRem <= 0 then return S.InsectSwarm + FOCUS_OFFSET end
        if hStacks <= 0 and wStacks <= 0 and hasValidFocus and focusMfRem <= 0 then return S.Moonfire + FOCUS_OFFSET end
    end
    
    -- P4: 月神选民
    if moonChosenDur > 0 and castingSpellName ~= "月神轨道炮" then
        -- 星落 CD 好（可选）
        if (WAParam.config and WAParam.config.Starfall) and cd(S.Starfall) <= CastWindow then
            return S.Starfall
        end
        
        -- 苍穹之焰还在 或 都耗尽 → 优先消耗：自然之赐不够赌2个愤怒或愤怒<1秒→星火，否则愤怒
        if hStacks > 0 or wStacks <= 0 then
            if (natureGrace>math.min(starfireCT,2*wrathCT) or (natureGrace>0 and natureGrace<wrathCT)) or wrathCT < 1 then
                return S.Starfire
            end
            return S.Wrath
        end
        
        -- 苍穹之焰耗尽 → 星辰之怒还在 → 愤怒打完
        if wStacks > 0 then
            return S.Wrath
        end
    end
    
    -- P3: 月蚀 + 炮就绪 → 根据节奏开炮
    if eclipseDur > railgunCT + railgunCD and railgunCD <= CastWindow 
    and ((targetDeadTime <= 20 or targetDeadTime > 20 + eclipseDur - railgunCT)
        or (eclipseDur < railgunCT + railgunCD + starfireCT))then
        -- 能量未满3 → 补足再开炮（防预测虚高导致能量不足，几乎不可能走到）
        if solarStacks < MAX_ENERGY then return S.Moonfire end
        if lunarStacks < MAX_ENERGY then return S.InsectSwarm end
        
        if inCombat then
            if inBoss then return S.Railgun end     -- 全爆发 + 轨道炮
            return (0-S.Railgun)                         -- 手套 + 轨道炮
        else
            return 6603                           -- 正在读炮或脱战 → 等着，不往下掉
        end
    end
    
    -- P5: 月蚀 + 炮 CD 中/击杀时间在月蚀与选民微妙的节奏中 调控节奏
    if eclipseDur > 0 and (railgunCD > CastWindow or (targetDeadTime > 20 and targetDeadTime <= 20 + eclipseDur - railgunCT)) then
        
        -- 日月能维护
        if solarDur <= starfireCT+0.5 then return S.Starfire end
        if lunarDur <= starfireCT+0.5 then return S.Wrath end--用starfireCT是因为星火也要吃增伤
        
        if railgunCD <= 3 and not noDOT then              -- 炮快好了，确保 DOT 覆盖到开炮后
            local threshold = railgunCT + railgunCD
            if isRem < threshold then return S.InsectSwarm end
            if mfRem < threshold then return S.Moonfire end
        end
        
        -- 万一月亮未满 → 愤怒叠月亮
        if lunarStacks < MAX_ENERGY then
            return S.Wrath
        end
        -- 万一太阳未满 → 星火补太阳
        if solarStacks < MAX_ENERGY then
            return S.Starfire
        end
        -- 双满兜底 → 自然之赐或愤怒<1秒 → 星火
        if (natureGrace>math.min(starfireCT,2*wrathCT) or (natureGrace>0 and natureGrace<wrathCT)) or wrathCT < 1 then
            return S.Starfire
        end
        return S.Wrath
    end
    
    -- P1: 冲月蚀
    if eclipseDur == 0 and moonChosenDur == 0 then
        
        -- 日月能维护
        if solarDur <= starfireCT+0.5 then return S.Starfire end
        if lunarDur <= starfireCT+0.5 then return S.Wrath end--用starfireCT是因为星火也要吃增伤
        
        if railgunCD <= 3 and not noDOT then              -- 炮快好了，确保 DOT 覆盖到开炮后
            local threshold = railgunCT + railgunCD
            if isRem < threshold then return S.InsectSwarm end
            if mfRem < threshold then return S.Moonfire end
        end
        
        -- 自然之赐 
        if (natureGrace>math.min(starfireCT,2*wrathCT) or (natureGrace>0 and natureGrace<wrathCT)) and solarStacks < MAX_ENERGY then
            return S.Starfire
        end
        
        -- 愤怒冲月亮 
        if lunarStacks < MAX_ENERGY then
            return S.Wrath
        end
        
        -- 月亮满3 → 星火冲太阳
        if solarStacks < MAX_ENERGY then
            return S.Starfire
        end
        
        -- 双满 → 等月蚀触发，P3接手
        return 6603
    end
    
    -- 兜底
    return 6603
end

aura_env.APLActionList = ActionList
aura_env.APLCallback = APLCallback
aura_env.APLName = "凌小猫娘"

