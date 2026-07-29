--[[
邪DK V2 — 纯优先级APL版 — by时光1凌姐
==================================
全局: 保持双病(冰霜疫病+血之疫病) / 孤寂buff≤3s补鲜血打击(5%增伤) / 食尸鬼狂乱≤5s补(活力分流+狂乱)
      符文追踪: 冰/邪/血各2枚(CLEU驱动+读条预测) / AOE: 每帧检测nameplate≥2目标→传染+凋零优先
P0   前置: 亡者复生(无宠物) / 白骨之盾(天鬼CD<10s) / 冰冷触摸(无冰霜疫病)
P1   爆发: (Boss战 + 石像鬼CD≤15s触发)
  1.  非绿脸→邪恶灵气(天鬼需要实时急速+15%)
  2.  无冰霜疫病→冰冷触摸 / 无血之疫病→暗影打击
  3.  石像鬼CD好+RP≥60→召唤石像鬼(快照AP)
  4.  手套就绪→加速手套+炸弹(让大军享受急速)
  5.  大军即将就绪→黑魔法宏
  6.  符文武器增效(重置全部符文+RP)
  7.  枯萎凋零(需blood+frost+unholy各≥1)
  8.  亡者大军
  9.  寒冬号角(RP≥60)
  10. 疾病≤3s→补病
  11. RP≥120→凋零缠绕泄能
  12. 天灾打击(frost+unholy) > 鲜血打击/血液沸腾(blood)
  13. 等待(符文全CD中)
  ↓ 爆发结束→自动切回鲜血灵气(红脸)
P2   平稳: (非爆发期)
  1.  冰霜疫病断→冰冷触摸 / 血之疫病断→暗影打击 / 冰霜疫病≤3s→补
  2.  [AOE] 枯萎凋零(≥2目标时最高优先) / 单体枯萎凋零(有符文时优先)
  3.  RP≥120→凋零缠绕泄能
  4.  食尸鬼狂乱≤5s+分流CD好→活力分流 / 分流CD中+狂乱≤8s→直接补狂乱
  5.  血之疫病≤5s→暗影打击(或AOE时传染)
  6.  [AOE] 传染(≥2目标时替代鲜血打击) / 孤寂≤3s→鲜血打击(单体)
  7.  天灾打击(frost+unholy) / 鲜血打击(blood,单体) / 血液沸腾(blood,AOE)
  8.  RP≥60→凋零缠绕 / RP<60+号角CD好→寒冬号角
  9.  鲜血打击兜底(blood符文) → 等待
爆发节奏: 石像鬼CD(3min)驱动 → CD≤15s进入爆发准备 → CD≤5s正式爆发+重置黑魔法
           大军CD(8min)且石像鬼已用(>150s) → 大军就绪也触发爆发
AOE: ≥2目标 → 鲜血打击→传染 / 枯萎凋零优先 / 天灾打击→血液沸腾
TODO: 孤寂buff ID待确认(当前用血之疫病剩余时间近似追踪)
]]
if WOW_PROJECT_ID ~= WOW_PROJECT_WRATH_CLASSIC then return end
if APL_UHSSDK_V2 then return end; APL_UHSSDK_V2 = true
local WAParam = aura_env
local win = GetCVar("SpellQueueWindow") / 1000

-- ==========================================
-- 技能 / Buff ID 表
-- ==========================================
local S = {
    IC     = 49909,   -- 冰冷触摸 — 远程上冰霜疫病，消耗frost符文
    PS     = 49921,   -- 暗影打击 — 近战上血之疫病，消耗unholy符文
    BS     = 49930,   -- 鲜血打击 — 消耗blood符文，触发孤寂5%增伤
    SS     = 55271,   -- 天灾打击 — 核心伤害，消耗frost+unholy符文
    BB     = 48721,   -- 血液沸腾 — 消耗blood符文，AOE填充
    DN     = 49938,   -- 枯萎凋零 — 消耗blood+frost+unholy符文
    DC     = 49895,   -- 凋零缠绕 — 消耗60RP，泄能/填充
    HN     = 57623,   -- 寒冬号角 — 消耗10RP，空闲填充
    GA     = 49206,   -- 召唤石像鬼 — 3分钟CD，爆发核心
    EW     = 47568,   -- 符文武器增效 — 5分钟CD，重置全部符文+RP
    AR     = 42650,   -- 亡者大军 — 8分钟CD，爆发核心
    BSH    = 49222,   -- 白骨之盾 — 防御buff
    BT     = 45529,   -- 活力分流 — 1分钟CD，转化符文
    GF     = 63560,   -- 食尸鬼狂乱 — 宠物buff +25%急速
    PE     = 50842,   -- 传染 — 消耗blood符文，传播双病(AOE)
    BP     = 48266,   -- 鲜血灵气 — 红脸 +15%伤害
    UP     = 48265,   -- 邪恶灵气 — 绿脸 +15%宠物急速
    RD     = 46584,   -- 亡者复生 — 召唤食尸鬼
    GLOVES = -112,    -- 加速手套（工程）
    IC_DEBUFF = 55095, -- 冰霜疫病debuff
    BP_DEBUFF = 49921, -- 血之疫病debuff（与暗影打击同ID）
}

local B = {
    Solitude    = 0,     -- TODO: 孤寂buff ID待确认(鲜血打击触发，5%增伤，20秒)
    GhoulFrenzy = 63560, -- 食尸鬼狂乱 — 宠物buff，持续30秒
    BoneShield  = 49222, -- 白骨之盾
}
-- 注意：孤寂buff当前用血之疫病剩余时间近似追踪(两者持续时间相近~20秒)
-- 待确认ID后，将solitudeDur改为VF_getBuff("player", B.Solitude, "HELPFUL|PLAYER")

-- ==========================================
-- 配置默认值
-- ==========================================
local cfg = {
    useGlovesAuto    = WAParam.config and WAParam.config.useGlovesAuto or true,
    autoBossBurst    = WAParam.config and WAParam.config.autoBossBurst or true,
    useDeathCoil     = WAParam.config and WAParam.config.useDeathCoil or true,
    pestilenceTargets = (WAParam.config and WAParam.config.pestilenceTargets) or 2,
    usePestilence    = WAParam.config and WAParam.config.usePestilence ~= false,
    useSpeedPotion   = WAParam.config and WAParam.config.useSpeedPotion or false,
    rpDumpThreshold = (WAParam.config and WAParam.config.rpDumpThreshold) or 120,
    rpHornThreshold = (WAParam.config and WAParam.config.rpHornThreshold) or 60,
}

-- ==========================================
-- ActionList（技能注册表）
-- ==========================================
local ActionList = {
    {6603, "macro", "/startattack\\n/petattack [combat]"},
    {S.RD, "spell", "亡者复生"},
    {S.IC, "macro", "/cast [nochanneling] 冰冷触摸\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("冰冷触摸")},
    {S.PS, "macro", "/cast [nochanneling] 暗影打击\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("暗影打击")},
    {S.BS, "macro", "/cast [nochanneling] 鲜血打击\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("鲜血打击")},
    {S.SS, "macro", "/cast [nochanneling] 天灾打击\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("天灾打击")},
    {S.BB, "macro", "/cast [nochanneling] 血液沸腾\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("血液沸腾")},
    {S.DN, "macro", "/cast [@player,nochanneling] 枯萎凋零", GetSpellTexture("枯萎凋零")},
    {S.DC, "macro", "/cast [nochanneling] 凋零缠绕\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("凋零缠绕")},
    {S.HN, "macro", "/cast [nochanneling] 寒冬号角", GetSpellTexture("寒冬号角")},
    {S.GA, "macro",
        "/cqs\\n/cast 石像形态(种族特长)\\n/cast 血性狂怒(种族特长)\\n/use 13\\n/use 14\\n/cast 召唤石像鬼",
        GetSpellTexture("召唤石像鬼")},
    {S.EW, "macro", "/cast [nochanneling] 符文武器增效", GetSpellTexture("符文武器增效")},
    {S.AR, "macro",
        "/cqs\\n/cast 狮心(种族特长)\\n/cast 狂暴(种族特长)"
        .. (cfg.useSpeedPotion and "\\n/use 速度药水" or "")
        .. "\\n/cast [nochanneling] 亡者大军",
        GetSpellTexture("亡者大军")},
    {S.BSH, "macro", "/cast [nochanneling] 白骨之盾", GetSpellTexture("白骨之盾")},
    {S.BT, "macro", "/cast [nochanneling] 活力分流", GetSpellTexture("活力分流")},
    {S.GF, "macro", "/cast [nochanneling] 食尸鬼狂乱", GetSpellTexture("食尸鬼狂乱")},
    {S.PE, "macro", "/cast [nochanneling] 传染\\n/startattack [combat]\\n/petattack [combat]\\n/cast [@pettarget,exists] 爪击", GetSpellTexture("传染")},
    {S.BP, "macro", "/cast 鲜血灵气", GetSpellTexture("鲜血灵气")},
    {S.UP, "macro", "/cast 邪恶灵气", GetSpellTexture("邪恶灵气")},
    {S.GLOVES, "macro", "/use 10\\n/use 通用热力工程炸药\\n/use [@player] 萨隆邪铁炸弹", 133035},
}

-- ==========================================
-- 辅助函数
-- ==========================================
local function cd(id) return math.max(0, VF_getSpellCD(id) - VF_getSpellCD(61304)) end
local function IsCD(id) return cd(id) >= 1 end
local function GetRP() return UnitPower("player", 6) or 0 end

local function hasFF(unit)
    return VF_getDebuff(unit, S.IC_DEBUFF, "HARMFUL|PLAYER") > 0
end
local function hasBP(unit)
    return VF_getDebuff(unit, S.BP_DEBUFF, "HARMFUL|PLAYER") > 0
end

-- 检测额外目标数（ PestInfo 返回 主目标之外的 nearby 数量）
local function PestInfo()
    local count, seen = 0, {}
    for i = 1, 40 do
        local uid = "nameplate" .. i
        if not UnitExists(uid) then break end
        if UnitCanAttack("player", uid) and not UnitIsDead(uid) then
            if WeakAuras.CheckRange(uid, 8, "<=") then
                local guid = UnitGUID(uid)
                if guid and not seen[guid] then
                    seen[guid], count = true, count + 1
                end
            end
        end
    end
    return math.max(0, count - 1)
end

local function isBoss()
    return (IsEncounterInProgress() or IsResting()) and UnitLevel("target") == -1
end

local function IsGlovesReady()
    return cfg.useGlovesAuto
        and (VF_getItemCD(10) == 0)
        and WeakAuras.CheckRange("target", 5, "<=")
end

-- ==========================================
-- 符文追踪系统
-- 通过 CLEU 追踪符文消耗，每帧计算可用数量
-- 用于优先级预判（主判断仍用 VF_getSpellCD）
-- ==========================================
local runeAvail = { blood = 2, frost = 2, unholy = 2 }
local runeTimers = { blood = {}, frost = {}, unholy = {} }
local RUNE_CD = 10  -- 基础符文恢复时间（秒）

local RUNE_COST = {
    [S.IC] = { frost = 1 },
    [S.PS] = { unholy = 1 },
    [S.BS] = { blood = 1 },
    [S.BB] = { blood = 1 },
    [S.PE] = { blood = 1 },
    [S.SS] = { frost = 1, unholy = 1 },
    [S.DN] = { blood = 1, frost = 1, unholy = 1 },
    [S.GF] = { unholy = 1 },
}

local function updateRunes(now)
    for _, type in ipairs({"blood", "frost", "unholy"}) do
        local remaining = {}
        for _, t in ipairs(runeTimers[type]) do
            if t <= now then
                runeAvail[type] = math.min(2, runeAvail[type] + 1)
            else
                remaining[#remaining + 1] = t
            end
        end
        runeTimers[type] = remaining
    end
end

local function spendRunes(spellID, now)
    local cost = RUNE_COST[spellID]
    if not cost then return end
    for rtype, amount in pairs(cost) do
        for _ = 1, amount do
            if runeAvail[rtype] > 0 then
                runeAvail[rtype] = runeAvail[rtype] - 1
                runeTimers[rtype][#runeTimers[rtype] + 1] = now + RUNE_CD
            end
        end
    end
end

-- CLEU 帧：仅用于符文追踪
local _lastCastID = 0
local _lastCastTime = 0
local Manager = CreateFrame("Frame", "UnholyDKV2RuneTracker", UIParent)
Manager:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Manager:RegisterEvent("PLAYER_REGEN_ENABLED")
Manager:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_REGEN_ENABLED" then
        -- 脱战重置符文
        runeAvail = { blood = 2, frost = 2, unholy = 2 }
        runeTimers = { blood = {}, frost = {}, unholy = {} }
        _blackMagicUsed = nil
        _postBurstBloodPending = nil
    elseif ev == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, srcG, _, _, _, _, _, _, _, sID = CombatLogGetCurrentEventInfo()
        if sub == "SPELL_CAST_SUCCESS" and srcG == UnitGUID("player") then
            local now = GetTime()
            -- 去重（500ms内同一技能不重复扣）
            if sID ~= _lastCastID or now - _lastCastTime > 0.5 then
                _lastCastID = sID
                _lastCastTime = now
                updateRunes(now)
                spendRunes(sID, now)
            end
        end
    end
end)

-- ==========================================
-- 爆发期状态追踪
-- ==========================================
local _blackMagicUsed   -- 黑魔法宏已使用（每次爆发期一次）
local _postBurstBloodPending  -- 爆发结束后需要切回红脸

-- 判断当前是否爆发期
-- 条件：Boss战 + autoBossBurst + (石像鬼CD好 或 大军CD好 或 刚开怪15s内)
local function isBurstPhase()
    if not cfg.autoBossBurst then return false end
    if not isBoss() then return false end
    local gaCD = cd(S.GA)
    local arCD = cd(S.AR)
    -- 石像鬼即将就绪（含15秒缓冲覆盖施法+大军窗口）
    if gaCD <= 15 then
        -- 新的爆发期开始，重置黑魔法标志
        if gaCD <= 5 then _blackMagicUsed = nil end
        return true
    end
    -- 大军即将就绪且石像鬼已施放（确保两者能配合）
    if arCD <= 5 and gaCD > 150 then return true end
    return false
end

-- ==========================================
-- 施法预测（类似鸟德V2）
-- 预测当前施法完成后的状态变化
-- ==========================================
local function predictState()
    local castingSpell = UnitCastingInfo("player")
    local pred = {
        ffRemain = math.max(0, VF_getDebuff("target", S.IC_DEBUFF, "HARMFUL|PLAYER")),
        bpRemain = math.max(0, VF_getDebuff("target", S.BP_DEBUFF, "HARMFUL|PLAYER")),
        rp = GetRP(),
    }
    if castingSpell == "冰冷触摸" then
        pred.ffRemain = 15  -- 冰霜疫病刷新15秒
    elseif castingSpell == "暗影打击" then
        pred.bpRemain = 15  -- 血之疫病刷新15秒
    end
    return pred
end

-- ==========================================
-- 核心 APL 优先级逻辑
-- 每帧独立评估，返回最高优先级技能ID
-- ==========================================
local function APLCallback()
    local now = GetTime()
    local targetExists = UnitExists("target") and not UnitIsDeadOrGhost("target")
    local targetAttackable = targetExists and UnitCanAttack("player", "target")
    local rp = GetRP()
    local castWindow = win
    local extraTargets = PestInfo()
    local aoe = cfg.usePestilence and extraTargets >= cfg.pestilenceTargets
    local pred = predictState()

    -- 更新符文可用状态
    updateRunes(now)

    -- 自身 buff / debuff 时间
    local ffRemTarget = pred.ffRemain
    local bpRemTarget = pred.bpRemain
    local solitudeDur = bpRemTarget  -- 用血之疫病剩余时间近似孤寂buff
    local gfBuffDur = math.max(0, VF_getBuff("pet", B.GhoulFrenzy, "HELPFUL"))
    local boneShieldDur = math.max(0, VF_getBuff("player", B.BoneShield, "HELPFUL|PLAYER"))

    -- 关键CD
    local gaCD = cd(S.GA)
    local arCD = cd(S.AR)
    local ewCD = cd(S.EW)
    local dnCD = cd(S.DN)
    local btCD = cd(S.BT)
    local dcCD = cd(S.DC)
    local hnCD = cd(S.HN)
    local peCD = cd(S.PE)

    -- 施法预测：符文状态
    local castingSpell = UnitCastingInfo("player")
    local predBlood = runeAvail.blood
    local predFrost = runeAvail.frost
    local predUnholy = runeAvail.unholy
    if castingSpell == "枯萎凋零" then
        predBlood = math.min(2, predBlood + 1)
        predFrost = math.min(2, predFrost + 1)
        predUnholy = math.min(2, predUnholy + 1)
    elseif castingSpell == "天灾打击" then
        predFrost = math.min(2, predFrost + 1)
        predUnholy = math.min(2, predUnholy + 1)
    elseif castingSpell == "冰冷触摸" then
        predFrost = math.min(2, predFrost + 1)
    elseif castingSpell == "暗影打击" then
        predUnholy = math.min(2, predUnholy + 1)
    elseif castingSpell == "鲜血打击" or castingSpell == "血液沸腾" or castingSpell == "传染" then
        predBlood = math.min(2, predBlood + 1)
    end

    -- =============================================
    -- P0: 前置检查（脱战 / 通用）
    -- =============================================

    -- 无宠物 → 亡者复生
    if not UnitExists("pet") and cd(S.RD) <= 0 then
        return S.RD
    end

    -- 无骨盾 + 天鬼即将就绪 → 补骨盾
    if boneShieldDur <= 0 and gaCD < 10 and cd(S.BSH) <= 0 then
        return S.BSH
    end

    -- 无目标 / 目标不可攻击 / 目标无冰霜疫病 → 冰冷触摸
    if not targetExists or not targetAttackable then
        return 6603
    end
    if not hasFF("target") then
        return S.IC
    end

    -- 非法目标（死亡等）
    if UnitIsDead("target") then
        return 6603
    end

    -- =============================================
    -- 爆发期逻辑
    -- =============================================
    local burst = isBurstPhase()

    if burst then
        _postBurstBloodPending = true  -- 标记：爆发结束后需要切回红脸

        -- 1. 非绿脸 → 邪恶灵气（天鬼需要实时急速增益）
        if GetShapeshiftForm() ~= 3 then
            return S.UP
        end

        -- 2. 疾病维护（爆发期也要保证双病）
        if not hasFF("target") then return S.IC end
        if not hasBP("target") then return S.PS end

        -- 3. 召唤石像鬼（快照AP，需要RP>=60确保施法成功）
        if gaCD <= castWindow and rp >= 60 then
            return S.GA
        end

        -- 4. 手套+炸弹（天鬼后立即使用，让后续大军享受急速）
        -- 直接检查CD，不跟踪使用状态，允许长战斗中多次使用
        if IsGlovesReady() then
            return S.GLOVES
        end

        -- 5. 黑魔法宏（大军前使用）
        if not _blackMagicUsed and arCD <= castWindow then
            _blackMagicUsed = true
            return S.DC  -- 占位，实际由用户黑魔法宏处理
        end

        -- 6. 符文武器增效（重置全部符文+RP，为大军做准备）
        if ewCD <= castWindow then
            return S.EW
        end

        -- 7. 枯萎凋零（大军前释放，让大军享受凋零增伤区域）
        if dnCD <= castWindow and predBlood >= 1 and predFrost >= 1 and predUnholy >= 1 then
            return S.DN
        end

        -- 8. 亡者大军（享受手套急速buff）
        if arCD <= castWindow then
            return S.AR
        end

        -- 9. 寒冬号角（填充CD窗口，提升攻强）
        if hnCD <= castWindow and rp >= cfg.rpHornThreshold then
            return S.HN
        end

        -- 10. 爆发期疾病快断 → 补病
        if ffRemTarget <= 3 then return S.IC end
        if bpRemTarget <= 3 then return S.PS end

        -- 11. 爆发期RP溢出 → 凋零缠绕
        if cfg.useDeathCoil and rp >= cfg.rpDumpThreshold and dcCD <= castWindow then
            return S.DC
        end

        -- 12. 爆发期填充：天灾打击 > 鲜血打击 > 血液沸腾
        if predFrost >= 1 and predUnholy >= 1 then
            return S.SS
        end
        if predBlood >= 1 then
            if aoe then return S.BB end
            return S.BS
        end

        -- 13. 爆发期等待（符文全部CD中）
        return 6603
    end

    -- =============================================
    -- 爆发结束后：切回红脸（一次性建议）
    -- =============================================
    if _postBurstBloodPending and GetShapeshiftForm() ~= 1 then
        _postBurstBloodPending = nil
        return S.BP
    end

    -- =============================================
    -- P2: 平稳输出期（核心优先级循环）
    -- =============================================

    -- 疾病维护（最高优先级）
    -- 冰霜疫病断了 → 立即补
    if ffRemTarget <= 0 then return S.IC end
    -- 血之疫病断了 → 立即补
    if bpRemTarget <= 0 then return S.PS end
    -- 冰霜疫病快断（≤3秒）→ 提前补
    if ffRemTarget <= 3 then return S.IC end

    -- AOE: 枯萎凋零（多目标时最高优先级之一）
    if aoe and dnCD <= castWindow and predBlood >= 1 and predFrost >= 1 and predUnholy >= 1 then
        return S.DN
    end

    -- 枯萎凋零（单体也优先，高伤害技能）
    if dnCD <= castWindow and predBlood >= 1 and predFrost >= 1 and predUnholy >= 1 then
        return S.DN
    end

    -- RP泄能（接近上限130，防止溢出）
    if cfg.useDeathCoil and rp >= cfg.rpDumpThreshold and dcCD <= castWindow then
        return S.DC
    end

    -- 食尸鬼狂乱维护（buff ≤5秒 + 活力分流CD好 → 补充）
    if gfBuffDur <= 5 and btCD <= castWindow then
        return S.BT  -- 先活力分流
    end
    if gfBuffDur > 0 and gfBuffDur <= 8 and btCD > castWindow then
        -- 分流在CD但狂乱快断了，直接补狂乱（如果有unholy符文）
        if predUnholy >= 1 then
            return S.GF
        end
    end

    -- 血之疫病快断（≤5秒）→ 补暗影打击或传染
    if bpRemTarget <= 5 then
        if aoe and peCD <= castWindow and predBlood >= 1 then
            return S.PE
        end
        return S.PS
    end

    -- AOE: 传染（保持疾病传播，代替鲜血打击消耗blood符文）
    if aoe and peCD <= castWindow and predBlood >= 1 then
        return S.PE
    end

    -- 孤寂buff维护（≤3秒 → 鲜血打击保持5%增伤）
    if solitudeDur <= 3 and predBlood >= 1 and not aoe then
        return S.BS
    end

    -- 核心填充：天灾打击（最高伤害符文技能，消耗frost+unholy）
    if predFrost >= 1 and predUnholy >= 1 then
        return S.SS
    end

    -- 鲜血打击（消耗blood符文，维持孤寂）
    if predBlood >= 1 and not aoe then
        return S.BS
    end

    -- AOE填充：血液沸腾（无frost+unholy时消耗blood符文）
    if aoe and predBlood >= 1 then
        return S.BB
    end

    -- RP中等 → 凋零缠绕（避免RP浪费）
    if cfg.useDeathCoil and rp >= cfg.rpHornThreshold and dcCD <= castWindow then
        return S.DC
    end

    -- 空闲填充：寒冬号角（低RP时）
    if rp < cfg.rpHornThreshold and hnCD <= castWindow then
        return S.HN
    end

    -- 鲜血打击兜底（消耗blood符文，总比等着好）
    if predBlood >= 1 then
        return S.BS
    end

    -- 全部符文CD中 → 等待
    return 6603
end

-- ==========================================
-- 导出接口
-- ==========================================
aura_env.APLActionList = ActionList
aura_env.APLCallback = APLCallback
aura_env.APLName = "邪DK_V2"
