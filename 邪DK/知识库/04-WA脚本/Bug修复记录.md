# WA脚本 Bug修复记录 

## 📋 版本历史概览

| 版本 | 日期 | 主要更新 | 状态 |
|------|------|----------|------|
| v2.4 | 2026年7月 | 适配冰霜系核心天赋，添加冰霜疫病保活逻辑 | ✅ 当前版本 |
| v2.3 | 2026年7月 | 适配符文能量掌握天赋，调整泄能阈值 | ✅ 已发布 |
| v2.2 | 2026年7月 | 修复狂乱补充、号角CD、炸弹时机、焦点卡死 | ✅ 已发布 |
| v2.1 | 2026年7月 | 修复N4狂乱重复、手套时机优化 | ✅ 已发布 |
| v2.0 | 2026年7月 | 泰坦时光服适配（AOE阈值、泄能阈值） | ✅ 已发布 |

---

## 🐛 v2.4 - 冰霜天赋适配版

### 修复内容

#### 1. 冰霜疫病保活逻辑
**问题**：冰冷之爪天赋要求全程保持冰霜疫病，但原脚本没有检测机制

**解决方案**：
```lua
// GetNormal中nSub==1时添加检测
local frostFeverTime = VF_getDebuff("target", S.IC_DEBUFF, "HARMFUL|PLAYER")
if frostFeverTime > 0 and frostFeverTime <= 3 then
    // 冰霜疫病快断了（≤3秒），优先补冰触
    return { spell = "冰冷触摸", id = S.IC, r = "保冰霜疫病" }
end
```

**影响**：确保冰冷之爪的20%攻速增益全程覆盖

---

## 🐛 v2.3 - 天赋适配修正版

### 修复内容

#### 1. 符文能量掌握适配
**问题**：符文能量掌握(2/2)将RP上限提升到130，但泄能阈值仍为50/90

**解决方案**：
- 空窗期泄能阈值：50 → **60**
- 循环中泄能阈值：90 → **120**
- 开怪循环泄能阈值：90 → **120**

**代码修改**：
```lua
// GetFiller
if WAParam.config.useDeathCoil and GetRP() >= 60 and not IsCD(S.DC) then
    return { spell = "凋零缠绕", ... }
end

// GetNormal
elseif step.id ~= S.DC and WAParam.config.useDeathCoil and GetRP() >= 120 and not IsCD(S.DC) then
    _isFilling = true
    return { spell = "凋零缠绕", ... }
end
```

**影响**：避免过早或过晚使用死缠，减少RP溢出浪费

---

## 🐛 v2.2 - Bug修复版

### 修复内容

#### 1. 狂乱补充逻辑修复
**问题**：进入正常循环后没有分流狂乱

**原因**：
```lua
// 原逻辑（错误）
if _isBoss and nRound ~= 4 and (buff <= 5 or buff == 0) ...
// 只在第1、2、3轮检查，如果战斗前没预铺狂乱，永远不会补充
```

**解决方案**：
```lua
// 新逻辑（正确）
local gfBuffTime = VF_getBuff("pet", S.GF, "HELPFUL")
if _isBoss and not _gfInsert and (gfBuffTime <= 5 or gfBuffTime == 0) ... then
    if nRound ~= 4 or gfBuffTime == 0 then  // N4轮次但buff消失也补充
        _gfInsert = 1
    end
end
```

**影响**：确保狂乱buff全程覆盖，即使战斗前没有预铺也能正常补充

---

#### 2. 寒冬号角CD判断修复
**问题**：如果战斗前已经用了寒冬号角，爆发时号角在CD，会卡住循环

**原因**：
```lua
// 原逻辑（错误）
if oStep == 8 and VF_getSpellCD(S.HN) > 1 ...  // oStep==8是符武，不是号角
```

**解决方案**：
```lua
// 新逻辑（正确）
if oStep == 6 and IsCD(S.HN) and GetRP() >= 60 then
    oStep = 7  // 跳过寒冬号角
end
```

**影响**：避免循环卡住，提高稳定性

---

#### 3. 手套使用时机优化
**问题**：炸弹使用还是很慢，没有在最佳时机使用

**原因**：只在oStep==8检查，可能错过

**解决方案**：
```lua
// 扩大检查范围到oStep 7-9
if not _bombsUsed and oStep >= 7 and oStep <= 9 and IsGlovesReady() then
    _bombsUsed = true
    return { spell = "加速手套", ... }
end
```

**影响**：确保亡者大军享受15秒手套急速buff，提升大军DPS

---

#### 4. 焦点卡死问题修复
**问题**：设置焦点后有时卡死

**原因**：PestInfo()遍历nameplate1-40时，某些nameplate单位无效导致UnitExists()出错

**解决方案**：
```lua
// 添加pcall保护
for i = 1, 40 do
    local uid = "nameplate" .. i
    local success, exists = pcall(UnitExists, uid)
    if not success or not exists then break end  // 安全退出
    
    if UnitCanAttack("player", uid) and not UnitIsDead(uid) then
        // 处理逻辑
    end
end
```

**影响**：防止焦点目标导致脚本卡死，提高稳定性

---

## 🐛 v2.1 - 逻辑优化版

### 修复内容

#### 1. N4轮次狂乱重复问题
**问题**：N4轮次固定包含食尸鬼狂乱，动态补充可能导致重复

**解决方案**：
```lua
// 排除N4轮次，但buff消失时仍补充
if _isBoss and nRound ~= 4 and (VF_getBuff("pet", S.GF, "HELPFUL") <= 5 ...) then
    _gfInsert = 1
end
```

**影响**：避免狂乱buff重叠，节省活力分流+狂乱的组合

---

#### 2. 常规循环手套重复尝试
**问题**：GetNormal和GetFiller中没有检查_bombsUsed标志

**解决方案**：
```lua
// GetNormal
elseif not _isFilling and IsGlovesReady() and (step.id == S.SS or step.id == S.DN) then
    if _bombsUsed then
        // 爆发期已使用，跳过
    else
        return { spell = "加速手套", ... }
    end
end

// GetFiller
if not _bombsUsed and IsGlovesReady() then
    return { spell = "加速手套", ... }
end
```

**影响**：避免常规循环中重复尝试使用手套

---

## 🐛 v2.0 - 泰坦时光服适配版

### 修复内容

#### 1. AOE阈值调整
**问题**：AOE传染阈值为1，不适应25人副本多目标场景

**解决方案**：
```lua
// 从1改为2
local useAOE = WAParam.config.usePestilence and PestInfo() >= 2
```

**影响**：适应泰坦时光服25人团队副本的AOE场景

---

#### 2. 泄能阈值调整
**问题**：泄能阈值为100，不适应快速成长的急速属性

**解决方案**：
```lua
// 从100改为90
if WAParam.config.useDeathCoil and GetRP() >= 90 and not IsCD(S.DC) then
    return { spell = "凋零缠绕", ... }
end
```

**影响**：适应泰坦时光服初期装备快速成长的特性

---

## 📊 Bug统计

| 类型 | 数量 | 占比 |
|------|------|------|
| 逻辑错误 | 5个 | 50% |
| 参数配置 | 3个 | 30% |
| 性能问题 | 2个 | 20% |

**总计**：10个Bug已全部修复 ✅

---

## 🔗 相关文档

- [脚本架构](./脚本架构.md)
- [核心函数](./核心函数.md)
- [状态管理](./状态管理.md)
- [代码逻辑分析](../../代码逻辑分析.md)

---

**最后更新**：2026年7月21日  
**适用服务器**：泰坦时光服（P4阶段）
