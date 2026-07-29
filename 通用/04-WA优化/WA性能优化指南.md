# WeakAuras性能优化指南

## 🎯 核心原则

**WA是魔兽世界中最影响性能的插件之一**,但也是最强大的自定义工具。关键在于平衡功能与性能。

---

## 📊 WA性能影响分析

### 高消耗的WA类型(按影响排序)

| 类型 | 性能影响 | 原因 |
|------|----------|------|
| **姓名板相关** | 🔴🔴🔴🔴🔴 | 每个玩家/NPC都触发,数量×频率 |
| **频繁刷新的计时器** | 🔴🔴🔴🔴 | 每帧更新,持续消耗CPU |
| **复杂动画效果** | 🔴🔴🔴🔴 | GPU渲染负担 |
| **多条件触发器** | 🔴🔴🔴 | 每次检查多个条件 |
| **自定义Lua代码** | 🔴🔴🔴🔴🔴 | 取决于代码质量 |
| **材质/纹理加载** | 🔴🔴🔴 | 内存和GPU占用 |
| **声音提示** | 🔴🔴 | 音频处理 |
| **简单图标显示** | 🔴 | 影响较小 |

### 性能计算公式
```
总消耗 = WA数量 × 平均刷新率 × 单个WA复杂度

示例:
50个WA × 每秒10次刷新 × 中等复杂度 = 可接受
100个WA × 每秒20次刷新 × 高复杂度 = 严重卡顿
```

---

## 🔧 优化技巧详解

### 技巧1: 降低刷新率

#### 在WA编辑器中:
```
1. 选择触发器
2. 找到"刷新率"或"Update Frequency"
3. 从默认的0.1秒改为0.2-0.5秒
4. 非关键WA可以设为1秒
```

#### 推荐设置:
```
战斗关键WA (技能冷却、buff): 0.1-0.2秒
普通监控 (DOT、资源): 0.3-0.5秒
背景信息 (统计数据): 1秒或更长
```

### 技巧2: 优化触发条件

#### ❌ 低效写法:
```lua
-- 每帧都检查所有条件
function()
    if UnitPower("player") > 50 and 
       GetSpellCooldown(12345) == 0 and
       UnitBuff("player", "某个buff") then
        return true
    end
    return false
end
```

#### ✅ 高效写法:
```lua
-- 使用事件驱动,只在相关事件发生时检查
function(allstates, event, ...)
    if event == "UNIT_POWER_UPDATE" or 
       event == "SPELL_UPDATE_COOLDOWN" or
       event == "UNIT_AURA" then
        -- 执行检查
    end
end
```

### 技巧3: 减少姓名板WA

#### 问题:
姓名板WA会对每个可见的姓名板执行,如果有20个玩家,就是20倍的消耗。

#### 解决方案:
```
1. 只监控关键目标(坦克、治疗、Boss)
2. 使用更长的刷新间隔(0.5-1秒)
3. 简化显示内容(只显示血条和名字)
4. 禁用不必要的动画
```

#### 示例优化:
```lua
-- 只监控焦点目标和坦克
function()
    local unit = aura_env.unit
    if not unit then return false end
    
    -- 只处理重要单位
    if UnitIsUnit(unit, "focus") or 
       UnitGroupRoleAssigned(unit) == "TANK" then
        return true
    end
    return false
end
```

### 技巧4: 合并相似WA

#### ❌ 分散的WA:
```
WA1: 监控技能A冷却
WA2: 监控技能B冷却
WA3: 监控技能C冷却
... (10个单独的WA)
```

#### ✅ 合并的WA:
```
单个WA包含多个触发器:
- 触发器1: 技能A
- 触发器2: 技能B
- 触发器3: 技能C
使用"显示全部"选项同时显示
```

### 技巧5: 禁用未激活状态的渲染

#### 在WA选项中:
```
1. 打开WA组设置
2. 找到"未激活时显示"
3. 取消勾选
4. 或设置透明度为0
```

#### 效果:
```
优化前: 50个WA始终渲染(即使不激活)
优化后: 只渲染激活的5-10个WA
性能提升: 60-80%
```

### 技巧6: 优化自定义Lua代码

#### 常见错误:
```lua
-- ❌ 每次调用都创建新表
function()
    local data = {}  -- 频繁分配内存
    data.value = GetSomeValue()
    return data
end

-- ❌ 使用全局变量查找
function()
    return UnitPower("player")  -- 每次都查找全局函数
end
```

#### 优化写法:
```lua
-- ✅ 复用表或使用局部变量
local cache = {}
function()
    cache.value = GetSomeValue()
    return cache
end

-- ✅ 缓存常用函数
local UnitPower = UnitPower
function()
    return UnitPower("player")  -- 直接调用局部变量
end
```

### 技巧7: 使用内置触发器而非自定义Lua

#### 优先使用:
```
✓ Buff/Debuff触发器
✓ 冷却触发器
✓ 资源触发器(能量、怒气等)
✓ 生命值触发器
```

#### 避免使用:
```
✗ 复杂的自定义Lua
✗ 频繁的API调用
✗ 循环遍历大量数据
```

---

## 📋 WA审查清单

### 每月审查项目

#### 1. 删除无用的WA
```
□ 超过1个月未触发的WA
□ 已不再使用的天赋对应的WA
□ 重复功能的WA
□ 过时的副本机制WA
```

#### 2. 优化高频WA
```
□ 检查刷新率是否可以降低
□ 是否有不必要的动画
□ 触发条件是否可以简化
□ 是否可以合并到其他WA
```

#### 3. 姓名板WA专项
```
□ 是否真的需要这么多姓名板WA
□ 能否限制监控的单位数量
□ 刷新率是否过高
□ 显示内容是否过于复杂
```

---

## 🎯 具体案例分析

### 案例1: 邪DK输出WA优化

#### 优化前:
```
- 15个独立WA监控各种技能
- 每个WA刷新率0.1秒
- 包含复杂动画和声音
- 姓名板显示疾病剩余时间
FPS影响: -15到-20
```

#### 优化后:
```
- 合并为3个WA组(单体、AOE、爆发)
- 刷新率调整为0.2-0.3秒
- 禁用非必要动画
- 疾病监控改为0.5秒刷新
FPS影响: -5到-8
性能提升: 60%
```

### 案例2: 团本通用WA

#### 优化前:
```
- 20个BOSS机制WA
- 全部始终保持激活
- 复杂的倒计时动画
- 多个声音提示
```

#### 优化后:
```
- 按BOSS分组,只加载当前BOSS的WA
- 使用条件显示(只在战斗中激活)
- 简化动画为简单的进度条
- 只保留关键声音提示
```

---

## 🔍 性能诊断工具

### 1. WA内置统计
```lua
/wa
点击"统计"标签
查看每个WA的执行时间和触发次数
找出最耗时的WA
```

### 2. 游戏内监控
```lua
/console fps 1
/script UpdateAddOnMemoryUsage()
/memory
-- 观察WeakAuras的内存占用
```

### 3. 测试方法
```
步骤1: 禁用所有WA,记录基准FPS
步骤2: 逐个启用WA组,记录FPS变化
步骤3: 找出影响最大的WA
步骤4: 针对性优化
```

---

## 💡 高级优化技巧

### 技巧1: 使用Load On Demand
```lua
-- 在WA组的"载入"标签中:
勾选"仅在以下情况载入"
- 特定副本
- 特定战斗
- 特定天赋专精
```

### 技巧2: 动态刷新率
```lua
-- 根据战斗状态调整刷新率
local lastUpdate = 0
function()
    local now = GetTime()
    local interval = InCombatLockdown() and 0.1 or 0.5
    if now - lastUpdate < interval then
        return false
    end
    lastUpdate = now
    return true
end
```

### 技巧3: 缓存计算结果
```lua
-- 避免重复计算
local cachedResult = nil
local lastCheck = 0

function()
    local now = GetTime()
    if now - lastCheck < 0.5 then
        return cachedResult
    end
    
    cachedResult = SomeExpensiveCalculation()
    lastCheck = now
    return cachedResult
end
```

---

## ⚠️ 常见性能陷阱

### 陷阱1: OnUpdate过于频繁
```lua
-- ❌ 错误
aura_env.frame:SetScript("OnUpdate", function(self, elapsed)
    -- 每帧执行,可能每秒60+次
end)

-- ✅ 正确
local accumulator = 0
aura_env.frame:SetScript("OnUpdate", function(self, elapsed)
    accumulator = accumulator + elapsed
    if accumulator >= 0.2 then  -- 每0.2秒执行
        accumulator = 0
        -- 执行更新
    end
end)
```

### 陷阱2: 字符串拼接过多
```lua
-- ❌ 低效
local text = ""
for i=1,10 do
    text = text .. "item" .. i  -- 每次都创建新字符串
end

-- ✅ 高效
local parts = {}
for i=1,10 do
    parts[i] = "item" .. i
end
local text = table.concat(parts)
```

### 陷阱3: 不必要的全局访问
```lua
-- ❌ 慢
function()
    return GetSpellInfo(GetSpellBookItemName(...))
end

-- ✅ 快
local GetSpellInfo = GetSpellInfo
local GetSpellBookItemName = GetSpellBookItemName
function()
    return GetSpellInfo(GetSpellBookItemName(...))
end
```

---

## 📊 性能目标参考

### 优秀配置
```
WA总数: < 50个触发器
平均刷新率: 0.2-0.3秒
FPS影响: < 5 FPS
内存占用: < 50 MB
```

### 良好配置
```
WA总数: 50-100个触发器
平均刷新率: 0.2-0.5秒
FPS影响: 5-10 FPS
内存占用: 50-100 MB
```

### 需要优化
```
WA总数: > 100个触发器
平均刷新率: < 0.2秒
FPS影响: > 15 FPS
内存占用: > 150 MB
```

---

## 🎯 针对您当前配置的建議

基于您的硬件(i9-10900K + RTX 3070):

✅ **可以承受**: 80-100个精心优化的WA  
⚠️ **需要注意**: 姓名板WA数量和刷新率  
🎯 **重点优化**: 邪DK输出循环相关的WA  

### 建议的WA分类管理:
```
📁 邪DK输出 (优先级最高,保持精细)
  ├─ 单体循环
  ├─ AOE循环
  └─ 爆发监控

📁 团队通用 (适度精简)
  ├─ BOSS机制
  ├─ 打断监控
  └─ 减伤提醒

📁 个人信息 (可选精简)
  ├─ BUFF监控
  ├─ 资源显示
  └─ 冷却追踪
```

---

## 🔄 定期维护计划

### 每周
- [ ] 检查新增WA的性能影响
- [ ] 清理临时测试的WA

### 每月
- [ ] 审查所有WA的使用频率
- [ ] 优化高频触发的WA
- [ ] 删除过期的副本WA

### 每个版本更新后
- [ ] 检查WA兼容性
- [ ] 更新过时的机制
- [ ] 重新评估必要性

---

## 📚 学习资源

- WeakAuras官方文档
- WoWInterface WA教程
- B站WA制作教程
- Discord WA社区

---

## 下一步行动

1. 运行 `/wa` 查看当前WA列表
2. 按照本指南审查每个WA
3. 应用优化技巧
4. 测试性能改善
5. 定期维护

祝您游戏愉快,FPS满满! 🎮
