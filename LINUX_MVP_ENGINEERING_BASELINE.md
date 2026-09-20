# Team Workbench — Linux MVP Engineering Baseline 1.0 Candidate

> 状态：Architecture Freeze Candidate（对应主规范 Draft v0.50）  
> 日期：2026-08-29  
> 目的：这是开发阶段的优先阅读规范。完整设计历史、讨论背景与全部 Decision 仍保存在 `TEAM_WORKBENCH_PROJECT_SPEC.md`。若历史章节与本文件冲突，以本文件与后续 Accepted ADR 为准。

---

## 1. 产品边界

Linux-first native AI Team Workbench。桌面端使用 Tauri v2 + React/TypeScript，长期运行控制面位于 Rust `workbenchd` 用户级后台服务。

持久 Workbench Agent 的 Core Runtime **只有**：

```text
DeepSeek Harness
Codex Harness
```

`Auto` 只在二者之间选择；`Hybrid` 只表示 DeepSeek + Codex 协作。Claude Code / OpenCode / OpenClaw 等不进入 Linux MVP Core Runtime；未来仅可作为 Room/Mission task-scoped External Worker。

Personal Primary Agent 是默认产品入口与自然语言控制面，但 Projects / Rooms / Workspace 仍是可直接进入的一等 Surface。

---

## 2. 最终 App Shell

```text
┌────────────┬────────────────────┬──────────────────────────────┬──────────────────┐
│ GLOBAL     │ CONTEXT / MY WORK  │ PRIMARY STAGE                │ LIVE SIGNAL      │
│            │                    │                              │ / INSPECTOR      │
│ 01 AGENT   │ Needs You          │ My Agent / Project / Room    │ Runtime          │
│ 02 PROJECT │ Running            │ Mission / Workspace / Studio │ Task             │
│ 03 ROOMS   │ Continue Work      │                              │ Cost             │
│ 04 WORKSP. │ Conversations      │                              │ Attention        │
│ 05 LIBRARY │ Rooms / Recent     │                              │ Evidence         │
│ 06 SYSTEM  │ contextual switch  │                              │                  │
└────────────┴────────────────────┴──────────────────────────────┴──────────────────┘
```

视觉借鉴参考图的**构图与信息语言**：高信息密度、强分区、执行现场感、编号/状态标记、编辑式控制台节奏。Theme 与 Style 独立；不绑定参考图具体颜色或黑色背景。

---

## 3. 代码边界

```text
React UI
   ↓
Tauri Desktop Host
   ↓  versioned local IPC / Unix domain socket
workbenchd
   ↓
Application / Domain
   ├── Store
   ├── Execution / Scheduler / Recovery
   ├── Context / Memory / Retrieval
   ├── Workspace
   ├── Diagnostics
   └── RuntimeAdapter
          ├── Codex Adapter
          └── DeepSeek Adapter
```

核心原则：

```text
React = View
Tauri = Native Shell
workbenchd = Application Truth
Harness = Agent Execution Runtime
```

React 不打开 Canonical DB，不解析 Codex/DeepSeek 私有协议，不自行推进 Mission/Task 真状态。

---

## 4. Rust Workspace 建议

```text
apps/
  workbenchd/
  desktop/

crates/
  workbench-protocol/
  workbench-domain/
  workbench-app/
  workbench-store/

  workbench-runtime-core/
  workbench-runtime-codex/
  workbench-runtime-deepseek/

  workbench-execution/
  workbench-context/
  workbench-workspace/
  workbench-diagnostics/
  workbench-platform-linux/
```

按稳定依赖边界拆分，不做“一对象一 crate”。DeepSeek/Codex private protocol 只能存在于各自 adapter crate。

---

## 5. Durable Truth 与数据库

MVP 使用单个 Canonical SQLite 数据库，由 `workbenchd` 单写。

```text
Canonical mutation
=
Domain State
+
Semantic Event
+
Receipt
```

三者在同一 transaction 提交。

大型 Workspace 文件、Raw Tool Output、Preview、Runtime binary、Search cache 不进入主库；数据库只保存 metadata / ResourceRef / ObjectRef。

Frontend durable state 是 daemon Projection，不是第二真源。

---

## 6. Agent / Memory / Shared Context

每个 Workbench Agent Instance：

```text
agent_id
private MemorySpace
Agent page/chat
DeepSeek or Codex RuntimeBinding
```

Memory 跟 Agent Identity，不跟 Runtime。

```text
Private Memory
≠
Project Shared Context
```

跨 Agent 私有 Memory 默认 DENY。Requirement / Decision / Contract / Knowledge / Artifact 等团队共同事实进入 Project Shared Context。

每个可见 Agent Turn 必须执行：

```text
beforeTurnMemory()
→ bounded Context / Materialization
→ Runtime
→ afterTurnMemory()
```

---

## 7. Retrieval / Token Baseline

默认不需要 Embedding、Vector DB、Reranker 或额外压缩模型。

```text
Direct Resolve
→ Metadata
→ FTS/BM25
→ Symbol / Entity / Relation
→ authority / freshness
→ Top-K
→ 当前主 LLM 继续判断或再次检索
```

Token 优化优先依靠：

```text
Tool Output Projection
Raw sidecar + searchable pointer
Repo/Symbol Map
Context Delta
Skill/Tool Exposure Budget
Structured Handoff
Minimum Sufficient Material
```

Token pressure 与 Provider Traffic Control 联动。

---

## 8. Scheduler / Provider / Recovery

原则：

```text
Agent proposes
Scheduler authorizes and executes
```

计划并行度不等于远程实际并发。Provider Traffic Controller 统一管理共享凭据、RPM/TPM、429/5xx、Retry-After、Adaptive Concurrency、Circuit Breaker 与 centralized Retry Budget。

```text
429 / 502 / 503 / 504
≠ Task FAILED
```

容量不足使用：

```text
WAITING_CAPACITY
WAITING_RATE_LIMIT
WAITING_PROVIDER_RECOVERY
WAITING_LOCAL_CAPACITY
```

副作用状态不确定时：

```text
UNCERTAIN_EFFECT
→ RECONCILING
```

只有确认 `NO_EFFECT` 才允许安全 replay。

Run Lease + Fencing Epoch 防止旧 Runtime 复活覆盖新执行。

---

## 9. Runtime / Permission / Upgrade

Workbench 不实现第三套 Harness Permission Engine。

```text
DeepSeek → DSH native permissions
Codex    → Codex native sandbox/approval
```

Workbench 只做入口、状态投影、用户决定转发和审计。

Runtime Update 使用 side-by-side version slots：

```text
STAGED
→ PROBE
→ CONTRACT TEST
→ CANARY
→ DRAIN
→ ACTIVATE
→ OBSERVE
→ LAST-GOOD
```

协议、Approval、Auth、Permission semantics、Error normalization、Resume capability 都是 Compatibility Gate 的一部分。

---

## 10. Waiting / Attention / Cost

等待用户批准时：

```text
WAITING_APPROVAL
→ idle
→ PARKED_WAITING_FOR_USER
```

等待本身默认：

```text
LLM calls = 0
Input Token = 0
Output Token = 0
LLM heartbeat = 0
```

Attention 是持久产品对象；Notification 只是投影。一个 Attention 只阻塞最小必要 Task/Branch，独立工作继续。

Android / Relay / Remote Approval 不进入 Linux MVP。

---

## 11. Workspace / Git / Safety

Workspace 与 Project 分离。Linux MVP 优先 Local Workspace + Git。

```text
ResourceRef
ExecutionWorkspaceBinding
WorkspaceChangeSet
Safety Point
ReviewFinding
```

代码并行优先 Git worktree/branch 隔离。非 Git 恢复优先底层 snapshot/reflink/version 能力；Safety Point 不替代 Harness 原生权限。

Git AI Review：

```text
ChangeSet
→ tests/lint
→ Review
→ APPROVED / CHANGES_REQUESTED / BLOCKED
→ Repair
→ Re-review
```

---

## 12. Secrets / Cloud Egress

Credential Plane 与 Context Plane 分离。Agent/LLM 不应获得 API Key/Password 原文。

Linux 优先 Runtime-native authentication；Workbench 自管 Secret 时优先系统 Secret Service。Provider Registry 只保存 `CredentialRef`。

Cloud Data Egress 支持：

```text
APPROVED_CLOUD
PROVIDER_RESTRICTED
ASK
LOCAL_ONLY
```

Materialization 发送前执行 Secret-aware Egress Preflight。Secret、完整凭据、Private Key 不进入普通 Event/Log/Support Bundle。

---

## 13. Diagnostics / Logs

正常监测是 deterministic、0 Token。需要复杂归因时，用户或 Personal Agent 可显式启动 AI Investigation。

AI Diagnostics 通过强类型证据 API 查询 Incident / Run / Runtime / Receipt，不获得 unrestricted log filesystem access，也不能绕过其他 Agent Private Memory。

Raw logs 使用：

```text
Age TTL
+
Storage quota
+
minimum free disk
+
priority eviction
+
Incident evidence pin
+
deterministic roll-up
```

普通 raw diagnostic log 默认最多约 30 天；TRACE/DEBUG 更短。Semantic Event / Receipt / Incident Summary 不跟 raw log 同寿命。

普通 Backup 默认不包含 raw logs、core dump、Secret 或 Runtime session。

---

## 14. Linux MVP Scope

P0：

```text
Route-3 Agent-centered Shell
Personal Primary Agent
DeepSeek + Codex Core Runtime
Per-Agent Private Memory
Project / Room / Mission
Scheduler / Handoff / Review
workbenchd
Provider / Token Control
Attention / Park / Resume
Local Workspace / Git / Safety
No-Embedding Search
Decision / Knowledge baseline
SQLite / Migration / Backup Restore
Credential / Egress
Diagnostics / AI Investigation
Log retention
Runtime update / Last-Good
First-run bootstrap
```

明确 Later：Android Companion、Remote Approval/Relay、Public Marketplace、External Workers、Embedding/Reranker、LLMLingua、Archscribe 深度集成、多机 Scheduler、Cloud Workbench Control Plane、完整高级 Skill analytics。

---

## 15. Implementation Slices

```text
0  Repo / build / protocol skeleton
1  Durable Agent Turn with FakeRuntime, 0 Token
2  Codex integration spike
3  DeepSeek integration + Auto/manual routing
4  Local Workspace / Git / ChangeSet / Safety
5  Project / Room / Mission / multi-Agent Scheduler
6  429 / Approval / Crash / Recovery fault paths
7  Diagnostics / Retention / Backup / Runtime Update
8  Release hardening / soak / privacy / token regression
```

Codex-first 是工程顺序，不是产品优先级。

---

## 16. First Walking Skeleton Acceptance

```text
Desktop opens
→ IPC handshake
→ daemon ready
→ My Agent projection renders
→ user sends text
→ Command is persisted
→ Event + Receipt atomically commit
→ FakeRuntime responds
→ Conversation projection updates
→ UI closes
→ UI reopens
→ same durable state is restored from daemon
→ daemon is killed/restarted
→ durable state remains correct
```

此链必须在 CI 中 0 Token 完成。

---

## 17. MVP Release Contract

MVP 必须通过完整链：安装 → Runtime Ready → Personal Agent → local Git Workspace → Project/Room/Mission → 2–3 Agents → real ChangeSet → 429/502 injection → Approval Park with 0 waiting Token → independent work continues → Runtime crash → Reconcile/Resume → Review/Repair → Mission verified completion → Diagnostics explains injected incident on demand → UI/daemon/machine restart recovery → staged Backup/Restore → Secret leak test → retention/disk budget test。

页面数量不是 Release Definition of Done。

---

## 18. Architecture Anti-patterns

```text
React/Tauri writes Canonical SQLite
Tauri owns Scheduler/Agent loop
Scheduler parses native Codex/DeepSeek JSON
Adapter accesses global DB directly
unbounded runtime/log/stream channels
per-token SQLite commits
UI polling as product truth
manual duplicate Rust/TypeScript IPC schemas
AI diagnostics reads arbitrary log filesystem
Scheduler tests require paid LLM
Harness update forces React protocol changes
old Approval reused for new Run/Epoch
429 treated as semantic task failure
```

出现以上模式应作为 Architecture Review 项处理。

---

## 19. Change Control

Freeze 后以下变更必须 ADR：Core Runtime boundary、Private Memory isolation、Harness-native Permission reuse、Canonical DB writer、side-effect replay/reconciliation、Data Egress/Secret policy、Provider failure semantics、Linux MVP Scope。

ADR 至少记录：Problem、Evidence、Affected Decisions、Alternatives、Chosen Change、Migration/Compatibility、Security/Privacy、Token/Cost、Test、Rollback。

---

## 20. 开工入口

第一阶段不要从完整视觉稿或全部页面开始。优先实现：

```text
workspace bootstrap
→ protocol
→ domain minimal types
→ SQLite migration 001
→ workbenchd + profile lock
→ IPC handshake
→ command/event/receipt transaction
→ projection snapshot/delta
→ FakeRuntime
→ Route-3 shell skeleton
→ My Agent minimal Composer
→ durable send/respond/restart loop
```

这条 Walking Skeleton 跑通后，再进入真实 Codex Adapter Integration Spike。