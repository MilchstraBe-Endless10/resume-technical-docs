# AI 集群 Agent 独立记忆系统需求规格 V3.10

> 状态：Workbench Integration Rewrite v3.10 — SQLite Schema / Rust API Engineering Freeze  
> 适用项目：Team AI Workbench / AI Cluster Memory  
> 对齐基线：`LINUX_MVP_ENGINEERING_BASELINE.md` + `TEAM_WORKBENCH_PROJECT_SPEC.md` v0.50 Architecture Freeze Candidate  
> 核心修正：在 v3.3 Token-Stable Memory / Cognitive Economy / Evaluation 基础上，正式锁定 Cluster Sync、Offline Multi-device Revision、Revision DAG、Durable Outbox、Tombstone Propagation、Namespace-bound Remote Recall 与 New-device Bootstrap；Cluster 继续作为复制/索引/同步层，而不是第二个 Memory Brain。  
> 部署硬约束：**不得以 Docker / Docker Compose 作为官方部署依赖或默认部署路径。**

---

# 0. 一句话结论

AI 集群记忆系统不是 Team Workbench 外挂的“全局记忆库”，也不是 DeepSeek / Codex 的可选 Memory Tool。

它在 Workbench 中的正式定位是：

> **以每个 Agent Instance 为所有权单位、由 workbenchd 强制执行生命周期、通过 MemoryProvider 接入的 Agent Private Memory Kernel。**

系统必须满足：

```text
1 个 Agent Instance
= 1 个稳定 agent_id
+ 1 个独立 private MemorySpace
+ 1 套可版本化 Core Memory
+ 1 套自己的 Episodic / Semantic / Procedural / Preference / Lesson Memory
+ 1 套 Memory Policy
+ 可读取的 Workbench Shared Context（按当前 Project / Room / Mission 权限与任务需要）
+ 可切换的 DeepSeek / Codex RuntimeBinding
```

因此：

```text
N 个已注册 Agent（N 不设产品级固定上限）
= N 个逻辑独立 Private MemorySpace
≠ N 个数据库
≠ N 个 Memory 服务
≠ N 个常驻 Harness / Model 进程
```

`800` 只可作为历史示例或某个压力测试档位，不能作为架构上限。系统容量必须用 `Registered Agent Count / Active Agent Count / Memory Record Count / Concurrent Turn Count` 等维度描述。

最关键的运行规则：

```text
每个可见 Agent Turn
必须执行：

beforeTurnMemory(agent_id)
→ Shared Context Materialization
→ bounded Context Package
→ DeepSeek / Codex Runtime
→ afterTurnMemory(agent_id)
→ MemoryTurnReceipt
```

模型可以决定“是否继续深挖某条记忆”，但不能决定“这一轮是否完全跳过自己的基础记忆”。

---

# 1. 规范优先级与系统边界

## 1.1 Normative Precedence

本文件是 AI 集群记忆子系统规范，不覆盖 Workbench 已冻结的产品和工程边界。

发生冲突时优先级：

```text
Accepted ADR / 后续明确修订
        ↓
LINUX_MVP_ENGINEERING_BASELINE.md
        ↓
TEAM_WORKBENCH_PROJECT_SPEC.md 当前有效 Decision
        ↓
本文件
        ↓
旧 AGENT_MEMORY_REQUIREMENTS / V2 历史描述
```

本文件只定义：

- Agent Private Memory 的所有权与生命周期；
- 每轮强制 Memory 调用；
- Recall / Capture / Conflict / Revision；
- MemoryProvider / AI Cluster Memory Engine 接口；
- MemoryTurnReceipt 与 Memory Studio 数据；
- Workbench Shared Context 与 Private Memory 的连接规则；
- 非 Docker 部署与 OSS 集成边界。

本文件**不重新实现**：

- Workbench Scheduler；
- Mission / Task Graph；
- DeepSeek / Codex Agent Loop；
- Harness 原生 Permission / Approval / Sandbox；
- Workspace 文件系统；
- Project Knowledge / Decision / Artifact 真源；
- UI 状态机；
- Provider Traffic Controller。

## 1.2 Workbench 与 Memory 的职责划分

```text
Workbench 管：
谁在工作
在哪里工作
当前做什么
Task / Mission 状态
Project / Room 共同事实
Runtime / Permission / Cost / Recovery

AI Cluster Memory 管：
这个 Agent 过去经历过什么
它形成了什么稳定经验
它对用户形成了什么可允许保存的偏好
这一轮应该想起什么
这一轮是否形成了新的个人长期经验
```

核心原则：

> **Workbench owns work reality. Agent owns private experience.**

---

# 2. 必须废止的旧模型

## 2.1 废止“全局 Memory 是所有 Agent 默认记忆中心”

禁止：

```text
Global Memory
     ↓
Agent A / B / C / ... 全部检索
```

该模式会导致：

- Agent 经验互相污染；
- Agent 个体差异无法长期形成；
- 群聊变成“多个 Prompt 访问同一个大脑”；
- 无法回答“这是谁记住的”；
- Clone / Import / Delete / Transfer 无法明确处理所有权；
- 当逻辑 Agent 数持续增长时，如果不先按 MemorySpace/namespace 收窄，检索噪音会急剧扩大。

V3 规定：

```text
Agent Private MemorySpace
= 默认且唯一的 Agent 长期记忆所有权单位
```

## 2.2 废止产品层 `Shared Memory`

V2 中曾允许：

```text
memory://room/<id>
memory://project/<id>
memory://organization/<id>
```

V3 废止这一产品语义。

现在正式区分：

```text
Agent Private Memory
≠
Workbench Shared Context
```

Workbench Shared Context 包括：

- Requirement；
- Decision；
- Contract；
- Knowledge Note；
- Artifact metadata / ResourceRef；
- Project Baseline Context；
- Room Digest / Room state；
- Mission Charter / Task / Handoff；
- Work Item / Current State。

这些是共享业务事实，不属于任何 Agent 的私有 Memory，也不通过“共享 Agent Memory”实现。

## 2.3 废止“模型自己决定要不要调用 Memory Tool”

禁止将基础记忆连续性依赖于：

```text
LLM -> decide memory.search or not
```

Memory Recall 必须在 Runtime 外围由 Workbench 强制执行。

## 2.4 Raw Conversation / Runtime Event / Work State 不再算 Memory

正式区分：

```text
Conversation History
= 当时说了什么

Runtime / Event Evidence
= 实际执行了什么

Work State
= 当前做到哪里

Shared Context
= 项目 / 房间 / Mission 中经治理的共同事实

Agent Private Memory
= 该 Agent 以后值得再次使用的个人经验、知识、偏好和方法
```

Memory 通过 `sourceRefs` 追溯历史，但不复制全部历史成为长期 Memory。

---

# 3. Agent Identity / Definition / Runtime / Memory 四层分离

## 3.1 Agent Definition

```text
Agent Definition
= 可复用模板 / Agent Package
```

包含：

- instructions；
- recommended Skills；
- Runtime compatibility；
- tool requirements；
- default memory policy；
- UI metadata。

Definition 没有个人长期记忆。

## 3.2 Agent Instance

```text
Agent Instance
= 真正长期存在的 AI 个体
```

建议：

```ts
interface AgentIdentity {
  agentId: string
  ownerType: 'user' | 'project' | 'organization'
  ownerId: string
  displayName: string
  definitionId: string
  definitionVersion: string
  privateMemorySpaceId: string
  status: 'active' | 'disabled' | 'archived'
  createdAt: string
}
```

强约束：

- `agentId` 不随模型切换改变；
- `privateMemorySpaceId` 不随 Harness Session 改变；
- 一个 Agent Instance 必须有且只有一个主 Private MemorySpace；
- DeepSeek Session / Codex Thread 只属于 RuntimeBinding；
- 同一个 Agent 在 Main Chat / 多个 Room / Mission 中仍使用同一 Private MemorySpace；
- 不同 Conversation / Room 使用独立 RuntimeBinding / RoomContext，避免 Harness session 串线。

## 3.3 Runtime Binding

```text
RuntimeBinding
= 当前一次 Run / Turn 使用哪个 Harness 执行
```

只允许 Workbench Core Agent Runtime：

```text
DeepSeek Harness
Codex Harness
```

Runtime 故障优先：

```text
same Agent Identity
→ new RuntimeBinding
```

而不是自动更换 Agent 个体。

## 3.4 Private MemorySpace

```text
Agent A
└── memory://agent/A

Agent B
└── memory://agent/B
```

默认：

> Agent A 不能直接读取 Agent B Private Memory，即使属于同一用户、Project 或 Room。

---

# 4. Private MemorySpace 内部记忆类型

所有下列类型都发生在**某一个 Agent 自己的 MemorySpace 内**。

## 4.1 Core Memory Snapshot

Core Memory 不再定义为一种可以无限增长的普通 Memory 类型，而定义为：

> **由某个 Agent 的高权重、长期稳定 Canonical Memory 物化出的“小型、版本化、每轮直接加载的连续性快照”。**

因此：

```text
Canonical Private Memories
  Preference / Lesson / Semantic / Procedural
            │
            ▼
    Core Eligibility Policy
            │
            ▼
     CoreMemorySnapshot
            │
      每个 Turn 直接加载
```

Core Snapshot 不复制 Agent Definition 中已经存在的系统指令，也不保存当前 Task / Room / Project 状态。它只承载“如果这一轮完全不做搜索，这个 Agent 仍必须知道的长期连续性信息”。

### 4.1.1 允许进入 Core 的内容

只允许四类：

```text
A. Standing Constraints
   该 Agent 长期必须遵守、且不是 Definition 静态配置的已确认约束

B. Confirmed User Preferences
   用户明确确认、允许长期保存、且高频影响协作方式的偏好

C. Critical Lessons
   已有强证据、未来高概率复用、错误代价较高的稳定 Lesson

D. Persistent Domain Anchors
   该 Agent 必须长期保留、但尚不属于 Project Shared Truth 的稳定个人认知锚点
```

禁止进入 Core：

- 当前 Work Item / Task progress；
- Room / Mission 临时状态；
- 普通 Conversation 摘要；
- 未验证推断；
- 大段文档；
- Raw Tool Output；
- Secret / credential；
- 其他 Agent Private Memory；
- 可从 Project Decision / Requirement 等权威 Shared Context 直接解析出的重复全文。

### 4.1.2 Core Snapshot Schema

```ts
interface CoreMemorySnapshot {
  agentId: string
  memorySpaceId: string
  revision: number
  policyVersion: string

  standingConstraints: CoreEntry[]
  confirmedPreferences: CoreEntry[]
  criticalLessons: CoreEntry[]
  persistentAnchors: CoreEntry[]

  sourceMemoryRefs: string[]
  renderedText: string
  estimatedTokens: number
  createdAt: string
}

interface CoreEntry {
  entryId: string
  sourceMemoryRef: string
  summary: string
  authority: number
  importance: number
}
```

### 4.1.3 Size / Token Budget

MVP 默认采用可配置的双阈值：

```text
soft limit: 512 estimated tokens
hard limit: 1024 estimated tokens
max entries: 24
max single entry: 160 estimated tokens
```

同时设置独立的序列化 hard byte cap，默认 `12 KiB`，防止 tokenizer 差异或异常结构绕过 token 限制。

规则：

- 超过 soft limit：Core Builder 必须压缩 / 降级低优先级条目；
- 超过 hard limit：禁止提交新 Core Snapshot；
- 不允许通过“把完整 Memory 放进一个 CoreEntry”绕过限制；
- Core 每轮直接加载，不依赖 FTS / Vector / Graph；
- Core Snapshot 必须有 `sourceMemoryRefs`，可以从 Canonical Memory 重建；
- Core UI 人工修改语义不是直接改 `renderedText`，而是创建 / supersede 对应 Canonical Memory，再重建 Snapshot。

### 4.1.4 Core Revision

`CoreMemorySnapshot.revision` 是该 Agent Core Projection 的单调 revision。

```text
Canonical Memory change
→ Core eligibility affected?
  ├─ No  → Core revision unchanged
  └─ Yes → rebuild candidate
           → validate size/sourceRefs
           → commit Core revision N+1
```

Core Snapshot 是 durable projection，但不成为第二套独立事实源。其内容必须能够追溯到当前有效 Canonical Memory revision。

## 4.2 Episodic Memory

该 Agent 自己经历过什么。

例如：

```text
在 Project X 中，本 Agent 曾因未检查 migration contract 造成返工；
之后采用“先读 contract，再改 schema”的顺序完成任务。
```

## 4.3 Semantic Memory

该 Agent 已沉淀、可复用的稳定事实或领域理解。

注意：

如果该事实已经成为 Project 正式 Requirement / Decision / Knowledge，则 Project 真源仍属于 Shared Context；Agent 可保留“自己学到过此事实”的引用型 Memory，但不得覆盖 Project 权威记录。

## 4.4 Procedural Memory

该 Agent 已验证的“怎么做”。

例如：

- 某类任务检查顺序；
- 某 Skill 的有效使用方式；
- 某工具的稳定组合；
- 已验证的排错流程。

Procedural Memory 不自动等于正式 Skill。若需要成为团队可复用 Skill，应产生 Skill Candidate，由 Workbench Skill / Library Domain 治理。

## 4.5 Preference Memory

该 Agent 对所属用户形成、且允许长期保存的稳定协作偏好。

例如：

- 输出偏好；
- 审查严格程度；
- 某类工作默认方式；
- 用户明确反复确认的禁忌。

不得把 Project 机密、其他用户信息或不必要敏感信息当作 Preference Memory。

## 4.6 Lesson Memory

重点保存 Why / How：

```text
What
= 发生了什么

Why / How
= 为什么这样做有效
= 哪些条件下会失败
= 下次该怎样判断
```

Lesson 是形成 Agent 个体长期差异的重要记忆类型。

---

# 5. Workbench Shared Context：共享事实，不共享大脑

## 5.1 Shared Context 正式来源

Private Memory 之外的共享信息由 Workbench 提供：

```text
Project Shared Context
├── Requirement
├── Decision
├── Contract
├── Knowledge Note
├── Artifact
├── Project Baseline
└── Project State

Room Context
├── Room membership
├── Room Digest
├── public messages / refs
└── Room coordination state

Mission Context
├── Mission Charter
├── Task Graph
├── Task Delta
├── Handoff Packet
├── Review result
└── Mission progress
```

## 5.2 不自动复制

禁止：

```text
Project Shared Context
→ 自动复制进所有 Agent Private Memory
```

也禁止：

```text
Agent Private Memory
→ 自动广播给 Room / Project
```

## 5.3 Private → Shared 的正确路径

如果 Agent 从自己的私人经验里得到一个对团队有价值的结论：

```text
Private Memory insight
      ↓
Promotion Eligibility / Disclosure Preflight
      ↓
CognitiveProposal
      ├─ Knowledge Candidate
      ├─ Decision Proposal
      └─ Skill Candidate
      ↓
Target Domain governance
      ↓
Published Shared Context / Capability
```

正式共享的是**经过最小披露、证据替换和目标 Domain 治理后的新资产**，不是 Private Memory Record 本身；其它 Agent 不因 Promotion 获得源 MemorySpace 的读取权限。

## 5.4 Shared → Private 的正确路径

Agent 可以在任务中读取共享事实；共享资产发布本身不自动复制到 Agent MemorySpace。只有 Agent 在真实任务中读取、应用、验证后形成了自己的可复用经验，才通过自身 Capture Pipeline 生成 Private Memory Candidate。该过程称为 `Assimilation`。

例如：

```text
Shared Decision:
“Runtime Adapter 必须隔离私有协议。”

Agent Lesson:
“本 Agent 在两次 Adapter 任务中发现，先建立 protocol fingerprint 再改解析器更稳定。”
```

前者是项目事实，后者是 Agent 经验。

---

# 6. Agent Turn Lifecycle — Memory 真正嵌入 Workbench 的位置

## 6.1 正式 Turn Pipeline

每一个可见 Agent Turn：

```text
Incoming User / Room / Mission Turn Request
                   │
                   ▼
           Resolve Agent Identity
                   │
                   ▼
           Resolve Surface Context
                   │
                   ▼
          beforeTurnMemory()          # 强制
                   │
                   ▼
         Shared Context Materialize
                   │
                   ▼
             Context Broker
                   │
                   ▼
          Bounded Context Package
                   │
                   ▼
          RuntimeAdapter Execute
             ├─ DeepSeek
             └─ Codex
                   │
                   ▼
          Normalize Runtime Evidence
                   │
                   ▼
          afterTurnMemory()           # 强制
                   │
                   ▼
       Event / Receipt / Projection
```

## 6.2 `beforeTurnMemory()` 属于 workbenchd

它不是 DeepSeek Plugin 决定，也不是 Codex Tool 决定。

建议逻辑组件：

```text
MemoryLifecycleCoordinator
```

它属于：

```text
workbenchd / Application / Context-Memory Domain
```

职责：

- resolve Agent MemorySpace；
- load Core Memory；
- Mandatory Recall；
- optional Deep Recall；
- namespace validation；
- authority / freshness / revision filtering；
- token / item budget；
- 生成 `MemoryContextMaterialization`；
- 生成 pre-turn trace / receipt data。

它不实现 Agent Loop。

## 6.3 `afterTurnMemory()` 属于同一 Lifecycle Coordinator

职责：

- 检查该 Turn 是否形成可记忆内容；
- 分类 Private Memory Candidate；
- 检查 duplicate / contradiction / supersede；
- 提交需要同步写入的 canonical mutation；
- 将共享事实候选路由到 Workbench Shared Context Domain；
- 更新 retrieval usage / usefulness feedback；
- 完成 MemoryTurnReceipt。

## 6.4 Runtime Adapter 不允许公开绕过 Memory 的 Agent Turn 路径

允许 Runtime Adapter 有底层 probe / auth / diagnostics 调用。

但用户可见 Agent Turn 的应用层入口不得：

```text
Workbench -> RuntimeAdapter.startAgentTurn()
```

绕过：

```text
MemoryLifecycleCoordinator
```

测试中必须有 Architecture Test / compile boundary / integration test 证明该路径不存在。

---

# 7. Mandatory Recall 与 Deep Recall

## 7.1 Mandatory Recall — 每轮必执行

每轮至少：

```text
1. Direct load Core Memory
2. namespace-filtered hot / metadata recall
3. FTS/BM25 private recall
4. authority / freshness / status filter
5. Top-K selection
```

默认不要求：

```text
Embedding
Vector DB
Reranker
HyDE
RAG Fusion
额外压缩模型
```

这与 Workbench No-Embedding Baseline 保持一致。

## 7.2 Deep Recall — 有明确需要才执行

可以包括：

- Vector Search；
- Graph Expansion；
- Historical Deep Dive；
- Query Rewrite；
- RAG Fusion；
- HyDE；
- Cold Archive Recall；
- 专用 Reranker。

这些必须作为可选 Retrieval Strategy，不得变成所有 Agent Turn 的固定串行步骤。

## 7.3 当前主模型可以继续深挖

Mandatory Recall 只给出最小充分 Memory Material。

如果 Runtime 判断需要更深证据，可通过 Workbench Search / Memory Tool 做第二阶段查询。

区别是：

```text
基础 Recall 是否发生
= Workbench 强制

是否继续深挖
= 当前任务 / Runtime 可以决定
```

---

# 8. Context Broker 组合模型

## 8.1 Context 来源必须显式分层

建议：

```text
Context Broker
│
├── Agent Memory Materializer
│   ├── Core Memory
│   └── Relevant Private Memory
│
├── Shared Context Materializer
│   ├── Project Baseline
│   ├── Requirement / Decision / Knowledge
│   ├── Room Digest
│   └── Mission / Handoff
│
├── Active Work Materializer
│   ├── Work Item / Task state
│   ├── Runtime constraints
│   ├── Workspace refs
│   └── current turn input
│
└── Conversation Delta
```

## 8.2 AgentContextPackage

建议概念对象：

```ts
interface AgentContextPackage {
  agent: {
    agentId: string
    definitionId: string
    definitionVersion: string
    memorySpaceId: string
  }

  memory: {
    coreRevision: number
    privateMemoryRefs: string[]
    recallReceiptId: string
  }

  sharedContextRefs: string[]

  location: {
    projectId?: string
    roomId?: string
    missionId?: string
    workItemId?: string
    conversationId?: string
    taskId?: string
  }

  handoffRefs: string[]
  resourceRefs: string[]
  conversationExcerpts: string[]

  budgets: {
    totalContextTokens: number
    memoryTokens: number
    sharedContextTokens: number
  }
}
```

注意：不再使用 `sharedMemoryRefs`。

---

# 9. Main Chat / Room / Mission 中的 Memory 调用

## 9.1 Direct Agent Chat

```text
User
 ↓
Agent A
 ↓
beforeTurnMemory(A)
 ↓
A Private Memory
+ Current Project Shared Context
+ Current Conversation Delta
 ↓
DeepSeek / Codex
 ↓
afterTurnMemory(A)
```

## 9.2 Agent Room

Room 中有 100 个 Agent 不意味着 100 次 Recall / 100 次模型调用。

只有被 Scheduler / Speaker policy 真正激活的 Agent 才执行 Turn Lifecycle。

当 Agent B 发言：

```text
beforeTurnMemory(B)
      ↓
B Core + B Private Recall
      +
Room Context / Digest
      +
Project Shared Context
      +
Mission / Task / Handoff
      ↓
B Runtime
      ↓
afterTurnMemory(B)
```

绝不能：

```text
A Private + B Private + C Private -> B
```

## 9.3 Main Agent → Room Dispatch

跨 Surface 派发只传结构化：

```text
DispatchPacket
├── objective
├── targetRef
├── userExplicitRefs
├── projectRefs
├── resourceRefs
├── taskRefs
├── constraints
└── sourceConversationRef
```

默认不传：

- 完整 Main Conversation；
- Personal Agent Private Memory；
- 其他 Room 历史；
- 其他 Agent Memory Record。

## 9.4 Agent → Agent Handoff

Agents exchange：

```text
objective
result
constraints
evidence refs
artifact refs
decision refs
unresolved questions
```

而不是：

```text
private memory records
```

原则：

> **Agents exchange conclusions and evidence, not private memories.**

## 9.5 Mission

Mission 上下文优先采用：

```text
Mission Context Base
+ Task Delta
+ Structured Handoff
+ Room Digest Delta
+ Current Agent Private Memory
```

避免每个 Agent 重复拉取整套历史和完整 Room transcript。

---

# 10. Post-Turn Capture — Mandatory Lifecycle, Selective Extraction

## 10.1 `afterTurnMemory()` 每轮必须执行，但不固定增加第二次 LLM 调用

```text
Every visible Turn
→ afterTurnMemory() 必须执行

Every visible Turn
≠ create Memory
≠ call another model
```

`afterTurnMemory()` 首先是一个确定性的 Lifecycle Gate，负责收集 Turn Evidence、检查 Capture Trigger、消费 Runtime 已经提供的结构化 Memory Hint，并决定 `NO_CAPTURE / IMMEDIATE_CANDIDATE / DEFER / EXTRACTION_JOB`。

## 10.2 Candidate Extractor — Hybrid, No Mandatory Second Model

MVP 正式采用混合模型：

```text
Runtime Result / Tool Evidence / User Event
                 │
                 ▼
        Deterministic Capture Gate   # 0 Token
                 │
       ┌─────────┼──────────┐
       ▼         ▼          ▼
      NONE   Runtime Hint   Strong Trigger
                  │          but no candidate
                  ▼                 │
            Validate Hint           ▼
                              CandidateExtractionJob
                              # deferred / policy-gated
```

优先级：

1. **Deterministic Gate**：每轮 0 Token 执行；
2. **Inline Runtime Hint**：如果当前 DeepSeek / Codex 同一次 Turn 已产生结构化 `memory.candidate` / `memory.hint`，直接消费，不再额外调用模型；
3. **Deferred Extraction Job**：只有强触发且缺少足够结构化候选时才允许异步/后台提取；它不阻塞当前用户可见回复，也不是每轮固定调用；
4. 不部署一个“永久每轮运行的独立 Memory LLM”。

### 10.2.1 Strong Capture Triggers

至少包括：

- 用户显式 `remember / 记住 / 保存为记忆` 动作或 Memory Studio 操作；
- 用户明确纠正已有偏好 / 事实；
- 一个 Work Item / Task 到达可验证终态并产生复用价值；
- Review / failure 形成有证据的高价值 lesson；
- Agent 明确提出可复用 procedure / lesson candidate；
- 当前记忆与新证据发生 contradiction。

普通寒暄、重复确认、纯展示性输出默认 `NONE`。

## 10.3 Candidate 分类

```text
Candidate Evaluation
       ├─ NONE
       ├─ Episodic Candidate
       ├─ Semantic Candidate
       ├─ Procedural Candidate
       ├─ Preference Candidate
       ├─ Lesson Candidate
       └─ Shared Context Candidate
```

Shared Context Candidate 不写 Private Memory，而路由到：

```text
Requirement / Decision / Knowledge / Skill / Project State Domain
```

## 10.4 Auto-Commit / Inbox / Drop 默认策略

MVP 采用 **Conservative Autonomy**：

### AUTO ACTIVE

只允许：

- 用户在 Memory Studio 直接创建 / 确认的 Memory；
- 用户显式要求“记住”的低敏感 Private Memory；
- 用户明确纠正已有 Preference 时，新 Preference revision 可自动 ACTIVE 并 supersede 旧值；
- 从 Workbench 结构化 Task/Run outcome 确定性生成的低风险 Episodic fact，可在 Policy 允许时自动 ACTIVE。

### MEMORY INBOX

默认进入 Inbox：

- Agent 自己推断出的用户 Preference；
- Semantic / Procedural / Lesson；
- 与现有 Memory 冲突的任何候选；
- 高敏感内容；
- 需要从自然语言中推断、且缺少结构化证据的候选；
- 可能影响跨项目行为的长期约束。

### DEFER

当证据不足但存在潜在长期价值，例如重复 Pattern 尚未达到阈值时，进入 `DEFER`，等待更多 Experience，而不是立刻制造 Memory 或打扰用户。

### DROP / NONE

默认丢弃：

- 临时任务状态；
- Room/Mission 临时上下文；
- 重复内容；
- 无 sourceRefs 的高风险推断；
- Secret / credential；
- 无未来复用价值的普通回复。

未来可以增加 `Balanced / Autonomous` Memory Policy，但不得改变 Private Memory ownership 与 sourceRefs / revision / conflict 规则。

## 10.5 Candidate 状态

```text
PROPOSED
VALIDATING
DEFERRED
INBOX
ACTIVE
CONTESTED
SUPERSEDED
RETRACTED
ARCHIVED
TOMBSTONED
```

## 10.6 冲突不能直接覆盖

禁止简单：

```text
new value -> overwrite old row
```

要求：

```text
old Memory
   ↓ superseded_by
new Memory revision
```

保留 lineage / sourceRefs / revision history。

---

# 11. Canonical Memory Model

```ts
interface CanonicalAgentMemory {
  memoryId: string
  agentId: string
  memorySpaceId: string

  type:
    | 'episodic'
    | 'semantic'
    | 'procedural'
    | 'preference'
    | 'lesson'

  subjectRefs?: string[]
  content: unknown

  sourceRefs: string[]
  derivedFrom?: string[]

  confidence: number
  importance: number
  authority: number

  status:
    | 'proposed'
    | 'active'
    | 'contested'
    | 'superseded'
    | 'retracted'
    | 'archived'
    | 'tombstoned'

  supersedes?: string
  supersededBy?: string

  revision: number
  createdAt: string
  updatedAt: string
  expiresAt?: string

  sensitivity?: string
  originModelRef?: string
  originRuntimeRef?: string
}
```

约束：

- 每条 Memory 必须属于一个 `agentId + memorySpaceId`；
- 不存在“没有 owner Agent 的 Private Memory”；
- Project / Room / Organization 对象不得伪装为 CanonicalAgentMemory；
- Memory 可以引用 Project Shared Context，但不能取代其真源。

---

# 12. Workbench Durable Truth 与 AI Cluster Memory Engine 的真源关系

## 12.1 Linux MVP 的冻结规则

Linux MVP 已规定：

```text
workbenchd = Application Truth
single Canonical SQLite = durable product truth
workbenchd = single writer
```

因此 V3 默认采用：

> **Workbench Canonical SQLite 对 Agent Memory 的正式 revision / status / ownership / receipt 具有权威性。**

AI Cluster Memory Engine 不得在 Workbench 不知情的情况下独立产生一个不同的 Canonical Memory 真源。

## 12.2 推荐写入模型

```text
afterTurnMemory()
      ↓
Memory Mutation Proposal
      ↓
Workbench Memory Domain Validation
      ↓
Canonical SQLite transaction
  ├── Memory state/revision
  ├── Semantic Event
  ├── Receipt
  └── Outbox record
      ↓
AI Cluster Memory Engine
  ├── index
  ├── cache
  ├── graph
  ├── optional vector
  ├── replica / cluster sync
  └── retrieval acceleration
```

## 12.3 Canonical SQLite Layout — Memory 保持小而结构化

Memory 本身不应该成为大文档仓库，因此 MVP 不为普通 Memory 设计任意大型 blob payload。大型来源继续留在 Conversation/Event/Artifact/Workspace 真源，Memory 只保存 compact derived content + stable sourceRefs。

推荐表：

```text
memory_space
memory_record              # stable memory identity / head pointer
memory_revision            # append-only content revisions
memory_source_ref          # Conversation/Event/Artifact/Decision/Task refs
memory_candidate
memory_core_snapshot       # durable Core projection
memory_access_stat         # recall/use/correction counters
memory_turn_receipt
memory_outbox              # provider index/sync projection
```

推荐原则：

```text
memory_record
  memory_id
  agent_id
  memory_space_id
  head_revision
  type
  status

memory_revision
  memory_id
  revision
  content_text / content_json
  confidence / importance / authority
  source lineage
  created_at
```

### Payload Bound

默认：

```text
normal target <= 4 KiB serialized content
hard inline cap = 16 KiB per revision
```

超过 hard cap 的内容原则上不进入 sidecar 继续伪装成“Memory”；应拆分成多个 compact Memory，或写入 Knowledge / Skill / Artifact 并由 Memory 保存 ResourceRef。只有经过 ADR 的特殊结构类型才允许独立 blob。

### FTS / Index

```text
Canonical memory_revision = durable truth
FTS5 active-head index     = rebuildable projection
Vector / Graph             = optional rebuildable projection
Provider cache             = rebuildable / replica
```

所有检索必须先限定 `memory_space_id`，再进入 FTS / optional index。

### Commit Transaction

一个正式 Memory mutation 至少原子提交：

```text
Memory revision / head
+ Core Snapshot change（如受影响）
+ Semantic Event
+ Mutation Receipt
+ Outbox
```

Application Domain 负责事务语义，不把关键业务规则藏在 SQLite trigger 中。

---

## 12.4 Provider 写接口语义修正

MemoryProvider 不应拥有“绕过 Workbench 直接改 canonical truth”的自由写能力。

建议区分：

```text
Query Plane
- getCore
- recall
- getMemory

Analysis Plane
- proposeCandidate
- compareConflict
- consolidateSuggestion

Projection / Sync Plane
- indexRevision
- tombstoneRevision
- rebuild
- syncCursor
```

Canonical commit 由 Workbench Memory Domain 完成。

## 12.5 未来 Cluster-authoritative 模式

如果未来决定：

```text
AI Cluster Memory Engine
= authoritative Memory Store
```

则会修改：

```text
single Canonical SQLite / workbenchd single-writer
```

这一点必须单独 ADR，包含：

- consistency model；
- offline behavior；
- conflict resolution；
- backup / restore；
- migration；
- Workbench restart；
- multi-device semantics；
- rollback。

V3 不默认采用该模式。

---

# 13. MemoryProvider V3 Contract

## 13.1 原则

Provider 是 OSS / Cluster Engine 与 Workbench Memory Domain 之间的防火墙。

所有 Private Memory Query 必须显式带：

```text
agentId
memorySpaceId
```

Provider 必须验证绑定关系。

## 13.2 建议合同

```ts
interface MemoryProviderV3 {
  probe(): Promise<MemoryCapabilities>

  getCore(input: {
    agentId: string
    memorySpaceId: string
    expectedRevision?: number
    maxTokens: number
  }): Promise<CoreMemorySnapshot>

  recall(input: {
    agentId: string
    memorySpaceId: string
    query: string
    filters?: MemoryFilters
    limit: number
    maxTokens: number
    strategy: 'mandatory' | 'deep'
  }): Promise<RecallResult>

  get(input: {
    agentId: string
    memorySpaceId: string
    memoryIds: string[]
  }): Promise<CanonicalAgentMemory[]>

  compare(input: {
    agentId: string
    memorySpaceId: string
    candidate: MemoryCandidate
  }): Promise<ConflictAnalysis>

  indexRevision(input: CanonicalMemoryRevisionEnvelope): Promise<IndexReceipt>
  tombstoneRevision(input: MemoryTombstoneEnvelope): Promise<void>
  rebuildNamespace(input: NamespaceRebuildRequest): Promise<RebuildJobRef>

  health(): Promise<MemoryProviderHealth>
}
```

## 13.3 禁止万能接口

不提供：

```text
searchAllAgents()
readAnyNamespace()
runSql()
writeCanonicalWithoutReceipt()
```

Cross-Agent diagnostics 也必须通过 Workbench 强类型诊断 API，不给 Memory Engine 一个“超级管理员搜索全部私有脑”的普通工具入口。

---

# 14. MemoryTurnReceipt — 验证每轮是否真的使用了 Memory

每一个可见 Agent Turn 必须生成 MemoryTurnReceipt。

```ts
interface MemoryTurnReceipt {
  receiptId: string
  traceId: string
  turnId: string
  agentId: string
  memorySpaceId: string
  policyRevision: string

  core: {
    attempted: boolean
    loaded: boolean
    revision?: number
    tokens?: number
  }

  mandatoryRecall: {
    attempted: boolean
    queryPlanId?: string
    candidates: number
    selected: number
    selectedMemoryRefs: Array<{ memoryId: string; revision: number }>
    latencyMs: number
  }

  deepRecall?: {
    used: boolean
    strategies: string[]
    selectedMemoryRefs: Array<{ memoryId: string; revision: number }>
    latencyMs: number
  }

  materialization: Array<{
    ref: string
    revision?: number
    disposition: 'MATERIALIZED' | 'REF_ONLY' | 'EVICTED'
    reason?: string
  }>

  sharedContextRefs: string[]

  dropped: Array<{
    ref: string
    reason: 'permission' | 'namespace' | 'status' | 'temporal' | 'applicability' | 'egress' | 'duplicate' | 'rank' | 'budget' | 'conflict'
  }>

  degradedMode?: string
  createdAt: string
}
```

验收和诊断不再问：

> “它好像记住了吗？”

而是回答：

- 本轮是否调用；
- 调的是哪个 Agent；
- Core revision；
- Recall 命中；
- 哪些最终进入 Context；
- 哪些被丢弃；
- 为什么被丢弃；
- 是否降级；
- Provider latency。

---

# 15. Memory Failure / Degraded Policy

用户要求每轮必须经过 Memory，因此禁止静默变成裸 LLM；但“每轮必须经过 Memory”也不等于任意非核心索引故障都要阻断 Agent。

## 15.1 状态

```text
MEMORY_READY
MEMORY_CORE_ONLY
MEMORY_DEGRADED_FTS
MEMORY_DEGRADED_LOCAL
MEMORY_PROVIDER_RECOVERING
MEMORY_CORE_UNAVAILABLE
MEMORY_NAMESPACE_ERROR
MEMORY_CANONICAL_ERROR
```

## 15.2 可继续的降级

以下情况允许继续，并必须写入 MemoryTurnReceipt：

```text
Canonical Core 可验证
+ FTS 不可用
→ MEMORY_CORE_ONLY / MEMORY_DEGRADED_FTS
→ 继续 Runtime

Canonical Local 可读
+ Cluster / optional provider 不可达
→ MEMORY_DEGRADED_LOCAL
→ 继续 Runtime

Canonical revision 比 Provider 新
→ Workbench Canonical wins
→ Provider 标记 stale / rebuild
→ 可继续使用 canonical + available local indexes
```

新建 Agent 没有任何长期 Memory 不属于故障。它必须拥有合法的 `Core revision = 0` 空快照，并可正常 Turn。

## 15.3 必须阻断

以下情况默认阻断普通 Agent Turn：

- `agentId -> memorySpaceId` 无法解析；
- namespace ownership mismatch；
- Canonical SQLite 无法可靠读取该 Agent Core；
- Core revision / source lineage 无法验证且无法回退到 last-good Core；
- Memory 数据发生疑似跨 Agent 泄漏；
- Workbench 无法确认当前使用的是哪个 Agent MemorySpace。

阻断的原则不是“搜索质量下降”，而是“Agent Identity Continuity 无法被可信保证”。

## 15.4 Temporary No-Memory Mode

可以保留为 **默认关闭、Policy-gated 的 Developer / Recovery 模式**：

- 必须用户显式开启；
- UI 明显标记 `NO MEMORY / IDENTITY CONTINUITY OFF`；
- 默认禁止 Post-Turn 自动写长期 Memory；
- 不允许把该 Turn 伪装为正常 Agent continuity；
- 产生独立 Incident / Receipt；
- 普通用户产品路径不默认提供一键绕过。

---

# 16. Memory Studio / Glass Box

Memory 不应成为不可检查的后台黑盒。

每个 Agent 至少可查看：

```text
Memory Overview
Core Memory
Episodes
Knowledge
Procedures
Preferences
Lessons
Timeline
Turn Trace
Revision History
Conflicts / Contested
Archived
```

用户能力：

- 搜索；
- 查看来源；
- 查看哪次 Turn 使用过；
- 人工纠正；
- retract；
- supersede；
- archive；
- 查看 revision diff；
- 查看 MemoryTurnReceipt。

注意：

Memory Studio 只是真源投影 / 编辑入口，不直接绕过 Workbench Memory Domain 写底层 Provider。

---

# 17. 用户自定义 / 上传 / 安装 / Clone Agent

## 17.1 Agent Package

```text
agent-package/
├── agent.yaml
├── instructions.md
├── skills/
├── tool-requirements.json
├── runtime-compatibility.json
├── memory-policy.yaml
├── ui-metadata.json
└── signatures/
```

## 17.2 Instance Creation

任何 Create / Install / Import 都由 Workbench 分配：

```text
new agent_id
new privateMemorySpaceId
```

第三方 Agent Package 不能指定一个现有私有 namespace。

## 17.3 Clone

默认：

```text
Clone Definition
→ new Agent Instance
→ new blank Private MemorySpace
```

高级：

```text
Clone with Memory Snapshot
```

必须：

- 显式用户动作；
- 新 namespace；
- lineage；
- snapshot revision；
- 不允许两个 Agent 永久共用同一个可写 MemorySpace。

## 17.4 Upgrade

```text
Definition version changes
Agent Identity remains
Private Memory remains
```

升级不得默认清空 Memory。

---

# 18. 任意规模逻辑 Agent Registry 与活跃工作集扩展

## 18.1 Registry

```text
Agent Registry
├── A -> MemorySpace A
├── B -> MemorySpace B
├── ...
└── N -> MemorySpace N
```

Agent Registry 必须索引化。

## 18.2 Runtime 不按 Agent 常驻

```text
N Persistent Logical Agents
        ↓
Scheduler / Lazy Activation
        ↓
Active Agent Set
        ↓
DeepSeek / Codex Runtime Pool
```

Cold Agent：

- 不常驻模型；
- 不常驻 Harness worker；
- 只保留 durable identity / Memory / index。

## 18.3 Memory 性能规则

- Private recall 必须先 namespace narrowing；
- cache key 至少含 `agentId + namespaceRevision`；
- hot Agent 可缓存 Core / hot memory；
- cold namespace 延迟加载；
- Room participant 数不等于 Recall 次数；
- 只有真正激活的 Agent 执行 before/after Turn；
- 临时 Agent 仍有独立 ephemeral MemorySpace，可 TTL 回收或 Promote。

---

# 19. Token-Stable Memory / Cognitive Economy 性能基线

Memory 系统不能因为“每轮必调”或“Agent 使用时间越来越长”成为线性增长的 Token 成本源。

## 19.1 Token-Stable Memory

正式目标：

```text
Memory Corpus Size N
可以持续增长：

10K
100K
1M
10M+
```

但单次 Turn 的 Materialized Memory Token：

```text
T_memory
```

必须由 Policy / Context Budget 有界控制，而不是随 N 线性增长。

原则：

```text
Memory growth
≠
Context growth

Corpus growth 主要影响：
- durable storage；
- indexing；
- background maintenance；
- search latency / shard strategy。

Corpus growth 不得自动导致：
- 每轮 Prompt 线性变长；
- 每轮 Memory LLM 调用增多；
- 每轮输出线性变长；
- 每轮加载整个 MemorySpace。
```

正式设计目标：

> **The smallest context that preserves the correct decision.**

即：

> **保留正确决策所需的最小充分上下文。**

系统不追求“最大压缩率”，而追求在正确性、Authority、Privacy、Temporal Validity 不被破坏的前提下最小化 Materialized Context。

## 19.2 Minimum Necessary Recall Ladder

在 M0 Core 之后，M1/M2 Recall 必须遵循“先避免、再复用、再展开”的 Token Ladder：

```text
0. Core / hard identity continuity
   ↓
1. 本轮除 Core 外是否真的需要 Private Memory？
   ├── NO → Mandatory Recall 可正常返回 EMPTY
   ↓
2. 所需信息是否已经存在于 Current Context / Stable Prefix？
   ├── YES → ContextPresenceKey 去重 / reuse
   ↓
3. 是否存在 Direct MemoryRef / Project / Task / Entity / Resource anchor？
   ├── YES → Direct Resolve
   ↓
4. MemoryCapsule 是否已经足够？
   ├── YES → Capsule inline
   ↓
5. 是否只需 1-hop Relation / provenance / validity 补充？
   ├── YES → bounded relation expansion
   ↓
6. 是否真的需要完整 Canonical Memory Record？
   ├── YES → memory.read(...)
   ↓
7. 当前证据仍不足？
   ├── YES → M2 search_more(...)
   ↓
8. 最后才允许昂贵 Deep Recall：
   Vector / Graph / Reranker / HyDE / Fusion
```

因此：

```text
Mandatory Recall attempted = true
Relevant Memory selected = 0
```

是正常成功结果，不是 Memory Failure。

## 19.3 MemoryCapsule Projection

正式增加：

```text
MemoryCapsule
```

它是 Canonical Memory 的可重建、小型 Materialization Projection，不是真源。

示例：

```text
MemoryCapsule

memory_id: M81
source_revision: R7
type: LESSON

claim:
Runtime Adapter 激活前验证 protocol fingerprint。

why:
上游 Harness 升级曾改变协议字段并导致 Adapter crash。

applies_to:
runtime-upgrade

status:
CURRENT

evidence:
Incident I82
Run R91
Decision D18

expand:
memory://M81@R7
```

普通 Recall 优先注入 Capsule；只有 Runtime 明确需要 evidence / lineage / detailed procedure 时，才展开完整 Record。

建议 Capsule 元数据至少包含：

```text
memory_id
source_revision
source_hash
capsule_revision
projection_policy_revision
estimated_tokens
critical_fields_hash
expand_ref
```

当 Canonical Memory Revision 变化时：

```text
M81 R7 → M81 R8
```

所有以 R7 为源的 Capsule / cache 必须失效或重建，禁止继续作为当前事实使用。

## 19.4 Compression Safety Classes

Token Reduction 必须按 Source Role / Truth Criticality 分级，禁止所有 Context 使用同一压缩器。

| Context 类别 | 默认允许的处理 | 约束 |
|---|---|---|
| Current User Request | NONE | 不做有损压缩 |
| Agent Critical Core | NONE / STRUCTURED | 不允许改变 identity / standing constraint |
| Accepted Decision / Contract | STRUCTURED / EXTRACTIVE | authority、scope、revision 必须保留 |
| Current Work/Task State | STRUCTURED | 当前事实不可通过语义摘要改写 |
| Critical Error / Security Evidence | EXTRACTIVE ONLY | 不允许生成式改写证据 |
| Private Lesson / Procedure | CAPSULE + REF | 适合结构化投影 |
| Episode | CAPSULE / REF_ONLY | 普通 Turn 不需全文 |
| Conversation History | DELTA / CHECKPOINT / EXTRACTIVE | Raw Event 不覆盖 |
| Tool Output | PROJECTION + RAW_REF | Raw Sidecar 保留 |
| Large Knowledge / Docs | EXCERPT + REF | 按需展开 |
| Archived Memory | REF_ONLY default | 仅 Deep/Historical Recall 展开 |

核心原则：

> **越接近 Current Truth / Authority / Safety Evidence，越不能做 lossy compression；越接近历史支持材料，越可以积极选择、裁剪与按需展开。**

## 19.5 Compression Modes

正式定义：

```text
C0 NONE
C1 STRUCTURED_PROJECTION
C2 EXTRACTIVE_PRUNING
C3 SEMANTIC_COMPRESSION
```

规则：

```text
C0
- Current User Request
- hard identity / critical constraint

C1
- Core derived structures
- Decision / Contract
- Task State
- MemoryCapsule

C2
- Conversation block
- long Knowledge
- duplicated supporting context
- Tool Result projection

C3
- 仅限低风险 supporting context
- 必须可回源
- 必须有 CompressionReceipt
- 必须通过 Benchmark
- 不得成为 Authority / Current State / Critical Evidence 默认路径
```

压缩失败时必须：

```text
fallback to safer projection / ref-only / full source
```

不得继续使用验证失败的压缩内容。

## 19.6 Selection Before Rewriting

Token Economy 的默认优先级：

```text
1. Do not select
2. Namespace / Scope filter
3. Dedup
4. Superseded / Temporal / Applicability filter
5. Ref-only
6. Structured projection
7. Extractive pruning
8. Semantic compression
```

因此系统优先：

> **Compress by selection before rewriting.**

禁止采用：

```text
先塞 50K Context
→ 再固定调用一个 LLM 总结成 5K
```

作为默认热路径。

## 19.7 Materialization Cache / Context Presence

使用：

```text
ContextPresenceKey
=
resource_id
+
revision_or_hash
+
materialization_policy_revision
```

同一 Runtime Session / Stable Prefix 中，如果：

```text
M81 R7
```

已经存在且未失效，则后续 Turn 不重复作为新正文 Materialize。

只有：

```text
M81 R8
```

或 Materialization Policy 变化时重新构建。

若 Provider / Harness 支持 Prompt Cache，则可利用 Provider Cache；即使不支持，也必须在 Workbench 侧保持 Base + Delta + Ref + Dedup 语义。

## 19.8 OutputTokenLease / Minimum Sufficient Output

Token Economy 同时治理输出，而不只治理输入。

正式增加逻辑对象：

```text
OutputTokenLease
```

由：

```text
ContextProfile
+ User Preference
+ Task Type
+ Surface
+ Runtime Capability
```

决定建议的输出预算。

原则：

```text
CHAT
→ concise/default

CODING
→ code/change/evidence + minimal explanation

ROOM
→ conclusion / evidence / next action

HANDOFF
→ structured HandoffCapsule

ARCHITECTURE / REPORT
→ explicit larger budget
```

目标：

> **Minimum Sufficient Output**

Agent 不应因为拥有更多 Memory 就自动输出更多历史背景。

## 19.9 HandoffCapsule

跨 Agent / Runtime / Room Handoff 默认使用结构化小包：

```text
HandoffCapsule
├ objective
├ current_state_refs[]
├ decision_refs[]
├ evidence_refs[]
├ changed_refs[]
├ constraints[]
├ risks[]
├ open_questions[]
├ next_action
└ source_trace_ref
```

禁止默认把完整 Conversation、完整 Memory、上一 Agent 长篇输出复制给下一个 Agent。

## 19.10 CognitiveEconomyController

正式增加逻辑组件：

```text
AgentTurnCoordinator
        │
        ▼
MemoryLifecycleCoordinator
        │
        ▼
Context Broker
        │
        ├── Context Arbitration
        │
        └── CognitiveEconomyController
              ├ Recall Budget
              ├ MemoryCapsule selection
              ├ Dedup / Ref-only conversion
              ├ Compression Safety Policy
              ├ On-demand Expansion Budget
              ├ Materialization Cache
              └ OutputTokenLease
        │
        ▼
Runtime
```

`CognitiveEconomyController`：

- 不是新的数据真源；
- 不拥有 Canonical Memory；
- 不改变 Domain Authority；
- 不得绕过 Privacy / Egress / Namespace；
- 只决定“这一 Turn 值得花多少 Context / Output Token”。

## 19.11 CompressionReceipt

任何会改变 Materialized Representation 的压缩/投影操作必须可解释。

建议：

```text
CompressionReceipt {
    trace_id
    source_ref
    source_revision
    original_estimated_tokens
    final_estimated_tokens

    mode:
      NONE |
      STRUCTURED_PROJECTION |
      EXTRACTIVE_PRUNING |
      SEMANTIC_COMPRESSION

    critical_fields_preserved[]
    validation_status
    policy_revision
    compressor_id?
    compressor_version?
    expansion_ref
    fallback_used?
}
```

如果是 Semantic Compression，必须明确标记：

```text
loss_class = LOSSY_SEMANTIC
```

禁止把它伪装成 Canonical Source。

## 19.12 OSS Research References — Non-normative

以下项目只作为设计参考或未来 Provider/POC 候选；不因列入本章节而成为正式依赖。

### Ponytail

Repository:

`https://github.com/DietrichGebert/ponytail`

可借鉴：

- “只做任务真正需要的工作”的 decision ladder；
- correctness/safety 不因追求更短输出而删除；
- 对 agentic workflow 进行真实仓库 benchmark，而不是只看单轮文本长度；
- Token / Cost 收益与 workload 有关，不把“越短越好”当目标。

本系统映射：

```text
Minimum Necessary Work
→
Minimum Necessary Recall
+
Minimum Necessary Context
+
Minimum Sufficient Output
```

### Letta

Repositories / docs:

- `https://github.com/letta-ai/letta-code`
- `https://github.com/letta-ai/skills`

可借鉴：

- 小型、持续在 Context 中的 Memory Blocks；
- External Memory 留在 Context 外，按需 Search；
- Core Context 属于稀缺资源，应保持 lean。

本系统仍保持：

```text
CoreMemorySnapshot = Workbench Projection
External Private Memory = Canonical Memory + Retrieval
```

不采用其存储真源作为 Workbench 真源。

### context-compressor

Repository:

`https://github.com/ingridtoulotte/context-compressor`

可借鉴：

- deterministic / extractive / lossless-first；
- 先去重复、低价值内容；
- 对 constraint / decision / preference 做 validation/audit；
- Compression 失败不算成功。

建议只作为 POC / ContextCompressionProvider 候选，通过 Q17 Benchmark 后再决定是否集成。

### LLMLingua

Repository:

`https://github.com/microsoft/LLMLingua`

可借鉴：

- prompt compression；
- Long-context context selection；
- token-level / sentence-level compression。

约束：

```text
不得默认用于：
Core Critical
Accepted Decision
Current State
Security/Critical Evidence
```

只能作为 Optional C3 Semantic Compression Provider 评估。

### Mnesis

Repository:

`https://github.com/Lucenor/mnesis`

可借鉴：

- Immutable Store + token-budgeted Active Context；
- Tool Output pruning 但保留 immutable source；
- 大文件使用 FileRef；
- Compaction 异步、不阻塞前台 Turn。

### Graphiti

Repository:

`https://github.com/getzep/graphiti`

定位：

```text
Candidate Set Reducer / Temporal Graph Provider
≠ Context Compressor
```

可借鉴 temporal validity、relationship-aware narrowing 和 hybrid retrieval；是否进入主链必须经 Benchmark。

### Mem0 / memory-benchmarks

Repositories:

- `https://github.com/mem0ai/mem0`
- `https://github.com/mem0ai/memory-benchmarks`

可借鉴：

- LongMemEval / LOCOMO / BEAM 等长记忆评测框架和 token-aware evaluation；
- 作为外部基准参考，而不是直接替代 Workbench 自有 Namespace/Continuity/Privacy Benchmark。

## 19.13 初始工程预算

以下为待 Benchmark 校准的工程目标，不是产品承诺：

```text
Core load local P95             < 20ms
Mandatory private recall P95    < 60ms
beforeTurnMemory local P95      < 100ms
Memory receipt commit P95       < 50ms

Memory Capsule:
typical target                  60–150 tokens / item

Mandatory retrieved memory:
default target                  <= ~1K tokens

Deep Recall total:
bounded by MemoryRecallLease

namespace mismatch denial       immediate / deterministic
```

具体 Token Budget 不应作为永久固定常量，必须按 Runtime Context Window、Task Profile 与 Q17 Benchmark 调整。

远端 Cluster / Sync 不得阻塞本地 Core continuity；如果未来允许 remote-only namespace，必须另行定义更高 SLA。
# 20. Security / Privacy / Cloud Egress

## 20.1 Private Memory 隔离与 Cloud Egress 是两个维度

```text
Agent A Private
```

不代表它一定可以发送给任何云模型。

Workbench 在 Materialization 前仍执行 Data Egress Policy。

可能出现：

```text
Memory belongs to Agent A
AND
current provider = restricted cloud
→ only approved / redacted subset may materialize
```

## 20.2 Secrets

禁止 Memory 保存：

- API Key 明文；
- Password 明文；
- Private Key；
- Secret Environment Variable 明文；
- Harness auth token。

Memory 可以保存：

```text
CredentialRef / secret name / usage constraint
```

但不能保存秘密值本身。

## 20.3 Cross-Agent Access

正常产品路径：

```text
cross-agent private memory read = DENY
```

管理员诊断也不应默认获得 unrestricted private content；必须通过专门诊断 / privacy scope。

---

# 21. Non-Docker Deployment

## 21.1 官方默认

```text
Native binaries / Node / Python env
+ systemd --user / systemd service
+ Unix Domain Socket
+ XDG data dirs
```

推荐拓扑：

```text
workbenchd.service
      ↕ UDS
ai-memoryd.service            # 若 AI Cluster Memory 采用独立进程
      ├── FTS / indexes
      ├── graph worker
      ├── optional vector worker
      └── sync worker
```

如果 Memory Engine 早期足够轻，也允许先作为 Workbench Memory crate / local library 实现，再保持 Provider Contract 以便后续拆成 `ai-memoryd`。

## 21.2 可选隔离

允许：

```text
Rootless Podman + Quadlet
systemd-nspawn
Incus / LXC
```

但 Docker / Docker Compose 不进入官方依赖。

## 21.3 不因逻辑 Agent 数量大就引入 Kubernetes

无论是数百、数千还是更多 Agent，首先都应理解为逻辑身份/namespace 数，而不是常驻服务数。

只有未来确实出现多机 Memory shard / distributed scheduler 需求时再讨论集群编排。

---

# 22. 多开源项目整合原则

## 22.1 Integration Registry

所有 OSS 必须登记：

```yaml
id: <component-id>
upstream: <repository>
role: runtime|memory|index|embedding|graph|parser|visualization|sync|observability
version: <pinned tag/commit>
license: <license>
integration: library|stdio|uds|http|sidecar|cli
state_owner: true|false
data_dir: <path>
healthcheck: <command/interface>
upgrade_policy: pinned
patches: []
```

## 22.2 Memory 相关 OSS 只能进入 Provider / Engine 层

```text
Workbench Memory Domain
        │
        ▼
MemoryProvider V3
        │
 ┌──────┼────────────┐
 ▼      ▼            ▼
Store  FTS/Index   Graph
OSS A   OSS B       OSS C
```

Workbench 不依赖这些上游项目的内部业务对象。

## 22.3 Source-of-Truth 冲突规则

如果两个 OSS 都声称自己是“Memory 主数据库”：

```text
必须只选一个 state_owner
```

在 Linux MVP 中，基于当前 Workbench freeze：

```text
state_owner for canonical product memory = workbenchd / Canonical SQLite
```

其他引擎做：

- index；
- retrieval；
- analysis；
- replica；
- optional graph/vector；
- consolidation suggestion。

## 22.4 优先进程边界

对更新频繁 / 异语言 / 重依赖项目优先：

```text
stdio
UDS
local RPC
sidecar
```

只有稳定、无状态、接口清晰的库适合直接 link/import。

---

# 23. Observability / Metrics / Evaluation

至少监控：

```text
memory_before_turn_call_rate
memory_before_turn_failure_rate
memory_core_load_latency
memory_private_recall_latency
memory_namespace_mismatch_denied
memory_cross_agent_access_denied

memory_context_items_per_turn
memory_context_tokens_per_turn
memory_capsule_tokens_per_turn
memory_full_record_expansion_rate
memory_unnecessary_expansion_rate
memory_context_cache_reuse_rate
memory_duplicate_token_rate

memory_candidate_rate
memory_candidate_accept_rate
memory_capture_precision
memory_capture_recall
memory_capture_f1
memory_premature_generalization_rate

memory_supersede_rate
memory_retracted_rate
memory_degraded_turn_rate
memory_materialized_rate
memory_runtime_explicit_reference_rate
memory_false_or_stale_injection_rate

memory_compression_original_tokens
memory_compression_final_tokens
memory_compression_validation_fail_rate
memory_semantic_compression_rate

memory_output_tokens_per_turn
memory_total_input_tokens_per_successful_task
memory_output_tokens_per_successful_task
memory_useful_recall_per_1k_tokens
```

硬指标：

```text
可见 Agent Turn 的 Memory Lifecycle 覆盖率 = 100%
未授权跨 Agent Private Memory 成功读取 = 0
namespace mismatch = deterministic deny
Critical Truth lossy compression = 0
```

质量评估不能只用“检索命中率”。必须至少区分：

```text
Recall Precision
Recall Coverage / Recall@K
Useful Recall Rate
False Recall Rate
Stale / Superseded Injection Rate
Context Pollution Rate
Recall-to-Materialization Survival
Critical Context Preservation
Correction Propagation Time
Cross-Agent Leakage Rate
Latency / Token Overhead
Compression Distortion / Validation Failure
Capture Precision / Recall / F1
```

Memory 技术优化必须同时观察：

```text
Quality
+
Token
+
Latency
+
Reliability
+
Privacy
```

禁止只以“Compression Ratio”“Vector Hit Rate”“Graph Node Count”等单一指标证明系统变好。
# 24. Backup / Restore / Rebuild

## 24.1 Canonical Backup

Linux MVP 普通 Workbench Backup 必须覆盖：

- Agent Identity；
- MemorySpace ownership；
- Canonical Memory revision/status；
- Memory receipts；
- candidate / conflict metadata；
- provider sync cursor / rebuild metadata（如需要）。

## 24.2 Rebuildable Data

以下应尽量可重建：

- FTS projection；
- vector index；
- graph index；
- hot cache；
- ranking cache。

## 24.3 Restore 后

```text
restore Canonical DB
→ validate MemorySpace bindings
→ provider rebuild/sync
→ verify Core revision
→ run namespace isolation test
→ READY
```

不得因为 index 丢失就丢失 Canonical Memory。

---

# 25. MVP 实施顺序

## Phase M0 — Memory Walking Skeleton

只做 3 个 Agent + FakeRuntime：

必须通过：

```text
Create Agent A/B/C
→ unique MemorySpace A/B/C
→ send Turn to A
→ beforeTurnMemory(A)
→ FakeRuntime
→ afterTurnMemory(A)
→ MemoryTurnReceipt
→ restart workbenchd
→ A Memory continuity remains
→ B cannot read A
```

全链可在 CI 0 Token 完成。

## Phase M1 — Real Runtime Integration

- Codex Adapter；
- DeepSeek Adapter；
- 同一 Agent Runtime rebind；
- Memory continuity；
- ContextPackage trace。

验收：

```text
Agent A on Codex
→ learns validated Memory
→ next Turn on DeepSeek
→ same MemorySpace recalled
```

## Phase M2 — Project Shared Context

- Requirement / Decision / Knowledge refs；
- Shared Context Broker；
- Private vs Shared separation；
- Private insight → Shared Candidate。

## Phase M3 — Room / Mission

- selected Agent Turn lifecycle；
- Room Digest；
- Structured Handoff；
- no private-memory broadcasting；
- multi-Agent independent post-turn capture。

## Phase M4 — Memory Studio

- Core editor；
- search；
- Turn Trace；
- revision；
- conflict；
- retract / supersede。

## Phase M5 — AI Cluster Engine Hardening

- separate `ai-memoryd` if needed；
- namespace auth；
- index workers；
- optional graph/vector；
- cluster sync；
- fault injection；
- backup/rebuild；
- 多档 Registered/Active Agent、Memory Record、Concurrent Turn benchmark；`800` 仅可作为其中一个兼容历史档位。

---

# 26. V3 验收标准

## 26.1 Agent Isolation

- 任意已注册 Agent 都拥有独立逻辑 MemorySpace；不存在“800 Agent”产品级硬上限；
- Agent A Private Memory 不可被 B 普通路径读取；
- Agent Runtime 从 Codex ↔ DeepSeek 切换不改变 MemorySpace；
- Agent Clone 默认创建新 MemorySpace；
- Agent disable / archive / purge 有明确生命周期。

## 26.2 Mandatory Memory Invocation

- 每个可见 Agent Turn 都有 MemoryTurnReceipt；
- 每轮 Core load attempted；
- 每轮 Mandatory Recall attempted；
- 用户可见 Agent Turn 不存在绕过 Memory Lifecycle 的 Runtime direct path；
- Memory 完全不可用时不静默生成“正常连续人格”回复。

## 26.3 Shared Context Separation

- Project / Room / Mission 共同事实不存入所谓 Shared Memory；
- Agent 可读取 Shared Context；
- Shared Context 不自动复制到 Agent Private Memory；
- Agent 私有经验不自动广播；
- 私有 insight 只有经过 Candidate / Publish 才成为共享业务事实。

## 26.4 Room / Mission

- Room 中多个 Agent 分别调用自己的 Memory；
- Room 100 participants 不触发 100 个模型/Recall；
- Handoff 不携带 Private Memory Record；
- 每个 Agent 在同一 Mission 后可形成不同 Lesson / Episode。

## 26.5 Durable Truth

- Canonical Memory mutation 通过 workbenchd 单写；
- Memory revision + semantic event + receipt 在相应事务中一致提交；
- Cluster index/provider 可重建；
- Provider 不可制造 Workbench 不知道的权威 Memory revision。

## 26.6 Deployment

- 官方安装不依赖 Docker / Compose；
- Native + systemd 可完成完整运行；
- `ai-memoryd` 如拆分，优先 UDS；
- OSS 均有 Integration Registry；
- upgrade 有 contract test / last-good / rollback 方案。

---

# 27. Decision Log — V3.0 / V3.1 Base

## M-D001 — Agent Private MemorySpace 是唯一 Agent Memory 所有权单位

**决定：** 每个持久 Agent Instance 有唯一 Private MemorySpace。Runtime、Conversation、Room、Project 均不能替代 Agent 作为 Private Memory owner。  
**状态：** Accepted Candidate

## M-D002 — 废止产品层 Shared Memory

**决定：** Room / Project / Organization 不建立共享 Memory 池。共同事实进入 Workbench Shared Context / Knowledge / Decision / State / Artifact Domain。  
**状态：** Accepted Candidate

## M-D003 — 每个可见 Agent Turn 强制 Pre/Post Memory Lifecycle

**决定：** `beforeTurnMemory -> Runtime -> afterTurnMemory` 由 workbenchd 强制执行。基础 Memory Recall 不是模型可选 Tool。  
**状态：** Accepted Candidate

## M-D004 — Memory Lifecycle Coordinator 属于 Workbench，不属于 Provider

**决定：** Turn 生命周期、Candidate 分类路由、Shared Context 连接、Receipt 均由 Workbench Memory Domain 负责；MemoryProvider 只提供稳定的 Memory 引擎能力。  
**状态：** Accepted Candidate

## M-D005 — Workbench Shared Context 与 Agent Private Memory 在 Context Broker 汇合

**决定：** 两者只在当前 Turn 的 Context Materialization 阶段组合，不在存储层合并。  
**状态：** Accepted Candidate

## M-D006 — Linux MVP Canonical Memory Truth 服从 workbenchd 单写 SQLite

**决定：** 在当前 Architecture Freeze 下，正式 Memory revision/status/ownership 由 Workbench Canonical SQLite 决定；AI Cluster Memory Engine 作为 namespace-aware retrieval/index/analysis/replica engine 接入。若未来改为 Cluster-authoritative，必须 ADR。  
**状态：** Accepted Candidate

## M-D007 — Agent 间只传 Handoff / Evidence，不传 Private Memory Record

**决定：** Main Chat / Room / Mission / Agent Handoff 均使用结构化任务上下文；Private Memory 不作为协作消息载体。  
**状态：** Accepted Candidate

## M-D008 — Mandatory Recall 使用 No-Embedding Baseline

**决定：** Core + Direct/Metadata + FTS/BM25 是 MVP Mandatory Recall 基线；Vector / Graph / HyDE / Fusion / Reranker 为可选 Deep Recall。  
**状态：** Accepted Candidate

## M-D009 — 非 Docker 官方部署

**决定：** Native + systemd 是默认；可选 rootless Podman / systemd-nspawn / Incus/LXC，但 Docker / Compose 不是官方依赖。  
**状态：** Accepted Candidate

## M-D010 — OSS 通过 Provider / Adapter 合同整合

**决定：** Memory OSS 只能通过 Integration Registry + Provider/Engine Boundary 接入，不进行无边界源码大拼接。  
**状态：** Accepted Candidate

## M-D011 — Core Memory 是有界 Durable Projection

**决定：** Core 不是普通无限增长 Memory 类型，而是从当前有效 Canonical Private Memory 中选取并物化的每轮直接加载快照；默认 soft 512 / hard 1024 estimated tokens，12 KiB byte hard cap。  
**状态：** Accepted Candidate

## M-D012 — afterTurn 使用 Deterministic Gate + Opportunistic Extraction

**决定：** 每轮 afterTurnMemory 必须执行，但不得固定增加第二次 LLM 调用。优先 0-Token capture gate 和同一 Runtime Turn 的 structured hint；强触发但缺候选时才允许 deferred extraction job。  
**状态：** Accepted Candidate

## M-D013 — MVP Memory Autonomy 采用 Conservative Policy

**决定：** 用户显式确认/纠正与少量确定性低风险 Episodic 可自动 ACTIVE；Agent 推断 Preference、Semantic、Procedural、Lesson 与冲突候选默认进入 Memory Inbox。  
**状态：** Accepted Candidate

## M-D014 — Memory Degradation 以 Identity Continuity 为硬边界

**决定：** FTS/Cluster/Optional Index 故障可 Core-only/local degraded 继续；只有 namespace/Core/Canonical continuity 无法可信保证时才阻断普通 Agent Turn。  
**状态：** Accepted Candidate

## M-D015 — Canonical Memory Compact-in-SQLite

**决定：** Canonical Memory revision 在主 SQLite 中保存 compact content + sourceRefs；普通 revision 默认目标 <=4 KiB、hard inline cap 16 KiB。大型内容必须转 Knowledge/Skill/Artifact 引用，不把 Memory Store 变成 blob 仓库。  
**状态：** Accepted Candidate

---

# 28. V3.2 Retrieval Query Plan 与 Usage Feedback

本章锁定原 Q6/Q7。Memory Retrieval 不再以“用户原话直接 FTS”作为唯一输入，也不要求每轮调用第二个 LLM 进行 Query Rewrite。

## 28.1 `MemoryQueryPlan`

每个 Mandatory Recall 先生成 Runtime-neutral、namespace-bound 的结构化查询计划：

```text
MemoryQueryPlan
├─ query_plan_id
├─ turn_id
├─ agent_id
├─ memory_space_id
├─ surface
├─ anchors
│  ├─ project_id?
│  ├─ work_item_id?
│  ├─ mission_id?
│  ├─ task_id?
│  ├─ resource_refs[]
│  └─ entity_refs[]
├─ lexical_terms[]
├─ preferred_memory_types[]
├─ temporal_mode
├─ source_constraints[]
├─ max_items
├─ token_budget
├─ deep_recall_allowed
└─ policy_revision
```

默认构建来源：Current User Turn + Current Work/Task + Project/Mission identity + Explicit ResourceRefs + Recent Conversation Delta + Core hints。默认 `LLM Calls = 0`。

## 28.2 Retrieval 分层

```text
R0 Core
R1 Direct Resolve
R2 Metadata + FTS/BM25
R3 1-hop Relation Expansion
R4 Agent-directed Deep Recall (optional)
```

Private Recall 必须先做 `memory_space_id = current_agent.memory_space` 的 namespace narrowing，再进行搜索；禁止先全局搜索后再过滤 Agent。

## 28.3 Ranking 不使用单一“万能分数”

流程：

```text
Candidate Generation
→ Hard Filters
→ Feature Scoring
→ Dedup / Diversification
→ Token Packing
```

Hard Filter 至少覆盖：ownership、namespace、status、supersede、temporal validity、applicability、permission、egress。

Feature 至少覆盖：relevance、anchor_match、type_fit、authority、freshness、importance、retrieval_utility、why/how fit、conflict/redundancy penalty。

## 28.4 Memory 使用反馈

必须区分：

```text
RETRIEVED
SELECTED
MATERIALIZED
REF_ONLY
RUNTIME_REFERENCED
OUTCOME_ASSOCIATED
USER_CONFIRMED
USER_REJECTED
```

Memory 被检索或注入本身不构成正反馈。Truth/Authority 与 Retrieval Utility 分离，禁止形成“因为常被召回所以越来越像真理”的自强化循环。

### D-MEM-020 — Structured MemoryQueryPlan

**决定：** 每个 Agent Turn 的 Mandatory Recall 必须先生成 namespace-bound、token-budgeted `MemoryQueryPlan`；默认使用确定性 anchors + FTS/BM25/Relation，不要求第二个检索模型。  
**状态：** Accepted Candidate

### D-MEM-021 — Evidence-weighted Memory Utility Feedback

**决定：** Memory 使用状态显式分层；显式用户反馈、Source invalidation、Supersede 等强证据优先，任务成功只提供弱相关信号，无证据时不更新 Utility。  
**状态：** Accepted Candidate

---

# 29. Workbench Cognitive Integration / Temporal Conflict

AI Cluster Memory 连接整个 Workbench 的方式不是成为 Runtime Integration Bus，而是成为长期 `Cognitive / Experience Layer`。

## 29.1 Cognitive Integration Boundary

```text
Workbench Domain Event
        ↓
Semantic / Cognitive Event
        ↓
Experience Builder
        ↓
Agent Attribution
        ↓
Memory Candidate
        ↓
Future Recall
```

Memory 负责跨时间连接经验，不负责在运行时连接业务服务。

禁止：

```text
Scheduler -> ask Memory for current Task truth
Workspace -> ask Memory for current file truth
Diagnostics -> ask Memory for current Incident truth
```

这些仍由 Workbench Domain API / State / Event / ResourceRef 解决。

## 29.2 `CognitiveEvent`

```text
CognitiveEvent
├─ event_id
├─ event_type
├─ actor { user_id?, agent_id?, runtime_id? }
├─ context { project_id?, work_item_id?, room_id?, mission_id?, task_id? }
├─ subjects ResourceRef[]
├─ outcome
├─ evidence_refs[]
├─ importance_hint
├─ sensitivity
└─ source_event_ref
```

高频 token/progress/heartbeat 等噪音事件默认不进入 Cognitive Pipeline。

## 29.3 Conflict 类型

至少区分：

```text
Correction
Temporal Evolution
Scoped Exception
Unresolved Evidence Conflict
Source Invalidation
```

不能统一采用“最新的赢”。

## 29.4 Temporal / Applicability

Memory Revision 至少支持：

```text
observed_at
valid_from
valid_to
recorded_at
applicability
```

当前任务默认检索当前有效且上下文匹配的 revision；历史调查可以显式查询 superseded/historical revision。

## 29.5 Memory Relation

至少支持：

```text
supersedes
contradicts
refines
derived_from
supports
applies_to
related_to
caused_by
validated_by
invalidated_by
```

MVP 可使用 SQLite relation table，不要求 Graph DB。

### D-MEM-022 — Workbench Cognitive Integration Boundary

**决定：** Memory 消费 Workbench Semantic/Cognitive Events 并形成长期 Experience，但不得成为业务服务 Runtime Integration Bus。  
**状态：** Accepted Candidate

### D-MEM-023 — Revision-first Canonical Memory

**决定：** Canonical Memory 使用稳定 `memory_id + immutable revision lineage`；修改产生新 revision，禁止静默原地覆盖；Turn Trace 必须记录实际使用的 revision。  
**状态：** Accepted Candidate

### D-MEM-024 — Context-aware Conflict Resolution

**决定：** 冲突必须区分纠正、时间演进、范围例外、未决证据和 Source Invalidation；Authority、Applicability、Evidence、Temporal Validity 优先于简单 recency。  
**状态：** Accepted Candidate

### D-MEM-025 — Temporal Validity & Applicability

**决定：** Memory 支持 observed/valid/recorded 时间与 applicability；当前查询与历史查询使用不同 temporal mode。  
**状态：** Accepted Candidate

### D-MEM-026 — Staleness Is Not Deletion

**决定：** Stale 是 Retrieval / Review 信号，不自动等于错误或删除；不同 Memory Type 使用不同 Freshness Policy。  
**状态：** Accepted Candidate

---

# 30. Memory Maintenance / Forgetting / Offline Recovery / Scale

旧 `AUTO DREAM` 的思想保留，但底层正式重构为 `Memory Maintenance Engine`。

## 30.1 Forgetting ≠ Delete

Memory Retrieval Temperature：

```text
HOT
WARM
COOL
COLD
ARCHIVED
```

与 Lifecycle State 正交：

```text
candidate / active / contested / superseded / retracted / archived / tombstoned
```

长期未使用默认导致 retrieval demotion，而不是物理删除。

## 30.2 Consolidation

多个 Episode/Lesson/Procedure 可以形成更高层 Consolidated Memory：

```text
Episodes / Lessons
      ↓
MemoryCluster (projection)
      ↓
Consolidated Lesson / Procedure Candidate
```

原始 Memory 保留 lineage，并可降温；普通 Recall 优先 Consolidated Memory。

## 30.3 Maintenance Trigger

```text
Event Trigger
Idle Trigger
Pressure Trigger
Policy Trigger
Manual Trigger
Scheduled Trigger
      ↓
MemoryMaintenancePlan
```

Scheduled 不是唯一触发，也不得写死 03:00。

## 30.4 关机语义

```text
Device OFF
→ local Recall / Maintenance / Index / Sync stop
→ Canonical Memory persists

Device ON
→ Memory Recovery Sweep
→ restore dirty projections / pending intents / sync cursor
→ lazy Agent activation
```

当前版本不考虑“电脑关机后 Agent 继续自主学习”。未显式启用其它节点时，关机期间 Memory LLM 调用为 0。

## 30.5 Memory Recovery Sweep

至少：

- Canonical DB/WAL integrity；
- MemorySpace ownership；
- pending outbox / deletion propagation；
- Core dirty check；
- FTS/index dirty check；
- interrupted maintenance requeue；
- sync cursor restore。

## 30.6 规模模型

产品级不设“800 Agent”固定上限。性能模型必须使用：

```text
Registered Agent Count
Active Agent Count
Warm Agent Count
Total Memory Records
Hot Namespace Count
Concurrent Turns
Concurrent Recall
Index Update Rate
```

大量逻辑 Agent 通过 Registry + Lazy Activation + Runtime Pool 管理。

### D-MEM-027 — Forgetting Is Retrieval Demotion, Not Deletion
### D-MEM-028 — Memory Maintenance Engine
### D-MEM-029 — Evidence-preserving Consolidation
### D-MEM-030 — Core Promotion/Demotion Are Maintenance Operations
### D-MEM-031 — Retention Is Type- and Evidence-aware
### D-MEM-032 — Deletion Propagates Across Projections
### D-MEM-033 — Agent Count Is Logical, Not Resident
### D-MEM-034 — Device Power-off Pauses Local Cognitive Computation
### D-MEM-035 — Memory Maintenance Uses Eventual Catch-up
### D-MEM-036 — Offline Means Zero Unrequested LLM Cost

**共同状态：** Accepted Candidate。当前版本不启用“关机后 Agent 自主学习”；如未来出现 Always-on Node，必须独立 ADR/Policy。

---

# 31. Memory Invocation 与 Context Arbitration

## 31.1 四级 Memory Invocation

```text
M0 Identity Recall       # Workbench 强制，Runtime 不可跳过
M1 Mandatory Recall      # Workbench 强制，MemoryQueryPlan
M2 Deep Recall           # Agent Runtime 按需，但 namespace/预算由 Workbench 锁定
M3 Post-turn Capture     # Workbench 强制执行 Capture Evaluation
```

Runtime 可以控制 query/filter/depth，但不能控制 owner、agentId、MemorySpace、permission、Canonical Store。

建议 Runtime 暴露窄接口：

```text
memory.search_more(...)
memory.read(ref)
memory.trace(ref)
memory.propose(...)
```

禁止 Runtime 获得 `memory.sql / writeCanonical / switchMemorySpace`。

## 31.2 Recall Budget

每 Turn 通过 `MemoryRecallLease` 限制：max items、tokens、deep-call count、latency、depth。可访问 Memory 不等于无界注入。

## 31.3 Context Broker = Cognitive Arbitration Engine

正式区分：

```text
Reachable Context  >>  Materialized Context
```

Materialization Mode：

```text
MUST_INLINE
INLINE
REF_ONLY
ON_DEMAND
NEVER
```

Context Priority Class：

```text
C0 Turn Contract
C1 Agent Identity / Core
C2 Current Authoritative Reality
C3 Current Evidence
C4 Agent Private Experience
C5 Conversation Delta
C6 Supporting Knowledge / Resource
C7 Active Tool / Skill Schema
```

原则：`Current Reality / Evidence > Historical Experience`。

## 31.4 Budget 机制

使用 `hard reservation + min/preferred/max + elastic pool`，不使用永久固定百分比。Token 压力时先 dedup、drop stale/superseded、full→excerpt→ref，再压缩低 utility Memory/Conversation/Knowledge；Current User Request、Task Contract、Critical Evidence、Core 不得被静默驱逐。

## 31.5 Stable Prefix + Dynamic Delta

```text
Stable Prefix:
Agent Definition + Core Snapshot + Project Baseline + stable capability set

Dynamic Delta:
Task + Recall + Conversation Delta + Evidence + Current Turn
```

Prefix/Resource 按 revision/hash 去重。

### D-MEM-038 — System-enforced Baseline Recall
### D-MEM-039 — Agent-directed Deep Recall
### D-MEM-040 — Recall Is Budgeted
### D-MEM-041 — Agent Proposes; Kernel Commits
### D-MEM-042 — Reachable Context ≠ Materialized Context
### D-MEM-043 — Context Broker Is Cognitive Arbitration
### D-MEM-044 — Current Reality Overrides Historical Experience
### D-MEM-045 — Hard Reservations + Elastic Budget
### D-MEM-046 — Inline / Ref / On-demand Materialization
### D-MEM-047 — Stable Prefix + Dynamic Delta
### D-MEM-048 — Context Assembly Is Fully Receipted

**共同状态：** Accepted Candidate

---

# 32. Working Memory Boundary 与 Capture Trigger Engine

## 32.1 不建立独立 Short-term/Session Memory Store

Working Memory 是逻辑认知视图，不是独立真源：

```text
Transient / Active
├─ Turn Context
├─ ConversationContextView
├─ RunWorkingState
└─ Runtime Scratch

Durable Experience
├─ Episodic
├─ Semantic
├─ Procedural
├─ Preference
└─ Lesson

Derived Projection
├─ CoreMemorySnapshot
├─ MemoryCluster
├─ Usage Stats
└─ Indexes
```

分类原则：

```text
只对本 Turn 有用        → Turn Context
当前 Work 后续必须正确  → Work/Task/Run State
未来相似任务值得复用    → Long-term Memory Candidate
```

不持久化模型隐藏 chain-of-thought；长期需要的内容必须转换为可审计的 Rationale/Assumption/Evidence/Checkpoint/Lesson/Procedure。

## 32.2 Capture Trigger Engine

每个 Turn `afterTurnMemory()` 必须执行，但绝大多数 Turn 可以 `NO_CAPTURE`。

```text
Workbench/Semantic Events
        ↓
Capture Trigger Engine (0 Token)
        ↓
NO_CAPTURE | CaptureSignal
        ↓
Early Dedup / Filter
        ↓
Deterministic Candidate or Extraction Job
        ↓
Candidate Validation
        ↓
ACTIVE | INBOX | DEFER | DROP
```

高价值 Trigger：

```text
Explicit User Remember
Explicit User Correction
Verified Work Outcome
Failure→Root Cause→Repair→Verification
Repeated Verified Pattern
Runtime Memory Hint
```

默认 Negative Capture：普通寒暄、heartbeat、progress、temporary retry、raw tool noise、未验证推测、runtime scratch、Agent 未参与的 Room 消息。

## 32.3 Agent Attribution

Private Candidate 必须绑定 `experience_owner_agent_id`，并说明 ownership basis（ACTOR/PARTICIPANT/REVIEWER/EXPLICIT_USER_TO_AGENT）。Project/Room membership 本身不构成 Private Experience ownership。

## 32.4 Generalization Risk

Candidate scope 不得显著超出 evidence scope。单次局部事件不能无证据提升为全局 Lesson/Procedure。

### D-MEM-049 — No Independent Short-term Memory Store
### D-MEM-050 — Working State Belongs to Workbench State
### D-MEM-051 — ConversationContextView Is Rebuildable Projection
### D-MEM-052 — Runtime Scratch Is Non-canonical
### D-MEM-053 — Hidden Reasoning Is Not Memory
### D-MEM-054 — Working Information Uses Lifecycle Classification
### D-MEM-055 — Runtime Handoff Uses Structured Work Context
### D-MEM-056 — Capture Evaluation Mandatory, Capture Sparse
### D-MEM-057 — Deterministic Gate Before Model Extraction
### D-MEM-058 — Workbench Events Are Triggers, Not Automatically Private Memories
### D-MEM-059 — Private Capture Requires Agent Attribution
### D-MEM-060 — Capture Prioritizes Verified Experience
### D-MEM-061 — Candidate Uses Active/Inbox/Defer/Drop
### D-MEM-062 — Scope Must Not Exceed Evidence
### D-MEM-063 — CaptureSignal Durable; Heavy Extraction May Be Async

**共同状态：** Accepted Candidate

---

# 33. Cognitive Asset Pipeline：Memory / Knowledge / Decision / Skill

Private Memory、Project Knowledge、Decision、Skill 是不同 Domain Object，不通过“修改 Memory type”互相转换。

## 33.1 CognitiveProposal

```text
CognitiveProposal
├─ proposal_id
├─ proposal_type: KNOWLEDGE|DECISION|SKILL
├─ proposed_by_agent_id
├─ source_memory_refs[]
├─ public_evidence_refs[]
├─ private_derivation_refs[]
├─ target_scope
├─ proposed_content
├─ rationale
├─ confidence
├─ sensitivity
├─ generalization_risk
├─ authority_requirement
└─ status
```

Cognitive Fabric 只负责发现/提出/路由，目标 Domain 保留 Validation/Authority/Commit。

## 33.2 Promotion

```text
Private Experience
→ Private Memory
→ CognitiveProposal
→ Knowledge / Decision Proposal / Skill Candidate
```

共享的是经过治理的新资产，不是源 Private Memory 原文。

## 33.3 Assimilation

新 Knowledge/Decision/Skill 发布后进入 Shared Context/Capability Plane，不自动复制进所有 Agent MemorySpace。Agent 真正读取/应用/验证后，才可通过自身 Capture Pipeline 形成 Private Experience。

## 33.4 Skill Qualification

Procedural Memory → Skill Candidate 必须经过：Contract、Permission、Compatibility、Failure Semantics、Testability、Sandbox/Contract Test 等 Qualification。

### D-MEM-064 — Memory and Shared Cognitive Assets Are Separate Domains
### D-MEM-065 — Promotion Shares Value, Not Private Memory
### D-MEM-066 — CognitiveProposal Is Cross-domain Contract
### D-MEM-067 — Decision Promotion Produces Proposal, Never Authority
### D-MEM-068 — Procedural Memory Requires Skill Qualification
### D-MEM-069 — Shared Asset Publication Does Not Auto-copy Into Agent Memory
### D-MEM-070 — Shared Asset Changes Trigger Dependency Revalidation
### D-MEM-071 — Promotion Does Not Delete Source Experience
### D-MEM-072 — Promotion Threshold Rises With Shared/Executable Impact

**共同状态：** Accepted Candidate

---

# 34. Cognitive Privacy / Promotion Permission

Cognitive Sharing Policy 只管理 `Private Cognition → Shared Cognitive Asset`，不得借此重建统一 Runtime Permission/Sandbox/Approval Engine。

## 34.1 三个正交维度

```text
Private Access
Promotion / Disclosure Policy
Data Egress Policy
```

例如一条 Memory 可以：owner-only read、允许形成 Project Proposal、但原 Memory `LOCAL_ONLY` 不得发送云 Provider。

## 34.2 MemoryDisclosureClass

```text
PRIVATE_NORMAL
PRIVATE_SENSITIVE
PRIVATE_PERSONAL
PRIVATE_SECRET
PRIVATE_RESTRICTED
```

Secret/Credential 类禁止 Promotion；Preference/Personal Conversation-derived Memory 默认 `PRIVATE_ONLY`。

## 34.3 Promotion Result

```text
AUTO_PUBLISH
AUTO_PROPOSE
REVIEW_QUEUE
PRIVATE_ONLY
DENY
```

Decision 永远只自动到 Proposal；Skill 永远只自动到 Candidate，后续 Authority/Qualification 属于目标 Domain。

## 34.4 Disclosure Preflight

```text
Ownership
→ Target Scope
→ Privacy/Sensitivity/Secret
→ Private-source Minimization
→ Public Evidence Substitution
→ Semantic Disclosure Check
→ Egress Policy
→ CognitiveProposal
```

优先使用 Incident/Run/Test/Artifact/Decision 等 public evidence 替代 Private Memory 原文。

## 34.5 防侧信道

其它 Agent 不得指定另一个 Agent 的 MemorySpace/memory_id/topic 来触发 Promotion，避免通过 Proposal/拒绝原因反向推断 Private Memory。

### D-MEM-073 — Private Is Default Disclosure State
### D-MEM-074 — Cognitive Permission Is Narrow-domain Governance
### D-MEM-075 — Privacy, Promotion and Egress Are Orthogonal
### D-MEM-076 — Propose and Publish Are Separate Authorities
### D-MEM-077 — Promotion Requires Disclosure Preflight
### D-MEM-078 — Prefer Public Evidence Over Private Evidence
### D-MEM-079 — Personal Preference and Secret Memory Do Not Auto-promote
### D-MEM-080 — Promotion Cannot Be Cross-Agent Side Channel
### D-MEM-081 — Promotion Automation Is Risk-tiered and Budgeted
### D-MEM-082 — Promotion Is Revocable and Dependency-aware

**共同状态：** Accepted Candidate

---

# 35. CognitiveTrace / Explainability / Cognitive Debugging

Memory Studio 从“记忆浏览器”升级为 Agent Cognitive Debugger，但解释必须来自真实 Receipt/Event/Policy，而不是模型事后自述。

## 35.1 CognitiveTraceRoot

```text
CognitiveTraceRoot
├─ trace_id
├─ turn_id
├─ conversation_id
├─ agent_id
├─ memory_space_id
├─ project_id?/room_id?/mission_id?/task_id?
├─ runtime_binding_id
├─ model_selection_ref
├─ started_at/completed_at
├─ status
└─ child_receipt_refs[]
```

## 35.2 Trace Stage

```text
C0 Identity
C1 Recall
C2 Shared Reality
C3 Context Arbitration
C4 Egress / Materialization
C5 Runtime
C6 Post-turn Capture
C7 Downstream Learning
```

Trace 是 correlation + structured evidence graph，不是第二套 Event Log，也不默认保存完整 Prompt/Memory/Workspace/Tool Output。

## 35.3 ReceiptEnvelope

所有 Cognitive Receipt 统一公共字段：trace_id、agent_id、turn_id、policy_revision、component_version、latency、status、degraded_reason、evidence_refs、child_refs。

## 35.4 SelectionDisposition

至少支持：

```text
SELECTED
FILTERED_PERMISSION
FILTERED_NAMESPACE
FILTERED_STATUS
FILTERED_TEMPORAL
FILTERED_APPLICABILITY
FILTERED_EGRESS
DEDUPLICATED
RANK_BELOW_CUTOFF
TOKEN_BUDGET_EVICTED
CONFLICT_SUPPRESSED
REF_ONLY
```

禁止只记录 `selected=false`。

## 35.5 Trace Privacy

Trace 自身也必须经过权限裁剪。未授权 Viewer 可以看到“存在受保护 Private Derivation”，但不得顺着 Trace 打开源 Agent Memory payload。

## 35.6 Durable vs Raw Debug

长期保存：Trace root、Receipt summaries、revision/policy/resource refs、selection disposition。  
短期 TTL：raw prompt dump、wire log、token stream、deep retrieval dump。

## 35.7 Cognitive Root Cause Taxonomy

至少覆盖 Identity/Core、Recall、Temporal/Appplicability、Context、Egress、Runtime、Capture、Promotion 等机器可读原因，例如：

```text
IDENTITY_BINDING_FAILURE
CORE_UNAVAILABLE
RECALL_NO_MATCH
RECALL_RANKED_TOO_LOW
RECALL_BUDGET_EVICTED
MEMORY_SUPERSEDED
CONTEXT_TOKEN_EVICTED
EGRESS_POLICY_BLOCKED
CAPTURE_NO_SIGNAL
PROMOTION_PRIVATE_ONLY
```

### D-MEM-083 — CognitiveTrace Is Unified Cognitive Correlation Root
### D-MEM-084 — Trace Is Evidence Graph, Not Duplicate Store
### D-MEM-085 — Explanations Come From Receipts, Not Model Self-report
### D-MEM-086 — Memory Use States Are Explicitly Separated
### D-MEM-087 — Retrieval/Context Drops Have Structured Dispositions
### D-MEM-088 — Cognitive Trace Is Privacy-aware
### D-MEM-089 — Durable Cognitive Evidence Separate From Raw Debug Data
### D-MEM-090 — Typed Cognitive Root Causes
### D-MEM-091 — AI Investigation Uses Typed Evidence APIs
### D-MEM-092 — CognitiveTrace Supports Causal DAG and Async Lineage

**共同状态：** Accepted Candidate

---

# 36. Token-Stable Memory / Cognitive Economy Decision Lock

本章正式锁定上一轮 Token Economy 讨论。

### D-MEM-093 — Token-Stable Memory

Memory Corpus 可持续增长，但每个 Turn 的 Materialized Memory 必须受有界 Policy 控制；Memory Record Count 增长不得自动导致 Prompt、LLM Call 或 Output Token 线性增长。

### D-MEM-094 — Minimum Necessary Recall

除小型 Core Identity Continuity 外，Private Recall 遵循 Minimum Necessary Recall Ladder。系统优先判断是否无需额外 Memory、是否已经存在于 Context、是否可 Direct Resolve / Capsule / Ref-only，再逐步允许 relation expansion、full read 和 Deep Recall。

### D-MEM-095 — MemoryCapsule Is a Rebuildable Projection

`MemoryCapsule` 是 Canonical Memory Revision 的小型、可重建 Materialization Projection，不是真源。Capsule 必须绑定 source revision/hash；源 Revision 变化时旧 Capsule 必须失效。

### D-MEM-096 — Critical Truth Is Never Lossy-compressed by Default

Current User Request、Critical Core、Accepted Decision/Contract、Current State、Security/Critical Evidence 不得默认使用 lossy semantic compression。越接近 Authority / Current Truth，压缩模式越保守。

### D-MEM-097 — Selection / Dedup / Ref Precede Semantic Compression

Token Reduction 默认顺序为 filter → dedup → temporal/applicability → ref-only → structured projection → extractive pruning → semantic compression。禁止把“大 Context 先全部塞入，再固定调用另一个 LLM 总结”作为默认热路径。

### D-MEM-098 — On-demand Expansion Beats Bulk Injection

普通 Recall 优先注入 Capsule / Excerpt / Ref。Runtime 只有在当前任务确实需要 evidence / lineage / full procedure 时才通过受限 `memory.read / search_more / resource.read` 扩展，且 Expansion 受预算与 Trace 管理。

### D-MEM-099 — CognitiveEconomyController

Context Broker 增加 `CognitiveEconomyController` 逻辑职责，统一管理 Recall Budget、Capsule、Dedup、Ref-only、Compression Safety、Materialization Cache、Expansion Budget 与 OutputTokenLease。它不是新真源，也不得改变 Authority/Privacy。

### D-MEM-100 — Compression Is Receipted, Validated and Reversible

所有 Structured/Extractive/Semantic Compression 均生成可审计 `CompressionReceipt`。压缩结果必须可回源；验证失败必须回退到更安全的 Projection/Ref/Full Source，禁止继续使用已知失真的摘要。

### D-MEM-101 — Minimum Sufficient Output

Agent 输出 Token 与 Memory Corpus Size 解耦。Workbench 通过 `OutputTokenLease + ContextProfile + User Preference` 鼓励 Minimum Sufficient Output；Room/Handoff 默认传结构化结论、EvidenceRef 和 NextAction，而不是长篇叙述复制。

### D-MEM-102 — Token Economy Is a First-class Benchmark Dimension

任何 Retrieval、Compression、Graph、Vector、Reranker、LLM Summary、Context Provider 或 OSS 变更都必须同时评估 Recall Quality、Critical Context Preservation、Input/Output Token、Latency、Failure 和 Privacy。高压缩率本身不构成成功。

**共同状态：** Accepted Candidate。

---

# 37. Memory Evaluation / Benchmark / Release Gate

Q17 在 V3.3 中正式从 Open Discussion 升级为 Accepted Candidate。

目标不是证明“Memory 组件在运行”，而是证明：

> **Agent 因为这套 Memory 系统在长期运行中变得更连续、更准确、更安全，同时 Token / Latency / Cost 可接受。**

## 37.1 Benchmark 维度

统一 `CognitiveMemoryBenchmarkSuite` 至少覆盖：

```text
A. Memory Correctness
B. Agent Continuity
C. Isolation / Privacy
D. Cognitive Learning Quality
E. Context / Token Efficiency
F. System Reliability / Recovery
```

### A. Memory Correctness

必须测试：

```text
Relevant Recall
False Recall
Stale / Superseded Injection
Temporal Current Query
Temporal Historical Query
Applicability
Conflict Preservation
Relation Expansion
```

核心指标：

```text
Recall@K
MRR
Relevant Memory Coverage
False Recall Rate
Superseded Injection Rate
Unresolved Conflict Preservation Rate
```

### B. Agent Continuity

必须测试：

```text
Runtime switch:
Codex → DeepSeek
DeepSeek → Codex

Process restart
Workbench restart
Crash at transaction boundaries
Core revision recovery
MemorySpace binding recovery
Pending outbox / maintenance resume
```

要求：

```text
agent_id continuity
memory_space_id continuity
canonical revision continuity
```

身份/MemorySpace 错绑属于 Hard Failure。

### C. Isolation / Privacy

必须包含多 Agent adversarial fixture：

```text
Agent A private marker = SECRET-A
Agent B private marker = SECRET-B
```

并覆盖：

```text
FTS
Direct Resolve
Vector
Graph
Deep Recall
Context Broker
CognitiveTrace
Promotion
Diagnostics
```

要求：

```text
Cross-Agent Private Memory Leakage = 0
```

恶意参数/路径/Prompt 不能改变当前绑定 namespace。

同时测试：

```text
Private → Shared Promotion
Semantic Disclosure
Secret/Credential promotion
Trace side channel
Promotion side channel
```

### D. Cognitive Learning Quality

Capture / Consolidation / Promotion 必须评估：

```text
Capture Precision
Capture Recall
Capture F1
Duplicate Pollution
Premature Generalization
Preference Correction
Procedure Learning
Consolidation quality
Promotion Privacy
```

典型 fixture：

```text
1000 ordinary turns
→ Capture Evaluation 1000
→ Long-term Memory commits must remain sparse
```

以及：

```text
single success
→ should not immediately become universal procedure

repeated verified success
→ may mature into Procedural Candidate
```

### E. Context / Token Efficiency

必须独立测：

```text
Recall → Selected → Materialized Survival
Critical Context Preservation
Memory Tokens / Turn
Input Tokens / Successful Task
Output Tokens / Successful Task
Useful Recall per 1K Memory Tokens
Duplicate Token Rate
Context Cache Reuse Rate
On-demand Expansion Rate
Unnecessary Expansion Rate
Compression Distortion / Validation Failure
```

在 Token Pressure fixture 中必须验证：

```text
Current User Request
Task Contract
Current Authority
Critical Evidence
Core Identity
```

不会因为 Conversation / low-utility Memory / Supporting Knowledge 而被错误驱逐。

### F. System Reliability / Recovery

必须覆盖：

```text
Canonical SQLite transaction crash points
WAL recovery
index rebuild
tombstone propagation
deleted-memory search
Core dirty rebuild
CaptureSignal async recovery
Maintenance coalesced catch-up
```

## 37.2 Benchmark Execution Levels

正式分层：

```text
L0 Deterministic Contract Suite
L1 Deterministic Retrieval Suite
L2 FakeRuntime End-to-End
L3 Real Runtime Behavioral Benchmark
L4 Long-horizon Simulation
```

### L0

要求：

```text
0 Token
0 LLM
```

测试：

- namespace；
- revision；
- status；
- temporal validity；
- applicability；
- conflict state；
- canonical transaction；
- deletion；
- recovery invariants；
- compression policy；
- deterministic Capture Gate。

每次 CI 必跑。

### L1

固定：

```text
Memory fixture
MemoryQueryPlan
FTS
Relation
Ranking
Context Arbitration
```

主要测 Recall、False Recall、Stale、Scope、Budget、Token Economy。

默认 0 Token。

### L2

使用 FakeRuntime：

```text
ContextPackage
→ deterministic Runtime
→ known tool/reference behavior
```

测试完整 Turn Lifecycle、Deep Recall Contract、Capture、Receipt、Restart。

默认 0 Token。

### L3

使用真实：

```text
DeepSeek Harness
Codex Harness
```

检查：

- 模型是否善用已提供 Memory；
- 是否按需 `search_more`；
- 是否遵守 Authority / Conflict；
- Runtime/Model 更新是否造成行为回归。

适合 nightly / release candidate / adapter or model upgrade。

### L4

模拟：

```text
10K
100K
1M+
Memory Records
```

及长时间 Agent Experience，测试：

- ranking drift；
- memory pollution；
- consolidation；
- Core drift；
- storage/index growth；
- token stability；
- temperature/archive；
- restart/rebuild。

## 37.3 Benchmark Scale Profile

不使用“支持 800 Agent”作为单一性能定义。

Benchmark Profile 使用矩阵，例如：

| Profile | Registered Agents | Active Agents | Total Memories | Concurrent Turns |
|---|---:|---:|---:|---:|
| Desktop Small | 20 | 2 | 20K | 1 |
| Power User | 1K | 10 | 1M | 4 |
| Large Registry | 10K | 20 | 10M | 8 |
| Extreme Registry | 100K | 20 | 50M+ | 8–16 |

以上只为初始压力档位，必须按实际硬件和实现校准，不是产品承诺或固定上限。

## 37.4 Benchmark Expectation

Fixture 不只保存 `expected_memory_id`，还应包含：

```text
BenchmarkExpectation
├ expected_refs[]
├ forbidden_refs[]
├ acceptable_alternatives[]
├ required_roles[]
├ required_dispositions[]
├ temporal_mode
├ target_time?
├ expected_conflict_behavior?
└ rationale
```

这样 Revision / Supersede / Alternative Recall 变化时仍可审计为什么测试应该通过。

## 37.5 Deterministic Assertion First

真实模型输出评估顺序：

```text
1. Deterministic assertion
2. Structured outcome assertion
3. Judge model only when necessary
```

Namespace、Revision、Leakage、Deletion、Receipt、Token Budget 等不得使用 Judge LLM 作为主要判断器。

Judge Model 只允许用于难以结构化的行为质量评估，并必须单独记录模型、prompt、cost 和不确定性。

## 37.6 Memory vs No-Memory A/B

关键用户任务必须支持：

```text
Run A:
Memory disabled / minimal baseline

Run B:
Memory enabled
```

其余：

```text
Task
Workspace
Current State
Shared Context
```

尽量保持相同。

比较：

```text
Task Success
Repeated Error Rate
User Correction Count
Tool Calls
Input Tokens
Output Tokens
Latency
```

这样才能证明 Memory 带来的净价值，而不只是 Memory 内部指标好看。

## 37.7 OSS / Provider Incremental Value Gate

任何：

```text
Graph
Vector DB
Embedding
Reranker
HyDE
LLMLingua
Context Compressor
Consolidation Engine
Cluster Retrieval
External Memory OSS
```

进入 Mandatory Hot Path 前必须与当前 Baseline A/B：

```text
Quality
Token
Latency
RAM
Disk
Reliability
Privacy
```

如果质量收益不能覆盖复杂度/成本/故障面，则：

```text
保持 Optional Deep Recall
或
不集成
```

不能因为“功能更多”进入主链。

## 37.8 Release Gate

### Hard Gate

任何一项失败即阻止 Release：

```text
Cross-Agent Leakage > 0
Namespace bypass
Agent/MemorySpace identity mismatch
Canonical memory corruption
Restart continuity failure
Deleted/tombstoned memory remains normally retrievable
Visible Turn bypasses M0/M1 lifecycle
Critical Truth lossy-compressed
Compression validation failure silently accepted
```

### Regression Gate

以下指标和上一稳定版比较：

```text
Recall Quality
False Recall
Stale Injection
Capture F1
Context Survival
Critical Context Preservation
Memory Tokens / Turn
P95 Recall Latency
P95 Turn Added Latency
```

具体阈值由初始 Benchmark Baseline 决定；原则是：

> **新版本不得在没有明确收益和批准的情况下造成显著认知质量/安全/Token 回归。**

## 37.9 MemoryBenchmarkReport

统一报告：

```text
MemoryBenchmarkReport
├ build_id
├ dataset_revision
├ memory_policy_revision
├ retrieval_version
├ context_policy_revision
├ compression_policy_revision
├ runtime_versions[]
│
├ deterministic_contract_suite
├ retrieval_suite
├ isolation_suite
├ recovery_suite
├ capture_suite
├ promotion_privacy_suite
├ token_economy_suite
├ real_runtime_suite
├ long_horizon_suite
│
├ regressions[]
├ improvements[]
├ hard_gate_status
└ release_recommendation
```

## 37.10 Accepted Decisions

### D-MEM-103 — Memory Quality Requires Multi-dimensional Evaluation

Memory Benchmark 不只评估 Retrieval Hit Rate，同时覆盖 Correctness、Continuity、Isolation/Privacy、Learning Quality、Context/Token Efficiency 与 Reliability。

### D-MEM-104 — Benchmark Uses Layered Execution Levels

采用 L0 Deterministic Contract、L1 Deterministic Retrieval、L2 FakeRuntime E2E、L3 Real Runtime Behavior、L4 Long-horizon Simulation；L0–L2 优先 0 Token。

### D-MEM-105 — Privacy and Identity Violations Are Hard Release Blockers

Cross-Agent Leakage、Namespace bypass、Agent/MemorySpace mismatch、Canonical corruption 等不采用统计容忍度；发现一次即 Release Blocker。

### D-MEM-106 — Recall Evaluation Includes False/Stale Recall

必须同时测 Relevant Recall 与 False/Stale/Superseded Injection；不得用高 Top-K Hit Rate 掩盖 Context Pollution。

### D-MEM-107 — Capture Has Precision/Recall, Not Only Candidate Rate

使用结构化/人工标注 fixture 测 Capture Precision、Recall、F1、Premature Generalization、Duplicate Pollution，不以“记得更多”为成功。

### D-MEM-108 — Context Arbitration Is Independently Benchmarked

必须跟踪 `Recall → Selected → Materialized` Survival，并在 Token Pressure 下验证 Current Authority、Critical Evidence、Core 和 Task Contract 保留正确。

### D-MEM-109 — Every Major Component Must Prove Incremental Value

Graph、Vector、Reranker、Embedding、Compression、Consolidation OSS、Cluster Engine 等进入 Hot Path 前必须在同一 Benchmark 下证明 Quality/Token/Latency/Reliability 的净收益。

### D-MEM-110 — Runtime and Model Upgrades Require Cognitive Regression

DeepSeek/Codex/Harness/Model 升级必须跑 Cognitive Behavioral Regression，防止模型行为变化破坏 search_more、Authority、Conflict 或 Memory Use。

### D-MEM-111 — Benchmark Dataset Is Namespace/Revision/Temporal Aware

Benchmark fixture 必须包含多个 Agent namespace、revision lineage、superseded/contested、temporal/applicability、forbidden refs 和 expected rationale。

### D-MEM-112 — Benchmark Is a Release Gate

Benchmark 结果生成 `MemoryBenchmarkReport`；Hard Safety/Continuity Gate 与相对稳定版本的 Cognitive/Token Regression Gate 共同参与 Release 决策。

**共同状态：** Accepted Candidate。

---

# 38. V3.3 Decision Log Addendum

v3.3 在 v3.2 `D-MEM-020` 至 `D-MEM-092` 基础上新增：

```text
D-MEM-093 ~ D-MEM-102
Token-Stable Memory / Cognitive Economy

D-MEM-103 ~ D-MEM-112
Memory Evaluation / Benchmark / Release Gate
```

当前系统级结论进一步升级为：

```text
Memory corpus may grow; per-turn memory context must remain bounded.
Memory is not Context.
Selection precedes compression.
Critical truth is never silently lossy-compressed.
Private Memory is normally materialized as Capsule/Ref, then expanded on demand.
Input and output token are governed by Cognitive Economy.
All compression is traceable, validated, reversible and benchmarked.
No OSS enters Memory Hot Path without proving incremental value.
Privacy/Identity failures are hard release blockers.
```

---

# 39. Cluster Sync / Offline Multi-device Revision

Q18 在 v3.4 中正式从 Open Discussion 升级为 Accepted Candidate。

目标：

> **多设备可以共享同一 Agent Identity / MemorySpace 的 durable cognition，但 Cluster 不成为第二个 AI Brain，Sync 不通过文件覆盖或 Last-Write-Wins 破坏 Revision / Supersede / Privacy。**

## 39.1 Sync Is Resource Replication, Not Database Replication

禁止：

```text
upload Canonical SQLite
→ overwrite remote/local database file
```

Private Memory Sync 采用：

```text
stable IDs
+
immutable revisions
+
hash
+
mutation/event
+
sync cursor
+
idempotency key
```

进行资源级增量同步。

单个节点仍保持：

```text
workbenchd
=
local Canonical SQLite single writer
```

多设备并不意味着多个进程共同直接写同一个 SQLite 文件。

## 39.2 Workbench Node vs Cluster Authority

正式区分：

```text
Workbench Node
=
Semantic Mutation Author

Cluster
=
Replication / Transport / Replica / Optional Index Authority
```

Cluster 默认可以：

```text
receive
validate envelope
store
replicate
sequence transport
serve namespace-safe retrieval
rebuild indexes
propagate tombstones
```

Cluster 默认不得：

```text
invent new Preference
rewrite Lesson
supersede Canonical Memory
run hidden LLM consolidation
create new Agent experience
```

因此：

```text
Cluster
≠
Memory Brain
```

当前版本继续保持：

```text
device powered off
→ local cognitive computation stops
```

服务器在线不表示 Agent 继续学习。

## 39.3 Stable Cross-device MemorySpace Identity

所有设备共享：

```text
owner_user_id
agent_id
memory_space_id
```

设备自身拥有：

```text
device_id
```

Mutation 来源使用 `device_id`，但 Memory ownership 不随设备变化。

任何：

```text
Sync
Remote Search
Remote Hydration
Remote Index Query
```

必须先绑定：

```text
owner_user_id
+
agent_id
+
memory_space_id
```

Runtime/LLM 不能通过参数切换目标 Agent MemorySpace。

## 39.4 Revision DAG

单机线性 Revision：

```text
R1 → R2 → R3
```

在多设备中升级为 immutable causal DAG：

```text
        R5
       /  \
   R6-A   R6-B
```

建议 Revision 至少包含：

```text
MemoryRevision
├ revision_id
├ memory_id
├ parent_revision_ids[]
├ origin_device_id
├ origin_sequence
├ recorded_at
├ payload_hash
├ status
├ validity
└ source_refs[]
```

要求：

```text
revision_id
≠
sync_cursor
≠
server_sequence
```

`sync_cursor/server_sequence` 只表示传输进度，不表示 Semantic Authority。

第一版不要求完整 Vector Clock；`parent_revision_ids + origin_device_id + origin_sequence` 用于表达基本因果关系。

## 39.5 Sync Mutation Envelope

每次本地正式 Memory Commit 同一事务写入：

```text
Canonical Memory Revision
+
Semantic Event
+
Receipt
+
Sync Outbox
```

建议：

```text
MemorySyncMutation {
    protocol_version

    owner_user_id
    agent_id
    memory_space_id

    memory_id
    revision_id
    parent_revision_ids[]

    mutation:
      CREATE |
      REVISE |
      SUPERSEDE |
      RETRACT |
      TOMBSTONE

    origin_device_id
    origin_sequence

    payload_hash
    policy_revision

    payload_ref
    idempotency_key
}
```

因此用户在 Commit 后立刻断网/关机：

```text
Memory durable ✓
Outbox intent durable ✓
Remote sync pending
```

重新开机后从 durable outbox 恢复。

## 39.6 Push / Pull / Cursor

基本同步：

```text
LOCAL OUTBOX
    ↓
PUSH immutable mutations
    ↓
Cluster ACK + cursor
    ↓
mark local delivery state

Cluster mutation journal
    ↓
PULL after local cursor
    ↓
namespace / hash / revision validation
    ↓
apply or conflict
    ↓
advance cursor
```

必须：

```text
idempotent
resumable
delta-based
conflict-visible
offline-capable
```

## 39.7 Revision Conflict Policy

### Fast-forward

```text
local: R7
remote: R8(parent=R7)
```

→ deterministic apply。

### Exact duplicate / retry

相同：

```text
revision_id
idempotency_key
payload_hash
```

→ ignore duplicate。

### Concurrent same-record revisions

```text
      R7
     /  \
 R8-A   R8-B
```

禁止：

```text
last-write-wins
timestamp-wins
```

生成：

```text
RevisionConflictSet
```

第一版仅自动处理：

```text
exact duplicate
causal descendant
safe idempotent fast-forward
```

其它 concurrent semantic edits 保持显式 conflict，由 Memory Domain 后续处理。

## 39.8 Sync Conflict ≠ Semantic Conflict

明确区分：

```text
Revision Conflict
=
same memory_id
+
concurrent revisions
```

与：

```text
Semantic Conflict
=
different memories/claims
+
meaning contradiction
```

Sync Layer 只检测 Revision/Causality Conflict，不运行 NLP/LLM 解决 Semantic Conflict。

Semantic Conflict 继续属于：

```text
Memory Conflict / Temporal / Evidence Domain
```

## 39.9 Tombstone Dominates Offline Resurrection

用户删除：

```text
M81
→ Tombstone T81
```

必须传播到：

```text
Cluster
Devices
FTS
Vector
Graph
Cache
```

离线设备基于旧 head 产生的新 Revision：

```text
R-old-device
```

在 Tombstone 之后重新上线时，不得自动恢复 `ACTIVE`。

规则：

```text
authenticated tombstone
→ prevents ordinary resurrection
```

离线分支可保留为受限 audit/conflict evidence，但不能重新进入正常 Recall。

## 39.10 Rebuildable Projections Are Not Sync Truth

以下默认不作为 Canonical Sync Truth：

```text
CoreMemorySnapshot
FTS
Vector
Graph
MemoryCapsule
Ranking cache
Context cache
Hot/Warm cache
Usage materialized stats
```

同步：

```text
Canonical Memory
Revision
Relation/lineage
Tombstone
necessary semantic receipts/provenance
```

后：

```text
invalidate projection
→ rebuild locally / cluster side
```

因此 Index 损坏可以重建，不改变 Memory Truth。

## 39.11 Simultaneous Same-Agent Use Across Devices

允许：

```text
same Agent A
active on Laptop
active on Desktop
```

不使用 remote hard lock 阻止离线工作。

在线时可以显示 advisory presence：

```text
Agent A active on another device
```

但网络不可用不得导致 Agent 被锁死。

代价：

```text
possible concurrent revisions
```

由 Revision DAG + ConflictSet 处理。

## 39.12 Private Sync Does Not Change Sharing Scope

```text
Private Memory
+ Server/Cluster replica
=
still Private Memory
```

同步不会自动成为：

```text
Project Knowledge
Organization Knowledge
Shared Memory
```

同一用户拥有多个 Agent，也不得因此允许 Agent B 搜索 Agent A Private Memory。

## 39.13 Remote Recall

远端查询必须先绑定：

```text
ClusterMemorySearchContext
{
    authenticated_user
    bound_agent_id
    bound_memory_space_id
}
```

然后 Runtime 只能表达：

```text
query
filters
depth
budget
```

不能表达：

```text
target_agent_id
target_memory_space_id
```

远端默认返回：

```text
memory_id
revision_id
capsule
score/features
source_hash
hydration_ref
```

而不是大批 full payload。

所有结果仍经过：

```text
Local Sync Validation
Context Arbitration
CognitiveEconomyController
Privacy / Egress
CognitiveTrace
```

## 39.14 Remote Revision Must Be Verifiable Before Materialization

禁止：

```text
Cluster has M81 R9
Local canonical head = R7
Runtime secretly consumes R9
```

Remote Candidate 必须先：

```text
verify namespace
verify revision/hash
register/apply through workbenchd sync path
or establish explicit local read-replica revision state
```

之后才能 Materialize。

CognitiveTrace 必须能准确记录模型实际看到的 Revision。

## 39.15 Payload Lazy Sync

大规模 MemorySpace 可以分层同步：

```text
Namespace Manifest
+
Headers / Lineage / Tombstones
+
Hot/Warm payload
+
Cold payload on demand
+
Archived remote ref
```

新设备可提供策略：

```text
STANDARD CACHE
FULL OFFLINE COPY
```

离线时 remote-only cold/archive payload 不可用，应明确记录：

```text
ARCHIVE_UNAVAILABLE_OFFLINE
```

不得静默当成“没有这条 Memory”。

## 39.16 New-device Bootstrap

禁止复制 SQLite 文件。

Bootstrap：

```text
Namespace Manifest
↓
logical checkpoint
↓
resource bundles
↓
delta after checkpoint
↓
workbenchd transactional apply
↓
Core rebuild
↓
FTS/Capsule rebuild
↓
Agent Ready
↓
Vector/Graph optional background rebuild
```

Agent Identity / Core continuity 优先于可选深层 Index。

## 39.17 Sync Is Zero-token by Default

以下全部：

```text
hash
cursor
revision comparison
idempotency
dedup
fast-forward
tombstone
conflict detection
bootstrap
```

默认：

```text
LLM Calls = 0
```

语义 merge / conflict resolution 是独立 Memory Domain 工作流，不隐藏在 Sync 热路径。

## 39.18 Device Registry / Revocation

Q18 至少定义：

```text
device_id
device_status:
  ACTIVE |
  REVOKED
```

REVOKED 设备：

```text
Sync Pull DENY
Sync Push DENY
```

Key Rotation / ciphertext / E2EE 细节进入 Q19。

## 39.19 Accepted Decisions

### D-MEM-113 — Sync Replicates Resources, Never Database Files

Private Memory Sync 基于稳定 ID、immutable revision、hash、mutation/event 与 cursor 做资源级增量复制；禁止整库上传覆盖 Canonical SQLite。

### D-MEM-114 — Workbench Nodes Author Semantics; Cluster Replicates

每个设备的 `workbenchd` 是该节点 Canonical Mutation 的唯一 writer。Cluster 可以验证、存储、传输、复制和索引已提交 Mutation，但默认不能自主创造、修改或 supersede Agent Canonical Memory。

### D-MEM-115 — MemorySpace Identity Is Stable Across Devices

`ownerUserId + agentId + memorySpaceId` 在所有设备和 Cluster 中保持稳定；`deviceId` 只表示 Mutation 来源。所有 Sync/Search 操作必须先绑定 MemorySpace。

### D-MEM-116 — Revision Causality Uses Immutable Parent Lineage

Memory Revision 使用 globally unique `revisionId + parentRevisionIds + originDeviceId + originSequence` 表示因果关系。Sync Cursor / Server Sequence 只用于传输进度，不作为 Memory Authority 或 Conflict Resolution 依据。

### D-MEM-117 — Concurrent Semantic Edits Never Use Silent Last-write-wins

同一 Memory Record 的 concurrent revision 默认形成显式 `RevisionConflictSet`。第一版仅自动处理 exact duplicate、causal fast-forward 等确定性情况；不得因更新时间较晚静默覆盖另一设备修改。

### D-MEM-118 — Tombstone Prevents Offline Resurrection

经过授权的 Memory Tombstone 必须传播到所有 Replica/Projection；离线设备后来提交的旧内容修改不得自动复活已删除 Memory，只能进入冲突/审计路径。

### D-MEM-119 — Rebuildable Projections Are Not Sync Truth

CoreMemorySnapshot、FTS、Vector、Graph、MemoryCapsule、Ranking/Context Cache 等默认不作为 Canonical Sync Truth；Canonical Revision 同步后由节点/Cluster重新构建相应 Projection。

### D-MEM-120 — Offline Writes Use Durable Outbox and Eventual Sync

断网/关机不阻塞本地 Agent Memory Commit。Canonical Memory、Event、Receipt、SyncIntent/Outbox 同事务持久化；设备恢复后幂等 Push/Pull，并使用 durable cursor 继续。

### D-MEM-121 — Remote Recall Is Namespace-bound and Token-stable

Cluster Retrieval 只能在已绑定 MemorySpace 内执行，默认返回 bounded Capsule/Ref 而非大规模全文；所有结果仍经过 Local Context Arbitration、Token Economy、Privacy/Egress 与 CognitiveTrace。

### D-MEM-122 — Private Sync Never Changes Sharing Scope

MemorySpace 上传到 Server/Cluster 仅表示 Private Replica / Recovery / Retrieval，不改变 Agent 所有权，不授权其他 Agent或用户读取，也不自动成为 Project/Organization Knowledge。

### D-MEM-123 — Sync Is Deterministic and Zero-token by Default

Revision comparison、cursor、hash、dedup、fast-forward、tombstone 和 sync conflict detection 不调用 LLM。需要语义 Conflict Resolution 时进入独立 Memory Domain 工作流，而不是隐藏在 Sync 热路径中。

### D-MEM-124 — New-device Bootstrap Uses Logical Checkpoint + Delta

新设备恢复使用 Namespace Manifest / logical checkpoint / resource bundle + incremental delta，而不是复制数据库文件；本地 Canonical State 建立后重建 Core/FTS/Capsule 等 Projection，并优先恢复 Agent Identity Continuity。

**共同状态：** Accepted Candidate。

---

# 40. V3.4 Decision Log Addendum

v3.4 在 v3.3 `D-MEM-020` 至 `D-MEM-112` 基础上新增：

```text
D-MEM-113 ~ D-MEM-124
Cluster Sync / Offline Multi-device Revision
```

新增系统级结论：

```text
Cluster is not a second Memory Brain.
Sync replicates immutable semantic resources, not DB files.
Local workbenchd remains node-local single writer.
MemorySpace identity is stable across devices.
Revision conflict never silently uses Last-Write-Wins.
Tombstone prevents ordinary offline resurrection.
Remote recall remains namespace-bound and token-stable.
Sync is deterministic and zero-token by default.
```

---

# 41. E2EE / Server-side Retrieval / Key Architecture

Q19 在 v3.5 中正式从 Open Discussion 升级为 Accepted Candidate。

## 41.1 Hosting Modes

正式定义：

```text
LOCAL_ONLY
E2EE_PRIVATE_SYNC
TRUSTED_NODE
SEARCHABLE_CLOUD
```

默认远端模式：

```text
E2EE_PRIVATE_SYNC
```

`E2EE_PRIVATE_SYNC` 中公共 Cluster 只保存 ciphertext 与最小必要 routing metadata；FTS/Relation/Ranking/MemoryCapsule 默认在授权设备本地完成。

`TRUSTED_NODE` 允许用户自己的可信 Workbench/Memory Node 解密并执行 FTS / Vector / Graph / Archive Retrieval，公共 relay 仍可只见 ciphertext。

`SEARCHABLE_CLOUD` 允许 Cloud 直接处理可理解的 Memory Projection，因此属于更大的信任边界，不与 strict E2EE 混称。

## 41.2 Key Domains

Private Memory 采用：

```text
User Memory Root
    ├── MemorySpace Key A
    ├── MemorySpace Key B
    └── MemorySpace Key C
```

不同 Agent MemorySpace 使用独立长期数据密钥域。Runtime/LLM 永远不直接获得密钥材料。

Private / Project Shared / Organization Shared 使用不同 cryptographic domain：

```text
Private MemorySpace Key
Project Shared Key
Organization Shared Key
```

Private → Shared Promotion 必须创建新的 Shared Domain Asset 并重新加密，不能共享 Private Memory key/ciphertext。

## 41.3 Device Identity / Enrollment / Revocation

每个设备拥有独立：

```text
device_id
signing_public_key
key_agreement_public_key
status
```

新设备通过可信设备、Recovery mechanism 或其它明确授权流程获得受包装 key material。

Device revoke：

```text
future Push DENY
future Pull DENY
```

并可推进 MemorySpace Key Epoch。

必须明确：Revoke 只能阻止未来访问；如果失窃设备已经拥有旧 plaintext/key，服务器无法远程保证历史副本消失。

## 41.4 Key Epoch

Memory Revision 与 Encryption Key Epoch 完全分离：

```text
Memory Revision R182
encrypted_with MSK epoch 7
```

Key Rotation 不改变 semantic revision lineage。

触发可包括：

```text
device revoke
suspected compromise
manual rotate
policy
```

## 41.5 Cryptographic Mutation Authentication

`MemorySyncMutation`、Tombstone、Device/Key Security Mutation 必须可验证来源和完整性。

建议至少：

```text
origin_device_id
origin_sequence
payload_hash
signature
```

Server/Receiving Device 必须验证授权、签名、namespace、revision/hash 与 authenticated encryption。

## 41.6 E2EE Retrieval

严格 E2EE 模式：

```text
Remote encrypted replica
↓
authorized device
↓ decrypt locally
Local FTS / Metadata / Relation
↓
MemoryQueryPlan
↓
MemoryCapsule
```

大 MemorySpace 可：

```text
Local:
headers
capsules
FTS
relations
hot/warm payload

Remote encrypted:
cold/archive payload
```

命中冷数据时再 hydrate ciphertext、解密并验证。

## 41.7 Storage Privacy ≠ Model Egress

必须分别治理：

```text
Storage E2EE
```

和：

```text
LLM Provider Egress
```

Memory 在 Sync Cluster 上 E2EE，并不意味着被选中的 MemoryCapsule 没有发送给 Cloud Runtime。

所有 Materialization 继续执行 Data Egress Preflight，并在 CognitiveTrace/UI 中分别显示 Storage Privacy 与 Model Egress。

## 41.8 Metadata-minimized E2EE

Server 可能仍看到：

```text
opaque namespace/object id
revision id
device id
payload size
sync timing
access pattern
```

目标是 metadata-minimized，而不是声称 metadata-free。

默认加密：

```text
memory type
title
semantic tags
semantic summary
project/user descriptive labels
```

## 41.9 Recovery

默认优先 User-controlled Recovery Secret / Package。

必须明确：

```text
all devices lost
+
recovery secret lost
=
strict E2EE memory unrecoverable
```

未来若提供 Managed Recovery，必须明确 Key Escrow / Trust Boundary 变化。

## 41.10 Advanced Searchable Encryption

Searchable Symmetric Encryption、PIR、Homomorphic Encryption、Encrypted Vector Search、Confidential Compute 等属于后续 Research，不进入 MVP/Memory Hot Path，必须经过独立 Threat Model、Benchmark、Failure Analysis。

## 41.11 Accepted Decisions

### D-MEM-125 — E2EE Private Sync Is the Default Remote Memory Mode
Private Memory 跨设备同步默认采用 E2EE；公共 Sync/Cluster 不默认获得 Private Memory 明文。

### D-MEM-126 — Server-side Semantic Search and Strict E2EE Are Separate Modes
普通 server-side FTS/Vector/Graph 与 strict E2EE 属于不同信任模式，必须产品级明确区分。

### D-MEM-127 — E2EE Retrieval Is Local-first
Strict E2EE 下 FTS/Relation/Ranking/MemoryCapsule 默认在授权设备本地执行，Cold/Archive ciphertext 可按需 hydrate。

### D-MEM-128 — Trusted Node Provides Private Server-side Retrieval
允许用户自己的 Trusted Node 解密并执行完整 Retrieval；公共 relay 可继续只见 ciphertext。

### D-MEM-129 — Every Private MemorySpace Has an Independent Encryption Key Domain
每个 Agent Private MemorySpace 使用独立数据密钥域，Runtime/LLM 不获得密钥材料。

### D-MEM-130 — Keys Use Independent Epochs From Memory Revisions
Encryption Key Epoch 与 semantic Memory Revision 分离；Rotate 不修改 Revision lineage。

### D-MEM-131 — Device Enrollment Is Explicitly Authorized
新设备必须经过可信设备、Recovery 或其它明确授权流程获得 key material；公共 Server 默认无 Root Key。

### D-MEM-132 — Device Revocation Protects Future Access, Not Already Exfiltrated Plaintext
Revoke 阻止未来 Sync/Key 使用，但不虚假承诺能远程擦除已完全泄露的历史明文/旧 key。

### D-MEM-133 — Sync Mutations Are Cryptographically Authenticated
MemorySyncMutation、Tombstone 和 Key/Device Security Mutation 必须验证来源、授权与完整性。

### D-MEM-134 — Private and Shared Cognitive Assets Use Separate Key Domains
Private、Project Shared、Organization Shared 使用不同 key domain；Promotion 创建新 Shared Asset，不共享 Private ciphertext/key。

### D-MEM-135 — E2EE Storage and Model Egress Are Orthogonal
Storage E2EE 与 Cloud Model Egress 分开治理和展示。

### D-MEM-136 — E2EE Is Metadata-minimized, Not Metadata-free
Server 只持有最小 opaque routing/sync metadata；不得宣称 strict E2EE 等于零 metadata leakage。

### D-MEM-137 — Advanced Searchable Encryption Is Not P0
高级 searchable encryption / confidential compute 不进入 MVP 热路径，必须通过独立研究和 Benchmark。

### D-MEM-138 — Recovery Must State Who Can Recover the Key
Recovery 必须明确最终 Key Recovery Authority；默认优先 User-controlled Recovery，禁止隐式 Key Escrow。

**共同状态：** Accepted Candidate。

---

# 42. V3.5 Decision Log Addendum

v3.5 在 v3.4 `D-MEM-020` 至 `D-MEM-124` 基础上新增：

```text
D-MEM-125 ~ D-MEM-138
E2EE / Server-side Retrieval / Key Architecture
```

---

# 43. Agent Clone with Memory Snapshot

Q20 在 v3.6 中正式从 Open Discussion 升级为 Accepted Candidate。

目标：

> **普通 Clone 复制 Agent 的定义与能力，而不是默认复制其私人认知；显式带 Memory 克隆时，新 Agent 获得新的 Identity、MemorySpace、Memory IDs 与 Encryption Key，并从 Snapshot 时刻开始独立演化。**

## 43.1 Product Operations

正式区分三个产品操作：

```text
Clone Agent
=
Definition only

Clone with Experience
=
Definition
+
selected immutable Memory Snapshot

Export / Import Agent
=
portable package
```

`Clone`、`Sync`、`Export/Backup` 不得混为同一语义。

## 43.2 Definition-only Is the Default

普通 Clone 默认复制：

```text
Agent Definition
Instructions
Skill configuration
Tool requirements
Runtime compatibility
UI metadata
```

并创建：

```text
NEW agent_id
NEW memory_space_id
NEW MemorySpaceKey
NEW RuntimeBinding
EMPTY Private Memory
```

普通 Clone 的复杂度应接近 Agent Definition size，而不是 Source Memory Corpus size。

## 43.3 Clone with Experience Is Explicit

只有用户明确选择：

```text
Clone with Experience
```

才创建：

```text
MemoryCloneSnapshot
```

Snapshot 固定源 Agent 在某一时刻的 Memory Revision frontier，例如：

```text
M18@R4
M22@R7
M81@R2
M91@R19
```

Snapshot 创建后，源 Agent 后续 Revision 不自动传播到 Clone。

原则：

> **Clone inherits the past, not the future.**

## 43.4 Cloned Memory Gets New Identity

禁止：

```text
Agent A owns M81
Agent B also owns writable M81
```

正确：

```text
Agent A
M81 R7

↓ clone

Agent B
M982 R1

cloned_from:
memory://A/M81@R7
```

目标 Memory 使用新的：

```text
memory_id
memory_space_id
revision lineage
```

并通过 Clone Lineage 保留来源。

## 43.5 MemoryCloneLineage

建议：

```text
MemoryCloneLineage
├ clone_operation_id
├ snapshot_id
│
├ source_agent_id
├ source_memory_space_id
├ source_memory_id
├ source_revision_id
│
├ target_agent_id
├ target_memory_space_id
├ target_memory_id
├ target_initial_revision_id
│
├ clone_policy_revision
└ created_at
```

Lineage 用于 Audit / Trace / Privacy Delete，但不得成为目标 Agent读取源 Agent未来 Private Memory 的通道。

## 43.6 Type-aware Default Clone Policy

显式 `Clone with Experience` 也不执行全表复制。

建议默认：

| Memory 类型/状态 | 默认 Clone 行为 |
|---|---|
| Lesson | INCLUDE |
| Procedural | INCLUDE |
| Agent-owned Semantic | INCLUDE_IF_APPLICABLE |
| Preference | EXCLUDE |
| Episodic | EXCLUDE |
| Sensitive / Personal | REVIEW / EXCLUDE |
| Secret / Credential | DENY |
| Superseded | EXCLUDE |
| Retracted | EXCLUDE |
| Tombstoned | DENY |
| Contested | EXCLUDE / Explicit |
| Archived | EXCLUDE |

### Lesson

适合继承，但必须：

```text
ACTIVE
current-valid
non-sensitive
target applicability compatible
```

### Procedural

适合继承，但必须重新检查：

```text
target runtime
tool availability
version scope
project scope
```

### Semantic

如果本质属于 Shared Decision/Knowledge，只保留 Shared `ResourceRef`，不复制共享事实正文到每个新 Agent Private Memory。

### Preference

默认 EXCLUDE。用户和源 Agent 的关系偏好不自动等价于用户与新 Agent 的关系偏好。

### Episodic

默认 EXCLUDE。大量历史 Episode 不应成为普通 Clone 的隐式长期包袱。

## 43.7 Credential / Secret Never Clone Through Memory

Secret / Credential 不得随 Memory Clone 传播。

如果目标 Agent需要相同 Provider/Secret：

```text
Agent B
↓
Credential Requirement
↓
explicit CredentialRef binding
```

而不是：

```text
Clone A
→ copy secret to B
```

## 43.8 Clone Disclosure Preflight

`Clone with Experience` 必须复用 Cognitive Privacy Policy：

```text
MemoryClonePlan
      ↓
Clone Disclosure Preflight
      ├ sensitivity
      ├ personal data
      ├ secret
      ├ applicability
      ├ temporal validity
      ├ project scope
      └ user policy
      ↓
INCLUDE / REVIEW / EXCLUDE / DENY
```

Clone 不能因为用户点击一个按钮就绕过 Private Memory 治理。

## 43.9 MemoryClonePlan / Preview

建议：

```text
MemoryClonePlan {
    source_agent_id
    source_memory_space_id

    snapshot_mode:
      SELECTED_CURRENT |
      CUSTOM |
      HISTORICAL_FULL

    include_types[]
    exclude_types[]

    temporal_cutoff
    project_scope_filter
    sensitivity_policy

    estimated_memory_count
    estimated_payload_size

    policy_revision
}
```

UI 应先展示 Preview，例如：

```text
Lesson       182 include
Procedure     47 include
Semantic      91 include

Preference    26 excluded
Episode    12,812 excluded
Sensitive     11 review
Superseded   103 excluded
Tombstoned    18 denied
```

## 43.10 Minimum Sufficient Experience Inheritance

大型 MemorySpace：

```text
5M memories
```

不得默认全量复制。

优先：

```text
ACTIVE
type
importance
applicability
consolidated state
privacy
```

筛选出最小充分经验集。

原则：

> **Clone 的目标不是最大复制，而是最小充分经验继承。**

## 43.11 Core / Index / Cache Are Rebuilt

禁止直接复制：

```text
CoreMemorySnapshot
FTS
Vector
Graph
MemoryCapsule
Ranking stats
Usage stats
Temperature cache
Context cache
```

流程：

```text
selected Canonical Memories
↓
new target MemorySpace
↓
rebuild Core / FTS / Capsule
↓
optional Vector/Graph rebuild
```

Core 必须从目标 MemorySpace Canonical Records 重建，避免被排除的 Preference/Personal Memory通过旧 Core 偷渡。

## 43.12 Usage / Utility / Temperature Are Agent-specific

源 Agent：

```text
M81
used 892 times
utility 0.98
HOT
```

Clone 后不得变成目标 Agent自己的历史事实。

目标：

```text
usage = 0
local utility = neutral
temperature = policy-derived
```

允许保存：

```text
source_quality_hint
```

作为弱 prior，但不能替代目标 Agent自己的 Retrieval/Feedback history。

## 43.13 Evidence Permissions Are Re-evaluated

Cloned Memory 可以保留：

```text
ResourceRef
protected provenance
```

但目标 Agent必须重新通过目标 Project/Conversation/Artifact Permission 解析 Evidence。

例如：

```text
Project Incident I18
→ if authorized, usable

Source Agent Private Conversation C19
→ protected provenance only
```

Clone 不自动扩大 Source Resource 权限。

## 43.14 Shared Asset Refs Are Not Copied as Private Truth

若源 Memory 引用：

```text
Decision D22
Knowledge K18
```

目标 Memory保留 refs，而不是复制 D22/K18 正文形成第二套 Private Truth。

若目标 Agent无权限：

```text
source availability = UNRESOLVED
```

并降低 authority / 标记 revalidation，而不是偷偷复制 Shared Asset。

## 43.15 No Future Propagation

Clone 后：

```text
Source A updates M81
```

不自动：

```text
Target B updates M982
```

需要多 Agent持续共享的规则必须进入：

```text
Knowledge
Decision
Skill
Agent Definition
```

而不是 Private Memory propagation。

## 43.16 Deletion / Privacy Lineage

普通：

```text
delete source M81
```

默认仅影响源 MemorySpace；目标 Clone 已经是独立 Private Memory。

同时提供显式：

```text
DeletionScope
```

例如：

```text
SOURCE_ONLY
THIS_MEMORY_SPACE
CLONE_DESCENDANTS
ALL_DERIVED_PRIVATE_COPIES
```

用户要求“从所有克隆 Agent 删除这项信息”时，使用：

```text
LineagePurgeRequest
```

沿 `cloned_from / derived_from` 找到受影响 Private copies，并按权限/Tombstone/Purge Policy 执行。

## 43.17 Invalid Memories Are Not Inherited

默认：

```text
SUPERSEDED → EXCLUDE
RETRACTED  → EXCLUDE
TOMBSTONED → DENY
CONTESTED  → EXCLUDE
```

高级历史 Fork 可显式保留 Contested 历史，但必须保持 `CONTESTED`，不得在 Clone 后变为 ACTIVE。

## 43.18 Snapshot Is a Manifest, Not a New Memory Truth

`MemoryCloneSnapshot` 用于：

```text
audit
lineage
reproduce clone
```

不是正常 Recall 数据源。

普通本地 Clone：

```text
manifest durable
temporary payload bundle removable
```

只有显式 Export/Backup 才创建长期 portable encrypted package。

## 43.19 E2EE Clone Re-encrypts

Strict E2EE：

```text
Source Memory encrypted under MSK-A
↓
trusted local node decrypts selected items
↓
Clone Disclosure Preflight
↓
create target Memory IDs
↓
encrypt under MSK-B
```

禁止 A/B 共享长期 Private Memory key。

Public Cluster 不应看到 Clone plaintext。

## 43.20 Clone Is Zero-token by Default

以下默认：

```text
filter
select
copy
lineage
re-encrypt
rebuild projections
```

全部：

```text
LLM Calls = 0
```

如果用户要求：

```text
“克隆时重新总结/提炼/改造这些经验”
```

这是独立：

```text
Clone Transform Pipeline
```

必须显式触发，并重新经过 Candidate / Validation / Privacy。

## 43.21 Mass Inheritance Boundary

如果用户希望：

```text
1000 Agents
持续共享同一批规则/Procedure
```

正确模型：

```text
Agent Template
Project Knowledge
Decision
Skill
Shared Context
```

而不是：

```text
1000 × Private Memory Clone
```

原则：

> **Mass inheritance should be modeled as shared capability/knowledge, not massive Private Memory duplication.**

## 43.22 AgentCloneReceipt

建议：

```text
AgentCloneReceipt
├ clone_operation_id
├ source_agent_id
├ target_agent_id
│
├ source_memory_space_id?
├ target_memory_space_id
│
├ mode:
│   DEFINITION_ONLY |
│   MEMORY_SNAPSHOT
│
├ snapshot_id?
├ source_frontier?
│
├ memories_considered
├ memories_included
├ memories_excluded
├ exclusion_reason_counts
│
├ preference_included?
├ sensitive_reviewed?
│
├ target_key_epoch
├ projection_rebuild_status
└ completed_at
```

CognitiveTrace 可据此解释：

```text
“This memory exists because it was cloned at Snapshot S18.”
```

但未授权 Viewer 不得通过 Receipt 打开 Source Private Memory。

## 43.23 Accepted Decisions

### D-MEM-139 — Clone Defaults to Definition Only

普通 Agent Clone 只复制 Agent Definition、Instructions、Skill/Tool Requirements、Runtime Compatibility 与 UI Metadata；始终创建新的 `agentId / MemorySpaceId / MemorySpaceKey`，Private Memory 默认为空。

### D-MEM-140 — Memory Clone Is an Explicit Immutable Snapshot

只有用户明确选择 `Clone with Memory/Experience` 时才创建 `MemoryCloneSnapshot`；Snapshot 固定源 Memory Revision frontier，克隆后源 Agent 的后续 Revision 不自动传播。

### D-MEM-141 — Cloned Memories Receive New Identity

复制到新 Agent 的每条 Private Memory 获得新的 `memory_id` 和目标 MemorySpace 初始 Revision，通过 `cloned_from / sourceMemoryRef / snapshotRef` 保留 lineage；禁止两个 Agent共同拥有同一 writable Memory Record。

### D-MEM-142 — Clone Inherits the Past, Not the Future

Memory Clone 是 point-in-time inheritance，不是 Replication/Subscription。源 Agent 和 Clone Agent 从创建时刻开始独立演化；需要多 Agent持续共享的规则必须进入 Knowledge/Decision/Skill/Definition，而不是 Private Memory propagation。

### D-MEM-143 — Clone Policy Is Type- and Sensitivity-aware

显式 Memory Clone 默认优先包含 Active、Current-valid、non-sensitive Lesson/Procedure 与合适的 Agent-owned Semantic Memory；Preference、Episode、Sensitive/Personal、Contested、Archived 默认排除或要求显式选择；Secret/Credential、Tombstoned 默认禁止。

### D-MEM-144 — Core and Retrieval Projections Are Rebuilt

CoreMemorySnapshot、FTS、Vector、Graph、MemoryCapsule、Ranking/Usage/Temperature/Context Cache 不直接复制。目标 MemorySpace 建立 Canonical Memories 后重新构建 Projection。

### D-MEM-145 — Historical Utility Is Not Target-agent Usage

源 Agent 的 Usage Count、Hotness、Retrieval Utility 不作为目标 Agent 的真实使用历史复制。允许保存弱 `source_quality_hint`，但目标 Agent 的 Utility/Temperature 必须重新学习。

### D-MEM-146 — Clone Does Not Grant New Source Permissions

Cloned Memory 可保留 ResourceRef / protected provenance，但目标 Agent必须重新通过 Project/Conversation/Artifact 权限解析 Evidence；Clone 不自动授予源 Agent Private Conversation、Credential 或其它 Protected Resource 的访问权。

### D-MEM-147 — Memory Clone Requires Disclosure Preflight

`Clone with Memory` 必须经过 Cognitive Privacy/Sensitivity/Secret/Applicability/Temporal Preflight，并提供 Clone Preview；不能以用户点击 Clone 为理由绕过 Private Memory 治理。

### D-MEM-148 — Clone Re-encrypts Into a New MemorySpace Key Domain

E2EE Memory Clone 在可信节点解密选中 Source Memory，并以目标 Agent 新 MemorySpaceKey 重新加密；源与目标 Agent不得共享长期 Private Memory key。

### D-MEM-149 — Source Deletion Does Not Imply Automatic Clone Deletion

普通源 Memory 删除默认只影响源 MemorySpace，因为 Clone 已经独立；系统同时提供显式 lineage-aware `DeletionScope / LineagePurgeRequest`，用于用户要求从所有克隆/派生 Private Copies 删除某项信息的场景。

### D-MEM-150 — Clone Is Deterministic and Zero-token by Default

普通 Definition Clone 和 Snapshot select/copy/re-encrypt/rebuild 不调用 LLM。任何“Clone 时重新总结、提炼、改变人格”的行为属于独立 Transform Pipeline，必须显式触发并重新经过 Candidate/Validation。

### D-MEM-151 — Mass Inheritance Uses Shared Assets, Not Private Memory Duplication

当大量 Agent需要持续继承相同知识、规则或 Procedure 时，应使用 Agent Template、Project Knowledge、Decision、Skill 等 Shared/Capability Domain；不得通过批量 Private Memory Clone 构造隐式 Shared Brain。

**共同状态：** Accepted Candidate。

---

# 44. V3.6 Decision Log Addendum

v3.6 在 v3.5 `D-MEM-020` 至 `D-MEM-138` 基础上新增：

```text
D-MEM-139 ~ D-MEM-151
Agent Clone / Memory Snapshot
```

---

# 45. Memory Process Boundary / Zero-Extra-Model Baseline

Q21 在 v3.7 中正式从 Open Discussion 升级为 Accepted Candidate。

> **当前产品不要求、也不部署额外 Embedding / Reranker / Summarizer / 专用 Memory Model。Memory Baseline 除用户本来就在使用的主 Runtime（DeepSeek / Codex）之外，不增加额外模型依赖与模型费用。**

```text
Required Extra AI Models for Memory Baseline = 0
```

## 45.1 Current Official Topology

```text
workbenchd
├ AgentTurnCoordinator
├ ContextBroker
├ CognitiveEconomyController
├ MemoryKernel
│  ├ Identity / Namespace
│  ├ Canonical Memory / Revision / Conflict
│  ├ CoreMemory
│  ├ Capture / Candidate
│  ├ Privacy / Promotion
│  ├ Sync / Clone
│  ├ Receipts / CognitiveTrace
│  └ Deterministic Maintenance
├ Canonical SQLite
│  ├ Memory tables
│  ├ FTS5 / BM25
│  ├ Relation tables
│  ├ Outbox / Jobs / Receipts
│  └ Projection metadata
└ RuntimeAdapter
   ├ DeepSeek
   └ Codex
```

当前不部署：

```text
ai-memoryd
Embedding daemon
Vector database
Reranker model
HyDE model path
Dedicated semantic summarizer
Dedicated compression model
Dedicated memory model
Background dream model
```

## 45.2 Zero-Extra-Model Principle

Memory Baseline 不要求用户购买、订阅、下载或常驻运行额外 AI 模型。

当前 Recall：

```text
Direct Resolve
→ Metadata
→ SQLite FTS5 / BM25
→ Entity / Symbol / ResourceRef
→ SQLite Relation
→ Temporal / Applicability
→ Authority / Freshness
→ Dedup
→ Top-K
→ MemoryCapsule
→ Current Main Runtime judges small candidate set
```

## 45.3 Mandatory Recall Has No Embedding Dependency

```text
M0 Core
M1 Direct / Metadata / FTS / Relation
M2 deterministic deeper search_more
```

当前 `search_more()` 仍只需 FTS / Metadata / Temporal / Relation / ResourceRef，默认不产生额外模型调用。

## 45.4 Zero-token Maintenance

以下默认 `additional LLM calls = 0`：

```text
exact/hash dedup
supersede filtering
temperature update
archive candidate
Core dirty detection
FTS rebuild
relation maintenance
tombstone propagation
sync
clone
projection rebuild
job reconciliation
```

复杂语义 consolidation / generalized procedure extraction / difficult conflict resolution 默认 DEFER，而不是后台自动烧模型预算。

## 45.5 Process Boundary

Memory Kernel 保留在 `workbenchd` 内 Rust Domain。

必须留在可信热路径：

```text
Agent → MemorySpace binding
Namespace enforcement
Canonical Memory read/write
Revision DAG / Supersede / Retract / Tombstone
CoreMemory authority
Capture deterministic gate
Candidate lifecycle
Conflict / Temporal / Applicability
Privacy / Disclosure / Promotion
Clone / Sync authorization
Key authorization metadata
Context materialization authorization
Receipts / CognitiveTrace
```

## 45.6 No `ai-memoryd` in Current Product

当前：

```text
ai-memoryd = NOT DEPLOYED
```

只有未来真实出现多个异构持久 Worker、共享 GPU/model cache、复杂资源调度、独立升级/重启需求时，才考虑抽取 Compute Supervisor。即便如此，它也不能拥有 Canonical Memory Authority。

## 45.7 FTS / Relation Stay In-process

SQLite FTS5/BM25 与基础 `memory_relation` 留在 `workbenchd` / Canonical SQLite。第一版不要求 Graph DB。

## 45.8 MemoryCapsule Is Deterministic

MemoryCapsule 从 Canonical structured fields / refs 确定性构造，不要求每条 Memory 调用模型摘要。

## 45.9 Future Semantic Retrieval Extension

可以保留接口：

```text
SemanticRetrievalProvider
EmbeddingProvider
VectorIndexProvider
RerankerProvider
SemanticCompressionProvider
```

但当前：

```text
implementation = NONE
deployed = false
required = false
```

接口存在不代表未来必须采购或部署。

## 45.10 Future Entry Gate

未来任何 Embedding / Vector DB / Reranker / HyDE / Semantic Compression Model / Graph Semantic Engine / Dedicated Memory Model，只有同时满足：

```text
真实 Benchmark 缺口存在
+
Zero-Extra-Model Baseline 无法接受地解决
+
Q17 A/B 证明显著任务收益
+
Token/Latency/RAM/Disk 成本可接受
+
运营预算存在
```

才允许进入实施评审。

如果 SQLite/FTS/Relation baseline 已达到质量目标，则可以永久不部署 Embedding/Vector。

## 45.11 No Embedding Model Is Selected

当前不锁定 BGE / E5 / Nomic / Jina 或其它 Embedding Model。只有未来 Semantic Retrieval Extension 被正式批准后，才通过独立 ADR / Benchmark 决定 provider、model、revision、dimensions、distance metric、normalization 与 index migration。

## 45.12 Future Worker Boundary

未来若启用 Embedding / Vector / Advanced Graph / Semantic Compression / Reranker / Consolidation Proposal，它们只能作为：

```text
replaceable
rebuildable
non-canonical
```

Worker/Provider，不能拥有 Canonical SQLite、MemorySpace、ACTIVE Memory commit 权或长期 MemorySpace keys。

## 45.13 Future Worker Results Are Revision-bound

所有未来异步 Worker Result 必须绑定 `source_ref + source_revision + source_hash + provider_version`。源 Revision/Tombstone 变化后结果必须视为 `STALE_RESULT`。

## 45.14 Future Workers Default No-network

未来本地第三方 Worker 默认无网络；需要 remote provider 时必须显式经过 Workbench Egress Policy。

## 45.15 Native Linux Process Model

官方仍使用 native binary + `systemd --user` + UDS（如未来需要）。Docker/Compose 不进入官方依赖链。当前最小正式拓扑只要求 `workbenchd.service`。

## 45.16 Accepted Decisions

### D-MEM-152 — Canonical Memory Kernel Lives Inside `workbenchd`
MemorySpace ownership、Canonical Revision、Core、Lifecycle、Conflict、Capture、Privacy、Sync/Clone authorization 与 Receipt/Trace 属于 `workbenchd` 内 Rust Memory Domain；不得迁移给独立 `ai-memoryd` 形成第二 Canonical Writer。

### D-MEM-153 — Zero-Extra-Model Is the Current Memory Baseline
当前 Memory Baseline 除用户已选择的 DeepSeek/Codex 主 Runtime 外，不要求购买、下载、常驻或调用额外 Embedding、Reranker、Summarizer、Compression 或专用 Memory Model。

### D-MEM-154 — Mandatory Recall Has No Embedding Dependency
M0/M1 与当前 M2 Deep Recall 必须在没有 Embedding/Vector/Reranker/HyDE 的情况下完整工作。

### D-MEM-155 — Zero-token Maintenance Is the Default
Dedup、Supersede、Temperature、Archive、Core dirty、FTS/Relation rebuild、Tombstone、Sync、Clone 与 Job Recovery 默认不调用额外 LLM。

### D-MEM-156 — No `ai-memoryd` Is Required in the Current Product
当前产品不部署独立常驻 `ai-memoryd`；Memory Kernel、FTS、Relation、Capsule 与 Deterministic Maintenance 由 `workbenchd` 直接提供。

### D-MEM-157 — FTS and Baseline Relation Stay In-process
SQLite FTS5/BM25 与基础 Relation 查询属于当前 Baseline，不跨进程、不依赖 Graph DB/Vector DB。

### D-MEM-158 — MemoryCapsule Is Deterministic by Default
MemoryCapsule 从 Canonical structured fields / refs 确定性构造，不要求每条 Memory 调用模型摘要。

### D-MEM-159 — Semantic Retrieval Interfaces Are Reserved, Not Deployed
Embedding/Vector/Reranker/SemanticCompression Provider seam 可保留，但当前 `implementation = NONE`、`deployed = false`、`required = false`。

### D-MEM-160 — Future Semantic Retrieval Is Budget- and Benchmark-gated
只有真实 Benchmark 证明当前 Baseline 存在关键缺口，且语义扩展带来显著净收益并具备预算时，才允许进入实施评审。

### D-MEM-161 — No Embedding Model Is Selected Until Semantic Retrieval Is Approved
当前不选定具体 Embedding Model；只有未来 Semantic Retrieval Extension 被正式批准后才单独选型。

### D-MEM-162 — Future Workers Are Non-canonical Cognitive Coprocessors
未来可选 Worker 只能生成 Projection/Score/Proposal，不拥有 MemorySpace、Canonical SQLite、Semantic Authority 或长期 Key Material。

### D-MEM-163 — Future Worker Results Are Revision-bound
所有未来异步 Worker Result 必须绑定 Source Revision/Hash，并在提交前校验。

### D-MEM-164 — Future Third-party Workers Default to No Network
本地 Worker 默认无网络权限；只有明确 remote provider 才能经过 Egress Policy 获得有限网络能力。

### D-MEM-165 — `ai-memoryd` May Be Extracted Only When Real Compute Orchestration Requires It
只有异构持久 Worker、共享 GPU/model cache、资源调度、独立升级/重启等真实复杂度达到阈值时，才允许抽取 Compute Supervisor，且不得改变 Canonical Authority Boundary。

**共同状态：** Accepted Candidate。

---

# 46. V3.7 Decision Log Addendum

v3.7 在 v3.6 `D-MEM-020` 至 `D-MEM-151` 基础上新增：

```text
D-MEM-152 ~ D-MEM-165
Memory Process Boundary / Zero-Extra-Model Baseline
```

当前正式成本结论：

```text
Extra Memory Models Required: 0
Embedding Deployed: NO
Vector DB Deployed: NO
Reranker Deployed: NO
Dedicated Memory Model: NO
Dedicated Compression Model: NO
ai-memoryd Deployed: NO

Baseline:
SQLite + FTS5 + Metadata + Relation
+ MemoryCapsule
+ CognitiveEconomy
+ Current Main Runtime
```

---

# 47. OSS Final Integration Map

Q22 在 v3.8 中正式从 Open Discussion 升级为 Accepted Candidate。

目标：

> **OSS Research 的目的不是安装更多依赖，而是吸收成熟设计、避免已知错误，并只在 Stable Boundary + Benchmark + Budget 允许时引入真正需要的组件。**

当前约束：

```text
No extra model budget in current product
No Docker official dependency
No second Canonical Memory truth
No mandatory Vector / Embedding
No Worker direct Canonical DB access
No Private Memory cross-Agent leakage
```

## 47.1 Current MVP Integration Registry

| 项目 | 当前决策 | 主要用途 |
|---|---|---|
| SQLite FTS5 | ADOPT | 官方 Baseline Retrieval |
| Ponytail | REFERENCE_ONLY / optional skill research | Cognitive Economy |
| context-compressor | PORT_IDEA / POC | deterministic/extractive pruning |
| Mnesis | REFERENCE_ONLY | Active Context / FileRef / tool pruning |
| Letta | REFERENCE_ONLY | Lean Core / External Memory / continuity |
| Mem0 | REFERENCE_ONLY | Memory API / evaluation ideas |
| memory-benchmarks | REFERENCE / FIXTURE_INPUT | LOCOMO / LongMemEval / BEAM ideas |
| Graphiti | FUTURE_PROVIDER / REFERENCE_ONLY | Temporal relation / provenance |
| LLMLingua | FUTURE_RESEARCH | C3 semantic compression |
| Vector DB / Embedding stack | NOT_DEPLOYED | future benchmark-gated seam |

## 47.2 SQLite FTS5 Is the Official Retrieval Engine

当前正式 Retrieval：

```text
MemorySpace hard namespace filter
↓
ACTIVE / Temporal / Applicability
↓
FTS5 MATCH
↓
BM25
↓
Authority / Freshness / Importance / Anchor boost
↓
Dedup
↓
Top-K
↓
MemoryCapsule
```

FTS5 不承担全部语义理解；它负责把大 Corpus 收敛成小候选集，最终语义判断由当前主 Runtime 对 bounded Capsules 完成。

## 47.3 Ponytail

定位：

```text
Memory Provider      NO
Canonical Component  NO
Retrieval Engine     NO

Design Reference     YES
Optional Skill POC   YES
```

吸收：

```text
Minimum Necessary Work
→
Minimum Necessary Recall
Minimum Necessary Context
Minimum Sufficient Output
Minimum Necessary Expansion
```

Ponytail 不成为 Memory Core 依赖。

## 47.4 Deterministic Context Compression

`context-compressor` 一类 deterministic / extractive / lossless-first 思路优先作为算法参考。

若 POC 有收益：

```text
study algorithm
↓
reimplement minimal logic in Rust
↓
Q17 benchmark
↓
adopt native deterministic pruner
```

不因 Context Compression 引入常驻 Python Runtime。

优先用于：

```text
Conversation Delta
Long Tool Projection
Repeated Knowledge excerpts
Repeated instructions
```

不作为 Canonical Memory truth rewrite。

## 47.5 Mnesis

吸收：

```text
Active Context
Tool Output pruning
Content-addressed FileRef
Lossless / deterministic context management
```

不引入其 Session / Agent Runtime / Python orchestration。

状态：

```text
REFERENCE_ONLY
```

## 47.6 Letta

吸收：

```text
Lean in-context Core
External Memory
On-demand retrieval
Agent continuity concepts
```

不引入：

```text
Letta Agent Runtime
Letta Canonical Store
Letta Session authority
```

状态：

```text
REFERENCE_ONLY
```

避免 Workbench 出现第三 Agent Loop。

## 47.7 Mem0

当前标准路线常依赖：

```text
LLM extraction
Embedder
Vector Store
optional Reranker
```

与 Zero-Extra-Model Baseline 不匹配。

当前：

```text
Mem0 Canonical Store      REJECT
Mem0 Hot Path Provider    REJECT
Mem0 Cloud dependency     REJECT
Mem0 API / Eval ideas     REFERENCE_ONLY
```

## 47.8 External Memory Benchmarks

LOCOMO / LongMemEval / BEAM 等外部评测可作为：

```text
dataset
scenario taxonomy
fixture inspiration
```

但最终必须转换成 Workbench 自有：

```text
BenchmarkExpectation
MemoryBenchmarkReport
```

并增加：

```text
Namespace
Cross-Agent Privacy
Restart
Tombstone
Clone
E2EE
Token Economy
```

等 Workbench 特有测试。

## 47.9 Graphiti

吸收：

```text
temporal validity
provenance
relation modeling
incremental graph thinking
```

当前不部署：

```text
Graphiti runtime
Graph DB
Embedding
Reranker
Graph LLM chain
```

当前 SQLite `memory_relation` 足够第一版。

只有 Q17 证明 SQLite Relation 不足时，才进入 Future Provider 评审。

## 47.10 LLMLingua

当前因需要额外 compression model/runtime：

```text
NOT_DEPLOYED
```

仅作为未来：

```text
C3 SEMANTIC_COMPRESSION
```

研究候选，并受：

```text
Budget Gate
Benchmark Gate
Compression Safety Gate
```

控制。

## 47.11 Integration Registry Contract

今后每个 OSS Candidate 必须登记：

```text
IntegrationRegistryEntry
├ project
├ version_or_commit_reviewed
├ license
│
├ decision
│   ADOPT
│   PORT_IDEA
│   PROVIDER_FUTURE
│   REFERENCE_ONLY
│   REJECT
│
├ target_layer
├ canonical_authority
├ model_required
├ network_required
├ persistent_process
├ language_runtime
│
├ private_plaintext_access
├ key_access
│
├ token_cost
├ ram_cost
├ disk_cost
│
├ failure_mode
├ degradation_mode
│
├ benchmark_requirements[]
└ rationale
```

以下字段必填：

```text
model_required
network_required
persistent_process
private_plaintext_access
key_access
```

当前预算下：

```text
model_required = YES
```

默认意味着：

```text
REFERENCE_ONLY
or
FUTURE_BENCHMARK_GATED
```

除非另有明确批准。

## 47.12 No OSS Is Mandatory Beyond SQLite Baseline

即使以下项目全部不存在：

```text
Ponytail
Letta
Mem0
Graphiti
LLMLingua
Mnesis
context-compressor
```

正式 Memory Baseline 仍必须完整运行：

```text
workbenchd
+
SQLite
+
FTS5
+
Relation
+
MemoryCapsule
+
CognitiveEconomy
+
DeepSeek/Codex Runtime
```

## 47.13 Accepted Decisions

### D-MEM-166 — SQLite FTS5 Is the Official MVP Retrieval Engine

当前正式 Memory Retrieval 使用 Canonical SQLite 上的 Metadata + FTS5/BM25 + Relation + Temporal/Authority Ranking；不要求独立搜索服务、Vector DB 或 Embedding。

### D-MEM-167 — OSS Is Integrated by Stable Boundary, Not Source Mega-merge

第三方项目只有在确有必要时通过 Provider/Adapter/Worker 集成；Architectural Idea 可以重新实现，但不得为了“功能齐全”把外部 Agent Runtime、Memory DB 或 Control Plane 合并进 Workbench Core。

### D-MEM-168 — Ponytail Is a Cognitive Economy Reference, Not a Memory Provider

Ponytail 的 Minimum Necessary Work / benchmark 方法进入 Cognitive Economy 设计参考；其代码不成为 Canonical Memory dependency。未来可独立评估为 Workbench Coding Skill。

### D-MEM-169 — Deterministic Context Compression Is Preferred Over Model Compression

`context-compressor` 一类 deterministic/extractive/lossless-first 方法优先作为算法 POC；如果验证有效，优先在 Rust/Workbench 内重实现，不为此引入常驻 Python Runtime。

### D-MEM-170 — Letta and Mnesis Are Architecture References, Not Runtime Dependencies

Letta 的 Lean Core/External Memory 和 Mnesis 的 deterministic Active Context/FileRef 等设计可以吸收，但它们自己的 Agent/Session/Memory Runtime 不进入 Workbench execution authority。

### D-MEM-171 — Mem0 Is Not a Current Memory Provider

Mem0 当前标准 OSS 架构与 Zero-Extra-Model Baseline 不匹配；当前仅参考其 API/benchmark 思路，不作为 Canonical、Provider 或 Hot Path dependency。

### D-MEM-172 — Graphiti Is a Future Temporal Graph Reference

Graphiti 的 Temporal/Provenance/Relation 模型可用于验证我们的 Relation Schema，但当前不部署 Graphiti、Graph DB、Embedding、Reranker 或相关 LLM chain。只有 Q17 证明 SQLite Relation 不足时才重新评估。

### D-MEM-173 — LLMLingua Is Future Compression Research Only

LLMLingua 因需要额外 compression model/runtime 不进入当前产品；仅作为未来 C3 Semantic Compression 候选，并受预算、Benchmark、Compression Safety Gate 控制。

### D-MEM-174 — External Memory Benchmarks Are Inputs, Not Release Authority

LOCOMO、LongMemEval、BEAM 等外部评测可以转换为 Workbench fixture，但最终 Release Gate 由自有 `MemoryBenchmarkReport` 决定，必须增加 Namespace、Privacy、Restart、Tombstone、Clone、E2EE、Token Economy 等 Workbench 特有测试。

### D-MEM-175 — Every OSS Candidate Must Declare Cost and Trust Surface

任何 OSS Integration Registry 必须明确 Model、Network、Persistent Process、Language Runtime、Private Plaintext、Key Access、RAM/Disk/Token Cost 和 Failure/Degradation Mode；无法满足当前 Budget/Privacy Boundary 的项目默认不进入实施。

### D-MEM-176 — No OSS Is Mandatory Beyond the SQLite Baseline

当前 Memory MVP 不因为 OSS Research 而增加新的必须运行服务。所有第三方 Memory OSS 全部不可用时，正式 Memory Baseline 仍必须完整运行。

**共同状态：** Accepted Candidate。

---

# 48. V3.8 Decision Log Addendum

v3.8 在 v3.7 `D-MEM-020` 至 `D-MEM-165` 基础上新增：

```text
D-MEM-166 ~ D-MEM-176
OSS Final Integration Map
```

当前正式 MVP Dependency 结论：

```text
Required Memory OSS:
SQLite / FTS5 only

Required Extra Models:
0

Required Vector DB:
0

Required Graph DB:
0

Required Memory Daemon:
0

Required Python/Node Memory Runtime:
0
```

---

# 49. Memory MVP Implementation Plan

Q23 在 v3.9 中正式从 Open Discussion 升级为 Accepted Candidate。

目标：

> **从架构规范进入可直接排 Sprint / Issue / Migration 的工程实现阶段。MVP 先实现可靠、可恢复、可解释、Token 有界的 Canonical Memory Backbone，不把高级语义能力作为前置条件。**

## 49.1 MVP Scope

```text
workbenchd
+ Canonical SQLite
+ FTS5/BM25
+ Relation
+ CoreMemory
+ MemoryCapsule
+ beforeTurnMemory()
+ afterTurnMemory()
+ Receipts
+ Recovery
```

当前不属于 MVP 前置条件：

```text
Embedding
Vector DB
Graph DB
Reranker
ai-memoryd
Semantic Compression Model
Background LLM Maintenance
```

## 49.2 Rust Module Boundary

```text
workbenchd/
└ memory/
   ├ mod.rs
   ├ model.rs
   ├ repository.rs
   ├ lifecycle.rs
   ├ recall.rs
   ├ ranking.rs
   ├ capsule.rs
   ├ core.rs
   ├ capture.rs
   ├ conflict.rs
   ├ maintenance.rs
   ├ sync.rs
   ├ receipts.rs
   └ recovery.rs
```

`repository.rs` 只负责 persistence/query/transaction，不隐藏 ACTIVE/DROP/Supersede/Conflict 等 Domain 决策。

## 49.3 Initial Canonical Tables

```text
memory_space
memory_record
memory_revision
memory_revision_parent
memory_source_ref
memory_relation
memory_candidate
memory_core_snapshot
memory_access_stat
memory_turn_receipt
memory_capture_receipt
memory_use
memory_outbox
memory_job
memory_projection_state
memory_fts
```

全部位于 Workbench Canonical SQLite，由 `workbenchd` 单写。

## 49.4 MemorySpace Invariants

```text
1 Agent Identity = 1 writable Private MemorySpace
```

禁止一个 Agent 多个 writable MemorySpace，也禁止多个 Agent 共享同一 writable MemorySpace。

## 49.5 Stable Record + Immutable Revision

`memory_record` 保存稳定 Memory identity/current head；`memory_revision` 保存 immutable canonical content revision。多设备未来通过 `memory_revision_parent` 扩展 DAG。

## 49.6 Canonical Memory Types

```text
EPISODIC
SEMANTIC
PROCEDURAL
PREFERENCE
LESSON
```

不增加 SHORT_TERM / SESSION / PROJECT_MEMORY / ROOM_MEMORY / GLOBAL_MEMORY。

## 49.7 Lifecycle

Canonical Record 状态：

```text
ACTIVE
SUPERSEDED
CONTESTED
RETRACTED
ARCHIVED
TOMBSTONED
```

Candidate 独立存在于 `memory_candidate`。

## 49.8 FTS5 Projection

普通 Recall 的 FTS5 默认只索引当前可召回 Head。旧/superseded Revision 不混入 Current Recall；Historical Recall 走独立路径。

建议字段：

```text
memory_id
memory_space_id
claim
lesson
keywords
entity_text
scope_text
```

FTS Projection 更新与 Canonical Revision/Head/Receipt 同 SQLite transaction 维护。

## 49.9 `beforeTurnMemory()`

输入至少包含：

```text
turn_id
agent_id
conversation_id
surface
project_id?
work_item_id?
mission_id?
room_id?
user_text
resource_refs[]
conversation_delta_refs[]
context_profile
token_budget
egress_context
```

Runtime 不提供 `memory_space_id`，由 Memory Kernel 根据 `agent_id` 绑定。

输出：

```text
memory_space_id
core_snapshot
query_plan
selected_capsules[]
expansion_capabilities
memory_budget
degraded
receipt_draft_ref
```

Memory 不直接生成最终 Prompt，由 Context Broker Arbitration。

## 49.10 Deterministic MemoryQueryPlan

MVP QueryPlan 由 Current Turn、Task/Project IDs、ResourceRefs、Conversation Delta、Core Anchors 确定性生成，不新增 LLM Query Rewriter。

## 49.11 MVP Recall Pipeline

```text
Resolve namespace
→ hard filter
→ Direct refs
→ FTS5/BM25
→ Relation boost
→ Rank
→ Dedup
→ Token pack
→ MemoryCapsule Top-K
```

初始 Ranking 只使用 lexical、anchor、type、authority、freshness、importance、applicability、redundancy penalty 等少量可解释 feature。

## 49.12 MemoryCapsule

```text
MemoryCapsule
├ memory_ref
├ type
├ claim
├ lesson?
├ scope?
├ status
├ validity?
├ evidence_refs[0..3]
└ expand_ref
```

普通目标 60–150 tokens/item；完整内容通过 `memory.read()` 按需展开。

## 49.13 Runtime Memory Tools

```text
memory.search_more(query, filters?)
memory.read(memory_ref)
memory.trace(...)
```

自动绑定当前 Agent MemorySpace；Runtime 不能传 agent_id、memory_space_id 或 raw SQL。

## 49.14 `afterTurnMemory()`

输入至少包含：

```text
turn_id
agent_id
user_turn_ref
assistant_turn_ref
tool_result_refs[]
workspace_change_refs[]
decision_refs[]
review_refs[]
outcome
user_explicit_memory_intent?
runtime_memory_hints[]
```

先执行 deterministic Capture Gate。

## 49.15 Initial Capture Signals

```text
EXPLICIT_USER_MEMORY
EXPLICIT_USER_CORRECTION
VERIFIED_FAILURE_REPAIR
VERIFIED_TASK_OUTCOME
MANUAL_MEMORY_SAVE
```

automatic repeated-pattern inference / semantic generalization / autonomous consolidation 暂缓。

## 49.16 Golden Path 1 — Explicit Remember

```text
User: remember X
→ afterTurnMemory
→ Capture Gate
→ Candidate
→ sensitivity/secret/dedup
→ Canonical Commit
→ Core dirty if eligible
→ CaptureReceipt
→ restart
→ next Turn recalls exact revision
```

## 49.17 Golden Path 2 — Correction

```text
Old Memory
→ User Correction
→ resolve affected memory
→ new revision/supersede/conflict
→ old no longer current
→ FTS/Core dirty update
→ next Turn sees current truth
```

禁止简单创建两个并行 ACTIVE 矛盾 Memory。

## 49.18 CoreMemory MVP

MVP Core 优先只允许：

```text
Confirmed Preference
Standing Constraint
Critical Lesson
```

Core 必须 small、deterministic、versioned、hard capped、rebuildable。

## 49.19 Memory Evidence

每个 Visible Turn 至少生成 `MemoryTurnReceipt`，关联 memory_space、core revision、query plan、selected revisions、estimated tokens、deep recall、degraded state。

`memory_use` 至少记录：

```text
RETRIEVED
SELECTED
MATERIALIZED
REF_ONLY
TOKEN_EVICTED
RANKED_OUT
CONFLICT_SUPPRESSED
```

## 49.20 Recovery Sweep

`workbenchd` 启动执行 `MemoryRecoverySweep`，至少验证：

```text
memory_record.head exists
head belongs same memory_id
MemorySpace ownership
Core dirty
FTS dirty
pending outbox
pending deterministic jobs
tombstone propagation
```

Canonical/Core/Ownership invariant 破坏时阻断正常 Turn；可重建 Projection 问题允许 degraded startup/rebuild。

## 49.21 Projection State

```text
CORE
FTS
RELATION
```

状态：

```text
CLEAN
DIRTY
REBUILDING
FAILED
```

## 49.22 Migration Order

```text
M001 Memory identity / record / revision
M002 Source refs / relations
M003 FTS5 projection
M004 Core / candidates / receipts / use
M005 Outbox / projection state / recovery jobs
```

## 49.23 FakeRuntime

提供确定性 FakeRuntime，用于完整 Turn Lifecycle 0 Token 集成测试。

## 49.24 Initial 0-token CI Matrix

```text
Agent namespace isolation
MemorySpace binding
Revision / supersede
Temporal current/history
FTS recall
Relation recall
Capsule packing
Core size limit
Capture Gate
Tombstone
Restart recovery
Clone lineage
Sync outbox
Token budget
```

## 49.25 Implementation Phases

```text
Phase A Canonical Memory Foundation
Phase B Mandatory Recall
Phase C Capture / Correction
Phase D Observability / Recovery
Phase E Memory Studio
Phase F Sync / E2EE
Phase G Optional sophistication
```

MVP Release 可以在 Phase E 后形成首个完整 Local Release。

## 49.26 Hard Release Gate

任何一项失败阻止发布：

```text
Cross-Agent Private Memory read > 0
Visible Turn bypasses beforeTurnMemory
Canonical revision/head inconsistency
Current recall returns tombstoned Memory
Superseded current Memory injected as current
Restart loses committed Memory
Core exceeds hard budget
FTS returns another MemorySpace
Memory Receipt missing for visible Turn
Pathological capture pollution
```

## 49.27 Engineering Priority

```text
correct
bounded
observable
recoverable
```

高于：

```text
semantically fancy
more autonomous
more providers
more models
```

## 49.28 Accepted Decisions

### D-MEM-177 — MVP Implements Canonical Memory Before Advanced Retrieval
第一阶段优先实现 MemorySpace、Stable Record、Immutable Revision、SourceRef、Relation、Lifecycle、Tombstone 与 Transaction Invariant；Vector/Graph/Embedding/AI Consolidation 不属于 MVP 前置条件。

### D-MEM-178 — MVP Uses One Canonical SQLite Database
Memory Canonical tables、FTS5 Projection、Receipts、Outbox、Jobs 与 Projection State 均位于 Workbench Canonical SQLite，并继续由 `workbenchd` 单写。

### D-MEM-179 — FTS5 Indexes Current Searchable Heads by Default
普通 Recall 的 FTS Projection 只索引当前可召回 Revision，旧/superseded Revision 不进入默认当前搜索。

### D-MEM-180 — MemoryQueryPlan Is Deterministic in MVP
MVP `MemoryQueryPlan` 由 Turn/Task/Project/ResourceRef/Conversation Delta/Core Anchor 确定性生成，不新增 LLM Query Rewriter。

### D-MEM-181 — MemoryCapsule Is the Default Recall Materialization Unit
M1 Recall 默认输出 bounded `MemoryCapsule`，完整记录仅通过 `memory.read()` 按需展开。

### D-MEM-182 — Before-turn Memory Is Mandatory but May Return Zero Memories
每个 Visible Agent Turn 必须执行 `beforeTurnMemory()`；M1 返回零 Relevant Memory 属于正常成功状态。

### D-MEM-183 — Initial Capture Supports Only High-confidence Signals
MVP Capture 优先实现 Explicit Remember、Manual Save、Explicit Correction、Verified Outcome/Repair 等强信号。

### D-MEM-184 — Correction Updates Memory Lineage Instead of Adding Silent Contradictions
明确用户 Correction 必须查找受影响 Memory，并通过 Revision/Supersede/Conflict 更新当前 Truth。

### D-MEM-185 — Core Is Deterministic, Small and Rebuildable
MVP Core 只包含少量高价值条目，并从 Canonical Memory 确定性重建。

### D-MEM-186 — Every Visible Turn Produces Memory Evidence
每个 Visible Turn 至少产生 `MemoryTurnReceipt`，并记录 MemorySpace、Core Revision、QueryPlan、Selected Revisions、Token Estimate、Deep Recall、Degraded State。

### D-MEM-187 — Recovery Is Deterministic and Runs Before Normal Memory Use
`workbenchd` 启动执行 Memory Recovery Sweep，验证 Head/Revision/Namespace/Projection/Outbox/Tombstone invariants。

### D-MEM-188 — FakeRuntime Is a First-class Integration-test Runtime
提供确定性 FakeRuntime，使完整 Memory/Context/Capture/Receipt/Recovery Integration Tests 在 0 Token 成本下运行。

### D-MEM-189 — MVP Release Is Blocked by Identity, Privacy, Revision or Recovery Failures
Cross-Agent Leakage、MemorySpace misbinding、Tombstoned/Superseded current injection、Canonical inconsistency、committed-memory loss、Visible Turn bypass 等属于 Hard Release Blocker。

### D-MEM-190 — Sync and Advanced Cognitive Automation Follow Local MVP Correctness
Cluster Sync/E2EE、Semantic Consolidation、高级 Pattern Learning 和外部 Provider 在 Local Canonical Memory、Recall、Capture、Recovery、Trace 与 Memory Studio 稳定后进入下一阶段。

**共同状态：** Accepted Candidate。

---

# 50. V3.9 Decision Log Addendum

v3.9 在 v3.8 `D-MEM-020` 至 `D-MEM-176` 基础上新增：

```text
D-MEM-177 ~ D-MEM-190
Memory MVP Implementation Plan
```

---

# 51. SQLite Schema / Rust API Engineering Freeze

Q24 在 v3.10 中正式完成，并结束开发前架构冻结阶段。

目标：

> **从这一版本开始，Memory MVP 的核心数据库、Domain API、事务一致性、错误语义、Migration 与 Golden Path 已达到可以直接编码的级别。除非测试或实现证明 Contract 存在缺陷，否则不再以“继续架构讨论”为理由推迟 Phase A。**

## 51.1 Engineering Freeze Scope

本轮冻结：

```text
SQLite feature baseline
exact canonical DDL
FTS5 current-head projection
indexes / constraints / triggers

Rust IDs / enums / structs
MemoryQueryPlan
MemoryCapsule
beforeTurnMemory()
recordMaterialization()
search_more()
read()
afterTurnMemory()

repository/domain boundary
transaction boundaries
error taxonomy
migration names
FakeRuntime contract
first acceptance tests
```

不冻结：

```text
GUI layout
future Cluster protocol wire format
future vector/embedding provider
future semantic worker
future physical E2EE storage encoding
```

这些不能反向改变当前 Canonical Memory Authority。

## 51.2 SQLite Feature Baseline

Memory MVP 要求 SQLite 具备：

```text
Foreign Keys
FTS5
JSON functions
STRICT tables
WAL support
```

运行时必须：

```text
PRAGMA foreign_keys = ON
```

建议 Workbench 继续使用 WAL + 短写事务。

这里的要求不增加任何独立数据库服务、模型或 daemon。

## 51.3 Canonical ID / Time Rules

Persistence 层：

```text
IDs       = opaque non-empty TEXT
timestamp = Unix epoch milliseconds INTEGER
boolean   = INTEGER CHECK (0, 1)
JSON      = canonical UTF-8 TEXT + json_valid CHECK
```

Rust 层必须对 MemorySpaceId / MemoryId / MemoryRevisionId 等使用 newtype，禁止在 Domain 热路径中把它们都当裸 `String` 混用。

Memory ID / Revision ID 的具体生成算法可以使用 Workbench 现有全局 ID 方案；Q24 不另造第二种 ID system。

## 51.4 Exact DDL

以下 DDL 为 Memory MVP V1 的 normative schema。Standalone companion 同时生成：

`MEMORY_MVP_SCHEMA_V1.sql`

```sql
-- MEMORY_MVP_SCHEMA_V1.sql
-- Q24 / V3.10 normative MVP schema.
-- SQLite requirements:
--   foreign_keys = ON
--   FTS5 available
--   JSON functions available
--   STRICT tables available
-- Runtime recommendation:
--   WAL mode, short write transactions, one Workbench writer.

PRAGMA foreign_keys = ON;

-- ============================================================
-- M001__memory_identity_revision.sql
-- ============================================================

CREATE TABLE memory_space (
    memory_space_id   TEXT PRIMARY KEY NOT NULL
                      CHECK (length(memory_space_id) > 0),
    owner_user_id     TEXT NOT NULL
                      CHECK (length(owner_user_id) > 0),
    agent_id          TEXT NOT NULL
                      CHECK (length(agent_id) > 0),
    status            TEXT NOT NULL DEFAULT 'ACTIVE'
                      CHECK (status IN ('ACTIVE', 'SUSPENDED', 'TOMBSTONED')),
    policy_revision   TEXT NOT NULL
                      CHECK (length(policy_revision) > 0),
    created_at_ms     INTEGER NOT NULL
                      CHECK (created_at_ms >= 0),
    updated_at_ms     INTEGER NOT NULL
                      CHECK (updated_at_ms >= created_at_ms),

    UNIQUE (owner_user_id, agent_id)
) STRICT;

CREATE INDEX idx_memory_space_agent
    ON memory_space(agent_id);

CREATE TABLE memory_record (
    memory_id          TEXT PRIMARY KEY NOT NULL
                       CHECK (length(memory_id) > 0),
    memory_space_id    TEXT NOT NULL,
    memory_type        TEXT NOT NULL
                       CHECK (memory_type IN (
                           'EPISODIC',
                           'SEMANTIC',
                           'PROCEDURAL',
                           'PREFERENCE',
                           'LESSON'
                       )),
    lifecycle_status   TEXT NOT NULL
                       CHECK (lifecycle_status IN (
                           'ACTIVE',
                           'SUPERSEDED',
                           'CONTESTED',
                           'RETRACTED',
                           'ARCHIVED',
                           'TOMBSTONED'
                       )),
    head_revision_id   TEXT,
    created_at_ms      INTEGER NOT NULL
                       CHECK (created_at_ms >= 0),
    updated_at_ms      INTEGER NOT NULL
                       CHECK (updated_at_ms >= created_at_ms),

    UNIQUE (memory_space_id, memory_id),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_record_space_status
    ON memory_record(memory_space_id, lifecycle_status);

CREATE INDEX idx_memory_record_space_type_status
    ON memory_record(memory_space_id, memory_type, lifecycle_status);

CREATE INDEX idx_memory_record_head
    ON memory_record(head_revision_id);

CREATE TABLE memory_revision (
    revision_id         TEXT PRIMARY KEY NOT NULL
                        CHECK (length(revision_id) > 0),
    memory_space_id     TEXT NOT NULL,
    memory_id           TEXT NOT NULL,

    lifecycle_status    TEXT NOT NULL
                        CHECK (lifecycle_status IN (
                            'ACTIVE',
                            'SUPERSEDED',
                            'CONTESTED',
                            'RETRACTED',
                            'ARCHIVED',
                            'TOMBSTONED'
                        )),

    claim               TEXT NOT NULL,
    lesson              TEXT,
    rationale           TEXT,

    scope_json          TEXT NOT NULL DEFAULT '[]'
                        CHECK (
                            json_valid(scope_json)
                            AND json_type(scope_json) = 'array'
                        ),
    applicability_json  TEXT NOT NULL DEFAULT '{}'
                        CHECK (
                            json_valid(applicability_json)
                            AND json_type(applicability_json) = 'object'
                        ),
    content_json        TEXT NOT NULL
                        CHECK (
                            json_valid(content_json)
                            AND json_type(content_json) = 'object'
                        ),

    -- Deterministically constructed search fields.
    keywords_text       TEXT NOT NULL DEFAULT '',
    entity_text         TEXT NOT NULL DEFAULT '',
    scope_text          TEXT NOT NULL DEFAULT '',

    confidence          REAL
                        CHECK (
                            confidence IS NULL
                            OR (confidence >= 0.0 AND confidence <= 1.0)
                        ),
    importance          REAL
                        CHECK (
                            importance IS NULL
                            OR (importance >= 0.0 AND importance <= 1.0)
                        ),
    authority           REAL
                        CHECK (
                            authority IS NULL
                            OR (authority >= 0.0 AND authority <= 1.0)
                        ),

    sensitivity         TEXT NOT NULL DEFAULT 'PRIVATE_NORMAL'
                        CHECK (sensitivity IN (
                            'PRIVATE_NORMAL',
                            'PRIVATE_SENSITIVE',
                            'PRIVATE_PERSONAL',
                            'PRIVATE_SECRET',
                            'PRIVATE_RESTRICTED'
                        )),

    observed_at_ms      INTEGER
                        CHECK (observed_at_ms IS NULL OR observed_at_ms >= 0),
    valid_from_ms       INTEGER
                        CHECK (valid_from_ms IS NULL OR valid_from_ms >= 0),
    valid_to_ms         INTEGER
                        CHECK (valid_to_ms IS NULL OR valid_to_ms >= 0),
    recorded_at_ms      INTEGER NOT NULL
                        CHECK (recorded_at_ms >= 0),

    content_hash        TEXT NOT NULL
                        CHECK (length(content_hash) > 0),
    created_by_turn_id  TEXT,

    UNIQUE (memory_space_id, memory_id, revision_id),

    FOREIGN KEY (memory_space_id, memory_id)
        REFERENCES memory_record(memory_space_id, memory_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CHECK (
        lifecycle_status = 'TOMBSTONED'
        OR length(trim(claim)) > 0
    ),

    CHECK (
        valid_from_ms IS NULL
        OR valid_to_ms IS NULL
        OR valid_to_ms > valid_from_ms
    )
) STRICT;

CREATE INDEX idx_memory_revision_memory_time
    ON memory_revision(memory_space_id, memory_id, recorded_at_ms DESC);

CREATE INDEX idx_memory_revision_validity
    ON memory_revision(memory_space_id, valid_from_ms, valid_to_ms);

CREATE INDEX idx_memory_revision_hash
    ON memory_revision(memory_space_id, content_hash);

CREATE TABLE memory_revision_parent (
    memory_space_id    TEXT NOT NULL,
    memory_id          TEXT NOT NULL,
    revision_id        TEXT NOT NULL,
    parent_revision_id TEXT NOT NULL,

    PRIMARY KEY (revision_id, parent_revision_id),

    FOREIGN KEY (memory_space_id, memory_id, revision_id)
        REFERENCES memory_revision(memory_space_id, memory_id, revision_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    FOREIGN KEY (memory_space_id, memory_id, parent_revision_id)
        REFERENCES memory_revision(memory_space_id, memory_id, revision_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    CHECK (revision_id <> parent_revision_id)
) STRICT;

CREATE INDEX idx_memory_revision_parent_parent
    ON memory_revision_parent(memory_space_id, memory_id, parent_revision_id);

-- memory_space identity is immutable after creation.
CREATE TRIGGER trg_memory_space_identity_immutable
BEFORE UPDATE OF memory_space_id, owner_user_id, agent_id ON memory_space
FOR EACH ROW
WHEN
    NEW.memory_space_id <> OLD.memory_space_id
    OR NEW.owner_user_id <> OLD.owner_user_id
    OR NEW.agent_id <> OLD.agent_id
BEGIN
    SELECT RAISE(ABORT, 'MEMORY_SPACE_IDENTITY_IMMUTABLE');
END;

-- memory_record identity and type are immutable.
CREATE TRIGGER trg_memory_record_identity_immutable
BEFORE UPDATE OF memory_id, memory_space_id, memory_type ON memory_record
FOR EACH ROW
WHEN
    NEW.memory_id <> OLD.memory_id
    OR NEW.memory_space_id <> OLD.memory_space_id
    OR NEW.memory_type <> OLD.memory_type
BEGIN
    SELECT RAISE(ABORT, 'MEMORY_RECORD_IDENTITY_IMMUTABLE');
END;

-- A head must point to a revision belonging to the same record/space
-- and mirror that revision's current lifecycle status.
CREATE TRIGGER trg_memory_record_head_guard
BEFORE UPDATE OF head_revision_id, lifecycle_status ON memory_record
FOR EACH ROW
WHEN NEW.head_revision_id IS NOT NULL
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
              FROM memory_revision r
             WHERE r.revision_id = NEW.head_revision_id
               AND r.memory_id = NEW.memory_id
               AND r.memory_space_id = NEW.memory_space_id
               AND r.lifecycle_status = NEW.lifecycle_status
        )
        THEN RAISE(ABORT, 'MEMORY_HEAD_REVISION_MISMATCH')
    END;
END;

-- Immutable revision contract. Future physical privacy purge requires
-- an explicit privileged purge workflow/migration, not normal mutation.
CREATE TRIGGER trg_memory_revision_no_update
BEFORE UPDATE ON memory_revision
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'MEMORY_REVISION_IMMUTABLE');
END;

CREATE TRIGGER trg_memory_revision_no_delete
BEFORE DELETE ON memory_revision
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'MEMORY_REVISION_IMMUTABLE');
END;


-- ============================================================
-- M002__memory_sources_relations.sql
-- ============================================================

CREATE TABLE memory_source_ref (
    memory_space_id   TEXT NOT NULL,
    memory_id         TEXT NOT NULL,
    revision_id       TEXT NOT NULL,

    source_ref        TEXT NOT NULL
                      CHECK (length(source_ref) > 0),
    source_type       TEXT NOT NULL
                      CHECK (length(source_type) > 0),
    relation          TEXT NOT NULL
                      CHECK (relation IN (
                          'OBSERVED_IN',
                          'DERIVED_FROM',
                          'SUPPORTED_BY',
                          'VALIDATED_BY',
                          'CORRECTED_BY',
                          'INVALIDATED_BY'
                      )),

    PRIMARY KEY (revision_id, source_ref, relation),

    FOREIGN KEY (memory_space_id, memory_id, revision_id)
        REFERENCES memory_revision(memory_space_id, memory_id, revision_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_source_ref_reverse
    ON memory_source_ref(source_ref, relation);

CREATE TABLE memory_relation (
    memory_space_id    TEXT NOT NULL,
    source_memory_id   TEXT NOT NULL,
    source_revision_id TEXT NOT NULL,

    relation_type      TEXT NOT NULL
                       CHECK (relation_type IN (
                           'SUPERSEDES',
                           'CONTRADICTS',
                           'REFINES',
                           'DERIVED_FROM',
                           'SUPPORTS',
                           'APPLIES_TO',
                           'RELATED_TO',
                           'CAUSED_BY',
                           'VALIDATED_BY',
                           'INVALIDATED_BY',
                           'PROMOTED_TO',
                           'CLONED_FROM'
                       )),

    target_ref         TEXT NOT NULL
                       CHECK (length(target_ref) > 0),
    target_memory_id   TEXT,

    created_at_ms      INTEGER NOT NULL
                       CHECK (created_at_ms >= 0),

    PRIMARY KEY (
        source_revision_id,
        relation_type,
        target_ref
    ),

    FOREIGN KEY (
        memory_space_id,
        source_memory_id,
        source_revision_id
    )
        REFERENCES memory_revision(
            memory_space_id,
            memory_id,
            revision_id
        )
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    FOREIGN KEY (memory_space_id, target_memory_id)
        REFERENCES memory_record(memory_space_id, memory_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_relation_source
    ON memory_relation(
        memory_space_id,
        source_memory_id,
        source_revision_id
    );

CREATE INDEX idx_memory_relation_target_ref
    ON memory_relation(memory_space_id, target_ref);

CREATE INDEX idx_memory_relation_target_memory
    ON memory_relation(memory_space_id, target_memory_id)
    WHERE target_memory_id IS NOT NULL;


-- ============================================================
-- M003__memory_fts_current_heads.sql
-- ============================================================

CREATE VIRTUAL TABLE memory_fts USING fts5(
    memory_id       UNINDEXED,
    memory_space_id UNINDEXED,
    revision_id     UNINDEXED,

    claim,
    lesson,
    keywords,
    entity_text,
    scope_text,

    tokenize = 'unicode61 remove_diacritics 2'
);

-- Current-head view. This is convenient for deterministic reads and
-- recovery checks. Do not expose it directly to Runtime/LLM.
CREATE VIEW memory_current_head AS
SELECT
    mr.memory_id,
    mr.memory_space_id,
    mr.memory_type,
    mr.lifecycle_status,
    mr.head_revision_id,
    rv.claim,
    rv.lesson,
    rv.rationale,
    rv.scope_json,
    rv.applicability_json,
    rv.content_json,
    rv.keywords_text,
    rv.entity_text,
    rv.scope_text,
    rv.confidence,
    rv.importance,
    rv.authority,
    rv.sensitivity,
    rv.observed_at_ms,
    rv.valid_from_ms,
    rv.valid_to_ms,
    rv.recorded_at_ms,
    rv.content_hash
FROM memory_record mr
JOIN memory_revision rv
  ON rv.revision_id = mr.head_revision_id
 AND rv.memory_id = mr.memory_id
 AND rv.memory_space_id = mr.memory_space_id;

-- FTS is a current searchable-head projection. It is kept transactionally
-- aligned with head changes, while remaining fully rebuildable.
CREATE TRIGGER trg_memory_record_fts_after_head_update
AFTER UPDATE OF head_revision_id, lifecycle_status ON memory_record
FOR EACH ROW
BEGIN
    DELETE FROM memory_fts
     WHERE memory_id = NEW.memory_id;

    INSERT INTO memory_fts(
        memory_id,
        memory_space_id,
        revision_id,
        claim,
        lesson,
        keywords,
        entity_text,
        scope_text
    )
    SELECT
        NEW.memory_id,
        NEW.memory_space_id,
        r.revision_id,
        r.claim,
        COALESCE(r.lesson, ''),
        r.keywords_text,
        r.entity_text,
        r.scope_text
      FROM memory_revision r
     WHERE r.revision_id = NEW.head_revision_id
       AND r.memory_id = NEW.memory_id
       AND r.memory_space_id = NEW.memory_space_id
       AND NEW.lifecycle_status IN ('ACTIVE', 'CONTESTED');
END;


-- ============================================================
-- M004__memory_core_capture_receipts.sql
-- ============================================================

CREATE TABLE memory_candidate (
    candidate_id          TEXT PRIMARY KEY NOT NULL,
    memory_space_id       TEXT NOT NULL,

    capture_signal        TEXT NOT NULL
                          CHECK (capture_signal IN (
                              'EXPLICIT_USER_MEMORY',
                              'EXPLICIT_USER_CORRECTION',
                              'VERIFIED_FAILURE_REPAIR',
                              'VERIFIED_TASK_OUTCOME',
                              'MANUAL_MEMORY_SAVE'
                          )),

    candidate_memory_type TEXT
                          CHECK (
                              candidate_memory_type IS NULL
                              OR candidate_memory_type IN (
                                  'EPISODIC',
                                  'SEMANTIC',
                                  'PROCEDURAL',
                                  'PREFERENCE',
                                  'LESSON'
                              )
                          ),

    payload_json          TEXT NOT NULL
                          CHECK (
                              json_valid(payload_json)
                              AND json_type(payload_json) = 'object'
                          ),
    source_turn_id        TEXT,
    source_refs_json      TEXT NOT NULL DEFAULT '[]'
                          CHECK (
                              json_valid(source_refs_json)
                              AND json_type(source_refs_json) = 'array'
                          ),

    confidence_hint       REAL
                          CHECK (
                              confidence_hint IS NULL
                              OR (
                                  confidence_hint >= 0.0
                                  AND confidence_hint <= 1.0
                              )
                          ),
    importance_hint       REAL
                          CHECK (
                              importance_hint IS NULL
                              OR (
                                  importance_hint >= 0.0
                                  AND importance_hint <= 1.0
                              )
                          ),
    sensitivity           TEXT NOT NULL DEFAULT 'PRIVATE_NORMAL'
                          CHECK (sensitivity IN (
                              'PRIVATE_NORMAL',
                              'PRIVATE_SENSITIVE',
                              'PRIVATE_PERSONAL',
                              'PRIVATE_SECRET',
                              'PRIVATE_RESTRICTED'
                          )),

    status                TEXT NOT NULL
                          CHECK (status IN (
                              'INBOX',
                              'DEFER',
                              'COMMITTED',
                              'DROPPED'
                          )),
    disposition_reason    TEXT,

    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),
    resolved_at_ms        INTEGER
                          CHECK (resolved_at_ms IS NULL OR resolved_at_ms >= created_at_ms),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_candidate_queue
    ON memory_candidate(memory_space_id, status, created_at_ms);

CREATE TABLE memory_core_snapshot (
    memory_space_id       TEXT PRIMARY KEY NOT NULL,
    core_revision         INTEGER NOT NULL
                          CHECK (core_revision >= 1),

    content_json          TEXT NOT NULL
                          CHECK (
                              json_valid(content_json)
                              AND json_type(content_json) = 'object'
                              AND length(CAST(content_json AS BLOB)) <= 12288
                          ),

    entry_count           INTEGER NOT NULL
                          CHECK (entry_count >= 0 AND entry_count <= 24),
    estimated_tokens      INTEGER NOT NULL
                          CHECK (estimated_tokens >= 0 AND estimated_tokens <= 1024),

    source_hash           TEXT NOT NULL
                          CHECK (length(source_hash) > 0),
    policy_revision       TEXT NOT NULL
                          CHECK (length(policy_revision) > 0),

    dirty                 INTEGER NOT NULL DEFAULT 0
                          CHECK (dirty IN (0, 1)),

    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),
    updated_at_ms         INTEGER NOT NULL
                          CHECK (updated_at_ms >= created_at_ms),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE TABLE memory_access_stat (
    memory_space_id       TEXT NOT NULL,
    memory_id             TEXT NOT NULL,

    retrieved_count       INTEGER NOT NULL DEFAULT 0
                          CHECK (retrieved_count >= 0),
    selected_count        INTEGER NOT NULL DEFAULT 0
                          CHECK (selected_count >= 0),
    materialized_count    INTEGER NOT NULL DEFAULT 0
                          CHECK (materialized_count >= 0),
    runtime_ref_count     INTEGER NOT NULL DEFAULT 0
                          CHECK (runtime_ref_count >= 0),
    user_confirmed_count  INTEGER NOT NULL DEFAULT 0
                          CHECK (user_confirmed_count >= 0),
    user_rejected_count   INTEGER NOT NULL DEFAULT 0
                          CHECK (user_rejected_count >= 0),

    last_retrieved_at_ms  INTEGER,
    last_materialized_at_ms INTEGER,
    last_feedback_at_ms   INTEGER,

    PRIMARY KEY (memory_space_id, memory_id),

    FOREIGN KEY (memory_space_id, memory_id)
        REFERENCES memory_record(memory_space_id, memory_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE TABLE memory_turn_receipt (
    receipt_id            TEXT PRIMARY KEY NOT NULL,
    trace_id              TEXT NOT NULL,
    turn_id               TEXT NOT NULL,
    agent_id              TEXT NOT NULL,
    memory_space_id       TEXT NOT NULL,

    stage                 TEXT NOT NULL
                          CHECK (stage IN (
                              'STARTED',
                              'BEFORE_READY',
                              'COMPLETED',
                              'FAILED'
                          )),

    core_revision         INTEGER,
    query_plan_json       TEXT NOT NULL DEFAULT '{}'
                          CHECK (
                              json_valid(query_plan_json)
                              AND json_type(query_plan_json) = 'object'
                          ),
    selected_refs_json    TEXT NOT NULL DEFAULT '[]'
                          CHECK (
                              json_valid(selected_refs_json)
                              AND json_type(selected_refs_json) = 'array'
                          ),

    selected_count        INTEGER NOT NULL DEFAULT 0
                          CHECK (selected_count >= 0),
    estimated_tokens      INTEGER NOT NULL DEFAULT 0
                          CHECK (estimated_tokens >= 0),

    deep_recall_used      INTEGER NOT NULL DEFAULT 0
                          CHECK (deep_recall_used IN (0, 1)),
    degraded              INTEGER NOT NULL DEFAULT 0
                          CHECK (degraded IN (0, 1)),
    degraded_reason       TEXT,

    policy_revision       TEXT NOT NULL,

    started_at_ms         INTEGER NOT NULL
                          CHECK (started_at_ms >= 0),
    before_ready_at_ms    INTEGER,
    completed_at_ms       INTEGER,

    UNIQUE (turn_id, agent_id),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_turn_receipt_space_time
    ON memory_turn_receipt(memory_space_id, started_at_ms DESC);

CREATE TABLE memory_capture_receipt (
    receipt_id            TEXT PRIMARY KEY NOT NULL,
    trace_id              TEXT NOT NULL,
    turn_id               TEXT NOT NULL,
    agent_id              TEXT NOT NULL,
    memory_space_id       TEXT NOT NULL,

    capture_signal        TEXT,
    gate_decision         TEXT NOT NULL
                          CHECK (gate_decision IN (
                              'NO_CAPTURE',
                              'CANDIDATE',
                              'DEFER',
                              'DROP'
                          )),

    candidate_id          TEXT,
    committed_memory_id   TEXT,
    committed_revision_id TEXT,
    reason_code           TEXT NOT NULL,

    policy_revision       TEXT NOT NULL,

    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),
    completed_at_ms       INTEGER
                          CHECK (
                              completed_at_ms IS NULL
                              OR completed_at_ms >= created_at_ms
                          ),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT,

    FOREIGN KEY (candidate_id)
        REFERENCES memory_candidate(candidate_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_capture_receipt_turn
    ON memory_capture_receipt(turn_id, agent_id);

CREATE TABLE memory_use (
    use_id                TEXT PRIMARY KEY NOT NULL,
    turn_id               TEXT NOT NULL,
    memory_space_id       TEXT NOT NULL,
    memory_id             TEXT NOT NULL,
    revision_id           TEXT NOT NULL,

    disposition           TEXT NOT NULL
                          CHECK (disposition IN (
                              'RETRIEVED',
                              'SELECTED',
                              'MATERIALIZED',
                              'REF_ONLY',
                              'RUNTIME_REFERENCED',
                              'TOKEN_EVICTED',
                              'RANKED_OUT',
                              'CONFLICT_SUPPRESSED',
                              'USER_CONFIRMED',
                              'USER_REJECTED'
                          )),

    rank_position         INTEGER
                          CHECK (rank_position IS NULL OR rank_position >= 1),
    estimated_tokens      INTEGER
                          CHECK (
                              estimated_tokens IS NULL
                              OR estimated_tokens >= 0
                          ),
    score_json            TEXT NOT NULL DEFAULT '{}'
                          CHECK (
                              json_valid(score_json)
                              AND json_type(score_json) = 'object'
                          ),

    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),

    UNIQUE (turn_id, revision_id, disposition),

    FOREIGN KEY (memory_space_id, memory_id, revision_id)
        REFERENCES memory_revision(memory_space_id, memory_id, revision_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_use_turn
    ON memory_use(turn_id, disposition, rank_position);

CREATE INDEX idx_memory_use_memory
    ON memory_use(memory_space_id, memory_id, created_at_ms DESC);


-- ============================================================
-- M005__memory_outbox_projection_recovery.sql
-- ============================================================

CREATE TABLE memory_outbox (
    outbox_id             TEXT PRIMARY KEY NOT NULL,
    memory_space_id       TEXT,
    kind                  TEXT NOT NULL
                          CHECK (length(kind) > 0),
    aggregate_ref         TEXT,
    payload_json          TEXT NOT NULL
                          CHECK (
                              json_valid(payload_json)
                              AND json_type(payload_json) = 'object'
                          ),
    idempotency_key       TEXT NOT NULL UNIQUE,

    status                TEXT NOT NULL DEFAULT 'PENDING'
                          CHECK (status IN (
                              'PENDING',
                              'IN_FLIGHT',
                              'ACKED',
                              'FAILED'
                          )),
    attempt_count         INTEGER NOT NULL DEFAULT 0
                          CHECK (attempt_count >= 0),

    available_at_ms       INTEGER NOT NULL
                          CHECK (available_at_ms >= 0),
    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),
    updated_at_ms         INTEGER NOT NULL
                          CHECK (updated_at_ms >= created_at_ms),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_outbox_ready
    ON memory_outbox(status, available_at_ms);

CREATE TABLE memory_job (
    job_id                TEXT PRIMARY KEY NOT NULL,
    memory_space_id       TEXT,

    job_type              TEXT NOT NULL
                          CHECK (length(job_type) > 0),
    idempotency_key       TEXT NOT NULL UNIQUE,

    source_ref            TEXT,
    source_revision_id    TEXT,
    source_hash           TEXT,

    payload_json          TEXT NOT NULL DEFAULT '{}'
                          CHECK (
                              json_valid(payload_json)
                              AND json_type(payload_json) = 'object'
                          ),

    status                TEXT NOT NULL DEFAULT 'PENDING'
                          CHECK (status IN (
                              'PENDING',
                              'RUNNING',
                              'DONE',
                              'FAILED',
                              'CANCELLED'
                          )),
    attempt_count         INTEGER NOT NULL DEFAULT 0
                          CHECK (attempt_count >= 0),

    available_at_ms       INTEGER NOT NULL
                          CHECK (available_at_ms >= 0),
    created_at_ms         INTEGER NOT NULL
                          CHECK (created_at_ms >= 0),
    updated_at_ms         INTEGER NOT NULL
                          CHECK (updated_at_ms >= created_at_ms),

    last_error_code       TEXT,
    last_error_message    TEXT,

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_job_ready
    ON memory_job(status, available_at_ms);

CREATE TABLE memory_projection_state (
    memory_space_id       TEXT NOT NULL,
    projection_type       TEXT NOT NULL
                          CHECK (length(projection_type) > 0),

    status                TEXT NOT NULL
                          CHECK (status IN (
                              'CLEAN',
                              'DIRTY',
                              'REBUILDING',
                              'FAILED'
                          )),

    source_marker         TEXT,
    last_error_code       TEXT,
    last_error_message    TEXT,

    updated_at_ms         INTEGER NOT NULL
                          CHECK (updated_at_ms >= 0),

    PRIMARY KEY (memory_space_id, projection_type),

    FOREIGN KEY (memory_space_id)
        REFERENCES memory_space(memory_space_id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
) STRICT;

CREATE INDEX idx_memory_projection_state_status
    ON memory_projection_state(status, projection_type);


-- ============================================================
-- Recovery / rebuild statements (application-owned, not triggers)
-- ============================================================

-- Rebuild all current searchable heads for one MemorySpace:
--   1. DELETE FROM memory_fts WHERE memory_space_id = ?1;
--   2. INSERT rows from memory_current_head where lifecycle_status
--      IN ('ACTIVE', 'CONTESTED').
--
-- Canonical memory_revision rows must never be rebuilt from FTS.
-- FTS is disposable projection state.

```

## 51.5 DDL Invariants

由 DB + Domain 双重保证：

```text
one owner/user + agent
→ one writable MemorySpace

Memory record identity/type
→ immutable

Memory revision
→ immutable

record.head_revision
→ same memory_id
→ same memory_space_id
→ same lifecycle status

internal target_memory relation
→ cannot cross MemorySpace

normal FTS
→ current searchable head only

Core
→ <= 24 entries
→ <= 1024 estimated tokens
→ <= 12 KiB serialized projection
```

Revision DAG 的“无环”仍由 Domain 在写入 parent edge 时验证；SQLite CHECK/FK 不尝试实现递归 DAG cycle detection。

## 51.6 FTS5 Security Boundary

FTS5 是共享物理索引，但所有 Workbench Recall API 都必须把：

```text
memory_space_id
```

作为不可省略的 Kernel-bound 查询条件。

Runtime/LLM 永远不能直接执行 FTS SQL。

Cross-Agent FTS 返回属于 Hard Release Blocker。

FTS 排名统计可以跨物理表产生，但返回行必须经过 exact MemorySpace filter；任何 future optimization 不得用“性能”理由放宽 Namespace Gate。

## 51.7 Rust API Contract

Developer-facing standalone companion 同时生成：

`MEMORY_MVP_RUST_API_FREEZE_V1.md`

其冻结内容如下：

# Memory MVP Rust API Freeze V1

This is the Q24/V3.10 developer-facing API contract. It freezes semantic
boundaries, not the project's choice of SQLite crate/ORM/threading wrapper.

## ID and enum rules

All IDs are opaque strings at persistence boundaries and strongly typed
newtypes in Rust.

```rust
pub struct MemorySpaceId(pub String);
pub struct MemoryId(pub String);
pub struct MemoryRevisionId(pub String);
pub struct MemoryReceiptId(pub String);
pub struct MemoryCandidateId(pub String);
pub struct MemoryUseId(pub String);

pub enum MemoryType {
    Episodic,
    Semantic,
    Procedural,
    Preference,
    Lesson,
}

pub enum MemoryLifecycleStatus {
    Active,
    Superseded,
    Contested,
    Retracted,
    Archived,
    Tombstoned,
}

pub enum TemporalMode {
    Current,
    AsOf { timestamp_ms: i64 },
    HistoricalRange { from_ms: i64, to_ms: i64 },
}

pub enum MemoryUseDisposition {
    Retrieved,
    Selected,
    Materialized,
    RefOnly,
    RuntimeReferenced,
    TokenEvicted,
    RankedOut,
    ConflictSuppressed,
    UserConfirmed,
    UserRejected,
}
```

## Runtime-safe MemoryRef

Runtime-visible references do not carry a user-selectable `agent_id` or
`memory_space_id`.

```rust
pub struct MemoryRef {
    pub memory_id: MemoryId,
    pub revision_id: MemoryRevisionId,
}
```

The Memory Kernel resolves and verifies the current bound MemorySpace.

## MemoryQueryPlan

```rust
pub struct MemoryQueryPlan {
    pub plan_version: u32,
    pub turn_id: String,
    pub agent_id: String,

    // Kernel-generated. Runtime cannot override it.
    pub memory_space_id: MemorySpaceId,

    pub lexical_terms: Vec<String>,
    pub memory_types: Vec<MemoryType>,
    pub temporal_mode: TemporalMode,
    pub anchors: MemoryQueryAnchors,

    pub max_items: u16,
    pub token_budget: u32,
    pub allow_search_more: bool,

    pub policy_revision: String,
}

pub struct MemoryQueryAnchors {
    pub project_id: Option<String>,
    pub work_item_id: Option<String>,
    pub mission_id: Option<String>,
    pub room_id: Option<String>,
    pub resource_refs: Vec<String>,
}
```

MVP query planning is deterministic. No query-rewriter model is invoked.

## MemoryCapsule

```rust
pub struct MemoryCapsule {
    pub memory_ref: MemoryRef,
    pub memory_type: MemoryType,

    pub claim: String,
    pub lesson: Option<String>,
    pub scope: Vec<String>,

    pub lifecycle_status: MemoryLifecycleStatus,
    pub valid_from_ms: Option<i64>,
    pub valid_to_ms: Option<i64>,

    pub evidence_refs: Vec<String>, // max 3 in normal materialization
    pub expand_ref: String,

    pub estimated_tokens: u32,
}
```

Normal target: 60-150 estimated tokens. Hard packing is governed by the
turn's Memory token budget, not by corpus size.

## beforeTurnMemory

```rust
pub struct BeforeTurnMemoryInput {
    pub turn_id: String,
    pub agent_id: String,
    pub conversation_id: String,
    pub surface: String,

    pub project_id: Option<String>,
    pub work_item_id: Option<String>,
    pub mission_id: Option<String>,
    pub room_id: Option<String>,

    pub user_text: String,
    pub resource_refs: Vec<String>,
    pub conversation_delta_refs: Vec<String>,

    pub context_profile: String,
    pub memory_token_budget: u32,
    pub egress_context: String,
}

pub struct BeforeTurnMemoryOutput {
    pub receipt_id: MemoryReceiptId,
    pub memory_space_id: MemorySpaceId,

    pub core: Option<CoreMemoryMaterialization>,
    pub query_plan: MemoryQueryPlan,
    pub selected_capsules: Vec<MemoryCapsule>,

    pub expansion: MemoryExpansionCapabilities,
    pub degraded: bool,
    pub degraded_reasons: Vec<MemoryDegradedReason>,
}

pub struct CoreMemoryMaterialization {
    pub core_revision: u64,
    pub content_json: String,
    pub estimated_tokens: u32,
}

pub struct MemoryExpansionCapabilities {
    pub search_more: bool,
    pub read: bool,
    pub trace: bool,
}
```

Coordinator-facing service signature:

```rust
impl MemoryService {
    pub async fn before_turn_memory(
        &self,
        input: BeforeTurnMemoryInput,
    ) -> Result<BeforeTurnMemoryOutput, MemoryError>;
}
```

The caller supplies `agent_id`; the caller never supplies
`memory_space_id`.

## Materialization receipt boundary

`before_turn_memory()` selects candidates. The Context Broker decides which
ones are actually placed in the Runtime context. That decision must be
recorded before Runtime dispatch.

```rust
pub struct MemoryMaterializationOutcome {
    pub receipt_id: MemoryReceiptId,
    pub materialized: Vec<MemoryRef>,
    pub ref_only: Vec<MemoryRef>,
    pub token_evicted: Vec<MemoryRef>,
    pub total_memory_tokens: u32,
}

impl MemoryService {
    pub async fn record_materialization(
        &self,
        outcome: MemoryMaterializationOutcome,
    ) -> Result<(), MemoryError>;
}
```

This is the authoritative distinction between SELECTED and MATERIALIZED.

## Runtime tools

```rust
pub struct MemorySearchMoreInput {
    pub turn_id: String,
    pub query: String,
    pub memory_types: Vec<MemoryType>,
    pub temporal_mode: Option<TemporalMode>,
    pub max_items: u16,
    pub token_budget: u32,
}

pub struct MemorySearchMoreOutput {
    pub capsules: Vec<MemoryCapsule>,
    pub degraded: bool,
}

pub struct MemoryReadInput {
    pub turn_id: String,
    pub memory_ref: MemoryRef,
}

pub struct MemoryReadOutput {
    pub memory_ref: MemoryRef,
    pub content_json: String,
    pub evidence_refs: Vec<String>,
    pub relations: Vec<String>,
}

impl MemoryService {
    pub async fn search_more(
        &self,
        current_agent_id: &str,
        input: MemorySearchMoreInput,
    ) -> Result<MemorySearchMoreOutput, MemoryError>;

    pub async fn read(
        &self,
        current_agent_id: &str,
        input: MemoryReadInput,
    ) -> Result<MemoryReadOutput, MemoryError>;
}
```

There is intentionally no Runtime-facing `agent_id`, `memory_space_id`,
SQL, table name, or arbitrary target namespace field inside the tool input.

## afterTurnMemory

```rust
pub enum CaptureSignal {
    ExplicitUserMemory,
    ExplicitUserCorrection,
    VerifiedFailureRepair,
    VerifiedTaskOutcome,
    ManualMemorySave,
}

pub enum CaptureGateDecision {
    NoCapture,
    Candidate,
    Defer,
    Drop,
}

pub struct AfterTurnMemoryInput {
    pub turn_id: String,
    pub agent_id: String,

    pub user_turn_ref: String,
    pub assistant_turn_ref: String,

    pub tool_result_refs: Vec<String>,
    pub workspace_change_refs: Vec<String>,
    pub decision_refs: Vec<String>,
    pub review_refs: Vec<String>,

    pub outcome: String,
    pub explicit_memory_intent: Option<String>,
    pub runtime_memory_hints: Vec<String>,
}

pub struct AfterTurnMemoryOutput {
    pub capture_receipt_id: MemoryReceiptId,
    pub gate_decision: CaptureGateDecision,
    pub candidate_id: Option<MemoryCandidateId>,
    pub committed_memory: Option<MemoryRef>,
}

impl MemoryService {
    pub async fn after_turn_memory(
        &self,
        input: AfterTurnMemoryInput,
    ) -> Result<AfterTurnMemoryOutput, MemoryError>;
}
```

Runtime hints are proposals only. They cannot choose namespace, canonical
owner, lifecycle transition, or final commit.

## Repository/domain boundary

The Workbench's existing SQLite access layer remains the DB execution
mechanism. Q24 freezes these semantics:

```rust
pub trait MemoryReadStore {
    fn resolve_memory_space(
        &self,
        owner_user_id: &str,
        agent_id: &str,
    ) -> Result<MemorySpaceId, MemoryError>;

    fn load_current_head(
        &self,
        memory_space_id: &MemorySpaceId,
        memory_id: &MemoryId,
    ) -> Result<Option<CanonicalMemoryHead>, MemoryError>;

    fn search_current_fts(
        &self,
        memory_space_id: &MemorySpaceId,
        query: &str,
        max_candidates: u16,
    ) -> Result<Vec<RecallCandidate>, MemoryError>;

    fn load_current_relations(
        &self,
        memory_space_id: &MemorySpaceId,
        refs: &[MemoryRef],
    ) -> Result<Vec<MemoryRelationView>, MemoryError>;
}

pub trait MemoryWriteTx: MemoryReadStore {
    fn insert_record(&mut self, record: &NewMemoryRecord)
        -> Result<(), MemoryError>;

    fn insert_revision(&mut self, revision: &NewMemoryRevision)
        -> Result<(), MemoryError>;

    fn insert_revision_parents(
        &mut self,
        child: &MemoryRevisionId,
        parents: &[MemoryRevisionId],
    ) -> Result<(), MemoryError>;

    fn insert_source_refs(
        &mut self,
        refs: &[NewMemorySourceRef],
    ) -> Result<(), MemoryError>;

    fn insert_relations(
        &mut self,
        relations: &[NewMemoryRelation],
    ) -> Result<(), MemoryError>;

    fn set_current_head(
        &mut self,
        memory_id: &MemoryId,
        revision_id: &MemoryRevisionId,
        lifecycle: MemoryLifecycleStatus,
    ) -> Result<(), MemoryError>;

    fn mark_core_dirty(
        &mut self,
        memory_space_id: &MemorySpaceId,
    ) -> Result<(), MemoryError>;

    fn append_memory_event_and_receipt(
        &mut self,
        event: &MemorySemanticEvent,
        receipt: &MemoryMutationReceipt,
    ) -> Result<(), MemoryError>;
}
```

A semantic memory mutation is one Workbench write transaction. It is never
split into a "memory DB commit" and a later "event/receipt commit".

## Transaction boundaries

### T1 — Create/revise/correct/tombstone canonical memory

One write transaction:

```text
resolve/verify MemorySpace
→ insert stable record when new
→ insert immutable revision
→ insert parent lineage
→ insert source refs / relations
→ update current head + lifecycle mirror
→ FTS trigger updates current projection
→ mark Core dirty when eligible
→ append Semantic Event
→ append mutation/capture Receipt
→ enqueue durable outbox/job intent when needed
→ COMMIT
```

Any failure rolls back the whole semantic mutation.

### T2 — beforeTurnMemory

```text
ensure Core current (short deterministic write tx if dirty)
→ consistent read transaction for current heads / FTS / relation
→ rank / dedup / pack outside canonical mutation
→ short receipt write transaction
→ return selected Capsules
```

Exact immutable revision IDs selected during the read snapshot are stored in
the Receipt.

### T3 — Context materialization

Short write transaction before Runtime dispatch:

```text
SELECTED
→ MATERIALIZED / REF_ONLY / TOKEN_EVICTED
```

This records what the model actually received.

### T4 — Runtime memory tools

Each `search_more()` / `read()` performs a namespace-bound read and a short
`memory_use`/receipt write. Tool reads never mutate canonical memory.

### T5 — afterTurnMemory

Capture Gate is deterministic. `NO_CAPTURE` writes only a CaptureReceipt.
If a candidate or canonical correction/save is produced, candidate and
canonical mutation are committed through the same Workbench transaction
rules as T1.

## Error taxonomy

```rust
pub enum MemoryErrorCode {
    MemorySpaceNotFound,
    MemoryNotFound,
    RevisionNotFound,

    NamespaceDenied,
    CrossSpaceReferenceDenied,
    PolicyDenied,
    EgressDenied,

    Tombstoned,
    InvalidLifecycleTransition,
    HeadRevisionMismatch,
    CorruptInvariant,

    ProjectionDirty,
    ProjectionUnavailable,

    StorageBusy,
    StorageIo,
    Serialization,
    UnsupportedSchemaVersion,
}

pub enum MemoryFailureClass {
    UserInput,
    Degradable,
    Retryable,
    HardSecurity,
    HardIntegrity,
}
```

Required behavior:

- `NamespaceDenied`, `CrossSpaceReferenceDenied` -> fail closed, security
  receipt, no cross-Agent fallback.
- `HeadRevisionMismatch`, `CorruptInvariant` -> fail closed; normal Agent
  turn is blocked until recovery/repair.
- `ProjectionDirty`, `ProjectionUnavailable` -> rebuild or use a documented
  deterministic degraded path; never switch namespace or invent memory.
- `MemoryNotFound`, `RevisionNotFound`, `Tombstoned` from a Runtime tool ->
  bounded tool error; the current turn may continue without that memory.
- Token pressure is not an integrity error. It produces
  `TOKEN_EVICTED`/`REF_ONLY`, not a hidden truncation.

## Migration naming freeze

```text
M001__memory_identity_revision.sql
M002__memory_sources_relations.sql
M003__memory_fts_current_heads.sql
M004__memory_core_capture_receipts.sql
M005__memory_outbox_projection_recovery.sql
```

If the main Workbench repository uses a global numeric migration sequence,
preserve these exact suffixes and map them onto the next global numbers.

## FakeRuntime contract

FakeRuntime consumes the exact `ContextPackage` and emits a deterministic
scripted event stream.

```rust
pub struct FakeRuntimeScript {
    pub assert_materialized_memory: Vec<MemoryRef>,
    pub tool_calls: Vec<FakeToolCall>,
    pub runtime_memory_hints: Vec<String>,
    pub final_text: String,
}
```

It must be able to:

1. assert exact Memory revision refs present/absent;
2. call `memory.search_more`;
3. call `memory.read`;
4. emit a memory proposal/hint;
5. complete without network or model calls;
6. simulate interruption before/after canonical commits.

## First acceptance-test freeze

- `MEM-GP-001 explicit_remember_survives_restart`
- `MEM-GP-002 correction_supersedes_old_current_truth`
- `MEM-GP-003 agent_namespace_isolation_is_fail_closed`
- `MEM-GP-004 tombstone_disappears_from_current_recall`
- `MEM-GP-005 token_budget_keeps_context_bounded`
- `MEM-GP-006 zero_relevant_memory_is_valid_and_receipted`
- `MEM-GP-007 current_fts_never_returns_old_head_as_current`
- `MEM-GP-008 materialization_receipt_matches_runtime_context`
- `MEM-GP-009 core_hard_limits_are_enforced`
- `MEM-GP-010 committed_memory_survives_process_restart`

Every test above runs with zero extra model calls.


## 51.8 Canonical Mutation Boundary

任何产生新的 Canonical Memory Truth 的动作：

```text
manual remember
explicit remember
correction
verified outcome commit
supersede
retract
tombstone
```

都必须通过单个 Workbench write transaction。

禁止：

```text
commit Memory revision
↓
later commit event

or

commit event
↓
later commit Memory revision
```

Semantic State + Event + Receipt 必须原子一致。

## 51.9 Read/Receipt Boundary

Recall 本身使用 consistent read snapshot；选中的 Revision 是 immutable，因此即使随后另一个 Turn 创建新 Head，本 Turn Receipt 仍精确记录实际选中的 Revision。

`SELECTED` 与 `MATERIALIZED` 必须分开：

```text
Memory Kernel selects
↓
Context Broker arbitrates
↓
record_materialization()
↓
Runtime dispatch
```

只有 MATERIALIZED 才表示模型真正收到正文。

## 51.10 Core Dirty Rule

如果 Core 被标记 DIRTY：

```text
beforeTurnMemory
→ ensure_core_current()
```

必须在正常 Runtime dispatch 前处理。

优先：

```text
deterministic rebuild
```

如果 Canonical Memory 可读但 Core projection 写入失败，可使用同一 deterministic builder 产生本 Turn 临时 Core，并记录 degraded + Core projection repair job。

如果 Canonical/ownership invariant 本身损坏：

```text
FAIL CLOSED
```

不得用空 Core 偷偷继续。

## 51.11 FTS Rebuild Rule

FTS 永远是 disposable Projection。

Recovery 可以：

```text
DELETE affected MemorySpace FTS rows
↓
reinsert current ACTIVE/CONTESTED heads
```

但绝对禁止：

```text
FTS
→ reconstruct Canonical Memory
```

投影只能从 Canonical Truth 重建，方向不可逆。

## 51.12 Capture MVP Contract

Capture Gate 不调用额外模型。

第一阶段 only：

```text
EXPLICIT_USER_MEMORY
EXPLICIT_USER_CORRECTION
VERIFIED_FAILURE_REPAIR
VERIFIED_TASK_OUTCOME
MANUAL_MEMORY_SAVE
```

如果输入不满足确定性规则：

```text
NO_CAPTURE
or
DEFER
```

不为了“多学习”猜测生成长期 Memory。

## 51.13 Runtime Tool Namespace Contract

Runtime-visible：

```text
memory.search_more
memory.read
memory.trace
```

只能在当前 Agent 的 Kernel-bound MemorySpace 内运行。

Tool schema 中禁止出现：

```text
target_agent_id
memory_space_id
database_path
sql
table
```

这是结构性安全约束，而不是 prompt instruction。

## 51.14 Error / Degradation Contract

Hard Security：

```text
NamespaceDenied
CrossSpaceReferenceDenied
```

Hard Integrity：

```text
HeadRevisionMismatch
CorruptInvariant
UnsupportedSchemaVersion
```

以上 fail closed。

Degradable：

```text
ProjectionDirty
ProjectionUnavailable
```

允许明确降级，但必须 Receipt。

Runtime-local read problem：

```text
MemoryNotFound
RevisionNotFound
Tombstoned
```

返回 bounded tool error，不自动换成其它 Agent / Historical Revision。

## 51.15 Migration Freeze

正式 Migration：

```text
M001__memory_identity_revision.sql
M002__memory_sources_relations.sql
M003__memory_fts_current_heads.sql
M004__memory_core_capture_receipts.sql
M005__memory_outbox_projection_recovery.sql
```

每个 migration 必须至少有：

```text
empty DB apply
existing previous migration upgrade
restart
foreign_key_check
integrity_check
fixture round-trip
```

禁止在首个 migration 放所有未来 Cluster/Vector/Graph 表。

## 51.16 Phase A First Coding Order

Q24 完成后第一批开发 Issue 应按：

```text
A1 Migration runner + M001
A2 Rust newtypes/enums
A3 MemorySpace create/resolve
A4 Stable Record + Revision transaction
A5 head/revision invariant tests
A6 M002 SourceRef/Relation
A7 tombstone/retract/supersede transitions
A8 Recovery invariant checker
```

然后才进入 Phase B FTS/Recall。

## 51.17 First Acceptance Tests

正式锁定：

```text
MEM-GP-001 explicit_remember_survives_restart
MEM-GP-002 correction_supersedes_old_current_truth
MEM-GP-003 agent_namespace_isolation_is_fail_closed
MEM-GP-004 tombstone_disappears_from_current_recall
MEM-GP-005 token_budget_keeps_context_bounded
MEM-GP-006 zero_relevant_memory_is_valid_and_receipted
MEM-GP-007 current_fts_never_returns_old_head_as_current
MEM-GP-008 materialization_receipt_matches_runtime_context
MEM-GP-009 core_hard_limits_are_enforced
MEM-GP-010 committed_memory_survives_process_restart
```

全部：

```text
extra model calls = 0
network = 0
```

`MEM-GP-003` 任意一次跨 Agent 成功读取即 Hard Fail。

## 51.18 Definition of Ready for Development

Q24 之后，Memory MVP 满足：

```text
Architecture Ready       YES
Canonical Schema Ready   YES
Domain API Ready         YES
Transaction Rules Ready  YES
Migration Plan Ready     YES
Test Contract Ready      YES
Extra Model Purchase     NO
```

因此：

> **下一步不是 Q25 架构讨论，而是 Phase A Implementation。**

只有以下情况允许重新打开 Q24：

```text
DDL 无法表达已接受 invariant
existing Workbench DB transaction API 与 Contract 硬冲突
security test 证明 Namespace Gate 不充分
recovery test 证明 immutable/head model 存在不可修复缺陷
```

普通命名、代码组织、UI 偏好、优化不构成重新打开架构冻结的理由。

## 51.19 Accepted Decisions

### D-MEM-191 — Q24 Freezes the MVP Engineering Contract

SQLite Schema、Rust Domain API、Transaction Boundary、Error Taxonomy、Migration 与 Golden Tests 从 v3.10 起视为开发基线；后续默认通过 Issue/ADR 小范围修订，而不是重新进行整体 Memory 架构设计。

### D-MEM-192 — Memory MVP Uses Strict SQLite Contracts

MVP 要求 SQLite Foreign Key、FTS5、JSON、STRICT table 与 WAL-compatible execution；Memory 数据继续位于 Workbench 单一 Canonical SQLite。

### D-MEM-193 — Memory IDs Are Opaque and Strongly Typed in Rust

Persistence 使用 opaque TEXT ID，Rust Domain 使用 MemorySpaceId/MemoryId/RevisionId 等 newtype；Runtime 不得通过裸字符串自行构造目标 Namespace。

### D-MEM-194 — Current Head Is a Guarded Pointer to an Immutable Revision

`memory_record.head_revision_id` 只能指向同 MemorySpace、同 Memory、同 lifecycle mirror 的 immutable Revision；Revision 正常路径禁止 UPDATE/DELETE。

### D-MEM-195 — Revision Parent Schema Is DAG-ready From MVP

MVP 即使用独立 `memory_revision_parent`，单机通常只有一个 Parent，但无需未来为 Multi-device Concurrent Revision 重做 Canonical Schema；Cycle Validation 属于 Domain。

### D-MEM-196 — FTS5 Is a Current-head Projection Maintained With Canonical Mutations

FTS 默认只包含 ACTIVE/CONTESTED current heads，通过同一 SQLite transaction 中的 head mutation trigger 更新，并允许从 Canonical Memory 完整重建。

### D-MEM-197 — Runtime-facing Memory References Never Select Namespace

Runtime-facing `MemoryRef` 只携带 Memory/Revision identity；`memory.search_more/read/trace` 不接受 target agent、MemorySpace 或 SQL。Namespace 始终由 Kernel 根据当前 Agent 绑定。

### D-MEM-198 — `MemoryQueryPlan` and `MemoryCapsule` Are Stable MVP Contracts

Q24 冻结 deterministic MemoryQueryPlan 与 bounded MemoryCapsule 的结构；修改必须保持 Token-Stable 与 exact Revision traceability。

### D-MEM-199 — Selected and Materialized Memory Are Separate Audited States

Memory Kernel 的 SELECTED 不等于模型已看到；Context Broker 必须在 Runtime dispatch 前调用 materialization receipt，将 MATERIALIZED/REF_ONLY/TOKEN_EVICTED 明确写入 Trace。

### D-MEM-200 — Canonical Memory Mutation Is One Workbench Transaction

Record/Revision/Parent/Source/Relation/Head/FTS/Core-dirty/Event/Receipt/Outbox Intent 组成一个语义 mutation transaction；禁止跨事务制造“双写最终一致性”作为正常路径。

### D-MEM-201 — Core Projection Failure Is Degradable Only When Canonical Truth Is Healthy

Core dirty 必须在 normal Turn 前处理；若 Canonical 可读可验证，可临时 deterministic materialize 并记录 degraded repair；Canonical/ownership invariant 损坏时必须 fail closed。

### D-MEM-202 — Error Classes Define Fail-closed vs Degraded Behavior

Namespace/Integrity 错误不得降级绕过；Projection 错误可重建降级；MemoryRef NotFound/Tombstoned 只产生 bounded tool error，禁止 fallback 到其它 Namespace/旧 Revision。

### D-MEM-203 — Five Memory Migrations Are the Initial Schema Boundary

M001–M005 名称与职责正式冻结；未来 Cluster/E2EE/Vector/Graph 通过后续 migration 扩展，不提前污染 MVP schema。

### D-MEM-204 — FakeRuntime and Ten Golden Paths Are Mandatory Before MVP Release

FakeRuntime 与 `MEM-GP-001 ~ 010` 成为首批正式 0-token Integration/Acceptance Contract；其中 Namespace Leakage、Canonical Loss、Tombstone Resurrection、Materialization Receipt 错误属于 release-blocking。

### D-MEM-205 — Architecture Discussion Ends at Q24; Phase A Starts Next

v3.10 之后默认直接进入 Phase A Canonical Memory Foundation 开发。只有实现/安全/恢复测试证明冻结 Contract 存在结构性缺陷时，才通过小型 ADR 重开相应条目。

**共同状态：** Accepted / Engineering Freeze。

---

# 52. V3.10 Decision Log Addendum

v3.10 在 v3.9 `D-MEM-020` 至 `D-MEM-190` 基础上新增：

```text
D-MEM-191 ~ D-MEM-205
SQLite Schema / Rust API Engineering Freeze
```

当前阶段：

```text
Memory Architecture Discussion: COMPLETE
Memory MVP Engineering Contract: FROZEN
Next Action: PHASE A IMPLEMENTATION
```

---

# 53. 下一步：直接开发

不再创建 Q25 架构主题。

开发入口：

```text
Phase A — Canonical Memory Foundation

A1 M001 migration
A2 Rust Memory newtypes/enums
A3 MemorySpace create/resolve
A4 Canonical record/revision transaction
A5 invariant tests
A6 SourceRef/Relation
A7 lifecycle transitions
A8 Recovery invariant checker
```

Phase A 通过后进入：

```text
Phase B — Mandatory Recall / FTS5 / MemoryCapsule
```
