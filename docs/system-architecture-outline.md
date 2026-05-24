# 2D RPG 对战卡牌游戏系统结构大纲

来源需求：`docs/requests/0001-2d-rpg-card-battle-system-outline.md`

本文档用于第一阶段统一玩法、数据、战斗、内容制作和技术架构方向。当前阶段只定义系统边界和原型结构，不实现游戏功能。

## 0. 范围与假设

- 第一版优先做单人 PvE 原型，目标是验证角色成长、卡组构筑和回合制战斗是否成立。
- 战斗默认采用离散回合制；如果后续改为半回合制，仍应复用同一套行动、结算、状态和数据模型。
- 玩家可先从单角色 + 单卡组开始，数据结构预留队伍、多角色、职业和装备扩展。
- 内容配置采用数据驱动方式，卡牌、角色、敌人、关卡、奖励都应能由配置文件描述。
- 本文不包含商业化、联网账号、正式剧情、完整美术管线、多人匹配和实时运营系统。

## 1. 游戏定位

### 1.1 游戏类型

- 类型：2D RPG + 对战卡牌。
- 战斗形式：玩家通过抽牌、出牌、管理能量和状态效果，与敌人进行回合制或半回合制战斗。
- 成长形式：角色等级、职业倾向、卡牌解锁、卡牌强化、装备和资源共同驱动长期构筑。
- 推进形式：通过关卡、节点或章节逐步面对敌人、事件和奖励。

### 1.2 核心体验

- 角色成长：角色属性、职业标签、起始卡组、被动能力和装备影响战斗策略。
- 卡组构筑：玩家在战斗外编辑卡组，在奖励阶段获得或强化卡牌。
- 战斗决策：玩家在有限行动点或能量下选择出牌顺序、目标和资源消耗。
- 敌人推进：敌人、关卡和奖励池随阶段推进逐步变化。

### 1.3 第一版原型范围

- 一个基础准备界面：选择角色、查看卡组、进入测试关卡。
- 一个可运行的战斗原型：抽牌、出牌、消耗能量、伤害、防御、治疗和状态效果。
- 少量测试内容：1 个角色、1 套初始牌组、3 到 5 张基础卡牌、2 到 3 种敌人、1 条短关卡链。
- 一个战斗后奖励流程：获得金币、经验、卡牌三选一或卡牌强化机会。
- 本地存档：保存角色成长、解锁内容和当前卡组。

### 1.4 暂不实现内容

- 多人对战、匹配、排行榜、聊天和观战。
- 完整剧情系统、任务系统、地图探索和复杂 NPC 交互。
- 正式美术资源管线、动画编辑器、音频系统和特效编辑器。
- 付费、商城、活动、成就和运营后台。
- 复杂装备词缀、随机词条和大型 Roguelike 事件库。

## 2. 核心玩法循环

1. 玩家进入准备界面，查看角色、卡组、装备和可进入关卡。
2. 玩家选择角色、队伍和卡组，进入指定关卡或战斗节点。
3. 战斗开始后初始化牌库、手牌、弃牌堆、能量、敌人和状态效果。
4. 玩家回合中抽牌、选择卡牌、支付费用、指定目标并结算行动。
5. 敌方根据意图或行为脚本行动，造成伤害、施加状态或执行特殊机制。
6. 系统持续检查胜负条件。胜利后进入奖励选择；失败后进入结算或重试。
7. 玩家获得金币、经验、卡牌、强化、装备或解锁内容。
8. 玩家回到准备界面，调整卡组和成长方向，再进入下一关。

## 3. 主要系统模块

| 模块 | 职责 | 关键输入 | 关键输出 |
| --- | --- | --- | --- |
| 战斗系统 | 管理回合、行动、费用、目标、结算、胜负 | `BattleState`、卡牌指令、敌人意图 | 新的 `BattleState`、事件日志、奖励入口 |
| 卡牌系统 | 定义卡牌类型、费用、目标、效果、升级 | `Card` 配置、角色标签、战斗上下文 | 可执行效果、描述文本、升级结果 |
| 角色与属性系统 | 管理角色基础属性、等级、职业、装备、被动 | `Character`、成长数据、装备 | 战斗单位属性、可用卡牌约束 |
| 敌人与关卡系统 | 配置敌人、敌方行为、关卡节点、难度曲线 | `Enemy`、`Stage`、随机种子 | 战斗编队、敌人意图、关卡推进 |
| 成长与奖励系统 | 发放经验、金币、卡牌、强化、装备和解锁 | 战斗结果、关卡奖励池 | `Reward`、角色成长、解锁状态 |
| 资源与经济系统 | 管理金币、消耗品、强化材料和商店价格 | 存档资源、奖励、消费请求 | 资源变化记录、购买或强化结果 |
| UI/UX 页面结构 | 承载准备、卡组、战斗、奖励、设置等流程 | 游戏状态、用户输入 | 命令、选择结果、状态展示 |
| 存档与配置系统 | 读取配置、保存进度、处理版本迁移 | 内容配置、本地存档 | 可用内容、玩家进度、迁移日志 |
| 内容数据管理系统 | 组织卡牌、敌人、关卡、奖励池和校验规则 | 内容文件、schema、校验脚本 | 校验报告、构建期内容索引 |

## 4. 战斗系统大纲

### 4.1 回合流程

1. 战斗初始化：根据关卡生成敌人，读取玩家卡组，洗牌并设置随机种子。
2. 玩家回合开始：增加回合数或轮次，刷新能量，触发回合开始状态，抽取固定数量手牌。
3. 玩家行动阶段：玩家重复出牌、选择目标和结算效果，直到结束回合或无可用行动。
4. 玩家回合结束：触发回合结束状态，处理保留或弃置手牌，更新持续效果。
5. 敌方回合开始：展示或确认敌人意图，触发敌方回合开始状态。
6. 敌方行动阶段：敌人按行动顺序执行攻击、防御、治疗、召唤或状态效果。
7. 敌方回合结束：处理状态持续时间、死亡检查和下一轮意图。
8. 胜负检查：每次行动后都检查玩家全灭、敌人全灭、特殊目标达成或失败条件。

### 4.2 行动点、能量和费用

- 第一版使用能量制：每个玩家回合刷新到固定能量值，例如 3 点。
- 每张卡牌有 `cost`，出牌时消耗能量；费用不足时不可打出。
- 状态、装备或卡牌效果可以临时增加、减少、锁定或下回合保留能量。
- 如果后续加入行动点，行动点应作为单位行动次数限制，能量继续作为卡牌费用资源。

### 4.3 牌区

- 抽牌堆：战斗开始由卡组洗牌得到。
- 手牌：玩家当前可打出的卡牌集合，有最大手牌上限。
- 弃牌堆：回合结束弃置和已使用的非消耗卡牌进入弃牌堆。
- 墓地或消耗区：被消耗、移除或本场战斗不可再次使用的卡牌进入该区域。
- 临时牌区：由效果生成、复制或发现的临时卡牌可在战斗结束后清理。
- 抽牌堆为空时，默认将弃牌堆洗入抽牌堆；墓地和消耗区不参与洗牌。

### 4.4 行动和效果

- 攻击：根据攻击值、卡牌倍率、目标防御和状态修正造成伤害。
- 防御：获得格挡、护盾或减伤；可在回合结束清空或按配置保留。
- 治疗：恢复生命，受治疗增益、禁疗或最大生命限制影响。
- 状态效果：包括中毒、燃烧、虚弱、易伤、力量、敏捷、护甲保留等。
- 抽牌和弃牌：改变手牌、抽牌堆和弃牌堆，可作为卡牌效果的一部分。
- 召唤或生成：第一版可只生成临时卡牌，召唤单位留作后续扩展。

### 4.5 敌我行动顺序

- 第一版采用玩家整回合和敌方整回合交替。
- 多敌人按 `initiative` 或关卡配置顺序行动。
- 敌人意图在玩家回合展示，帮助玩家做防御和击杀决策。
- 后续半回合制可引入行动条或速度排序，但应继续产出同样的 `BattleCommand` 和 `BattleEvent`。

### 4.6 胜负条件

- 胜利：所有必须击败的敌人生命值小于等于 0，或达成关卡特殊目标。
- 失败：玩家队伍所有可行动角色生命值小于等于 0，或达到关卡失败条件。
- 中止：玩家主动放弃、退出或读取存档，需明确是否消耗关卡进度。

## 5. 卡牌系统大纲

### 5.1 卡牌类型

- 攻击牌：造成伤害，可附带破甲、连击、吸血或元素效果。
- 技能牌：提供防御、抽牌、资源转换、位移或辅助效果。
- 法术牌：偏向元素、范围、状态和高费用爆发。
- 能力牌：打出后提供持续被动效果，通常每场战斗只结算一次。
- 道具牌：由装备、奖励或关卡临时提供，可消耗或战斗后移除。

### 5.2 稀有度

- 基础：角色初始卡组或教程卡牌，效果简单。
- 普通：常见奖励，构筑核心的低复杂度卡牌。
- 稀有：提供更高收益或组合能力。
- 史诗：改变玩法方向，可能有较强条件或副作用。
- 传说：绑定职业、角色或关卡主题，数量应严格控制。

### 5.3 费用

- 常规费用：0 到 3 点适合第一版原型。
- 高费用牌：4 点及以上需要费用减免、能量成长或特殊条件支持。
- 可变费用：例如消耗全部能量并按消耗值结算。
- 替代费用：弃牌、失去生命、移除状态或消耗资源，建议后续版本再加入。

### 5.4 卡牌效果表达方式

卡牌效果应采用声明式配置，由战斗系统解释执行，避免把每张卡写成独立逻辑。

```ts
type CardEffect = {
  type: "damage" | "block" | "heal" | "draw" | "discard" | "applyStatus" | "gainEnergy" | "moveCard";
  target: TargetSelector;
  value?: number | ScalingValue;
  statusId?: string;
  stacks?: number;
  duration?: number;
  condition?: EffectCondition;
};
```

效果执行应遵循固定顺序：校验费用和目标，创建行动事件，逐条结算效果，写入事件日志，检查触发器和胜负条件。

### 5.5 升级和强化方向

- 数值强化：提高伤害、防御、治疗、抽牌数量或状态层数。
- 费用变化：降低费用，或在特定条件下费用降低。
- 目标变化：从单体变为全体，或增加额外目标。
- 机制变化：增加保留、消耗、连击、发现、复制或额外触发。
- 职业强化：在特定职业或属性角色使用时获得额外效果。

### 5.6 卡牌与职业、属性关系

- 每张卡可配置 `allowedClasses`、`element` 和 `tags`。
- 角色职业决定可加入卡组的卡牌池，属性决定卡牌加成或额外触发。
- 通用卡可被所有角色使用；职业卡只对指定职业或角色开放。
- 装备可以临时允许跨职业卡牌、替换起始牌或生成道具牌。

## 6. 数据结构初稿

以下为 TypeScript-like pseudo schema，用于指导后续 schema 和状态模型实现。

```ts
type Id = string;
type Rarity = "basic" | "common" | "rare" | "epic" | "legendary";
type CardType = "attack" | "skill" | "spell" | "power" | "item";
type Element = "neutral" | "fire" | "ice" | "lightning" | "holy" | "dark";
type BattlePhase = "setup" | "playerTurn" | "enemyTurn" | "reward" | "victory" | "defeat";

type ScalingValue = {
  base: number;
  stat?: "attack" | "magic" | "defense" | "level";
  multiplier?: number;
};

type TargetSelector = {
  side: "self" | "ally" | "enemy" | "allAllies" | "allEnemies" | "any";
  count?: number;
  rules?: string[];
};

type EffectCondition = {
  type: "hasStatus" | "hpBelow" | "cardTagPlayed" | "turnNumber" | "energyRemaining";
  value: string | number | boolean;
};

type CardEffect = {
  type: "damage" | "block" | "heal" | "draw" | "discard" | "applyStatus" | "gainEnergy" | "moveCard";
  target: TargetSelector;
  value?: number | ScalingValue;
  statusId?: Id;
  stacks?: number;
  duration?: number;
  condition?: EffectCondition;
};

type Card = {
  id: Id;
  name: string;
  description: string;
  type: CardType;
  rarity: Rarity;
  cost: number;
  element: Element;
  tags: string[];
  allowedClasses: string[];
  effects: CardEffect[];
  upgradeTo?: Id;
  exhausts?: boolean;
  retains?: boolean;
  artKey?: string;
};

type Character = {
  id: Id;
  name: string;
  classId: string;
  level: number;
  xp: number;
  baseStats: {
    maxHp: number;
    attack: number;
    magic: number;
    defense: number;
    speed: number;
  };
  growth: Record<string, number>;
  startingDeckId: Id;
  equipmentSlots: string[];
  passiveIds: Id[];
  unlockedCardPools: Id[];
};

type EnemyIntent = {
  type: "attack" | "defend" | "buff" | "debuff" | "summon" | "special";
  value?: number;
  target: TargetSelector;
  effects: CardEffect[];
};

type Enemy = {
  id: Id;
  name: string;
  level: number;
  maxHp: number;
  stats: {
    attack: number;
    defense: number;
    speed: number;
  };
  tags: string[];
  resistances: Partial<Record<Element, number>>;
  intentPattern: EnemyIntent[];
  rewardPoolId?: Id;
};

type Deck = {
  id: Id;
  name: string;
  ownerCharacterId?: Id;
  cardIds: Id[];
  minSize: number;
  maxSize: number;
  format: "starter" | "player" | "enemy" | "temporary";
  version: number;
};

type StatusEffect = {
  id: Id;
  name: string;
  description: string;
  isDebuff: boolean;
  stackRule: "stackIntensity" | "stackDuration" | "replace" | "unique";
  maxStacks?: number;
  durationRule: "turns" | "rounds" | "battle" | "instant";
  timing: "onApply" | "turnStart" | "turnEnd" | "beforeAttack" | "afterAttack" | "onDamaged";
  effects: CardEffect[];
};

type BattleUnitState = {
  instanceId: Id;
  definitionId: Id;
  side: "player" | "enemy";
  hp: number;
  maxHp: number;
  block: number;
  energy?: number;
  statuses: Array<{ statusId: Id; stacks: number; remaining?: number }>;
  isAlive: boolean;
};

type BattleState = {
  battleId: Id;
  stageId: Id;
  rngSeed: string;
  phase: BattlePhase;
  turnNumber: number;
  activeSide: "player" | "enemy";
  playerUnits: BattleUnitState[];
  enemyUnits: BattleUnitState[];
  drawPile: Id[];
  hand: Id[];
  discardPile: Id[];
  graveyard: Id[];
  temporaryCards: Card[];
  energy: { current: number; max: number };
  enemyIntents: Record<Id, EnemyIntent>;
  eventLog: BattleEvent[];
  pendingActions: BattleCommand[];
};

type BattleCommand = {
  type: "playCard" | "endTurn" | "selectReward" | "enemyAction";
  actorId: Id;
  cardInstanceId?: Id;
  targets?: Id[];
};

type BattleEvent = {
  id: Id;
  type: string;
  payload: Record<string, unknown>;
  turnNumber: number;
};

type StageNode = {
  id: Id;
  type: "battle" | "elite" | "boss" | "event" | "shop" | "rest";
  enemyGroupId?: Id;
  rewardPoolId?: Id;
  nextNodeIds: Id[];
};

type Stage = {
  id: Id;
  name: string;
  act: number;
  recommendedLevel: number;
  nodes: StageNode[];
  entryNodeId: Id;
  unlockRequirements: string[];
  backgroundKey?: string;
};

type Reward = {
  id: Id;
  type: "gold" | "xp" | "cardChoice" | "cardUpgrade" | "equipment" | "resource" | "unlock";
  amount?: number;
  choices?: Id[];
  rarityWeights?: Partial<Record<Rarity, number>>;
  conditions?: string[];
};
```

## 7. 技术架构建议

### 7.1 推荐前端技术栈

- TypeScript 作为核心语言，保证配置、战斗状态和 UI 事件都有明确类型。
- Vite 作为构建工具，适合快速原型和后续扩展。
- React 用于菜单、准备界面、卡组编辑、奖励选择和设置等复杂 UI。
- 游戏核心逻辑放在纯 TypeScript 模块中，不依赖 React 或渲染层。

### 7.2 2D 渲染方案

- 第一版可用 React DOM 承载大部分 UI，用简单 2D 元素展示战斗单位和卡牌。
- 如果需要更强的动画、粒子和战场表现，优先考虑 PixiJS 作为 2D 渲染层。
- 渲染层只消费 `BattleState` 和事件日志，不直接修改战斗状态。

### 7.3 状态管理方式

- 战斗核心采用 reducer 或 state machine：输入 `BattleCommand`，输出新的 `BattleState` 和 `BattleEvent`。
- UI 层可使用 Zustand 或 React Context 管理页面状态、选择状态和存档摘要。
- 战斗状态应可序列化，便于回放、调试、测试和未来多人同步。

### 7.4 数据驱动内容配置

- 内容文件建议放在 `src/content` 或 `content`，按 `cards`、`characters`、`enemies`、`stages`、`rewards` 拆分。
- 使用 JSON、YAML 或 TypeScript 数据文件均可；原型期建议 TypeScript 数据 + schema 校验，便于类型提示。
- 使用 Zod、JSON Schema 或自定义校验脚本检查 ID 唯一性、引用存在、费用范围、卡组大小和奖励池合法性。
- 所有内容对象必须使用稳定 ID，不使用展示名作为引用键。

### 7.5 测试策略

- 单元测试：覆盖费用校验、抽牌洗牌、伤害结算、状态持续时间和胜负判断。
- 表驱动测试：用配置样例验证每张基础卡的输入和输出状态。
- 回放测试：记录 `rngSeed` 和 `BattleCommand` 序列，确保同一输入产生同一事件日志。
- UI 冒烟测试：覆盖进入战斗、打出卡牌、结束回合、获得奖励和返回准备界面。
- 内容校验测试：构建前检查所有内容配置是否符合 schema。

### 7.6 多人对战预留边界

- 战斗核心必须确定性执行，随机数只能来自显式 `rngSeed` 和受控 RNG。
- 玩家输入应抽象成 `BattleCommand`，不要让 UI 直接修改状态。
- 状态、命令和事件需要可序列化，并包含内容版本号。
- 隐藏信息需要边界：手牌、抽牌堆顺序和敌方策略不能直接暴露给对方客户端。
- 如果进入多人版本，应采用服务器权威结算，客户端只提交命令和播放事件。
- 网络协议、匹配和账号系统不进入第一版，但命令模型应避免绑定本地 UI。

## 8. 建议代码与内容目录

第一版实现时可参考以下结构，实际目录可按项目框架调整。

```text
src/
  game/
    battle/        # BattleState、BattleCommand、reducer、效果结算
    cards/         # 卡牌 schema、目标选择、效果解释器
    characters/    # 角色属性、成长、职业规则
    stages/        # 关卡节点、敌人编队、奖励入口
    economy/       # 金币、资源、强化消耗
    save/          # 本地存档、配置版本迁移
  content/
    cards/
    characters/
    enemies/
    stages/
    rewards/
  ui/
    screens/       # 准备、战斗、奖励、卡组、设置
    components/    # 卡牌、单位面板、状态图标、资源栏
```

## 9. 后续 Linear Issue 候选任务

1. 初始化 TypeScript + Vite 项目脚手架和基础目录结构。
2. 定义卡牌、角色、敌人、关卡和奖励的内容 schema。
3. 实现战斗状态模型 `BattleState`、命令 `BattleCommand` 和事件 `BattleEvent`。
4. 实现抽牌、洗牌、弃牌、手牌上限和墓地区域的牌区逻辑。
5. 实现卡牌费用校验、目标选择和声明式效果解释器。
6. 实现基础伤害、防御、治疗和状态效果结算。
7. 实现敌人意图、敌方行动顺序和基础敌人行为配置。
8. 实现最小战斗原型页面，包括出牌、结束回合和胜负结算。
9. 实现准备界面、角色选择、卡组查看和进入关卡流程。
10. 实现战斗后奖励选择、经验、金币和卡牌解锁流程。
11. 实现本地存档、内容版本号和基础迁移机制。
12. 建立战斗核心单元测试、内容校验测试和回放测试样例。
