# 团队 AI 工作台项目设计文档

> 文档状态：Draft v0.50 — Architecture Freeze Candidate  
> 当前重点：Vertical Slice / Linux MVP Engineering Baseline / Decision Conflict Cleanup / Architecture Freeze  
> 更新日期：2026-08-29  
> 后续方式：本文件作为持续迭代的主项目文档，需求变更直接在本文件更新并记录 Decision Log。
> v0.17 Agent Memory Lifecycle & Agent Registry：在 v0.16.1 的“每 Agent 独立 MemorySpace”基础上，新增 Agent Definition / Instance / Runtime Binding / MemorySpace 四层模型、强制 Pre/Post Turn Memory Gate、MemoryTurnReceipt、百级/千级逻辑 Agent 扩展模型、非 Docker 官方部署约束与 OSS Integration Registry。共享项目/群聊信息继续归 Workbench Shared Context / Knowledge / State，不并入任何 Agent 私有 Memory。
> v0.18 Memory Studio & Harness Glass Box：将每个 Agent 的独立 MemorySpace 提升为可视、可检索、可编辑、可追溯的一等产品对象；新增 Memory Overview / Layers / Timeline / Graph / Turn Trace / Revision Editor，多入口查看与人工修订能力。Memory UI 只是真源投影，不改变 Per-Agent Private Memory 隔离。结合 DeepSeek Harness 的运行时可组合、追加式事件留痕与透明执行思路，新增 Harness Glass Box、插件/Context/Tool/Memory 注入可视化以及 Cache-aware Context Layering。
> v0.19 Capability Studio & Skill/Plugin Observability：在 Memory Studio / Harness Glass Box 之上，将 Skill、Plugin、Tool 与 Runtime Capability 提升为可视、可统计、可追踪、可审计的一等产品对象。用户可按本人 / Agent / Work / Conversation / Run 查看“有哪些能力、哪些真正被调用、调用多少次、由谁触发、成功率、耗时、Token/Cost、Context 影响与错误”；Skill 与 Plugin 的使用事实由 Event Store + Usage Ledger 增量投影，不依赖模型自述。

> v0.20 Composer Skill Palette & Explainable Skill Router：把 Skill 从“后台自动路由能力”提升为用户可直接发现、理解、显式调用和解释的 Composer 一等对象；新增 `/` Skill Palette、Skill Preview、Skill Detail、兼容性预检、Skill Intent、Router Candidate Scoring、调用来源区分、Pinned / Recommended Skill、Plugin Capability Resolution，以及“为什么选择 / 为什么没选择某 Skill”的可解释路由。
> v0.21 Plugin Host / Lifecycle & Safe Self-Extension：将插件系统提升为 Workbench 一等运行基础设施；借鉴 DeepSeek Harness/Cordis 的 Fiber 生命周期、依赖驱动激活、effect/dispose 自动回收和动态 Package 思路，但不把 Workbench 绑定为 Cordis 的外壳。新增 Workbench Extension Host、Extension Manifest、Effect Ledger、Activation Transaction、Hot Update/Drain、Ephemeral vs Persistent Plugin、AI 自扩展授权边界、Quarantine/Rollback、插件生命周期可视化，以及 DeepSeek/Codex Runtime-native Extension Adapter。
> v0.22 Model Registry / Admin Model Management & Explainable Auto Model Router：新增管理员专属 Model / Provider 配置中心与配置文件、模型能力与成本注册表、Agent 级 Model Policy、Auto Model Router、Fallback / Drain / Health、ModelSelectionReceipt 与模型使用可视化。默认 Agent 使用 `AUTO`，先做确定性能力硬过滤，再按任务、质量、成本、延迟、Context、历史效果与 Agent 策略评分；模型可由系统自动选择，但任何选择都受管理员白名单、预算、权限和 Runtime 兼容性约束。
> v0.23.1 Native Harness Permission Reuse Correction：保留“用户手动选择模型”是一等路径；撤销上一版自建 Unified Capability / Access Envelope / Approval Lease / SandboxProvider 权限架构。Agent 执行权限直接复用各 Runtime 官方原生权限体系：DeepSeek Harness 使用其 `sandbox/mode`、`approval/policy`、`permission-presets` 与 Cordis 权限插件扩展点；Codex 使用其原生 sandbox / approval / permission request 机制。Workbench 只做配置入口、Runtime Adapter 转发、状态展示与审计投影，不再发明第三套权限系统。
> v0.24 Workspace / Files & Execution Binding：将 Workspace 从“文件树入口”提升为独立资源与执行环境层，正式定义 Local / Remote / Mounted / Mirrored Provider、稳定 ResourceRef、Workspace Registry / Binding、文件浏览与传输、大文件与媒体代理、Git/代码工作区、Agent Runtime Execution Binding、并行写入隔离、Workspace Change Projection、Mirrored Sync 与冲突恢复。Workbench 不重新实现 Harness 权限；它负责解析“工作区在哪里、资源是什么、怎样传输/绑定”，实际 Agent 文件访问权限仍由 DeepSeek/Codex 原生 sandbox / approval / permission 体系执行。
> v0.25 Git AI Review / Windows Explorer-grade Workspace & Resumable I/O：在 Workspace v0.24 上新增 Git Change Review Pipeline、AI Review Provider / ReviewFinding / Repair Gate、Workspace 中 AI 改动与操作过程可视化；Workspace Explorer 的交互目标提升到 Windows 11 Explorer 级别，并借鉴 Files、Tauri/Rust 文件管理器等开源实现，但不盲目内嵌平台绑定或许可证不兼容代码。文件浏览采用 metadata-first、visible-range hydration、虚拟化、增量索引、磁盘缓存与有界内存；上传/下载采用持久 TransferJob、chunk checkpoint、partial cache、断线续传、完整性校验与原子完成。
> v0.26 Workspace Safety Points / Undo / Snapshot & Revert：将“AI 改了什么、能否安全撤销”提升为 Workspace 一等能力。代码优先利用 Git branch/worktree/commit/diff；非 Git Workspace 优先复用底层 Provider / 文件系统原生版本能力（Btrfs/ZFS snapshot、reflink、对象版本、NAS snapshot 等），Workbench 不自造一套通用版本文件系统。新增 WorkspaceVersionProvider、Run Safety Point、Write Intent Snapshot、Operation Journal、Workspace Trash、AI ChangeSet、Revert Run、三方回退冲突检测、Binary Rollback Coverage、Rollback Receipt 与版本/空间压力策略。
> v0.27 Agent Definition / Instance / Install / Clone / Marketplace：把“Agent 是什么、用户怎样得到一个 Agent、升级时如何不破坏它已经形成的个体记忆”正式产品化。Agent Definition 是可复用模板，Agent Instance 是长期存在的独立个体；每个 Instance 继续拥有唯一 Private MemorySpace。新增 Agent Package、Agent Library、Create / Install / Import / Clone / Fork / Upgrade / Archive 生命周期、依赖解析、信任与签名、Agent Capability Manifest、Definition Diff、Instance Overlay、Memory-safe Upgrade、Agent Compatibility Projection，以及未来 Marketplace / Team Catalog 的边界。
> v0.28 Agent Room / Agent Team / Multi-Agent Collaboration：正式定义 Agent Team、Agent Room、Room Membership 与 Room Turn Request；Room 是可视协作与沟通表面，Task Graph / Scheduler 仍是工作状态真源。新增参与者选择、@Agent 精确点名、自动发言路由、Panel 模式、Speaker/Cost/Round Budget、Room Awareness Cursor、Catch-up Context、Agent 私有 Memory 隔离、Handoff/Task 与聊天解耦、多人房间状态可视化，以及“Joined 不等于每条消息都调用模型”的成本与性能边界。
> v0.29 Mission-Oriented Agent Room & Pluggable Execution Backends：将 Agent Room 从“多人聊天”升级为可自动组队、分工、调度和可视化执行的 Mission 协作表面。用户可 @ 一个 Lead Agent，由该 Agent 基于任务能力缺口提出团队组成、Task Graph、Handoff 与并行方案；Scheduler 负责验证并执行，Auto Team 模式下允许在预算/人数/可信模板边界内自动邀请或创建临时 Agent。**其中“同一 Agent 可直接切换 Claude Code / OpenCode / OpenClaw 等为自身 Runtime”的解释已被 v0.35.1 修正：Workbench Agent 的核心对话 Runtime 只允许 DeepSeek Harness / Codex Harness；其他 CLI/Harness 仅作为 Room/Mission 中可选的外部 Execution Worker，不成为主 Agent Runtime。**上下文采用 Mission Context Base + Task Delta + Handoff Packet + Room Digest Delta + Agent Private Memory，流程与每个 Agent/Worker 的 Harness、Model、Skill、Task 状态统一投影到 Live Canvas。
> v0.30 Mission Planner / Team Assembly Planner：把 AUTO TEAM 从“自动拉 Agent”提升为结构化任务规划、能力缺口分析、团队组装、任务分配、滚动式重规划与完成验证系统。Mission Lead 负责提出目标理解、Capability Demand、Task Graph 与 Team Proposal；Workbench 的 Plan Compiler / Team Assembly / Scheduler 负责确定性校验、Agent 匹配、预算/并发/Workspace 冲突与真实状态推进。新增 Mission Charter、Role Slot、TeamCompositionProposal、MissionPlanRevision、Rolling-Wave Planning、Mission Progress Projection、Replan Trigger、TeamAssemblyReceipt、Plan Review/Takeover 与 Playbook 机制。
> v0.31 Project / Mission Control Center：把 Project 首页定义为一个基于结构化投影的项目控制中心，而不是聊天入口、复杂 BI Dashboard 或默认 Canvas。用户进入 Project 后应在数秒内回答“项目是否正常、什么正在运行、哪里需要我、AI 刚改了什么、下一步是什么、成本是否受控”。新增 ProjectControlProjection、Attention Inbox、Active Mission/Work Summary、Workspace Impact、Decision/Artifact/Transfer 摘要、Budget Projection、Project Health、Mission Focus Mode、增量刷新与跨端紧凑投影；所有数据继续来自 Event Store / Task Graph / Workspace / Runtime / Usage Ledger 等真源，不使用 LLM 每次重算首页。
> v0.32 Project Knowledge / Decision / Artifact & Shared Context：正式把“项目共同事实”从 Agent 私有 Memory 中分离出来，建立 Project Knowledge Registry、Decision Record、Requirement/Contract、Artifact Registry、Project Baseline Context、Shared Context Broker 与 Context Receipt。Agent 可以从 Conversation / Run / Workspace / Review 中提出 Knowledge/Decision Candidate，但共享事实必须经过来源、去重、冲突、版本与发布状态治理；Artifact 只保存产品级元数据和稳定 ResourceRef，不复制大型 Workspace 内容。新增 Knowledge/Decision/Artifact 可视化、版本/超越关系、来源追溯、Staleness Invalidation 与增量索引，使多个 Agent 共享同一项目事实而不共享彼此私有 Memory。
> v0.33 Search / Retrieval / Knowledge Engine：建立 Agent Context Retrieval 的统一检索基础设施，并允许 Workspace / Knowledge 等页面复用同一索引能力；用户主交互仍然是 Agent Composer，不要求增加常驻全局搜索框。新增 Search Gateway、Retrieval Planner、SearchScope、Index Document/Chunk Projection、Direct Resolve → Metadata/FTS → Vector → Graph Expansion → Fusion/Rerank 分层检索、Authority/Freshness/Lineage 过滤、Retrieval Budget、Search/Context Receipt 与增量索引。
> v0.33.1 Composer-first & Cloud-Model Correction：明确“搜索引擎”主要是 Agent 背后的 Retrieval Infrastructure，不把独立 Search Box 变成 Agent 页主入口；Workspace 仍可保留类似 Windows Explorer 的文件搜索，Knowledge 页面可有范围内搜索，Ctrl+K 全局搜索仅作为可选高级入口。部署默认采用 Cloud Model First：推理模型、Embedding、Reranker 均可通过管理员配置的云端 Provider/API 使用，不要求部署本地模型服务器；本地 Tantivy/SQLite/缓存属于索引与数据基础设施，不等于本地模型。
> v0.33.2 No-Embedding Baseline Correction：Embedding / Vector Search / Reranker 不再作为默认或必需基础设施，默认关闭且不要求付费接入。首版 Retrieval 采用 Direct ID/Path Resolve + Metadata + FTS/BM25 + Symbol/Relation Index + Authority/Freshness 排序；需要更深入理解时优先让当前已经在执行任务的主模型通过 Workbench Search Tools 继续检索和读取 Top-K 候选，不额外部署或强制调用专用 Embedding/Reranker 模型。Vector Semantic Retrieval 仅保留为未来可选插件。
> v0.34 Deterministic Ingestion / On-Demand Multimodal Understanding：建立零额外 AI 服务也能运行的文件摄取与内容投影链。Workspace 原文件继续是真源；后台默认只做 metadata、确定性文本/结构解析、代码 symbol、缩略图/关键帧/媒体元数据与索引，不自动调用 Vision/OCR/STT/Embedding。只有用户或当前 Mission 真正需要理解图片、扫描 PDF、音频、视频或复杂版面时，才由当前已经配置的主多模态模型按页/帧/片段按需分析，并缓存带 SourceRevision 的 AI-derived UnderstandingRecord。新增 Parser Host、ContentProjection、IndexCoverage、MaterializationPlan、IngestionReceipt、UnderstandingReceipt、恶意文件隔离与大文件渐进处理。
> v0.35 Runtime Capability Matrix / Input Materialization & Multi-Backend Attachment：建立资源物化与 Capability Probe 基础，但其“同一个主 Agent 可在所有外部 CLI/Harness 间直接切 Runtime”的范围已由 v0.35.1 收紧。ResourceIntent / Materialization / Workspace Staging 继续有效；在 Direct Agent Domain 中仅针对 DeepSeek Harness / Codex Harness，在 Room/Mission External Worker Domain 中才扩展到 Claude Code / OpenCode / ACP/CLI 等 Worker。
> v0.35.1 Core-Agent Runtime Boundary & Skill Visual Explain Correction：明确持久 Workbench Agent 的主聊天/主 Agent Turn 只运行于 DeepSeek Harness 或 Codex Harness；Direct Agent 中的并行子代理优先使用当前 Harness 自带的 native subagent/worker，不把 Claude Code/OpenCode/OpenClaw 等接成主 Agent Runtime。Room/Mission 可按策略调用外部 CLI/Harness 作为 Task-scoped Execution Worker，但它们默认不是 Agent Instance、没有独立 Private MemorySpace、不能取代主 Agent 身份。Skill Studio 新增 Visual Explain：从 Skill 真源生成 SkillVisualizationIR，内置轻量可视化，同时把 Archscribe 作为可选高级渲染/Skill 集成，支持 Excalidraw/PNG/GIF/MP4/SVG/HTML 等导出；Installed Skill 数量与每轮暴露给模型的 Active Skill Set 分离。
> v0.35.2 Personal Agent → Room Control & Room Coordinator Correction：将主聊天中的 Personal Primary Agent 提升为跨界面 Personal Operator，但不新增第三套 Agent Loop。用户可直接在主聊天里要求创建 Room、添加 Agent、启动/恢复 Mission、查询状态或 `@Room/Agent` 派发任务；主 Agent 通过 Workbench Control Plane 的结构化 Room/Mission Tools 执行。Room 不再引入隐藏的“Room Master Model”，而是把 `Room Coordinator` 定义为一个角色绑定，默认指向创建该 Room 的当前 Workbench Agent（通常为 Personal Primary Agent）；Coordinator 负责无 @ 消息的默认承接、Room 生命周期和任务入口，`Mission Lead` 则是每个 Mission 独立选择的工作负责人，两者可相同也可不同。同一个 Agent 在 Main Chat 与多个 Room 中保持同一 agent_id / Private MemorySpace，但每个 Conversation/Room 使用独立 RuntimeBinding、RoomContext 与 Awareness Cursor，禁止复用同一个 Harness session 导致上下文串线。主聊天跨 Room 派发只传结构化 DispatchPacket / ResourceRef / TaskRef，不复制主 Agent 私有 Memory 或整段 Conversation。
> v0.36 Workbench Control Tools / Personal Command API：把 Personal Primary Agent 作为“自然语言工作台入口”的能力落到一组结构化、强类型、可审计且可重试的 Workbench Control Tools。工具只负责 Workbench 产品域状态与调度，例如查询 Project/Room/Mission、创建 Room、邀请 Agent、派发任务、启动/暂停/恢复 Mission、创建 Handoff、请求 Review、创建 Decision/Knowledge Candidate、打开 Surface；文件读写、Shell、代码执行、Harness native subagent 等执行能力继续属于 DeepSeek/Codex Harness 原生工具与权限体系。新增 Control Tool Catalog、Toolset Projection / Tool Exposure Budget、Query/Command/Job 三类语义、TargetRef、ActionContext、dry-run/preview、idempotencyKey、expectedRevision、CommandReceipt、长任务 JobRef、跨 Agent Dispatch 审计，以及“主 Agent 可协调他人但不能冒充他人或读写他人 Private Memory”的硬边界。
> v0.37 Durable Mission Execution / Runtime Recovery & Crash-safe Resume：把 AUTO TEAM 从“正常情况下能跑”提升为“进程崩溃、网络断线、模型限流、应用/机器重启后仍可恢复”。Workbench 保存 Mission/Task/Plan/Command/Event/Workspace ChangeSet/Safety Point 等产品级 durable truth；DeepSeek/Codex 的 Session/Thread/Run 只作为 RuntimeBinding，可恢复则 Resume，不可恢复则通过 Recovery Capsule 建立新 Binding。新增 Recovery Coordinator、ExecutionCheckpoint、Run Lease/Fencing Epoch、Runtime Event Cursor、Lost-Connection Grace、Uncertain Side Effect Reconciliation、RecoveryReceipt、Retry/Backoff/Circuit Breaker、Recovery Budget 与 Boot Recovery Sweep。系统不宣称跨 Harness/File/Shell 的 exactly-once；采用 idempotent Control Command + side-effect evidence + reconciliation，禁止在副作用状态不确定时盲目重跑同一 Turn。
> v0.37.1 Provider Traffic Control / Rate-limit-aware Parallelism：把 429/502/503/504、动态限流、共享 API Key 配额、模型服务拥塞和多 Agent 并行造成的 burst 从“Run 失败”中剥离，建立全局 Provider Traffic Controller、分层 Capacity Envelope、Admission Queue、RateLimitLease、Adaptive Concurrency、Retry Budget、Retry-After/指数退避+jitter、Circuit Breaker 与 ProviderPressureProjection。Mission 的“计划并行度”和“实际远程模型并发”分离；容量不足时 Task 进入 WAITING_CAPACITY / WAITING_RATE_LIMIT，而不是 FAILED 或触发 Repair/Replan。DeepSeek/Codex Harness native subagent 也必须纳入并行负载预算：能配置原生 max-workers/并发时由 Adapter 下发，不能观测内部调用时采用保守 Run Slot 估算并显式标记 OPAQUE_CONSUMPTION。
> v0.38 Token-efficient Agent Execution & Background Workbench Service：在 Provider Traffic Control 之前增加 Token Pressure / Context Budget 层，用确定性裁剪、结构化 Tool Output、Repo/Symbol Map、Context Delta、Raw-output Sidecar 与动态 Token Lease 同时降低输入/输出 Token、成本和 TPM 限流概率；不默认引入额外压缩模型。桌面执行生命周期从 Tauri Window 中剥离为用户级 Workbench Service/Daemon，UI 关闭不等于 Mission 终止；Daemon 持有 Scheduler、Recovery、Provider Traffic、Runtime Supervisor 与 Durable Jobs，并定义 Close/Quit、Sleep/Wake、Autostart、Tray、Notification 以及未来 Android Companion 的安全远程投影/控制边界。
> v0.39 Attention / Notification / Remote Approval & Android Companion Interaction：把“需要用户处理”从零散弹窗升级为持久 AttentionItem，并将通知仅视为 Attention 的多端投影。Scheduler 在某个 Task 等待 Codex/DeepSeek 原生 Approval、Review、冲突、预算或 Provider 处理时，只暂停受影响分支，独立 Task 继续运行；429/普通 Retry 不进入用户 Attention。Android Companion 通过安全 Relay 获取 compact projection，可处理 pause/resume、消息派发和符合策略的实时原生 Approval，但 Remote Approval 必须绑定精确 Run/Epoch/NativeRequest、带过期时间且由 Harness 最终确认，禁止离线盲排队、自动批准或绕过 Harness 权限。新增通知去重/聚合、桌面与手机 Presence-aware Routing、Quiet Hours、RemoteCommand 状态、AttentionReceipt 与可插拔 Push Provider；ntfy/Gotify/UnifiedPush 仅作为通知基础设施研究参考，不成为产品状态真源。
> v0.39.1 Linux-first Attention / Parked Approval Correction：Android Companion、Relay、远程审批保持长期接口与安全边界设计，但从 Linux 首版实现范围中后移。Linux MVP 先完成 durable Attention、桌面/Tray 通知、WAITING_APPROVAL、Park/Resume、Approval Expiry/Revalidation 与零 Token 等待；用户两小时不处理审批时，受影响 Task 可以进入 PARKED_WAITING_FOR_USER，不轮询模型、不发送“还在等吗”类 LLM 心跳、不持续消耗 Token。Native approval/session 若仍有效可原地恢复；若已过期，则保留 Attention 与任务状态，用户回来时重新探测并通过 Recovery Capsule/新 RuntimeBinding 产生新的当前原生请求，旧批准绝不套用。Android 首版未来优先做只读 compact state + 通知，再逐步加入普通 remote command，live native approval 放到更后阶段。
> v0.40 Linux workbenchd / Runtime Supervisor & Resource Governance：将长期运行稳定性落实为 Linux 用户级后台服务与受控进程树。workbenchd 负责 Durable Scheduler、Recovery、Provider Traffic/Token Control、Runtime Supervisor 与本地 IPC；DeepSeek Harness / Codex Harness 由 Adapter 声明各自进程模型与会话能力，Workbench 不假设“一 Agent 一进程”或“一进程多 Agent”。新增 ProcessLease、RuntimeProcessRecord、Warm/Idle TTL、Drain/Park/Shutdown、CPU/RAM/PID/FD/日志预算、systemd --user/cgroup 可选资源边界、Crash-loop Quarantine、Late-process Fencing、结构化日志轮转、无模型 Heartbeat、版本兼容 Probe、Last-Good Runtime 与故障注入验收。UI 关闭不影响后台 Mission；等待用户/限流时可释放 Runtime 资源但保持 Durable Task/Attention。
> v0.41.1 Visual Style Correction：用户提供截图所要借鉴的是**界面风格与构图语言，不是截图中的具体配色或深色背景**。Linux Desktop 的 Visual North Star 改为：高信息密度但层次清楚的“Agent 执行现场”、非传统 SaaS 的编辑式/控制台式排版、强分区与多层 Panel、大小文字反差、编号与技术标记、状态信号、局部倾斜/切角/悬浮标签、带有技术海报/广播控制台感的视觉节奏，以及主舞台与侧栏之间明显的空间层级。颜色、明暗主题和 Accent Palette 独立成为 Theme Tokens，不从参考图硬编码。v0.41 的 Runtime Upgrade Compatibility 设计保持不变。
> v0.42 Credential / Secret Storage & Cloud Data Egress：在 Cloud Model First、DeepSeek/Codex 原生 Runtime 与 No-Embedding Baseline 上补齐 Linux MVP 的凭据与数据外发边界。新增 Credential Plane / Context Plane 分离、Runtime-native Auth First、Linux Secret Service 优先的 CredentialStore、CredentialRef、Secret-safe Process Injection、Project/Workspace Data Egress Policy、Minimum Sufficient Material Preflight、Secret Detection/Redaction、DataEgressReceipt、敏感日志隔离与 External Worker Opaque Egress 约束。Agent/Model 不获得 API Key/Password 原文；Private Memory 的“跨 Agent 私有性”和“是否允许发送给当前云模型”作为两个独立维度治理。
> v0.43 Linux Installation / First-run Bootstrap & Runtime Installation Manager：把“下载安装到第一次可用对话”定义为可恢复、可诊断的 Bootstrap Pipeline。Workbench 本体、workbenchd 与 DeepSeek/Codex Runtime 安装生命周期分离；Runtime 支持 Managed Installation 与 External Installation 两种来源，并通过 Version Slot / InstallationId / Protocol Fingerprint / Capability Probe / Contract Test 决定可用性。Codex 优先利用官方 Linux standalone binary 进入用户级 Managed Slot；DeepSeek Harness 由于官方当前仍处于 developer preview 且明确可能发生破坏性兼容变化，MVP 采用 RuntimeInstallerProvider + user-scoped package slot，并把 Node/官方 npm 运行依赖作为显式 prerequisite，不在后台偷偷 sudo 或 curl|sh。首次启动允许一个 Runtime READY 即进入 Agent，另一个可稍后配置；安装、认证、协议兼容、Secret Store、workbenchd、Workspace 与可选网络 Smoke Test 分阶段展示并支持重试。

> v0.46 Diagnostics / Privacy / Support Bundle & Crash-safe Incident Capture：在 Linux-first、workbenchd 后台运行、DeepSeek/Codex Runtime Compatibility、Credential/Data Egress 和 Durable Data 基础上补齐故障诊断链。新增 IncidentRecord、CorrelationId、DiagnosticSnapshot、CrashEnvelope、结构化本地日志、Crash Domain 分类、Bounded Breadcrumb、Privacy Classification、Redaction Pipeline、Support Bundle Profile/Manifest、临时 Deep Trace、Crash-loop Recovery Entry 与 Support Export Preview。默认诊断为本地、零 Token、零自动上传；API Key、认证 Token、Private Memory 原文、完整 Prompt、项目代码/Workspace 原文、Raw Tool Output 与原生 core dump 不进入默认 Support Bundle。用户可显式提高诊断级别并预览导出清单；任何可能含敏感内容的采集都有 TTL、范围和可撤销状态。
> v0.47 AI-assisted Diagnostics / Agent Investigation & System Verification：在 v0.46 的本地诊断真源上增加“AI 可按需调查 Incident”的能力，但不引入常驻诊断模型。Personal Primary Agent 或用户指定的 Workbench Agent 通过强类型 Diagnostic Tools 读取已脱敏 DiagnosticSnapshot、Incident、Agent/Run execution events、Receipt、Runtime/Provider/Resource facts，并形成 DiagnosisCandidate / RepairPlan；默认不能读取其他 Agent 的 Private Memory、完整 Prompt、隐藏推理或 Secret，必要的 P2 内容需用户显式扩大 scope。修复分为 deterministic recovery、配置/Runtime rollback、Task repair 与 source-level patch 等等级，最终执行仍经过现有 Workbench Control Tools、Harness 原生权限、Review/Test/Safety Point，不允许 AI 直接修改运行中的 Workbench binary 或凭据。同步建立全系统 Performance / Stress / Fault-injection Matrix，以交互延迟、Event/DB规模、Workspace规模、并发 Mission、Provider/Token压力、内存/磁盘/进程预算、Crash/429/502/OOM/断电组合故障为 Release Gate。
> v0.48 Log Lifecycle / Retention & Linux MVP Scope Freeze：将“日志会无限增长”作为容量与隐私问题正式治理。Raw/DEBUG/TRACE/INFO diagnostic logs 采用 age + size 双重 retention，Linux MVP 默认本地诊断日志保留 30 天且受总磁盘预算约束；Semantic Event/Receipt/Incident Summary 不与 raw logs 同寿命，按 durable evidence 规则保留。未解决 Incident 可 Pin，过期前先生成确定性 roll-up，不调用模型。普通 Workbench Backup 默认不包含 raw logs/trace/core dump，避免备份抵消删除策略；Restore 后仍重新执行 retention。与此同时正式冻结 Linux MVP：第一版只交付 Agent-centered Shell、DeepSeek/Codex Core Runtime、Personal Agent、Project/Room/Mission 基础协作、Workspace/Git 安全链、Durable Scheduler/Recovery、Provider/Token Control、Memory/Shared Context 基线、Attention、Diagnostics 与安装升级基础；Android、Marketplace、External Workers、高级可视化/语义检索等进入 Post-MVP/Later。
> v0.49 Code-level System Architecture：把此前的产品架构收敛为可编译、可测试、可替换的代码边界。Linux MVP 采用 `React UI -> Tauri Desktop Host -> versioned Unix IPC -> workbenchd -> Application/Domain -> SQLite/Runtime/Workspace infrastructure` 的分层；Runtime Adapter 的正式实现从早期 TypeScript 示例收紧为 daemon-side Rust contract，DeepSeek/Codex 各自隔离在独立 Adapter crate，避免上游协议变化污染 UI、Scheduler 与数据层。新增 Rust workspace/crate 划分、Daemon Service Supervisor、Command/Query/Job 与事务 Outbox/Projection 流、typed IPC schema generation、bounded async channels/backpressure、frontend durable projection vs local UI state 分离、SQLite 单写者执行器、Fake Runtime/Provider 测试替身、依赖防火墙与 Vertical Slice 编译边界。
> v0.50 Architecture Freeze Candidate / Vertical Slice & Engineering Baseline：停止继续扩展 Linux MVP 的大功能面，把前述架构收敛成第一条可执行 Walking Skeleton、分阶段 Vertical Slice、最终冲突优先级与工程基线。正式规定实现顺序优先 `Protocol/Domain -> workbenchd + SQLite -> IPC + Projection -> FakeRuntime -> Codex Adapter -> DeepSeek Adapter -> Workspace/Git -> Mission/Recovery -> Diagnostics/Backup/Update`；Codex 先接仅是工程顺序，不形成产品主从关系。建立 Final Normative Precedence，明确 v0.23 自建 Permission Engine、v0.29/v0.35 外部 CLI 作为主 Agent Runtime、v0.33 默认 Vector/Embedding、v0.39 Android/Remote Approval 进入 Linux MVP、v0.41 绑定具体配色等旧描述均由后续修正覆盖。另生成精简 `LINUX_MVP_ENGINEERING_BASELINE.md`，作为开发阶段优先阅读的规范基线；主文档继续保留完整设计历史与 Decision lineage。
> v0.44 Durable Data / SQLite Persistence / Migration / Backup & Restore：把 Agent Memory、Conversation、Room/Mission/Task、Project Knowledge、Decision、Receipt、Usage 与 Event 等长期数据统一纳入 Linux 本地持久化边界。MVP 采用 workbenchd 单写者 + 单个 Canonical SQLite 数据库 + WAL/事务语义，所有关键状态与语义事件在同一事务边界提交；大型原始 Tool Output、缓存、索引、Runtime binary 与 Workspace 文件不塞入主库。新增 XDG 数据目录布局、数据耐久等级、Semantic Event/Telemetry 分离、Schema Migration Ledger、Pre-migration Snapshot、Online Backup、Restore Staging/Atomic Cutover、Credential/RuntimeBinding/Workspace Rebind 规则、Corruption Quarantine 与 Last-Good Backup 恢复。Search/Projection/Cache 可重建；Secret Store、Workspace 字节、Runtime Session 与 Harness binary 不作为 Workbench 数据备份的一部分。
> v0.45.1 Hybrid Agent-centered App Shell：在 v0.45 六大一级 Product Surface 与四区壳层基础上，正式选择“路线 3 混合版”。`Global Rail` 继续提供 Agent / Projects / Rooms / Workspace / Library / System 的稳定专业入口，但默认进入 `01 AGENT` 时，第二栏不使用泛化的 Context Rail，而是明确成为 `MY WORK`：Needs You / Running / Continue Work / Conversations / Rooms / Recent。中央 `Primary Stage` 仍由 Personal Primary Agent / 当前工作现场主导；只有切换到 Projects / Rooms / Workspace / Library / System 时，第二栏才转化为对应的 Context Rail。由此保留最早 Agent Page / Personal Agent Home 的“Agent 是入口与工作中心”感，同时保留 v0.45 面向复杂项目、Workspace 与专业 Surface 的扩展能力。

---

## 0. 一句话结论

本项目采用 **双 Harness、单任务优先单 Runtime、按需 Hybrid** 的架构：

- **DeepSeek Harness** 与 **Codex Harness** 都是一等公民 Agent Runtime；
- **Workbench Core** 是一个薄的 Agent Control Plane，不实现第三套 Agent Loop；
- 每个任务由一个 **Lead Runtime** 主导，系统可自动路由，用户也可以手动指定；
- 默认遵循 **Single Runtime First, Hybrid on Demand**，避免双 Harness 带来不必要的双重成本；
- 用户可以选择 `Auto / DeepSeek / Codex / Hybrid`，并选择 `Economy / Balanced / Quality / Custom` 成本策略；
- Workbench 统一拥有 Project Context、Memory Gateway / Memory 生命周期基础设施、Event Bus、预算与 Usage Ledger；Runtime 执行权限由各 Harness 原生权限系统负责，Workbench 仅保存选择、转发配置并展示权限状态；**每个 Agent Instance 自己拥有独立 MemorySpace**，避免 DeepSeek 与 Codex 形成状态孤岛，也避免不同 Agent 的长期经验互相污染。
- **Hybrid / 多 Runtime 协作必须可视化**：用户能直观看到每个 AI / Runtime 当前负责的任务、进度、依赖、交接、等待、失败与结果；
- Workbench 明确区分 **Direct Agent Chat** 与 **Agent Room / Mission**：Direct Agent Chat 的持久 Agent Turn 只使用 DeepSeek Harness / Codex Harness；Room 才承担多 Agent 协作、自动组队与可选外部 Execution Worker。被点名的 Lead Agent 可在 `Auto Team` 下根据能力缺口提出并组建协作队伍；Room 负责沟通与可视化，Task Graph / Scheduler 负责真实执行与边界控制。
- Agent 页面采用 **Adaptive Workspace / Progressive Disclosure**：默认保持最轻量的对话与执行视图，只有当任务实际进入多步骤、Hybrid、多 Agent、并行、依赖、审批或复杂执行时，才自动展开 Canvas、Task Board、Live Inspector 等工作台能力；用户可手动展开、收起或锁定视图，AI 只负责建议与触发，不强迫界面常驻复杂化。
- **性能与算法效率是一等公民需求**：后续功能会持续增加，因此从第一版开始采用增量计算、索引、懒加载、事件投影、按需上下文、后台任务隔离与可测量性能预算，禁止依赖“全量扫描 / 全量重渲染 / 全量塞入模型上下文”的简单实现。
- **AI 可以访问整个 Workbench 的数据能力，但不等于把全部数据塞入模型上下文**：所有 Runtime 通过统一 Workbench Data Gateway / Tool Gateway 按需发现、搜索、读取、订阅和在授权范围内修改工作台数据；其中 Runtime 执行权限不由 Workbench 另造一套实现，而是交给当前 Harness 的原生权限 / 审批 / 沙箱机制；Workbench 负责数据入口、配置展示、事件记录与用户选择。
- **工作台面向团队成员使用，但不把“团队”当成所有数据与 Agent 的唯一所有者**：统一 Shell 服务于整个团队；Access Role 负责权限，Work Profile 负责岗位 / 领域配置；每个用户拥有独立的 Personal Primary Agent，并同时存在 Personal / Project / Organization 等不同数据作用域。

核心角色定义：

```text
Workbench Core     = Agent Control Plane
DeepSeek Harness   = General Agent Runtime
Codex Harness      = Engineering Agent Runtime
```

如果任务是研究、规划、知识、内容与跨领域协作，通常由 DeepSeek Harness 作为 Lead；如果任务是代码理解、修改、测试、Debug、Refactor，通常由 Codex Harness 作为 Lead；复杂软件任务则可以进入 Hybrid，例如 `DeepSeek Plan -> Codex Implement -> DeepSeek Review`。

---

# 1. 项目背景与目标

## 1.1 项目目标

做一个团队内部使用的 **本地优先 AI 工作台**，界面风格参考 Boujoy Harness 演示图与项目，但不复制其产品边界。底层同时接入 DeepSeek Harness 与 Codex Harness，由 Workbench Core 统一承担路由、项目上下文、记忆、事件、权限、成本与运行时生命周期管理。两个 Harness 均可成为当前任务的 Lead Runtime。

第一阶段只开发：

- Linux 桌面版；
- Agent 页面；
- 本地项目 / Workspace；
- DeepSeek Harness Runtime 接入；
- Codex Harness Runtime 接入；
- Auto / DeepSeek / Codex / Hybrid 四种 Runtime 模式；
- Economy / Balanced / Quality / Custom 四种成本策略；
- 会话、运行状态、工具调用的基本可视化；
- DeepSeek / Codex Hybrid 协作过程的基础可视化：阶段、责任 Runtime、状态、交接与结果；
- 为后续多 Agent 协作画布与 Agent 群聊预留统一数据模型和页面入口；
- 为后续知识库、专家、风格、监控、新闻等模块预留统一侧边栏与数据模型。

后续平台顺序：

1. Linux Desktop
2. Windows Desktop
3. Android Client

Android 暂不建议直接在手机本地运行完整 DeepSeek Harness + Codex CLI，而应优先作为 **远程控制/查看客户端**，连接用户自己的 Linux / Windows 工作站运行时。这会显著降低移动端沙箱、二进制、Node Runtime、文件系统和编译工具链的复杂度。

## 1.2 非目标（第一阶段不做）

- 不从零重写 DeepSeek Harness Agent Loop；
- 不从零重写 Codex；
- 不让 DeepSeek Harness 或 Codex Harness 单独成为项目长期状态与记忆的唯一真源；
- 不第一版就实现复杂多 Agent 自治团队或完整 Agent 群聊编排，但必须预留数据模型、事件协议和 UI 扩展位；
- 不第一版自动把全部聊天无条件写入知识库；
- 不第一版开发知识库完整图谱、新闻抓取、专家市场等全部侧栏功能；
- 不把应用做成需要浏览器打开的网站。

---

# 2. 参考项目与资料理解

## 2.1 Boujoy Harness 参考价值

Boujoy Harness 的思路非常适合参考：

- DeepSeek Harness 继续作为 Agent Runtime；
- 桌面层负责宿主、交互和本地工作区；
- Markdown Vault 负责长期可读、可编辑的知识；
- 不破坏上游事件 / RPC 语义；
- 主 UI 围绕项目、会话、运行状态与知识组织。

我们需要参考的是其**产品分层与信息架构**，不是照搬代码或视觉素材。

## 2.2 上传视频字幕中体现的产品能力

参考素材表达的核心工作流包括：

- 自动分析有价值的对话与行动；
- 沉淀为知识卡与 Skill；
- 下一次相似任务自动检索并复用；
- 知识卡、Skill、媒体与知识图谱可视化；
- 自动规划下一步行动；
- 手动“沉淀本次对话”；
- 项目做到一半也能保存进度；
- 新会话可“接着做上次项目”；
- 专家模式、风格模式；
- 新闻聚合与热点发现。

这些能力会作为后续完整工作台的模块目标，但第一版先完成 Agent 页面和能够承载这些能力的数据骨架。

### 2.2.1 从参考素材抽取出的核心闭环

参考素材里真正值得进入底层架构的，不是某一个按钮，而是一条完整的“工作经验复用闭环”：

```text
Conversation / Run / Action / Artifact
        ↓
价值判断与候选提取
        ↓
Memory Capture
        ├─ Knowledge Card
        ├─ Decision / Project State
        ├─ Skill Candidate
        └─ Next Action / Resume State
        ↓
可读、可审阅、可追溯地保存
        ↓
下一次相似任务
        ↓
Retrieval / Ranking / Policy
        ↓
自动建议或注入相关 Knowledge / Skill
        ↓
继续执行并产生新的经验
```

Workbench 将把这条闭环作为长期核心能力，而不是把“记忆”理解为单纯保存聊天记录。

同时吸收以下产品要求：

- **自动沉淀与手动沉淀并存**：系统可以后台形成候选，用户也可以主动点击“沉淀本次对话 / 本次工作”；
- **知识与 Skill 必须可读**：AI 生成的 Knowledge Card、Decision、Skill 不应成为不可检查的黑盒向量；
- **相似任务自动复用**：再次处理类似工作时，Context Broker / Memory Gateway 可以检索并推荐或注入之前的 Knowledge / Skill；
- **下一步行动必须持久化**：AI 规划出的 Next Actions 应进入 Work Item / Work Capsule，而不是只存在于聊天气泡；
- **Artifact 可视化**：视频、图片、文档、Diff、3D 资产等应尽可能通过对应 Viewer 打开，而不是只显示路径；
- **知识关系可视化**：Knowledge Graph 属于后续 Knowledge Surface 的投影能力，不是 Memory Store 的唯一存储模型；
- **专家 / 风格是可调用配置层**：它们作用于 Personal Agent / 当前 Run，而不是复制出另一套 Agent 产品；
- **新闻 / 热点发现是独立模块**：可接入近几日热点抓取、聚合与研究，但不侵入 Agent 核心执行链。

## 2.3 DeepSeek Harness 的关键特性

DeepSeek Harness 目前是 Developer Preview，核心设计为 **Everything is a Plugin**：模型、工具、Skill、Session、Sandbox、Storage、Agent Loop、UI 等都可以通过 Cordis 插件进行组合。

对本项目最重要的几个能力：

- `ctx.sessions`：append-only Session Event Log；
- `ctx.agents`：Agent 生命周期；
- `ctx.tools`：工具注册和执行管线；
- `ctx.llm`：LLM adapter seam；
- `ctx.subagents`：具名 Subagent Provider 注册表；
- `session/event`：UI 可以据此增量渲染；
- `agent.inject()`：向下一次模型请求注入上下文；
- Profiles / Bundles / Plugins：允许我们不修改上游核心即可扩展。

## 2.4 DeepSeek Harness 已有 Codex 集成

截至当前上游文档，DeepSeek Harness 已提供：

`@deepseek-ai/dsh-subagent-codex`

其工作方式：

1. DeepSeek Harness 父 Agent 产生一个 Codex 子任务；
2. provider 在父 Session 的 cwd 中启动官方 `codex app-server --stdio`；
3. 建立 app-server 协议；
4. 创建临时 Codex thread；
5. 提交一次 Codex turn；
6. 等待完成；
7. 将 Codex 最终答案作为 subagent 结果返回给父 Agent。

当前上游实现适合“一次性 Codex 委派”，但不是完整的持久 Codex 工作台集成。

---


## 2.5 Agent Flow 可视化工作流参考

用户补充的 Agent Flow 参考强调：流程不应只存在于短暂对话里，而应形成可读、可改、可提交的持久步骤文件；同一批步骤可以投影为实时画布，支持节点、分支和内联编辑，并由实时事件同步文件变化。其“逻辑条件由确定性规则/真值表决定，而不是让模型临场发挥”的思路也值得借鉴。

对本项目的借鉴边界：

- **借鉴“协作过程实时可视化”**，但我们的画布展示的不只是静态 STEP.md，而是 Workbench Event Bus 投影出的 Runtime / Agent / Task / Handoff 状态；
- **借鉴“文件/结构化状态是真源，画布是投影”**，避免把画布本身变成唯一不可审计状态；
- Hybrid 流程中的确定性条件（预算、权限、测试是否通过、是否允许自动切换）由 Workbench Policy / condition evaluator 决定，不交给 LLM 随意判断；
- 未来多 Agent Workflow 可以支持 Markdown/JSON workflow definition，但第一版先从 DeepSeek + Codex 的真实执行链路开始。


## 2.3 Archify 参考价值：可验证流程与系统图，而不是直接充当 Runtime 真源

`tt-a1i/archify` 的价值非常适合本项目，但要明确借鉴边界。Archify 当前把代码仓库或系统描述转换为 **Typed JSON IR**，再经过 Schema / Validator / 布局规则校验，确定性编译为可交互 HTML/SVG；其公开设计支持 Architecture、Workflow、Sequence、Data Flow、Lifecycle 五类技术视图，并强调“交互不编造拓扑”“失败保留最后一份通过校验的成品”“只修改相关结构而非整图重写”。

这些思想与 Workbench 的目标高度一致：

- 流程图必须由真实 Task / Handoff / Event 数据投影，而不是模型自由画图；
- 图形需要稳定 Typed IR，而不是把 Canvas 状态直接当真源；
- Renderer 与 Scheduler / Event Store 解耦；
- 节点、边、状态和来源应可验证；
- 运行中采用局部 patch，不因单个事件全量重建；
- 动效只表达已有状态变化，不制造新的业务语义；
- 可保留 last-good projection，在候选视图异常时不把 UI 直接破坏；
- 可导出静态 / 动态流程快照，用于文档、汇报和审计。

Archify 仓库目前还提供社区 DeepSeek Harness 集成，但该集成本质是 **Skill-only bundle**：通过 DSH 普通 Skill / shell / filesystem 路径生成 JSON/HTML，不提供 Workbench 所需的原生实时 telemetry、Web client、后台事件桥或 Runtime 调度能力。因此本项目不把 Archify 直接作为 Live Collaboration Canvas 的运行时内核。

建议采用两层关系：

```text
Workbench Runtime Truth
Task Graph + Event Store + Scheduler
             │
             ▼
      Flow Projection IR
             │
      ┌──────┴────────┐
      ▼               ▼
Live Canvas      Archify-style Export
实时执行视图       架构/流程/生命周期快照
```

第一阶段优先借鉴其 Typed IR、验证器、渐进披露、路径追踪和可导出思想；后续可评估直接复用其 MIT 许可下的部分 Schema / Renderer / Export 能力，或把 Archify 作为一个可选 Skill/Artifact Generator 接入。

# 3. “Agent 到底是什么”——本项目统一定义

在我们的产品里，**Agent 不是某一个模型名称，也不是 DeepSeek 或 Codex 的别名。**

统一定义：

```text
Agent Run
= Lead Runtime
+ Model / Provider
+ System Instructions
+ Tools
+ Skills
+ Project Context
+ Memory Context
+ Permission Policy
+ Cost Policy
+ Optional Collaborating Runtime(s)
```

`Lead Runtime` 是每个任务或每一阶段真正掌握 Agent Loop 的 Harness，可以是：

```text
DeepSeek Harness
Codex Harness
```

Workbench 本身不执行第三套推理循环，而负责为 Runtime 提供共享控制面。

UI 上建议显示：

```text
AGENT PRESET: Team Agent
RUNTIME MODE: Auto
LEAD RUNTIME: DeepSeek Harness
COST STRATEGY: Balanced
WORKSPACE: /home/user/projects/xxx
HYBRID: Allowed
SESSION BUDGET: ¥5.00
```

如果进入工程任务，可以变为：

```text
RUNTIME MODE: Auto
LEAD RUNTIME: Codex Harness
COLLABORATOR: DeepSeek (on demand)
```

因此，“当前使用谁”是运行时决策，不再被写死成产品架构。

---

# 4. DeepSeek Harness + Codex 的结合方案

## 4.1 方案 A：DeepSeek Harness 永久主导，Codex 只做 Subagent

优点：简单、已有上游能力、开发量小。

缺点：会压扁 Codex Harness 的 Thread、Turn、Diff、Approval、Progress Event 等原生工程能力，也无法让 Codex 在纯工程任务中直接成为 Lead。

结论：**可作为早期兼容路径，但不再作为最终架构。**

## 4.2 方案 B：Codex Harness 永久主导，DeepSeek 只做顾问

优点：Coding 体验强，仓库理解、Shell、Diff、测试、Approval 更自然。

缺点：产品未来包含知识库、专家、风格、研究、内容、新闻、长期记忆等大量非 Coding 工作，Codex 不适合天然承担整个团队工作台的唯一控制面。

结论：**不采用为固定总架构。**

## 4.3 方案 C：双 Harness + Workbench Control Plane（最终方案）

结构：

```text
                         Desktop UI
                             │
                             ▼
                  ┌─────────────────────┐
                  │   Workbench Core    │
                  │   Control Plane     │
                  │                     │
                  │ Router              │
                  │ Shared Context      │
                  │ Memory              │
                  │ Event Bus           │
                  │ Permissions         │
                  │ Cost Policy         │
                  │ Usage Ledger        │
                  │ Runtime Manager     │
                  └─────────┬───────────┘
                            │
                  ┌─────────┴─────────┐
                  ▼                   ▼
          DeepSeek Harness      Codex Harness
          General Runtime       Engineering Runtime
```

关键原则：

1. 两个 Harness 都是一等公民 Runtime；
2. 一次任务默认只选一个 Lead Runtime；
3. Hybrid 只在任务确有必要时启动；
4. Workbench 不实现第三套 Agent Loop；
5. Project Context、Memory、预算、权限、事件与长期状态属于 Workbench，而不是某个 Harness；
6. 系统可以自动推荐 Runtime，但用户可以手动指定。

结论：**Accepted，作为当前目标架构。**

## 4.4 Lead Runtime 选择

典型路由：

```text
研究 / 写作 / 知识 / 项目规划
→ DeepSeek Harness Lead

代码理解 / Debug / 修改 / 测试 / Refactor
→ Codex Harness Lead

产品设计 + 大规模实现
→ Hybrid
   DeepSeek Plan
   → Codex Implement
   → DeepSeek Review
```

Hybrid 也允许反向发起，例如 Codex 先扫描仓库，再把架构问题交给 DeepSeek 分析。

---

# 5. 最终推荐架构

## 5.1 核心原则

### 原则 1：Workbench Core 是薄控制面，不是第三个 Harness

Workbench Core 只负责：

- Task Router；
- Runtime Manager；
- Shared Project Context；
- Memory / Vault；
- Unified Event Bus；
- Permission Policy；
- Cost Policy Engine；
- Usage Ledger；
- Team / Project / User / Session 配置合并；
- UI ViewModel。

真正的 Agent Loop 始终由 DeepSeek Harness 或 Codex Harness 执行。

### 原则 2：双 Harness 是“能力池”，不是“双倍执行”

默认策略：

> **Single Runtime First, Hybrid on Demand.**

能由单一 Harness 完成的任务，不自动启动第二个 Harness。

### 原则 3：用户保留 Runtime 最终选择权

运行模式：

```text
Auto
DeepSeek
Codex
Hybrid
```

- `Auto`：Router 根据任务与 Policy 自动选择；
- `DeepSeek`：强制 DeepSeek Harness 作为 Lead；
- `Codex`：强制 Codex Harness 作为 Lead；
- `Hybrid`：允许两个 Runtime 协作。

### 原则 4：成本策略与 Runtime 选择分离

成本策略：

```text
Economy
Balanced
Quality
Custom
```

Runtime Mode 回答“谁来跑”；Cost Strategy 回答“允许花多少钱、何时升级、是否允许自动 Hybrid”。两者不能混为一个设置。

### 原则 5：共享上下文和长期记忆属于 Workbench

```text
              Workbench Context / Memory
                      │
              ┌───────┴───────┐
              ▼               ▼
       DeepSeek Context    Codex Context
```

这样后续替换模型、升级 Harness 或增加 Claude Code / Gemini / Local Agent 时，不会丢失项目状态。

---


### 原则 6：协作必须可视、可解释、可回放

Hybrid 不能只在后台表现为“DeepSeek 调了 Codex，然后返回一段结果”。Agent 页面必须显式显示：

```text
谁在做？
做什么？
为什么交给它？
当前做到哪一步？
正在等待什么？
产生了哪些工具 / 文件 / 测试 / 决策结果？
什么时候发生 Runtime Handoff？
成本由谁产生？
```

第一版先做到 **阶段级可视化**；Codex Direct Adapter 和更完整事件流接入后，再升级到命令、文件、Diff、Approval 等细粒度可视化。



### 原则 7：性能预算优先于功能堆叠

工作台后续会同时承载 Agent、知识库、专家、风格、监控、新闻、自动化、多 Agent、群聊和可视化流程，因此性能不能作为“后期优化项”。第一版开始就要求：

- UI 只渲染当前可见和必要的数据；
- 状态变化采用增量事件更新，不对整个 Session / Canvas 做全量重算；
- 搜索、记忆检索、任务查询依赖索引，而不是遍历所有文件；
- 大型历史记录、日志、Diff、附件和知识库采用分页 / 游标 / 虚拟列表；
- AI Context 使用检索与摘要，不把“整个工作台数据”直接塞进模型；
- Runtime、索引、抓取、Embedding、知识沉淀等耗时任务必须与 UI 主线程隔离；
- 所有高频路径都要有可测量的 latency / CPU / memory budget。

### 原则 8：AI 通过统一 Data Plane 连接整个 Workbench

DeepSeek Harness、Codex Harness，以及未来其他 Agent，不直接各自读取 SQLite、Vault、UI Store 或其他模块私有数据库。统一通过 Workbench Data Gateway 获取能力：

```text
AI Runtime / Agent
       │
       ▼
Workbench Tool / Data Gateway
       │
       ├── Discover resources
       ├── Search / Query
       ├── Read / Snapshot
       ├── Subscribe / Watch
       ├── Mutate (policy-gated)
       └── Execute domain action
       │
       ▼
Project / Session / Memory / Knowledge / Files / Tasks / Usage / Monitor / News / ...
```

关键原则：**AI 拥有“可连接整个工作台”的能力，不拥有“无条件读取一切”的权限。** 实际可访问范围由 Team / Project / User / Session / Task capability 合并决定，并且所有写操作必须可审计。

# 6. 第一版系统架构图

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Linux Desktop App                           │
│                            Tauri v2                                 │
│                                                                     │
│  React / TypeScript UI                                              │
│  Agent / Knowledge / Experts / Style / Monitor / News              │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ Tauri IPC
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Workbench Core                              │
│                                                                     │
│ Task Router          Runtime Manager       Shared Context           │
│ Event Bus            Memory / Vault        Permissions              │
│ Cost Policy Engine   Usage Ledger          Policy Resolver          │
└───────────────┬─────────────────────────────────┬───────────────────┘
                │                                 │
                ▼                                 ▼
┌─────────────────────────────┐     ┌─────────────────────────────┐
│ DeepSeek Harness            │     │ Codex Harness               │
│ General Agent Runtime       │     │ Engineering Agent Runtime   │
│                             │     │                             │
│ Reasoning / Planning        │     │ Repo understanding          │
│ Research / Knowledge        │     │ Shell / Files / Diff        │
│ Skills / General tools      │     │ Test / Debug / Refactor     │
│ Cross-domain work           │     │ Approval / Interrupt        │
└──────────────┬──────────────┘     └──────────────┬──────────────┘
               │                                   │
               └────────────────┬──────────────────┘
                                ▼
                     Project Workspace / Vault
                                │
             ┌──────────────────┼──────────────────┐
             ▼                  ▼                  ▼
        Markdown Vault       SQLite DB        Runtime Logs
```

第一版不要求一次任务同时跑两个 Runtime。Router 只需要实现可靠的单 Runtime 路由与手动选择；Hybrid 在此基础上逐步增加。

---

# 7. 为什么 Linux 第一版建议 Tauri v2

用户要求是**桌面应用，不是网页**。

Tauri 的前端虽然可以使用 Web UI 技术栈，但最终产品是一个桌面程序，有原生窗口、进程管理、文件系统能力与本地 sidecar 管理，不需要用户打开浏览器。

## 7.1 Tauri 的优势

- Linux / Windows 都支持；
- 后面能够复用 UI 到 Android；
- 比 Electron 占用更轻；
- Rust Host 很适合管理 DSH / Codex 子进程；
- 可以限制前端可调用的本地权限；
- 可以做 `.deb` / `.rpm` / AppImage 等 Linux 分发。

## 7.2 Electron 备选

如果早期团队绝大部分工程能力在 Node / TypeScript，Electron 会更快，因为 DSH 本身也是 Node 生态。

但考虑未来 Android，因此当前推荐：

**Tauri v2 + React + TypeScript + Rust host**。

## 7.3 Android 的架构提前约束

Android 版建议分为：

```text
Android UI
   │
   └── Secure Pairing / WebSocket
          │
          ▼
Linux / Windows Workbench Node
          │
          ├── DeepSeek Harness
          └── Codex
```

也就是说 Android 先做 companion client，不尝试把完整开发环境塞进手机。

---

# 8. Agent 页面详细 UX 设计

参考图的核心不是颜色，而是**四层信息密度**：全局模块、项目上下文、主 Agent 流、实时运行状态。

## 8.1 页面总布局

建议桌面窗口最小尺寸：1280×760。这里的四列是**可伸缩信息架构**，不是要求所有面板永久显示；Adaptive Workspace 可以收起第二列或第四列，中央区域也会在 Home / Conversation / Timeline / Canvas 之间切换。

```text
┌────────┬───────────────────┬─────────────────────────────┬──────────────┐
│ Global │ Work / Conversation│ Personal Agent Surface      │ Adaptive     │
│ Nav    │ Rail              │ Home / Conversation / Run   │ Inspector    │
│ 72px   │ ~280px            │ flex                        │ ~320px       │
│        │                   │                             │ optional     │
├────────┴───────────────────┴─────────────────────────────┴──────────────┤
│ Status / Runtime diagnostics（按需）                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

## 8.2 第一列：Global Navigation

第一版可显示全部未来功能，但非 Agent 模块暂时为 disabled / coming soon。

建议：

1. `01 AGENT` — 执行现场
2. `02 知识库` — Knowledge Vault
3. `03 专家` — Expert Presets
4. `04 风格` — Style Presets
5. `05 监控` — Jobs / Automation / Runtime Monitor
6. `06 新闻` — AI News / Research Feed
7. 底部：Settings / Runtime / Update

视觉建议：

- 深色基底；
- 高饱和黄绿色作为 action / selected；
- 蓝色用于 runtime / active process；
- 红色只用于危险/错误；
- 保留工业控制台感，但不要复刻 Boujoy Logo、字体资源或具体装饰。

## 8.3 第二列：Work / Conversation Rail

第二列不暴露 DeepSeek Session / Codex Thread。它是 Personal Agent 的**工作与对话索引**，默认以用户可继续的 `Work Item` 为中心，同时保留精确进入某条 `Conversation` 的能力。

顶部基线：

- `+ 新对话` 主按钮；其下拉菜单可进入 `新工作事项`，未来可进入 `新群聊`；
- 当前范围 `Current Project / Personal / All Projects`；
- Rail 内搜索；
- `概览 / 工作 / 对话` 三个视图；`群聊` 仅在功能启用后出现。

默认 `概览` 不做原始历史流，而只显示：

1. `需要处理`：Approval / Blocked / Failed 等条件触发项；
2. `正在进行`：Active Run / In Progress Work Item；
3. `Pinned`：用户固定的工作；
4. `最近`：少量 Recent Work 与独立 Conversation。

`工作` 视图以 Work Item 为一级条目；Work Item 可展开至最多一层 Conversation 子项。`对话` 视图则展示所有用户 Conversation，并通过 breadcrumb 标识其所属 Work Item / Project。Rail 不允许形成无限递归树。

点击语义固定：

- 点击 `Work Item` → 打开 Work Capsule；
- 展开 Work Item 后点击子 `Conversation` → 打开该具体多轮对话；
- 点击独立 `Conversation` → 打开该对话；
- Runtime Session ID 仅在 Developer Details / Diagnostics 中可见。

`running / waiting_approval / failed` 等执行状态属于 **Run / Work Item projection**，而不是把 Conversation 本身当成 Runtime Session。普通 Conversation 可以只是多轮聊天；一旦产生持久任务，再关联 Work Item / Run。

Rail 自身也遵循性能与渐进披露原则：Materialized Projection + Cursor Pagination + Virtual List；状态通过 Event Bus 增量更新，打开页面不扫描全部历史，也不为排序调用模型。

## 8.4 中央：Agent Timeline

不是传统纯 Chat Bubble，而是 **Conversation + Execution Timeline**。

每一个 turn 可以包含：

```text
User Message
  ↓
Agent Plan
  ↓
Tool Call(s)
  ↓
Codex Delegation (optional)
  ↓
Codex Result
  ↓
Agent Synthesis
  ↓
Final Answer
```

需要有专门的 Codex 子任务卡：

```text
┌ CODING WORKER / CODEX ─────────────────────┐
│ Task: 重构认证模块并补齐测试                  │
│ Status: RUNNING                            │
│ Workspace: /repo                           │
│ Mode: approve-for-me                       │
│ Started: 12:31:08                          │
│                                            │
│ [查看任务] [停止]                           │
└────────────────────────────────────────────┘
```

第一版由于上游 provider 不转发 Codex 中间过程，卡片内部先只展示：

- queued；
- started；
- completed / failed；
- final answer。

后续升级 bridge 后再加入：

- command execution；
- file changes；
- todo；
- Codex progress；
- token usage；
- diff preview。

## 8.5 底部 Composer

建议包含：

- 附件；
- 当前 workspace；
- Agent preset；
- Runtime Mode；
- Cost Strategy；
- 当前预算提示；
- Send；
- Stop。

Runtime Mode：

```text
AUTO
DEEPSEEK
CODEX
HYBRID
```

Cost Strategy：

```text
ECONOMY
BALANCED
QUALITY
CUSTOM
```

高级设置增加：

```text
允许 Agent 自动切换 Runtime: ON/OFF
允许自动进入 Hybrid: ON/OFF
Hybrid 超预算前询问: ON/OFF
单任务预算
每日预算
```

第一版默认推荐：`AUTO + BALANCED`。

## 8.6 右侧 Live Inspector

建议不是单一面板，而是 Tab：

### Live Signal

- Runtime 状态；
- DeepSeek provider；
- Codex provider；
- 当前 turn；
- elapsed time；
- context usage；
- tool calls；
- errors。

### Plan

- 当前目标；
- 当前步骤；
- 完成度；
- 下一步。

### Task Queue

- Background jobs；
- Codex subagents；
- scheduled jobs。

### Context

显示本轮实际注入了哪些：

- project brief；
- knowledge cards；
- skills；
- files。

这个功能很重要，因为它让“AI 为什么知道这些”变得可解释。

### Cost / Usage

显示：

- 当前 Lead Runtime；
- DeepSeek 本轮 / 本会话消耗；
- Codex 本轮 / 本会话消耗；
- Session Total；
- Today Total；
- 单任务预算进度；
- 每日预算进度；
- 是否触发预算警告；
- 是否因为成本策略阻止了 Hybrid。

Hybrid 时应按 Runtime 拆分成本，不只显示总额。

---


## 8.6.1 Adaptive Workspace：按任务需要自动展开工作台

Agent 页不应把 Timeline、Canvas、Task Board、Live Inspector、Group Room 等复杂能力永久全部铺开。界面遵循 **Progressive Disclosure（渐进披露）**：

```text
简单单项任务
User -> One Runtime -> Result
=> 保持轻量 Conversation / Timeline

多步骤任务
User -> Plan -> Task A -> Task B -> Result
=> 自动建议 / 展开 Task Timeline

Hybrid / 多 Runtime
DeepSeek -> Codex -> Review
=> 自动建议 / 展开 Collaboration Canvas + Live Inspector

并行 / 多 Agent / 有依赖
Agent A ─┐
Agent B ─┼-> Merge -> Review
Agent C ─┘
=> 自动建议 / 展开 Canvas / Task Board
```

### 触发展开的信号

首版不依赖一个额外大模型做 UI 决策，而由 Workbench 根据可观测任务状态判断，例如：

- `task_count > 1`；
- 出现 `handoff`；
- `runtime_count > 1`；
- 出现并行任务或依赖边；
- 出现 `approval.requested`；
- 出现长时间运行的 command / tool；
- 出现多个 Agent / Group Room；
- 用户主动进入 Canvas / Inspector。

### 交互原则

- **AI 可以建议，不应劫持界面。** 自动展开应尽量是可预测的 UI 行为，而不是模型随意改变布局。
- **用户拥有最终控制权。** 用户可手动展开、关闭、固定（Pin）某个面板；一旦用户锁定布局，本次 Session 不再自动覆盖。
- **复杂度按需出现。** 单 Agent、单步骤任务不显示空白 Canvas，也不显示没有意义的 Task Board。
- **状态不因视图关闭而丢失。** Canvas / Inspector 是 Event Log 的投影；收起只影响 UI，不影响任务执行。
- **完成后可自动收束。** 当协作阶段结束后，可将工作台折叠为一张 Run Summary / Collaboration Summary，避免页面永久膨胀。

这个机制的目标不是“AI 自动切 UI 炫技”，而是让界面复杂度与任务复杂度同步增长。

## 8.7 Collaboration Canvas（协作画布）

这是 Agent 页新增的核心视图。Hybrid / 多 Runtime 协作不能仅依赖聊天气泡表达，而需要一张 **实时执行图**。

### 8.7.1 目标

用户打开协作画布后，应当在 3 秒内回答四个问题：

1. 当前有哪些 AI / Runtime 在参与？
2. 每个 AI 正在负责什么？
3. 当前主路径进行到哪里？
4. 有无等待、失败、预算/审批阻塞？

### 8.7.2 第一版节点类型

```text
USER / INPUT
DEEPSEEK_AGENT
CODEX_AGENT
TASK
HANDOFF
CONDITION
TOOL / COMMAND
OUTPUT
ERROR
APPROVAL
```

P0 不要求所有类型都能手工创建；其中 `DEEPSEEK_AGENT / CODEX_AGENT / TASK / HANDOFF / OUTPUT / ERROR` 必须能由真实运行自动生成。

### 8.7.3 节点视觉状态

```text
QUEUED       灰色 / 未开始
RUNNING      高亮 + 活动指示
WAITING      黄色 / 等待输入、审批或前置任务
COMPLETED    已完成
FAILED       红色 / 可展开错误
CANCELLED    中止
SKIPPED      被条件或策略跳过
```

每个 Agent/Runtime 节点至少显示：

- 名称与 Runtime；
- 当前角色（Lead / Collaborator / Reviewer / Worker）；
- 当前任务摘要；
- elapsed time；
- token / cost（如果可获得）；
- 当前状态；
- 最近一个关键事件；
- 点击后进入 Inspector。

### 8.7.4 连线语义

连线不是装饰，必须有语义：

```text
solid      正常任务流 / handoff
dashed     条件分支 / optional
blocked    等待 / approval
error      failure path
```

连线可以标记：

```text
PLAN
IMPLEMENT
REVIEW
PASS
FAIL
APPROVED
DENIED
FALLBACK
```

### 8.7.5 Hybrid Standard 示例

```text
[User Task]
     │
     ▼
[DeepSeek / Planner]  RUNNING
     │ implementation brief
     ▼
[Handoff]
     │
     ▼
[Codex / Engineer]    RUNNING
     │ files + tests + diff
     ▼
[DeepSeek / Reviewer] QUEUED
     │
     ▼
[Final Output]
```

当 Codex 执行时，DeepSeek Planner 节点保持 `COMPLETED`，Codex 节点高亮；进入 Review 时高亮迁移到 DeepSeek Reviewer。用户不需要读聊天记录就能理解协作进度。

### 8.7.6 画布与 Timeline 的关系

Agent 页面提供两种互补视角：

```text
Timeline = 时间顺序，适合阅读对话和细节
Canvas   = 任务拓扑，适合理解协作关系和进度
```

二者使用同一个 `WorkbenchEvent` 数据源，不维护两份状态。点击画布节点可定位 Timeline 对应事件；点击 Timeline 中的 Handoff / Agent 卡片可聚焦画布节点。
### 8.7.7 P0 / 后续边界

**P0：**

- 自动生成 DeepSeek / Codex 节点；
- 自动生成任务与 Handoff 边；
- 实时状态更新；
- 点击节点查看任务、事件与成本；
- Hybrid Lite / Standard 可视化；
- 错误、等待审批、取消状态可见。

**P2+：**

- 用户拖拽创建/重排节点；
- 可编辑工作流；
- condition / merge / loop；
- workflow template；
- 运行前模拟与估算成本；
- 多 Agent 并行泳道；
- 持久化 Workflow Definition。

## 8.8 多 Agent 协作与 Agent 群聊（需求记录 / 后续专题）

Agent 页面未来不仅有单 Agent 会话，也需要 **Group / Room** 概念。当前先记录需求，不在本轮确定完整交互。

### 已确认需求

- 用户可以手动创建一个多 Agent 群聊；
- 用户可以选择群聊中有哪些 Agent / Runtime / Expert；
- AI 可以根据任务建议创建群聊；
- 在用户授权的策略下，AI 未来可以自动建立临时协作群；
- 群聊中的每个 Agent 应有明确身份、角色、状态与当前任务；
- 群聊不能只是一堆模型自由发言，必须受到任务、成本、权限和轮次策略控制；
- 群聊与 Collaboration Canvas 应共享同一任务/参与者模型；
- 后续多 Agent 协作功能应支持串行、并行、Review、投票/仲裁等模式，但具体协议另开专题讨论。

### 暂不决定的问题

- 群聊是“所有 Agent 都看到全部消息”还是支持私有子线程；
- 谁拥有发言调度权；
- AI 自动拉群是否需要每次确认；
- 是否允许 Agent 自行邀请新的 Agent；
- 多 Agent 成本如何分摊与限额；
- 群聊结束后如何沉淀为项目记忆 / 决策 / Skill；
- 是否存在固定团队模板（产品经理 + 架构师 + 工程师 + Reviewer）。

第一版 Agent 页需要给未来 `Group Chat / Collaboration` 留入口，但可以显示为 `Coming later` 或 feature flag。


# 9. 双 Harness 第一版真正怎么实现

## 9.1 DeepSeek 路径可先复用上游 Codex Subagent

目标 Profile 安装：

```bash
dsh plugin --profile team-workbench add @deepseek-ai/dsh-subagent-codex
```

然后在 Agent preset 中暴露一个 Codex 工具：

```yaml
- id: tool-subagent-codex
  name: '@deepseek-ai/dsh-tool-subagent'
  config:
    provider: codex
    toolName: subagent_codex
    backgroundMode: one-shot
    maxDepth: provider-managed
```

具体 provider 的 `model`、`permissionMode` 等配置要跟随我们锁定的 DeepSeek Harness 版本生成配置，不在 UI 里写死 schema。

## 9.2 Auto Router V0.1

第一版不让某一个 Agent 自己决定是否调用另一个 Harness，也不增加额外分类模型。Workbench Core 使用确定性 Router：

```text
if user.runtime_mode != AUTO:
    use user selected runtime
else:
    classify from task metadata / workspace intent
    apply project + user preferences
    apply cost policy
    choose DeepSeek or Codex
```

初始判断：

- 研究、知识、写作、产品规划、跨领域分析 → DeepSeek；
- 代码修改、仓库理解、Debug、Test、Refactor → Codex；
- 明确跨“规划 + 大规模实现” → 提议 Hybrid；
- 无法可靠判断 → 使用当前项目默认 Runtime，而不是额外花一次模型调用做路由。

## 9.3 为什么第一版仍要实现 Codex Direct Adapter

因为 Codex Harness 已经是我们的一级 Runtime，所以第一版必须具备最小 Codex Direct 能力，而不是只能通过 DSH Subagent 间接调用。

最小统一接口建议：

```ts
interface RuntimeAdapter {
  startTask(input: RuntimeTaskInput): Promise<RuntimeRun>
  cancel(runId: string): Promise<void>
  getStatus(runId: string): Promise<RuntimeStatus>
  subscribe(runId: string, onEvent: (event: WorkbenchEvent) => void): Unsubscribe
}
```

DeepSeek Harness 与 Codex Harness 分别实现 Adapter。DeepSeek Lead 场景仍可保留 `dsh-subagent-codex` 作为 Hybrid Lite 的一种实现路径。

---

# 10. Codex 两种接入路径

## 10.1 DSH Codex Subagent 路径

适合：

- DeepSeek 已经是 Lead；
- 只需要一次清晰的编码委派；
- 不要求完整 Codex 中间事件；
- 追求最小集成成本。

当前上游 one-shot provider 的限制包括：临时 thread、无持久 resume、过程事件有限、父会话主要拿最终结果。

## 10.2 Codex Direct Runtime 路径

适合：

- Coding / Debug / Refactor / Test 本身就是主任务；
- 需要 Codex 原生 Thread / Turn / command / file change / diff / approval / interrupt 等事件；
- 希望 UI 的 Live Signal 直接呈现工程执行现场。

Workbench 通过 Codex app-server Adapter 映射到统一 `WorkbenchEvent`，前端不直接连接 Codex app-server。

## 10.3 两条路径可以共存

```text
DeepSeek Lead + 简单工程委派
→ DSH subagent_codex

Codex Lead
→ Codex Direct Adapter

Hybrid Standard
→ Workbench 编排 DeepSeek / Codex 两个 Runtime 阶段
```

---

# 11. 统一事件模型

**Workbench Event Store / Conversation Event Store 才是跨 Runtime 的产品层事件真源。** DeepSeek Harness Session Event 与 Codex Thread / App Server Event 均作为原生 Runtime 执行证据保留，并由各自 Adapter 映射成统一 `WorkbenchEvent`。任何一个 Harness 的原生日志都不能单独决定用户可见 Conversation、Work Item 或跨设备恢复语义。

工作台基于统一事件维护可重建的 UI / State Projection：

```ts
interface WorkbenchEvent {
  id: string
  conversationId?: string
  workItemId?: string
  runId?: string
  taskId?: string
  timestamp: number
  source: 'dsh' | 'codex' | 'workbench' | 'memory' | 'workspace'
  sourceRef?: string             // DeepSeek session event / Codex thread item / resource ref
  type:
    | 'message'
    | 'plan'
    | 'tool_started'
    | 'tool_finished'
    | 'subagent_started'
    | 'subagent_progress'
    | 'subagent_finished'
    | 'task_started'
    | 'task_completed'
    | 'handoff_created'
    | 'approval_requested'
    | 'approval_resolved'
    | 'artifact_changed'
    | 'workspace_changed'
    | 'memory_written'
    | 'memory_retrieved'
    | 'budget_warning'
    | 'error'
  payload: unknown
}
```

原则：

1. DeepSeek / Codex 原生 Runtime 事件原样保留，作为审计与诊断证据；
2. Workbench 只做稳定、版本化的语义映射，不把某个 Runtime 私有 ID 当成产品层 ID；
3. UI / Collaboration / Resume projection 必须可以从 Workbench Event Store + State Store 重建；
4. Codex 原始协议事件只在 Codex Adapter 层解析，DSH 原始事件只在 DSH Adapter 层解析；
5. 只映射产品需要展示、恢复、同步、审计的信息；
6. 不保存或暴露敏感 private reasoning 原文。

---


## 11.1 Collaboration Graph Event Projection

画布不直接订阅 DeepSeek/Codex 私有协议，而由统一事件投影生成：

```text
agent.spawned
agent.role_changed
agent.started
agent.progress
agent.waiting
agent.completed
agent.failed

task.created
task.assigned
task.started
task.progress
task.completed
task.failed

handoff.created
handoff.started
handoff.completed

condition.evaluated
approval.requested
approval.resolved
budget.warning
```

由 `CollaborationProjection` 把 Event Log 计算成节点、边、状态和进度。这样同一个 Run 可以在 Timeline、Canvas、Monitor 中以不同方式展示，并支持后续回放。


# 12. Project / Workspace 数据模型

`Project` 与 `Workspace` 必须从第一版就在语义上分开：

- **Project** = 逻辑工作上下文：目标、成员、权限、知识、决策、Work Item、配置；
- **Workspace** = 可访问的真实文件 / 执行环境，可以位于本地、服务器、挂载存储或后续镜像环境。

一个 Project 可以没有 Workspace，也可以绑定一个 Primary Workspace 和多个附加 Workspace；一个 Workspace 也可以被多个 Project 以只读或共享方式引用。业务 ID 不依赖绝对路径。

```ts
type WorkspaceKind = 'local' | 'remote' | 'mounted' | 'mirrored'

interface Workspace {
  id: string
  name: string
  kind: WorkspaceKind
  providerId: string
  locator: string              // provider-specific locator，不作为业务主键
  capabilities: string[]       // read/write/watch/upload/download/execute...
  syncState?: string
  createdAt: string
  updatedAt: string
}

interface Project {
  id: string
  name: string
  primaryWorkspaceId?: string
  attachedWorkspaceIds: string[]
  memoryScopeId: string
  defaultAgentPresetId?: string
  createdAt: string
  updatedAt: string
}
```

Workspace 的统一 Provider 语义：

```text
WorkspaceProvider
├─ LocalWorkspace
├─ RemoteWorkspace
├─ MountedWorkspace
└─ MirroredWorkspace   # 后续能力
```

Agent / UI 通过 `workspaceId + resourceId/path` 访问资源；Local 与 Server 的差异由 Provider 和 Capability 层处理，而不是让上层业务写两套逻辑。

---

# 13. Knowledge / Markdown Vault 设计

Markdown 仍然非常重要，但其定位修正为：**长期可读、可迁移、可人工审阅的 Knowledge / Decision / Skill 载体与导出格式之一**，而不是整个 Workbench Memory 系统的唯一存储真源。

建议保留人类可读目录约定：

```text
.vault/
├── 00-Projects/
│   └── <project-id>/
│       ├── PROJECT.md
│       ├── STATE.md
│       ├── DECISIONS.md
│       └── TODO.md
├── 01-Knowledge/
│   └── *.md
├── 02-Skills/
│   └── <skill-name>/
│       └── SKILL.md
├── 03-Prompts/
│   └── *.md
├── 04-Content/
│   └── ...
└── 99-System/
    └── export-metadata.json
```

用途：

- Git / diff / code review；
- 编辑器 / Obsidian / grep；
- 人工审核和可移植备份；
- Knowledge Card、Decision、Skill 的稳定人类可读表达。

但高频 Conversation Event、Runtime Event、同步游标、索引、Usage Ledger、Memory embedding / relation metadata 等不强制直接落成 Markdown。它们使用适合增量写入和查询的结构化 Store，并可按需投影 / 导出为 Markdown。

---

# 14. Memory / 知识沉淀策略

## 14.1 Memory 是平台服务，Capture 是其中一种写入方式

Workbench 通过独立 `Memory Gateway` 管理长期记忆；Markdown Vault、结构化本地存储、服务器 Memory Store、用户后续接入的 AI 集群记忆系统都可以成为后端或投影。

第一版仍建议先提供显式操作：

`沉淀本次对话 / 沉淀本次工作`

流程：

```text
Workbench Conversation/Event Store
+ Work Item / Task State
+ Runtime evidence
+ Artifact / Workspace references
   ↓
Memory Capture Pipeline
   ↓
候选内容
   ├─ Project Memory / State Update
   ├─ Decision
   ├─ Semantic Knowledge
   ├─ Procedural Memory / Skill Candidate
   └─ Preference / Episodic Memory（按 Scope）
   ↓
Preview / Policy / Confirm
   ↓
Memory Gateway
   ├─ Local Memory Store
   ├─ Markdown Knowledge Projection
   └─ Optional Remote / Cluster Memory Backend
```

不建议 MVP 直接“每次对话无条件自动写长期记忆”，避免垃圾记忆、重复、临时结论污染以及敏感数据误沉淀。

## 14.2 后续自动 Capture

规则稳定后可支持：

- 自动提取与去重；
- 重要性 / 置信度评分；
- 低置信度进入 Memory Inbox；
- 高置信度 Project State / Task Result 在权限允许时自动沉淀；
- 通过 `sourceRefs` 保持 Memory 可追溯到 Conversation、Decision、Artifact、Run 或文件。

## 14.3 Memory Reuse Loop：沉淀之后必须能够再次真正使用

长期记忆的价值不在“存了多少”，而在“下一次任务能否正确复用”。因此 Memory Service 必须同时提供 Capture 与 Reuse 两条路径。

```text
Capture Path
Conversation / Work / Run
  -> candidate extraction
  -> classify
  -> deduplicate
  -> confidence / scope / permission
  -> persist
  -> sourceRefs

Reuse Path
Current task
  -> retrieve candidates
  -> relevance rank
  -> freshness / conflict check
  -> token / cost budget
  -> recommend or inject
  -> record usage feedback
```

Reuse 结果至少区分三种行为：

1. `Suggest`：只提示“发现相关知识 / Skill”，由用户决定是否使用；
2. `Auto Attach`：低风险、高置信度内容自动加入 Context Package，并在 UI 中可见；
3. `Execute Skill`：涉及工具执行、写文件、外部系统或高成本动作时，继续经过 Capability / Approval / Budget Policy。

每次复用都记录：`memory_id / skill_id / sourceRefs / used_at / outcome / user_feedback`，用于后续排序与淘汰。禁止因为“以前存过”就永久高权重注入。

## 14.4 Next Action 与 Resume State 必须属于 Work State

AI 可以主动规划下一步，但这些计划不能只留在某次 Conversation 中。建议使用结构化 `NextAction`：

```text
NextAction
├─ id
├─ work_item_id
├─ title
├─ rationale
├─ status
├─ priority
├─ dependencies
├─ suggested_runtime
├─ estimated_cost_band
├─ sourceRefs
└─ created_by (user / agent / rule)
```

它进入 Work Capsule、ResumeIndex 和 Agent Home Projection。这样“接着做上次项目”恢复的是可验证的工作状态，而不是让模型凭聊天摘要猜下一步。默认本地持久化；用户开启同步后按数据 Scope 同步到服务器。

## 14.5 “继续工作”通过 Work Capsule + Context Broker 恢复，而不是回灌全部聊天

恢复某个 Work Item 时，Workbench 先恢复产品状态：

```text
Work Capsule
+ Project State
+ Workspace bindings
+ Task / Run state
+ Artifact pointers
+ Relevant Project / Personal Memory
+ Key Decisions
+ Recent critical conversation excerpts
```

随后由 Context Broker 根据当前任务、Runtime 能力与 Token Budget 构建 `Context Package`。

- DeepSeek Adapter 可使用 DSH 的 context / inject 能力；
- Codex Adapter 使用 Codex thread / turn 输入和可用的 workspace context；
- 其它 Runtime 通过统一 Adapter 接口获取同一个逻辑 Context Package。

因此“继续工作”不依赖某个 Harness 的原生 session resume，也不默认加载整个历史 Conversation。

---

# 15. 检索策略

第一版：

- 文件元数据；
- SQLite FTS；
- tag；
- project binding；
- recency。

第二版再加 embeddings。

推荐相关性评分：

```text
score =
  0.35 * lexical
+ 0.30 * semantic
+ 0.15 * project_match
+ 0.10 * recency
+ 0.10 * manual_priority
```

每次只注入少量最相关卡片，不允许把整个 Vault 塞给模型。

---

# 15A. Runtime Routing 与成本策略

## 15A.1 三个必须分离的概念

```text
Runtime Mode
= Auto / DeepSeek / Codex / Hybrid

Routing Mode
= 自动判断或用户显式选择

Cost Strategy
= Economy / Balanced / Quality / Custom
```

## 15A.2 默认路由策略

V0.1 不使用额外 LLM 作为 Router，优先采用规则与任务元数据，减少成本和不可解释性。

初始规则：

```text
普通问答 / 写作 / 研究 / 规划 / 知识
→ DeepSeek

明确代码仓库操作 / Debug / Refactor / Test
→ Codex

跨产品设计与大型实现
→ 建议 Hybrid；是否自动执行取决于 Cost Policy
```

## 15A.3 Cost Strategy

### Economy

- 单 Runtime 优先；
- 默认禁止自动 Hybrid；
- 必要时才升级 Runtime；
- 预算不足时先请求用户确认。

### Balanced

- 默认模式；
- 通用任务倾向 DeepSeek；
- 工程任务倾向 Codex；
- 复杂任务允许 Hybrid；
- 超过阈值时需要确认。

### Quality

- 结果质量优先；
- 可主动启用规划、实现、Review 多阶段协作；
- 仍受用户硬预算与团队 Policy 限制。

### Custom

允许用户配置：

```text
preferredGeneralRuntime
preferredCodingRuntime
allowAutoSwitch
allowHybrid
hybridApproval
maxTaskCost
maxDailyCost
maxHybridDepth
```

## 15A.4 Hybrid 协作强度

```text
Hybrid Lite
DeepSeek -> Codex

Hybrid Standard
DeepSeek Plan -> Codex Execute -> DeepSeek Review

Hybrid Deep
允许多轮 DeepSeek <-> Codex 协作
```

默认最多使用 `Hybrid Standard`；`Hybrid Deep` 必须显式开启或由团队 Policy 允许。

## 15A.5 Policy 优先级

建议分成“硬限制”和“默认偏好”：

```text
Team Hard Limits
        ↓
Project Policy
        ↓
User Preferences
        ↓
Session Override
```

Session Override 拥有最高的个人临时选择权，但不能突破 Team Hard Limits（例如禁止某 Provider、公司预算上限、数据合规限制）。

## 15A.6 Cost Policy Engine

Cost Policy Engine 不做模型推理，只做确定性策略判断：

```text
Router Recommendation
        │
        ▼
Cost Policy Engine
├─ User Preference
├─ Team Policy
├─ Project Policy
├─ Budget
├─ Runtime Pricing Metadata
├─ Current Usage
└─ Escalation Rules
        │
        ▼
ALLOW / ASK / FALLBACK / DENY
```

价格信息不能硬编码在 Router 中。不同 Provider、账号类型、API 计费方式可能不同，因此使用独立 `RuntimePricingProvider` / pricing metadata 接口；如果无法可靠估价，UI 必须显示“估算不可用”，不能伪造精确金额。

## 15A.7 Usage Ledger

统一记录：

```text
usage.started
usage.updated
usage.completed
budget.warning
budget.exceeded
runtime.escalation_requested
runtime.escalation_approved
runtime.escalation_denied
```

Usage Ledger 是 Workbench 层能力，允许以后加入更多 Runtime 时继续共用。

---

# 16. Workbench Gateway / Runtime Adapters

Workbench 对前端暴露一个由我们控制版本的稳定 Gateway；DeepSeek Harness 与 Codex Harness 各自通过 Adapter 接入。不要把整个 Workbench Gateway 实现成 DSH 专属插件，否则会再次把产品控制面绑到单一 Harness。

```text
Frontend
   ↕
Workbench Gateway / Local RPC
   ├─ DeepSeek Runtime Adapter
   │    └─ optional @our-team/dsh-workbench-adapter/plugin
   ├─ Codex Runtime Adapter
   ├─ Workspace Gateway
   ├─ Memory Gateway
   └─ Sync / Usage / Policy Services
```

Workbench Gateway 职责：

- 暴露本地 RPC / WS / Tauri IPC 边界；
- Conversation / Work Item / Run / Task API；
- Workbench Event subscription；
- Workspace discover / list / read / write；
- Memory search / retrieve / capture；
- Context preview / Context Broker；
- Runtime health / start / cancel / diagnostics；
- Usage / Cost / Approval；
- 不包含第三套 Agent Loop。

DeepSeek Adapter 负责订阅 / 映射 `session/event` 等 DSH 原生接口；Codex Adapter 负责 app-server / thread / turn 原生接口。前端不直接依赖任何 Harness 内部 package API。

---

# 17. 进程模型

Linux MVP：

```text
team-workbench
├─ Tauri main process
├─ DeepSeek Harness process
│  └─ Node runtime
└─ Codex processes (on-demand)
```

Process Supervisor 必须记录：

- executable path；
- version；
- PID；
- port；
- health；
- restart count；
- stderr last N lines。

启动状态机：

```text
BOOTING
  -> CHECKING_RUNTIME
  -> STARTING_DSH
  -> WAITING_DSH_HEALTH
  -> READY
```

失败：

```text
RUNTIME_MISSING
DSH_BOOT_FAILED
DSH_HEALTH_TIMEOUT
CODEX_UNAVAILABLE
AUTH_REQUIRED
CONFIG_INVALID
```

UI 不要只显示一个 spinner，必须给明确诊断。

---

# 18. 运行时版本策略

DeepSeek Harness 当前仍是 Developer Preview，明确会有 breaking changes。

因此不能做：

```text
每次启动 npm install latest
```

必须：

- pin DSH 版本或 commit；
- pin Codex integration protocol baseline；
- Runtime compatibility matrix；
- 升级前跑 contract tests；
- UI 与 DSH 通过我们自己的 Gateway DTO 解耦。

建议维护：

```text
runtime-lock.json
```

示意：

```json
{
  "deepseekHarness": "<pinned-version>",
  "codex": "<tested-version>",
  "gatewaySchema": 1
}
```

---

# 19. Codex 权限设计

第一版 UI 给三种可理解模式，不直接暴露复杂配置：

### Safe

- 只允许有限 workspace 行为；
- 对风险行为失败关闭。

### Auto Approve Workspace

映射到 Codex provider 支持的 `approve-for-me` 类策略。

### Full Access

映射到危险的 bypass 模式；
- UI 显著警告；
- 每 Workspace 单独开启；
- 不作为默认值。

原则：

- permission 是 deployment/workspace policy；
- Agent 不能自己把权限从 Safe 升到 Full Access；
- 子 Agent 权限不得大于 Workspace 允许的上限。

---

# 20. 安全边界

第一版必须：

- 默认只绑定 `127.0.0.1`；
- 前端不能任意执行 shell；
- 文件访问限制在选定 workspace / vault；
- API key 不写入 Markdown Vault；
- 不在 UI 日志输出完整 credential；
- process stderr 做 secret redaction；
- 危险 Codex mode 二次确认；
- 外部 URL / MCP 连接显示来源；
- 任何远程控制功能默认关闭。

后面 Android 配对时才增加：

- pairing token；
- TLS；
- device revoke；
- LAN / relay policy。

---

# 21. Agent 页面内部状态模型

```ts
interface AgentPageState {
  personalAgent: PersonalAgentSummary
  runtime: RuntimeHealth
  project: ProjectSummary | null
  workspace: WorkspaceSummary | null
  conversation: ConversationSummary | null
  workItem: WorkItemSummary | null
  activeRun: RunSummary | null
  timeline: TimelineItem[]
  composer: ComposerState
  inspector: InspectorState
  runningJobs: JobSummary[]
  collaborators: AgentRuntimeSummary[]
  collaboration: CollaborationGraphState
  rooms: AgentRoomSummary[]
  contextSnapshot: ContextSnapshot
}
```

`TimelineItem` 不要与任何单一后端 wire schema 强耦合。

---


基础协作模型：

```ts
interface CollaborationGraphState {
  runId: string
  nodes: CollaborationNode[]
  edges: CollaborationEdge[]
  activeNodeIds: string[]
  updatedAt: number
}

interface AgentRoomSummary {
  roomId: string
  name: string
  mode: 'single' | 'hybrid' | 'group'
  participants: AgentParticipant[]
  status: 'idle' | 'running' | 'waiting' | 'completed' | 'failed'
}
```

`AgentRoomSummary` 在 P0 主要承担未来兼容用途；真正的 Group Chat 编排协议后续单独设计。


# 22. Runtime UI 状态机

所有 Runtime 先映射为统一状态：

```text
CREATED
  ↓
STARTING
  ↓
RUNNING
  ├─ WAITING_APPROVAL
  ├─ COMPLETED
  ├─ FAILED
  ├─ CANCELLED
  └─ TIMED_OUT
```

Codex Direct Adapter 可以追加更细事件：

```text
reasoning / progress
command execution
file changes
diff
todos
usage
approval requests
```

DeepSeek Adapter 则把 DSH Session / Tool / Subagent 等事件投影为同一套 `WorkbenchEvent`。UI 不绑定任何单一 Harness wire schema。

---

# 23. Auto Router 策略

Auto 模式先判断“谁应该成为 Lead”，而不是默认“DeepSeek 是否要委派给 Codex”。

### 倾向 DeepSeek Lead

- 产品讨论；
- 会议总结；
- 文档结构；
- 知识问答；
- 新闻分析；
- 研究与规划；
- 无代码 workspace 的任务。

### 倾向 Codex Lead

- 实现功能；
- 修改 repo；
- 修测试；
- 排查编译错误；
- 重构多个文件；
- 跑测试直到通过；
- 深入代码审查。

### 倾向 Hybrid

- 架构设计后需要大规模落地；
- 复杂工程任务需要独立 Review；
- Codex 扫描代码后需要通用架构推理；
- DeepSeek 规划后需要工程实施与验证。

Route Recommendation 产生后必须经过 Cost Policy Engine，最终得到：

```text
ALLOW / ASK / FALLBACK / DENY
```

---

# 24. 工作流示例

## 24.1 普通讨论：DeepSeek Lead

```text
用户：帮我讨论这个产品下一阶段怎么规划
→ Workbench Router
→ DeepSeek Harness Lead
→ 读取 Project Context
→ 回答
```

## 24.2 开发任务：Codex Lead

```text
用户：把登录模块重构为 OAuth，并补测试
→ Workbench Router
→ Cost Policy: ALLOW
→ Codex Harness Lead
→ 读取 repo / project context
→ 修改代码 + 测试 + diff
→ Workbench 汇总运行事件与结果
```

不需要为了“形式上的主脑”先绕 DeepSeek 一圈。

## 24.3 Hybrid Standard

```text
用户：重新设计插件架构，并完成第一版实现
→ DeepSeek Harness: Plan
→ Workbench Handoff
→ Codex Harness: Implement + Test
→ Workbench Handoff
→ DeepSeek Harness: Review
→ Final
```

## 24.4 Hybrid Lite

```text
DeepSeek Lead
→ 一次性 subagent_codex(task)
→ DeepSeek 汇总
```

## 24.5 Hybrid Deep

允许多轮 `DeepSeek <-> Codex`，但默认关闭，需要显式策略允许，避免成本和执行时间失控。

---

# 25. Git / 文件变更策略

推荐每个高风险 Coding 任务支持独立 worktree：

```text
repo
├─ main working tree
└─ .worktrees/
   └─ agent-<task-id>
```

未来可以把 Codex 子任务自动放在 worktree 中，任务完成后：

- diff；
- tests；
- review；
- merge / apply。

这比多个 Agent 同时直接写主工作目录安全。

MVP 如果暂时不做 worktree，也必须限制同 Workspace 同时只能有一个 write-capable Codex run。

---

# 26. 第一版功能清单（MVP）

## P0 必须

- Linux native desktop window；
- Personal Agent 首页基础状态；
- Workbench Conversation：新建、多轮、历史读取；
- Workbench Event Store / State Store 基础实现；
- Work Item / Run / Task 最小数据模型；
- `继续会话` 与 `继续工作 / Work Capsule` 的基础分离；
- Workspace Provider 抽象 + LocalWorkspace 打开 / 切换；
- 启动 / 停止 DeepSeek Harness；
- 启动 / 连接 Codex Harness / app-server；
- 双 Runtime health；
- DeepSeek Runtime Adapter；
- Codex Direct Runtime Adapter；
- DSH Codex Subagent 兼容路径（Hybrid Lite 可选）；- Tool / command / runtime lifecycle 映射到统一 `WorkbenchEvent`；
- Cancel 当前 Run；
- Adaptive Activity Inspector；
- Hybrid Collaboration Canvas 基础视图；
- DeepSeek / Codex 节点、Handoff、运行状态实时可视化；
- Runtime Mode：Auto / DeepSeek / Codex / Hybrid；
- Cost Strategy：Economy / Balanced / Quality / Custom；
- 本地日志与最小 Usage Ledger；
- Settings：runtime path / model / permission；
- Context Broker 最小接口；
- Memory Gateway 接口骨架，不要求 MVP 完成自动长期记忆。

## P1

- Work Capsule 完整状态页；
- 同一 Work Item 中新开 Conversation；
- ResumeIndex / Recent Work projection；
- 手动“沉淀本次对话 / 本次工作”；
- Knowledge Card / Decision / Project Memory；
- Markdown Knowledge Projection；
- Context Preview；
- FTS search；
- Background jobs；
- RemoteWorkspace 基础 Provider；
- Server Workspace upload / download；
- Personal Agent Private Sync 基础能力。

## P2

- Codex richer progress stream / persistent thread reuse（在上游能力允许时）；
- diff viewer；
- approval UI；
- worktree isolation；
- multi subagent；
- 可编辑 Collaboration Workflow（节点/连线/条件/合并）；
- 多 Agent 并行执行画布；
- Memory 自动 Capture / 去重 / 置信度策略；
- AI 集群记忆系统 Connector；
- Mirrored Workspace / 更完整 Remote execution。

## P3

- 专家；
- 风格；
- 监控；
- 新闻；
- 知识图谱；
- Android remote client。
- Agent Group Chat / Room；
- 用户创建多 Agent 群聊；
- AI 建议/创建临时协作群；

---

# 27. 第一版验收标准

## Runtime

- Linux 首次启动可完成 DeepSeek Harness / Codex Harness 双 Runtime diagnosis；
- 任一 Runtime 异常退出时 UI 明确显示原因；
- DeepSeek 不可用时，在 Policy 允许的情况下 Codex 任务仍可独立运行；
- Codex 不可用时，DeepSeek 普通任务仍可运行；
- RuntimeAdapter 支持 start / cancel / status / events。

## Routing / Cost

- 用户可选择 Auto / DeepSeek / Codex / Hybrid；
- 用户可选择 Economy / Balanced / Quality / Custom；
- Auto 能分别完成一次 `DeepSeek Lead` 与一次 `Codex Lead`；
- 禁止 Hybrid 时系统不会偷偷启动第二个 Runtime；
- 超过预算阈值可产生 ASK / FALLBACK / DENY；
- UI 能按 Runtime 展示 usage / cost ledger。

## Agent

- 用户能在同一 Workbench Conversation 中进行多轮交流，并可跨多个 Run / Runtime 保持同一用户线程；
- UI 能明确显示当前 Lead Runtime；
- Hybrid 时能显示阶段交接；
- 用户可以停止当前 Run；
- Workbench Context 能分别注入两个 Runtime。

## Workspace

- 用户可通过 Workspace Provider 选择 Local Workspace；
- 数据模型已经支持 Remote / Mounted / Mirrored，而不把绝对本地路径写成业务主键；
- Runtime cwd / execution target 能解析到当前 Workspace；
- Agent 通过 Capability Scope 访问 Workspace，不能越权访问未授权资源；
- Server Workspace 上线后，Upload / Download 语义与本地 Import / Export 清晰区分。

## UI

- 1280×760 可用；
- 流式输出时滚动稳定；
- 长对话不会强制抢滚动；
- 运行状态不依赖“输入框是否转圈”来判断。
- Hybrid 运行时，用户无需阅读完整聊天即可从 Canvas 判断当前由谁执行、执行到哪一步、是否发生 Handoff / Waiting / Failure；
- Timeline 与 Canvas 对同一事件状态一致。

---

# 28. 推荐代码仓库结构

```text
team-workbench/
├── apps/
│   └── desktop/
│       ├── src/                  # React UI
│       └── src-tauri/            # Rust native host
│
├── packages/
│   ├── ui/                       # Design system
│   ├── workbench-protocol/       # Shared DTO / schemas
│   ├── runtime-client/           # UI -> Gateway client
│   └── vault-core/               # Markdown model
│
├── dsh-plugins/
│   ├── workbench-gateway/
│   ├── workbench-context/
│   ├── workbench-memory/
│   └── codex-workbench/          # Phase 2
│
├── profiles/
│   └── team-workbench/
│       └── cordis.patch.yml
│
├── docs/
│   ├── architecture/
│   ├── product/
│   └── decisions/
│
├── scripts/
├── tests/
└── runtime-lock.json
```

---

# 29. 技术栈建议

## Desktop

- Tauri v2
- Rust

## UI

- React
- TypeScript
- Vite
- Zustand 或 Redux Toolkit（二选一）
- TanStack Query（RPC/cache）
- CodeMirror / Monaco（后续 diff / Markdown editor）

## Runtime / Plugins

- Node.js
- TypeScript
- DeepSeek Harness / Cordis

## Local storage

- Markdown
- SQLite
- SQLite FTS5

## Protocol

- localhost WebSocket / HTTP RPC
- Tauri IPC 只用于 Native Host 权限与进程控制

---

# 30. 为什么 UI 不直接调用 DSH 内部对象

如果 React 代码直接依赖：

```ts
@deepseek-ai/dsh-xxx
```

那么 DSH 每次 breaking change 都会污染整个应用。

正确边界：

```text
UI
  ↕ stable Workbench Protocol
Gateway Adapter
  ↕ version-specific DSH APIs
DeepSeek Harness
```

Workbench Protocol 由我们控制版本：

```text
v1/session/list
v1/session/open
v1/session/send
v1/session/cancel
v1/runtime/status
v1/context/current
v1/capture/session
```

---

# 31. Source of Truth 规则

必须提前固定。随着架构从“DeepSeek 主会话 + Codex Subagent”演进为“双 Harness 一等 Runtime”，用户可见的 Conversation 不能再绑定到 DeepSeek Harness Session Log。Runtime 原生日志继续保留，但它们是执行证据，不是 Workbench 用户会话的唯一业务真源。

| 数据 | 真源 |
|---|---|
| Personal Agent 用户会话 / Conversation | Workbench Conversation Event Store |
| 用户可见统一执行时间线 | Workbench Event Store / Projection |
| DeepSeek 原生执行细节 | DeepSeek Harness Session / Runtime Log |
| Codex 原生执行细节 | Codex Thread / App Server Runtime Log |
| Work Item / Task Graph 当前状态 | Workbench State Store + 可导出 Markdown Snapshot |
| 长期 Memory | Workbench Memory Service / Memory Store；Markdown 可作为 Knowledge / Decision / Skill 的人类可读投影 |
| Project 当前状态 | Workbench Project State；可投影 / 导出为 Markdown `STATE.md` |
| UI 临时状态 | App Store / SQLite |
| 搜索索引 | SQLite / FTS / Vector Index，可重建 |
| Codex 原生认证 | Codex 原生配置 |
| DeepSeek Provider 认证 | DSH 原生 credential / provider 配置 |

原则：

1. Workbench 拥有跨 Runtime 的用户连续性；
2. Runtime 拥有自己的原生执行日志，Workbench 通过稳定 ID 建立映射；
3. 不让 DeepSeek Session ID 或 Codex Thread ID 成为产品层 Conversation ID；
4. 禁止两个系统同时写同一份业务真源；
5. Markdown 是长期可读、可迁移的重要投影 / Vault 形式，但高频事件、索引和同步状态不强制全部直接写成 Markdown 文件。

---

# 32. 关于“知识卡”和 Skill 的区别

建议产品上明确区分：

### Knowledge Card

“我们知道什么”

例如：

- 某客户的系统限制；
- 项目 API 约定；
- 一次事故的根因；
- 某方案为什么被否决。

### Skill

“我们怎么做”

例如：

- 发布流程；
- 写竞品分析的方法；
- 数据库迁移检查清单；
- 视频脚本生产工作流。

Capture Agent 判断：

```text
fact / decision -> Knowledge
repeatable procedure -> Skill
current progress -> Project State
next action -> TODO
```

---

# 33. Agent 页面后续可以如何扩展到团队模式

未来 Agent 页面可以从单任务单 Lead 进化成运行时协作拓扑，例如：

```text
Workbench Project Run
├─ Lead Runtime: DeepSeek 或 Codex
├─ Coding Worker: Codex（可选）
├─ Research Worker（后续）
├─ QA Worker（后续）
└─ Documentation Worker（后续）
```

Lead 不固定绑定 DeepSeek。默认用户仍从 Personal Agent / Work Item 进入，不因为 Runtime 数量增加就强迫用户打开多个独立 Harness 聊天窗口；当任务真正进入 Hybrid / Multi-Agent 时，再由 Adaptive Workspace 展开 Collaboration Canvas、Task Graph 或 Agent Room。

原则：

**多 Agent / 多 Runtime 是执行拓扑；Conversation、Work Item、Canvas 和未来 Agent Room 是产品层交互对象，不能直接等同于底层 Harness Session。**

---

# 34. 我们现在不应该做的架构动作

1. 不 fork DeepSeek Harness 并长期修改核心 Agent Loop；
2. 不自己复制 Codex session 文件当主会话数据库；
3. 不让前端同时直接连接 DSH WS 和 Codex app-server；
4. 不把全部 Vault 每轮塞进模型；
5. 不直接使用 `latest` runtime；
6. 不第一版开放多 Agent 并发写同一 repo；
7. 不默认启用 `danger-full-access`；
8. 不把 Android 当“缩小版 Linux 运行时”。

---

# 35. 建议的开发顺序

## Milestone 0 — Dual Runtime Spike

目标：证明“双 Harness + Control Plane”成立，不做漂亮 UI。

- Linux 安装并固定 DeepSeek Harness；
- 安装并固定 Codex；
- 实现 `DeepSeekRuntimeAdapter`；
- 实现 `CodexRuntimeAdapter`；
- 统一 `WorkbenchEvent`；
- `Auto -> DeepSeek Lead` 跑通；
- `Auto -> Codex Lead` 跑通；
- 手动 Runtime Override 跑通；
- cancel / crash / restart 基础处理；
- 最小 Usage Ledger。

验收：同一 CLI / 简单页面中，可以不改 UI 入口直接切换两个 Lead Runtime。

## Milestone 1 — Desktop Shell

- Tauri window；
- React layout；
- Process Supervisor；
- Workbench Core；
- 双 Runtime health。

## Milestone 2 — Agent Page

- Personal Agent Home；
- Conversation Rail / Recent Work；
- Multi-turn Conversation；
- Work Item / Work Capsule；
- Runtime Mode；
- Cost Strategy；
- Tool / command / diff cards；
- Adaptive Inspector；
- Composer；
- Usage / Budget。

## Milestone 3 — Hybrid + Project Memory

- Hybrid Lite；
- Hybrid Standard；
- Vault；
- Capture；
- State；
- Continue project；
- Context preview。

## Milestone 4 — Advanced Runtime Collaboration

- persistent Codex app-server；
- richer progress / diff / approvals；
- worktree；
- Hybrid Deep（可选）；
- more runtimes / subagents。

---

# 36. 当前关键技术判断

## 判断 A

**“DeepSeek Harness + Codex Harness”不是把两个代码库合并成一个 Harness。**

正确做法是让 Workbench Core 提供薄 Control Plane，并用 Adapter 接入两个原生 Runtime。

## 判断 B

DeepSeek Harness 与 Codex Harness 都可以成为 Lead Runtime；不把“主脑”永久绑定在任何一方。

## 判断 C

双 Harness 不意味着双倍执行。默认必须是：

> **Single Runtime First, Hybrid on Demand.**

## 判断 D

UI 以 `WorkbenchEvent` 为主，而不是以 DSH Session Event 或 Codex Thread Event 任意一方作为唯一真源。

## 判断 E

长期记忆独立于两个 Harness：Runtime Session 负责原生执行证据，Workbench Memory Service 负责“什么值得长期保留”；Markdown Vault 是其中的人类可读知识投影之一，不是唯一 Memory 后端。

## 判断 F

Router 与 Cost Policy Engine 必须分开：Router 推荐最合适的 Runtime；Policy 决定是否允许、是否询问、是否降级以及是否满足用户预算。

---

# 37. 仍需和产品方确认的问题

以下是当前仍未完全锁定、但不阻塞 Agent Page PRD 的问题。已经解决的“团队使用 / Personal Agent 所有权、Project 与 Workspace 分离、Local First / Private Sync”等不再重复列为开放项。

1. DeepSeek 的具体模型与 Provider 是团队统一配置、个人可选，还是两层覆盖？
2. Codex 认证第一阶段以 ChatGPT 登录、API Key，还是允许两者并存？
3. 第一版代码修改 / Shell 执行的默认 Approval Policy 到什么粒度？
4. Linux 首发目标发行版与打包优先级：Ubuntu 22.04/24.04、Debian、Arch、AppImage / deb / rpm？
5. 团队管理员统一下发 Agent Preset / Skill / Runtime Policy / Cost Budget 时，允许个人覆盖到什么范围？
6. Server Workspace 第一阶段是直接远程文件访问，还是同时要求远程执行能力？
7. Memory Service v1 首先使用哪一种本地实现，以及用户正在建设的 AI 集群记忆系统采用何种 Connector / Protocol 接入？
8. Personal Private Sync 是否第一阶段就支持端到端加密，还是先采用传输加密 + 服务端加密并预留 E2EE？

---

# 38. Decision Log

## D-001 — 主 Runtime

**原决定：** DeepSeek Harness 作为永久主 Agent Runtime。  
**状态：** Superseded by D-007  
**原因：** 后续讨论确认需要完整保留 Codex Harness 的工程执行能力，并允许其在 Coding 任务中直接成为 Lead。

## D-002 — Codex 集成

**原决定：** Codex 只作为 `ctx.subagents` provider，而非第二主 Runtime。  
**状态：** Superseded by D-007  
**保留用途：** DeepSeek Lead 场景下仍可复用该路径作为一种兼容/快速委派方式。

## D-003 — Linux Desktop 技术

**决定：** 优先 Tauri v2。  
**状态：** Proposed / 待团队确认  
**原因：** Linux + Windows + Android 路线更统一。

## D-004 — 长期知识

**原决定：** Markdown Vault 为长期知识真源，SQLite 只做索引。  
**状态：** Superseded / Narrowed by D-036 and D-038  
**新定义：** Markdown 继续作为 Knowledge / Decision / Skill 的重要人类可读载体与可移植投影；长期 Memory 的业务真源由 Workbench Memory Service 管理，可使用本地结构化 Store、Markdown Projection、服务器或 AI 集群记忆后端。

## D-005 — MVP Codex 模式

**原决定：** 只使用上游 one-shot `dsh-subagent-codex`。  
**状态：** Superseded / Narrowed  
**新定义：** 它可以作为 DeepSeek Lead 下的快速 Codex 委派路径，但 Codex Harness 还需要独立 Runtime Adapter。

## D-006 — 高级 Codex

**原决定：** 只通过自定义 DSH provider / bridge 扩展 Codex。  
**状态：** Superseded / Narrowed  
**新定义：** Codex 独立 Runtime 优先通过 Codex app-server Adapter 接入 Workbench Event Bus；DSH provider 作为兼容路径保留。

## D-007 — 双 Harness Control Plane

**决定：** DeepSeek Harness 与 Codex Harness 均为一等公民 Runtime；Workbench Core 作为薄 Control Plane，动态选择 Lead Runtime。  
**状态：** Accepted  
**原则：** `Single Runtime First, Hybrid on Demand`。

## D-008 — Runtime 用户控制

**决定：** 提供 `Auto / DeepSeek / Codex / Hybrid` 四种 Runtime Mode；用户可以覆盖系统自动路由。  
**状态：** Accepted

## D-009 — 成本策略

**决定：** 提供 `Economy / Balanced / Quality / Custom` 四种 Cost Strategy，并将 Cost Policy 与 Runtime Router 分离。  
**状态：** Accepted

## D-010 — 预算与升级

**决定：** 支持单任务预算、每日预算、自动切换 Runtime 开关、自动 Hybrid 开关以及超预算确认。  
**状态：** Accepted

## D-011 — Shared Context Ownership

**决定：** Project Context、长期 Memory、Usage Ledger、统一事件与权限策略由 Workbench 拥有，不能绑定到单一 Harness。  
**状态：** Accepted

## D-012 — Hybrid 强度

**决定：** Hybrid 分为 Lite / Standard / Deep；默认不超过 Standard，Deep 需要显式允许。  
**状态：** Accepted

---


## D-013 — Hybrid 协作可视化

**决定：** Hybrid / 多 Runtime 协作是 Agent 页一级能力，必须通过 Collaboration Canvas 实时展示参与者、任务、状态、Handoff、等待、失败与成本，而不是只在聊天文本里隐式发生。  
**状态：** Accepted

## D-014 — 多 Agent 群聊产品方向

**决定：** Agent 页面后续加入 Agent Group Chat / Room；支持用户手动创建，未来支持 AI 建议或在策略允许时创建临时协作群。完整群聊调度、多 Agent 协议与成本治理后续专题确定。  
**状态：** Requirement Recorded / Architecture Reserved

## D-015 — Canvas / Timeline 单一事件真源

**决定：** Collaboration Canvas 与 Agent Timeline 均由统一 `WorkbenchEvent` / Event Log 投影，不分别维护业务状态。  
**状态：** Accepted


## D-016 — Adaptive Workspace / 渐进披露

**决定：** Agent 页面默认保持轻量；Canvas、Task Board、Live Inspector、Group Room 等复杂工作台能力按实际执行状态自动建议或展开，而不是无论任务复杂度都常驻。自动触发优先依据可观测事件和任务拓扑，用户可随时手动覆盖并锁定布局。
**状态：** Accepted

# 39. 下一步：进入 Agent 页面 PRD

双 Harness、成本控制、Hybrid 可视化、Adaptive Workspace 和未来 Group Chat 的方向已经形成产品基线。下一步正式进入 **Agent Page PRD v0.1**，不再先讨论底层大架构。

PRD 按以下顺序锁定：

1. **页面信息架构**：Global Nav / Work & Conversation Rail / Personal Agent Surface / Collaboration Canvas / Adaptive Inspector / Composer；
2. **Adaptive Workspace**：简单任务保持轻量，复杂任务何时自动展开 Timeline / Canvas / Split / Inspector，以及用户如何覆盖；
3. **新建会话与继续工作流程**：Project / Workspace Context、Conversation Branch、Work Item、Runtime Mode、Cost Strategy；
4. **Auto / DeepSeek / Codex / Hybrid 选择器** 的交互与状态；
5. **Hybrid Collaboration Canvas**：节点、连线、状态、Handoff、点击详情；
6. **Live Inspector**：Runtime / Plan / Context / Cost / Approval / Files；
7. **Agent Timeline 卡片体系**：Message / Plan / Tool / Task / Handoff / Diff / Error / Approval；
8. **Composer**：附件、Workspace、运行策略、发送、停止、审批；
9. **Conversation / Work Item / Run / Task / Runtime Binding 的关系** 与历史恢复；
10. **Group Chat 入口预留**：本版只确定导航与数据结构，不实现完整群聊；
11. **空状态、运行态、等待态、失败态、完成态**；
12. **MVP 验收稿**：从“新建任务”到 Hybrid 执行与可视化的完整 happy path。

PRD 第一轮优先回答：**Agent 页在“简单单项任务”时最小界面保留什么，以及任务复杂度上升后，哪些信号会触发 Timeline / Canvas / Split / Inspector 的逐级展开？** 这将替代“所有工作台模块常驻”的固定布局思路。



# 40. Agent Page PRD v0.1 — 第一轮：最小界面与自适应展开

## 40.1 最小状态：Conversation First

当一次任务只有一个 Runtime、一个主要目标、没有 Handoff / 并行 / 审批 / 长任务时，Agent 页中央只保留最轻量的执行界面：

```text
┌──────────────────────────────────────────────────────┐
│ Agent / Project / Runtime                            │
├──────────────────────────────────────────────────────┤
│                                                      │
│  User                                                │
│  帮我总结这份方案。                                   │
│                                                      │
│  DeepSeek                                            │
│  正在分析…                                           │
│                                                      │
│  Final Result                                        │
│                                                      │
├──────────────────────────────────────────────────────┤
│ [附件] [Auto] [Balanced]                    [发送]    │
└──────────────────────────────────────────────────────┘
```

默认不显示空 Canvas、不显示空 Task Board、不显示无意义的多 Agent 面板。顶部或底部只保留一个轻量 `Activity` 指示，用户随时可以展开完整执行详情。

## 40.2 第一层展开：Execution Detail

当出现工具调用、长命令、文件修改、测试、等待或审批时，不直接进入复杂 Canvas，而是先展开一个轻量 Inspector / Activity Rail：

```text
Conversation                       Activity
                                   ├─ 读取 6 个文件
                                   ├─ 执行 tests
                                   ├─ 修改 2 个文件
                                   └─ 运行中 00:34
```

这是单 Runtime 复杂任务的默认扩展层。

## 40.3 第二层展开：Task / Plan View

出现多个明确步骤、依赖或可恢复任务时，生成结构化 Task View：

```text
[分析] ✓  → [实现] ● → [测试] ○ → [审查] ○
```

Task View 来源于真实 Task State / Event Projection，不允许只从自然语言“猜一个流程图”。

## 40.4 第三层展开：Collaboration Canvas

只有当出现 `handoff`、多个 Runtime、多个 Agent、并行分支、merge、condition 等拓扑关系时，才自动建议 / 展开 Collaboration Canvas。

典型 Hybrid：

```text
[DeepSeek / Planner] ✓
          │ handoff
          ▼
[Codex / Engineer] ●
          │ review
          ▼
[DeepSeek / Reviewer] ○
```

用户可将 Canvas `PINNED`，也可以选择本次 Session `HIDDEN`。

## 40.5 自动展开不是模型自由控制 UI

自适应布局由 `UI Complexity Engine` 根据确定性事件和拓扑计算：

```text
WorkbenchEvent + TaskGraph + UserLayoutPreference
                    │
                    ▼
             UI Complexity Engine
                    │
     ┌──────────────┼──────────────┐
     ▼              ▼              ▼
 Conversation   Inspector      Canvas / Board
```

模型可以通过显式 `ui.suggest_surface` 事件建议某个工作台，但最终是否展开由 UI Policy 决定。

---

# 41. 极致性能 / 算法优化基线

## 41.1 目标不是“跑得快一点”，而是避免功能增长导致复杂度失控

工作台会不断增加资源类型和实时事件。如果每增加一个模块都允许全量扫描、全量订阅、全量重渲染，系统会很快失控。因此采用以下算法与数据结构基线：

### Event Log + Materialized Projection

Runtime 原始事件写入 append-only log；UI 不反复回放全部历史，而维护增量 projection：

```text
Raw Events -> Normalizer -> Indexed Event Store -> Incremental Projections
                                                  ├─ Timeline
                                                  ├─ TaskGraph
                                                  ├─ Canvas
                                                  ├─ Usage
                                                  └─ Live Inspector
```

### 增量更新

- 新事件只更新受影响的实体 / 节点；
- Canvas 布局只对局部新增节点做增量布局，避免每个 token / event 重排全图；
- 汇总计数使用增量 accumulator；
- 大型列表采用 cursor pagination + virtualization；
- 高频 token stream 与低频业务事件分通道，避免 UI 被 token 级事件淹没。

### 索引优先

SQLite / 本地索引至少按以下维度建立查询路径：

```text
session_id
run_id
task_id
agent_id
runtime
timestamp
resource_type
project_id
status
```

全文检索使用 FTS；语义检索使用独立向量索引，不能把 Markdown Vault 全目录逐文件遍历作为线上查询方案。

### Context Budgeting

“AI 能访问整个工作台”使用检索式访问：

```text
Discover -> Search -> Rank -> Read relevant slices -> Summarize -> Inject
```

而不是：

```text
Load everything -> Put everything in prompt
```

这同时降低 latency、token cost 和上下文污染。

## 41.2 初始性能预算（可在实现阶段校准）

以下先作为工程目标，而不是营销承诺：

- 冷启动到可交互：目标 `< 2.5s`（不含首次 Runtime 安装 / 登录）；
- 常用页面切换：目标 `< 100ms` 主观响应；
- 本地 UI 操作反馈：目标 `< 50ms`；
- Event -> 可见 UI projection：P95 目标 `< 150ms`；
- 10k Timeline 事件下滚动保持虚拟化，不一次性创建全部 DOM 节点；
- 1k Canvas 节点时仍必须支持按区域 / 层级折叠、虚拟化或分块显示，禁止无脑全量布局；
- 后台索引、Embedding、抓取不能阻塞 UI thread；
- 空闲状态不持续高 CPU 轮询，优先 event-driven / watch。

这些预算后续需要用 benchmark fixture 持续回归。

## 41.3 性能治理接口

Workbench Core 建议内置：

```ts
interface PerfMetric {
  name: string
  ts: number
  durationMs?: number
  count?: number
  bytes?: number
  tags?: Record<string, string>
}
```

开发模式记录：router latency、gateway query latency、projection latency、canvas layout latency、DB query latency、runtime event lag、memory footprint 等。生产模式采样并默认本地保存，可由用户决定是否导出。

---

# 42. Workbench Data Plane：让 AI 连接整个工作台的数据

## 42.1 设计目标

AI 应能理解并操作“整个工作台”，包括当前和未来的：

- Projects / Workspaces；
- Sessions / Runs / Turns；
- Tasks / Plans / Handoffs；
- Agents / Agent Presets / Groups；
- Knowledge / Memory / Skills / Experts / Styles；
- Files / Artifacts / Diffs；
- Usage / Budget / Runtime health；
- Monitor / Jobs / Automation；
- News / Research results；
- 用户允许开放给 Agent 的其他本地数据源。

但模型不直接接触数据库 schema，也不直接读取前端状态容器。

## 42.2 统一接口分层

```text
┌──────────────────────────────────────────────┐
│ DeepSeek / Codex / Future Agent             │
└──────────────────────┬───────────────────────┘
                       │ Agent Tools
                       ▼
┌──────────────────────────────────────────────┐
│ Workbench Tool Gateway                      │
│ AI-friendly semantic tools                  │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│ Workbench Data API                          │
│ Discover / Query / Read / Search / Watch    │
│ Mutate / Action                             │
└──────────────────────┬───────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       SQLite        Vault      Domain Services
       Indexes       Files      Runtime / Jobs / ...
```

其中：

- **Data API** 面向内部程序，是稳定的数据访问合同；
- **Tool Gateway** 面向 AI，把底层 API 组合成语义清晰、参数受限、可审计的工具；
- UI 也应尽量通过 Domain API / Query 层访问业务数据，不直接绕过业务规则。

## 42.3 通用资源接口

建议定义统一 Resource Envelope：

```ts
type ResourceRef = {
  type: string
  id: string
  projectId?: string
  version?: string
}

type ResourceEnvelope<T = unknown> = {
  ref: ResourceRef
  data: T
  updatedAt: number
  etag?: string
  permissions: string[]
}
```

通用读取能力：

```ts
interface WorkbenchDataApi {
  discover(input: DiscoverInput): Promise<ResourceTypeDescriptor[]>
  get(ref: ResourceRef, opts?: ReadOptions): Promise<ResourceEnvelope>
  query(input: QueryInput): Promise<Page<ResourceEnvelope>>
  search(input: SearchInput): Promise<SearchHit[]>
  snapshot(input: SnapshotInput): Promise<Snapshot>
  subscribe(input: SubscribeInput, cb: (e: DataEvent) => void): Unsubscribe
}
```

写入与动作能力必须分离并经过 Policy：

```ts
type ActionContext = {
  userId: string
  agentId?: string
  conversationId?: string
  roomId?: string
  missionId?: string
  projectId?: string
  originTurnId?: string
  requestId: string
}

interface WorkbenchMutationApi {
  mutate(input: MutationInput, ctx: ActionContext): Promise<MutationResult>
  execute(input: ActionInput, ctx: ActionContext): Promise<ActionResult>
}
```

这样“读数据”和“执行副作用”不会混在一个万能 `run_sql` / `write_anything` 工具里。

## 42.4 AI Tool Gateway 首批工具

AI 侧不建议暴露几十个数据库表工具，而提供稳定的语义工具：

```text
workbench.discover
workbench.search
workbench.get_context
workbench.read_resource
workbench.list_tasks
workbench.read_task
workbench.update_task
workbench.list_sessions
workbench.read_session_summary
workbench.search_knowledge
workbench.read_knowledge
workbench.read_project_state
workbench.list_artifacts
workbench.read_artifact
workbench.get_usage
workbench.get_runtime_status
workbench.create_handoff
workbench.request_surface
```

未来增加 Knowledge / News / Monitor 等模块时，新增 domain tools，不破坏已有 Runtime Adapter。

## 42.5 `get_context` 是核心接口

为了兼顾“AI 能连接所有数据”与成本 / 性能，建议提供一个 Context Broker：

```ts
type ContextRequest = {
  task: string
  projectId?: string
  resourceTypes?: string[]
  maxTokens?: number
  maxItems?: number
  freshness?: 'live' | 'recent' | 'any'
}
```

返回的是经过 Policy + Search + Rank 后的相关上下文包：

```text
Project Summary
Relevant Decisions
Current Tasks
Relevant Knowledge Cards
Selected Files / Artifacts
Recent Session Summary
Runtime / Cost constraints
```

Runtime 仍可进一步调用 `read_resource` 深挖原始内容。

## 42.6 访问与动作边界：全连接，不是全权限

> **v0.36 修正：** Workbench 不使用 `CapabilityToken` 再造一套 Runtime 权限系统。Tool Gateway 收到的是经过登录会话解析的 `ActionContext`，Domain Service 只校验现有 Access Role、资源所有权、Project/Room/Mission Governance、对象状态与业务前置条件；Shell、文件读写、命令执行、Harness 工具调用仍完全交给 DeepSeek Harness / Codex Harness 的原生 sandbox / approval / permission 体系。

因此需要区分两类约束：

```text
Workbench Domain Authorization
= 这个用户 / Agent 是否可以在产品里创建 Room、派 Task、改 Coordinator、发布 Decision 等

Harness Native Permission
= 当前 Runtime 是否可以读写文件、运行命令、调用外部工具等
```

Workbench Control Tool 不持有 API Key、系统密码或 Harness 的“超级权限”。所有产品域写操作继续生成审计事件，例如：

```text
control.command_requested
control.command_validated
control.command_rejected
control.command_committed
```

需要人工确认的产品动作（例如不可逆删除、导出私有数据、扩大预算、邀请外部成员）由对应 Domain Governance 决定；这属于产品业务规则，不是第三套 Runtime Permission Engine。

## 42.7 DeepSeek / Codex 如何使用同一套接口

```text
DeepSeek Harness Adapter ─┐
                         ├─> Workbench Tool Gateway -> Data Plane
Codex Harness Adapter ────┘
```

两个 Harness 不分别维护“知识库插件 A / 项目插件 B”的两套业务逻辑。它们只负责把同一批 Workbench Tools 映射成各自 Harness 能消费的工具协议。这样未来增加第三个 Runtime 时，只写一个 Adapter，不重做整套数据层。

## 42.8 本地进程接口建议

Linux Desktop 第一版建议：

- UI ↔ Tauri Core：Tauri IPC；
- Core ↔ Runtime adapters：优先进程内接口 / stdio / Unix Domain Socket，按 Runtime 真实能力选择；
- 实时事件：内部 Event Bus，跨进程需要时映射为 framed JSON / JSON-RPC；
- 不为了“统一”强行让所有本地模块都走 HTTP；
- Android / 远程客户端阶段再单独增加认证后的 remote gateway。

这有利于减少协议栈开销，同时把远程攻击面留到真正需要时再开放。

---

# 43. 新增 Decision Log

## D-017 — Performance First

**决定：** 极致性能 / 算法效率作为一等公民非功能需求，从第一版开始采用增量 projection、索引、虚拟化、懒加载、事件驱动、Context Budgeting 和后台任务隔离；禁止将全量扫描、全量重渲染、全量上下文注入作为长期实现。  
**状态：** Accepted

## D-018 — Workbench Unified Data Plane

**决定：** AI 可以连接整个工作台的数据能力，但必须通过 Workbench Data API + Tool Gateway 按需访问；DeepSeek、Codex 与未来 Runtime 使用同一语义接口，数据访问受 capability / policy / audit 控制。  
**状态：** Accepted

## D-019 — Full Connectivity != Full Context

**决定：** “可访问整个工作台”与“将全部工作台数据注入模型 Context”严格分离。默认使用 Discover -> Search -> Rank -> Read -> Inject；只有任务真正需要的资源才进入模型上下文。  
**状态：** Accepted



# 46. 面向团队使用的工作台、角色配置与个人主 Agent 模型

## 46.1 三个概念必须彻底分开

本产品是为团队成员共同使用而开发的工作台，但“给团队用”不等于所有 Agent、聊天和个人记忆都属于团队公共数据。后续会面向管理员、开发者、3D 建模、视频制作等不同岗位。为了避免“每个岗位重新做一套产品”，从现在开始将以下概念明确拆开：

```text
Workbench Shell
= 团队成员共同使用的桌面工作台骨架

Role Workspace Profile
= 岗位 / 领域能力配置

Personal Primary Agent
= 每个用户独立拥有的主 Agent
```

它们不是同一个对象。

### 还必须再分开：Access Role 与 Work Profile

“管理员”和“开发者 / 3D / 视频”不是同一维度。

```text
Access Role / Permission Role
= Admin / Owner / Member / Guest / ...
= 决定“允许做什么”

Work Profile / Domain Profile
= Developer / 3D / Video / Operations / ...
= 决定“默认看到什么、使用什么领域能力”
```

同一个用户完全可能是：

```text
Access Role: Admin
Work Profile: Developer
```

或者：

```text
Access Role: Member
Work Profile: Video Creator
```

因此后续数据模型禁止用一个 `role` 字段同时承担权限和工作台配置，否则会导致 UI 配置、RBAC 和 Agent Capability 强耦合。建议：

```ts
type UserWorkbenchContext = {
  accessRoles: string[]
  activeWorkProfileId: string
  availableWorkProfileIds: string[]
}
```

Personal Primary Agent 同时读取两者：Access Role 决定 capability ceiling，Work Profile 决定默认工具、Surface、Skill / Expert Pack 和领域上下文。
### Workbench Shell

所有岗位尽量共用：

- 全局导航；
- Agent 页面；
- 项目 / Workspace；
- Conversation / Activity / Task / Canvas 的自适应展开机制；
- Workbench Data Plane；
- 权限、审计、Usage、预算；
- Runtime 管理；
- 通知、审批、任务恢复；
- 统一视觉语言和布局规则。

目标是让用户从“开发者工作台”切到“视频工作台”时，不像换了一个完全不同的软件。

### Role Workspace Profile

角色配置决定“这个岗位需要什么能力”，而不是复制一套新 UI。

```ts
type RoleWorkspaceProfile = {
  id: string
  domain: 'developer' | '3d' | 'video' | 'operations' | string
  modules: string[]
  tools: string[]
  dataSources: string[]
  defaultSurfaces: string[]
  defaultRuntimePolicy: RuntimePolicyRef
  skillPacks: string[]
  expertPacks: string[]
  shortcuts: string[]
}
```

例如：

```text
管理员 / 开发者
├─ Projects
├─ Repository
├─ Terminal / Runtime
├─ Diff / Test / Monitor
└─ DeepSeek + Codex

3D 建模
├─ Assets
├─ Scene / Object
├─ Render Jobs
├─ Material / Texture
├─ GPU / Queue
└─ 3D Domain Skills / Tools

视频制作
├─ Media Library
├─ Timeline / Shot
├─ Transcript
├─ Render / Export
├─ Review / Version
└─ Video Domain Skills / Tools
```

这些角色仍然使用相同的 Agent 页面和 Adaptive Workspace，只是在任务进入专业领域时自动出现不同的领域 Surface。

## 46.2 Personal Primary Agent：每个用户都拥有独立主 Agent

每个用户拥有一个属于自己的 `Personal Primary Agent`。它不是“管理员公共 Agent”或“开发组公共 Agent”，而是用户自己的长期 AI 入口。

建议模型：

```ts
type PersonalPrimaryAgent = {
  agentId: string
  ownerUserId: string
  displayName: string
  personaProfile: string
  preferredRuntimeMode: 'auto' | 'deepseek' | 'codex' | 'hybrid'
  costStrategy: 'economy' | 'balanced' | 'quality' | 'custom'
  roleProfiles: string[]
  personalMemoryScope: string
  permissionsPolicyRef: string
  uiPreferenceRef: string
}
```

主 Agent 负责：

- 作为用户进入 AI 能力的默认入口；
- 理解用户当前角色、项目、Workspace、任务与权限；
- 访问用户有权访问的 Workbench Data Plane；
- 根据任务选择 / 建议 Runtime；
- 需要时拉起 DeepSeek、Codex 或未来其他 Agent；
- 需要时建议进入 Collaboration Canvas / Group Chat；
- 维护属于该用户的偏好、工作习惯和个人长期记忆；
- 代表用户参与未来的多 Agent 协作，但不能突破用户权限。

## 46.3 “个人 Agent”与团队共享数据必须分层

必须区分四类数据作用域：

```text
Personal
  个人偏好、个人记忆、个人草稿

Project / Team
  项目任务、共享文档、项目决策、团队知识

Organization
  组织策略、公共技能、公共专家、公共模板

Runtime Ephemeral
  当前 Run 的临时上下文、Tool Output、日志
```

个人主 Agent 可以通过 Workbench Data Plane 访问用户授权范围内的 Team / Project 数据，但：

- 个人记忆不会自动变成团队知识；
- 团队私有数据不能因为 Agent 属于某个用户就绕过 RBAC / Capability；
- 不同项目之间的敏感上下文默认隔离；
- 用户离开某项目后，Agent 不应继续获得该项目新数据；
- 写入共享知识库必须遵循团队 Policy / Approval。

因此：

> Personal Agent Identity != Unlimited Data Access

## 46.4 一个用户可以跨角色，但主 Agent 不必重建

建议允许一个用户拥有多个 Role Workspace Profile，例如：

```text
User: Alice
Personal Primary Agent: Alice Agent

Role Contexts:
├─ Developer
├─ Admin
└─ Video Reviewer
```

切换角色时，不重新创建一个“新人格 Agent”，而是让同一个 Personal Primary Agent 切换：

- Role Capability Pack；
- 默认工具；
- 页面 Surface；
- 权限范围；
- Runtime Policy；
- Domain Context。

必要时用户也可以主动创建其他专用 Agent，但那属于未来的 `Secondary Agent / Specialist Agent`，不能和 Personal Primary Agent 概念混淆。

---

# 47. Agent Page PRD v0.2 — 用户打开 Agent 页面第一眼看到什么

## 47.1 核心结论：第一眼看到“我的 Agent”，不是“复杂工作流”

Agent 页面第一屏应该是 **Personal Agent Home / Personal Agent Command Surface**。

默认不应该先展示：

- 空 Canvas；
- 空任务看板；
- Runtime 拓扑；
- 大量 Monitor 指标；
- 所有角色模块；
- 多 Agent 群聊列表。

用户第一眼需要明确三件事：

1. **我正在和谁工作？** —— 我的 Personal Primary Agent；
2. **它现在在哪个工作上下文？** —— 当前 Role / Project / Workspace；
3. **我现在可以让它做什么？** —— 一个极低摩擦的任务输入入口。

## 47.2 Idle / 无运行任务时的首屏

推荐首屏：

```text
┌──────────────────────────────────────────────────────────────────┐
│ TEAM WORKBENCH                                                   │
│ Agent                                                            │
├───────────────┬──────────────────────────────────────────────────┤
│ Global Nav    │  My Agent                         ● Ready         │
│               │  Developer Workspace · Project Alpha             │
│ Agent         │                                                   │
│ Projects      │  下午好。                                        │
│ Knowledge     │  当前项目：Project Alpha                          │
│ ...           │                                                   │
│               │  [继续上次任务]  [查看待处理]                     │
│               │                                                   │
│               │  最近                                             │
│               │  · Agent Page PRD                 12 min ago      │
│               │  · Runtime cost policy            Yesterday      │
│               │                                                   │
│               │  ┌─────────────────────────────────────────────┐  │
│               │  │ 交给我的 Agent…                            │  │
│               │  │                                             │  │
│               │  │ [附件] [Project Alpha] [Auto] [Balanced]  │  │
│               │  └─────────────────────────────────────────────┘  │
└───────────────┴──────────────────────────────────────────────────┘
```

视觉焦点必须是：

```text
Personal Agent Identity
        +
Current Context
        +
Composer
```

而不是各种系统能力。

## 47.3 Header 只显示“必要上下文”，高级信息收起来

首屏 Agent Header 建议只保留：

```text
[Agent Avatar / Name]  ● Ready
Role: Developer
Project: Project Alpha
```

Runtime / Cost 可以在 Composer 里以紧凑控制出现：

```text
[Auto] [Balanced]
```

Harness、Token、Gateway、Context Budget、Capability 等技术细节默认不占首屏，需要时在 Inspector 中查看。

管理员 / 开发者模式可开启 `Developer Details`，显示更深运行信息，但不能成为普通角色的默认界面。

## 47.4 Returning User：优先“接着做”，不要重新寒暄

如果存在可恢复的主要任务：

```text
Last Active Task
Agent Page PRD
Progress 6 / 9
Last active 18 min ago

[继续任务]
[查看状态]
```

这时首屏核心动作不是“新对话”，而是：

> Continue Current Work

Personal Agent 应通过 Workbench Project State / Task State 获取真实进度，不只根据聊天最后一句推断。

## 47.5 Active Run：直接进入正在执行的任务

如果 Personal Agent 当前有活跃 Run，打开 Agent 页面不展示 Home 空状态，直接进入：

```text
Conversation
+ 当前运行状态
```

并根据任务复杂度自适应展开：

```text
single task       -> Conversation
long execution    -> + Activity Inspector
multi-step        -> + Task / Plan
hybrid / multi-AI -> + Collaboration Canvas
```

即：

> Agent Home 是 Idle Surface，不是强制 Landing Page。

## 47.6 Pending Approval / Error 优先级高于普通 Home

如果存在需要用户立即处理的状态：

```text
Approval Required
Codex wants to run deployment command

[Review]
```

或：

```text
Task Blocked
Render worker offline

[查看原因]
```

应该优先显示在 Personal Agent Header / Home 顶部，但不把整个页面改造成告警面板。

## 47.7 角色工作台如何改变 Agent 首屏

基础布局不变，只改变 Domain Context 与 Quick Actions。

### Developer

```text
Current Repo
Open PR / Tests / Runtime
Continue coding task
```

### Admin

```text
System status
Pending approvals
Team jobs
```

### 3D

```text
Current Scene
Render queue
Recent assets
```

### Video

```text
Current Project
Timeline / Shot
Render / Review jobs
```

这些都是 Role Profile 注入的 `Context Card / Quick Action`，不能硬编码成四套页面。

## 47.8 Personal Agent 与未来 Group Chat 的关系

未来多 Agent 群聊中，Personal Primary Agent 可以作为用户的默认 AI 代表：

```text
User
  │
  ▼
Personal Primary Agent
  │
  ├─ DeepSeek Specialist
  ├─ Codex Engineer
  └─ Other Agents
```

但 Group Chat 不替代 Personal Agent Home。用户始终有一个稳定入口，可以：

- 发起新任务；
- 继续旧任务；
- 创建 / 加入 Agent Room；
- 查看 Personal Agent 当前参加的协作；
- 让 Personal Agent 建议需要哪些 Agent。

---

# 48. 新增 Decision Log

## D-020 — Shared Shell + Role Workspace Profile

**决定：** 不同人员不分别复制独立产品；采用统一 Team Workbench Shell。权限维度使用 Access Role，岗位 / 领域维度使用 Work Profile，两者严格分离；Work Profile 控制领域模块、工具、数据源、默认 Surface、Skill / Expert Pack 与 Runtime Policy，Access Role 控制权限上限。  
**状态：** Accepted

## D-021 — Personal Primary Agent Per User

**决定：** 每个用户拥有独立的 Personal Primary Agent，作为长期 AI 入口、个人偏好 / Memory 承载者与未来多 Agent 协作代表；角色变化不要求重建主 Agent，角色能力通过 Role Workspace Profile 注入。  
**状态：** Accepted

## D-022 — Agent Page Opens on Personal Agent Context

**决定：** Agent 页 Idle 状态第一视觉中心是 Personal Agent Identity + Current Role / Project Context + Composer；复杂 Canvas、Task Board、Inspector 继续遵循 Adaptive Workspace 按任务需要出现。存在 Active Run / Approval / Blocker 时，页面优先恢复真实运行状态而不是固定显示 Home。  
**状态：** Accepted


# 49. Local-First Personal Agent Data & Optional Server Sync

## 49.1 核心原则：Personal Agent 默认本地优先

Personal Primary Agent 的聊天、个人记忆、个人偏好、个人草稿与个人运行历史默认首先写入本机数据层。没有显式启用同步时，工作台应能够完全离线运行这些个人能力。

```text
Personal Agent
      │
      ▼
Local Data Layer  ← 默认事实副本
      │
      ├─ Conversations
      ├─ Personal Memory
      ├─ Preferences
      ├─ Run History
      └─ Personal Artifacts

      optional sync
      │
      ▼
Workbench Sync Service / Team Server
```

因此：

> Local First != Local Only

用户可以选择把允许同步的数据上传到团队服务器，使其在新电脑登录后恢复；但“换电脑不丢数据”不能建立在强制云端存储个人聊天的前提上。

## 49.2 数据作用域与默认同步策略

建议最少区分数据所有权，而不是把“共享内容”误称为 Shared Memory：

```text
Agent Private Memory
  每个 Agent 自己的长期记忆；至少由 ownerUserId + agentId 隔离
  默认：Local First
  可选：Private Sync / Cluster Sync

Personal Agent Data
  个人聊天、Work Item、偏好、个人草稿、Run metadata
  默认：Local First
  可选：Private Sync

Project / Team Shared Data
  项目任务、共享文档、Project State、Knowledge、协作产物
  这是共享业务数据，不属于任何 Agent 的 Memory

Organization Shared Data
  团队公共 Skill、Expert、Template、Policy、Knowledge
  默认：Server Managed + Local Cache；仍不进入 Agent 私有 Memory 池

Runtime Ephemeral
  临时 Tool Output、流式日志、中间状态
  默认：Local / TTL；除非审计策略要求，否则不长期上传
```

用户在设置中至少可以看到：

```text
Agent Data

Storage Mode
● Local only
○ Sync my Agent data

Sync Scope
[x] Conversations
[x] Personal memory
[x] Preferences
[ ] Large artifacts

Device
This PC: up to date
Server: last synced 2 min ago
```

## 49.3 同步不是“复制数据库”，而是资源级增量同步

禁止把本地 SQLite 文件整体上传覆盖服务器数据库。同步层使用稳定资源 ID、revision / event id、hash 与 sync cursor 做增量同步。

建议：

```text
Local Change Journal
      │
      ▼
Sync Planner
      │
      ├─ push new immutable events
      ├─ push changed resources
      ├─ pull remote revisions
      ├─ resolve / surface conflicts
      └─ update local sync cursor
```

聊天 / Agent Run 本身优先设计成 append-only event stream，因此跨设备合并成本低；可编辑 Markdown、Project State、Preference 等可变资源使用 revision / ETag / optimistic concurrency。

同步协议必须保证：

- idempotent：重复上传不会生成重复消息 / 任务；
- resumable：网络中断后从 cursor 继续；
- delta based：只同步变化，不全量扫描；
- content-addressable for blobs：大文件按 hash 去重；
- conflict visible：不能静默覆盖用户在另一台电脑上的修改；
- offline capable：断网时本地读写不被阻塞。

## 49.4 隐私、安全与团队权限

“同步到服务器”与“共享业务数据”必须彻底分离；**Agent Memory 本身不提供 Team Share 语义**。

```text
Private / Cluster Sync
= 为换机、多设备恢复、集群检索而同步某个 Agent 的 MemorySpace
≠ 自动共享给其他用户
≠ 自动开放给同一用户的其他 Agent

Team / Project Share
= 把文档、Knowledge、Project State、Artifact 等业务资源发布到 Project / Organization 数据域
= 不等于分享某个 Agent 的私有 Memory
```

Private Sync 数据至少要求：传输加密、服务端加密存储、资源级 owner / access policy、审计日志。后续如果团队对高敏感个人对话有更强要求，可增加 client-side / E2EE 模式，但需要单独评估服务器检索、索引和跨设备恢复的取舍。

## 49.5 Workbench Data API 必须包含 Storage / Sync 语义

AI 可以连接整个工作台，但 API 返回的数据必须带作用域与同步元数据，避免 AI 把个人本地内容误当成团队共享事实。

建议资源元数据：

```ts
type WorkbenchResourceMeta = {
  id: string
  scope: 'personal' | 'project' | 'organization' | 'ephemeral'
  ownerUserId?: string
  projectId?: string
  storage: 'local' | 'synced' | 'server'
  syncState: 'local-only' | 'pending' | 'synced' | 'conflict' | 'error'
  revision: string
  updatedAt: string
}
```

对应接口：

```text
workbench.storage.get_status
workbench.sync.get_status
workbench.sync.push
workbench.sync.pull
workbench.sync.resolve_conflict
workbench.resource.get_meta
```

AI 默认只能“查看同步状态 / 请求同步动作”，不能绕过用户策略擅自把 Personal Private 内容上传或分享。

## 49.6 Agent 页面只轻量呈现同步状态

Personal Agent 首页不能变成云盘管理页。默认只在 Agent Header / 状态区展示紧凑状态：

```text
My Agent   ● Ready
Developer · Project Alpha
Local ✓   Synced 2m ago
```

如果是 Local Only：

```text
Local only
```

如果有异常：

```text
Sync paused / Conflict 1
```

用户点击后才打开详细 Sync Center。

---

# 50. Agent Page PRD v0.3 — 首屏信息层级与 Composer

## 50.1 首屏不强调“团队归属”，强调“个人入口 + 当前工作上下文”

纠正之前容易造成误解的表述：Workbench 是为团队成员共同使用的产品；Personal Agent 是每个用户自己的主 AI 入口。Agent 首屏不需要写成“团队 Agent 首页”，而是：

```text
My Agent
Current Work Profile
Current Project / Workspace
Current Run / Continue Work
Composer
```

团队属性主要体现在权限、共享项目、公共 Skill / Expert、协作和同步层。

## 50.2 推荐 Header

```text
┌─────────────────────────────────────────────────────────────┐
│ My Agent        ● Ready              [Developer ▾] [···]   │
│ Project Alpha · /workspace/project-alpha                   │
│ Local ✓ · Synced 2m ago                                  │
└─────────────────────────────────────────────────────────────┘
```

Header 的职责只有：Agent 身份、运行状态、当前 Work Profile、当前 Project / Workspace、数据状态。

不默认显示 Harness、Token、Context Window、内部 Gateway 等技术细节。

## 50.3 Home 中央区采用“状态优先”，而不是固定卡片堆叠

优先级：

```text
P0  Approval / Blocker / Sync conflict
P1  Active Run
P2  Resumable Work
P3  Suggested / Recent Work
P4  Empty State
```

同一时间首屏只突出一个主要状态，避免未来模块增加后所有卡片一起抢注意力。

## 50.4 Composer 是 Agent 页的永久主操作入口

初版建议：

```text
┌─────────────────────────────────────────────────────────────┐
│ 交给我的 Agent…                                            │
│                                                             │
│ [+]  [Context: Project Alpha ▾]      [Auto ▾] [Balanced ▾] │
│                                              [Send / Stop]  │
└─────────────────────────────────────────────────────────────┘
```

其中：

- `+`：附件 / 文件 / 图像 / 资源；
- `Context`：当前项目、Workspace、选中资源；
- `Auto`：Runtime Mode（Auto / DeepSeek / Codex / Hybrid）；
- `Balanced`：Cost Strategy；
- Send 在运行中切换为 Stop / Interrupt。

Work Profile 不放在 Composer 里，放 Header；否则输入区域会随着岗位扩展不断变复杂。

## 50.5 专业角色能力通过 Context Actions 动态出现

Composer 主结构保持稳定，但可在输入框上方按 Work Profile / 当前上下文出现 2–4 个轻量动作：

Developer：`Attach Repo` / `Run Tests` / `Review Diff`
3D：`Current Scene` / `Render Preview` / `Inspect Assets`
Video：`Current Timeline` / `Transcribe` / `Render Preview`
Admin：`System Status` / `Pending Approval` / `Usage`

这些是配置注入，不是独立页面硬编码。

## 50.6 首屏仍遵循 Adaptive Workspace

首屏开始时保持轻量；只有真实事件出现时才展开 Activity / Task / Canvas。数据同步状态也遵循同一原则：正常时一行状态，冲突时才展开 Sync Conflict Surface。

---

# 51. 新增 Decision Log

## D-023 — Workbench for Team Use, Personal Agent Ownership

**决定：** Workbench 是面向团队成员共同使用的产品，而不是把所有 Agent / 数据都定义成团队公共所有；每个用户拥有自己的 Personal Primary Agent，同时通过 Access Role、Work Profile 与资源 Scope 接入共享能力。  
**状态：** Accepted

## D-024 — Local-First Personal Agent Data

**决定：** Personal Agent 的聊天、个人记忆、偏好与个人运行历史默认 Local First；用户可显式启用 Private Sync 到团队服务器以支持换机 / 多设备恢复。Private Sync 不等于 Team Share。  
**状态：** Accepted

## D-025 — Resource-Level Incremental Sync

**决定：** 跨设备同步使用资源级增量同步、稳定 ID、revision / event id、sync cursor 和 blob hash，不上传整库覆盖；聊天 / Run 优先 append-only，冲突必须可见且可恢复。  
**状态：** Accepted

## D-026 — Agent Page Header + Composer Baseline

**决定：** Agent 页 Header 负责 Personal Agent 身份、Work Profile、Project / Workspace 和紧凑数据状态；Composer 作为永久主操作入口，保留 Context、Runtime Mode 与 Cost Strategy，专业角色能力通过配置化 Context Actions 注入。  
**状态：** Accepted


# 52. Agent Page PRD v0.4 — 最近工作、继续工作、新会话与 Project / Conversation 模型

## 52.1 先锁定产品语义：Project 不是聊天文件夹，Conversation 也不是 Project 状态

Agent 首页如果直接把“项目、会话、任务、Run”混在一起，用户使用一段时间后一定会越来越乱。因此产品层必须明确区分：

```text
Project
= 长期工作上下文 / 资源容器
= 文件、目标、知识、决策、成员、权限、共享状态

Conversation
= 用户与 Personal Agent 的一条连续交互分支
= 对话、消息、操作请求、结果解释

Work Item
= 需要持续推进 / 可恢复的工作事项
= 可以跨多次 Conversation、多个 Run、多个 Runtime

Run
= 一次实际执行周期
= 由一次用户请求、继续执行、审批恢复或自动动作触发

Task
= Run / Work Item 内部可执行的具体子任务
```

核心原则：

> **聊天负责交流，Work Item 负责连续工作，Project 负责长期上下文，Run / Task 负责真实执行。**

## 52.2 Work Item 不是所有聊天都强制创建

为了保持 Agent 页轻量，简单聊天不需要一开始就创建完整“任务对象”。

```text
简单问答
Conversation only

↓ 出现持久工作信号

Conversation + Work Item

↓ 出现执行

Work Item + Run + Tasks

↓ 出现 Hybrid / Multi-Agent

Work Item + Run + Task Graph + Collaboration Projection
```

可触发 Work Item 的信号包括：

- 用户明确“继续做 / 后面接着做 / 记住这个进度”；
- 形成多个 Task / Plan 节点；
- 修改文件、生成关键 Artifact；
- 出现长期运行、等待、Approval、Blocker；
- 一个目标跨越多个 Conversation；
- 用户手动 `Pin / 保存为工作事项`；
- Hybrid / Multi-Agent 协作开始。

因此 Adaptive Workspace 不只控制 UI，也控制数据模型复杂度：简单任务保持简单，真正需要连续性的任务才升级为 Work Item。

## 52.3 推荐实体关系

```text
Personal Agent
│
├─ Conversation A              # 一次简单聊天，可独立存在
│   └─ Runs
│
├─ Project Alpha
│   ├─ Work Item 01            # 例如“完成 Agent Page PRD”
│   │   ├─ Conversation B
│   │   ├─ Conversation C      # 可从同一工作事项新开一条干净分支
│   │   ├─ Runs
│   │   └─ Tasks
│   │
│   └─ Work Item 02
│       └─ ...
│
└─ Personal Work Item          # 不属于某个 Project 也允许
    └─ Conversation D
```

关系规则：

- 一个 Project 可以有多个 Work Item；
- 一个 Work Item 可以有多个 Conversation；
- 一个 Conversation 在某一时间只绑定一个主要 Work Item，但可以读取 Project Context；
- 一个 Conversation 可以包含多个 Run；
- 一个 Run 可以由 DeepSeek、Codex 或 Hybrid 执行；
- Runtime 的切换不创建新的用户 Conversation；
- 新开 Conversation 可以继续绑定原 Work Item，从而获得“新对话窗口 + 同一工作进度”的能力。

## 52.4 “继续工作”不再等同于恢复某条 Conversation，而是打开 Work Capsule

用户点击 `继续工作` 时，不应强制跳回“最后一条聊天”或自动恢复某个底层 Runtime Session。它首先打开一个稳定的 **Work Capsule / 工作胶囊**，展示这项工作的真实状态：

```text
Work Capsule
├─ Work Item current state
├─ Current Project / Workspace binding
├─ Task Graph / unfinished tasks
├─ Conversation branches index
├─ Active / paused Runtime Runs
├─ Pending Approval / Blocker
├─ Relevant artifacts / changed files
├─ Runtime + Cost policy
├─ Memory references / key decisions
├─ User layout preference
└─ Context Package for the next model call
```

进入 Work Capsule 后，用户可以：

- `继续最近对话`：显式打开最近一条 Conversation；
- `在此工作中新开对话`：创建新的 Conversation Branch，但继续绑定同一个 Work Item；
- `直接继续执行`：在无需聊天的情况下从未完成 Task / Run 继续；
- `查看状态`：只浏览进度、Artifact、Memory、任务与历史，而不启动模型。

因此产品上必须明确区分：`继续上次会话` 与 `继续上次工作` 是两个不同动作。前者是 Conversation 级恢复，后者是 Work Item 级恢复。

其中 UI 可以从本地 Event Store 恢复完整历史，但重新调用模型时禁止默认把全部历史逐字重新塞入 Context。Context Broker 应生成：

```text
Work Item Summary
+ Current State
+ Relevant Decisions
+ Pending Tasks
+ Recent Critical Events
+ Required Project Resources
+ Token-budgeted conversation excerpts
```

也就是说：

> **UI 恢复可以完整，模型上下文恢复必须精炼。**

## 52.5 “最近工作”应该以可继续的工作为主，而不是原始 Session 列表

Agent Home 不建议默认展示几十条 Runtime Session。推荐首页只显示 3–6 条高价值 `Recent Work`：

```text
最近工作

Agent Page PRD                    IN PROGRESS
Team Workbench · 8 / 12 tasks
18 min ago

Runtime Cost Design              COMPLETED
Team Workbench
Yesterday

总结 Agent Flow                  CONVERSATION
Personal
2 days ago
```

首页卡片允许混合展示：

- `WORK`：有 Work Item，可继续推进；
- `ACTIVE`：当前正在执行；
- `BLOCKED`：需要用户处理；
- `CONVERSATION`：普通历史对话；
- `COMPLETED`：已完成但近期可能需要回看。

但排序不能简单按 `updated_at DESC`。

## 52.6 Continue Candidate 使用确定性增量排序，不需要每次调用模型

建议维护 `ResumeIndex` / materialized projection，只在相关事件发生时更新候选分数，打开首页时 O(k) 读取 Top-N，而不是扫描全部 Conversation / Task。

第一版权重可以确定性实现：

```text
Priority =
  AttentionWeight       # Approval / Blocked / Error
+ ActiveRunWeight       # 正在运行 / 暂停
+ PinnedWeight          # 用户固定
+ CurrentProjectWeight  # 与当前 Project 相同
+ IncompleteWeight      # 未完成任务
+ RecencyDecay          # 最近使用
+ DueSoonWeight         # 后续有 deadline 时
```

排序结果：

1. 需要用户处理；
2. 当前正在执行；
3. 用户 Pin 的未完成工作；
4. 当前 Project 最近未完成工作；
5. 其它最近工作；
6. 普通历史 Conversation。

AI 可以为卡片生成摘要或建议，但不负责决定核心排序真值，避免额外成本和不稳定。

## 52.7 “新会话”与“继续当前工作”必须是两个明确动作

### 新会话

含义：创建一条新的 Conversation Branch，清空本 Conversation 的短期对话上下文，但不一定离开当前 Project。

默认行为：

```text
Current Work Profile  -> 保留
Current Project       -> 保留（用户可改）
Current Conversation  -> 新建
Previous chat context -> 不直接继承
Project Context       -> 可按需读取
Personal Agent        -> 不变
```

因此“新会话”不等于“完全失忆”。它只表示：

> **不要继续上一条聊天分支，但仍然可以在当前工作环境里工作。**

### 继续当前工作

含义：恢复已有 Work Item + 最新 Conversation + Task / Run 状态。

### 同一工作中新开对话

高级但非常重要的能力：

```text
Work Item: Agent Page PRD

[继续原会话]
[在此工作中新开对话]
```

第二个动作创建新 Conversation，但继续绑定同一个 Work Item。这能避免超长聊天窗口，同时保留工作连续性。

## 52.8 Agent Home 第一眼建议布局

Idle / Returning 状态下推荐：

```text
┌──────────────────────────────────────────────────────────────┐
│ My Agent     ● Ready      Developer ▾     Local ✓ Synced    │
│ Current: Team Workbench / Agent Page                         │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  继续工作                                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ Agent Page PRD                              IN PROGRESS │  │
│  │ Team Workbench · 8 / 12 tasks                         │  │
│  │ Last active 18 min ago                                │  │
│  │                          [继续] [新开对话继续此工作]   │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  最近工作                                      [查看全部]     │
│  Runtime Cost Design       Completed · Yesterday             │
│  Agent Flow Review         Conversation · 2 days ago         │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ 交给我的 Agent…                                       │  │
│  │                                                        │  │
│  │ [+] [Project ▾]                [Auto] [Balanced] [↑]  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

原则：

- 首屏最多突出一个“继续工作”主卡；
- 最近工作只显示少量高价值记录；
- `新会话` 是明确入口，但不与 `继续工作` 抢主视觉；
- Composer 永远可见；
- 有 Active Run / Approval 时继续遵循之前的 P0/P1 优先规则，直接恢复运行现场。

## 52.9 历史页面 / Work & Conversation Rail 不直接暴露 Runtime Session

用户需要的是“我之前做了什么”，不是“DeepSeek Session 17 / Codex Thread 42”。

Agent 历史建议按以下对象组织：

```text
All Work
├─ Active / Blocked
├─ Work Items
├─ Conversations
├─ Group Rooms        # future
└─ Archived
```

并支持：

- 搜索标题 / 内容 / Project；
- Project filter；
- Work Profile filter；
- 时间过滤；
- Active / Completed / Archived；
- Pin；
- Rename；
- Move to Project；
- Convert Conversation -> Work Item；
- Archive；
- Delete（受同步 / 权限策略约束）。

Runtime Session ID 只在 Inspector / Developer Details / Diagnostics 中可见。

## 52.10 本地优先同步必须区分“Agent Data”与“真实 Workspace 文件”

换电脑恢复时必须避免一个错误承诺：同步了聊天与 Agent 状态，不代表本地代码仓库、3D 工程、原始视频素材也自动存在于新机器。

定义两类同步：

```text
Agent Data Sync
├─ Conversations
├─ Work Items
├─ Tasks / Run metadata
├─ Personal memory
├─ Preferences
├─ Summaries
└─ small artifacts / metadata

Workspace Data
├─ Git repository
├─ 3D scene / source assets
├─ raw video / media
├─ large generated files
└─ external project files
```

第一阶段：
- `Agent Data Sync` 可由 Workbench 提供；
- `Workspace Data` 默认仍由 Git、NAS、对象存储、团队文件系统或用户自己的同步方案负责；
- 新设备恢复 Personal Agent 后，如果原 Workspace 不存在，显示 `Workspace disconnected`，引导用户重新绑定 / clone / locate；
- 后续可以增加 Managed Workspace Sync，但不能与 Personal Agent Sync 混成一个概念。

## 52.11 跨设备稳定 ID

为了支持换机继续工作，以下 ID 必须由 Workbench 自己生成并跨设备稳定：

```text
userId
personalAgentId
projectId
workItemId
conversationId
runId
taskId
artifactId
```

DeepSeek Session ID / Codex Thread ID 作为：

```text
runtimeBindingId
```

挂在 Run / RuntimeBinding 下面，而不是反过来决定业务对象身份。

## 52.12 首页性能预算

Agent Home 是高频入口，必须做到近似“读 Projection，不做全量计算”：

```text
Home open
   ↓
read AgentHomeProjection
   ├─ primaryResumeCandidate
   ├─ attentionCount
   ├─ activeRunSummary
   ├─ recentWorkTopN
   └─ syncState
```

更新策略：

- 新事件到达时增量维护；
- Recent Work 只维护 Top-N + 分页索引；
- 卡片摘要缓存，不在每次打开首页重新调用模型；
- 附件 / 大历史 / Workspace 文件按需加载；
- 跨设备同步优先同步 metadata / recent headers，再懒加载正文与大对象。

这与“极致算法优化”的总体原则一致。

---

# 53. 新增 Decision Log

## D-027 — Conversation / Work Item / Project 分层

**决定：** Project 是长期上下文与资源容器；Conversation 是用户与 Personal Agent 的交互分支；只有需要持续推进时才创建 / 升级为 Work Item；Run / Task 表示真实执行。简单聊天不强制承担完整任务模型。  
**状态：** Accepted

## D-028 — Continue Work 恢复 Work Context，而不是只恢复聊天

**决定：** `继续工作` 恢复 Work Item、Project、Task Graph、最新 Conversation、Runtime Run、Artifact、Approval / Blocker 与策略状态；UI 可完整恢复，但模型 Context 由 Context Broker 按预算精炼构建，禁止默认回灌全部历史。  
**状态：** Amended by D-034

## D-029 — New Conversation 保留工作环境但切断短期对话分支

**决定：** `新会话` 默认保留 Personal Agent、Work Profile 与当前 Project，但创建新的 Conversation 并不直接继承旧聊天文本；用户可选择“在当前 Work Item 中新开对话”，在减小上下文的同时保持工作连续性。  
**状态：** Accepted

## D-030 — Recent Work / Continue Candidate 使用增量确定性排序

**决定：** Agent Home 的继续候选与 Recent Work 由 Workbench Projection / ResumeIndex 增量维护，按 Attention、Active、Pinned、Current Project、Incomplete 与 Recency 等确定性信号排序；AI 只可辅助摘要，不作为核心排序真值。  
**状态：** Accepted

## D-031 — Agent Data Sync 与 Workspace Data Sync 分离

**决定：** Personal Agent 跨设备同步负责 Conversation、Work Item、Task / Run metadata、Memory、Preference 等 Agent 数据；代码仓库、3D 源资产、原始视频等 Workspace 大文件第一阶段不默认由 Personal Agent Sync 承担。新设备缺少 Workspace 时恢复 Agent 状态并要求重新绑定实际 Workspace。  
**状态：** Accepted

## D-032 — Workbench 业务 ID 独立于 Runtime Session ID

**决定：** `conversationId / workItemId / runId / taskId` 由 Workbench 生成并跨设备稳定；DeepSeek Session ID / Codex Thread ID 仅作为 Runtime Binding，避免产品数据模型绑定任何单一 Harness。  
**状态：** Accepted

# 44. 参考资料

- DeepSeek Harness 官方项目  
  https://github.com/deepseek-ai/deepseek-harness

- DeepSeek Harness 官方介绍  
  https://www.deepseek.com/harness/

- DeepSeek Harness Architecture  
  https://deepseek-harness.github.io/deepseek-harness/en/reference/

- DeepSeek Harness Subagent  
  https://deepseek-harness.github.io/deepseek-harness/en/reference/subsystems/subagent

- DeepSeek Harness Codex Subagent package  
  https://github.com/deepseek-ai/deepseek-harness/tree/master/packages/subagent/subagent-codex

- OpenAI Codex CLI  
  https://github.com/openai/codex

- Codex app-server  
  https://github.com/openai/codex/tree/main/codex-rs/app-server

- Boujoy Harness  
  https://github.com/asen-goat-mine/boujoy-harness

- 用户提供的 Douyin 演示链接  
  https://www.douyin.com/user/self?from_tab_name=main&modal_id=7674612514622419327&showTab=like

---

# 45. 文档变更约定

以后每次需求变化时：

1. 修改对应章节；
2. 新增或更新 Decision Log；
3. 不删除已经失效的重要决策，而是标记 `Superseded`；
4. 大版本设计变化更新文档版本号；
5. 代码实现与本文不一致时，以明确的新 Decision 为准，而不是静默漂移。



# 54. Workspace / Conversation / Memory 架构修正（Draft v0.9）

## 54.1 Workspace 必须成为一等公民，而不是 Agent 页的附件

用户需要像访问桌面文件管理器一样访问自己的工作环境，但该入口不应被塞进 Agent 页。建议在主导航中独立设置 `Workspace / Files`，Agent 只通过当前上下文引用 Workspace。

```text
Workbench Shell
├─ Agent
├─ Workspace / Files
├─ Projects
├─ Knowledge
├─ Monitor
└─ ...
```

Workspace 对用户表现为统一文件树，但底层允许多种 Provider：

```text
WorkspaceProvider
├─ LocalWorkspace       # 本机目录 / 磁盘
├─ RemoteWorkspace      # 服务器目录 / 远程执行环境
├─ MountedWorkspace     # NAS / SMB / NFS / 其它挂载
└─ MirroredWorkspace    # 本地工作副本 + 服务器同步（后续能力）
```

统一能力接口至少包括：

```text
list
stat
read
write
mkdir
move
copy
delete
search
watch
upload
download
getCapabilities
```

UI 必须明确标识 `Local / Server / Mounted / Mirrored`，避免用户误以为远程文件已经存在于本机。

### Local 与 Server 的利用方式

- **Local Workspace**：低延迟、离线可用，最适合本机代码、个人文件、需要本地 GPU / 工具链的工作；
- **Server Workspace**：适合跨设备恢复、团队共享、大型算力、集中式任务与权限控制；
- **Mirrored Workspace**：后续用于“本地编辑 + 服务器备份 / 执行”，需要独立同步协议和冲突处理；
- Agent Data Sync 与 Workspace Sync 仍然分离，不能因为服务器上有聊天数据就声称服务器上也有完整工作目录。

Agent 通过 `workspaceId + resourceId/path` 引用文件，不直接把本地绝对路径当成业务主键。

## 54.2 Conversation 应该天然支持多轮，但不能把 Runtime Session 当成用户会话

用户侧 `Conversation` 是一个可以持续多轮的长期交互线程：

```text
Conversation
├─ Turn 1
├─ Turn 2
├─ Turn 3
└─ ...
```

一次 Conversation 中可以产生多个 Run，甚至在不同 Run 中切换 DeepSeek / Codex。底层 Harness 是否支持原生 resume，是 Runtime Adapter 的能力问题，不应改变用户层 Conversation 的身份。

```text
Conversation C-17
├─ Run R-1 -> DeepSeek binding
├─ Run R-2 -> Codex binding
└─ Run R-3 -> DeepSeek binding
```

因此：

- 不会每问一句就新建一个 Conversation；
- 用户可以主动新开 Conversation；
- Work Item 可以拥有多条 Conversation Branch；
- 若底层 Runtime Session 可恢复，Adapter 可以复用；若不可恢复，则创建新的 Runtime Binding，并由 Context Broker 重建必要上下文；
- 任何 Harness Session / Thread 都只是实现细节。

## 54.3 “继续会话”与“继续工作”正式拆开

建议产品文案严格区分：

```text
继续上次会话
= 打开同一 Conversation，继续多轮交流

继续上次工作
= 打开 Work Capsule，恢复任务、文件、状态、Memory、Artifact、Run 与 Conversation 索引
```

`继续工作` 不再默认选择某条聊天作为唯一真源。这样能解决：

- 一个工作事项有多条对话时“到底继续哪条”的歧义；
- 上次聊天很长但真正进度已经记录到 Task / Artifact 时的上下文浪费；
- DeepSeek 与 Codex 来回切换导致底层 Session 不一致；
- 换电脑后 Runtime Thread 不可直接恢复的问题；
- 用户只想继续执行，而不想重新进入旧聊天的问题。

## 54.4 Memory 应该升级为 Workbench 平台服务，而不是聊天摘要功能

用户正在建设 AI 集群记忆系统，因此 Workbench 不应把记忆实现写死在 Conversation 或某个 Harness 内。建议提供独立 `Memory Service / Memory Gateway`，允许未来接入现有的集群记忆系统。

```text
DeepSeek Harness ----\
Codex Harness --------> Memory Gateway -> Memory Store / Cluster
Future Agents -------/
```

推荐的记忆分类全部发生在**某一个 Agent 自己的 MemorySpace 内**：

```text
Working Memory      # 该 Agent 当前 Run 的短期工作记忆
Episodic Memory     # 该 Agent 经历过什么：任务、决策、结果、失败
Semantic Memory     # 该 Agent 已沉淀的稳定知识、事实、领域结论
Procedural Memory   # 该 Agent 的 Skill / 可复用流程 / 操作经验
Preference Memory   # 该 Agent 对所属用户的偏好与工作方式理解
Project-scoped Memory # 该 Agent 针对某 Project 的长期经验、约束与上下文
```

不存在产品层 `Shared Memory`。团队共享事实、项目决策、公共 Skill / Expert / Knowledge 属于 Workbench 的共享业务数据层，由 Agent 按权限读取，而不是把多个 Agent 的私有记忆合并成公共记忆池。

核心原则：

> **Memory 不替代 Event Log，也不替代 Conversation History。**

Event Log 负责审计事实；Conversation History 负责完整交流；Memory 负责从历史中沉淀可复用、可检索、可跨会话调用的信息。

每条长期 Memory 至少应保存：

```text
memoryId
scope
type
content / structured payload
sourceRefs
createdAt / updatedAt
confidence
importance
permissions
embedding/index metadata
```

`sourceRefs` 非常关键：AI 使用一条记忆时可以追溯它来自哪次 Conversation、哪条 Decision、哪个文件或 Run，避免记忆逐渐变成无法验证的“传说”。

## 54.5 Memory 与 Continue Work 的关系

恢复工作时，Context Broker 不应该只依赖“上次聊天摘要”。推荐构建：

```text
Resume Context
= Work Item state
+ Task state
+ Current Agent project-scoped memory
+ Current Agent relevant private memory
+ Shared Project Knowledge / Decisions（按权限）
+ Artifact pointers
+ Workspace bindings
+ Recent critical conversation excerpts
```

Memory Retrieval 负责补齐长期背景，Conversation 只提供近期必要片段。这样即使同一个 Work Item 已经存在十几条 Conversation，也不需要把所有聊天重新加载给模型。

## 54.6 Workspace 访问与 Agent 数据访问统一走能力层

AI 可以访问整个工作台，但不直接获得裸数据库或裸文件系统权限。Workspace 也纳入现有 Workbench Tool Gateway：

```text
workbench.workspace.list
workbench.workspace.search
workbench.workspace.read
workbench.workspace.write
workbench.workspace.upload
workbench.workspace.download
workbench.workspace.watch
```

权限继续遵循 Capability Scope，例如：

```text
workspace:read
workspace:write
workspace:upload
workspace:download
workspace:execute
```

Local 与 Server Provider 对 Agent 暴露同一语义接口，Agent 不需要为不同存储位置写两套逻辑。

## 54.7 对 Agent 首页的直接影响

经过以上修正，首页主卡不再使用模糊的“继续上次会话 / 继续工作”二选一文案。建议：

```text
继续工作
Agent Page PRD
8 / 12 tasks · 3 conversations · 2 artifacts
Workspace: Local · Connected

[打开工作] [继续最近对话] [新开对话]
```

如果只是普通 Conversation，没有 Work Item：

```text
最近对话
讨论 Runtime 成本策略
[继续对话]
```

这能让用户清楚知道自己恢复的是“聊天”还是“工作”。

---

# 55. Decision Log — v0.9.1

## D-033 — Workspace 是独立一等公民

**决定：** 用户可在独立 `Workspace / Files` 页面像文件管理器一样访问工作目录；Workspace 可由 Local / Remote / Mounted / Mirrored Provider 提供，Agent 页只引用当前 Workspace，不承担完整文件浏览器职责。
**状态：** Accepted

## D-034 — Continue Conversation 与 Continue Work 分离

**决定：** `继续上次会话` 恢复具体 Conversation；`继续上次工作` 打开 Work Capsule，不强制绑定某条 Conversation 或 Runtime Session。Work Item 可拥有多个 Conversation Branch。
**状态：** Accepted

## D-035 — Conversation 为多轮用户线程，Runtime Session 仅是 Binding

**决定：** 一个用户 Conversation 天然包含多轮交互和多个 Run，可跨 DeepSeek / Codex；Harness Session / Thread 作为 Runtime Binding，不决定 Conversation 身份。
**状态：** Accepted

## D-036 — Memory 是独立平台服务

**决定（v0.16.1 修正）：** Workbench 提供独立 Memory Gateway，但 Memory 的所有权单位是 Agent。每个 Agent 拥有独立 `MemorySpace`，其中可包含 Working / Episodic / Semantic / Procedural / Preference / Project-scoped Memory。不存在跨用户或跨 Agent 的默认 Shared Memory。团队/项目共享知识由 Knowledge / Project State / Workspace 等独立业务层承载。AI 集群记忆系统作为隔离的 MemoryProvider 接入。Memory 不替代 Event Log 或完整 Conversation History。
**状态：** Accepted


## D-037 — Project 与 Workspace 解耦

**决定：** Project 是逻辑工作上下文，Workspace 是真实文件 / 执行环境；二者不再一一绑定。Project 可绑定零个、一个 Primary Workspace 或多个附加 Workspace；Workspace 可由 Local / Remote / Mounted / Mirrored Provider 提供。  
**状态：** Accepted

## D-038 — Memory Service 与 Markdown Vault 分层

**决定：** Workbench Memory Service 是长期记忆的统一业务层；Markdown Vault 保留为 Knowledge / Decision / Skill 的人类可读载体与可移植投影之一，不再承担整个 Memory 系统的唯一真源。  
**状态：** Accepted

## D-039 — Workbench Event Store 是跨 Runtime 产品层真源

**决定：** DeepSeek Session Event 与 Codex Thread / App Server Event 作为原生 Runtime 证据保留；跨 Runtime 的 Conversation、Work Item、Resume 与 UI Projection 以 Workbench Event Store / State Store 为产品层真源。  
**状态：** Accepted

---

# 56. Agent Page PRD v0.5 — Work / Conversation Rail 信息架构

## 56.1 Rail 的定位：不是“聊天历史栏”，而是 Personal Agent 的工作索引

传统 Chat 产品的侧栏通常只是按时间排列 Thread。这个模型不适合本项目，因为一个长期 Work Item 可以跨多个 Conversation、多个 Run、多个 Runtime，而且用户还需要处理 Approval、Blocked、Pinned Work 和未来 Agent Room。

因此第二列正式定义为：

> **Work / Conversation Rail = 当前用户的 Personal Agent 工作索引。**

它解决四个问题：

1. 我现在有哪些事情正在推进；
2. 哪些事情需要我处理；
3. 我想精确回到哪一项工作或哪一条对话；
4. 历史很多以后，如何快速找回，而不是浏览一长串 Harness Session。

Rail 不承担：

- Workspace 文件浏览；
- Runtime 诊断；
- 完整任务看板；
- Knowledge 浏览；
- 全局团队管理。

这些由其它一级页面或 Adaptive Workspace 面板承担。

## 56.2 默认结构：Overview / Work / Conversations，Rooms 后续按 Feature Flag 出现

推荐第二列顶部结构：

```text
┌──────────────────────────────┐
│ AGENT                    ⌘K  │
│ [+ 新对话 ▾]                 │
│ [Team Workbench ▾]           │
│ [概览] [工作] [对话]         │
├──────────────────────────────┤
│                              │
│ 需要处理                     │  # 条件出现
│ ! Agent Page PRD             │
│   等待审批                   │
│                              │
│ 正在进行                     │
│ ▾ Agent Page PRD      8/12   │
│    ├ 首页交互讨论            │
│    └ Memory 讨论             │
│                              │
│ Pinned                       │  # 有内容才出现
│ • Runtime Architecture       │
│                              │
│ 最近                         │
│ ✓ Runtime Cost Design        │
│ 💬 Agent Flow Review         │
│                              │
└──────────────────────────────┘
```

默认不显示空分组。没有 Approval 就不出现“需要处理”；没有 Pin 就不出现 Pinned。

未来 Group Chat / Agent Room 启用时，才增加：

```text
[概览] [工作] [对话] [群聊]
```

MVP 不用 `Coming soon` 长期占据 Rail 宽度。

## 56.3 Overview：智能摘要，不是完整历史

`概览` 是默认视图，但它不显示所有东西。它只展示最高价值对象，推荐顺序：

```text
P0 需要处理
   Approval / Blocked / Error / Conflict

P1 正在运行
   Active Run / Waiting / Paused

P2 Pinned Work

P3 当前 Project 的 In-Progress Work

P4 最近 Work

P5 少量独立 Conversation
```

同一个 Work Item 在 Overview 中只能出现一次。即使它内部有 6 条 Conversation，也不应把 6 条对话再次平铺出来造成重复。

如果用户想进入其中某条 Conversation，可展开该 Work Item 或切换到 `对话`。

## 56.4 Work：一级 Work Item，最多展开一层 Conversation

`工作` 视图是长期工作管理入口，但仍保持轻量。

```text
Work

▾ Agent Page PRD                IN PROGRESS
  Team Workbench · 8 / 12
  ├─ 首页信息架构               18 min
  ├─ Workspace / Memory         42 min
  └─ Runtime Cost               Yesterday

› Linux Runtime Adapter         BLOCKED
  Team Workbench · 3 / 9

› News Collector                COMPLETED
  Internal Tools
```

层级最多：

```text
Work Item
└─ Conversation
```

禁止：

```text
Project
└─ Work Item
   └─ Conversation
      └─ Run
         └─ Task
            └─ Tool Call
```

这种无限树不应该进入 Rail。Project 由 Scope / breadcrumb 表达，Run / Task / Tool Call 进入中央 Surface 与 Inspector。

点击 Work Item 行的主区域：

```text
→ 打开 Work Capsule
```

点击展开后的 Conversation：

```text
→ 精确打开该 Conversation
```

如果 Work Item 当前只有一条 Conversation，也仍保持 Work Item 点击进入 Work Capsule 的语义，不偷偷等同于 Conversation。

## 56.5 Conversations：精确历史入口

`对话` 视图用于用户明确寻找某条聊天，不承担“继续工作”的决策。

```text
Conversations

首页信息架构
Agent Page PRD / Team Workbench
18 min ago

Workspace 与 Memory
Agent Page PRD / Team Workbench
42 min ago

解释 Rust 生命周期
Personal
Yesterday
```

规则：

- 一条 Conversation 是天然多轮；
- 绑定 Work Item 的 Conversation 显示 `Work Item / Project` breadcrumb；
- 独立 Conversation 显示 `Personal` 或 Project breadcrumb；
- Runtime 切换不生成新的 Conversation；
- DeepSeek Session / Codex Thread 不作为列表条目；
- Conversation 可以 Rename / Pin / Archive / Delete；
- Conversation 可显式 `Convert / Attach to Work Item`，但 MVP 可先只实现 Convert。

## 56.6 “新对话”必须简单，但不能把工作关系搞乱

顶部主操作是：

```text
+ 新对话
```

直接点击时：

```text
Personal Agent       保留
Work Profile         保留
Current Project      默认保留，可在 Composer 改
Conversation         新建
Current Work Item    不自动继承
Previous Chat        不直接继承
```

这避免用户只想开一条干净对话，却被系统偷偷继续某个旧 Work Item。

下拉菜单：

```text
+ 新对话
+ 新工作事项
----------------
在当前工作中新开对话   # 仅当前已进入 Work Item 时出现
新群聊                 # future / feature flag
```

其中“在当前工作中新开对话”与普通“新对话”必须是两个清晰动作。

## 56.7 Scope Selector：默认当前 Project，但可一键看全部

Rail 顶部保留一个紧凑 Scope Selector：

```text
[ Team Workbench ▾ ]
```

可选：

```text
Current Project
Personal
All Projects
----------------
Project A
Project B
...
```

原则：

- Project 是逻辑过滤范围，不是树形根节点；
- Workspace 不在这里作为一级导航对象；
- Work Profile 不需要常驻重复过滤，因为它属于页面级工作环境；后续可作为高级 Filter；
- 搜索时用户可切换 `当前范围 / 全部`。

## 56.8 Search：Rail 搜索与全工作台搜索分开

Rail Search 只搜索与当前 Agent 索引相关的内容：

```text
Work Item title / summary
Conversation title / message FTS
Project name
状态 / 标签
```

不默认搜索：

```text
所有 Workspace 文件
全部 Knowledge
所有团队资产
新闻全文
```

这些属于 Global Search / Workbench Search。

Rail Search 的结果仍按对象类型呈现，而不是返回原始数据库命中：

```text
WORK
Agent Page PRD
Matched: "Memory Gateway"

CONVERSATION
Workspace 与 Memory
Matched in message · 42 min ago
```

## 56.9 状态表达：少而明确，不把 Rail 变成监控面板

推荐只保留 5 类用户可理解的状态：

```text
● RUNNING
◐ WAITING
! NEEDS ATTENTION
○ IN PROGRESS
✓ COMPLETED
```

`failed / approval_requested / sync_conflict / runtime_offline` 等详细机器状态，在 Rail 上聚合成 `NEEDS ATTENTION`，点击后由中央 Surface / Inspector 给出原因。

同步状态默认不逐条显示。只有以下情况才显示：

```text
Sync conflict
Remote only / not downloaded
Sync failed
```

正常 `Synced` 不给每一行增加图标，避免视觉噪音。

## 56.10 Work Item 从 Conversation 升级时，Rail 不制造重复项

当一个普通 Conversation 因任务变复杂而升级为 Work Item：

```text
Before
💬 Agent Page discussion

After
▾ Agent Page PRD     IN PROGRESS
   └─ Agent Page discussion
```

Overview 中原 Conversation 条目被 Work Item 替代；Conversation 本身仍然存在，并可在 `对话` 视图或 Work Item 展开后访问。

这样保持：

- Conversation ID 不变；
- 用户历史不丢；
- Overview 不出现重复；
- Work Item 获得稳定的长期入口。

## 56.11 Pin / Archive / Delete 的语义

### Pin

Pin 是个人导航偏好，不改变 Work Item / Conversation 的共享属性。

### Archive

Archive 表示：

> 从默认 Rail / Recent 中隐藏，但继续保留、可搜索、可恢复。

### Delete

Delete 进入 Trash / soft delete，不能直接不可逆删除同步数据。第一版建议保留恢复窗口，最终永久删除再走确认。

### Rename

用户 Rename 是产品层标题真值。AI 后续不得自动覆盖用户手动标题。

## 56.12 标题生成不应为 Rail 增加额外模型成本

第一版标题策略：

1. 立即使用首条用户消息的本地截断标题；
2. 如果已有主 Agent 模型调用，可顺带返回更好的 `suggestedTitle`；
3. 后台可在空闲时做标题优化，但不能阻塞 UI；
4. 用户手动 Rename 后永久优先。

因此打开 / 新建 Rail 条目不需要单独调用模型。

## 56.13 性能基线：Rail 必须是 Projection，不是现场聚合查询

为满足大型长期工作台性能目标，建议维护：

```text
AgentRailProjection
├─ object_id
├─ object_type
├─ title
├─ project_id
├─ work_item_id
├─ status
├─ attention_reason
├─ active_run_id
├─ task_progress
├─ pinned
├─ archived
├─ last_activity_at
├─ resume_score
└─ sync_exception
```

执行原则：

- Event Bus 增量更新 Projection；
- 首页 / Rail 直接读取 Projection；
- Cursor Pagination，不做 offset 深翻页；
- 长列表使用 Virtual List；
- 每次只加载当前 Work Item 展开的 Conversation 子项；
- 搜索走 SQLite FTS / 专用索引；
- 查询可取消，避免快速输入产生过期结果；
- 不通过模型决定排序；
- Active Run 状态通过 event patch 局部更新单行，不刷新整表；
- Project Scope 切换只切索引范围，不重算所有业务状态。

性能目标（工程预算，后续 Benchmark 校准）：

```text
Rail 首屏 Projection query       P95 < 30ms（本地）
单条状态 Event -> Rail patch     P95 < 100ms
本地 FTS 首批搜索结果             P95 < 100ms
10k+ 历史对象                     不允许完整 DOM 渲染
```

## 56.14 不同 Work Profile 共用同一个 Rail 骨架

Developer、3D、Video、Admin 等 Work Profile 不应拥有完全不同的历史导航产品。

统一保留：

```text
Overview
Work
Conversations
Search
Scope
Pin / Archive
```

差异只允许通过配置化 metadata / quick action 增强，例如：

```text
Developer Work Item
repo / branch / test status

3D Work Item
scene / render state

Video Work Item
project / shot / render state
```

这些 metadata 只能是辅助信息，不能改变 Work / Conversation 的基本点击语义。

## 56.15 Rail 与 Agent Home 的关系

Agent Home 是“当前最重要的状态面”，Rail 是“工作索引”。

因此：

- Home 的 `继续工作` 主卡来自 ResumeIndex Top-1；
- Rail Overview 展示更广的 Top-N；
- Work 视图提供完整 Work Item 浏览；
- Conversation 视图提供精确多轮历史；
- 两者共享相同 Projection / ResumeIndex，不各算一套排序。

用户从 Rail 选择对象以后，中央 Personal Agent Surface 切换：

```text
Work Item     -> Work Capsule / 当前 Run 状态
Conversation  -> Conversation Timeline
Room          -> Group Surface（future）
```

## 56.16 v0.5 推荐视觉基线

```text
┌────────┬────────────────────────────┬──────────────────────────────┐
│ Global │ AGENT                  ⌘K  │ Personal Agent Surface       │
│ Nav    │ [+ 新对话 ▾]               │                              │
│        │ [Team Workbench ▾]         │                              │
│        │ [概览][工作][对话]          │                              │
│        ├────────────────────────────┤                              │
│ Agent  │ 需要处理                   │                              │
│ Files  │ ! Agent Page PRD           │    Work Capsule /            │
│ Project│   Waiting approval         │    Conversation /            │
│ Knowl. │                            │    Active Run                 │
│ ...    │ 正在进行                   │                              │
│        │ ▾ Agent Page PRD     8/12  │                              │
│        │   ├ 首页信息架构           │                              │
│        │   └ Memory 讨论            │                              │
│        │                            │                              │
│        │ 最近                       │                              │
│        │ ✓ Runtime Cost Design      │                              │
│        │ 💬 Agent Flow Review       │                              │
└────────┴────────────────────────────┴──────────────────────────────┘
```

这仍然不是固定四列强制常驻。窗口较窄、用户手动隐藏 Rail 或进入专注模式时，第二列可以折叠为图标 / overlay drawer；中央 Surface 不依赖 Rail 才能运行。

---

# 57. Decision Log — v0.10

## D-040 — Rail 采用 Work First，而不是 Session First

**决定：** Work / Conversation Rail 是 Personal Agent 的工作索引。默认 Overview 以 Work Item / Attention / Active Run 为主，Conversation 作为精确历史入口；DeepSeek Session / Codex Thread 不进入普通导航。
**状态：** Accepted

## D-041 — Work Item 点击与 Conversation 点击语义永久分离

**决定：** 点击 Work Item 打开 Work Capsule；点击 Conversation 打开具体多轮对话。Work Item 即使只有一条 Conversation，也不自动退化成聊天 Thread。
**状态：** Accepted

## D-042 — 新对话不默认继承当前 Work Item

**决定：** `+ 新对话` 默认保留 Personal Agent、Work Profile 与 Current Project，但创建独立 Conversation，不自动继续当前 Work Item；`在当前工作中新开对话` 为独立显式动作。
**状态：** Accepted

## D-043 — Rail 层级最多两层

**决定：** Rail 最深只到 `Work Item -> Conversation`。Run / Task / Tool Call / Runtime Session 均进入中央 Surface / Inspector，不在 Rail 构造递归执行树。
**状态：** Accepted

## D-044 — Rail 由增量 Projection 驱动

**决定：** Agent Rail 通过 Event Bus 维护 materialized projection、ResumeIndex、Cursor Pagination 与虚拟列表；打开 Rail 不扫描全部历史，不调用模型决定排序。
**状态：** Accepted

## D-045 — Group Room 只预留入口，不污染 MVP Rail

**决定：** Agent Room / Group Chat 未来作为第四种 Rail 视图和对象类型接入；未启用前不长期显示 `Coming soon` 占位，完整 Room 层级与 Work Item 关系留给 Multi-Agent PRD 决定。
**状态：** Accepted

# 58. Decision Log — v0.10.1 Reference Integration

## D-046 — Memory 必须形成 Capture → Reuse 闭环

**决定：** Workbench Memory 不能只负责保存。系统必须支持从 Conversation / Work / Run / Artifact 提取可追溯候选，并在下一次相似任务中经过检索、排序、冲突检查与预算控制后进行 Suggest / Auto Attach / Skill Execute。
**状态：** Accepted

## D-047 — 自动沉淀与手动沉淀并存

**决定：** 保留“沉淀本次对话 / 本次工作”的显式动作，同时允许后台自动生成 Memory / Knowledge / Skill Candidate；自动候选必须经过 Scope、权限、去重和置信度策略，不能无条件写入长期记忆。
**状态：** Accepted

## D-048 — Next Action 属于 Work State，不属于聊天气泡

**决定：** AI 规划的下一步行动以结构化 NextAction 持久化到 Work Item / Work Capsule，并参与 ResumeIndex；继续工作恢复 Work State + Memory + Workspace，而不是只恢复最近 Conversation。
**状态：** Accepted

## D-049 — Knowledge / Skill / Artifact 必须可审阅、可追溯、可视化

**决定：** Knowledge Card、Decision、Skill 应提供人类可读表达与 sourceRefs；视频、图片、文档、Diff、3D 等 Artifact 通过对应 Viewer 可视化；Knowledge Graph 是关系投影，不替代底层 Memory / Knowledge Store。
**状态：** Accepted


# 59. Agent Page PRD — Personal Agent Surface v0.11

## 59.1 核心结论：中央区域不是多个固定页面，而是一块“自适应执行表面”

Agent 页中央区域正式定义为 **Personal Agent Surface**。

它不是固定的：

```text
Chat Tab
Work Tab
Run Tab
Canvas Tab
```

也不是把所有能力同时常驻。

正确模型是：

```text
Rail 选中的对象
        +
当前真实执行状态
        +
需要用户处理的 Attention
        +
当前 Work Profile / Project Context
        ↓
Adaptive Surface Controller
        ↓
Personal Agent Surface
```

因此中央区域始终只有一个主表面，但会根据任务复杂度逐步长出：

```text
Conversation
    ↓
Work State
    ↓
Active Run
    ↓
Inspector
    ↓
Collaboration Canvas
```

这延续既定原则：

> Conversation First, Workspace When Needed.

并进一步明确：

> Surface Complexity Follows Execution Complexity.

## 59.2 Personal Agent Surface 的五种主状态

中央区域只允许以下五种产品层主状态，避免以后新增功能时无限堆 Tab。

### S0 — Agent Home

没有明确选择 Work Item / Conversation，或用户点击 Agent 顶层入口时进入。

主要内容：

```text
Personal Agent
Current Work Profile
Current Project / Context
Primary Resume Candidate
Attention
Recent Work
Composer
```

S0 不展示完整历史，不展示 Canvas，不展示长期 Monitor。

### S1 — Conversation Surface

用户从 Rail 点击具体 Conversation 后进入。

主对象是：

```text
Conversation
└─ Turn 1└─ Turn 2
└─ Turn 3
...
```

这里负责“我们具体聊了什么”。

### S2 — Work Capsule Surface

用户点击 Work Item，或点击“继续工作”后进入。

主对象不是某条聊天，而是完整 Work State：

```text
Work Item
├─ Goal
├─ Status
├─ Progress
├─ Next Actions
├─ Active / Pending Tasks
├─ Conversations
├─ Artifacts
├─ Workspace Bindings
├─ Memory References
├─ Decisions
├─ Runtime History
└─ Usage / Cost Summary
```

### S3 — Active Run Surface

当前 Work Item / Conversation 有正在执行的 Run，并且用户进入执行现场时进入。

主对象变为：

```text
Run
├─ Lead Runtime
├─ Current Phase
├─ Tasks
├─ Tool Activity
├─ Files / Commands / Tests
├─ Handoffs
├─ Usage
├─ Approvals
└─ Result
```

### S4 — Collaboration Surface

仅当真实存在以下至少一种情况时进入 / 自动建议进入：

- 两个及以上 Runtime 同时参与；
- Agent Handoff；
- 并行 Task；
- 多 Agent Group；
- Merge / Condition / Reviewer 等明显拓扑关系。

S4 才允许出现 Collaboration Canvas。

Canvas 是执行拓扑投影，不是独立数据源。

## 59.3 Surface 不等于互斥页面：采用 Base Surface + Adaptive Layers

五种状态在 UI 上不必表现为五个完全不同页面。

正式采用三层结构：

```text
┌──────────────────────────────────────────────┐
│ Persistent Agent Header                     │
├──────────────────────────────────────────────┤
│ Base Surface                                 │
│ Conversation / Work Capsule / Run / Canvas   │
│                                              │
│                 +                            │
│                                              │
│ Adaptive Inspector / Attention Layer         │
├──────────────────────────────────────────────┤
│ Persistent Composer                          │
└──────────────────────────────────────────────┘
```

其中：

- Header 尽量稳定；
- Base Surface 根据所选对象切换；
- Inspector 按事件出现，可 Pin / Hide；
- Approval / Error 等 Attention 允许覆盖普通状态优先级；
- Composer 在绝大多数状态持续存在。

## 59.4 Persistent Agent Header

中央区域顶部建议稳定保留：

```text
My Agent     ● Ready / Working
Developer · Team Workbench / Agent Page PRD
Local ✓ · Synced
                            [Auto] [Balanced] [···]
```

但必须遵循视觉优先级：

### 第一优先级

- Personal Agent 身份；
- 当前状态：Ready / Working / Waiting / Blocked；
- 当前 Work / Conversation 标题。

### 第二优先级

- Project / Work Profile；
- Runtime Mode；
- Cost Strategy。

### 第三优先级

- Sync；
- Runtime 技术细节；
- Session ID；
- Token / Context 等 Developer Detail。

普通成员默认看不到大量 Harness 技术信息。管理员 / Developer 可以开启 Developer Details。

## 59.5 Conversation Surface 的信息模型

Conversation Surface 不应该只是纯气泡列表，也不能把所有工具事件完全展开造成噪声。

推荐结构：

```text
User Message

Agent Response
  ├─ reasoning summary / plan（可选）
  ├─ compact activity card
  └─ result

User Message

Agent Response
...
```

执行事件默认进行语义压缩：

```text
Codex worked for 2m 14s
├─ Read 8 files
├─ Changed 3 files
├─ Ran 4 commands
└─ Tests: 18 passed

[展开执行详情]
```

只有用户展开、发生 Error / Approval，或开启 Developer Details，才显示细粒度工具事件。

因此 Conversation Timeline 是：

> 人类可读的工作叙事。

Event Store 则保留：

> 机器可审计的完整事实。

二者不能混成一份 UI。

## 59.6 Work Capsule Surface 是“继续工作”的默认落点

用户点击 `继续工作` 时，默认不直接跳进最近 Conversation，而进入 Work Capsule。

第一屏建议：

```text
Agent Page PRD                         IN PROGRESS
Team Workbench

Goal
完成 Agent 页面 PRD 与执行交互架构

Progress
8 / 12 Tasks
██████████████░░░░

Next Actions
1. 确定 Personal Agent Surface
2. 定义 Inspector 状态
3. 进入 Composer PRD

Current State
No active run

Workspace
Team Workbench · LOCAL · CONNECTED

Recent Conversations
- Agent Rail 信息架构
- Memory / Workspace 讨论

Artifacts
- TEAM_WORKBENCH_PROJECT_SPEC.md

[继续最近对话]
[在此工作中新开对话]
[执行下一步]
```

Work Capsule 必须回答六个问题：

1. 我正在做什么？
2. 做到哪里了？
3. 下一步是什么？
4. 现在有没有 Agent 在运行？
5. 相关资源 / Workspace 在哪里？
6. 我从哪里继续最合适？

## 59.7 Active Run 不能把用户强制带离 Conversation

当用户发送消息触发 Run 后，不建议立刻把整个聊天页强制切成复杂执行控制台。

第一阶段采用 **Run Strip + Adaptive Expansion**：

```text
Conversation

┌───────────────────────────────────────┐
│ ● Codex Working                      │
│ Implementing runtime adapter         │
│ 3 / 6 tasks · Tests running          │
│                          [打开现场]   │
└───────────────────────────────────────┘

Conversation continues...
```

如果任务很简单，Run 完成后直接收束为结果卡片。

如果运行时间长、事件丰富、发生 Approval / Error、用户主动点击 `打开现场`，才扩展为 Active Run Surface。

这防止“每执行一个 shell 命令，界面就跳成 IDE”。

## 59.8 Active Run Surface

展开执行现场后：

```text
┌─────────────────────────────────────────────┐
│ Run: Implement Runtime Adapter              │
│ Codex · Working · 2m 14s                    │
├─────────────────────────────────────────────┤
│ Current                                     │
│ Running integration tests                   │
│                                             │
│ Tasks                                       │
│ ✓ Inspect repository                        │
│ ✓ Modify adapter                            │
│ ● Run tests                                 │
│ ○ Review diff                               │
│                                             │
│ Activity                                    │
│ 19:31 Read src/runtime/...                  │
│ 19:32 Changed 3 files                       │
│ 19:33 npm test                              │
│                                             │
│ [Files] [Commands] [Tests] [Diff]           │
└─────────────────────────────────────────────┘
```

这里的 Tabs 仅属于 Run 内部的详情过滤，不是 Agent 页顶层导航。

## 59.9 Adaptive Inspector

Inspector 不作为永远常驻的第四列。

默认状态：

```text
AUTO
```

支持：

```text
AUTO
PINNED
HIDDEN
```

触发建议：

```text
file.changed           -> Files Inspector
command.started        -> Command Inspector
test.started           -> Tests Inspector
approval.requested     -> Approval Inspector
budget.warning         -> Usage Inspector
sync.conflict          -> Sync Inspector
memory.candidate       -> Memory Inspector（低优先级）
```

Inspector 的展开优先级：

```text
P0 Approval / Security / Destructive Action
P1 Error / Blocked / Sync Conflict
P2 Active execution detail
P3 Usage / Cost warning
P4 Informational detail
```

低优先级事件不能抢占用户正在阅读的内容。

## 59.10 Collaboration Canvas 的出现规则

Canvas 不通过“任务看起来很复杂”这种模糊模型判断自动出现。

使用真实结构事件：

```text
runtime.participant_count >= 2
OR handoff.created
OR parallel_group.created
OR agent_group.created
OR topology.edge_count > 0
```

第一阶段建议：

- 单 Runtime、单 Task：不出现；
- 单 Runtime、多步骤：优先 Task / Plan，不出现；
- DeepSeek -> Codex 单次交接：显示 Compact Handoff，可建议展开 Canvas；
- DeepSeek Plan -> Codex Execute -> DeepSeek Review：自动进入 Split / Canvas 推荐状态；
- 并行 Agent >= 2：默认打开 Collaboration Surface；
- 用户 Pin Canvas 后维持显示。

## 59.11 Collaboration Canvas 的最小节点语义

节点至少包含：

```text
Agent / Runtime Name
Role
Current Task
Status
Progress
Runtime
Cost
Elapsed
```

边至少表达：

```text
HANDOFF
DEPENDENCY
PARALLEL
REVIEW
MERGE
CONDITION
```

状态颜色不是唯一信息，必须同时有文本 / 图标，保证可访问性。

Canvas 第一版不承担自由绘图编辑器职责，只是执行状态投影。

## 59.12 Attention Layer：Approval / Error / Blocked 的最高优先级规则

如果发生：

```text
approval.requested
security.warning
run.blocked
sync.conflict requiring user action
```

中央 Surface 不应该默默继续显示普通聊天。

但也不建议全屏打断。

采用：

```text
Attention Banner
+
Inspector Auto Open
```

例如：

```text
⚠ 需要你的确认
Codex 请求执行：deploy-production.sh

[查看命令] [拒绝] [允许一次]
```

所有 Approval 必须保留：

- 发起 Runtime；
- 原因；
- 影响范围；
- 对应 Work / Run；
- 用户决策；
- 时间；
- 审计记录。

## 59.13 Composer 是中央 Surface 的永久工作入口

Composer 不随 Conversation / Work Capsule / Active Run 完全消失。

基础结构：

```text
┌──────────────────────────────────────────────┐
│ 交给我的 Agent...                           │
│                                              │
│ [+] [Context ▾]       [Auto ▾] [Balanced ▾]│
│                                  [Send ↑]    │
└──────────────────────────────────────────────┘
```

但它的 Context Chip 会根据 Surface 改变：

```text
S0 Home
Context = Current Project / Personal

S1 Conversation
Context = This Conversation + Current Project

S2 Work Capsule
Context = This Work Item

S3 Active Run
Context = This Work Item + Active Run
```

用户永远可以点击 Context Chip 检查当前 Agent 会看到的上下文范围。

这为后续“全工作台数据可访问，但上下文按需”提供可见产品入口。

## 59.14 从 Rail 到 Surface 的确定性点击语义

```text
点击 Agent 顶层入口
-> S0 Agent Home

点击 Conversation
-> S1 Conversation Surface

点击 Work Item
-> S2 Work Capsule

点击 Active Run / 打开执行现场
-> S3 Active Run Surface

点击 Collaboration / 多 Agent 执行图
-> S4 Collaboration Surface
```

这些跳转由对象类型决定，不调用模型判断。

## 59.15 Surface 自动升级 / 收束状态机

建议正式实现：

```text
HOME
  |
  | open conversation
  v
CONVERSATION
  |
  | conversation promoted to work
  v
WORK CAPSULE
  |
  | run.started
  v
RUN STRIP
  |
  | user opens / attention / complex execution
  v
ACTIVE RUN
  |
  | multi-runtime / handoff / parallel
  v
COLLABORATION
  |
  | run.completed
  v
RUN SUMMARY
  |
  v
WORK CAPSULE / CONVERSATION
```

收束规则：

- Run 完成后，实时节点压缩成 Run Summary；
- Collaboration 完成后，Canvas 折叠为协作摘要；
- Inspector AUTO 状态在相关事件结束后自动收起；
- PINNED 永不自动关闭；
- 用户正在阅读某 Conversation 时，后台 Run 完成不得强制跳走。

## 59.16 Memory 与 Surface 的关系

Memory 不应该占据主聊天区域大量空间。

推荐三种轻量呈现：

### Retrieved Memory

```text
已使用 4 条相关记忆
[查看]
```

### Memory Candidate

```text
可沉淀为项目决策
[保存] [编辑] [忽略]
```

### Manual Capture

```text
[沉淀本次对话]
[沉淀本次工作]
```

详细 Memory 管理进入 Knowledge / Memory 独立页面。

## 59.17 Workspace 与 Surface 的关系

Workspace 仍是独立一级功能，但 Agent Surface 中允许显示轻量 Workspace Context：

```text
Workspace
Team Workbench
LOCAL · CONNECTED
/home/user/team-workbench
```

支持动作：

```text
[打开 Workspace]
[在文件页显示]
[重新绑定]
```

不在 Agent Surface 内复制完整文件管理器。

## 59.18 Personal Agent Surface 的 Work Profile 扩展槽

统一骨架不变：

```text
Header
Base Surface
Inspector
Composer
```

Work Profile 只能注册扩展槽：

```text
Context Widgets
Quick Actions
Artifact Viewers
Inspector Panels
Runtime Hints
```

例如：

```text
Developer
Quick: Run Tests / Review Diff
Inspector: Files / Commands / Tests

3D
Quick: Render Preview / Open Scene
Inspector: Render / Assets / GPU

Video
Quick: Transcribe / Render Shot
Inspector: Timeline / Render / Media
```

禁止 Work Profile 重写整个 Agent 页面信息架构。

## 59.19 性能与算法预算

Personal Agent Surface 作为整个工作台最高频页面，必须采用增量 Projection。

建议 Projection：

```text
AgentHomeProjection
ConversationProjection
WorkCapsuleProjection
RunProjection
CollaborationProjection
AttentionProjection
InspectorProjection
```

执行约束：

- Token stream 只 patch 当前正在生成的 message block；
- Run event 只更新对应 Run / Task 节点；
- Conversation 历史虚拟化，不保留全部 DOM；
- 长历史按 message/event cursor 分页；
- Canvas 只对变化子图做增量布局；
- 高频 command output 做 batching / throttling；
- File diff / video / 3D artifact 懒加载；
- 隐藏 Inspector 不订阅高成本 UI projection；
- Memory retrieval 结果与 Conversation rendering 解耦；
- 后台 Run 不触发当前 Surface 全量 render；
- 切换 Surface 应优先读 materialized state，再按需补历史。

工程预算目标：

```text
Surface 切换可交互              P95 < 100ms（本地已投影数据）
Event -> visible status patch   P95 < 100ms
Token stream visual latency     P95 < 100ms
Inspector auto-open             P95 < 150ms
Canvas incremental update       P95 < 200ms（中等规模）
Conversation 10k+ messages      不允许全 DOM / 全历史重算
```

## 59.20 v0.11 推荐中央布局基线

Idle / Conversation：

```text
┌────────┬───────────────────────┬────────────────────────────────────┐
│ Global │ Work / Conversation   │ My Agent  ● Ready                  │
│ Nav    │ Rail                  │ Developer · Team Workbench         │
│        │                       ├────────────────────────────────────┤
│ Agent  │                       │                                    │
│ Files  │                       │ Conversation / Work Capsule        │
│ ...    │                       │                                    │
│        │                       │                                    │
│        │                       ├────────────────────────────────────┤
│        │                       │ Composer                           │
└────────┴───────────────────────┴────────────────────────────────────┘
```

复杂执行：

```text
┌────────┬──────────────────┬───────────────────────┬─────────────────┐
│ Global │ Rail             │ Active Run / Canvas   │ Inspector       │
│ Nav    │                  │                       │ AUTO / PINNED   │
│        │                  │                       │                 │
│        │                  │                       │ Files / Tests   │
│        │                  │                       │ Approval / Cost │
├────────┴──────────────────┴───────────────────────┴─────────────────┤
│ Composer                                                          │
└────────────────────────────────────────────────────────────────────┘
```

Inspector 并非固定第四列；窄窗口下为右侧 Drawer / Bottom Sheet。

---

# 60. Decision Log — v0.11 Personal Agent Surface

## D-050 — Agent 中央区域采用单一自适应 Surface

**决定：** 不建立固定 Chat / Work / Run / Canvas 顶层 Tab。中央区域由 Rail 所选对象、真实执行状态和 Attention 驱动，自适应呈现 Home、Conversation、Work Capsule、Active Run 或 Collaboration Surface。
**状态：** Accepted

## D-051 — Continue Work 默认进入 Work Capsule

**决定：** `继续工作` 默认打开 Work Capsule，而不是最近 Conversation；用户再选择继续最近聊天、在当前工作中新开对话、执行下一步或查看运行状态。
**状态：** Accepted

## D-052 — Active Run 先以内嵌 Run Strip 出现

**决定：** 简单执行不强制把 Conversation 切成执行控制台。Run 首先以内嵌状态条 / 卡片出现，只有用户主动打开、发生 Attention 或执行复杂度上升时才扩展为 Active Run Surface。
**状态：** Accepted

## D-053 — Inspector 为事件驱动的可折叠层

**决定：** Inspector 默认 AUTO，支持 PINNED / HIDDEN；由文件、命令、测试、Approval、Usage、Sync 等真实事件触发，不作为永久固定第四栏。
**状态：** Accepted

## D-054 — Collaboration Canvas 只由真实协作拓扑触发

**决定：** Canvas 只在多 Runtime、Handoff、并行、多 Agent Group、Merge / Review / Condition 等真实拓扑存在时自动建议 / 展开，不因“任务看起来复杂”而常驻。
**状态：** Accepted

## D-055 — Conversation UI 与 Event Store 分层

**决定：** Conversation Surface 展示人类可读的工作叙事与压缩活动卡；完整工具事件、命令输出、运行细节保存在 Workbench Event Store，并通过 Inspector / Developer Details 按需展开。
**状态：** Accepted

## D-056 — Composer 在不同 Surface 中保持连续

**决定：** Composer 是 Personal Agent Surface 的持续入口，Context Chip 随 Home / Conversation / Work Item / Run 改变，并允许用户检查当前 Agent 的上下文范围。
**状态：** Accepted


---

# 61. Agent Composer PRD — 输入、上下文、访问权限与执行策略

> **v0.23.1 修正：** 本节中若出现 Workbench 自建 Runtime Capability / Access Envelope / Approval Lease 等权限内核描述，均视为历史方案，不再作为实现要求。Runtime 权限按第 162 节直接复用 DeepSeek Harness / Codex 原生权限体系；本节仅保留 Context 选择、应用数据访问和 UI 交互语义。

## 61.1 Composer 的产品定位

Composer 不是普通聊天输入框，也不能演化成一个塞满十几个永久按钮的“Agent 控制台”。它是 **Personal Agent 的统一请求入口**，负责把用户自然语言与当前工作上下文、数据引用、访问权限、Runtime 策略、成本策略和协作策略组合成一次可审计、可恢复的 Workbench Request。

核心原则：

```text
用户看到：
“告诉我的 Agent 要做什么”

系统内部：
User Intent
+ Current Context
+ Referenced Resources
+ Access Envelope
+ Runtime Policy
+ Cost Policy
+ Collaboration Policy
= Workbench Agent Request
```

Composer 必须遵循已经确定的 Progressive Disclosure：普通聊天保持极简；只有当用户需要附件、复杂上下文、Runtime 覆盖、Skill、Expert、Agent 协作或权限控制时，才展开更深控制。

## 61.2 默认视觉结构

推荐第一版基线：

```text
┌───────────────────────────────────────────────────────────────┐
│ 交给我的 Agent…                                               │
│                                                               │
│                                                               │
│ [+] [Context · Team Workbench] [Auto · Balanced]       [↑]  │
└───────────────────────────────────────────────────────────────┘
```

默认只常驻四类入口：

- `+`：添加文件、文件夹、图片以及 Workbench 内部资源；
- `Context`：查看 / 修改当前 Project、Work Item、Workspace、Memory 与数据访问范围；
- `Execution`：显示当前 `Runtime Mode + Cost Strategy`，例如 `Auto · Balanced`；
- `Send`：提交当前请求。

`Skill / Expert / @Agent / Hybrid / Approval / Context Token` 等能力不应全部永久平铺在输入框底部。

Developer / Admin 等高级 Work Profile 可以允许“高级控制常显”，但这是用户偏好，不改变统一 Composer 数据模型。

## 61.3 Context Chip 不是简单的 Project Selector

以前的 `Project Alpha` Selector 应升级为统一的 **Context Chip**。

例如：

```text
Context · Team Workbench
```

展开后：

```text
CURRENT CONTEXT

Project
Team Workbench

Work
Agent Page PRD

Workspace
team-workbench-local
Local · Connected

Pinned
- TEAM_WORKBENCH_PROJECT_SPEC.md
- D-039 Workbench Event Store

Memory
Current Agent Memory          Allowed
Current Agent Project Memory  Allowed

Shared Data
Project Knowledge             Search on demand
Organization Knowledge        Search on demand

[查看 AI 本次可访问的数据]
```

Context Chip 解决的是：

> “我现在是基于什么工作环境、什么工作事项、哪些明确引用和哪些长期记忆在向 Agent 下达任务？”

它不是把这些数据全部直接注入 Prompt。

## 61.4 Full Connectivity 与 Per-Turn Access Envelope

工作台已经确定“AI 可以连接整个 Workbench”，但每一轮请求都必须形成一个明确的 **Access Envelope**。

有效权限由多层策略求交集：

```text
Organization Security Policy
          ∩
Access Role
          ∩
Project Policy
          ∩
Personal Agent Defaults
          ∩
Work Item / Conversation Policy
          ∩
Per-Turn Override
          ↓
Effective Access Envelope
```

采用最小权限和 `deny wins` 原则；Per-Turn Override 只能进一步收紧权限，不能绕过上层安全策略自行提权。

示例：

```text
READ
✓ Current Project
✓ Current Work Item
✓ Project Knowledge
✓ Personal Memory
✓ Current Workspace files

WRITE
✓ Current Work Item
✓ Current Workspace
○ Project Knowledge          Ask before write

EXECUTE
✓ Local shell                Approval by policy
○ Remote production runtime  Denied

SHARE
○ Organization Knowledge     Ask before publish
```

因此：

```text
Full Connectivity != Full Context
Full Connectivity != Full Permission
Full Permission != Silent Execution
```

## 61.5 “AI 本次能看到什么”必须可检查

Context Drawer 中必须提供一个面向用户的 **What AI Can Access / Context Preview**。

建议分成两层：

```text
ACCESS
Agent 有资格访问哪些数据源？

CONTEXT PACKAGE
本次真正准备注入 / 检索了哪些内容？
```

例如：

```text
Context Package

Pinned                         3
Auto-retrieved                12
Project Decisions              4
Relevant Memories              5
Workspace References           7
Recent Conversation            6 messages

Estimated Context             ~18k tokens

[查看来源]
```

用户不需要阅读底层 Prompt，但必须可以追踪“AI 为什么知道这件事”和“本轮用了哪些来源”。

Context Broker 仍负责 Rank / Deduplicate / Freshness / Token Budget，不因 Context Drawer 可视化而改变按需上下文原则。

## 61.6 附件与 Workbench Resource Reference

`+` 菜单应统一处理“上传内容”和“引用已有工作台资源”。

建议结构：

```text
ADD
File / Image
Folder

FROM WORKBENCH
Workspace Resource
Knowledge Card
Decision
Task / Work Item
Artifact
Conversation

MORE
Link
```

关键原则：Workbench 内部资源优先保存 **Resource Reference**，不复制原始内容进 Conversation。

例如：

```text
ref://workspace/ws_12/src/runtime/router.rs
ref://decision/D-039
ref://knowledge/k_182
```

执行时由 Context Broker 按权限和当前版本解析。

这样同一个 2GB 视频、Blender 文件或大型 Repository 不会因为被引用一次就复制进聊天数据库。

## 61.7 Local Workspace 与 Server Workspace 在 Composer 中统一引用

Composer 不需要让用户针对本地 / 服务器分别学习不同的引用方式。

```text
[+]
  → Workspace
      → Local Workspace
      → Server Workspace
      → Mounted Workspace
      → Mirrored Workspace
```

最终添加到消息中的仍然是统一 Resource Reference。

底层由 Workspace Gateway 解析：

```text
WorkspaceRef
    ↓
Provider
    ├── Local
    ├── Remote
    ├── Mounted
    └── Mirrored
```

如果执行 Runtime 无法直接访问某个 Remote Resource，由 Workspace Gateway 决定 Streaming、临时下载、挂载或拒绝访问，不让 Harness 自己猜路径。

## 61.8 Runtime 与 Cost Strategy 合并成一个 Execution Chip

为了避免 Composer 永久出现过多控件，推荐显示：

```text
[Auto · Balanced]
```

展开：

```text
EXECUTION

Runtime
● Auto
○ DeepSeek
○ Codex
○ Hybrid

Cost Strategy
○ Economy
● Balanced
○ Quality
○ Custom

Auto Switch Runtime
ON

Hybrid
Allowed · Standard max

Task Budget
¥5.00
[高级]
```

当用户强制覆盖默认值时，Chip 应明显显示：

```text
[Codex · Quality]
```

或者：

```text
[Hybrid · Custom · ¥10]
```

但没有覆盖时保持紧凑。

## 61.9 Execution Policy 的继承与覆盖

Runtime / Cost Policy 使用明确继承顺序：

```text
User Default
   ↓
Project Default
   ↓
Work Item Policy
   ↓
Conversation Override
   ↓
Per-Turn Override
```

UI 必须能说明当前值来自哪里，例如：

```text
Balanced
Inherited from Project
```

用户本轮修改为 Quality 时只影响当前请求，除非显式选择：

```text
[仅本次]
[设为本会话默认]
[设为此工作默认]
```

避免一次临时选择无意中永久提高成本。

## 61.10 Expert、Style、Skill 与 Agent 的入口要区分语义

不建议把所有东西都做成 `@xxx`。

推荐语义：

```text
@ = 人 / Agent / Expert
/ = Skill / Action
+ = 文件 / 数据 / Workbench Resource
```

示例：

```text
@架构师 帮我检查这个设计

/codereview

/沉淀本次工作
```

Style 更接近 Personal Agent / Conversation 的行为配置，不需要每次通过特殊语法重复添加；必要时可从 Composer 的高级控制中临时覆盖。

未来群聊中 `@Agent` 才进一步承担明确发言对象 / 任务委派语义。

## 61.11 Expert 不等于 Runtime

例如：

```text
Expert = 软件架构师
Runtime = DeepSeek
```

或者：

```text
Expert = Code Reviewer
Runtime = Codex
```

Expert 定义角色、知识与行为模板；Runtime 决定哪个 Harness / Model 实际执行。

Workbench Router 可以根据 Expert 的 capability requirements 推荐 Runtime，但两者在数据模型中必须分离。

## 61.12 Composer 与 Memory 的关系

默认 Composer 是 Memory-aware，但不是“每句话自动永久记忆”。

本轮请求可以使用：

```text
Current Agent Memory
Current Agent Project-scoped Memory
Relevant Project / Organization Knowledge（按权限）
Work State
```

默认检索边界是当前 `agentId` 的 MemorySpace；同一用户拥有的其他 Agent 记忆也不能被隐式检索。跨 Agent 协作通过 Handoff / Context Package 传递必要信息，而不是直接读取对方 Memory。

执行结束后再由 Memory Capture Pipeline 判断是否生成：

```text
Knowledge Candidate
Decision Candidate
Preference Candidate
Skill Candidate
Project State Update
Next Action
```

建议未来提供一个轻量隐私 / 临时模式：

```text
Private / Ephemeral Conversation
```

在该模式下可关闭长期 Memory Capture，并可根据产品策略关闭 Server Sync；但第一版不需要把这一开关常驻 Composer。

## 61.13 Send 不是直接调用 Harness

点击 Send 后必须经过统一请求流水线：

```text
Composer
   ↓
Create WorkbenchRequest
   ↓
Policy Resolve
   ↓
Access Envelope
   ↓
Context Broker
   ↓
Cost / Budget Check
   ↓
Runtime Router
   ↓
Runtime Adapter
   ↓
DeepSeek / Codex / Hybrid
```

如果出现：

```text
预计需要 Hybrid
预计超过 Task Budget
需要敏感写操作
需要 Production Runtime
```

则在真正启动前进入 Confirmation / Approval，而不是 Agent 启动以后才告诉用户。

## 61.14 统一 Workbench Agent Request Envelope

建议把 Composer 的最终提交对象定义为稳定协议，不直接传某个 Harness 的私有参数。

建议概念模型：

```text
WorkbenchAgentRequest

identity
- requestId
- userId
- personalAgentId

location
- projectId?
- workItemId?
- conversationId?
- workspaceRefs[]

input
- text
- attachments[]
- resourceRefs[]

contextPolicy
- pinnedRefs[]
- memoryScopes[]
- retrievalMode
- tokenBudget

accessPolicy
- requestedCapabilities[]
- approvalPolicy

executionPolicy
- runtimeMode
- costStrategy
- taskBudget
- allowAutoSwitch
- hybridLevel

collaborationPolicy
- allowed
- maxAgents
- allowAgentCreatedRoom

presentation
- sourceSurface
- preferredResponseMode
```

Runtime Adapter 再把它转换成：

```text
DeepSeek Harness Request
Codex Harness Request
Future Runtime Request
```

这保证 Workbench 不会被任何一个 Harness 的参数模型锁死。

## 61.15 Request Envelope 必须可审计、可重放但不能泄露秘密

Event Store 至少保存：

```text
requestId
resolved project/work/conversation
resource references
resolved policy ids
runtime decision
cost decision
approval events
context source references
```

但不应把：

```text
API Key
Credential
Secret Environment Variable
敏感 token 的明文值
```

写入可重放 Event Log。

所谓“重放”主要是重建产品状态和执行意图，不保证对非确定性模型得到字节级相同输出。

## 61.16 运行中的 Composer 必须保持可用

当 Agent 正在执行时，Composer 不应被整个禁用。

用户仍然可能说：

```text
“先别改数据库。”
“测试只跑 unit tests。”
“顺便把 README 更新掉。”
```

Workbench 需要统一一个 **Live Guidance** 抽象：

```text
User Guidance
     ↓
Runtime Adapter Capability Check
     ├── supports steer
     │      → 注入当前 Run 安全检查点
     └── no live steer
            → 排队为 Pending Guidance
               在下一安全检查点 / 下一 Turn 应用
```

UI 不要求用户理解 DeepSeek / Codex 各自是否原生支持 steer。

运行时 Composer 可显示：

```text
Agent 正在工作
[发送指导]
```

发送菜单允许：

```text
发送到当前工作
排到当前 Run 之后
开始新对话
```

默认选择应根据当前 Surface 和 Runtime Capability 自动给出，但用户可改。

## 61.17 不允许“用户一发新消息就静默取消当前 Run”

新的用户消息不能默认：

```text
cancel active run
start new run
```

除非用户明确选择 Stop / Replace。

正确状态至少区分：

```text
STEER      给当前 Run 新指导
QUEUE      当前 Run 完成后执行
STOP+SEND  先停止当前 Run，再执行新请求
NEW        新 Conversation / Work context
```

第一版可以隐藏高级选项，只在 Active Run 时通过 Send 下拉暴露。

## 61.18 Context / Access 变化必须可见

当 Agent 因任务需要请求扩大访问范围时，例如：

```text
当前只有：workspace:read
现在需要：workspace:write
```

不能静默升级。

Surface 显示：

```text
Codex 需要额外权限

Write
/workspace/src/**

Reason
需要实现已确认的 Runtime Adapter 修改

[允许本次]
[允许此工作]
[拒绝]
```

获批后更新当前 Workbench Request / Run 的 Access Envelope，并写入审计事件。

## 61.19 Composer 与不同 Work Profile

所有 Work Profile 共用同一个 Composer 基础协议。

差异只体现在快捷资源和领域能力：

```text
Developer
+ Repo / File / Diff
/ test / review / build

3D
+ Scene / Asset / Material
/ render-preview / validate-scene

Video
+ Timeline / Shot / Media
/ transcribe / render-shot

Admin
+ Runtime / Team / Usage
/ health-check / audit
```

因此新增 Work Profile 不需要重做 Composer，只需注册新的 Resource Provider、Skill 和 Quick Action。

## 61.20 Composer 性能设计

Composer 是最高频交互之一，必须避免“每敲一个字就查询整个工作台”。

约束：

```text
输入文本
→ 只更新本地 draft state

@ / / / Resource Search
→ 用户触发后才查询对应索引

Context Chip
→ 读取 ContextSummaryProjection

Resource Picker
→ Cursor + FTS / Provider Search

Send
→ 才创建完整 WorkbenchAgentRequest
```

工程预算目标：

```text
输入按键到视觉反馈                 P95 < 16ms
Composer 打开 Context Summary     P95 < 80ms
本地资源搜索首批结果               P95 < 100ms
Execution Drawer 打开             P95 < 80ms
Send 到 Request Accepted          P95 < 100ms（不含模型首 token）
```

Context Token Estimate、远程 Workspace metadata、Server Sync 状态等非关键数据可异步补充，不阻塞输入和 Send。

## 61.21 v0.12 推荐 Composer 基线

普通状态：

```text
┌───────────────────────────────────────────────────────────────┐
│ 交给我的 Agent…                                               │
│                                                               │
│ [+] [Context · Agent Page PRD] [Auto · Balanced]       [↑]  │
└───────────────────────────────────────────────────────────────┘
```

添加资源后：

```text
┌───────────────────────────────────────────────────────────────┐
│ 检查这个 Runtime Router，并按我们之前的决策修改。             │
│                                                               │
│ [router.rs] [D-039]                                          │
│                                                               │
│ [+] [Context · Agent Page PRD] [Codex · Balanced]      [↑]  │
└───────────────────────────────────────────────────────────────┘
```

运行中：

```text
┌───────────────────────────────────────────────────────────────┐
│ Agent 正在工作 · Codex                                       │
│ 给当前工作补充要求…                                           │
│                                                               │
│ [+] [Context] [发送指导 ▾]                                  │
└───────────────────────────────────────────────────────────────┘
```

Context Drawer：

```text
┌─────────────────────────────────────────┐
│ CONTEXT & ACCESS                        │
├─────────────────────────────────────────┤
│ Project        Team Workbench           │
│ Work           Agent Page PRD           │
│ Workspace      Local · Connected        │
│                                         │
│ Pinned                                  │
│ 2 resources                             │
│                                         │
│ Memory                                  │
│ Personal       Read                     │
│ Project        Read                     │
│                                         │
│ Workspace                               │
│ Read            Allowed                 │
│ Write           Ask if needed           │
│                                         │
│ Context Package                         │
│ Estimated       ~18k tokens             │
│                                         │
│ [查看来源] [权限设置]                   │
└─────────────────────────────────────────┘
```

---

# 62. Decision Log — v0.12 Composer / Context & Access

## D-057 — Composer 是统一 Agent Request 入口

**决定：** Composer 不直接调用 DeepSeek / Codex；所有提交先形成 WorkbenchAgentRequest，再由 Policy、Context Broker、Cost Engine、Router 与 Runtime Adapter 处理。
**状态：** Accepted

## D-058 — Context Chip 升级为 Context & Access 入口

**决定：** Composer 中不再只提供 Project Selector；统一 Context Chip 管理 Project、Work Item、Workspace、Pinned Resources、Memory Scope 和本轮数据访问范围。
**状态：** Accepted

## D-059 — 每一轮请求形成 Access Envelope

**决定：** AI 可以连接整个 Workbench，但每一轮请求的有效权限由 Organization / Access Role / Project / Agent / Work / Conversation / Per-Turn Policy 求交集产生；采用最小权限、deny-wins 与可审计升级。
**状态：** Accepted

## D-060 — 用户可以检查 AI 本轮真正使用的上下文来源

**决定：** Context Drawer 区分“可访问数据源”和“本轮 Context Package”，支持查看 pinned / retrieved / memory / decision / conversation 等来源引用，不把内部完整 Prompt 暴露为产品依赖。
**状态：** Accepted

## D-061 — Workbench 内部内容通过 Resource Reference 进入 Composer

**决定：** Workspace 文件、Knowledge、Decision、Task、Artifact、Conversation 等以稳定 Resource Reference 引用，不复制大型原始内容进入聊天数据库；执行时由 Gateway 按权限与版本解析。
**状态：** Accepted

## D-062 — Runtime 与 Cost Strategy 在 UI 中合并为 Execution Chip

**决定：** 默认 Composer 使用 `Auto · Balanced` 一枚紧凑 Execution Chip；展开后仍完整支持 Auto / DeepSeek / Codex / Hybrid 和 Economy / Balanced / Quality / Custom，以及预算与 Auto Switch / Hybrid Policy。
**状态：** Accepted

## D-063 — Expert / Skill / Runtime 三者在数据模型中解耦

**决定：** Expert 定义角色与知识行为，Skill 定义可复用能力 / 流程，Runtime 决定实际 Harness 执行；UI 可使用 `@`、`/` 与 Resource Picker 区分语义，但不把它们绑定成一个概念。
**状态：** Accepted

## D-064 — 运行中的 Composer 保持可用，并统一为 Live Guidance

**决定：** Active Run 时 Composer 允许用户继续补充要求；Workbench 将输入映射为 STEER / QUEUE / STOP+SEND / NEW，由 Runtime Adapter 根据底层能力实现，不让用户承担 Harness 协议差异。
**状态：** Accepted

## D-065 — 新消息不得静默取消当前 Run

**决定：** Active Run 时发送新消息默认不会自动 cancel + restart；任何停止或替换当前 Run 的行为必须具有明确用户动作或已定义自动化策略。
**状态：** Accepted

## D-066 — Context / Capability 升级必须显式可见

**决定：** Agent 在执行中如果需要扩大写入、执行、共享或高风险访问范围，必须产生 Approval / Access Request；不得静默扩大权限。
**状态：** Accepted

## D-067 — Local / Server Workspace 在 Composer 中统一为 Workspace Reference

**决定：** Composer 和 Agent Request 不区分不同文件交互 UI；通过统一 WorkspaceRef / ResourceRef 引用 Local、Remote、Mounted、Mirrored Provider，实际读取、上传、下载、挂载和缓存由 Workspace Gateway 负责。
**状态：** Accepted


# 63. Composer PRD 增补 — 多模态上传与模型能力动态门控（v0.13）

## 63.1 必须支持的输入类型

Composer 的资源入口 `+` 第一阶段至少预留并支持：

```text
File
Image
Video
Folder / Workspace Resource
Workbench Resource
```

但“界面允许选择某类资源”与“当前模型能够原生理解该资源”必须分开。

Workbench 不允许把上传按钮写死为永久可用。每次以下任一条件变化时，必须重新计算当前 **Effective Model Capability**：

```text
用户切换 Runtime
用户切换 Model
Project 覆盖默认 Model
Work Item 覆盖 Model
管理员更新 Provider / Model 配置
Runtime Adapter 重新连接
模型能力探测结果发生变化
```

Composer 根据能力结果即时更新资源入口状态。

## 63.2 Model Capability Manifest

所有可选择模型都必须在 Workbench Model Registry 中暴露统一能力描述，而不是让 UI 硬编码某个模型名称：

```ts
interface ModelCapabilityManifest {
  modelId: string
  providerId: string
  runtimeKinds: Array<'deepseek' | 'codex' | 'other'>

  input: {
    text: CapabilityMode
    image: CapabilityMode
    audio: CapabilityMode
    video: CapabilityMode
    file: CapabilityMode
  }

  output: {
    text: boolean
    image?: boolean
    audio?: boolean
  }

  limits: {
    contextTokens?: number
    maxImages?: number
    maxFileBytes?: number
    maxVideoBytes?: number
    maxVideoDurationSec?: number
  }

  source: 'provider' | 'runtime' | 'verified-config' | 'admin-override'
  verifiedAt?: number
}

type CapabilityMode = 'native' | 'adapted' | 'unsupported'
```

三态语义：

```text
native
→ 当前模型 / Runtime 可以直接消费这种输入

adapted
→ Workbench 可以先通过受控预处理转换，再交给模型

unsupported
→ 当前执行路径无法可靠处理这种输入
```

## 63.3 UI 门控规则

如果当前模型不支持图片：

```text
图片
Unsupported by current model
[灰色，不可直接选择]
```

如果当前模型不支持视频：

```text
视频
Unsupported by current model
[灰色，不可直接选择]
```

用户切换到支持对应模态的模型后，入口应立即恢复可用，不需要重新打开 Conversation。

必须注意：

> **“不能直接发给当前模型”不等于“不能把资源导入 Workbench”。**

因此可以存在两种入口语义：

```text
Attach to Agent
→ 受当前 Model Capability 门控

Import to Workspace
→ 受 Workspace Provider / 权限 / 文件限制门控
```

例如当前模型不支持视频，用户仍然可以把视频上传到 Server Workspace；只是不能把它作为本轮模型的直接视频输入。

## 63.4 Adapted Capability（可选增强）

为了避免未来把“模型原生能力”和“Workbench 工具能力”混为一谈，建议保留 `adapted`：

```text
Video native
→ 视频直接交给模型

Video adapted
→ Workbench 先执行：
   metadata extraction
   + audio transcription
   + key-frame extraction
   + optional OCR / scene indexing
→ 再把结构化结果提供给模型

Video unsupported
→ 不允许本轮 Agent 消费视频
```

第一阶段如果希望规则最严格，可以只开放 `native`，把 `adapted` 作为 P1；数据模型从第一版保留三态。

## 63.5 能力发现不能只信模型名称

Capability 的来源优先级建议：

```text
1. Runtime / Provider 提供的可靠 capability metadata
2. Workbench verified model registry
3. 管理员显式 override
4. 未知 → 默认 unsupported，而不是乐观猜测
```

原因是很多 Provider 的模型别名、代理模型和自部署模型无法仅靠名称判断图片 / 视频能力。

UI 应允许高级用户查看：

```text
Model
xxx

Image input
Native

Video input
Unsupported

Capability source
Verified Registry

Last verified
...
```

## 63.6 上传资源的处理生命周期

用户添加图片 / 视频 / 文件后，不应立即把原始二进制塞进 Conversation Event：

```text
Select Resource
    ↓
Capability Gate
    ↓
Permission / Size / Provider Check
    ↓
Resource Ingest
    ↓
Hash / Metadata / Preview
    ↓
ResourceRef
    ↓
WorkbenchAgentRequest
```

Conversation 只保存 `ResourceRef`、展示 metadata 和 source provenance。

大文件 / 视频采用流式上传、分块校验、断点续传和内容哈希去重。

---

# 64. 运行中输入队列 — Codex 式 Follow-up Queue 语义

## 64.1 核心决定

Active Run 期间 Composer 必须继续可输入；但是新消息默认 **不取消当前 Run**。

Workbench 引入统一：

```text
Run Input Queue
```

它吸收 Codex 类产品“运行过程中继续输入、排队到后续安全边界处理”的交互优点，并抽象成跨 Runtime 能力。

## 64.2 四种消息意图

运行中的新输入统一解析为：

```text
STEER
→ 尽快影响当前 Run；仅在 Runtime 支持且处于安全点时应用

QUEUE
→ 放入当前 Run 的 Follow-up Queue，默认行为

INTERRUPT
→ 请求中止当前 Run，并应用新输入

BRANCH
→ 不影响当前 Run；创建新 Conversation / Run / Work branch
```

默认发送行为：

```text
Active Run + 普通新消息
→ QUEUE
```

不允许普通 Send 隐式变成 `INTERRUPT`。

## 64.3 队列 UI

当存在未消费消息时，Composer 上方显示紧凑队列：

```text
Queued for current run · 2

1. README 也一起更新
2. 测试只跑 unit tests

[编辑] [删除] [调整顺序]
```

高级操作：

```text
[发送到当前安全点]
[等待下一 Turn]
[停止当前并应用]
[转为新分支]
```

## 64.4 队列必须可编辑

消息在被 Runtime 消费前，用户应可以：

```text
edit
remove
reorder
retarget
```

消费后变为不可编辑的审计事件。

这比“发出去以后只能再发一条纠正”更适合长时间 Agent Run。

## 64.5 Runtime Adapter 映射

Workbench 只暴露统一语义：

```text
queueFollowUp()
steerIfSupported()
interrupt()
branch()
```

Adapter 决定具体实现：

```text
Codex Adapter
→ 优先映射到 Codex 可用的后续输入 / turn / interrupt 能力

DeepSeek Adapter
→ 根据 DSH 能力映射为当前安全点 guidance、下一 turn injection 或 Workbench queue

Future Runtime
→ 实现相同 RuntimeInputControl 接口
```

因此产品 UI 不依赖某个 Harness 的具体输入协议。

## 64.6 Hybrid / Multi-Agent 的目标选择

当存在多个 Agent / Runtime 时，队列消息可以带 `target`：

```ts
interface QueuedGuidance {
  id: string
  runId: string
  target:
    | { type: 'lead' }
    | { type: 'active-agent'; agentId: string }
    | { type: 'task'; taskId: string }
    | { type: 'all' }
  mode: 'steer' | 'queue' | 'interrupt' | 'branch'
  text: string
  resourceRefs?: string[]
  createdAt: number
  consumedAt?: number
}
```

第一版 UI 默认只显示：

```text
发送给 Lead Agent
```

进入 Hybrid / Multi-Agent 后才逐步开放 `@Agent` 或目标 Task。

---

# 65. Agent Run / Task / Collaboration Event Model v0.13

## 65.1 为什么这一层必须现在定义

Personal Agent Surface、Collaboration Canvas、Resume、Monitor、Memory、Cost、审批与跨设备恢复最终都依赖同一组运行事实。

因此不能让：

```text
DeepSeek 自己维护一套 Task 状态
Codex 自己维护另一套 Turn 状态
Canvas 再维护第三套节点状态
UI 再猜第四套
```

正确结构：

```text
Native Runtime Events
    │
    ├── DeepSeek Adapter
    └── Codex Adapter
            ↓
      WorkbenchEvent
            ↓
      Event Store
            ↓
   Incremental Projections
     ├ RunProjection
     ├ TaskProjection
     ├ TimelineProjection
     ├ CollaborationProjection
     ├ CostProjection
     ├ ResumeProjection
     └ MonitorProjection
```

## 65.2 四个最核心运行对象

### Run

一次可审计、可取消、可恢复语义的 Agent 执行实例。

```ts
interface AgentRun {
  id: string
  conversationId: string
  workItemId?: string
  parentRunId?: string

  leadAgentId: string
  leadRuntime: 'deepseek' | 'codex' | 'hybrid' | 'other'

  status: RunStatus
  startedAt?: number
  completedAt?: number

  inputRequestId: string
  accessEnvelopeId: string
  costPolicyId: string
}
```

### Task

Run / Work Item 中可以独立跟踪的执行单元。

```ts
interface AgentTask {
  id: string
  runId: string
  parentTaskId?: string
  title: string
  status: TaskStatus
  assignedAgentId?: string
  runtimeBindingId?: string
  dependsOn?: string[]
}
```

### Runtime Binding

Workbench 产品对象与底层 Harness 原生 Session / Thread / Turn 之间的绑定。

```ts
interface RuntimeBinding {
  id: string
  runId: string
  taskId?: string
  runtime: 'deepseek' | 'codex' | 'other'
  nativeSessionRef?: string
  nativeThreadRef?: string
  nativeTurnRef?: string
}
```

### Handoff

Agent / Runtime 之间正式的任务交接，不是一句聊天文本。

```ts
interface Handoff {
  id: string
  runId: string
  fromAgentId: string
  toAgentId: string
  taskId?: string
  reason: string
  contextPackageRef: string
  status: HandoffStatus
}
```

## 65.3 Run 状态机

统一状态：

```text
CREATED
  ↓
QUEUED
  ↓
PREPARING
  ↓
RUNNING
  ├── WAITING_APPROVAL
  ├── WAITING_INPUT
  ├── WAITING_DEPENDENCY
  ├── PAUSED
  └── RUNNING
  ↓
COMPLETING  ↓
COMPLETED

异常终态：
FAILED
CANCELLED
BLOCKED
```

说明：

```text
QUEUED
→ 等待 Runtime slot / dependency / policy

PREPARING
→ Context Broker、权限、Workspace、Runtime 初始化

WAITING_INPUT
→ Agent 明确需要用户补充，而不是普通 idle

BLOCKED
→ 无法自动继续，需要外部条件改变
```

## 65.4 Task 状态机

```text
PENDING
READY
RUNNING
WAITING
COMPLETED
FAILED
SKIPPED
CANCELLED
BLOCKED
```

Task 的 `WAITING` 必须带原因：

```text
approval
input
dependency
runtime
resource
rate_limit
budget
```

UI 不显示模糊的“Waiting”。

## 65.5 Agent 状态

Collaboration Canvas 中 Agent 节点使用：

```text
IDLE
ASSIGNED
WORKING
WAITING
REVIEWING
ERROR
COMPLETED
OFFLINE
```

Agent 状态是 Projection，不是 Agent 自己写入数据库的私有字段。

## 65.6 Event Envelope

现有 `WorkbenchEvent` 升级为版本化 Envelope：

```ts
interface WorkbenchEventV1<T = unknown> {
  eventId: string
  schemaVersion: 1
  sequence: number
  occurredAt: number
  ingestedAt: number

  scope: {
    userId?: string
    projectId?: string
    workItemId?: string
    conversationId?: string
    runId?: string
    taskId?: string
    agentId?: string
  }

  source: {
    kind: 'workbench' | 'deepseek' | 'codex' | 'workspace' | 'memory' | 'sync'
    adapterVersion?: string
    nativeRef?: string
  }

  type: string
  payload: T
}
```

`sequence` 用于同一 Event Stream 内的稳定排序；跨设备同步仍需处理不同 stream 的合并，不依赖单一 wall clock。

## 65.7 第一版事件命名规范

使用领域前缀：

```text
run.created
run.queued
run.preparing
run.started
run.paused
run.resumed
run.completed
run.failed
run.cancel_requested
run.cancelled
run.blocked

task.created
task.ready
task.assigned
task.started
task.progress
task.waiting
task.completed
task.failed
task.skipped
task.cancelled

agent.assigned
agent.started
agent.progress
agent.waiting
agent.reviewing
agent.completed
agent.failed

handoff.created
handoff.accepted
handoff.started
handoff.completed
handoff.rejected

message.created
message.queued
message.edited
message.removed
message.consumed
message.steered

context.requested
context.packaged
context.resource_added
memory.retrieved

approval.requested
approval.granted
approval.denied
approval.expired

runtime.binding_created
runtime.connected
runtime.disconnected
runtime.restarted
runtime.native_event

command.started
command.output
command.completed

file.read
file.changed
file.diff_created

test.started
test.result
test.completed

artifact.created
artifact.updated

usage.updated
budget.warning
budget.exceeded

error.raised
error.recovered
```

## 65.8 原生事件与语义事件分层

不是所有 Codex / DeepSeek 原生事件都应该直接进入高层 Timeline。

分两级：

```text
Native Evidence
→ 完整、可审计、按 Runtime 保存

Semantic Workbench Event
→ 产品需要恢复 / 展示 / 统计 / 协作的稳定事件
```

例如 Codex 连续产生大量 command stdout：

```text
Native Evidence
1000 chunks
```

Workbench 可以批量映射为：

```text
command.started
command.output_batch
command.completed
```

UI Timeline 再投影成：

```text
Ran tests
18 passed · 2m 14s
```

避免事件风暴拖垮界面。

## 65.9 Handoff 是 Collaboration Canvas 的关键边

Hybrid Standard：

```text
DeepSeek Planner
      │
      │ handoff.created
      ▼
Codex Engineer
      │
      │ handoff.completed
      ▼
DeepSeek Reviewer
```

Handoff 必须携带：

```text
目标
原因
Task
Context Package
权限摘要
预算摘要
输入 Artifact / ResourceRefs
预期输出
```

因此 Canvas 的边不是“装饰线”，而是可点击的真实业务对象。

## 65.10 并行任务

Work Item / Run 可创建 DAG：

```text
          Task A
         /      \
    Task B      Task C
         \      /
          Task D
```

第一版只要求支持：

```text
dependsOn[]
ready when all required dependencies complete
```

不急着做用户自由拖拽的通用 Workflow Engine。

Task Scheduler 必须是确定性的：

```text
dependency state
+ runtime availability
+ policy
+ budget
+ approval
→ READY / WAITING
```

不让模型每次临场决定基础调度语义。

## 65.11 Approval 状态必须是一等事件

```text
approval.requested
```

至少包含：

```text
actor
requested capability
scope
reason
risk level
related task
expiry
```

批准可以是：

```text
once
for current run
for current work item
```

但不得越过 Organization / Role 的硬性 Deny。

## 65.12 Retry 不是重新创建一切

失败后：

```text
Task T1 attempt 1 FAILED
Task T1 attempt 2 RUNNING
```

需要 `attemptId`：

```ts
interface TaskAttempt {
  id: string
  taskId: string
  ordinal: number
  runtimeBindingId?: string
  startedAt?: number
  completedAt?: number
  terminalReason?: string
}
```

这样 UI 可以显示：

```text
Tests
Attempt 2 / 3
```

而不是制造三个重复 Task。

## 65.13 Cancel 采用请求 / 确认两阶段

```text
run.cancel_requested
      ↓
Runtime Adapter interrupt
      ↓
run.cancelled
```

如果底层 Runtime 一时无法中止：

```text
Cancel requested…
```

不能提前把 UI 标成已经 Cancelled。

Task 同理。

## 65.14 Cost / Usage 是 Run Event 的组成部分

每一个 Runtime Adapter 统一上报：

```text
input tokens
output tokens
cached tokens（如可用）
provider reported cost（如可用）
estimated cost
tool / compute cost（未来）
```

CostProjection 支持：

```text
Run
Task
Agent
Runtime
Work Item
User
Project
Day
```

多 Agent / Hybrid 时仍然能回答：

> 到底是哪一个 Agent / Runtime 花了多少钱？

## 65.15 Collaboration Canvas 的数据来源

Canvas 只读取 `CollaborationProjection`：

```ts
interface CollaborationProjection {
  runId: string
  nodes: Array<{
    id: string
    kind: 'agent' | 'task' | 'approval' | 'merge' | 'condition'
    status: string
    progress?: number
    cost?: number
  }>
  edges: Array<{
    id: string
    kind: 'handoff' | 'dependency' | 'review' | 'merge'
    from: string
    to: string
    status: string
  }>
}
```

Canvas 不直接订阅 Runtime private event。

## 65.16 Event Storm / 性能控制

高频事件必须分等级：

```text
Critical
approval / error / state transition
→ 立即投影

Interactive
message / task progress / file change
→ 小批次增量投影

Telemetry
stdout / token delta / low-level progress
→ batch / sample / aggregate
```

UI 不因为每一个 token / stdout chunk 触发全局 render。

建议工程预算：

```text
关键状态 Event → Projection     P95 < 50ms
Projection → Visible UI          P95 < 100ms
高频 output 批处理窗口           16–100ms 自适应
Canvas 大图布局                 仅变更子图增量计算
```

## 65.17 Run Summary

Run 结束后自动生成结构化 Summary Projection：

```text
Run Completed

Runtime
DeepSeek → Codex → DeepSeek

Tasks
12 / 12

Files
7 changed

Tests
42 passed

Approvals
2

Cost
¥3.42

Duration
08:21

Memory candidates
4

[查看全过程]
```

它是 Work Capsule、Resume、Memory Capture 和 Monitor 的共同输入之一。

---

# 66. Decision Log — v0.13 Multimodal / Queue / Run Event Model

## D-068 — Composer 输入能力由 Model Capability 动态门控

**决定：** 图片、视频、音频、文件等输入入口不得硬编码；模型 / Runtime / Project 配置变化后重新解析 Effective Model Capability。不支持的直接 Agent 输入入口变灰。
**状态：** Accepted

## D-069 — 模型能力使用 `native / adapted / unsupported` 三态

**决定：** 从第一版数据模型区分模型原生多模态能力、Workbench 预处理能力与完全不支持；第一版 UI 可只开放 native，后续启用 adapted。
**状态：** Accepted

## D-070 — Import to Workspace 与 Attach to Agent 分离

**决定：** 当前模型不支持视频不代表用户不能把视频存入本地 / Server Workspace；“文件存储能力”和“模型消费能力”分别门控。
**状态：** Accepted

## D-071 — Active Run 默认采用 Follow-up Queue

**决定：** 采用 Codex 式运行中消息队列语义；普通新消息默认进入当前 Run 队列，不静默终止执行。用户可编辑、删除、调整未消费消息。
**状态：** Accepted

## D-072 — Workbench 统一 RuntimeInputControl

**决定：** `steer / queue / interrupt / branch` 由 Workbench 统一抽象，再由 DeepSeek / Codex Adapter 映射底层能力。
**状态：** Accepted

## D-073 — Run / Task / Runtime Binding / Handoff 成为一等产品对象

**决定：** Collaboration、Resume、Monitor、Cost 不再从聊天文本反推执行关系；使用结构化运行对象和统一事件协议。
**状态：** Accepted

## D-074 — Collaboration Canvas 只读取 Projection

**决定：** Canvas 不直接依赖 Codex / DeepSeek 私有协议；只消费由 Workbench Event Store 生成的 `CollaborationProjection`。
**状态：** Accepted

## D-075 — Retry 使用 Task Attempt，不复制 Task

**决定：** 重试是同一 Task 的多个 Attempt；保证任务身份稳定、成本可归因、历史可解释。
**状态：** Accepted

## D-076 — Cancel 使用 request / confirmed 两阶段

**决定：** UI 只有收到 Runtime 中止确认或 Workbench 确认终止后才进入 Cancelled；避免表面状态与真实进程不一致。
**状态：** Accepted

## D-077 — 高频 Runtime Evidence 必须分层聚合

**决定：** 原始 stdout / token / native telemetry 可保存为证据，但 UI 与核心 Projection 只接收语义化、批处理或聚合事件，防止 Event Storm。
**状态：** Accepted


# 67. Runtime Adapter Contract — DeepSeek / Codex 统一接入协议（v0.14）

## 67.1 目标

Workbench 不能把 DeepSeek Harness 与 Codex Harness 的私有协议直接泄露到 UI、Conversation、Memory、Task Scheduler 或 Collaboration Canvas。

统一边界：

```text
Workbench Core
      │
      ├── Runtime Adapter Contract
      │       ├── DeepSeekRuntimeAdapter
      │       ├── CodexRuntimeAdapter
      │       └── FutureRuntimeAdapter
      │
      └── WorkbenchEvent / RuntimeBinding / CapabilityManifest
```

Adapter 的职责是：

```text
能力发现
请求转换
Runtime 生命周期
输入队列 / steer / interrupt
原生 Session / Thread 绑定
原生事件采集
语义事件映射
Usage / Cost 上报
健康状态
```

Adapter **不拥有** Conversation、Work Item、Memory 或 Project。

## 67.2 不做“最低公分母接口”

如果只定义：

```text
send(prompt)
stop()
```

会丢掉 Codex 的工程执行能力，也无法发挥 DeepSeek Harness 的插件 / Agent 能力。

因此采用：

```text
Core Contract
+
Capability Extensions
```

所有 Runtime 实现最小核心；高级能力通过 Capability Manifest 开启。

## 67.3 Core Runtime Adapter

建议 TypeScript 侧协议：

```ts
interface RuntimeAdapter {
  readonly runtimeId: string
  readonly kind: 'deepseek' | 'codex' | 'other'

  probe(): Promise<RuntimeProbeResult>
  getCapabilities(modelId?: string): Promise<RuntimeCapabilityManifest>

  createBinding(input: CreateRuntimeBindingInput): Promise<RuntimeBinding>
  startRun(input: RuntimeRunRequest): Promise<RuntimeRunHandle>

  queueInput(input: RuntimeQueuedInput): Promise<QueueAck>
  interrupt(input: RuntimeInterruptRequest): Promise<InterruptAck>

  subscribe(
    bindingId: string,
    onEvidence: (event: RuntimeEvidence) => void
  ): Unsubscribe

  resume?(input: RuntimeResumeRequest): Promise<RuntimeRunHandle>

  getUsage?(bindingId: string): Promise<RuntimeUsageSnapshot>
  disposeBinding(bindingId: string): Promise<void>
  shutdown(): Promise<void>
}
```

`steer` 不强制成为所有 Runtime 的必选方法，而通过 capability + `queueInput(mode='steer')` 表达，Adapter 决定能否立即应用。

## 67.4 Runtime Capability Manifest

它比单独的 Model Capability 更高一层：

```ts
interface RuntimeCapabilityManifest {
  runtime: {
    nativeResume: boolean
    nativeSteer: boolean
    followUpQueue: boolean
    interrupt: boolean
    parallelTasks: boolean
    subagents: boolean
    approvals: boolean
    sandbox: boolean
    diffEvents: boolean
    structuredPlan: boolean
    usageTelemetry: boolean
  }

  model: ModelCapabilityManifest
}
```

UI / Router / Composer / Scheduler 均读取这一份有效能力，而不是判断：

```text
if runtime === 'codex' ...
if modelName contains 'vision' ...
```

## 67.5 Capability Resolution

最终能力不是只看模型，也不是只看 Harness：

```text
Runtime Capability
        ∩
Model Capability
        ∩
Provider Capability
        ∩
Workspace / Platform Capability
        ∩
Policy
        ↓
Effective Capability
```

例如模型理论上支持图片，但当前 Codex / DeepSeek Adapter 的这条执行路径不接受图片，则 Composer 仍应判定本轮 `image=unsupported`。

反过来，如果 Runtime 支持视频预处理工具，但模型不原生支持视频，可得到：

```text
video = adapted
```

## 67.6 用户切模型后的资源兼容性

如果用户已经添加：

```text
[architecture.png]
[demo.mp4]
```

然后把模型切换成不支持图片 / 视频的模型：

Workbench **不能删除资源，也不能默默忽略**。

资源 Chip 变成：

```text
architecture.png   ⚠ Not supported by current model
demo.mp4           ⚠ Not supported by current model
```

并阻止 Send：

```text
当前模型无法处理 2 个已附加资源。

[切换兼容模型]
[移除不兼容资源]
[仅导入 Workspace]
```

这样用户不会误以为 Agent 已经“看过”图片 / 视频。

## 67.7 RuntimeRunRequest

WorkbenchAgentRequest 在经过 Policy / Context / Routing 后，转换成更窄的运行请求：

```ts
interface RuntimeRunRequest {
  runId: string
  bindingId: string
  modelId: string

  messages: RuntimeMessage[]
  contextPackageRef: string
  resourceRefs: string[]

  permissions: RuntimePermissionEnvelope
  execution: {
    workingDirectory?: string
    timeoutMs?: number
    sandboxMode?: string
  }

  metadata: {
    projectId?: string
    workItemId?: string
    conversationId: string
    taskId?: string
  }
}
```

Adapter 只拿执行所需最小信息，不获得整个 Workbench 数据库句柄。

## 67.8 RuntimeEvidence

Adapter 首先产出接近原生但统一包裹的证据：

```ts
interface RuntimeEvidence {
  evidenceId: string
  bindingId: string
  runId: string
  nativeType: string
  nativeRef?: string
  timestamp: number
  payload: unknown
  priority: 'critical' | 'interactive' | 'telemetry'
}
```

然后 Normalizer 映射到：

```text
WorkbenchEventV1
```

这样既保留原生诊断能力，又不让 UI 依赖私有协议。

## 67.9 Adapter 内部分层

每个 Adapter 包建议至少拆为：

```text
Transport
→ 进程 / stdio / socket / API 通信

Protocol
→ Runtime 私有协议解析

Capability Resolver
→ 运行时和模型能力

Input Controller
→ queue / steer / interrupt / resume

Evidence Collector
→ 原生事件

Semantic Normalizer
→ WorkbenchEvent

Usage Reporter
→ token / cost / runtime usage
```

避免一个 `adapter.ts` 最终膨胀为几万行。

## 67.10 DeepSeek Adapter 第一版职责

```text
DeepSeekRuntimeAdapter
├─ 管理 DeepSeek Harness 进程 / SDK binding
├─ 创建 / 关联 DSH native session
├─ 把 Context Package 转成 DSH 可消费输入
├─ 注入 Workbench tools / capabilities
├─ 映射 tool / task / subagent / message 事件
├─ queue / next-turn guidance
├─ interrupt（若当前集成路径支持）
└─ usage / error / health
```

DeepSeek Harness 原生 Session 是 evidence / runtime binding，不成为 Workbench Conversation ID。

## 67.11 Codex Adapter 第一版职责

```text
CodexRuntimeAdapter
├─ 管理 Codex runtime / app-server binding
├─ 创建 / 关联 Codex thread / turn
├─ 把 Workbench Context / Workspace 映射到 Coding Run
├─ 采集 command / file / diff / approval / test 相关事件
├─ 映射 Follow-up Queue
├─ interrupt
├─ native resume（若当前运行模式可用）
└─ usage / error / health
```

Codex Thread 同样只是 Runtime Binding。

## 67.12 DSH 内部调用 Codex 与 Codex Direct 不混为一个 Adapter

第一版允许两条执行路径：

```text
A. DeepSeek Runtime
   └─ DSH 内部 Codex subagent

B. Codex Direct Runtime
```

它们在 Workbench 中必须产生不同的 Runtime Binding / source metadata。

原因：

```text
A
→ 适合 DeepSeek Lead 的轻量 delegation

B
→ 适合需要完整 Codex execution telemetry / thread / queue / diff / approval 的直接 Coding Run
```

Router 可以根据任务和 UI 可观测性要求选择路径。

## 67.13 Runtime Slot 与资源治理

双 Harness 不意味着两个进程无限并发。

Runtime Manager 维护：

```text
Runtime Slot
CPU / Memory Budget
GPU / Tool Constraints
Concurrent Runs
Per-user Limit
Per-project Limit
```

Scheduler 在 `task.ready` 后仍需通过：

```text
policy
budget
runtime slot
workspace lock
```

才能进入 `RUNNING`。

这直接服务于前面要求的“极致算法 / 性能优化”。

## 67.14 Workspace Lock / Write Coordination

如果 DeepSeek 与 Codex 或多个 Agent 同时修改同一 Workspace：

不能依赖模型自行避免冲突。

第一版至少提供：

```text
read concurrency
write intent
path-level write reservation
conflict detection
```

例如：

```text
Codex A → src/auth/**  WRITE
Codex B → tests/**     WRITE
```

可以并行。

如果两个任务都要写：

```text
src/auth/login.ts
```

Scheduler 应等待、串行或建立显式 merge flow，而不是同时覆盖。

## 67.15 Runtime Health

每个 Adapter 对 Workbench 提供：

```text
READY
DEGRADED
OFFLINE
STARTING
RESTARTING
INCOMPATIBLE
```

并带原因：

```text
binary missing
version mismatch
auth required
model unavailable
provider unreachable
capability probe failed
```

Agent 页面只在需要时提示，Monitor 页面提供完整状态。

## 67.16 Failover 原则

Auto 模式下某 Runtime 不可用时，不直接偷偷换 Runtime。

Policy 分三档：

```text
Safe fallback
→ 等价能力且不扩大成本 / 权限，可以自动切换

Ask fallback
→ 能完成但成本、权限或能力发生变化，询问用户

No fallback
→ 用户强制 DeepSeek / Codex 时，失败即报告，不自动换
```

例如用户明确选择 `Codex Only`，Workbench 不应在 Codex Offline 时偷偷交给 DeepSeek。

---

# 68. Decision Log — v0.14 Runtime Adapter Contract

## D-078 — Runtime Adapter 使用 Core + Capability Extensions

**决定：** 不以最低公分母牺牲 DeepSeek / Codex 的高级能力；通过统一核心合同和动态 capability 暴露差异能力。
**状态：** Accepted

## D-079 — UI / Router 只读取 Effective Capability

**决定：** 不按模型名字或 Runtime 名字硬编码多模态、resume、steer、approval 等行为；统一经过 Capability Resolution。
**状态：** Accepted

## D-080 — 已附加资源在模型切换后必须重新验证

**决定：** 模型 / Runtime 改变后立即重新计算资源兼容性；不兼容资源保留但标红/警告，并阻止无提示发送。
**状态：** Accepted

## D-081 — Runtime Adapter 不获得 Workbench 全库访问

**决定：** Adapter 仅接收 RuntimeRunRequest、Context Package 与授权 ResourceRefs；Workbench Data Plane 保持数据边界。**状态：** Accepted

## D-082 — Runtime 原生事件先作为 Evidence，再映射 Semantic Event

**决定：** 保留诊断证据与稳定产品事件两层，防止 Runtime 私有协议污染 UI 和持久数据模型。
**状态：** Accepted

## D-083 — DSH→Codex delegation 与 Codex Direct 是不同执行路径

**决定：** 两者分别建立 Runtime Binding；前者用于 DeepSeek Lead 的 delegation，后者用于完整 Codex 工程执行与可观测性。
**状态：** Accepted

## D-084 — Runtime Manager 必须治理并发与资源槽位

**决定：** 双 Harness / 多 Agent 不等于无限并发；统一管理 CPU、内存、Runtime Slot、用户/项目并发与 Workspace 写冲突。
**状态：** Accepted

## D-085 — Auto Failover 不能破坏用户显式选择

**决定：** 只有等价且不扩大成本/权限的 Safe fallback 可以静默自动执行；其它 fallback 需要用户确认；强制 Runtime 模式不自动替换。
**状态：** Accepted


---

# 69. Task Scheduler + Hybrid Orchestrator

## 69.1 核心结论：Agent 可以提议，Scheduler 才拥有执行权

这一层必须避免两个极端：

```text
极端 A
所有事情都由中央 Scheduler 硬编码
→ Agent 没有自主性

极端 B
Agent 想创建多少 Task、调用多少 Agent、切多少 Runtime 都可以
→ 成本、并发、权限、可观测性全部失控
```

正式采用：

> **Agent proposes, Scheduler authorizes and executes.**

也就是说：

- Personal Agent / Lead Runtime 可以分析任务并提出 Task Graph；
- DeepSeek / Codex 可以提出新的子任务、Handoff、Repair、Review 或需要额外 Agent 的请求；
- **Workbench Scheduler** 负责校验依赖、权限、成本、Runtime Capability、Workspace 写冲突、并发槽位和用户策略；
- 只有 Scheduler 接受后，任务才真正进入 `READY / QUEUED / RUNNING`；
- Agent 无权绕过 Scheduler 直接建立无限递归的 Agent / Task。

因此 Hybrid Orchestrator 不是第三套 Agent Loop，而是 **确定性的任务控制平面**。

```text
Personal Agent / Lead Runtime
          │
          │ proposes
          ▼
     Task Graph Draft
          │
          ▼
┌────────────────────────┐
│ Workbench Scheduler    │
│                        │
│ Validate Dependencies  │
│ Resolve Runtime        │
│ Check Capability       │
│ Check Cost/Budget      │
│ Check Permission       │
│ Check Runtime Slot     │
│ Check Workspace Lock   │
└───────────┬────────────┘
            │ accepts
            ▼
      Executable Task Graph
```

## 69.2 Personal Agent 是用户入口，不等于所有任务的执行 Runtime

用户仍然面对自己的 Personal Primary Agent。

但一个工作内部可以形成：

```text
Personal Agent
     │
     ├─ Task A → DeepSeek
     ├─ Task B → Codex
     ├─ Task C → Codex
     └─ Task D → DeepSeek Reviewer
```

因此 Personal Agent 更接近：

```text
User-facing Lead / Coordinator Identity
```

而不是固定绑定某一个模型或 Harness。

## 69.3 Task Graph

复杂工作进入 Hybrid / 多步骤模式后，Workbench 使用有向无环图（DAG）表达依赖：

```text
            [Analyze]
                │
                ▼
             [Plan]
             /    \
            ▼      ▼
     [Backend]   [Tests]
            \      /
             ▼    ▼
             [Review]
                │
                ▼
              [Done]
```

一个 Task 至少包含：

```text
Task
├── id
├── workItemId
├── runId
├── parentTaskId?
├── type
├── title
├── objective
├── definitionOfDone
├── dependencies[]
├── status
├── priority
├── proposedRuntime
├── assignedRuntime
├── capabilityRequirements[]
├── workspaceRefs[]
├── readSet[]
├── writeIntent[]
├── contextRefs[]
├── permissionRequirements[]
├── estimatedCost
├── reservedBudget
├── actualCost
├── retryPolicy
├── reviewPolicy
├── sourceRefs[]
└── resultRefs[]
```

第一版不需要把所有字段都暴露给用户，但底层模型应从一开始预留。

## 69.4 Task 状态机

统一状态建议为：

```text
DRAFT
  ↓
READY
  ↓
QUEUED
  ↓
RUNNING
  ├─→ WAITING
  ├─→ BLOCKED
  ├─→ REVIEW
  ├─→ SUCCEEDED
  ├─→ FAILED
  └─→ CANCELLED
```

额外允许：

```text
SUPERSEDED
```

用于表达旧 Task 被新的 Repair / Replan Task 替代，但保留历史证据。

不要通过“直接修改已完成 Task 的历史结果”来模拟返工。

## 69.5 谁可以创建 Task

### 用户

用户可以显式创建：

```text
新工作事项
新 Task
拆分工作
```

### Personal Agent / Lead Runtime

可以提出：

```text
child task
dependency
handoff
review
repair
parallel branch
```

但必须经过 Scheduler。

### Worker Agent

默认只能：

- 完成分配给自己的 Task；
- 提出 `task.spawn.requested`；
- 提出 `handoff.requested`；
- 提出 `permission.escalation.requested`；
- 提出 `repair.requested`。

不能自行无限递归地生成 Worker。

### Reviewer

Reviewer 不直接修改原 Implementation Task 的结果。

Review 不通过时：

```text
Implementation Task   SUCCEEDED
        │
        ▼
Review Task           FAILED / CHANGES_REQUESTED
        │
        ▼
Repair Task           CREATED
        │
        ▼
Review Task #2
```

这样历史、成本、责任 Runtime 和实际修复过程都可追溯。

## 69.6 Auto 模式下的 Lead Runtime 选择

Auto Router 不使用“任务看起来复杂”这种模糊理由，而根据显式信号评分。

建议输入特征：

```text
Capability Fit
Coding Intensity
Repository Dependency
Reasoning / Research Intensity
Multimodal Requirement
Workspace Write Requirement
Expected Tool Usage
Need for Diff / Tests / Sandbox
Context Size
Risk Level
Estimated Cost
Expected Latency
Runtime Queue Depth
Runtime Health
Existing Runtime Binding / Cache Affinity
User Preference
Project Policy
```

第一版可以使用确定性规则 + 权重评分，不必额外调用模型做路由。

## 69.7 Runtime Stickiness

为了降低成本、冷启动和上下文重复，Scheduler 不应该每个 Task 都频繁切 Runtime。

增加 `Runtime Stickiness`：

```text
如果当前 Runtime 能可靠完成下一 Task
并且没有明显成本 / 能力劣势
→ 优先保持当前 Runtime
```

只有满足明确升级条件才切换。

这可以减少：

- 重复 Context 打包；
- Runtime 冷启动；
- Thread / Session 创建；
- 工具重新探测；
- Workspace Cache Miss；
- 用户难以理解的频繁 Agent 切换。

## 69.8 Single Runtime First

即使 Work Item 有多个 Task，也不意味着进入 Hybrid。

例如：

```text
Analyze repo
Implement feature
Run tests
Fix tests
```

如果 Codex 可以完整完成：

```text
Codex Lead
  ├─ Analyze
  ├─ Implement
  ├─ Test
  └─ Fix
```

仍然属于 Single Runtime。

只有出现跨能力边界时，才升级 Hybrid。

## 69.9 Hybrid 升级条件

建议至少满足以下一种明确条件：

1. **能力缺口**：当前 Runtime 缺少必要 capability；
2. **任务职责明显分层**：如产品 / 架构规划 + 代码实现；
3. **独立 Review 要求**：用户或项目策略要求由另一 Runtime 审阅；
4. **风险等级触发**：高风险修改必须异构 Review；
5. **当前 Runtime 主动报告能力不足**，且 Scheduler 验证成立；
6. **用户显式指定 Hybrid**；
7. **成本模型表明拆分反而更经济**；
8. **并行收益明显且不存在写冲突**。

不能因为“Hybrid 更高级”而自动升级。

## 69.10 Hybrid 等级继续沿用 Lite / Standard / Deep

### Hybrid Lite

```text
Lead Runtime
    ↓
一次 Handoff
    ↓
Worker Runtime
```

例如：

```text
DeepSeek Plan
→ Codex Implement
```

### Hybrid Standard

```text
DeepSeek Plan
→ Codex Implement
→ DeepSeek Review
```

这是默认推荐的 Hybrid 上限。

### Hybrid Deep

允许多轮：

```text
DeepSeek
↕
Codex
↕
DeepSeek
↕
Codex
```

但必须设置：

```text
maxHandoffs
maxRepairLoops
maxAgents
maxCost
maxWallTime
```

默认不得无限递归。

## 69.11 Hybrid 升级预算闸门

Scheduler 在实际增加第二 Runtime 之前计算：

```text
Current Actual Cost
+ Reserved Running Cost
+ Proposed Hybrid Cost
```

然后与：

```text
Per-task Budget
Per-work Budget
Daily Budget
Project Policy
User Strategy
```

比较。

处理逻辑：

```text
在预算内 + Policy Allow
→ 自动升级

超过软阈值
→ Ask

超过硬阈值
→ Block
```

因此 `Auto + Balanced` 不等于系统可以无上限创建 Hybrid Task。

## 69.12 并行调度原则

Scheduler 不追求“Agent 数量最大化”，而追求：

> **在依赖、成本、Runtime Slot、Workspace 写冲突和用户优先级约束下，缩短关键路径。**

只有满足以下条件才并行：

```text
依赖独立
AND Runtime Slot 可用
AND 预算允许
AND 权限允许
AND Workspace write-set 不冲突
```

例如：

```text
Task A → 修改 src/backend/**
Task B → 编写 docs/**
```

可以并发。

但：

```text
Task A → 修改 src/auth/login.ts
Task B → 修改 src/auth/login.ts
```

必须串行或进入显式 Merge Flow。

## 69.13 Scheduler 的第一版算法

第一版不需要复杂 AI Scheduler，可以使用确定性 DAG Scheduler：

```text
1. Incremental DAG update
2. 维护 dependency counter
3. dependency == 0 → READY
4. READY Task 进入 priority heap
5. 检查 budget / capability / runtime slot / workspace lock
6. 通过 → QUEUED / RUNNING
7. Task 完成后仅更新直接依赖节点
```

优先级可综合：

```text
P0 Human Attention / Approval recovery
P1 Critical Path
P2 User Priority
P3 Blocking Count
P4 Runtime Affinity
P5 Age
P6 Cost Efficiency
```

禁止每个事件都重新扫描完整 Task Graph。

## 69.14 Handoff 是一等对象

Handoff 不只是聊天文字，而是结构化交接包：

```text
Handoff
├── fromRuntime / fromAgent
├── toRuntime / toAgent
├── taskId
├── reason
├── objective
├── definitionOfDone
├── inputResourceRefs[]
├── contextRefs[]
├── decisionRefs[]
├── constraints[]
├── permissionEnvelope
├── budgetEnvelope
├── expectedOutputs[]
└── sourceRefs[]
```

原则：

> **Handoff 传递最小充分上下文，不复制整条 Conversation。**

这样减少 Token、降低错误上下文污染，也方便用户在 Canvas 上检查“为什么这个任务交给 Codex”。

## 69.15 Review 与 Repair

Review 结果至少区分：

```text
APPROVED
CHANGES_REQUESTED
BLOCKED
```

`CHANGES_REQUESTED` 时，不盲目重新运行原任务，而生成 Repair Task。

```text
Implementation
      ↓
Review
      ↓ changes requested
Repair
      ↓
Review #2
```

默认 Repair Loop：

```text
Economy   1
Balanced  2
Quality   3
Custom    user-defined
```

达到上限仍未通过：

```text
→ BLOCKED
→ 请求用户决策 / Replan
```

## 69.16 Retry 与 Repair 必须分开

### Retry

适用于基础设施 / 瞬时故障：

```text
network timeout
provider 5xx
process crash before mutation
runtime temporary unavailable
```

可以采用有限次数指数退避，并保持同一 Task。

### Repair / Replan

适用于语义失败：

```text
tests failed
implementation incorrect
review rejected
wrong assumptions
context insufficient
```

不能盲目 Retry。

应该建立新的：

```text
Repair Task
或
Replan Task
```

否则会浪费 Token 并重复相同错误。

## 69.17 Idempotency

每一个可重试动作必须带：

```text
idempotencyKey
```

Scheduler / Adapter 在进程崩溃、桌面重启、网络重连后能够判断：

```text
这个 Task 是从未执行
正在执行
已执行但 ACK 丢失
还是已完成
```

这对 Remote Workspace、服务器 Runtime 和未来多设备恢复尤其重要。

## 69.18 Cancel / Interrupt 语义

至少区分：

```text
Cancel Task
Cancel Branch
Cancel Run
Interrupt Runtime Turn
Remove Queued Guidance
```

优先使用 Graceful Interrupt：

```text
停止继续生成 / 执行
→ 等待当前不可分割操作结束
→ 记录已发生副作用
→ 释放 Runtime Slot / Workspace Lock
```

只有 Runtime 无响应时才强杀进程。

## 69.19 Codex 式 Follow-up Queue 纳入 Scheduler

运行中的 Composer `QUEUE` 不是孤立聊天消息，而进入当前 Run 的 Follow-up Queue：

```text
Run
├── Active Task
└── Follow-up Queue
      ├── Message 1
      ├── Message 2
      └── Message 3
```

Scheduler 决定应用时机：

```text
当前 Runtime 原生支持 queued follow-up
→ 映射到 Runtime

不支持
→ 在当前 Task / Turn 安全结束后生成下一 Task 或 Guidance Turn
```

用户界面保持一致，不暴露底层差异。

## 69.20 多 Agent 自治的边界先预留

未来允许 Agent 提出：

```text
spawn agent
create room
invite specialist
parallelize tasks
```

但第一阶段正式原则仍是：

> **Spawn is a request, not an entitlement.**

Scheduler 根据：

```text
maxAgents
budget
role policy
runtime slots
workspace conflict
user preference
```

决定是否接受。

未来可以提供自治等级：

```text
Manual
Ask Before Spawn
Autonomous Within Limits
```

但不会从第一版开始默认开放完全自治。

## 69.21 Agent Group / 群聊与 Scheduler 不是同一个概念

必须区分：

```text
Agent Room
= 谁在一起沟通 / 讨论

Task Graph
= 谁实际负责什么工作、依赖是什么、是否完成
```

一个群里可以有 5 个 Agent，但只有 2 个 Agent 当前有运行 Task。

也可以没有群聊 UI，但 Scheduler 仍然调度 3 个 Worker。

因此以后 Group Chat 不应该承担任务真源职责。

## 69.22 Auto 决策必须可解释

用户点开一个自动路由的 Task 时，应该看到简短原因：

```text
Assigned to Codex

Why
- Repository write required
- Tests required
- Codex has native diff + sandbox capability
- Within Balanced budget

Estimated
¥0.80–1.60
```

Hybrid 升级同理：

```text
Hybrid enabled

Reason
- Architecture decision required
- Code implementation required
- Independent review required by project policy
```

避免黑盒路由。

## 69.23 Hybrid 可视化直接由 Scheduler 真值驱动

Canvas 不由模型生成一张“看起来像流程图”的图。

它读取：

```text
Task Graph
Runtime Assignment
Handoff
Dependency
Status
Review
Repair
Approval
Cost
```

例如：

```text
DeepSeek Planner       ✓ ¥0.28
       │
       │ HANDOFF
       ▼
Codex Engineer         ● ¥0.74
       │
       ├── Tests       ●
       │
       ▼
DeepSeek Reviewer      ○
```

这样视觉永远与真实执行一致。

## 69.24 性能要求：Scheduler 必须增量化

不能每收到一个 token / command output 就重算整个任务图。

采用：

```text
Event
 ↓
affected task ids
 ↓
local state patch
 ↓
dependency counter update
 ↓
ready queue patch
 ↓
projection patch
```

核心数据结构建议：

```text
Task Map              O(1) lookup
Dependency Counters   O(1) readiness update per edge
Ready Priority Heap   O(log n)
Runtime Slot Index    O(1) / O(log n)
Workspace Lock Index  prefix/path index
```

Canvas 只接收 changed nodes / changed edges。

## 69.25 Task Deduplication

Agent 在 Replan 时可能反复提出类似任务。

Workbench 可以计算：

```text
Task Fingerprint
= normalized objective
+ workspace scope
+ expected output type
+ relevant dependency set
```

发现近似重复时：

```text
merge suggestion
reuse result
mark duplicate
```

但不能只靠模糊语义自动合并高风险 Task；高风险情况下需要用户或 Lead Agent 确认。

## 69.26 Context Reuse

同一 Work Item 内多个 Task 不应各自从零检索全部上下文。

Context Broker 可以维护：

```text
Work Context Base
+ Task Delta
```

例如：

```text
Base
Project summary
Architecture decisions
Workspace manifest

Task A Delta
src/auth/**

Task B Delta
tests/auth/**
```

这样 Hybrid / 多 Agent 场景不会因为每个 Worker 都重新拉一整套 Context 而产生巨大 Token 成本。

## 69.27 Scheduler 持久化与恢复

Workbench 重启后不能丢失任务图。

持久化：

```text
Task Graph
Task State
Queue
Runtime Binding
Handoff
Approval
Budget Reservation
Workspace Lock metadata
Follow-up Queue
```

重启后通过 Runtime Adapter `probe / resume / inspect` 对账：

```text
Workbench says RUNNING
Runtime says COMPLETED
→ reconcile → COMPLETED

Workbench says RUNNING
Runtime missing
→ DEGRADED / RECOVERY_REQUIRED
```

不依赖单个 Harness Session 作为唯一恢复依据。

---

# 70. Hybrid Orchestrator 默认策略（第一版）

## 70.1 Auto + Economy

```text
Single Runtime First
Auto Hybrid = OFF by default
Review = same Runtime unless policy requires otherwise
Parallelism = conservative
Repair loops = 1
```

## 70.2 Auto + Balanced

```text
Single Runtime First
Auto Hybrid = allowed when explicit trigger exists
Default Hybrid max = Standard
Parallel independent Tasks when safe
Repair loops = 2
Budget soft gate enabled
```

## 70.3 Auto + Quality

```text
Independent review preferred for important work
Hybrid Standard commonly allowed
Hybrid Deep only when policy permits
More aggressive parallelism under safe locks
Repair loops = 3
```

## 70.4 Manual Runtime

用户指定：

```text
DeepSeek
Codex
```

默认不自动升级到 Hybrid。

如果确实缺 capability：

```text
→ 提示用户
→ 建议切换 / Hybrid
→ 不静默改变用户选择
```

## 70.5 Explicit Hybrid

用户指定 Hybrid 后，Scheduler 仍必须遵守：

```text
budget
permissions
runtime health
workspace locks
max agents
max handoffs
```

`Hybrid` 不是绕过治理规则的超级权限。

---

# 71. Agent 页面在 Scheduler 上的可视化投影

## 71.1 简单单 Runtime

```text
Conversation

● Codex Working
Implementing Runtime Adapter
3 / 6 tasks

[打开执行现场]
```

## 71.2 多 Task 单 Runtime

```text
Codex
├─ ✓ Analyze repo
├─ ● Implement adapter
├─ ○ Run tests
└─ ○ Review diff
```

仍不必显示 Collaboration Canvas。

## 71.3 Hybrid
自动出现协作投影：

```text
DeepSeek Planner       ✓
       │
       ▼
Codex Engineer         ●
       │
       ▼
DeepSeek Reviewer      ○
```

## 71.4 并行

```text
                DeepSeek Plan ✓
                   /       \
                  ▼         ▼
          Codex Backend   Codex Tests
              ●              ●
                  \         /
                   ▼       ▼
                  Review ○
```

## 71.5 Repair

```text
Codex Implement ✓
      │
      ▼
DeepSeek Review ! Changes requested
      │
      ▼
Codex Repair ●
      │
      ▼
Review #2 ○
```

UI 显示的是 Scheduler 真值，而不是 Agent 自述状态。

---

# 72. Decision Log — v0.15 Task Scheduler + Hybrid Orchestrator

## D-086 — Agent 提议 Task，Workbench Scheduler 拥有最终调度权

**决定：** Agent 可以提出任务拆分、Handoff、Repair、Review、Spawn 请求，但所有执行必须通过 Scheduler 的依赖、预算、权限、Runtime Slot、Capability 与 Workspace 冲突校验。
**状态：** Accepted

## D-087 — 复杂工作使用 DAG Task Graph

**决定：** 多步骤 / Hybrid / 多 Agent 工作统一使用 DAG 表达依赖；Canvas 与进度投影直接读取 Task Graph。
**状态：** Accepted

## D-088 — Single Runtime First 继续作为调度默认原则

**决定：** 多 Task 不等于 Hybrid；如果一个 Runtime 可以可靠完成整条链路，优先保持单 Runtime 和 Runtime Stickiness。
**状态：** Accepted

## D-089 — Hybrid 只能由显式能力 / 质量 / 风险 / 用户策略触发

**决定：** 禁止仅因“任务很复杂”或“Hybrid 更高级”自动升级；升级前必须经过预算闸门。
**状态：** Accepted

## D-090 — 并行目标是缩短关键路径，而不是最大化 Agent 数量

**决定：** 只有依赖独立、预算允许、Runtime Slot 可用且 Workspace 写集合不冲突时才并行。
**状态：** Accepted

## D-091 — Review 不通过创建 Repair Task，不篡改原任务历史

**决定：** Implementation、Review、Repair 使用独立 Task，并建立 lineage；达到 Repair Loop 上限后进入 BLOCKED / Replan。
**状态：** Accepted

## D-092 — Retry 与 Repair / Replan 分离

**决定：** 瞬时基础设施错误允许有限自动 Retry；语义错误不得盲重试，必须 Repair 或 Replan。
**状态：** Accepted

## D-093 — Handoff 是结构化一等对象

**决定：** Handoff 保存目标、Definition of Done、最小充分 Context、资源引用、权限、预算、预期输出与来源引用，不复制整条聊天。
**状态：** Accepted

## D-094 — Codex 式 Follow-up Queue 归 Scheduler 管理

**决定：** Active Run 中的新消息默认可进入 Follow-up Queue；Runtime 原生支持则映射原生队列，不支持则由 Workbench 在安全点生成 Guidance Turn / Next Task。
**状态：** Accepted

## D-095 — 多 Agent Spawn 必须经过 Scheduler

**决定：** Future Agent 可以请求创建 Agent / Room / Parallel Worker，但默认没有无限派生权；自治能力由 maxAgents、预算、权限和用户策略约束。
**状态：** Accepted

## D-096 — Agent Room 与 Task Graph 分离

**决定：** 群聊负责交流关系，Task Graph 负责真实工作职责与执行状态；群聊不能成为任务状态真源。
**状态：** Accepted

## D-097 — Auto 路由与 Hybrid 升级必须可解释

**决定：** UI 可查看 Runtime Assignment / Hybrid Upgrade 的简短理由、Capability Fit、成本估计和策略来源。
**状态：** Accepted

## D-098 — Scheduler 必须采用增量 DAG / Ready Queue 算法

**决定：** 通过 dependency counter、priority heap、Runtime Slot Index、Workspace Lock Index 等局部更新，禁止事件到来后全图扫描与全量重算。
**状态：** Accepted

## D-099 — Context 使用 Work Base + Task Delta 复用

**决定：** 同一 Work Item 的多个 Runtime / Agent 不重复构造完整 Context；共享基础上下文并只增加任务差量，以降低延迟与 Token 成本。
**状态：** Accepted

# 73. Flow Visualization Framework — 流程框架必须成为一等可视化对象

## 73.1 核心原则：Process Truth First, Visualization Second

流程框架不是“AI 画了一张流程图”，而是 Workbench 中真实存在的结构化执行对象。

```text
Conversation / Work Item
          │
          ▼
      Task Graph
          │
          ├── Task
          ├── Dependency
          ├── Handoff
          ├── Review
          ├── Retry / Repair
          ├── Approval
          └── Runtime Assignment
          │
          ▼
     Workbench Events
          │
          ▼
      Flow Projection
          │
    ┌─────┼──────────┐
    ▼     ▼          ▼
 Timeline Canvas   Lifecycle
```

**真源始终是 Scheduler / Event Store / Work State，图只是 Projection。**

## 73.2 Flow Projection IR

引入 Runtime-neutral 的 `FlowProjectionIR`，与 DeepSeek / Codex 原生事件解耦。

建议基础结构：

```ts
interface FlowProjectionIR {
  schemaVersion: number;
  flowId: string;
  revision: number;
  mode: 'workflow' | 'collaboration' | 'sequence' | 'lifecycle' | 'architecture';
  nodes: FlowNode[];
  edges: FlowEdge[];
  lanes?: FlowLane[];
  groups?: FlowGroup[];
  focusPath?: string[];
  sourceRefs: ResourceRef[];
  generatedAt: string;
}
```

节点应引用真实对象：

```text
Task Node      → taskId
Agent Node     → agentId
Runtime Node   → bindingId
Approval Node  → approvalId
Artifact Node  → artifactId
Memory Node    → memoryId（仅在专门视图需要时）
```

边同样必须有业务语义：

```text
depends_on
handoff
parallel
review
repair
retry
wait_for
merge
condition_true
condition_false
```

禁止只保存视觉意义上的 `lineA -> lineB` 而丢掉真实语义。

## 73.3 三种可视化层级

### Level A — Lightweight Activity

单 Agent / 单 Runtime / 短任务：

```text
Codex ● Working
├ Reading repository
├ Editing 3 files
└ Tests running
```

不调出 Canvas。

### Level B — Workflow

任务进入明显多阶段时：

```text
Analyze ✓ → Plan ✓ → Implement ● → Test ○ → Review ○
```

可视化“流程”。

### Level C — Collaboration Graph

真实发生多 Runtime / 多 Agent / Handoff / 并行时：

```text
             DeepSeek Planner ✓
                /          \
               ▼            ▼
       Codex Backend ●   Codex Test ●
               \            /
                ▼          ▼
              DeepSeek Review ○
```

可视化“谁在干什么以及怎么协作”。

## 73.4 可视化必须回答的问题

用户不应只看到节点，而应该一眼回答：

1. 当前谁在工作？
2. 它负责哪个 Task？
3. 为什么这个 Task 被交给它？
4. 前置依赖是什么？
5. 当前正在使用什么 Runtime / Model？
6. 当前状态：Queued / Running / Waiting / Blocked / Review / Done？
7. 是否正在等待用户 Approval？
8. 是否出现 Retry / Repair？
9. 哪些 Task 可以并行？
10. 当前成本和累计成本是多少？
11. 哪些文件 / Artifact 被修改？
12. 下一步会发生什么？

## 73.5 动态只表达真值

借鉴 Archify 的有限动效思想，Live Canvas 的动画不能承担只有动画才能看懂的业务语义。

允许：

- Running 节点轻量脉冲；
- Handoff 边一次性流动提示；
- 新 Task 局部出现；
- 状态改变做有限过渡；
- 用户点击后播放一次已发生流程的 Story / Replay。

禁止：

- 永久高速流动造成 GPU / CPU 浪费；
- 动画暗示真实系统中不存在的数据流；
- 用模型生成动画路径代替真实 Task Dependency；
- 后台不可见 Canvas 仍保持连续动画。

需尊重 `prefers-reduced-motion` 与 Workbench 性能模式。

## 73.6 Last-Good Projection

借鉴 Archify 的“失败时保留最后好图”思想：

```text
Event Revision 108
      ↓
Projection Candidate 109
      ↓
Validate
  ├ Pass → Commit Revision 109
  └ Fail → UI 继续显示 Revision 108
             + 标记 Projection degraded
```

Canvas 数据异常不得导致整个 Agent Run 页面不可用。

---

# 74. Flow IR Validation

## 74.1 为什么需要验证器

多 Agent 以后，错误可视化会比“不显示可视化”更危险。

例如真实状态：

```text
Review 等待 Implement 完成
```

但 UI 如果错误显示：

```text
Review Running
```

用户会误判 Agent 当前动作。

因此 `FlowProjectionIR` 在提交给 Canvas 前需要低成本验证：

- nodeId 唯一；
- edge endpoint 存在；
- Task 依赖引用合法；
- 不允许把终态节点显示为 Running；
- Running Task 必须有合法 Run / Runtime Binding；
- Handoff from/to 与真实 Handoff Object 对应；
- Approval 状态与 Event Store 一致；
- Cost 不允许大于 Usage Ledger 当前值；
- revision 必须单调；
- sourceRefs 可追溯。

## 74.2 Validation 不应每次全图扫描

采用 patch-aware validator：

```text
Event
  ↓
Changed Objects
  ↓
Affected Nodes / Edges
  ↓
Local Validation
  ↓
Revision Commit
```

只有导出、快照、历史回放校验等场景才进行 Full Validation。

---

# 75. Archify 在 Workbench 中的建议定位

## 75.1 不直接承担 Live Runtime Canvas

原因：

- Archify 的强项是从 Typed JSON IR 生成经过验证、便携的系统图；
- 其 DSH 社区集成当前是 Skill-only；
- Live Workbench 需要毫秒级 Event patch、Run 生命周期、队列、Approval、Usage 和 Workspace Lock 等内部状态；
- 如果把 HTML Artifact 当成 Runtime Truth，会造成反向耦合。

## 75.2 建议的三种集成方式

### A. Design Inspiration / Schema Inspiration

第一版必须做：借鉴 Typed IR、Schema Validation、有限动效、路径追踪、来源证据、last-good 输出。

### B. Snapshot / Export Engine

后续可把某个 `FlowProjectionIR` 转换成 Archify-compatible IR，生成：

- Workflow HTML；
- Architecture HTML；
- Lifecycle HTML；
- SVG / PNG；
- WebM 动态流程演示。

用于：

- 工作报告；
- 项目文档；
- PR / 架构 Review；
- Agent Run 复盘；
- 分享给团队成员。

### C. Agent Skill

允许 Personal Agent / DeepSeek / Codex 显式调用 Archify Skill：

```text
/archify current-work
/archify repository
/archify runtime-flow
```

这里生成的是 Artifact，不改变真实 Scheduler 状态。

---

# 76. Memory System — 正式架构

## 76.1 Memory 不是 Conversation History

正式区分：

```text
Conversation History
= 人和 Agent 当时说了什么

Runtime / Event Evidence
= 系统真实做了什么

Memory
= 什么值得未来再次被使用
```

Memory Service 不保存“所有原始事实的唯一副本”，而保存经过归类、可追溯、可更新的长期工作知识。

## 76.2 Memory 是独立基础设施

```text
                  Workbench Core
                        │
                 Memory Gateway
                        │
                 Memory Namespace
              ownerUserId + agentId
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     Local Memory   Server Memory   AI Cluster Memory
        Store          Store           Provider
          │             │             │
          └─────────────┼─────────────┘
                        ▼
            Per-Agent Memory Indexes
            FTS / Vector / Entity / Graph
```

DeepSeek Harness、Codex Harness、未来 Runtime 都可以通过 Memory Gateway 使用记忆，但**只能在当前 Agent 获得授权的 MemorySpace 内检索/写入**。Runtime 不决定记忆所有权，`agentId` 才决定。

## 76.3 Memory Provider Contract

你正在开发的 AI 集群记忆系统建议放在 `MemoryProvider` 后端接口，而不是直接侵入 Agent / Conversation 数据模型。

```ts
interface MemoryProvider {
  probe(): Promise<MemoryCapabilities>;

  put(space: AgentMemorySpace, memory: CanonicalMemory): Promise<MemoryRevision>;
  get(space: AgentMemorySpace, memoryId: string): Promise<CanonicalMemory | null>;
  search(space: AgentMemorySpace, query: MemoryQuery): Promise<MemoryCandidate[]>;
  batchGet(space: AgentMemorySpace, ids: string[]): Promise<CanonicalMemory[]>;

  supersede(space: AgentMemorySpace, input: SupersedeRequest): Promise<void>;
  tombstone(space: AgentMemorySpace, memoryId: string): Promise<void>;
  sync?(space: AgentMemorySpace, cursor: SyncCursor): Promise<SyncDelta>;
}

type AgentMemorySpace = {
  ownerUserId: string;
  agentId: string;
  persistence: 'persistent' | 'ephemeral';
};
```

这样未来可以：

```text
Local SQLite / FTS
        ↓
本地快速记忆

AI Cluster Memory
        ↓
跨设备 / 集群级长期记忆
```

两者可以组合，而不是二选一。

---

# 77. Memory Taxonomy — 记忆类型

## 77.1 Working Memory

当前 Task / Run 的短期工作状态。

特点：

- 生命周期短；
- 不默认成为长期记忆；
- Run 结束后只提取有价值内容。

示例：

```text
当前正在修改 runtime-router.ts
测试还剩 2 项
用户要求先不要动数据库
```

## 77.2 Episodic Memory

保存“发生过什么”的可复用经验摘要。

```text
2026-08-28
Agent Page PRD 讨论时，最终将 Conversation 与 Work Item 解耦。
```

必须带 `sourceRefs`。

## 77.3 Semantic Memory

稳定事实、概念、项目知识。

```text
Workbench 采用双 Harness，一次任务优先单 Runtime。
```

## 77.4 Procedural Memory

保存“怎么做”。

```text
Skill
Workflow Template
Runbook
Tool Usage Pattern
```

## 77.5 Preference Memory

用户明确或高置信度形成的个人偏好。

```text
默认成本策略 = Balanced
```

敏感偏好必须受隐私策略限制。

## 77.6 Project-scoped Agent Memory

这是**当前 Agent 自己**针对某个 Project 形成的长期经验与上下文，不是项目成员共享的记忆池。

```text
该 Agent 对项目约束的理解
该 Agent 过去在此项目遇到的失败与修复经验
该 Agent 对项目词汇、文件结构、工作习惯的长期记忆
```

权威项目事实（Architecture Decision、Requirement、Project State、共享文档）应存放在 Project / Knowledge 数据层；Agent 可以引用和记住其 `sourceRefs`，但不能把自己的 Memory 当作团队事实真源。

## 77.7 禁止 Shared Memory：共享信息属于 Knowledge / Project Data

产品层不设计 `Shared / Organization Memory`。

```text
Agent A MemorySpace  ─┐
Agent B MemorySpace   │ 彼此隔离
Agent C MemorySpace  ─┘

Project Knowledge / Project State / Shared Workspace
= 团队共享事实与协作数据
```

同一用户拥有多个 Agent 时也默认隔离。Agent B 不能因为 ownerUserId 相同就直接检索 Agent A 的 Memory。需要协作时，由 Workbench 通过 Handoff / ResourceRef / Context Package 显式传递必要信息。

---

# 78. Memory Capture Pipeline

## 78.1 Agent 可以提议，Memory Service 决定提交

延续 Scheduler 原则：

> **Agent Proposes, Memory Service Validates & Commits.**

DeepSeek / Codex 可以产生：

```text
memory.candidate
```

但不能绕过策略直接永久写入所有长期记忆。

## 78.2 Capture Pipeline

```text
Conversation / Event / Artifact / Work State
                  │
                  ▼
          Candidate Extractor
                  │
                  ▼
             Classifier
        ┌─────────┼──────────┐
        ▼         ▼          ▼
   Knowledge   Decision    Skill
   Preference  ProjectState NextAction
        │
        ▼
      Dedup
        │
        ▼
 Contradiction Check
        │
        ▼
 Scope / Permission
        │
        ▼
 Confidence / Importance
        │
        ▼
    Commit / Inbox / Drop
```

## 78.3 三种提交路径

### Automatic Commit

只允许高度结构化、低争议状态，例如：

- 已完成 Task；
- 已确认 Decision；
- 用户明确修改的偏好；
- 已确认 Project State。

### Memory Inbox

中等置信度、可能有长期价值但不应直接写死：

```text
“用户似乎更喜欢……”
“可能应该形成一个 Skill……”
```

### Manual Capture

用户主动：

```text
/沉淀本次对话
/沉淀本次工作
/保存为知识卡
/保存为 Skill
```

---

# 79. Memory Provenance / Conflict / Staleness

## 79.1 每条长期 Memory 必须有 Provenance

```ts
interface CanonicalMemory {
  id: string;
  type: MemoryType;
  scope: MemoryScope;
  subject?: string;
  content: unknown;
  confidence: number;
  importance: number;
  sourceRefs: ResourceRef[];
  createdAt: string;
  updatedAt: string;
  revision: number;
  status: 'active' | 'superseded' | 'contested' | 'tombstoned';
}
```

## 79.2 不允许静默覆盖矛盾记忆

例：

旧记忆：

```text
默认 Runtime = DeepSeek
```

新 Decision：

```text
Auto Router 为默认
```

系统应该：

```text
old → superseded
new → active
```

并保留 lineage。

## 79.3 Authority Hierarchy

发生冲突时不能单纯按“最新时间”判断：

```text
Explicit User Decision
    > Approved Project Decision
    > Team Policy
    > Verified Work State
    > Extracted Semantic Memory
    > Inferred Preference
```

具体优先级允许按组织策略配置。

---

# 80. Memory Retrieval Pipeline

## 80.1 每个 Agent Turn 必须经过 Memory Lifecycle，但召回深度按需

正式规则：

> **Retrieval Mandatory, Content On-demand.**

每一个可见 Agent Turn 在进入 Runtime 前都必须先绑定当前 `agentId + memoryNamespaceId`，加载 Core Memory，并至少执行一次当前 Agent 私有 Memory 的轻量召回；但这不等于把全部 Memory 注入模型，也不要求每轮都运行昂贵的 Vector / Graph / HyDE / RAG Fusion。

```text
Incoming Turn
      │
      ▼
Mandatory Recall (Stage A)
├─ Core Memory            # 每轮必载
├─ Private Hot / FTS      # 每轮必查
├─ Current Work hints
└─ Token-budgeted Top-K
      │
      ├── 若信息已足够 ───────────────┐
      │                               │
      ▼                               │
Deep Recall (Stage B, optional)       │
├─ Vector Search                      │
├─ Entity / Graph                     │
├─ Query Rewrite                      │
├─ RAG Fusion / HyDE                  │
└─ Cold Archive                       │
      │                               │
      └──────────────┬────────────────┘
                     ▼
              Candidate Merge
                     ▼
             Namespace / Access
                     ▼
        Relevance + Freshness + Authority
                     ▼
              Dedup / Diversity
                     ▼
                Token Budget
                     ▼
               Context Package
```

Room / Project / Organization 的共享业务数据若被允许使用，由 **Context Broker / Workbench Data Gateway** 作为 Shared Context 挂载；它们不进入 `memory://agent/<agentId>`，也不被定义为 Shared Memory。

## 80.2 建议评分因素

概念上：

```text
score =
  semantic_relevance
+ lexical_relevance
+ project_affinity
+ work_item_affinity
+ authority
+ confidence
+ freshness
+ explicit_pin_bonus
- contradiction_penalty
- stale_penalty
```

具体权重必须通过真实 Benchmark 调整，禁止早期硬编码成看似精确但未经验证的固定公式。

## 80.3 Context Receipt

每次检索后保留低成本 Receipt：

```text
Retrieved 18 candidates
Selected 6
Dropped 12
Reason: token budget / duplicate / stale / scope denied
```

用户需要时可以查看：

> “这次 Agent 为什么知道这个？”

---

# 81. DeepSeek / Codex 如何共享 Memory

## 81.1 Canonical Memory Runtime-neutral

禁止：

```text
DeepSeek Memory DB
Codex Memory DB
```

作为产品层长期记忆。

应该：

```text
                Memory Gateway
                  /       \
                 ▼         ▼
             DeepSeek    Codex
```

不同 Runtime 可以保留自己的临时 Session / Cache，但长期 Memory 统一进入 Workbench Canonical Memory。

## 81.2 Runtime Scratchpad 不自动升级长期记忆

Codex 的临时推理、工具过程、DeepSeek 的临时上下文不应全部进入长期 Memory。

只捕获：

- 最终被确认的结论；
- 对未来任务有价值的经验；
- Project State；
- Decision；
- Skill；
- Next Action；
- 用户明确要求记住的内容。

---

# 82. Local-first + Server / Cluster Memory Sync

## 82.1 默认本地可用

```text
Personal Agent
      ↓
Local Memory Store
      ↓
Local Index
```

无网络时仍能完成本地记忆检索。

## 82.2 开启服务器同步后

```text
Local Memory Journal
       │
       ▼
Incremental Sync
       │
       ▼
Server / AI Cluster Memory
```

只同步变更，不上传整个数据库。

## 82.3 Cluster Sync 保持 Agent 隔离

```text
Agent A MemorySpace
  + Server / Cluster Sync
  = 仍然只属于 Agent A

Agent B MemorySpace
  + Server / Cluster Sync
  = 仍然只属于 Agent B
```

同步只改变存储位置与可恢复性，不改变记忆所有权。**Memory 不支持通过“改 Scope”变成 Project / Organization Shared Memory。** 需要共享时，应把经过用户确认的内容发布为 Knowledge / Decision / Skill / Artifact 等共享业务资源；其他 Agent 是否把这些共享资源再沉淀进自己的 Memory，由各自的 Capture Pipeline 独立决定。

---

# 83. Memory Performance Architecture

## 83.1 分层索引

建议：

```text
Hot Working Set
  ↓
SQLite / KV / FTS
  ↓
Vector Index
  ↓
Graph / Entity Index
  ↓
Cold Archive / Server
```

不是每次查询都打所有索引。Query Planner 根据请求类型选择。

## 83.2 后台任务隔离

以下任务不能阻塞 Agent UI：

- embedding；
- memory consolidation；
- 去重；
- graph relationship extraction；
- server sync；
- stale memory review。

必须放入后台低优先级队列并支持 backpressure。

## 83.3 增量更新

Memory revision 改变时只更新：

```text
affected FTS row
affected vector
affected entity edges
affected ResumeIndex
```

禁止重建整个 Memory Graph。

---

# 84. Memory 可视化与用户控制

Memory 的完整图谱不应常驻 Agent 页，但必须可解释。

Agent 页面只在需要时展示：

```text
Memory Used
6 items

Project Decision ×2
Knowledge ×2
Preference ×1
Previous Work ×1

[查看来源]
```

独立 Knowledge / Memory 页面以后可以提供：

- Memory Cards；
- Source Trace；
- Superseded History；
- Entity Graph；
- 当前 Agent 的 Project-scoped Memory Map；
- Capture Inbox；
- 删除 / 更正 / Pin / 导出；如需团队共享，转为 Knowledge / Decision / Skill 等共享资源，而不是直接 Share Memory。

Memory 图谱同样遵循“真实数据 → Projection”，不能让模型凭空画关系。

---

# 85. Decision Log — v0.16 Flow Visualization + Memory Architecture

## D-100 — 流程框架必须有真实可视化投影

**决定：** Task Graph、Handoff、Review、Approval、Retry、Repair、Runtime Assignment 等真实 Scheduler 状态必须能够投影成 Workflow / Collaboration / Lifecycle 视图。
**状态：** Accepted

## D-101 — Flow Canvas 不成为流程真源

**决定：** Scheduler / Event Store / Work State 是真源，Canvas 仅消费 `FlowProjectionIR`。
**状态：** Accepted

## D-102 — 借鉴 Archify 的 Typed IR + Validator + Last-Good 思想

**决定：** 第一版吸收 Archify 的可验证 IR、有限动效、来源证据和 last-good projection 思想；不把 Archify 的 Skill-only DSH 集成当作 Workbench 实时 Runtime Canvas。
**状态：** Accepted

## D-103 — Archify 优先作为 Snapshot / Export / Skill 能力

**决定：** 后续可把真实 Workbench Flow 转换为 Archify-compatible Artifact，用于 HTML/SVG/PNG/WebM 导出与架构/流程复盘；是否复用具体 Renderer 需在实现阶段评估许可证、性能和 UI 一致性。
**状态：** Accepted

## D-104 — Memory 是 Runtime-neutral 基础设施

**决定：** DeepSeek / Codex 不拥有产品层长期 Memory；统一通过 Workbench Memory Gateway。
**状态：** Accepted

## D-105 — AI 集群记忆系统通过 MemoryProvider 接入

**决定：** 集群记忆后端采用可替换 Provider Contract 接入，Local Memory 与 Server / Cluster Memory 可以组合。
**状态：** Accepted

## D-106 — Memory 写入采用 Candidate Pipeline

**决定：** Agent 可提出 Memory Candidate，但长期提交必须经过分类、去重、冲突、Scope、权限、置信度与重要性策略。
**状态：** Accepted
## D-107 — 长期 Memory 必须可追溯、可 supersede

**决定：** 每条 Canonical Memory 保留 sourceRefs、revision、confidence 和 status；冲突不得静默覆盖。
**状态：** Accepted

## D-108A — Memory Lifecycle 每轮强制执行，召回内容与深度按需

**修订：** 每个可见 Agent Turn 必须执行 `beforeTurnMemory -> Runtime -> afterTurnMemory`。`beforeTurnMemory` 至少加载 Core Memory 并尝试当前 Agent 私有 Memory 的轻量召回；Vector / Graph / HyDE / RAG Fusion 等昂贵策略按需启用。所有召回仍受 Namespace、权限、相关性、去重与 Token Budget 控制，禁止全量注入。
**状态：** Accepted；Supersedes D-108

## D-109 — Memory 永远按 Agent 隔离，同步不改变所有权

**决定（v0.16.1 修正）：** 每个 Agent 拥有独立 MemorySpace。服务器 / AI 集群同步只用于该 Agent 的跨设备恢复、检索和持久化，不会把 Memory 变成 Project / Organization Shared Memory，也不会自动开放给同一用户的其他 Agent。
**状态：** Accepted

## D-110 — Memory 后台维护必须与前台 Agent 执行隔离

**决定：** embedding、consolidation、graph extraction、sync 等通过低优先级后台队列和 backpressure 执行，不阻塞 Composer、Run 或 Canvas。
**状态：** Accepted

# 86. Agent-Isolated Memory Model — v0.16.1 修正

## 86.1 Memory 的所有权单位是 Agent，不是 Team，也不只是 User

正式所有权关系：

```text
User A
├─ Personal Primary Agent A1
│    └─ MemorySpace(userA, agentA1)
├─ Custom Agent A2
│    └─ MemorySpace(userA, agentA2)
└─ Custom Agent A3
     └─ MemorySpace(userA, agentA3)

User B
└─ Personal Primary Agent B1
     └─ MemorySpace(userB, agentB1)
```

即使 A1、A2、A3 都属于同一个用户，它们的长期记忆也默认彼此隔离。

## 86.2 AI 集群记忆系统是隔离的 Memory Fabric，不是公共记忆池

建议把未来 AI 集群记忆系统理解为：

```text
                 AI Cluster Memory
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
 MemorySpace A1    MemorySpace A2    MemorySpace B1
  userA/agentA1     userA/agentA2     userB/agentB1
        │               │               │
     indexes          indexes          indexes
```

Cluster 可以共享计算、索引服务、存储节点和同步协议，但不能默认共享记忆内容。

必须以 `ownerUserId + agentId` 作为硬隔离键；服务端查询、向量检索、Graph 查询、增量同步都必须先绑定 MemorySpace，再执行检索。

## 86.3 每个 Agent 都拥有自己的 Capture → Retrieve → Consolidate 闭环

```text
Agent A
  Conversation / Run / Experience
              ↓
       Memory Candidate
              ↓
    Agent A MemorySpace
              ↓
     Retrieval / Reuse
              ↓
           Agent A
```

Agent B 同样拥有自己的闭环。A 的 `memory.candidate` 不能直接写入 B 的 MemorySpace。

## 86.4 多 Agent 协作不通过互读 Memory 实现

例如：

```text
DeepSeek Planner Agent
       │
       │ Handoff Package
       ▼
Codex Engineer Agent
```

交接内容来自：

- 当前 Work Item；
- Task Definition；
- Shared Project Knowledge；
- Workspace ResourceRef；
- 当前 Agent 显式选择的 Memory-derived 摘要；
- Approval / Cost / Permission Envelope。

Codex Engineer 不需要也不应直接打开 Planner Agent 的私有 Memory DB。

这保证了：

- Agent 身份稳定；
- 记忆不会互相污染；
- Handoff 内容可审计；
- 多 Agent 协作时上下文成本可控；
- 删除一个 Agent 时能够明确删除/保留其 MemorySpace。

## 86.5 临时 Agent 也有独立 MemorySpace，但生命周期可以不同

每个 Agent 都有独立记忆命名空间，但不是每个 Agent 都必须永久保存。

建议：

```text
Persistent Agent
→ persistence = persistent
→ Local First + Optional Cluster Sync

Temporary / Spawned Agent
→ persistence = ephemeral by default
→ 独立 MemorySpace + TTL
→ 如果用户把它保存为长期 Agent，再显式 Promote MemorySpace
```

这里的“ephemeral”只表示生命周期，不表示与其他 Agent 共用记忆。

## 86.6 Shared Knowledge 与 Agent Memory 必须分层

如果团队成员共同确认：

```text
D-039 Workbench Event Store 是产品层真源
```

它应该进入：

```text
Project Decision / Knowledge
```

而不是写进一个所谓 Team Shared Memory。

各 Agent 可以：

```text
读取 Project Decision
      ↓
在自己的 MemorySpace 形成引用 / 经验
```

因此共享事实只有一个权威来源，而每个 Agent 对它形成的经验和长期理解仍然独立。

## 86.7 跨 Agent“学习”必须显式发生

未来如果用户希望 Agent B 学习 Agent A 的某些经验，不做透明跨库检索，而使用显式操作，例如：

```text
Export Memory Candidate
        ↓
用户 / Policy 审核
        ↓
Import to Agent B
        ↓
Agent B Capture Pipeline
        ↓
Agent B 自己的新 Memory Revision
```

更推荐的共享路径是把可复用内容提升为 Knowledge / Skill / Decision，再让各 Agent 按需学习，而不是复制整套私有 Memory。

## 86.8 关于提供的“五层记忆系统”资料

用户提供的资料明确说明：已有“五层记忆系统”可以适配 DeepSeek Harness，并且 Harness 支持多个自定义 Agent、可在原版 Agent 之外持续定制自己的 Agent；资料还展示了 Skill 自动路由的方向。当前这份转写**没有展开五层各自的精确定义，也没有明确说明各 Agent MemorySpace 的隔离协议**。因此 Workbench 现在只锁定“每 Agent 独立记忆 + Provider 接入”的平台边界，不擅自重定义用户现有五层模型。等获得 AI 集群记忆系统的正式结构文档后，再做字段级 Adapter Mapping。

---

# 87. Decision Log — v0.16.1 Agent-Isolated Memory Correction

## D-111 — 每一个 Agent 都拥有独立 MemorySpace

**决定：** Memory 所有权键至少为 `ownerUserId + agentId`。同一用户的多个 Agent 也不得默认共享长期 Memory。
**状态：** Accepted

## D-112 — AI 集群记忆系统不是共享记忆池

**决定：** Cluster Memory 可以共享底层计算与存储基础设施，但所有检索、写入、同步与索引必须绑定具体 Agent MemorySpace。
**状态：** Accepted

## D-113 — 产品层取消 Shared / Organization Memory 概念

**决定：** 团队/项目共享事实由 Knowledge、Project State、Decision、Skill、Workspace 等共享数据域承载；Memory 保持 Agent-private。
**状态：** Accepted

## D-114 — 多 Agent 协作通过 Handoff / Context Package，不互读私有 Memory

**决定：** Agent 间传递必要上下文必须形成显式、可审计的 Handoff / ResourceRef / Context Package；不得通过默认跨 Agent Memory Search 实现协作。
**状态：** Accepted

## D-115 — 临时 Agent 也隔离 Memory，只改变生命周期

**决定：** Temporary / Spawned Agent 默认获得独立 ephemeral MemorySpace；是否长期保存由 Agent 生命周期策略决定，隔离规则不变。
**状态：** Accepted

## D-116 — 五层记忆系统采用 Adapter Mapping，不在缺少正式定义时重写语义

**决定：** 当前仅确定 MemoryProvider / AgentMemorySpace 接口。待用户提供 AI 集群五层记忆系统正式结构后，再映射其五层模型、召回策略、合并策略与存储协议；不根据视频转写自行推断五层含义。
**状态：** Accepted



# 88. Agent Identity / Definition / Instance / Runtime / Memory 四层模型（Draft v0.17）

## 88.1 Agent 是长期产品实体，不是 Harness Session

正式区分：

```text
Agent Definition
= 可复用的模板 / 说明 / Skills / Tool requirements / UI metadata

Agent Instance
= 某个用户真正拥有和长期使用的 Agent 个体

Runtime Binding
= 本次/当前由 DeepSeek Harness、Codex Harness 或未来 Runtime 执行

MemorySpace
= 该 Agent Instance 独有的长期记忆命名空间
```

硬约束：

```text
Agent Identity ≠ Runtime
Agent Identity ≠ Model
Agent Identity ≠ DeepSeek Session
Agent Identity ≠ Codex Thread
```

建议对象：

```ts
interface AgentIdentity {
  agentId: string;
  ownerUserId: string;
  definitionId: string;
  definitionVersion: string;
  memoryNamespaceId: string;
  displayName: string;
  status: 'active' | 'disabled' | 'archived';
  createdAt: string;
}
```

其中 `agentId` 与 `memoryNamespaceId` 在 Runtime / Model 切换时保持不变。

## 88.2 每个 Agent Instance 必须有唯一 Private Memory Namespace

```text
Agent A -> memory://agent/A
Agent B -> memory://agent/B
Agent C -> memory://agent/C
```

同一用户拥有 A/B/C，也不得默认跨读。底层 Memory Cluster 可以共用存储节点、索引引擎、Embedding Worker、Graph Engine 与缓存基础设施，但逻辑隔离必须以 `ownerUserId + agentId + namespaceId` 强制执行。

## 88.3 Agent Definition 可共享，Agent Memory 不共享

同一个 Definition 可以被不同用户或同一用户多次实例化：

```text
Definition: Senior Python Architect
      │
      ├─ Agent Instance A -> MemorySpace A
      └─ Agent Instance B -> MemorySpace B
```

随着长期使用，两个 Agent 可以形成完全不同的经验。

---

# 89. Mandatory Agent Memory Turn Lifecycle

## 89.1 Memory 不是可选 Tool，而是 Runtime 外围生命周期 Gate

禁止把长期记忆可靠性建立在：

```text
LLM 自己决定“这轮要不要 memory.search”
```

正式执行链：

```text
Incoming Event / User Message
           │
           ▼
Resolve Agent Identity
           │
           ▼
PRE-TURN MEMORY GATE
├─ verify agentId <-> namespace binding
├─ load Core Memory                 # mandatory
├─ private Mandatory Recall         # mandatory attempt
├─ optional Deep Recall
├─ build MemoryTurnReceipt (pre)
└─ hand results to Context Broker
           │
           ▼
Context Broker
├─ Agent Definition
├─ Core + selected Private Memory
├─ Work / Conversation state
├─ allowed Shared Context refs
└─ User Input
           │
           ▼
Runtime Adapter
DeepSeek / Codex / Future Runtime
           │
           ▼
Agent Output / Runtime Evidence
           │
           ▼
POST-TURN MEMORY GATE
├─ evaluate capture every turn
├─ candidate extraction
├─ dedup / contradiction / authority
├─ commit / supersede / inbox / drop
└─ finalize MemoryTurnReceipt
```

这层组件命名：

```text
Agent Turn Orchestrator
```

它只负责 Lifecycle Gate / Context Wrapper / Runtime 调用编排，**不实现第三套 Agent Loop**。

## 89.2 Agent Turn Orchestrator 接口建议

```ts
interface AgentMemoryLifecycle {
  beforeTurn(input: BeforeTurnInput): Promise<MemoryContextReceipt>;
  afterTurn(input: AfterTurnInput): Promise<MemoryCommitReceipt>;
}

interface BeforeTurnInput {
  agentId: string;
  memoryNamespaceId: string;
  conversationId?: string;
  projectId?: string;
  workItemId?: string;
  roomId?: string;
  userInput: string;
  tokenBudget: number;
  accessEnvelopeId: string;
}
```

`RuntimeAdapter.startRun()` / `startTask()` 不允许存在绕过 `beforeTurn()` 的公开产品路径。

## 89.3 Memory Failure Policy

因为 Memory Lifecycle 是 Agent 连续性的硬约束，所以禁止静默退化成“裸 LLM”。

建议：

```text
Core Memory 无法读取
→ MEMORY_CORE_UNAVAILABLE
→ 默认阻断正常 Agent Turn

Cluster 不可用，但本地 Replica 可用
→ MEMORY_DEGRADED_LOCAL
→ 允许继续并记录 Receipt

Vector / Graph 不可用
→ 降级到 FTS / metadata
→ 允许继续并记录 degraded reason

全部 Memory Provider 不可用
→ 默认阻断
→ 只有用户显式选择 Temporary No-Memory Mode 才可继续
```

---

# 90. MemoryTurnReceipt — 证明这一轮真的用了哪个 Agent 的记忆

每一个可见 Agent Turn 都生成 Receipt：

```ts
interface MemoryTurnReceipt {
  receiptId: string;
  agentId: string;
  turnId: string;
  namespaceId: string;

  coreLoaded: boolean;
  coreRevision?: number;

  privateSearchAttempted: boolean;
  privateCandidates: number;
  privateSelected: number;

  sharedContextRefs: string[];
  contextMemoryRefs: string[];
  droppedReasons: string[];

  degradedMode?: string;
  latencyMs: number;
  providerTraceIds: string[];
  createdAt: string;
}
```

它解决的不是 UI 装饰，而是可观测性：

```text
这一轮有没有调用 Memory？
调用的是哪个 Agent Namespace？
Core revision 是什么？
候选多少？最终注入多少？
为什么某条 Memory 被丢弃？
是否发生 namespace mismatch / permission deny / degraded mode？
```

Agent 页默认只显示轻量状态：

```text
Memory ✓
6 items used · 34ms
```

Developer Details / Memory Inspector 才展开完整 Receipt。

---

# 91. Shared Context，不做 Shared Memory

## 91.1 群聊 / Project 可以共享事实，但不共享 Agent 私有记忆

正式模型：

```text
                    Shared Context Plane
        Project Knowledge / Decision / Work State
        Room Transcript / Task / Handoff / Artifact
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
          Agent A     Agent B     Agent C
          Memory A    Memory B    Memory C
```

当 Agent B 发言：

```text
B Core Memory
+ B Private Memory
+ 当前 Room 必要消息
+ Project Knowledge / Decision / State
+ 当前 Work Item / Handoff
→ B Runtime
```

禁止：

```text
A Private + B Private + C Private -> B
```

因此，V2 外部需求中提到的 `room/project/organization shared memory namespace` 在 Team Workbench 内部**重命名并收敛为 Shared Context Domain / Shared Business Data**，不进入 Agent Memory Provider 的私有记忆语义。

## 91.2 群聊结束以后各 Agent 独立沉淀

同一段协作后：

```text
Agent A -> 自己的 Episodic / Lesson
Agent B -> 自己的 Episodic / Lesson
Agent C -> 自己的 Episodic / Lesson
```

Room / Project 若产生公共结论，则写入：

```text
Decision
Knowledge
Task / Work State
Artifact
Skill（经确认）
```

而不是“Room Shared Memory”。

---

# 92. Agent Create / Import / Clone / Upgrade

Workbench 后续应支持：

```text
Create Agent
Import Agent Package
Install Agent Definition
Clone Agent
Archive Agent
Export Agent Definition
```

建议 Agent Package：

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

安全规则：

- 安装时由 Workbench 分配新的 `agentId + memoryNamespaceId`；
- 第三方包不能指定已存在的 Namespace；
- Definition 升级不删除 Memory；
- Clone 默认只复制 Definition，创建空白 Private Memory；
- `Clone with memory snapshot` 必须是显式高级操作，并创建新的 namespace lineage；
- 两个 Agent 永远不能长期共享同一可写 Private MemorySpace。

---

# 93. Hundreds-of-Agents Scale Model

## 93.1 800 个 Agent 是 800 个逻辑身份，不是 800 个常驻模型

```text
Agent Registry
├─ Agent 001 -> Namespace 001
├─ Agent 002 -> Namespace 002
├─ ...
└─ Agent 800 -> Namespace 800
        │
        ▼
Scheduler
        │
        ▼
Active Agent Set
        │
        ▼
Runtime Pool
├─ DeepSeek workers
├─ Codex workers
└─ future workers
```

激活某 Agent 时：

```text
Resolve agentId
→ Resolve MemorySpace
→ beforeTurnMemory
→ Resolve Runtime
→ Execute
→ afterTurnMemory
→ release / reuse worker
```

性能规则：

- Agent Registry 查询必须有索引，禁止扫描全部 Agent；
- Private Memory Search 必须先做 namespace narrowing；
- Hot Agent 可以缓存 Core / Hot Memory；
- Cold Agent 不常驻 Runtime；
- Cache key 至少包含 `agentId + namespaceRevision`；
- Room 有 100 Agent 不代表调用 100 个模型，只激活 Scheduler 认为需要发言/执行的 Agent；
- 临时 Agent 同样有独立 ephemeral MemorySpace，可 TTL 回收或 Promote 为 Persistent Agent。

---

# 94. Linux-first 非 Docker 官方部署与 OSS Integration Registry

## 94.1 官方路径不依赖 Docker / Docker Compose

当前 Linux-first 版本建议：

```text
Tier A — Native + systemd（默认）
- Workbench Core
- Memory Gateway / Memory Node
- Indexer / Worker
- Runtime Supervisor
- Sync Service

Tier B — Rootless Podman + systemd Quadlet（可选）
- 仅用于确实适合容器化的第三方组件

Tier C — systemd-nspawn / Incus / LXC（可选）
- 高风险工具或需要独立 rootfs 的服务
```

MVP 不因为“未来可能有数百 Agent”而提前引入 Kubernetes；逻辑 Agent 数量与常驻服务数量不是同一个维度。

## 94.2 OSS 不做源码大拼接

所有外部开源组件必须进入 `Integration Registry`：

```yaml
id: <component-id>
upstream: <repository>
role: runtime|memory|index|embedding|graph|workflow|visualization|sandbox|sync|observability
version: <pinned tag/commit>
license: <license>
integration: library|stdio|uds|http|sidecar|cli
state_owner: true|false
data_dir: <path>
healthcheck: <command/interface>
upgrade_policy: pinned
patches: []
```

统一内部合同：

```text
RuntimeAdapter
MemoryProvider
IndexProvider
EmbeddingProvider
ParserProvider
GraphProvider
FlowRendererAdapter
SandboxProvider
SyncProvider
```

优先通过 stdio / Unix Domain Socket / local RPC / sidecar 保持上游边界；只有稳定、无状态、接口明确的库才适合直接 link/import。

当前已知定位：

```text
DeepSeek Harness -> General RuntimeAdapter
Codex / app-server -> Engineering RuntimeAdapter
Archify -> Flow Snapshot / Export Adapter
Boujoy Harness -> 产品 / IA 参考，不作为核心真源
Tauri -> Desktop Host / UI Shell
```

---

# 95. Decision Log — v0.17 Agent Memory Lifecycle & Registry

## D-117 — Agent Definition / Instance / Runtime / Memory 四者独立建模

**决定：** Agent Definition 是模板；Agent Instance 是长期产品实体；Runtime Binding 只负责执行；MemorySpace 永久绑定 Agent Identity。Runtime / Model / Harness Session 切换不能改变 Agent 身份或私有记忆命名空间。
**状态：** Accepted

## D-118 — 每个可见 Agent Turn 必须执行 Pre/Post Memory Lifecycle

**决定：** 所有产品层 Agent Turn 必须执行 `beforeTurnMemory -> Runtime -> afterTurnMemory`。模型不能绕过基础记忆召回，也不能自行决定是否执行 Capture Evaluation。
**状态：** Accepted

## D-119 — Mandatory Recall 与 Deep Recall 分离

**决定：** Core Memory + Agent Private 轻量召回为每轮必执行 Stage A；Vector / Graph / HyDE / RAG Fusion / Cold Archive 为按需 Stage B，避免“每轮必调 Memory”演化成高延迟全量 RAG。
**状态：** Accepted

## D-120 — 每个 Agent Turn 生成 MemoryTurnReceipt

**决定：** Receipt 必须记录 agentId、namespaceId、Core revision、Private recall attempted/selected、degraded 状态、延迟与最终 Memory refs，作为记忆是否真正生效的审计事实。
**状态：** Accepted

## D-121 — Shared Context 与 Agent Private Memory 分层

**决定：** Room / Project / Organization 的共享事实不建立 Shared Memory 池；通过 Workbench Knowledge / Decision / State / Room / Artifact 等 Shared Context Domain 挂载给 Agent。每个 Agent 只写自己的 Private MemorySpace。
**状态：** Accepted

## D-122 — Agent Clone 默认只克隆 Definition

**决定：** Clone 默认创建新的 Agent Identity 与空白 MemorySpace；复制 Memory Snapshot 必须显式操作，并形成新的 lineage，禁止两个 Agent 长期共享同一可写 Namespace。
**状态：** Accepted

## D-123 — Hundreds-of-Agents 使用 Registry + Runtime Pool

**决定：** 数百 Agent 是逻辑实例规模，不对应相同数量的常驻 Runtime。Scheduler 只激活实际需要执行的 Agent；冷 Agent 只保存 Definition / Memory / Index 元数据。
**状态：** Accepted

## D-124 — Memory 故障不得静默回退到裸 LLM

**决定：** Core Memory 不可用默认阻断正常 Agent Turn；Cluster / Vector / Graph 故障可以按明确降级规则使用 Local / FTS，并写入 Receipt。完全无 Memory 时仅允许用户显式进入临时无记忆模式。
**状态：** Accepted

## D-125 — 官方部署不依赖 Docker / Docker Compose

**决定：** Linux-first 官方部署以 Native + systemd 为首选；需要容器隔离时允许经过批准的 Rootless Podman / Quadlet 或 systemd-nspawn / Incus / LXC。Docker / Docker Compose 不作为官方部署依赖。
**状态：** Accepted

## D-126 — 外部开源项目必须经 Integration Registry + Stable Contract 接入

**决定：** 禁止十多个上游项目通过源码大拼接成为产品核心；每个上游必须登记版本、License、职责、数据所有权、集成协议、健康检查和升级策略，并通过 Workbench 内部 Adapter / Provider Contract 接入。
**状态：** Accepted


---

# 96. Agent Memory Studio — 每一个 Agent 的记忆必须可视化（Draft v0.18）

## 96.1 产品原则

Memory 不能只存在于向量库、索引或后台 API 中。既然每个 Agent 是长期存在的独立个体，并拥有自己的 `MemorySpace`，用户就应该能够真正“打开这个 Agent 的脑内长期记忆”，查看它记住了什么、为什么记住、什么时候形成、在哪一轮被使用，以及哪些记忆已经失效或发生冲突。

正式原则：

> **Agent owns memory; user can inspect the memory of the Agent they own.**

> **Memory is observable, editable, revisioned and traceable — but never silently overwritten.**

这意味着任意持久 Agent 都应拥有一个逻辑入口：

```text
Agent Instance
    │
    └── Memory
         ├── Overview
         ├── Layers
         ├── Timeline
         ├── Graph
         ├── Search
         ├── Turn Trace
         └── Revisions
```

Memory 可视化不是独立于 Memory Service 的第二套数据，而是 Canonical Agent Memory 的实时投影。

## 96.2 Memory 入口不限定在单一页面

为了不把 Memory 变成一个“藏在设置里的功能”，同一个 Agent MemorySpace 可以从多个产品入口进入：

```text
Personal Agent Header
→ Memory

Agent Registry / Agent Card
→ 查看记忆

Conversation 某条 Agent 回复
→ 本轮使用的记忆

Work Capsule
→ 与本工作相关的 Agent 记忆

Memory Center
→ 选择“我的某个 Agent”后查看其 MemorySpace

Group Room Participant Card
→ 仅在当前用户有权查看该 Agent Private Memory 时开放
```

这些入口都必须解析到同一个：

```text
agentId + memoryNamespaceId
```

不得因为入口不同而创建不同 Memory 副本。

## 96.3 Agent Memory 首页 / Overview

建议第一屏回答六个问题：

```text
这个 Agent 是谁？
它的 Core Memory 是什么？
最近形成了哪些记忆？
哪些记忆最常被召回？
现在有没有冲突 / 过期 / 待确认 Memory？
最近一轮到底用了哪些 Memory？
```

示例：

```text
Architect Agent                                     ● Healthy
MemorySpace: mem_ag_architect_07

Core Memory                 revision 27
6 items · updated 2d ago

Active Memory
Semantic       184
Episodic       327
Procedural      51
Preference      18
Lesson          73

Recent Capture
+ “Runtime 切换不得改变 Agent Identity”
+ “Review fail 应创建 Repair Task”

Attention
2 contested
4 stale candidates
1 core change awaiting confirmation

Last Turn
Recall attempted ✓
19 candidates → 5 selected
43ms

[打开 Memory Trace] [查看图谱] [搜索记忆]
```

Overview 的计数、健康状态和最近项目均从增量 Projection 获取，禁止每次打开扫描完整 MemorySpace。

---

# 97. Memory 的六种可视化视角

Memory 本体保持 Canonical 模型；UI 根据用户问题提供不同 Projection。

## 97.1 Layers View — 看“这个 Agent 的脑子由什么组成”

当前 Workbench Canonical 类型：

```text
Core
Episodic
Semantic
Procedural
Preference
Lesson
```

可做成分层视图：

```text
┌ Core ─────────────────────────────┐
│ 身份 / 长期原则 / 禁止事项        │
└───────────────────────────────────┘

┌ Semantic ─────────────────────────┐
│ 稳定事实 / 项目知识               │
└───────────────────────────────────┘

┌ Procedural / Lesson ──────────────┐
│ 怎么做 / 为什么 / 失败经验        │
└───────────────────────────────────┘

┌ Episodic ─────────────────────────┐
│ 这个 Agent 自己经历过什么         │
└───────────────────────────────────┘

┌ Preference ───────────────────────┐
│ 该 Agent 与用户协作时的稳定偏好   │
└───────────────────────────────────┘
```

注意：这只是当前 Workbench 的 Canonical 分类投影。等 AI 集群“五层记忆系统”的正式 Layer 定义完整接入后，使用 `MemoryLayerAdapter` 映射，不强行把现有六类名称当成五层系统本体。

## 97.2 Timeline View — 看“它是怎么成长的”

按时间展示：

```text
Aug 28
├ learned      Runtime Stickiness reduces unnecessary handoff
├ corrected    Default Runtime: DeepSeek → Auto Router
├ lesson       Retry != Repair
└ preference   Cost Strategy = Balanced

Aug 27
├ episodic     Failed review in Agent Page task
└ procedural   New review/repair workflow validated
```

支持过滤：

```text
All / Learned / Corrected / Superseded / User Edited / AI Derived
```

## 97.3 Graph View — 看“记忆之间怎么关联”

Graph 不直接读取 Vector DB 私有结构，而消费稳定的 `MemoryProjectionIR`。

典型关系：

```text
related_to
supports
contradicts
supersedes
derived_from
used_with
caused_by
validated_by
```

例如：

```text
[Single Runtime First]
        │ supports
        ▼
[Runtime Stickiness]
        │ derived_from
        ▼
[Hybrid Cost Reduction Lesson]

[Old: DeepSeek is permanent lead]
        │ superseded_by
        ▼
[Auto Lead Runtime]
```

用户点节点可打开 Memory Detail；点边可查看关系来源和 `sourceRefs`。

## 97.4 Search / Table View — 精确管理

面向大量 Memory 的高密度视图：

```text
Title | Type | Status | Importance | Last Used | Revision | Source
```

支持：

```text
FTS
Semantic Search
Type Filter
Status Filter
Time Range
Source Filter
Work / Project Affinity
```

所有查询首先使用 `agentId + namespaceId` 缩小范围。

## 97.5 Turn Trace — 看“这一句话为什么这样回答”

这是 Memory 可视化最关键的视图之一。

任意 Agent 回复都可以展开：

```text
User Turn
   │
   ▼
PRE-TURN MEMORY GATE
   │
   ├ Core revision 27
   ├ Private recall: 19 candidates
   ├ Selected: M-18, M-42, M-77, M-91, M-102
   └ Dropped: stale 3 / duplicate 7 / budget 4
   │
   ▼
Context Package
   │
   ▼
Runtime: DeepSeek / Codex
   │
   ▼
Agent Response
   │
   ▼
POST-TURN MEMORY GATE
   │
   ├ Candidate C-889: Lesson
   └ Candidate C-890: Semantic
```

用户可以回答：

```text
这个 Agent 为什么知道这个？
这一轮到底用了哪些记忆？
为什么某条记忆没被选中？
这次回答又产生了什么新记忆？
```

Turn Trace 的事实来源是 `MemoryTurnReceipt + Context Package + Workbench Event Store`，不是模型事后自述。

## 97.6 Revision / Diff View — 看“记忆是怎么被改的”

所有人工或 AI 修改均形成 revision：

```text
Revision 26
Default Runtime = DeepSeek

Revision 27
Default Runtime = Auto Router
Reason
Architecture decision changed

Actor
user

Source
D-007 / Conversation C-18
```

支持：

```text
Compare
Restore as new revision
Supersede
Archive
Tombstone
```

不得在 UI 中直接覆盖旧值而不留历史。

---

# 98. Memory Editor — 用户可以添加、修改和纠正 Agent 记忆

## 98.1 允许的管理操作

Agent Owner 默认可对自己的 Agent 执行：

```text
Add Memory
Edit -> create new revision
Pin / Unpin Core Memory
Change Type
Adjust Importance
Mark Contested
Supersede
Archive
Tombstone
Attach SourceRef
Add Human Note
```

## 98.2 “编辑”不是数据库 UPDATE 覆盖

正确流程：

```text
Memory revision N
      │
User Edit
      │
      ▼
Validate
      │
      ▼
Memory revision N+1
      │
      ├ reindex
      ├ invalidate affected cache
      └ emit memory.revised
```

如果修改的是 Core Memory，需要额外显示 Diff 和影响提示，因为它会在未来每个 Turn 中被强制加载。

## 98.3 用户手动添加 Memory

手动新增必须明确标识：

```text
origin = user-authored
actor = <user>
sourceRefs = optional
```

不能伪装成“AI 自己经历后形成”的 Episodic Memory。

如果用户输入：

```text
“以后这个架构师 Agent 永远优先检查数据真源边界。”
```

系统可以建议保存为：

```text
Core / Lesson / Preference
```

但最终类型和提交由用户确认或既定 Policy 决定。

## 98.4 可逆与审计

Memory Studio 的人工操作必须支持：

```text
revision history
undo via new revision
actor audit
source refs
reindex status
sync status
```

对高敏感 Agent，可进一步要求本地认证或策略审批；Memory 可视化能力不得降低 Private Memory 隔离边界。

---

# 99. MemoryProjectionIR — 可视化不能成为第二套 Memory 真源

定义运行时中立 Projection：

```ts
interface MemoryProjectionIR {
  schemaVersion: number
  agentId: string
  namespaceId: string
  revision: number

  summary: {
    coreRevision: number
    activeCount: number
    candidateCount: number
    contestedCount: number
    lastRecallAt?: string
    lastCaptureAt?: string
  }

  nodes: MemoryProjectionNode[]
  edges: MemoryProjectionEdge[]
  timeline?: MemoryTimelineItem[]
  receipts?: string[]
}
```

原则：

```text
Canonical Memory Store
        │
        ▼
Memory Projection Engine
        │
        ├ Overview Projection
        ├ Timeline Projection
        ├ Graph Projection
        ├ Search Projection
        └ Turn Trace Projection
```

Graph / Timeline / Overview 删除后都能从 Canonical Memory + Event / Receipt 重建。

---

# 100. DeepSeek Harness Glass Box — 从 Memory 可视化扩展到整个 Agent 运行透明化

用户提供的 DeepSeek Harness 参考材料提出了几个非常值得 Workbench 吸收的方向：运行时插件可以动态安装/卸载并要求副作用可撤销；追加式会话日志有利于按真实顺序重建运行；系统提示、工具调用、上下文注入等执行痕迹可以留痕，从而把 Agent 从黑盒变成“玻璃盒”；同时其设计强调尽量维护稳定上下文前缀以提高缓存复用，并通过程序化/批量工具调用减少大量中间汇报进入模型上下文。

Workbench 不直接依赖这些实现细节作为唯一真源，但吸收其产品/架构思想。

## 100.1 Harness Glass Box

在 Developer / Admin Profile 下，可从某个 Run 打开：

```text
Harness Glass Box

Agent
architect_07

Runtime
DeepSeek Harness

Memory
Core rev 27
Recall 5 selected

Context Layers
1 Agent Definition
2 Stable Core Memory
3 Skills / Tool Manifest
4 Work State
5 Retrieved Memory
6 Current Turn

Plugins
memory-adapter       active
subagent-codex       active
archify-export       idle

Tool Execution
12 calls
3 batched groups

Cache / Context
Stable prefix        18.4k tokens
Dynamic context       4.1k tokens

[Timeline] [Context] [Plugins] [Tools] [Memory]
```

这个界面与普通用户的简洁 Agent 页面分离，只在需要调试、审计或开发时展开。

## 100.2 Plugin Lifecycle Visualization

对于支持运行时动态插件的 Runtime，Workbench 统一事件：

```text
plugin.install.requested
plugin.installed
plugin.activated
plugin.deactivated
plugin.uninstalled
plugin.rollback.completed
plugin.failed
```

并展示：

```text
插件提供哪些能力
注册了哪些 Tool / Hook / Service
产生了哪些可撤销副作用
卸载是否完整
是否需要 Runtime restart
```

具体 Runtime 不支持热卸载时 UI 按 Capability 降级，不伪装成支持。

## 100.3 Context / Cache-aware Layering

Memory 每轮必调不代表每轮破坏稳定前缀。

建议 Context Assembler 分层：

```text
STABLE PREFIX
├ System / Agent Definition
├ Stable Core Memory revision
├ Stable Tool / Skill Manifest
└ Stable policy

DYNAMIC SUFFIX
├ Current Work State
├ Retrieved Private Memory
├ Resource excerpts
├ Follow-up guidance
└ Current User Turn
```

Core Memory revision 没变化时尽量维持稳定序列；动态 Recall 放在后段。Conversation / Event 仍采用 append-oriented 结构，避免无意义改写旧前缀。

## 100.4 Context Impact Manifest

每个会向模型 Context 注入内容的内部模块 / 外部插件，建议登记：

```yaml
context_impact:
  injects: true
  stable_prefix_eligible: true|false
  estimated_tokens: 0
  cache_break_risk: low|medium|high
  insertion_zone: stable|dynamic|tool_result
  truncation_policy: summarize|drop|never
```

这使 Workbench 可以真正解释：

```text
哪个插件在吃 Token？
哪个 Memory 模块导致 Context 增长？
为什么这一轮 Cache 命中下降？
```

---

# 101. Memory Studio 的性能策略

Memory 可视化必须遵守整个 Workbench 的“极致增量”原则。

禁止：

```text
打开 Memory 页面
→ load 全部 Memory
→ load 全部 embedding
→ load 全图
→ 前端重新布局所有节点
```

采用：

```text
MemorySummaryProjection
+ Cursor Pagination
+ Namespace-first query
+ Graph neighborhood expansion
+ Viewport virtualization
+ Incremental graph patch
+ Worker-based layout
+ Background index refresh
```

Graph 初始只展示：

```text
Core
高 Importance
最近使用
当前 Work 相关
当前选中节点 1~2 hop 邻域
```

用户继续展开再加载邻居。

建议工程预算目标：

```text
Memory Overview local projection   P95 < 50ms
Memory Table first page            P95 < 100ms
Turn Receipt open                  P95 < 100ms
Graph initial projection           P95 < 200ms
Memory revision write -> UI patch  P95 < 150ms
```

以上是工程预算，后续 Benchmark 校准。

---

# 102. Decision Log — v0.18 Memory Studio & Harness Glass Box

## D-127 — Agent Memory 是一等可视化产品对象

**决定：** 每个持久 Agent 的独立 MemorySpace 必须支持 Overview / Layers / Timeline / Graph / Search / Turn Trace / Revision 等可视入口；Memory 不得只作为后台向量库能力存在。
**状态：** Accepted

## D-128 — Memory UI 是 Projection，不是第二套真源

**决定：** Canonical Agent Memory + Receipt / Event 是事实来源；Graph、Timeline、Overview 等均由 `MemoryProjectionIR` 派生，可删除重建。
**状态：** Accepted

## D-129 — Agent Owner 可以人工管理该 Agent 的长期 Memory

**决定：** 支持 Add / Revise / Supersede / Archive / Tombstone / Core Pin 等操作；编辑创建新 revision，不允许无审计覆盖。
**状态：** Accepted

## D-130 — 每条 Agent 回复都可追踪本轮 Memory 使用路径

**决定：** `MemoryTurnReceipt + Context Package` 构成 Memory Turn Trace，可解释 Recall attempted、selected、dropped、degraded 和 Post-turn Candidate；不得依赖模型自述“我为什么这么回答”。
**状态：** Accepted

## D-131 — Memory 可视化不改变 Agent Private 隔离

**决定：** 可视化、搜索和编辑都必须首先绑定 `agentId + namespaceId`；Memory Center 可以管理多个 Agent，但不能通过聚合 UI 建立跨 Agent 可写 Memory 池。
**状态：** Accepted

## D-132 — 五层记忆通过 Adapter 映射到可视层

**决定：** 当前 Workbench 可按 Canonical 类型展示，但不假定其等于 AI 集群五层记忆的正式定义；未来通过 `MemoryLayerAdapter` 映射真实五层结构。
**状态：** Accepted

## D-133 — Memory 编辑采用 Revision-first 语义

**决定：** 用户修改 Memory 产生新 Revision、重新索引并写审计；Core Memory 修改必须可 Diff、可回退，并提示其会影响未来所有 Turn。
**状态：** Accepted

## D-134 — DeepSeek Harness 的透明化思想扩展为 Harness Glass Box

**决定：** Developer / Admin 可查看 Runtime 的 Memory Gate、Context Layer、Plugin、Tool、Capability、Usage 和关键执行事件；普通用户仍保持 Adaptive Workspace 的轻量体验。
**状态：** Accepted

## D-135 — Context 采用 Cache-aware Stable Prefix / Dynamic Suffix

**决定：** Agent Definition、低频变化 Core Memory、稳定 Tool/Skill Manifest 优先保持稳定前缀；Retrieved Memory、Work State 和 Current Turn 位于动态后缀，避免 Mandatory Memory Recall 无意义破坏模型缓存复用。
**状态：** Accepted

## D-136 — 所有 Context 注入组件登记 Context Impact

**决定：** 内部模块与外部插件需要声明其 Token 影响、插入区域、Cache 风险和截断策略；Context Inspector 可以据此解释成本与缓存变化。
**状态：** Accepted


---

# 103. Agent Capability Studio — Memory 之外，Skill / Plugin / Tool 也必须可视化（Draft v0.19）

## 103.1 产品原则

既然 Workbench 希望把 Agent 从黑盒变成玻璃盒，那么透明化不能只停留在 Memory。用户还需要回答：

```text
这个 Agent 当前具备哪些能力？
这次任务到底调用了哪些 Skill？
哪些 Skill 是用户手动指定，哪些是 Agent 自动路由？
某个 Skill 总共调用过多少次？
哪些 Plugin 当前安装 / 启用 / 激活？
Plugin 实际提供了哪些 Tool / Hook / Service？
哪些能力真正参与了当前 Turn / Run？
哪个 Skill / Plugin 最耗 Token、时间和成本？
哪个能力失败最多、最常被 Retry？
切换 Runtime / Model 后，哪些能力变得不可用？
```

因此正式增加：

> **Agent Capability Studio**

它是 Memory Studio 的并列能力，而不是 Memory 的子页面。

```text
Agent Instance
├── Memory Studio
└── Capability Studio
     ├── Overview
     ├── Skills
     ├── Plugins
     ├── Tools
     ├── Runtime Capabilities
     ├── Usage
     ├── Timeline
     └── Turn / Run Trace
```

普通用户默认只看到与自己相关的简化统计；Developer / Admin 可展开详细生命周期、Context Impact、版本、Hook 和 Tool Trace。

## 103.2 “可用”与“被调用”必须严格区分

Skill / Plugin 的可视化最容易出现误导：一个 Skill 出现在 Agent 的能力清单中，不代表它真正参与了任务。

正式区分以下状态：

```text
AVAILABLE
已安装 / 当前 Agent 有资格使用

ENABLED
当前 Agent / Profile / Project 已启用

MATCHED
路由器认为与当前意图相关

SELECTED
已经进入本轮执行计划

INVOKED
真正发生一次 Skill 调用

COMPLETED
调用成功完成

FAILED
调用失败

SUPPRESSED
本来匹配，但因权限 / 成本 / Runtime 能力 / 用户策略被抑制
```

因此 UI 不能写：

```text
“本轮使用了 6 个 Skills”
```

如果其中 4 个只是挂载在 Manifest 中。

应该明确：

```text
Available  18
Matched     4
Invoked     2
Completed   2
```

Plugin 同样区分：

```text
INSTALLED
ENABLED
ACTIVATED
HOOK_FIRED
TOOL_USED
CONTEXT_INJECTED
DEACTIVATED
UNINSTALLED
FAILED
```

---

# 104. Skill Studio — 用户能精准知道自己 / 某个 Agent 调用了哪些 Skill

## 104.1 Skill 首页

用户进入自己的 Agent，可以看到：

```text
Skills                                      Architect Agent

Today
Invocations        24
Unique Skills       7
Success Rate     95.8%
Skill Cost        ¥1.82

Most Used
1. code-review             8 calls
2. architecture-analysis   6 calls
3. project-memory-recall   4 calls
4. test-planning           3 calls
5. archify-export          3 calls

Recent
20:41  code-review          ✓  18.2s
20:32  architecture-analysis ✓  11.4s
20:17  archify-export       ✓   4.8s
```

这里的 `24` 必须来自真实 `skill.invoked` 事件，而不是聊天文本搜索。

## 104.2 使用统计 Scope

用户说“我当前这个用户调用了哪些 Skills”，这里必须允许多种 Scope，但默认不能混在一起：

```text
ME
当前用户在所有自己拥有的 Agent 上触发 / 使用的 Skill

CURRENT AGENT
当前 Agent Instance 的 Skill 使用

CURRENT WORK
当前 Work Item

CURRENT CONVERSATION
当前 Conversation

CURRENT RUN
当前 Run

TIME RANGE
Today / 7d / 30d / Custom
```

典型 UI：

```text
Usage Scope
[Me ▾] [All my agents ▾] [Last 7 days ▾]
```

需要额外区分触发来源：

```text
User Explicit
用户输入 /skill 或手动点击

Agent Auto Route
Agent / Skill Router 自动选择

Workflow
Task Graph / Scheduler 规则触发

Plugin Internal
由 Plugin 内部逻辑触发

System Policy
系统强制能力，例如安全检查
```

所以某个 Skill Detail 可以显示：

```text
code-review

Invocations          128
├ User explicit       21
├ Agent auto-route    74
├ Workflow            29
└ System               4

Completed            122
Failed                 6
Average latency       9.8s
Last used             2m ago
```

## 104.3 Skill Detail

每个 Skill 应至少展示：

```text
Identity
- skillId
- name
- version
- provider / source
- owner

Compatibility
- supported Runtime
- supported Model capability
- required Tools
- required Permissions

Routing
- trigger keywords / semantic matcher
- Auto-route policy
- priority
- conflicts

Usage
- invocation count
- success / failure
- latency
- token / cost
- last used
- frequency trend

Context Impact
- injected tokens
- stable/dynamic zone
- cache break risk

Trace
- Recent invocations
- Work / Conversation / Run refs
- Agent refs
- error refs
```

如果 Skill 是用户可编辑的自定义 Skill，还应支持：

```text
View definition
Edit / Revision
Enable / Disable
Pin to Agent
Remove from Agent
Export
Clone
Test
```

但任何编辑必须产生版本 / revision，避免无法解释“为什么昨天同一个 Skill 行为不一样”。

---

# 105. SkillInvocationReceipt — Skill 调用必须和 MemoryTurnReceipt 一样可审计

每一次真正 Skill Invocation 都产生结构化 Receipt：

```ts
interface SkillInvocationReceipt {
  receiptId: string

  userId: string
  agentId: string
  skillId: string
  skillVersion: string

  workItemId?: string
  conversationId?: string
  runId?: string
  taskId?: string
  turnId?: string

  trigger:
    | 'user-explicit'
    | 'agent-auto-route'
    | 'workflow'
    | 'plugin-internal'
    | 'system-policy'

  matchedAt?: string
  invokedAt: string
  completedAt?: string

  status:
    | 'running'
    | 'completed'
    | 'failed'
    | 'cancelled'
    | 'suppressed'

  runtimeBindingId?: string
  modelId?: string

  inputRefs: string[]
  outputRefs: string[]

  contextTokens?: number
  inputTokens?: number
  outputTokens?: number
  estimatedCost?: number
  latencyMs?: number

  permissionEnvelopeId?: string
  errorRef?: string
}
```

这个 Receipt 是 Skill Studio、Usage Ledger、Run Trace 与成本统计的共同事实基础。

用户点击某次调用时，应能看到：

```text
为什么调用？
谁触发？
哪个 Agent 调用？
在哪个 Work / Run？
用了哪个版本？
给了什么输入？
生成了什么输出？
用了哪些权限？
消耗多少时间 / Token / 成本？
成功还是失败？
```

但不展示模型隐藏推理链，只展示系统真实事件和可审计输入输出。

---

# 106. Plugin Studio — 插件不仅要“装没装”，还要知道它实际干了什么

## 106.1 Plugin 首页

```text
Plugins                                      Architect Agent

Active             5
Idle               8
Disabled           3
Failed             1

Current Run
memory-adapter       ACTIVE
subagent-codex       ACTIVE
archify-export       IDLE
repo-tools           ACTIVE

Context Impact
memory-adapter      1.4k tokens
repo-tools          0.8k tokens
subagent-codex      0 tokens stable manifest
```

普通用户只需要看到：

```text
安装 / 启用 / 当前是否参与任务 / 是否异常
```

Developer / Admin 才展开 Hook / Service / rollback 等内部信息。

## 106.2 Plugin Capability Map

每个 Plugin 都应该能展开它真正提供了什么：

```text
repo-tools plugin
│
├── Tools
│   ├── repo.read
│   ├── repo.search
│   └── repo.diff
│
├── Skills
│   ├── code-review
│   └── repo-analysis
│
├── Hooks
│   ├── beforeTurn
│   └── afterTool
│
├── Services
│   └── repository-index
│
└── Context
    └── repository manifest
```

这样用户才能区分：

> `code-review` 是一个 Skill，但它来自 `repo-tools` Plugin；真正执行时又可能调用 `repo.diff` Tool。

正式关系：

```text
Plugin
  ├ provides Skill
  ├ provides Tool
  ├ provides Hook
  ├ provides Service
  └ may inject Context
```

Plugin、Skill、Tool 不能在 UI 里混成一层。

## 106.3 Plugin Usage 不能简单等于“调用次数”

Plugin 本身可能没有一个单一的 call，所以需要多维统计：

```text
Activation Count
Hook Fire Count
Provided Skill Invocation Count
Provided Tool Call Count
Context Injection Count
Failure Count
Rollback Count
Active Duration
Token Impact
Cost Attribution
```

例如：

```text
repo-tools

Activated                 38
Tool calls                912
Skill invocations         143
Hook fires              2,188
Context injections         71
Failures                    4
Rollbacks                   1
```

这样才能精确理解 Plugin 的真实参与度。

---

# 107. Capability Trace — 把 Memory / Skill / Plugin / Tool 统一到“这一轮到底发生了什么”

Conversation / Run 中任意 Agent Turn 都可以打开：

```text
TURN TRACE

Agent
Architect Agent

Memory
Core rev 27
Private recall 19 -> 5 selected

Skills
architecture-analysis   auto-route  ✓
code-review             workflow    ✓

Plugins
memory-adapter           active
repo-tools               active

Tools
repo.search              4 calls
repo.read                7 calls
repo.diff                1 call

Runtime
DeepSeek Harness

Context
18.4k stable
4.1k dynamic

Usage
Input      22.5k
Output      3.2k
Cost       ¥0.36
Duration   41.8s
```

这个页面是 Harness Glass Box 的核心统一入口。

它把用户之前分散的问题连起来：

```text
它记住了什么？
它用了什么 Skill？
它启用了什么 Plugin？
它调用了什么 Tool？
它为什么花这么多 Token？
这条回答是哪个 Runtime 完成的？
```

全部通过系统事件解释，而不是模型自己解释自己。

---

# 108. CapabilityProjectionIR — Skill / Plugin 可视化也必须只是 Projection

定义运行时中立投影：

```ts
interface CapabilityProjectionIR {
  schemaVersion: number
  scope: {
    userId?: string
    agentId?: string
    workItemId?: string
    conversationId?: string
    runId?: string
  }

  revision: number

  skills: SkillCapabilityProjection[]
  plugins: PluginCapabilityProjection[]
  tools: ToolCapabilityProjection[]

  usageSummary: CapabilityUsageSummary
  recentEvents: string[]
}
```

数据主链：

```text
Runtime / Scheduler / Skill Router / Plugin Host
                  │
                  ▼
            Workbench Event Store
                  │
                  ▼
             Usage Ledger
                  │
                  ▼
      Capability Projection Engine
         /          |           \
        ▼           ▼            ▼
 Skill Studio   Plugin Studio   Glass Box
```

禁止 Skill Studio 自己维护调用计数，禁止 Plugin Studio 自己保存另一份生命周期状态。

---

# 109. Capability Usage Ledger — 精准统计“这个用户到底调用了多少次”

为了避免每次打开页面扫描全部 Event Log，新增增量 Usage Ledger。

建议至少维护以下维度：

```text
user_id
agent_id
skill_id / plugin_id / tool_id
runtime_id
project_id
work_item_id
bucket_hour
bucket_day
```

聚合字段：

```text
matched_count
selected_count
invocation_count
success_count
failure_count
cancel_count
latency_sum
context_tokens
input_tokens
output_tokens
estimated_cost
last_used_at
```

写入策略：

```text
Event arrives
   ↓
append Event Store
   ↓
update affected counter bucket
   ↓
patch CapabilityProjection
```

不能：

```text
打开 Skill 页面
→ scan 3 months event log
→ GROUP BY skill
```

这符合 Workbench 已确定的极致增量原则。

### 109.1 用户级统计与 Agent 私有数据边界
用户默认只能查看：

```text
自己的 Agent
自己的 Skill 使用统计
自己的 Plugin / Tool 使用统计
```

团队管理员未来如果需要查看组织级“Skill 使用量”，应使用**聚合后的运营指标**，不能因此获得其他用户 Agent 的 Private Memory、完整 Context、输入内容或私有输出。

即：

```text
Usage Analytics
!= Private Agent Transcript Access
```

---

# 110. Skill / Plugin 可视化应该支持的几个关键视图

## 110.1 Overview

```text
Skills used today
Plugins active now
Tool calls today
Failures
Cost
Most used
Recently changed
```

## 110.2 Timeline

```text
20:41 Skill code-review invoked
20:41 repo-tools plugin hook fired
20:42 repo.search x4
20:42 repo.read x7
20:43 Skill code-review completed
```

高频 Tool 事件默认批量折叠，不逐条刷屏。

## 110.3 Graph

用于回答能力依赖关系：

```text
[repo-tools Plugin]
      │ provides
      ▼
[code-review Skill]
      │ uses
      ├──────────┐
      ▼          ▼
[repo.read]   [repo.diff]
      │
      ▼
[Current Run]
```

Graph 只在关系问题下展示，不应成为默认首页。

## 110.4 Usage / Frequency

可以直观看：

```text
code-review             128
architecture-analysis    94
memory-recall             81
archify-export            22
```

支持：

```text
Today / 7d / 30d
By Agent
By Project
By Work
Explicit / Auto / Workflow
Success / Failure
```

## 110.5 Context Impact

展示哪些能力影响模型上下文：

```text
Skill / Plugin        Tokens    Cache Risk
repo-tools              820     Low
memory-adapter         1410     Medium
video-analysis         6240     High
```

从而把“能力使用”直接连接到成本策略。

---

# 111. Runtime / Model 切换后 Skill 与 Plugin 要动态重新判定

和 Composer 图片 / 视频能力判断一样，Skill / Plugin 也必须通过 Effective Capability 动态计算。

例如某 Skill：

```text
video-understanding
requires:
- vision.video = native|adapted
- file.video.read = true
```

用户从支持视频的模型切换到不支持视频的模型：

```text
Skill
video-understanding

AVAILABLE -> UNSUPPORTED
```

UI 变灰并解释：

```text
当前 Runtime / Model 不满足：video input

[切换兼容模型]
[使用适配模式]
```

Plugin 如果只提供文本 Tool，可以继续保持 Enabled；不能因为其中一个 Skill 不兼容就把整个 Plugin 粗暴禁用。

所以 Capability Resolution 必须做到：

```text
Plugin Capability
→ Skill Capability
→ Tool Capability
→ Runtime / Model Capability
→ Access Envelope
→ Effective Capability
```

---

# 112. Agent Studio 的长期统一形态

到 v0.19 为止，一个 Agent 的“内部世界”已经可以组织为：

```text
AGENT STUDIO

Overview
│
├── Memory
│   ├ Overview
│   ├ Timeline
│   ├ Graph
│   └ Turn Trace
│
├── Capabilities
│   ├ Skills
│   ├ Plugins
│   ├ Tools
│   └ Runtime Capabilities
│
├── Usage
│   ├ Calls
│   ├ Tokens
│   ├ Cost
│   ├ Latency
│   └ Failures
│
├── Activity
│   ├ Runs
│   ├ Tasks
│   └ Handoffs
│
└── Developer
    └ Harness Glass Box
```

用户因此不仅知道：

```text
这个 Agent 记得什么
```

还知道：

```text
它会什么
它正在用什么
它以前最常用什么
哪些能力是自动选择的
哪些插件真正参与了运行
哪些能力最贵 / 最慢 / 最容易失败
```

这才构成真正意义上的长期 Agent 可观测性。

---

# 113. Decision Log — v0.19 Capability Studio & Skill / Plugin Observability

## D-137 — Skill / Plugin / Tool 是一等可视化能力对象

**决定：** Memory 之外，Agent 的 Skill、Plugin、Tool 与 Runtime Capability 必须支持可视、可检索、可统计和可追溯；用户能明确看到当前 Agent 有什么能力以及哪些能力真正参与了任务。
**状态：** Accepted

## D-138 — Available / Enabled / Invoked 必须分层

**决定：** Skill / Plugin 不得因“已安装 / 已启用”就被计入“已使用”；真实使用统计以结构化 Invocation / Activation / Hook / Tool Event 为准。
**状态：** Accepted

## D-139 — 每次真实 Skill 调用生成 SkillInvocationReceipt

**决定：** Skill 使用必须记录 user / agent / work / run / task / turn、触发来源、版本、Runtime、权限、Token、Cost、Latency、输入输出 Ref 与结果状态，作为可审计事实。
**状态：** Accepted

## D-140 — 用户级 Skill Usage 由增量 Usage Ledger 统计

**决定：** Workbench 支持按当前用户、Agent、Work、Conversation、Run 和时间范围查看 Skill 使用次数、成功率、成本与最近使用；统计通过 Event Store 增量聚合，禁止 UI 临时扫描全部历史。
**状态：** Accepted

## D-141 — Plugin Usage 使用多维参与指标

**决定：** Plugin 不简单使用一个“调用次数”字段；至少区分 Activation、Hook Fire、Provided Skill Invocation、Provided Tool Call、Context Injection、Failure、Rollback 与 Active Duration。
**状态：** Accepted

## D-142 — Skill / Plugin / Tool 关系通过 Capability Map 可视化

**决定：** Plugin 可提供 Skill / Tool / Hook / Service / Context；Skill 可依赖 Tool / Runtime Capability。Capability Graph 是投影，不成为能力配置第二真源。
**状态：** Accepted

## D-143 — Turn Trace 统一 Memory / Skill / Plugin / Tool / Runtime / Usage

**决定：** 单个 Agent Turn / Run 可以展开统一 Capability Trace，以系统事件解释本轮 Memory、Skill、Plugin、Tool、Runtime、Context 与 Usage；不得通过模型自述替代系统 Trace。
**状态：** Accepted

## D-144 — Capability Studio 采用 Projection + Usage Ledger

**决定：** Skill / Plugin Studio 不自行维护统计真源；Workbench Event Store 保存事实，Usage Ledger 保存增量聚合，CapabilityProjectionIR 负责 UI 投影。
**状态：** Accepted

## D-145 — Agent 私有数据与运营聚合统计分离

**决定：** 用户默认查看自己的 Agent 能力使用；未来组织级统计只能提供授权后的聚合指标，不因 Skill / Plugin Analytics 暴露其他用户 Agent 的 Private Memory、完整 Context、Conversation 或私有 Artifact。
**状态：** Accepted

## D-146 — Runtime / Model 切换触发 Skill / Plugin Effective Capability 重算

**决定：** Skill、Plugin、Tool 可用性必须由 Runtime / Model 能力、依赖 Tool、Access Envelope 和适配能力共同动态计算；不满足条件时 UI 禁用并说明原因，不允许静默失败。
**状态：** Accepted


# 114. Composer Skill Palette — 用户必须能直接发现、理解并显式调用 Skill（Draft v0.20）

Skill 不应只存在于后台 Router。用户在 Agent Composer 中必须可以直接调用 Skill，同时在真正调用前看懂它是干什么的、需要什么、是否兼容当前 Runtime / Model、可能产生什么成本与权限影响。

核心交互语义继续采用：

```text
@  = Agent / Expert / Person
/  = Skill / Action
+  = File / Image / Video / Workspace / Workbench Resource
```

因此用户输入 `/` 时打开 **Skill Palette**：

```text
┌──────────────────────────────────────────────────────────────┐
│ /                                                            │
├──────────────────────────────────────────────────────────────┤
│ Recommended                                                   │
│                                                               │
│ /code-review                                                  │
│ 检查当前代码修改，识别缺陷、风险与可维护性问题。              │
│ Codex ✓  DeepSeek ✓      Last used 18m ago                  │
│                                                               │
│ /architecture-analysis                                        │
│ 分析系统边界、依赖、数据真源和架构风险。                      │
│ DeepSeek ✓  Codex adapted                                    │
│                                                               │
│ /test                                                         │
│ 根据当前 Workspace / Diff 运行或规划测试。                    │
│ Codex ✓                                                      │
├──────────────────────────────────────────────────────────────┤
│ [查看全部 Skills]                                             │
└──────────────────────────────────────────────────────────────┘
```

每个候选项至少显示：

```text
name
一句话用途
provider / plugin
兼容状态
必要 Runtime / Model 能力
最近使用 / Pin 状态（可选）
```

默认列表不得直接塞入长文档；详细说明只在用户展开 Preview / Detail 时加载。

---

# 115. Skill Preview — 输入处必须能快速理解 Skill，而不必离开当前 Conversation

用户在 Skill Palette 中选中或悬停 / 聚焦 Skill 时，Composer 应出现轻量 Preview：

```text
/code-review

用途
检查当前代码、Diff 或指定文件，输出问题、风险、建议和必要时的修复任务。

适合
• PR / Diff Review
• 重构后的质量检查
• 提交前检查

需要
repo.read
repo.diff

当前状态
✓ Codex
✓ DeepSeek

Estimated context
~820 tokens

[使用] [详细说明]
```

Skill Preview 的目标是回答五件事：

```text
它是干什么的？
什么时候适合用？
会读取 / 调用什么？
当前模型能不能用？
我现在是否真的要调用它？
```

如果当前模型 / Runtime 不支持：

```text
/video-understanding
视频内容理解与时间轴摘要

○ 当前模型不支持视频输入

[切换兼容模型]
[查看适配方案]
```

不得允许用户点下去后才在 Runtime 阶段静默失败。

---

# 116. Skill Detail — Skill 必须拥有完整、可阅读、可审计的说明页

从 Composer、Capability Studio、Skill Invocation Trace、Plugin Detail 均可以进入同一个 Skill Detail。

建议字段：

```text
Identity
- Skill ID
- Name
- Version
- Provider / Plugin
- Author / Source

Purpose
- 一句话摘要
- 完整说明
- 适用场景
- 不适用场景

Inputs
- 支持的资源类型
- required / optional arguments
- current context requirements

Capabilities
- required Runtime capabilities
- required Model modalities
- required Tools
- required Permissions

Execution
- supported Runtime
- native / adapted / unsupported
- estimated context impact
- cache-break risk
- expected latency / cost class

Routing
- auto routing enabled
- trigger phrases / semantic intents
- priority
- conflicts / alternatives

Usage
- invocation count
- success / failure
- avg latency
- cost
- last used

Revision
- definition version
- change history
- sourceRefs
```

Skill Detail 中必须明确区分：

```text
Definition
= Skill 是什么

Invocation
= 某一次真的用了它

Usage Analytics
= 历史聚合
```

三者不能混成同一数据对象。

---

# 117. 显式 Skill 调用与自动 Skill 路由必须共存

系统支持至少四种 Skill 触发来源：

```text
USER_EXPLICIT
用户通过 /skill 或 Skill Palette 明确选择

AGENT_ROUTE
Agent / Skill Router 自动选择

WORKFLOW
Task / Workflow 节点固定要求

SYSTEM_POLICY
系统策略要求，例如高风险代码必须执行 security-review
```

显式调用必须具有最高的意图权重，但仍不能突破权限、模型能力或安全策略。

例如用户输入：

```text
/code-review 检查这次 Runtime Adapter 的修改
```

最终请求应保存为结构化 Skill Intent：

```ts
interface SkillIntent {
  skillId: string
  version?: string
  source: 'user_explicit' | 'agent_route' | 'workflow' | 'system_policy'
  args?: Record<string, unknown>
  resourceRefs?: string[]
  required?: boolean
}
```

如果显式 Skill 当前无法执行，系统必须告诉用户为什么，而不能偷偷换成另一个 Skill。

---

# 118. Skill Router — 自动路由必须是可控、可解释的能力选择器

自动 Skill 路由采用“候选发现 → 硬过滤 → 评分 → 选择”的结构，不允许模型在无约束条件下凭自然语言随意加载任意 Skill。

```text
User Intent / Task
        ↓
Candidate Discovery
        ↓
Compatibility Filter
        ↓
Permission Filter
        ↓
Context / Resource Filter
        ↓
Cost / Budget Filter
        ↓
History / Agent Preference
        ↓
Skill Score
        ↓
Selected / Suggested / Rejected
```

硬过滤项优先于评分：

```text
Runtime / Model capability
Input modality
Required Tool availability
Access Envelope
Workspace connection
Plugin enabled state
Skill version compatibility
Safety / Team policy
```

只有通过硬过滤的 Skill 才进入 Ranking。

---

# 119. Skill Router Scoring — 先用确定性特征，模型只做有限补充

V0.20 建议评分来源：

```text
Intent Match
Current Resource Match
Work Profile Affinity
Agent Preference
Pinned Skill
Past Success
Recent Failure Penalty
Cost Penalty
Latency Penalty
Context Impact Penalty
Runtime Native Bonus
Workflow Requirement
```

示例：

```text
code-review            0.91 SELECTED
repo-analysis          0.74 SUGGESTED
security-audit         0.31 NOT SELECTED
```

展开解释：

```text
code-review
Intent Match           +0.42
Current Diff           +0.18
Agent Preference       +0.12
Past Success           +0.11
Low Context Cost       +0.08

security-audit
Intent Match           +0.21
No security-sensitive change
                       -0.18
Higher Cost            -0.07
```

评分公式不必永久固定，但所有决定必须能还原为 **Router Receipt**，避免 UI 只能显示模型口头解释。

---

# 120. SkillRouterReceipt — “为什么用了这个 Skill”必须可审计

建议：

```ts
interface SkillRouterReceipt {
  receiptId: string
  userId: string
  agentId: string
  turnId?: string
  runId?: string

  queryIntent: string
  candidateSkillIds: string[]

  filtered: Array<{
    skillId: string
    reason: string
  }>

  scored: Array<{
    skillId: string
    score: number
    factors: Record<string, number>
  }>

  selectedSkillIds: string[]
  triggerSource: 'user_explicit' | 'agent_route' | 'workflow' | 'system_policy'
  createdAt: string
}
```

用户在 Turn Trace 中点击：

```text
为什么用了 code-review？
```

Workbench 读取 Router Receipt，而不是再次询问模型编一个理由。

---

# 121. Composer 中的 Skill 状态必须随着 Runtime / Model / Context 动态变化

例如用户先选择：

```text
Runtime = Codex
Model supports image = true
```

Skill Palette 中：

```text
/ui-review       ✓
/video-review    ○ adapted
```

随后用户切换到不支持图像的模型：

```text
/ui-review       ○ unsupported
/video-review    ○ unsupported
```

如果 `/ui-review` 已经被添加到 Composer，则必须：

```text
/ui-review  ⚠ 当前执行路径不兼容

[切换兼容 Runtime / Model]
[移除 Skill]
[查看原因]
```

不得无提示删除用户已经选择的 Skill。

Effective Skill Capability 由：

```text
Skill Definition
+ Plugin State
+ Runtime Capability
+ Model Capability
+ Required Tool
+ Input Resource
+ Access Envelope
+ Workspace State
+ Cost Policy
= Effective Skill State
```

统一计算。

---

# 122. Skill 与 Plugin 的关系必须在 Composer 中可见，但不能增加认知负担

用户主要选择的是 Skill，不应该要求普通用户先理解 Plugin。

因此 Composer 默认：

```text
/code-review
检查当前代码修改
```

详细信息中才显示：

```text
Provided by
repo-tools plugin 2.4.1
```

如果 Plugin 被禁用 / 崩溃：

```text
/code-review
○ unavailable
Provider repo-tools is disabled

[查看 Plugin]
```

这样 Skill 是用户层能力，Plugin 是实现 / 扩展层。

---

# 123. Skill 推荐必须克制，避免 Composer 变成广告栏

Skill 推荐遵循：

```text
最多 3~5 个高相关候选
先显示 Pinned / Explicitly Relevant
不因“已安装”就推荐
不为了提高 Skill 使用率主动打扰用户
高成本 Skill 不自动突出
连续失败 Skill 自动降权并提示
```

用户可以对某 Agent 设置：

```text
Always prefer this Skill
Prefer for this Work
Do not auto-route this Skill
Never use this Skill
```

这些偏好写入该 Agent 的能力策略 / Preference，而不是直接改 Skill Definition。

---

# 124. 多 Skill 调用：允许组合，但必须限制无意义的 Skill Chain

复杂任务可能需要：

```text
/repo-analysis
      ↓
/architecture-analysis
      ↓
/code-review
```

但默认禁止 Skill 自己无限递归调用 Skill。

建议：

```text
Skill can propose next Skill
Scheduler / Skill Router authorizes
```

并受到：

```text
maxSkillDepth
maxSkillInvocations
budget
context budget
runtime compatibility
cycle detection
```

限制。

可视化时应该显示：

```text
repo-analysis ✓
      │
      ▼
architecture-analysis ✓
      │
      ▼
code-review ●
```

而不是只在最终回答中说“使用了多个 Skill”。

---

# 125. Skill Invocation 与用户输入的视觉表达

当用户显式调用 Skill，Composer 中应该保留结构化 Chip：

```text
[/code-review ×]
[/test ×]

检查 Runtime Adapter 的修改
```

发送后 Conversation 中可以简化显示：

```text
You
/code-review · /test
检查 Runtime Adapter 的修改
```

运行中：

```text
Skills
code-review     ● RUNNING
/test           ○ QUEUED
```

完成后：

```text
Skills used 2
code-review     ✓ 18.2s
/test           ✓ 31.4s
```

所有真实调用仍由 `SkillInvocationReceipt` 计数。

---

# 126. Skill Search / Discovery 性能要求

Skill Palette 不能每次打开都遍历所有 Plugin / Skill Manifest。

维护：

```text
SkillRegistryIndex
SkillCompatibilityProjection
SkillUsageLedger
AgentSkillPreferenceIndex
```

输入 `/co` 时：

```text
prefix / FTS lookup
→ capability bitmap filter
→ agent preference boost
→ top N
```

目标工程预算：

```text
Palette 首批候选       P95 < 50 ms
输入过滤更新           P95 < 30 ms
Effective capability   增量更新，不全量扫描
Router hard filter     O(candidate set)
```

Skill 详情与长说明懒加载，不阻塞 Palette 首屏。

---

# 127. Agent Studio 中新增 Router / Skill 观察面板

Capability Studio 在 v0.20 增加：

```text
Skills
├── Available
├── Used
├── Pinned
├── Disabled
└── Failed

Router
├── Recent Selections
├── Candidate Scores
├── Rejected Reasons
└── Agent Preferences
```

某 Agent 的详情中可以看到：

```text
Architect Agent

Top Skills · 30d
architecture-analysis      94
code-review                63
repo-analysis              41

Auto-routed                71%
User explicit              22%
Workflow                     7%

Most rejected
security-audit
Reason: low intent match / incompatible context
```

这样用户不仅知道“用了多少次”，还能理解 Agent 的能力选择习惯。

---

# 128. Decision Log — v0.20 Composer Skill Palette & Explainable Skill Router

## D-147 — Composer 通过 `/` 提供 Skill Palette

**决定：** 用户可以在 Agent Composer 直接搜索、预览和显式调用 Skill；候选项必须提供一句话用途与当前兼容状态，长说明按需加载。
**状态：** Accepted

## D-148 — Skill 必须同时具备 Preview 与完整 Detail

**决定：** Skill Preview 服务于输入时快速决策；Skill Detail 提供完整用途、输入、依赖、权限、Runtime/Model 兼容、成本 / Context 影响、Routing、Usage 与 Revision 信息。
**状态：** Accepted

## D-149 — 显式 Skill Intent 与自动 Skill Route 共存

**决定：** Skill 调用来源至少区分 USER_EXPLICIT / AGENT_ROUTE / WORKFLOW / SYSTEM_POLICY；用户显式指定具有高意图权重，但不能绕过硬能力、权限和安全约束。
**状态：** Accepted

## D-150 — Skill Router 采用 Candidate → Hard Filter → Score → Select

**决定：** 自动 Skill 路由先做 Runtime / Model / Tool / Permission / Workspace / Policy 等确定性硬过滤，再对通过候选进行意图、历史效果、偏好、成本、延迟与 Context 影响评分。
**状态：** Accepted

## D-151 — Skill Router 必须生成可解释 Receipt

**决定：** 自动或策略路由产生 `SkillRouterReceipt`，记录候选、过滤原因、评分因子与最终选择；“为什么用了 / 没用某 Skill”由系统 Receipt 回答，不由模型事后编造。
**状态：** Accepted

## D-152 — Skill Effective Capability 随 Runtime / Model / Context 动态重算

**决定：** 用户切换 Runtime / Model、资源、Workspace、权限或成本策略后，Composer 和 Capability Studio 必须增量重算 Skill 可用性；已选但变得不兼容的 Skill 必须显式提示，不得静默移除或忽略。
**状态：** Accepted

## D-153 — Skill 是用户层能力，Plugin 是实现层

**决定：** Composer 主要展示 Skill 语义，Plugin Provider 放在二级详情；Plugin 故障可以使其提供的 Skill 不可用，但 UI 不要求普通用户先理解 Plugin 才能使用 Skill。
**状态：** Accepted

## D-154 — Skill 推荐必须受相关性、失败率和成本约束

**决定：** Composer 只推荐少量高相关 Skill；不得因为安装存在就主动推荐；连续失败、高成本或不匹配 Skill 自动降权，用户可对某 Agent / Work 设置偏好或禁止自动路由。
**状态：** Accepted

## D-155 — 多 Skill 组合受 Scheduler 与循环限制

**决定：** Skill 可以提出后续 Skill，但真正的 Skill Chain 由 Scheduler / Skill Router 授权，并受到深度、调用次数、成本、Context Budget、Runtime 兼容和 Cycle Detection 限制。
**状态：** Accepted

## D-156 — Skill Palette 使用索引与增量 Capability Projection

**决定：** Composer Skill 搜索不得实时遍历全部 Plugin / Manifest；使用 Skill Registry Index、Compatibility Projection、Usage Ledger 与 Agent Preference Index 增量生成候选。
**状态：** Accepted


---

# 129. Plugin Host / Plugin Lifecycle — 工作台必须能在不中断长任务的情况下安全扩展能力（Draft v0.21）

## 129.1 核心判断

Workbench 需要吸收 DeepSeek Harness / Cordis 的“运行时可组合”思想，但**不能把 Workbench 的插件系统等同于 DeepSeek Harness 的 Cordis 插件系统**。

正式分层：

```text
Workbench Extension Host
= 产品层扩展控制面

DeepSeek Cordis Plugin
= DeepSeek Runtime-native extension

Codex-native extension surface
= Codex RuntimeAdapter 能力范围内的原生扩展面

Skill / Tool / UI Extension
= 用户真正感知到的能力
```

因此：

```text
                    Workbench Extension Host
                              │
             ┌────────────────┼────────────────┐
             ▼                ▼                ▼
        Workbench-native   DeepSeek Adapter   Codex Adapter
          Extension          │                │
                             ▼                ▼
                        Cordis Plugin      Runtime-native
                                          capability surface
```

**Workbench 统一管理“安装、授权、版本、生命周期、可视化、审计与回滚”；各 Runtime Adapter 负责把 Runtime-native 插件语义翻译成 Workbench Extension Event。**

---

# 130. Extension 类型必须分开，禁止所有东西都叫 Plugin

正式定义五类扩展对象：

```text
1. Workbench Extension
   扩展工作台本身：数据 Provider、UI、后台 Service、资源浏览器、同步、监控等。

2. Runtime Extension
   扩展某个 Harness / Runtime，例如 DeepSeek Cordis Plugin。

3. Capability Package
   提供 Skill / Tool / Expert / Parser / Renderer 等用户层能力。
4. UI Extension
   向 Agent Studio、Inspector、Workspace 等注册受控 Slot / Panel / Viewer。

5. Ephemeral Dynamic Extension
   只为当前 Session / Run 临时存在的动态能力，结束后默认销毁。
```

一个安装包可以声明多个 Extension Unit，但每个 Unit 必须有独立：

```text
extension_id
provider
scope
lifecycle
permissions
capabilities
context_impact
resource_effects
runtime_compatibility
version
```

Skill 是“用户能力”，Plugin / Extension 是“实现和装配机制”，两者不得混为一谈。

---

# 131. Workbench Extension Lifecycle 状态机

Workbench 自己维护统一状态机：

```text
DISCOVERED
   ↓
INSTALLED
   ↓
RESOLVING
   ↓
ACTIVATING
   ↓
ACTIVE
   ↓
QUIESCING
   ↓
DEACTIVATING
   ↓
INACTIVE
   ↓
UNINSTALLED
```

异常状态：

```text
FAILED
ROLLBACK_PENDING
QUARANTINED
DEGRADED
UPDATE_PENDING
RESTART_REQUIRED
```

其中 `ACTIVE` 只表示“扩展已成功激活”，不等于其提供的所有 Skill / Tool 当前都可用；真正可用性仍由 Effective Capability 计算。

---

# 132. Effect Ledger — 插件每产生一个副作用，都必须登记“怎么撤销”

Workbench 借鉴 Cordis effect/dispose 的设计原则：插件不能只注册资源，还必须让 Host 知道资源归谁、怎样撤销。

统一定义：

```ts
interface ExtensionEffect {
  effectId: string
  extensionInstanceId: string

  type:
    | 'tool-registration'
    | 'skill-registration'
    | 'event-subscription'
    | 'timer'
    | 'file-watcher'
    | 'process'
    | 'socket'
    | 'port'
    | 'rpc-endpoint'
    | 'ui-slot'
    | 'background-job'
    | 'temp-resource'
    | 'workspace-lock'
    | 'context-injector'
    | 'service-registration'

  acquiredAt: string
  releaseMode: 'automatic' | 'provider-disposer' | 'external-transaction'
  state: 'active' | 'releasing' | 'released' | 'leaked' | 'failed'
}
```

核心要求：

```text
Activate Extension
      ↓
所有 Effect 写入 Effect Ledger
      ↓
Disable / Update / Crash / Dependency Loss
      ↓
按依赖关系进入 Quiesce
      ↓
执行 Disposer / Rollback
      ↓
验证资源已释放
```

对于 Workbench Host 自己可控的注册行为，必须自动撤销；对于网络连接、外部进程、文件 Watcher、临时文件等外部资源，Extension 必须提供 disposer / rollback contract。

禁止出现：

```text
插件 UI 消失了
但后台 timer / process / listener / port 还活着
```

---

# 133. Activation Transaction — 安装成功不等于激活成功

每次激活必须形成 `ExtensionActivationTransaction`：

```text
Resolve Dependencies
      ↓
Validate Manifest
      ↓
Validate Permissions
      ↓
Check Runtime / Model Compatibility
      ↓
Reserve Resources
      ↓
Activate
      ↓
Health Check
      ↓
Commit ACTIVE
```

任一步失败：

```text
ROLLBACK
↓
释放已登记 Effect
↓
恢复 Last-Good Extension State
```

插件更新也不能直接覆盖旧版本：

```text
v2.4 ACTIVE
    ↓
Stage v2.5
    ↓
Validate
    ↓
Activate / Health Check
    ↓
成功 → Drain v2.4 → Switch
失败 → 保持 v2.4 ACTIVE
```

这是 Extension 层的 Last-Good 原则。

---

# 134. Hot Replace 不是所有插件都能“无脑热更新”

每个 Extension Manifest 必须声明：

```text
hotReloadSupport:
  LIVE
  SAFE_CHECKPOINT
  RESTART_REQUIRED
```

语义：

```text
LIVE
= 可在不中断当前任务的情况下热替换。

SAFE_CHECKPOINT
= 当前 Task / Tool Call 到达安全点以后再切换。

RESTART_REQUIRED
= 无法保证状态一致性，必须重启指定 Worker / Runtime；不能假装支持热更新。
```

因此长期 Agent 正在执行时，Workbench 默认：

```text
新版本到达
→ 不立即杀 Worker
→ 标记 UPDATE_PENDING
→ 等 Safe Checkpoint
→ Drain Old Instance
→ Switch New Instance
```

如果扩展提供的是 Context Injector、Memory Lifecycle Hook、权限中间件等关键路径能力，默认至少要求 `SAFE_CHECKPOINT`，不得在同一个模型 Turn 中途替换。

---

# 135. Ephemeral Dynamic Extension 与 Persistent Extension 必须分开

借鉴 DeepSeek Harness 当前 Dynamic Cordis Package 的思路，Workbench 定义两类非常不同的动态扩展：

```text
EPHEMERAL
- Run / Conversation / Session 级
- 默认只存在内存或临时目录
- 不自动写入长期配置
- 重启后默认不存在
- 权限最小化
- 适合 Agent 临时生成“小工具”

PERSISTENT
- Agent / User / Project / Workbench 级
- 有正式 Manifest / Version / Signature / Audit
- 可重启恢复
- 必须经过安装 / 更新策略
```

Ephemeral Extension 如果被验证有长期价值，可以：

```text
Promote
→ 生成正式 Extension Package
→ 安全审查
→ 用户确认
→ 安装为 Persistent
```

禁止“临时动态代码因为很好用就悄悄永久驻留”。

---

# 136. AI 能不能给自己安装 Plugin？——允许提出和临时扩展，不允许静默永久扩权

正式采用三级自治：

```text
LEVEL 0 — MANUAL
AI 只能推荐 Plugin / Skill，用户自己安装。

LEVEL 1 — ASK BEFORE EXTEND
AI 可以生成 / 选择 Extension Proposal；安装、启用、权限提升前询问用户。

LEVEL 2 — AUTONOMOUS WITHIN LIMITS
AI 可以在预授权 Capability / Scope / Budget 内创建 Ephemeral Extension；
持久安装、扩大 Workspace 写权限、网络能力、Credential、系统级权限仍必须 Approval。
```

AI 可以做：

```text
发现缺少能力
→ extension.propose
→ 说明为什么需要
→ 需要哪些权限
→ 预计 Context / Cost / Risk
→ 是否只需临时使用
```

AI 默认不能做：

```text
silent persistent install
silent plugin upgrade
silent permission escalation
silent credential access
silent startup registration
silent system-service install
```

---

# 137. Extension Proposal 必须可解释

例如 Codex / DeepSeek 判断需要一个临时 AST 分析器：

```text
需要额外能力

Extension
AST Inspector

Purpose
分析当前 TypeScript AST，以定位 Runtime Adapter 的注册路径。

Scope
Current Run only

Permissions
workspace:read
process:spawn (restricted)

Network
None

Estimated Context Impact
Low

Estimated Runtime Cost
Low

Lifecycle
Ephemeral · auto-remove after run

[允许本次]
[查看代码 / Manifest]
[拒绝]
```

这条 Proposal、用户决定和最终 Activation Receipt 都必须进入 Event Store。

---

# 138. DeepSeek Harness / Cordis 的接入方式

DeepSeek Harness 官方 Cordis 当前已经具备非常适合我们借鉴和利用的能力：Plugin Fiber 生命周期、依赖驱动加载、`dispose()` 后自动撤销注册与子插件、`ctx.effect()` 管理外部资源，以及依赖消失时自动卸载 / 依赖恢复时重新加载。

Workbench 不复制 Cordis 内部 Fiber，而通过 `DeepSeekRuntimeAdapter` 映射：

```text
Cordis Fiber State
        ↓
DeepSeek Extension Adapter
        ↓
WorkbenchExtensionEvent
```

例如：

```text
PENDING       → extension.waiting_dependency
LOADING       → extension.activating
ACTIVE        → extension.active
UNLOADING     → extension.deactivating
DISPOSED      → extension.inactive
FAILED        → extension.failed
```

DeepSeek Harness 当前 Dynamic Cordis Package 也适合映射到 Workbench `EPHEMERAL` 类型：它可以 define / run / stop / undefine，且当前实现主要存在于 DSH 进程内存中，不等同于正式持久插件。Workbench 应利用这一事实，而不是把它错误展示成“已经永久安装”。

---

# 139. Codex 侧不能假装拥有与 Cordis 完全相同的插件生命周期

Workbench 的 Extension Contract **不能要求所有 Runtime 对称实现 Cordis 的全部语义**。

原则：

```text
Core Extension Contract
+ Runtime-native Capability Extension
```

Codex RuntimeAdapter 必须通过 `getCapabilities()` 声明它当前实际支持的扩展面，例如：

```text
runtimeExtension.hotLoad
runtimeExtension.hotUnload
runtimeExtension.ephemeral
runtimeExtension.persistent
runtimeExtension.toolRegistration
runtimeExtension.skillRegistration
runtimeExtension.mcp
runtimeExtension.safeCheckpoint
```

UI 根据 Effective Capability 决定：

```text
支持 → 正常显示
可适配 → Adapted
不支持 → Disabled + 原因
```

禁止为了“统一 UI”而伪造 Runtime 并不具备的热加载能力。

---

# 140. Plugin Lifecycle 必须可视化

Capability Studio / Agent Glass Box 增加 `Extensions`：

```text
Extensions
├── Active
├── Waiting
├── Ephemeral
├── Updates
├── Failed
└── Quarantined
```

某个插件卡片：

```text
repo-tools 2.4.1
ACTIVE

Scope
Agent · Architect Agent

Provides
2 Skills
4 Tools
1 Service

Effects
12 active

Context Impact
~1.2k stable
~0.4k dynamic

Usage · 7d
Skill calls       143
Tool calls        912
Failures            4

[Details] [Disable]
```

点击 Details 可查看真实生命周期：

```text
20:41:02 INSTALLED
20:41:03 RESOLVING
20:41:03 ACTIVATING
20:41:04 ACTIVE
20:54:11 dependency lost: repo-index
20:54:11 QUIESCING
20:54:12 INACTIVE
20:54:18 dependency restored
20:54:18 ACTIVATING
20:54:19 ACTIVE
```

并查看 Effect Ledger：

```text
Tool registration       4
Event subscriptions     3
File watchers           1
Background jobs         2
UI slots                1
Context injectors       1
```

这让用户能回答：

> “这个插件现在到底还活着吗？”

> “关掉以后资源有没有真正释放？”

> “它为什么刚才自动重载？”

---

# 141. Plugin 权限必须能力化，不能只做“安装/不安装”二元选择

Extension Manifest 只能**请求** Capability：

```text
workspace:read
workspace:write
network:outbound
process:spawn
runtime:extend
ui:register
context:inject
memory:lifecycle-hook
credential:use:<provider>
```

最终：

```text
Requested Capability
      ∩
User / Role Policy
      ∩
Agent Policy
      ∩
Project Policy
      ∩
Current Access Envelope
      ↓
Effective Extension Capability
```

插件升级如果新增 Capability：

```text
Old Version
workspace:read

New Version
workspace:read
network:outbound
```

必须重新 Approval，不得继承旧授权静默扩大权限。

---

# 142. Quarantine — 插件不能因为“失败”就无限自动重启

触发隔离的条件可包括：

```text
连续 Activation Failure
Dispose Leak
Crash Loop
异常高 CPU / Memory
异常 Context 注入
反复 Permission Denied
Contract Violation
Signature / Integrity Error
```

进入：

```text
QUARANTINED
```

以后默认：

```text
不再自动激活
不参与 Skill Router
不注入 Context
不提供 Tool
保留日志 / Manifest / Receipt
```

用户或管理员可以：

```text
查看原因
回滚版本
修复配置
重新授权
重新启用
卸载
```

---

# 143. Plugin Host 性能策略

Extension Host 不能成为每轮 Agent Turn 的重型扫描器。

维护增量投影：

```text
ExtensionRegistryIndex
ExtensionDependencyGraph
ExtensionCapabilityProjection
ExtensionEffectLedger
ExtensionUsageLedger
ExtensionHealthProjection
```

Agent Turn 只读取已经计算好的：

```text
Effective Capability Snapshot
+ Context Impact Snapshot
```

不在每条消息发送时：

```text
重新遍历全部插件
重新加载 Manifest
重新计算依赖图
重新扫描所有 Effect
```

高频事件如 Plugin Tool Calls 先进入 Usage Ledger 聚合，不直接触发整个 Capability Studio 重绘。

---

# 144. 第一阶段实现边界

MVP 不需要做“AI 可以任意写一个完整生产 Plugin 并永久安装”。

第一阶段只验证：

```text
1. Workbench Extension Registry
2. Extension Manifest
3. Lifecycle State Machine
4. Effect Ledger
5. Activate / Disable / Uninstall
6. Safe Checkpoint Update
7. DeepSeek Cordis Adapter
8. Ephemeral Extension
9. Activation / Disposal Receipt
10. Capability Studio Lifecycle View
```

AI 自主扩展先只开放：

```text
Proposal
+
Ephemeral Current-Run Extension
+
显式用户 Approval
```

持久自修改放在后续版本。

---

# 145. Decision Log — v0.21 Plugin Host / Lifecycle & Safe Self-Extension

## D-157 — Workbench Extension Host 与 Runtime-native Plugin System 分层

**决定：** Workbench 拥有统一 Extension 控制面，但 DeepSeek Cordis / Codex 原生扩展语义继续由各 RuntimeAdapter 管理；Workbench 不重新实现 Cordis，也不要求所有 Runtime 完全对称。
**状态：** Accepted

## D-158 — Extension 副作用必须进入 Effect Ledger

**决定：** Extension 产生的 Tool、Listener、Timer、Process、Watcher、UI Slot、Context Injector 等运行资源必须有明确 owner 和 release/rollback 语义，禁用 / 更新后可验证是否清理完成。
**状态：** Accepted

## D-159 — Extension 激活与更新采用 Transaction + Last-Good

**决定：** Extension 激活 / 更新必须先验证依赖、权限、兼容性和资源，再 Commit ACTIVE；失败自动回滚并继续保留最后健康版本。
**状态：** Accepted

## D-160 — Hot Reload 能力由 Manifest 显式声明

**决定：** `LIVE / SAFE_CHECKPOINT / RESTART_REQUIRED` 三态表示 Extension 的热替换能力；系统不得把 Restart-required 插件伪装成真正热更新。
**状态：** Accepted

## D-161 — Ephemeral 与 Persistent Extension 分离

**决定：** Agent 临时生成 / 挂载的能力默认 Ephemeral，不自动进入长期配置；只有经过 Promote + Review + Approval 才成为 Persistent Extension。
**状态：** Accepted

## D-162 — AI 可以提出自扩展，但不能静默永久扩权

**决定：** AI 可 discover / propose / 在预授权限制内创建 Ephemeral Extension；持久安装、更新、Credential、系统服务与权限提升必须按策略 Approval。
**状态：** Accepted

## D-163 — Runtime Extension 以 Effective Capability 驱动 UI

**决定：** UI 不使用 `if runtime == deepseek/codex` 决定 Plugin 功能；由 RuntimeAdapter 声明 hot-load、ephemeral、tool registration 等 Capability，缺失能力显式降级。
**状态：** Accepted

## D-164 — Plugin Lifecycle 必须可视化

**决定：** Capability Studio / Glass Box 展示 Extension 状态、依赖、Effects、Context 影响、Usage、失败、重载、Rollback 与 Quarantine 历史。
**状态：** Accepted

## D-165 — Extension 升级增加权限时必须重新授权

**决定：** 权限基于 Capability 差异授权；新版增加 network / write / credential 等能力不能沿用旧授权静默升级。
**状态：** Accepted

## D-166 — Crash Loop / Resource Leak Extension 自动 Quarantine

**决定：** 对持续激活失败、资源泄漏、异常 Context 注入、Crash Loop 或 Contract Violation 的 Extension 自动隔离，停止自动激活与能力暴露，保留可审计证据。
**状态：** Accepted

## D-167 — Extension Host 采用增量 Registry / Dependency / Capability Projection

**决定：** Agent Turn 不扫描全部 Plugin；ExtensionRegistryIndex、DependencyGraph、CapabilityProjection、EffectLedger、UsageLedger 增量维护。
**状态：** Accepted

## D-168 — Phase 1 只开放“提议 + 临时自扩展 + 显式审批”

**决定：** MVP 不允许 Agent 自动永久安装自己写出的生产插件；先证明 Ephemeral Extension 的权限、回滚、审计和销毁完全可靠，再逐步放宽自治。
**状态：** Accepted


---

# 146. Model Registry — 模型必须成为 Workbench 一等配置对象（Draft v0.22）

Workbench 后续同时存在 DeepSeek Harness、Codex Harness、多种 Model Provider、多模态模型与不同成本层级，因此模型不能继续散落在 Runtime 配置、环境变量或 UI 下拉框中。

正式建立：

```text
Workbench Model Registry
```

它是模型元数据、能力、可用状态、价格、Runtime 兼容性和管理策略的产品层注册表。

核心原则：

```text
Model != Runtime
Model != Agent
Model != Provider Credential
```

同一个 Agent 可以在不同 Turn 使用不同 Model；同一个 Model 也可能通过不同 Runtime / Provider 路径执行。

建议统一对象：

```ts
interface WorkbenchModelDefinition {
  modelId: string
  providerId: string
  displayName: string
  apiModelName: string

  status:
    | 'active'
    | 'degraded'
    | 'draining'
    | 'disabled'

  capabilities: ModelCapabilityManifest

  contextWindow?: number
  maxOutputTokens?: number

  pricing?: {
    inputPerMillion?: number
    outputPerMillion?: number
    cachedInputPerMillion?: number
    currency: string
  }

  supportedRuntimeIds: string[]
  tags: string[]

  qualityProfile?: Record<string, number>
  latencyProfile?: Record<string, number>

  credentialRef?: string
  endpointRef?: string

  createdAt: string
  updatedAt: string
}
```

Model Registry 只保存 Credential Reference，不应保存可被普通配置页面直接读取的明文 API Key。

---

# 147. Model / Provider 配置仅管理员可修改

用户提出的权限边界正式定义为：

```text
Admin / Owner
→ Add Provider
→ Add Model
→ Edit Model
→ Disable / Drain Model
→ Delete Model Definition
→ Configure Endpoint
→ Configure Credential Reference
→ Configure Pricing / Capability / Runtime Compatibility

普通成员
→ Read allowed model metadata
→ 在管理员允许的候选范围内为自己的 Agent 选择策略
→ 不得新增 / 删除 Provider 或 Model
→ 不得读取 Provider Secret
```

也就是说：

> **模型基础设施由管理员管理；Agent 的执行偏好可以由 Agent 所有者在管理员授权范围内管理。**

管理员页面建议：

```text
Settings
└── AI Infrastructure
    ├── Providers
    ├── Models
    ├── Routing Policy
    ├── Credentials
    ├── Health
    └── Usage / Cost
```

示例：

```text
MODELS

DeepSeek Reasoner
ACTIVE
Text ✓ Image ○ Video ○
DeepSeek Harness ✓
Cost: Low

Codex Engineering Model
ACTIVE
Text ✓ Image ✓
Codex Harness ✓
Cost: High

Vision Model X
DEGRADED
Image ✓ Video ✓
Runtime Adapter B ✓
```

---

# 148. 配置文件 + 配置页面必须同时存在

GUI 不是唯一配置入口。Linux-first 的管理员 / 开发部署还必须支持稳定配置文件，例如：

```text
config/
├── providers.yaml
├── models.yaml
├── routing-policy.yaml
└── credentials.refs.yaml
```

示例语义：

```yaml
models:
  - id: deepseek-general
    provider: deepseek-main
    api_model: <provider-model-name>
    enabled: true
    runtimes:
      - deepseek-harness
    tags:
      - general
      - reasoning
    credential_ref: secret://providers/deepseek-main
```

硬约束：

- 配置文件可被管理员通过 UI 修改，也可由管理员手工维护；
- GUI 与文件最终写入同一 Canonical Model Registry，不形成双真源；
- Secret 默认进入 OS Keyring / 加密 Secret Store；
- 配置文件只保存 `credential_ref`；
- Registry 变更必须生成 Audit Event；
- 普通用户进程不得读取明文 Credential；
- Model Registry 支持 revision / rollback。

---

# 149. 每一个 Agent 拥有自己的 Model Policy，而不是永久绑定一个 Model

用户提出“每一个 Agent 都可以选择使用什么模型，也可以让 AI 自己选择”，因此 Agent Instance 不保存单一死模型，而保存：

```ts
interface AgentModelPolicy {
  mode: 'auto' | 'pinned'

  pinnedModelId?: string

  allowedModelIds?: string[]
  preferredModelIds?: string[]

  qualityFloor?: number
  maxCostPerTurn?: number
  maxLatencyMs?: number

  allowFallback: boolean
  allowModelSwitchWithinWork: boolean
  askBeforePremiumModel?: boolean
}
```

默认推荐：

```text
Personal Primary Agent
Model Policy = AUTO
```

用户可以把自己的某个 Agent 改成：

```text
Pinned
→ DeepSeek Model A
```

或者：

```text
AUTO
Preferred
1. DeepSeek Model A
2. Codex Model B
```

但普通用户只能选择管理员已经：

```text
Enabled
+
Allowed for this user / role / project
```

的 Model。

---

# 150. Auto Model Router — AI 可以“自己选模型”，但不能让模型无限自由决定

用户希望 AI 根据“正在做什么”自行决定模型，这个方向接受，但不能实现成：

```text
先随便启动一个模型
→ 问它：你觉得应该换哪个模型？
→ 它随意决定
```

这会引入额外调用、循环依赖、成本和不可解释性。

正确架构：

```text
User Intent / Current Task
            │
            ▼
      Task Feature Extractor
            │
            ▼
       HARD FILTER
┌───────────┼────────────────┐
│           │                │
Modality   Runtime          Admin Policy
│           │                │
Context    Tool / Skill     Access Role
│           │                │
Budget     Health           Availability
└───────────┼────────────────┘
            ▼
      Candidate Models
            │
            ▼
        Utility Score
┌───────────┼────────────────┐
│           │                │
Task Fit   Quality         Cost
Latency    Context Fit     Cache Affinity
History    Agent Policy    Runtime Stickiness
└───────────┼────────────────┘
            ▼
       Selected Model
            │
            ▼
      Runtime / Scheduler
```

因此：

> **Agent may propose; Model Router authorizes.**

在难以判定的任务中，Personal Agent / Planner 可以提交 `model.route.proposal`，但最终选择仍由 Router 根据硬约束批准。

---

# 151. Model Router 的第一阶段算法不要依赖额外 LLM 调用

MVP 首先使用可解释、低成本的确定性 Feature：

```text
任务是否 Coding
是否需要图像
是否需要视频
是否需要超长 Context
是否依赖当前 Repo
是否要求 Tool Calling
是否要求高推理
是否要求低延迟
任务风险
当前成本策略
当前 Work Profile当前 Runtime
当前 Skill Requirements
```

例如：

```text
纯知识 / 总结 / 普通规划
→ General Candidate Set

代码修改 / Debug / Tests / Repo 操作
→ Engineering Candidate Set

图片输入
→ vision=true 硬过滤

视频输入
→ video=native/adapted 硬过滤

超长项目上下文
→ contextWindow 不满足的模型直接过滤
```

只有规则评分置信度低于阈值，才允许使用：

```text
Route Classifier / Planner Proposal
```

辅助决策。

这样绝大多数 Turn 的 Model Routing 本身几乎不产生额外 Model 成本。

---

# 152. Model Utility Score

初始可以采用可调权重评分，而不是黑盒学习算法：

```text
score(model) =
  task_fit
+ capability_fit
+ quality_score
+ history_score
+ agent_preference
+ cache_affinity
+ runtime_stickiness
- cost_penalty
- latency_penalty
- health_penalty
- context_risk
```

不同 Cost Strategy 只修改权重：

```text
Economy
→ cost_penalty 权重大

Balanced
→ quality / cost / latency 平衡

Quality
→ quality_score 权重大

Custom
→ 用户自定义 Policy
```

后续可以利用真实 Usage Ledger 做在线统计优化，但不能允许系统在没有 Audit 的情况下自行修改硬权限 / 预算上限。

---

# 153. Model Selection Receipt — 模型选择必须可解释、可视化

既然 Skill Router 有 `SkillRouterReceipt`，Model Router 同样必须产生：

```ts
interface ModelSelectionReceipt {
  receiptId: string
  agentId: string
  runId?: string
  turnId?: string

  mode: 'auto' | 'pinned'
  selectedModelId: string
  selectedRuntimeId: string

  candidates: Array<{
    modelId: string
    eligible: boolean
    score?: number
    filteredReasons?: string[]
    scoreFactors?: Record<string, number>
  }>

  policyRefs: string[]
  fallbackChain: string[]
  estimatedCostClass?: string
  createdAt: string
}
```

用户在 Glass Box / Run Detail 中可以点：

```text
为什么用了这个模型？
```

看到：

```text
MODEL ROUTER
────────────────────

Codex Engineering       0.92  SELECTED
DeepSeek General        0.71
Vision Model            FILTERED

选择原因
Coding Task             +0.32
Repository Required     +0.20
Past Success            +0.12
Runtime Stickiness      +0.10
Balanced Cost           +0.08
Tool Compatibility      +0.10

Vision Model 未选择
No engineering runtime compatibility
```

这必须来自真实 Router Receipt，而不是事后询问模型生成一个“解释”。

---

# 154. Model 状态与模型变更不能破坏正在执行的 Run

管理员操作 Model 时采用：

```text
ACTIVE
DEGRADED
DRAINING
DISABLED
```

普通删除不直接 Kill 正在使用该 Model 的 Run。

推荐：

```text
Admin Disable Model
        ↓
DRAINING
        ↓
不再接受新 Turn / Task
        ↓
当前安全 Run 完成
        ↓
DISABLED
```

只有管理员执行 Emergency Disable，或安全策略要求立即终止时，才中断现有执行。

Registry revision 变化后：

```text
Model Capability Projection
Skill Compatibility Projection
Composer Attachment Capability
Auto Router Candidate Index
```

全部增量重算。

---

# 155. Fallback 必须由 Router 管理，而不是 Runtime 自己偷偷换模型

模型出现：

```text
429
Provider outage
Health degraded
Context overflow
Capability mismatch
```

Runtime 不得静默切到另一个模型。

必须：

```text
Failure Evidence
      ↓
Model Router
      ↓
Fallback Policy
      ↓
Candidate Check
      ↓
Cost / Capability / Access
      ↓
Fallback Model
```

如果新模型成本等级明显升高或能力语义明显变化，根据用户 / Project Policy：

```text
Ask User
```

或者在预授权阈值内自动切换。

所有 Fallback 进入 Event Store 和 `ModelSelectionReceipt`。

---

# 156. Agent 页面如何呈现模型选择

默认 Composer 不增加新的常驻大按钮。

原：

```text
[Auto · Balanced]
```

可以展开为：

```text
EXECUTION

Runtime
Auto

Model
● Auto Select
○ DeepSeek Model A
○ Codex Model B
○ Vision Model X

Cost
Balanced
```

如果当前 Agent 使用 Auto：

```text
[Auto · Balanced]
```

运行后轻量显示：

```text
DeepSeek Model A
Auto selected
```

用户点击才看到 Selection Receipt。

如果 Agent 被 Pin：

```text
[Codex Model B · Balanced]
```

管理员禁用了该模型，则不得静默更换，显示：

```text
Pinned model unavailable
[Use Auto]
[Choose allowed model]
```

---

# 157. 管理员 Model Studio

管理员需要一个独立可视化页面：

```text
MODEL STUDIO

Overview
Providers
Models
Routing
Health
Usage
Cost
Audit
```

单个 Model Detail 至少展示：

```text
Model
Status
Provider
Runtime compatibility
Input modalities
Context window
Tool / function capability
Skill compatibility
Latency
Error rate
Usage
Token / Cost
Cache usage
Agents currently preferring it
Recent routing decisions
Fallback history
```

这样管理员可以真正回答：

```text
团队现在主要用了哪些模型？
哪些 Agent 在使用？
哪个模型最贵？
哪个模型最慢？
哪个模型最近失败率高？
为什么 Auto Router 总在选择某个模型？
```

---

# 158. Model Usage Ledger

禁止打开 Model Studio 后扫描全部 Event Log 做聚合。

维护增量：

```text
ModelUsageLedger
```

至少按：

```text
model_id
provider_id
runtime_id
agent_id
user_id
project_id
hour/day bucket
```

聚合：

```text
turns
runs
input_tokens
output_tokens
cached_tokens
cost
latency
success
failure
fallbacks
last_used
```

Model Router 的历史效果分数只读取 Ledger / Projection，不扫描原始历史。

---

# 159. Model Router 与 Agent Memory 的关系

Agent Memory 可以形成：

```text
“这个 Agent 在大型 Rust Repo 上使用 Model X 表现更稳定”
```

但 Memory 不得直接篡改 Model Router。

路径必须是：

```text
Agent Memory / Historical Evidence
        ↓
Validated Agent Model Preference
        ↓
AgentModelPolicy / Router Feature
        ↓
Model Router
```

管理员的：

```text
Model Disabled
Budget Limit
Security Policy
Runtime Compatibility
```

始终优先于 Agent Preference。

---

# 159A. 用户手动选择 Model 是一等执行路径，不是 Auto 的补丁

用户明确补充：除了 `AUTO`，普通用户必须能够在管理员已经允许的模型集合中，**自己选择当前 Agent / Work / Conversation / 当前 Turn 使用哪一个模型**。

因此 Model Selection Source 正式区分：

```text
AUTO_ROUTER
USER_SELECTED
AGENT_DEFAULT_PIN
WORK_OVERRIDE
TURN_OVERRIDE
FALLBACK
ADMIN_POLICY
```

推荐优先级：

```text
Admin Hard Policy
      ↓
Current Turn Override
      ↓
Current Work Override
      ↓
Conversation Override
      ↓
Agent Default Model Policy
      ↓
AUTO Router
```

注意：用户手动选择只能在 Admin Registry 已授权候选中进行，不能绕过管理员禁用、权限、预算硬上限、模型能力或 Runtime 兼容性。

### 159A.1 Agent 默认选择与“仅本次”选择必须分开

例如用户可以给自己的 Architect Agent 设置：

```text
Agent Default
Model = Auto
```

但当前 Turn 临时选择：

```text
This Turn Only
Model = Model X
```

不能因为一次临时选择就永久改掉 Agent 默认策略。UI 必须明确提供：

```text
仅本次
本会话
当前工作
设为此 Agent 默认
```

### 159A.2 手动模型与 Runtime 的关系

普通模式下用户手动 Pin `modelId` 后，Workbench 仍可在**兼容 Runtime 集合**中选择执行 Runtime；高级模式才允许用户同时 Pin：

```text
Runtime + Model
```

例如：

```text
User selected Model X
        ↓
Compatible Runtime Candidates
        ├ DeepSeek Harness
        └ Runtime Y
        ↓
Runtime Router
```

如果该 Model 只兼容一个 Runtime，则直接锁定该组合。

### 159A.3 手动选择失败时不得静默换模型

如果用户明确选择 Model X，但当前附件 / Skill / Context / Health 已不兼容：

```text
Model X unavailable for this request

原因
- Video unsupported
- Context exceeds limit

[选择兼容模型]
[切回 Auto]
[取消附件 / 降级处理]
```

除非用户预先开启：

```text
Allow fallback for manually selected model
```

否则不得静默改为其它模型。

### 159A.4 Receipt 必须记录“是谁选的”

`ModelSelectionReceipt` 增加：

```ts
selectionSource:
  | 'auto_router'
  | 'user_selected'
  | 'agent_default_pin'
  | 'work_override'
  | 'turn_override'
  | 'fallback'

requestedModelId?: string
resolvedModelId: string
```

因此 Glass Box 可以准确显示：

```text
Model X
Selected by: User
Scope: This Turn
Fallback: Disabled
```

而不是把所有非 Auto 情况都粗略标成 `Pinned`。

---

# 160. Model Routing 与 Runtime Routing 分层但联合求解

Workbench 不能假设：

```text
先选择 Runtime
再随便找该 Runtime 的 Model
```

也不能假设：

```text
先选 Model
再硬塞进任意 Runtime
```

应求解：

```text
Execution Candidate
= Runtime + Model
```

例如：

```text
Candidate A
DeepSeek Harness + Model A

Candidate B
Codex Harness + Model B

Candidate C
DeepSeek Harness + Vision Model C
```

Auto Router 对 `Runtime + Model` 组合做硬过滤和评分。

这样图片 / 视频、Skill、Tool、Sandbox、Resume、Queue、Cost 等能力才能统一判断。

---

# 161. Decision Log — v0.22 Model Registry / Admin Model Management / Auto Model Router

## D-169 — Model Registry 是 Workbench 一等配置真源

**决定：** Provider / Model 元数据、能力、价格、Runtime 兼容、Health 与状态统一进入 Workbench Model Registry；UI 与配置文件都写入该 Canonical Registry。
**状态：** Accepted

## D-170 — Model 基础设施配置仅管理员可修改

**决定：** 只有 Admin / Owner 可以新增、删除、修改 Provider / Model / Endpoint / Credential / Routing 基础策略；普通用户只能在授权候选范围内设置自己 Agent 的 Model Policy。
**状态：** Accepted

## D-171 — Agent 默认使用 Model Policy，不永久绑定单 Model

**决定：** 每个 Agent Instance 拥有 `AgentModelPolicy`；推荐默认 `AUTO`，同时支持用户在管理员允许范围内 Pin Model、设置 Preferred Models、Cost / Quality / Latency 偏好。
**状态：** Accepted

## D-172 — Auto Model Router 先硬过滤再评分

**决定：** Modality、Runtime、Context、Tool、Skill、Admin Policy、权限、预算、Health 等先做确定性 Hard Filter；只有通过候选才进入质量、成本、延迟、历史效果、Agent Preference、Cache 与 Runtime Stickiness 评分。
**状态：** Accepted

## D-173 — MVP 模型路由默认不增加额外 LLM 调用

**决定：** 第一阶段使用 Task Feature + Capability Index + Policy + Usage Ledger 做确定性路由；只有低置信度任务才允许 Planner / Route Classifier 参与建议，最终仍由 Router 授权。
**状态：** Accepted

## D-174 — 模型选择必须生成 ModelSelectionReceipt

**决定：** Auto / Fallback / Pinned 的模型选择均生成真实 Receipt，保存候选、过滤原因、评分、Policy 与 Fallback Chain；“为什么用了这个模型”从 Receipt 解释，不由模型事后编理由。
**状态：** Accepted

## D-175 — Model Disable 采用 Drain 优先

**决定：** 管理员禁用模型默认进入 DRAINING，停止新任务但允许安全 Run 收尾；Emergency Disable 才立即中断。模型变更触发相关 Capability Projection 增量重算。
**状态：** Accepted

## D-176 — Fallback 由 Workbench Model Router 统一控制

**决定：** Runtime / Provider 不得静默换模型；Fallback 必须重新通过 Capability、Admin Policy、预算与 Access 检查，并记录 Event / Receipt。
**状态：** Accepted

## D-177 — Runtime 与 Model 采用组合候选联合路由

**决定：** Auto 模式的基本候选单位是 `Runtime + Model`，避免先选 Runtime 或先选 Model 导致能力冲突；最终 Scheduler 执行已批准的 Execution Candidate。
**状态：** Accepted

## D-178 — Model 配置 Secret 与普通配置分离

**决定：** 配置文件与 Model Registry 不保存普通用户可读取的明文 API Key；使用 Credential Reference 指向 OS Keyring / 加密 Secret Store，并由管理员权限管理。
**状态：** Accepted

## D-179 — Model Usage / Health 使用增量 Ledger 与 Projection

**决定：** Model Studio、Router 历史分数、成本统计与 Health UI 使用增量 ModelUsageLedger / HealthProjection，不在页面加载时扫描全部 Event Log。
**状态：** Accepted

# 162. Runtime-native Permission Integration — 直接复用 Harness 官方权限体系（Draft v0.23.1）

本项目**不再设计一套新的统一权限架构**。上一版关于 Unified Capability、Access Envelope、Approval Lease、Workbench SandboxProvider、Network Guard、Credential Broker 等作为 Agent Runtime 权限主干的设计全部撤销，不作为实现要求。

正式原则：

> **DeepSeek Harness 的任务，使用 DeepSeek Harness 官方权限方法；Codex Harness 的任务，使用 Codex 官方权限方法；自定义权限优先写成对应 Runtime 的官方插件 / 扩展。Workbench 不重新发明权限系统。**

Workbench 在权限层只承担四个职责：

1. 给用户提供当前 Runtime 原生权限配置的 UI 入口；
2. 通过 Runtime Adapter 把用户选择传给对应 Harness；
3. 把 Runtime 原生 approval / sandbox / permission 事件投影到 Agent UI / Glass Box；
4. 保存“用户选择了什么权限模式”的产品状态与审计引用，但不成为底层权限判定真源。

---

## 162.1 DeepSeek Harness 权限：直接复用官方插件与服务

DeepSeek Harness 当前已经拥有可以直接使用的权限组成方式，包括：

```text
sandbox/mode
approval/policy
ctx.permissionPresets
ctx.approval
ctx.sandbox / ctx.sandboxPolicy
tools/pre-execute
ctx.tools.guard()
Cordis permission plugins
```

Workbench 不重新实现这些概念。

用户在 UI 中看到的例如：

```text
Permissions

[ Workspace Write ▼ ]

Workspace Write
Full Access
Custom / Plugin-defined ...
```

本质上只是读取 / 切换 DeepSeek Harness 自己的 permission preset 或相关原生配置。

如果以后需要新的权限模式，例如：

```text
Auto Review
Restricted Build
3D Render Only
Video Export Review
Enterprise Approval
```

优先实现为 DeepSeek Harness / Cordis 官方扩展路径上的权限插件，而不是往 Workbench Core 中增加一套新权限引擎。

---

## 162.2 DeepSeek 自定义权限插件

自定义权限逻辑可以使用 DeepSeek Harness 官方公开扩展点，例如在 `tools/pre-execute` 上做 allow / deny / review，也可以使用 `ctx.tools.guard()` 放置不可被后续插件放宽的硬性拒绝。

因此 Workbench 的“自定义权限”产品能力定义为：

```text
Custom Permission Package
        ↓
DeepSeek Runtime Adapter
        ↓
Cordis Permission Plugin
        ↓
DeepSeek Harness native execution
```

Workbench 可以负责插件发现、安装、启停和可视化，但**权限判定仍发生在 DeepSeek Harness 官方插件链里**。

---

## 162.3 Codex 权限：保持 Codex 原生机制

Codex Runtime 同样不映射成 Workbench 自建权限模型。Codex Adapter 直接使用 Codex app-server / CLI 原生的 sandbox、approval 与 permission request 流程。

例如 UI 收到 Codex 原生 approval request 后直接展示：

```text
Codex 请求执行命令 / 修改文件 / 扩大权限

[允许]
[允许本会话]
[拒绝]
```

用户作出的决定通过 Codex Adapter 原样回给 Codex。

如果 Codex 后续增加新的原生 permission profile / approval mode / sandbox 能力，Workbench 优先直接适配上游，而不是先要求它符合一套 Workbench 自定义权限抽象。

---

## 162.4 Workbench UI 可以统一“展示”，但不统一“权限内核”

允许在产品层提供一个统一入口：

```text
Agent Settings
└── Permissions
```

但打开后根据 Runtime 显示不同原生配置：

```text
DeepSeek Harness
├── Permission Preset
├── Sandbox Mode
├── Approval Policy
└── Installed Permission Plugins

Codex Harness
├── Sandbox
├── Approval Policy
├── Permission Requests
└── Runtime-native options
```

这叫 **Unified Permission UX**，不是 **Unified Permission Engine**。

它只统一用户体验，不统一底层权限算法。

---

## 162.5 Agent / Work / Session 的权限选择

产品可以保存用户希望采用哪一种 Runtime-native 权限配置，例如：

```text
Agent Default
Conversation Override
Work Override
Current Session / Run Override
```

但这些值本质上是：

```text
runtimePermissionProfileRef
```

例如：

```text
deepseek:permission-preset/workspace-write
deepseek:plugin/codex-auto-review
codex:approval/on-request
codex:sandbox/workspace-write
```

Workbench 不解释这些 profile 内部如何判定；对应 Runtime Adapter 负责读写它们。

---

## 162.6 权限可视化仍然保留

撤销自建权限内核**不代表撤销权限可视化**。

Agent Glass Box 仍可以显示当前 Runtime 提供的真实状态：

```text
PERMISSIONS

Runtime
DeepSeek Harness

Preset
Workspace Write

Sandbox
workspace-write

Approval
ask

Permission Plugins
Codex Auto Review   ACTIVE

Recent Approval
write src/runtime/router.ts   ALLOWED
```

Codex 时则显示 Codex 自己返回的 sandbox / approval / permission request 状态。

所有展示必须来自 Runtime 原生状态或事件，不能由 Workbench 猜测。

---

# 163. Decision Log — v0.23.1 Native Harness Permission Reuse

## D-180 — 用户手动选择模型是一等路径

**决定：** 用户可在管理员授权候选内，对 Agent 默认、Conversation、Work 或单个 Turn 手动选择 Model；`AUTO` 只是推荐默认，不是唯一执行方式。临时 Override 不得静默改写 Agent 永久默认。  
**状态：** Accepted

## D-181 — 手动模型不可静默 Fallback

**决定：** 用户明确选择的 Model 若不可用 / 不兼容，默认阻止执行并解释原因；只有用户预先允许 Manual Fallback 时才可替换，并必须生成 Receipt。  
**状态：** Accepted

## D-182 ~ D-190 — 上一版 Unified Security Architecture

**决定：** Superseded。上一版自建 Unified Capability / Access Envelope / Approval Lease / Workbench SandboxProvider / Process Guard / Network Guard / Credential Broker 作为 Runtime 权限主干的方案全部撤销。保留其中与普通应用数据权限、团队 RBAC 或 UI 审计相关的独立需求时，必须避免重新演化成第三套 Agent Runtime 权限系统。  
**状态：** Superseded by D-191 ~ D-194

## D-191 — Runtime-native Permission First

**决定：** Agent Runtime 的权限、审批与沙箱优先直接使用对应 Harness 官方原生实现。DeepSeek Harness 使用其官方 permission / approval / sandbox / Cordis plugin 体系；Codex 使用其原生 sandbox / approval / permission request 体系。Workbench 不实现新的通用 Runtime 权限内核。  
**状态：** Accepted

## D-192 — DeepSeek 自定义权限使用官方 Cordis 扩展点

**决定：** DeepSeek Harness 需要自定义权限时，优先以官方 Cordis plugin / `tools/pre-execute` / `ctx.tools.guard()` / permission preset 等公开扩展方式实现，不把策略代码迁入 Workbench Core。  
**状态：** Accepted

## D-193 — Codex 权限由 Codex Adapter 原生透传

**决定：** Workbench 对 Codex approval / sandbox / permission request 只做 Adapter、UI 与事件投影；用户决策返回 Codex 原生协议，不要求 Codex 服从 Workbench 自定义权限对象模型。  
**状态：** Accepted

## D-194 — Unified Permission UX, Not Unified Permission Engine

**决定：** Workbench 可以提供统一 Permissions 页面和 Glass Box 展示，但底层配置、判定与 enforcement 仍属于各 Runtime。统一的是入口、可视化和管理体验，不统一权限内核。  
**状态：** Accepted



# 164. Workspace / Files 正式架构（Draft v0.24）

## 164.1 Workspace 的定位：资源环境与执行环境，而不是 Project 的别名

`Project` 继续表示长期逻辑工作上下文；`Workspace` 表示真实资源所在位置以及 Runtime 可以工作的执行环境。

```text
Project
├─ requirements / decisions / tasks / conversations
└─ workspace bindings
      ├─ Primary Workspace
      └─ Auxiliary Workspaces

Workspace
├─ files / folders / repositories / media / assets
├─ provider / location
├─ capabilities
└─ execution binding
```

因此一个 Project 可以：

```text
0 Workspace        # 纯讨论 / 规划
1 Primary Workspace
N Auxiliary Workspaces
```

同一个 Workspace 也可以在多个 Work 中被引用，但 Workspace 自己的身份不由 Project 决定。

核心原则：

> **Project tells us what the work is; Workspace tells us where the real resources and execution environment are.**

---

## 164.2 Workspace Provider：统一产品语义，不强行统一底层存储实现

第一阶段保留四类 Provider：

```text
WorkspaceProvider
├─ LocalWorkspace
├─ RemoteWorkspace
├─ MountedWorkspace
└─ MirroredWorkspace
```

含义：

```text
Local
= 本机目录 / 磁盘 / 本机 Git Repo

Remote
= 服务器文件系统或远程执行环境中的资源

Mounted
= 已由 OS 挂载的 NAS / SMB / NFS / SSHFS / 其它文件系统

Mirrored
= Local Working Copy + Remote Canonical/Backup Target
```

Workbench Core 只依赖稳定 Provider Contract，例如：

```ts
interface WorkspaceProvider {
  probe(): Promise<WorkspaceCapabilities>
  list(input: ListRequest): Promise<ResourceEntry[]>
  stat(ref: ResourceRef): Promise<ResourceStat>
  openRead(ref: ResourceRef, options?: ReadOptions): Promise<ReadableHandle>
  openWrite?(ref: ResourceRef, options?: WriteOptions): Promise<WritableHandle>
  search?(input: WorkspaceSearchRequest): Promise<SearchResult[]>
  watch?(input: WatchRequest): AsyncIterable<WorkspaceChange>
  transfer?(input: TransferRequest): Promise<TransferJob>
  snapshot?(input: SnapshotRequest): Promise<WorkspaceSnapshot>
}
```

不是所有 Provider 都必须实现所有能力。UI、Scheduler 与 Adapter 根据 `WorkspaceCapabilities` 决定功能是否可用。

---

## 164.3 Workspace Registry 与 Workspace Binding

Workbench 维护 `Workspace Registry`，保存产品层稳定身份和连接信息：

```ts
interface WorkspaceRecord {
  workspaceId: string
  displayName: string
  providerType: 'local' | 'remote' | 'mounted' | 'mirrored'
  providerRef: string
  rootRef: string
  capabilitiesRevision: number
  status: 'ready' | 'offline' | 'degraded' | 'syncing' | 'conflict'
  createdAt: string
  updatedAt: string
}
```

Project / Work Item 只保存 Binding：

```text
Project P-1
├─ primaryWorkspaceId = W-1
└─ auxiliary = [W-2, W-3]
```

禁止把：

```text
/home/user/project-a
```

当成跨设备业务主键。

路径是 Provider 内定位信息，`workspaceId / resourceId` 才是产品层引用身份。

---

## 164.4 ResourceRef：文件被移动 / 重命名后尽量不让 Conversation 引用失效
资源引用建议统一为：

```ts
interface ResourceRef {
  workspaceId: string
  resourceId: string
  pathHint?: string
  revision?: string
  contentHash?: string
}
```

对不支持稳定 inode/object-id 的 Provider，可以由 Workbench/Provider 维护资源映射；`pathHint` 用于展示与定位，但不是唯一身份来源。

聊天、Task、Artifact、Memory `sourceRefs` 与 Decision 中引用文件时，优先引用 `ResourceRef`，避免文件改名以后历史记录全部断裂。

---

## 164.5 Workspace / Files 页面：像文件管理器，但不是复制 Windows Explorer

主导航保留独立：

```text
Workspace / Files
```

推荐基础布局：

```text
┌──────────────┬─────────────────────────────┬──────────────────────┐
│ Workspaces   │ Files / Search              │ Preview / Inspector  │
│              │                             │                      │
│ Local        │ src/                        │ router.rs            │
│ Server       │ assets/                     │ revision / size      │
│ Mounted      │ video/                      │ git status           │
│              │ ...                         │ used by Work / Agent │
└──────────────┴─────────────────────────────┴──────────────────────┘
```

基础能力：

```text
browse
search
preview
rename / move / copy / delete
create folder
open externally
show in system file manager
transfer
attach to conversation/work
tag / pin / recent
```

本地文件的语义优先使用 `Import / Export / Copy / Move`；远程资源使用 `Upload / Download`。不要在 Local Workspace 上把普通本机复制也错误叫成“上传”。

---

## 164.6 Agent 访问 Workspace：Workbench 负责 Binding，Harness 负责权限

此处正式修正旧版 54.6 中容易误解为 Workbench 自建文件权限层的描述。

Workbench 可以提供 `Workspace Gateway` 给自身 UI、Context Broker、索引器、预览器和同步器使用，但 Agent Runtime 的真实文件访问不由 Workbench 自建 `workspace:read / write` 权限引擎决定。

正确链路：

```text
Task / Work Item
      ↓
Workspace Binding Resolver
      ↓
ExecutionWorkspaceBinding
      ↓
Runtime Adapter
      ↓
DeepSeek Harness / Codex Harness
      ↓
Runtime-native sandbox / approval / permission plugins
      ↓
real filesystem / remote execution environment
```

`ExecutionWorkspaceBinding` 只回答：

```text
这个任务在哪个 Workspace 工作？
运行时看到哪个 root？
是本机路径、挂载路径、远程 Session，还是临时镜像？
当前 revision / snapshot 是什么？
```

它**不重新定义 Harness 的 allow / deny / approval 逻辑**。

---

## 164.7 Execution Workspace Binding

建议统一产品层描述：

```ts
interface ExecutionWorkspaceBinding {
  bindingId: string
  workspaceId: string
  runtimeId: string
  mode:
    | 'local-direct'
    | 'mounted-direct'
    | 'remote-native'
    | 'mirrored-local'
    | 'isolated-copy'
    | 'git-worktree'
  runtimeRootRef: string
  sourceRevision?: string
  writable: boolean
  disposable: boolean
  syncBackPolicy?: string
}
```

不同 Runtime Adapter 可以用完全不同的方法实现：

```text
DeepSeek Adapter
→ 绑定 Local root / remote environment
→ 使用 DeepSeek 原生 sandbox/permission

Codex Adapter
→ 绑定 Codex working directory / thread environment
→ 使用 Codex 原生 sandbox/approval
```

Workbench 只需要知道结果和生命周期。

---

## 164.8 多 Agent / Hybrid 并行写入：优先隔离工作副本，而不是全局文件锁

复杂任务中，两个 Agent 同时改同一 Repo 是实际风险。

不建议默认：

```text
Agent A ─┐
         ├─ 同时直接写 /project
Agent B ─┘
```

推荐 Scheduler 根据 Task Graph 与 Workspace 能力选择：

```text
Read-only parallel
→ 同一个 Workspace 共享读

Independent write paths
→ 可共享 Workspace，记录 write intent

Code branch work
→ 优先 Git worktree / branch isolation

Binary / non-mergeable assets
→ isolated copy / explicit exclusive edit

Remote environment
→ Provider / Runtime-native isolated session
```

代码项目中优先考虑：

```text
Task A
→ worktree A

Task B
→ worktree B

Review / Merge Task
→ compare / test / merge
```

这比 Workbench 自己发明一套复杂全局锁更符合现有开发工具链，也更容易审计和恢复。

Scheduler 仍可维护 `readSet / writeIntent` 作为调度信号，但它不是文件系统权限实现。

---

## 164.9 Git 是 Workspace Capability Overlay，不是新的 Workspace 类型

不新增 `GitWorkspace` 作为第五种 Provider。

一个 Local / Remote / Mounted / Mirrored Workspace 都可能同时具有：

```text
git.detected = true
repoRoot
branch
head
status
diff
worktree support
```

因此 Git 更适合做：

```text
Workspace Capability / Repo Adapter
```

而不是把存储位置和版本控制概念混成一个类型。

UI 可在 Workspace Inspector 显示：

```text
Repository
main
3 modified
1 untracked
HEAD abc123
```

详细 Diff / Commit / Branch 能力仍优先复用 Runtime 或 Git 原生工具，不在 Workspace Core 中重做完整 Git Client。

---

## 164.10 大文件：Metadata First，禁止默认完整载入

视频、3D、数据集、模型文件可能达到 GB/TB 级，不能沿用普通文本文件思路。

统一原则：

```text
Metadata First
Preview / Proxy Second
Range / Chunk Read
Full Transfer Only When Required
```

`ResourceStat` 至少允许提供：

```text
size
mime / kind
modifiedAt
contentHash（可选/延迟）
previewRef
proxyRefs
indexState
```

视频：

```text
原文件
├─ metadata
├─ transcript（可选）
├─ keyframes（可选）
└─ low-res preview proxy（可选）
```

3D：

```text
原文件
├─ metadata
├─ dependency manifest
├─ thumbnail / turntable preview
└─ lightweight scene proxy（后续）
```

这些是 Workspace 派生 Artifact / Cache，不替代原文件真源。

---

## 164.11 “上传到 Workspace”与“Attach to Agent”必须彻底分离

用户可以把任何允许的文件存进 Workspace，即使当前 Model 不支持理解该类型。

```text
Upload / Import to Workspace
→ Storage capability

Attach to Agent
→ Runtime + Model effective modality capability
```

例如当前模型不支持视频：

```text
video.mov
Workspace: READY ✓
Attach to Agent: UNSUPPORTED / ADAPTED
```

绝不能因为模型能力不足而禁止用户把视频保存到工作空间。

---

## 164.12 Preview / Viewer 采用 Resource Viewer Adapter

Workspace Inspector 不应硬编码所有文件类型。

```text
ResourceViewerAdapter
├─ Text / Code
├─ Image
├─ Video
├─ Audio
├─ PDF / Document
├─ Diff
├─ 3D Scene（后续）
└─ Fallback Metadata
```

Viewer 只负责展示和交互，不改变 Canonical Resource。

未来 Blender / 3D DCC、视频剪辑工具、CAD 等都可通过 Viewer / External Tool Adapter 接入，而不是不断修改 Workspace 核心数据模型。

---

## 164.13 Workspace Change Projection：Event Store 记录“发生了什么”，文件系统仍是内容真源

Workspace Provider 的 watcher / remote change feed 可以产生：

```text
workspace.resource.created
workspace.resource.modified
workspace.resource.moved
workspace.resource.deleted
workspace.sync.started
workspace.sync.completed
workspace.sync.conflict
```

这些进入 Workbench Event Store，用于：

```text
UI 增量刷新
Recent Files
Agent Activity
Task / Artifact lineage
搜索索引更新
审计与恢复提示
```

但：

> **Event Store 不复制并成为整个文件内容的第二真源。**

真实文件内容仍由对应 Workspace Provider 管理。

---

## 164.14 Mirrored Workspace：与 Agent Data Sync 完全分开

Mirrored Workspace 以后负责：

```text
Local Working Copy
        ↕
Workspace Sync Engine
        ↕
Remote Target
```

与此前的 Agent Data Sync 不同：

```text
Agent Data Sync
→ Conversation / Work State / Memory metadata / Preferences / small artifacts

Workspace Sync
→ repository / media / 3D / binary / directory tree
```

Mirrored Workspace 需要自己的：

```text
Sync Journal
manifest
revision / etag
content hash
delta / chunk transfer
resume
conflict state
```

文本文件未来可提供三方 Merge；大型二进制文件默认不做“智能自动合并”，冲突必须显式选择版本或进入专业工具处理。

---

## 164.15 Remote Workspace 与离线行为

Remote Workspace 状态至少：

```text
READY
OFFLINE
DEGRADED
RECONNECTING
AUTH_REQUIRED
```

离线时：

```text
Remote only
→ 只能显示已缓存 metadata / preview
→ 不假装文件可执行或完整可读

Mirrored
→ 可继续使用本地 working copy
→ 恢复连接后增量同步
```

Work Capsule 必须保存 Workspace Binding 和最后已知 revision，使“换电脑继续工作”时能够准确提示：

```text
Agent state restored ✓
Workspace not connected
[重新绑定] [Clone] [连接 Server]
```

而不是误导用户“工作已经完整恢复”。

---

## 164.16 Transfer Job：上传 / 下载必须是可恢复任务

对于远程 Workspace 和大文件，Upload / Download 不应作为一个不可观察的 UI 请求。

统一建模：

```ts
interface TransferJob {
  transferId: string
  direction: 'upload' | 'download' | 'sync'
  sourceRef: string
  destinationRef: string
  bytesTotal?: number
  bytesDone: number
  status: 'queued' | 'running' | 'paused' | 'failed' | 'completed' | 'cancelled'
  resumable: boolean
  checksumState?: string
}
```

用户可以：

```text
查看进度
暂停 / 恢复（Provider 支持时）
取消
失败重试
查看冲突 / 校验错误
```

大文件传输默认 chunked + resumable；同内容可通过 content hash 去重时由 Provider 优化。

---

## 164.17 Search / Index：按资源类型分层，不做全盘同步扫描

Workspace Search 分层：

```text
Path / filename index
Metadata index
FTS for text/code
Optional semantic index
Media transcript / tag index
```

本地 Provider 优先 watcher 驱动增量索引；远程 Provider 优先使用 remote change feed / provider-native search；没有事件能力时再做有限 background reconciliation。

禁止：

```text
每次用户打开搜索
→ 扫描整个 Workspace
```

也禁止因为 Agent 需要找一个文件，就把整个 Workspace 的目录树全部塞进 Context。

Context Broker 只取相关 `ResourceRef + excerpt / metadata`。

---

## 164.18 Workspace 与 Agent Glass Box / Flow Canvas 的关系

运行中的真实文件活动可以成为透明执行的一部分：

```text
Codex Engineer
   ↓
router.rs   modified
adapter.rs  created
   ↓
cargo test
   ↓
3 files changed
```

Agent Glass Box 可显示：

```text
WORKSPACE
Binding      git-worktree
Root         worktree/run-842
Reads        34 files
Writes       3 files
Generated    1 artifact
Transfers    0
```

Flow Canvas 中只显示有工作意义的资源节点 / Artifact，不把几千个普通文件节点全部画出来。

---

## 164.19 Workspace 性能预算

第一阶段工程预算：

```text
Local directory first page       P95 < 50ms
Local metadata stat              P95 < 20ms
Workspace switch cached          P95 < 100ms
Watcher event -> UI projection   P95 < 150ms
Filename / path search           P95 < 50ms（已索引）
Large directory                  virtualized / paginated
Preview generation               async, never block explorer
Hash / media indexing            background worker
```

这些是工程目标，不是对所有磁盘 / NAS / 网络环境的产品 SLA。

---

## 164.20 第一阶段实现边界

MVP 不需要一次做完所有 Provider。

建议顺序：

```text
Phase A
LocalWorkspace
ResourceRef
Workspace Registry
Explorer / Search / Preview
ExecutionWorkspaceBinding
DeepSeek + Codex local binding

Phase B
Git capability / worktree isolation
TransferJob
MountedWorkspace

Phase C
RemoteWorkspace
Remote execution binding

Phase D
MirroredWorkspace
Sync Journal
Conflict handling

Phase E
3D / Video / DCC specialized viewers and proxies
```

关键不是先支持所有协议，而是先把 `Workspace identity → ResourceRef → Runtime Binding → native Harness execution` 这条主链跑通。

---

# 165. Decision Log — v0.24 Workspace / Files & Execution Binding

## D-195 — Workspace 是独立资源 / 执行环境层

**决定：** Workspace 与 Project 解耦。Project 表示逻辑工作上下文，Workspace 表示真实资源与执行环境；Project 通过 Binding 引用一个或多个 Workspace。  
**状态：** Accepted

## D-196 — Workspace Provider 统一语义，不统一实现

**决定：** Local / Remote / Mounted / Mirrored 通过统一 Provider Contract 暴露能力，但 Provider 可拥有不同实际协议与能力；UI 按 capability 动态适配。  
**状态：** Accepted

## D-197 — ResourceRef 是稳定产品引用

**决定：** Conversation / Task / Artifact / Memory sourceRefs 不以绝对路径作为唯一身份；使用 `workspaceId + resourceId`，路径只作为 Provider 定位 / 展示信息。  
**状态：** Accepted

## D-198 — Workbench 负责 Workspace Binding，不自建 Runtime 文件权限

**决定：** Workbench 解析任务使用哪个 Workspace、Runtime root 和执行副本；DeepSeek/Codex 对该 Workspace 的真实读写权限继续由各 Harness 原生 sandbox / approval / permission plugin 实现。  
**状态：** Accepted

## D-199 — ExecutionWorkspaceBinding 是 Runtime Adapter 合同

**决定：** Local direct、mounted direct、remote native、mirrored local、isolated copy、git worktree 等执行方式通过 Runtime Adapter 绑定；Workbench 不要求所有 Runtime 使用相同文件系统实现。  
**状态：** Accepted

## D-200 — 多 Agent 写入优先隔离副本 / Worktree

**决定：** 并行写代码时优先 Git worktree / branch isolation；不可合并二进制资源优先 isolated copy 或显式独占编辑。Scheduler 的 readSet / writeIntent 用于调度，不作为新的文件权限系统。  
**状态：** Accepted

## D-201 — Git 是 Workspace Capability Overlay

**决定：** Git 不是第五种 Workspace Provider；Local / Remote / Mounted / Mirrored Workspace 均可声明 Repo 能力，并由 Repo Adapter / Runtime 原生工具处理 Git 操作。  
**状态：** Accepted

## D-202 — Upload to Workspace 与 Attach to Agent 分离

**决定：** Workspace 可保存模型当前不理解的资源；是否能 Attach 给 Agent 由 Runtime+Model effective modality capability 决定，不能反向限制 Workspace 存储。  
**状态：** Accepted

## D-203 — 大文件采用 Metadata-first / Proxy / Chunk Strategy

**决定：** 视频、3D、数据集等大型资源默认只加载 metadata / preview / proxy，支持 range/chunk/read-on-demand；禁止默认全文 / 全文件加载进 UI 或模型 Context。  
**状态：** Accepted

## D-204 — Workspace Event 是投影，不是文件内容真源

**决定：** Workspace change event 进入 Event Store 支持 UI、索引、审计和 lineage；原文件内容仍由 Workspace Provider 管理，不复制成第二 Canonical File Store。  
**状态：** Accepted

## D-205 — Agent Data Sync 与 Workspace Sync 永久分层

**决定：** Conversation / Work / Agent Memory 等 Agent Data Sync 与目录、Repo、视频、3D 等 Workspace Sync 是两条独立协议。Mirrored Workspace 使用独立 Sync Journal / Manifest / Conflict 机制。  
**状态：** Accepted

## D-206 — Transfer 是一等可恢复 Job

**决定：** Remote / Mirrored 的 upload/download/sync 采用可观察、可取消、可重试、可恢复的 TransferJob；大文件优先 chunked/resumable。  
**状态：** Accepted

---

# 166. Git Repository AI Review / Change Gate

Git 仓库中的 AI 审查不是“让一个模型每次重新读完整仓库”，而应围绕 **Change Set / Diff** 工作，并与 Scheduler、Review Task、Repair Task 和 Workspace Git Capability 对接。

核心目标：

```text
AI 修改代码
   ↓
形成 Git Change Set
   ↓
快速确定性检查
   ↓
AI Review Provider
   ↓
ReviewFinding[]
   ↓
APPROVED / CHANGES_REQUESTED / BLOCKED
   ↓
需要时创建 Repair Task
   ↓
Re-review
   ↓
Merge / Commit / Push Gate
```

## 166.1 开源项目接入原则

第一候选采用 `PR-Agent` 思路 / Adapter。它已经具备 `/review`、`/improve`、`/ask`、大 PR 压缩、多 Git Provider、多模型、Repo Context 等成熟能力，适合作为 `GitReviewProvider` 的参考实现或可选外部 Provider。

第二候选可评估自托管 AI code reviewer 类型项目，尤其是支持 OpenAI-compatible / 本地模型、inline findings、无独立 SaaS 依赖的实现。

Workbench 不把任何第三方 Reviewer 变成产品真源：

```text
Open-source Reviewer
      ↓
GitReviewAdapter
      ↓
Normalized ReviewFinding
      ↓
Workbench Review State / Scheduler
```

第三方项目负责“怎样分析 Change Set”，Workbench 负责“什么时候审查、如何展示、是否阻断流程、怎样进入 Repair lineage”。

所有候选仍需进入 Integration Registry，检查版本、License、部署方式、模型适配、数据外发和升级风险。

## 166.2 Review Target

AI Review 必须支持不同粒度：

```text
Uncommitted Diff
Staged Diff
Commit
Commit Range
Branch vs Base
Pull Request / Merge Request
Agent Run Change Set
```

默认对 Agent 自动修改使用：

```text
Run Base Snapshot
      vs
Current Working Tree / Worktree
```

避免把整个 Repo 作为主要输入。

## 166.3 Diff-first + Context-on-demand

基础审查包：

```text
Diff / Patch
Changed file metadata
Relevant project conventions
Relevant AGENTS / Skill / Decision refs
Test / lint result refs
```

只有 Reviewer 判断缺上下文时才按 `ResourceRef` 读取：

```text
邻近函数
类型定义
调用方
配置
测试
```

禁止默认“递归读取整个仓库”。

大 Diff 使用 file-aware / hunk-aware chunking，保证一个文件或逻辑修改尽量不被随意切断，并显式记录未覆盖 / 截断区域。

## 166.4 ReviewFinding Canonical Model

```ts
interface ReviewFinding {
  findingId: string
  reviewId: string
  severity: 'info' | 'low' | 'medium' | 'high' | 'critical'
  category?: string
  resourceRef: string
  lineRange?: { start: number; end: number }
  title: string
  description: string
  suggestion?: string
  evidenceRefs: string[]
  reviewerProvider: string
  reviewerModel?: string
  status: 'open' | 'accepted' | 'dismissed' | 'fixed' | 'stale'
}
```

AI Review 的发现是 Review Evidence，不自动等于事实；用户 / Reviewer Agent / Workflow Policy 可以接受、驳回或要求修复。

## 166.5 Review Gate 与 Repair

默认推荐的开发流程：

```text
Implement
   ↓
Tests / Lint
   ↓
AI Review
   ↓
┌─────────────┬─────────────────┐
│ APPROVED    │ CHANGES_REQUESTED
│             │
▼             ▼
Merge Ready   Repair Task
                  ↓
               Re-review
```

高风险项目可以配置：

```text
Critical finding -> BLOCK merge
High finding     -> require review / repair
Medium / Low     -> advisory
```

该 Gate 由项目工作流策略决定，而不是由某个 AI Reviewer 自己获得无限阻断权。

## 166.6 安全边界

PR / Diff 本身视为不可信输入。Review Provider 默认不执行 PR 中的代码，不从 PR Head 获取可修改 Reviewer Prompt / Secret，不因为 Diff 中存在“忽略规则 / 输出 Token”等文本而改变系统策略。

对外部 Git Provider / Action 的 Token 继续使用其原生安全机制与受限权限；Workbench 只做 Adapter / 配置 /审计，不另造 Harness 权限系统。

---

# 167. Workspace Explorer — Windows Explorer-grade UX + AI Change Overlay

Workspace 页面目标不是“做一个开发者文件树”，而是达到 **Windows 11 Explorer 级别的文件管理体验**，再叠加 AI 工作透明度。

## 167.1 产品交互目标

主界面应至少具备：

```text
Tabs
Back / Forward / Up
Breadcrumb / Address Bar
Search
Left Navigation Tree
Command Bar
Details / List / Grid / Gallery
Sort / Group / Filter
Multi-select
Context Menu
Drag & Drop
Copy / Cut / Paste
Rename
Delete / Trash
Properties
Keyboard Shortcuts
Preview Pane
Details Pane
Status / Operation Center
```

重点是“交互习惯与 Windows Explorer 尽量一致”，让普通团队成员无需重新学习一套文件操作逻辑。

## 167.2 开源参考策略

参考层分三类：

```text
Files Community / Files
→ Windows 11 级 UX、Fluent 交互、Tabs、文件管理产品感参考

Tauri + Rust File Explorer 项目
→ Linux-first 技术结构、Rust 文件 I/O、React Explorer、SFTP / Search / Cache 参考

Spacedrive / similar distributed explorer
→ Resource abstraction、Daemon / IPC、跨设备文件系统架构参考
```

但“开源”不意味着直接把项目嵌进我们的页面。

对于 Windows-only WinUI / C# 项目，无法作为 Linux-first Tauri 页面直接嵌入；对于 GPL / AGPL / FSL 等项目，必须先做 License Review；对于尚未 production-ready 的项目，只借鉴组件结构和算法，不作为核心依赖。

优先策略：

```text
Borrow UX / architecture
      ↓
Reuse compatible permissive components if appropriate
      ↓
Integrate through Provider / IPC if project itself适合独立运行
      ↓
Do not fork-and-merge entire file manager blindly
```

## 167.3 AI Change Overlay

Windows Explorer 体验之上增加 Workbench 专属 AI 层，但默认保持克制。

文件状态示例：

```text
router.rs          AI Modified · Codex · Run 821
adapter.rs         AI Created  · Codex · Run 821
test_router.rs     AI Modified · Reviewer Repair · Run 824
README.md          Human Modified
```

可快速过滤：

```text
[All]
[AI Changed]
[Human Changed]
[Current Run]
[Current Task]
[Unreviewed]
[Conflicted]
```

选中文件后右侧 Preview / Details 可展示：

```text
Current file
Diff
Before / After
Changed by which Agent
Task / Run
Skill used
Review findings
Tests related
Commit / Branch / Worktree
```

## 167.4 AI Operation Timeline

文件系统操作过程也必须可观察：

```text
22:01:14  Codex read      src/router.rs
22:01:22  Codex modified  src/router.rs
22:01:24  Codex created   src/adapter.rs
22:01:31  test skill      cargo test
22:01:44  Reviewer        finding HIGH #R-17
22:02:02  Repair Task     modified src/router.rs
```

默认 UI 只显示有意义的“写入 / 创建 / 删除 / 重命名 / Review / Test”事件，避免把数百次普通 read 变成噪音；完整 read evidence 可在 Glass Box / Developer Trace 查看。

## 167.5 Explorer 与 Git Diff 合并体验

Git Repo Workspace 中，文件列表可直接显示：

```text
M  modified
A  added
D  deleted
R  renamed
?  untracked
```

再叠加 Actor：

```text
M · AI
M · Human
M · Mixed
```

点击 Modified 文件直接进入内嵌 Diff Preview，不要求用户跳到另一个 Git 页面才能看 AI 改了什么。

---

# 168. Workspace High-performance I/O / Cache / Resumable Transfer

目标不是“第一次把整个磁盘读完以后很快”，而是：

> **First Frame Fast、Memory Bounded、Work Incremental、Failure Resumable。**

## 168.1 Directory Open：两阶段加载

禁止：

```text
打开目录
→ 对所有文件 stat + hash + thumbnail + media probe
→ 全部完成后显示
```

改为：

```text
Stage A — First Frame
read dir entries
name + type + minimal metadata
→ 立即显示

Stage B — Visible Hydration
只对当前屏幕 + 小预取窗口加载
size / mtime / icon / git / thumbnail / extra metadata
```

长目录使用 UI virtualization；离开视口的 Row 不保留重型 View State。

## 168.2 有界内存缓存

缓存必须分层：

```text
L1 Memory LRU
→ 当前目录 / 最近目录 / visible metadata

L2 Local Metadata DB
→ path/resource projection / git status / indexes

L3 Disk Cache
→ thumbnails / previews / remote partials / transfer chunks
```

所有层都有 size / item / TTL / pressure eviction；禁止把 Workspace Tree 永久完整保存在前端 JS 内存。

## 168.3 增量索引

```text
Initial bounded crawl
      ↓
Persistent index
      ↓
File watcher / remote change feed
      ↓
Incremental update
```

Local Linux 优先使用原生 watcher/inotify 路径；UI 不轮询整个目录树。

Filename / path search 走索引，不重新递归扫描磁盘；内容 FTS、媒体 transcript、semantic index 全部独立后台 Worker，允许延迟可用。
## 168.4 不默认 Hash 全 Workspace

Content hash 很有价值，但非常耗 I/O。

默认只在以下场景计算：

```text
Transfer integrity
Dedup candidate
Artifact identity
Explicit verify
Sync conflict resolution
```

普通浏览不为了显示一行文件而读取完整文件计算 hash。

## 168.5 预览 / Thumbnail

Preview 规则：

```text
Text / Code -> range / bounded read
Image       -> thumbnail cache
Video       -> metadata + proxy / keyframe
3D          -> metadata + generated lightweight preview
PDF         -> page-on-demand
Huge binary -> metadata only
```

Preview Worker 与 Explorer UI 分离，失败不会阻塞文件浏览。

## 168.6 TransferJob 必须持久化

TransferJob 状态进入本地数据库：

```text
QUEUED
RUNNING
PAUSED_USER
PAUSED_NETWORK
VERIFYING
COMPLETING
FAILED_RETRYABLE
FAILED_FATAL
COMPLETED
CANCELLED
```

Workbench 重启后可以恢复未完成传输。

## 168.7 Chunk Checkpoint + Partial Cache

远程上传 / 下载采用：

```text
Transfer Manifest
├── source identity
├── target identity
├── total size
├── chunk size
├── completed bitmap / ranges
├── chunk checksums（按 Provider / 策略）
└── retry metadata
```

下载：

```text
Remote
  ↓
.partial cache file
  ↓
received ranges persisted
  ↓
network lost
  ↓
PAUSED_NETWORK
  ↓
network restored
  ↓
continue missing ranges
  ↓
verify
  ↓
atomic rename to final file
```

上传：本地源文件本身已经是主要数据，不强制复制整份文件到缓存；缓存保存 chunk/hash/checkpoint。对于 Agent 流式生成、临时数据或远端到远端中转，则可先 spool 到 Disk Cache，再异步上传。

这满足“先缓存，网络恢复继续”的目标，又避免所有本地上传都无意义复制一遍大文件。

## 168.8 Source Mutation Guard

如果 20GB 文件上传到一半，源文件被 Agent / 用户修改：

```text
size / mtime / revision changed
          ↓
Transfer detects mutation
          ↓
PAUSE
          ↓
重新快照 / 重启该文件版本 / 用户确认
```

禁止继续把旧 chunk + 新 chunk 拼成一个损坏目标文件。

## 168.9 Backpressure / Stability

每个 Workspace Provider 必须限制：

```text
parallel directory metadata jobs
parallel preview jobs
parallel hash jobs
parallel transfers
per-transfer concurrency
memory buffer bytes
open file descriptors
```

调度器根据 CPU / disk / network pressure 动态减速。

即使用户一次拖入 2,000 个文件，也只是排入 Transfer Queue，而不是同时打开 2,000 个 file handle。

## 168.10 性能预算修订

第一阶段建议：

```text
Explorer first paint cached dir       P95 < 30ms
Explorer first paint uncached local   P95 < 80ms
Visible metadata hydration            incremental < 150ms typical
Indexed filename search               P95 < 30ms
100k-row UI                            virtualized, bounded DOM
UI memory growth                      independent of total Workspace size
Preview                               never blocks directory navigation
Transfer restart recovery             < 2s to reconstruct jobs
Network reconnect                     resumes without zero restart when provider supports ranges
```

预算需在 SSD / HDD / NAS / Remote 场景分别 Benchmark，不把实验室 SSD 数字当全环境 SLA。

---

# 169. Decision Log — v0.25 Git AI Review / Explorer UX / Resumable I/O

## D-207 — Git AI Review 采用 Provider / Adapter，不自造单一 Reviewer

**决定：** 优先评估 PR-Agent 等成熟开源项目作为 GitReviewProvider；Workbench 规范 Review Target、ReviewFinding、Gate、Repair lineage 与 UI，不复制第三方 Reviewer 内部实现成为产品真源。  
**状态：** Accepted

## D-208 — Git Review 默认 Diff-first / Context-on-demand

**决定：** Agent Change Review 默认读取 Change Set / Diff 与必要上下文，不递归读取完整 Repo；大 Diff 使用 file/hunk-aware chunking，并显式记录截断 / 未覆盖区域。  
**状态：** Accepted

## D-209 — AI Review 可以进入流程 Gate，但不能自行成为最终真源

**决定：** ReviewFinding 可触发 Repair / Re-review / Merge Block；是否阻断由 Project / Workflow Policy 决定，Reviewer 输出保持可驳回、可追踪。  
**状态：** Accepted

## D-210 — Workspace Explorer 以 Windows Explorer 交互熟悉度为目标

**决定：** Workspace 的 Tabs、导航、地址栏、搜索、视图、排序、上下文菜单、拖拽、快捷键、Preview / Details 等交互尽量与 Windows 11 Explorer 保持一致，再叠加 Workbench AI 功能。  
**状态：** Accepted

## D-211 — 开源文件管理器“借鉴 / 适配优先”，禁止无审查直接内嵌

**决定：** Files 等 Windows-only 项目主要作为 UX 参考；Tauri/Rust Explorer 可作为实现参考；任何源码复用必须先通过 Integration Registry + License Review，避免平台绑定与 GPL/AGPL/FSL 等许可冲突。  
**状态：** Accepted

## D-212 — AI 文件修改必须在 Explorer 直接可见

**决定：** 文件列表 / Preview 显示 AI Created/Modified/Deleted、Agent、Run、Task、Git status 与 Review 状态；支持 AI Changed / Current Run / Unreviewed 等过滤器。  
**状态：** Accepted

## D-213 — Explorer 使用 Metadata-first + Visible-range Hydration

**决定：** 打开目录不做全量 stat/hash/thumbnail；先展示最小目录项，再对 visible range 异步补齐 metadata / preview / git 信息。  
**状态：** Accepted

## D-214 — Workspace 缓存必须有界且分层

**决定：** Memory LRU、Persistent Metadata Index、Disk Preview/Transfer Cache 分层；总 Workspace 大小不得决定前端常驻内存规模。  
**状态：** Accepted

## D-215 — 上传 / 下载采用持久 Checkpoint 与断线续传

**决定：** TransferJob、chunk/range checkpoint 与 partial cache 持久化；网络中断进入 `PAUSED_NETWORK`，恢复后续传缺失范围；完成后校验并原子落盘。  
**状态：** Accepted

## D-216 — 上传缓存不默认复制完整本地源文件

**决定：** Local→Remote 上传对已有源文件只缓存 checkpoint/hash；流式产物和中转数据可 spool 到 Disk Cache。避免“为了断点续传再复制一份几十 GB 文件”的无谓 I/O。  
**状态：** Accepted

## D-217 — 文件 I/O 统一采用 Backpressure

**决定：** directory hydration、preview、hash、index、transfer 都有并发和内存上限；大批量操作排队执行，禁止任务数量直接映射为同时打开的文件/网络连接数。  
**状态：** Accepted



---

# 170. Workspace Safety Points / Undo / Snapshot — AI 修改必须可回退

AI 能够直接操作真实 Workspace 后，“看见改动”还不够。用户必须能够明确回答：

```text
这次是谁改的？
改了哪些资源？
能不能只撤销 AI 的改动？
撤销会不会覆盖我后来自己做的修改？
大型视频 / Blender / 二进制文件有没有可恢复版本？
```

本章把 Workspace 可恢复性定义为正式产品能力，但坚持一个原则：

> **Native Versioning First, Workbench Coordination Second。**
>
> Git、文件系统 snapshot、对象版本、NAS snapshot、reflink 等成熟能力能直接使用时，Workbench 负责发现、编排、可视化和审计，不重新发明一个通用版本文件系统。

## 170.1 不存在一种适用于所有文件的“万能 Undo”

不同资源采用不同回退后端：

```text
Code / Git Repo
→ Git branch / worktree / tree / commit / inverse diff

Local CoW filesystem
→ Btrfs / ZFS / reflink snapshot where available

Remote object / versioned storage
→ Provider version id / object version

NAS / storage appliance
→ native snapshot where provider exposes it

Generic local filesystem
→ Operation Journal + targeted pre-image backup

Large binary without native versioning
→ explicit safety coverage / pre-run snapshot of declared write set
```

Workbench 的统一点不是“统一底层实现”，而是统一用户语义：

```text
Create Safety Point
Show ChangeSet
Undo Operation
Revert AI Run
Restore Version
Explain Coverage
```

## 170.2 WorkspaceVersionProvider

建议增加薄合同：

```ts
interface WorkspaceVersionProvider {
  probe(workspaceId): Promise<VersionCapabilities>

  createSafetyPoint(input): Promise<SafetyPointRef>
  diff(input): Promise<WorkspaceChangeSet>
  restore(input): Promise<RestoreResult>
  release(input): Promise<void>

  listVersions?(resourceRef): Promise<ResourceVersion[]>
}
```

Capability 至少声明：

```text
snapshot                true/false
cheapCowSnapshot        true/false
resourceVersioning      true/false
atomicRestore           true/false
partialRestore          true/false
threeWayMerge           true/false
largeBinaryEfficient    true/false
```

UI 必须根据真实 capability 显示“可完全撤销 / 部分可撤销 / 无版本保护”，禁止假装所有 Provider 都有同样保障。

## 170.3 Run Safety Point

当 Scheduler 即将让 Agent 对 Workspace 执行有写副作用的 Run 时，优先创建：

```text
Run R-821
   ↓
resolve writeIntent
   ↓
WorkspaceVersionProvider
   ↓
Safety Point SP-821
   ↓
Runtime starts
```

Safety Point 不是每次都复制整个 Workspace。

它优先利用：

```text
Git worktree / commit base
filesystem CoW snapshot
provider-native version
reflink clone
```

如果只能做普通文件备份，则根据 Task Graph 中已有的 `writeIntent` 对目标文件 / 目录做 bounded pre-image capture，而不是扫描并复制整个 Workspace。

## 170.4 Write Intent 是性能与恢复能力之间的关键桥梁

Task 已经允许声明：

```text
writeIntent
readSet
workspaceRefs
```

因此在执行前可做：

```text
Task says:
write src/runtime/**

Safety layer:
保护 src/runtime/**
而不是复制 2TB Workspace
```

如果 Runtime 将要执行的操作超出原 write intent，是否允许仍由 DeepSeek Harness / Codex 的原生权限体系处理；Workspace Safety 层只负责扩大或记录恢复覆盖范围，不成为新的权限引擎。

## 170.5 AI ChangeSet 是“撤销”的产品主对象

每个有 Workspace 副作用的 Run 结束后生成：

```text
WorkspaceChangeSet
├── created
├── modified
├── deleted
├── renamed
├── moved
├── metadataChanged
├── gitDiffRefs
├── binaryVersionRefs
├── agentId
├── runId
├── taskId
└── safetyPointRef
```

Explorer 可以直接提供：

```text
AI Changes · Run R-821

3 Modified
1 Created
0 Deleted

[View Diff]
[Revert Selected]
[Revert Run]
[Create Checkpoint]
```

ChangeSet 来自 Git / Provider snapshot diff / watcher evidence / operation journal 的组合，而不是模型自己描述“我改了这些文件”。

## 170.6 “Revert AI Run” 不能粗暴恢复整个目录

最危险的场景：

```text
10:00 AI 修改 router.rs
10:10 用户手工又修改 router.rs
10:20 用户点击“撤销 AI 修改”
```

禁止直接把 10:00 前的文件覆盖回来，否则会把用户 10:10 的工作一起删掉。

文本 / Git 文件优先采用：

```text
Base Before AI
     +
AI Result
     +
Current Version
     ↓
Three-way inverse apply
```

结果：

```text
CLEAN_REVERT
CONFLICT
PARTIAL
BLOCKED
```

发生冲突时展示 Diff / Merge UI，由用户处理。

## 170.7 二进制文件必须采用更保守的回退规则

对于：

```text
.blend
.psd
.prproj
大型视频
模型文件
压缩包
数据库文件
```

通常不存在安全的语义三方 merge。

规则：

```text
如果 current revision == AI result revision
→ 可直接恢复 pre-image / snapshot

如果 AI 后用户又修改
→ 禁止静默覆盖
→ 提供 Restore as Copy / Compare Metadata / Keep Current
```

例如：

```text
scene.blend

AI version        v18
Current version   v19 (human changed)
Safety point      v17

[保留当前]
[把 v17 恢复为副本]
[查看版本历史]
```

## 170.8 Workspace Trash

Explorer 的普通 Delete 和 Workbench 自己发起的删除默认进入 Workspace Trash / Provider Trash，而不是立即永久删除。

记录：

```text
original ResourceRef
original path
trash location / provider version
actor
run / task
deletedAt
retention
```

对于 Runtime 内部直接执行 `rm` 等命令，是否允许仍由 Harness 原生 permission / sandbox 决定；如果 Run Safety Point 覆盖该路径，则仍可从 Safety Point 恢复。Workbench 不通过重写权限系统强制劫持所有删除命令。

## 170.9 Operation Journal

Explorer 自己执行的文件操作必须具备明确逆操作：

```text
rename A -> B
inverse: rename B -> A

move A -> folder/B
inverse: move folder/B -> A

create folder X
inverse: remove X if still empty / unchanged

trash file A
inverse: restore A
```

Operation Journal 适用于：

```text
Explorer 操作
Workbench 批处理
Upload / Download finalization
AI 通过 Workbench Workspace API 发起的显式资源操作
```

不假装能完整记录 Runtime 在 shell 内部发生的每一个任意系统调用；这类执行依靠 Git / Safety Point / native snapshot 提供更可靠的 run-level recovery。

## 170.10 Explorer 中的版本体验

Windows Explorer 风格 UI 上叠加：

```text
右键文件
├── Open
├── Rename
├── Delete
├── ...
├── AI Activity
├── View Changes
├── Version History
└── Restore
```

Preview / Details Pane 可显示：

```text
VERSION HISTORY

v19  Current · Human
v18  Codex · Run R-821
v17  Safety Point
v16  Human

[Compare]
[Restore as New Revision]
```

“Restore”默认生成新 revision / 新 change event，不篡改审计历史。

## 170.11 Undo 与 Restore 分成两个用户语义

```text
Undo
= 撤销最近一个明确 Workspace Operation

Revert AI Changes
= 逆向应用某个 Agent / Run 的 ChangeSet

Restore Version
= 从资源历史恢复一个指定版本

Restore Workspace Safety Point
= 高风险、较粗粒度恢复
```

不能全部用一个“撤销”按钮表达。

## 170.12 Rollback Receipt

任何恢复动作生成：

```text
RollbackReceipt

requestedBy
workspaceId
sourceSafetyPoint
sourceChangeSet
resourcesAffected
cleanReverted
conflicts
skipped
newRevisionRefs
startedAt
completedAt
```

因此以后可以追踪：

```text
AI 改了什么
谁撤销了
哪些恢复成功
哪些文件有冲突
最后形成了哪个版本
```

## 170.13 大文件版本策略必须受空间预算约束

不能为了“可撤销”无上限保存：

```text
10 × 80GB video
```

版本存储必须有：

```text
retention days
max bytes
max versions per resource
protected / pinned safety points
LRU / age eviction
minimum free disk threshold
```

优先级：

```text
Pinned User Checkpoint
> Active Run Safety Point
> Recent AI Change
> Generic old history
```

当磁盘空间不足时，必须先提示和降级 rollback coverage，而不是把系统盘写满。

## 170.14 Rollback Coverage 必须可见

Run 开始前 / 运行中可以显示轻量状态：

```text
Recovery
● Full       Git worktree
● Full       Btrfs snapshot
◐ Partial    selected write set backed up
○ None       provider has no version support
```

尤其对于大型二进制文件，用户必须在真正执行前知道：

> “这次 Agent 修改能否完整恢复？”

而不是出事以后才发现没有备份。

---

# 171. Git AI Review + Recovery 的完整闭环

代码工作建议形成：

```text
Base Commit
   ↓
Agent Worktree
   ↓
Implement
   ↓
Tests / Lint
   ↓
AI Review
   ↓
Repair
   ↓
Re-review
   ↓
Human / Policy Gate
   ↓
Merge
```

如果 Review 失败：

```text
Repair Task
```

如果用户不接受整次 AI 实现：

```text
Discard Worktree
```

即可回到 Base，通常比“把几十个文件一个个反向修改”更安全、更快。

因此对 Git Repo：

> **Isolation first, revert second。**

这也是代码类 Workspace 默认采用 worktree / branch 的重要理由。

---

# 172. 非 Git Workspace 的恢复等级

为了避免夸大能力，定义：

```text
R3 — FULL_VERSIONED
原生 snapshot / provider versioning，可完整恢复

R2 — TARGETED_PREIMAGE
已对声明 write set 保存 pre-image，可恢复覆盖区域

R1 — OPERATION_ONLY
只能撤销 Workbench 已记录的 rename/move/trash 等操作

R0 — OBSERVE_ONLY
只知道发生变化，但没有可靠旧版本
```

Workspace / Run UI 可展示：

```text
Recovery Level: R2
```

而不是统一显示一个虚假的“Undo available”。

---

# 173. 第一阶段实现优先级

Phase 1 不追求一次解决所有文件系统：

```text
Git Repo
→ worktree + diff + discard/revert

Explorer operation
→ operation journal + trash

Small/medium non-Git files
→ targeted pre-image

Large binary
→ detect native CoW/version provider
→ if unavailable, explicit partial/no coverage
```

第二阶段再增加：

```text
Btrfs snapshot provider
ZFS snapshot provider
reflink provider
remote object version provider
NAS snapshot adapters
binary-specific version integrations
```

这样第一版就有真实可靠的恢复能力，同时不为了“万能撤销”做一个高复杂度、低可信度的新文件系统。

---

# 174. Decision Log — v0.26 Workspace Safety / Undo / Snapshot

## D-218 — Workspace 回退采用 Native Versioning First

**决定：** Git、Btrfs/ZFS、reflink、对象版本、NAS snapshot 等原生机制优先；Workbench 负责 Provider 抽象、Safety Point、ChangeSet、UI 与审计，不重新实现通用版本文件系统。  
**状态：** Accepted

## D-219 — 每个有写副作用的 Agent Run 尽可能创建 Safety Point

**决定：** Scheduler 根据 Workspace Provider 能力与 Task `writeIntent` 创建 Run Safety Point；不默认复制整个 Workspace。  
**状态：** Accepted

## D-220 — Git Repo 默认 Isolation First

**决定：** AI 写代码优先使用 worktree / branch 隔离；不接受结果时直接丢弃隔离工作区，Review / Repair / Merge 在独立分支完成。  
**状态：** Accepted

## D-221 — AI ChangeSet 是撤销与审计的正式对象

**决定：** Workbench 从 Git / snapshot diff / operation evidence 构建 `WorkspaceChangeSet`，记录 created/modified/deleted/moved 与 Agent/Run/Task provenance。  
**状态：** Accepted

## D-222 — Revert AI Run 不得覆盖后续 Human Change

**决定：** 文本优先三方 inverse merge；存在冲突时进入 Merge UI。二进制文件若后续被修改，禁止静默覆盖。  
**状态：** Accepted

## D-223 — 删除默认走 Trash，Runtime 原生权限保持原样

**决定：** Explorer / Workbench 自身删除默认 Trash；Runtime shell 删除不通过 Workbench 新权限层劫持，依赖 Harness 原生权限以及 Run Safety Point 恢复。  
**状态：** Accepted

## D-224 — Operation Journal 只承诺记录可观察 / 可控制的操作

**决定：** Explorer、Workspace API、Transfer finalization 等进入 Operation Journal；任意 Runtime 内部系统调用不伪装成逐操作可逆，使用 run-level snapshot / Git recovery。  
**状态：** Accepted

## D-225 — Rollback Coverage 必须显式显示

**决定：** 每个 Workspace / Run 以 Full / Partial / None 或 R3-R0 明确展示可恢复等级，尤其大型二进制资源不得默认承诺可完全撤销。  
**状态：** Accepted

## D-226 — Version / Snapshot 存储必须受空间预算和 Retention 管理

**决定：** Safety Point / pre-image / binary version 全部受 TTL、空间预算、pin、free-space pressure 管理；不得为了历史版本耗尽本地磁盘。  
**状态：** Accepted

## D-227 — Restore 形成新历史，不静默改写旧历史

**决定：** 恢复动作生成新的 resource revision / change event / RollbackReceipt；保留被恢复版本与恢复原因的可追溯关系。  
**状态：** Accepted


---

# 175. Agent 必须继续坚持 Definition 与 Instance 分离

这一轮不把 Agent 设计成“一个 Prompt 文件”。正式对象仍然是：

```text
Agent Definition
= 可复用、可版本化、可安装的 Agent 模板

Agent Instance
= 某个用户真正创建出来、长期存在的 AI 个体
```

因此：

```text
同一个 Definition
“高级 Python 架构师”

        │ install
        ├───────────────┐
        ▼               ▼
User A Agent         User B Agent
ag_A_013             ag_B_044
Memory A             Memory B
```

两者可以拥有相同的初始 Instructions / Skills / Plugin Requirements，但一旦实例化，就拥有不同：

```text
agentId
memoryNamespaceId
Agent Owner
Agent-level Model Policy
Agent-level Skill Preference
Agent-level UI / Persona settings
Lifecycle state
Runtime history
Private Memory
```

**Definition 可以共享；Instance 与 Private Memory 默认不共享。**

---

# 176. Agent Package：安装的是“定义与依赖声明”，不是一颗现成共享大脑

建议 Agent Definition 采用可审计 Package：

```text
agent-package/
├── agent.yaml
├── instructions.md
├── skills.yaml
├── plugins.yaml
├── runtime-policy.yaml
├── model-policy.yaml
├── memory-policy.yaml
├── workspace-policy.yaml
├── ui-metadata.yaml
├── compatibility.yaml
├── LICENSE
├── NOTICE
└── signatures/
```

其中：

```text
agent.yaml
→ id / name / version / description / author / categories

instructions.md
→ Agent Definition 的稳定行为与职责说明

skills.yaml
→ 需要 / 推荐 / 可选 Skills

plugins.yaml
→ 需要 / 推荐 / 可选 Plugins

runtime-policy.yaml
→ Runtime compatibility / preference，不写死当前 Binding

model-policy.yaml
→ Auto / recommended capability requirements / allowed model classes

memory-policy.yaml
→ Core Memory template、capture policy、retention hints

workspace-policy.yaml
→ 需要哪些 Workspace capability，不代表授予权限

compatibility.yaml
→ Workbench / Runtime / Skill / Plugin / OS capability requirements
```

Package 可以带 **Core Memory Seed / Initial Knowledge Seed**，但必须标成：

```text
SEED
```

而不是伪装成该 Agent 已经“亲身经历过的 Private Memory”。

安装时：

```text
Definition Seed
      ↓
New Agent Instance
      ↓
New Private MemorySpace
```

之后形成的 Episodic / Lesson / Preference 等长期经验只属于这个 Instance。

---

# 177. Agent Library 是本地产品入口，Marketplace 是未来来源之一

Workbench 第一版不需要先做公共市场服务器。先做：

```text
Agent Library
```

用户看到的是：

```text
My Agents
Installed Definitions
Local Packages
Team Catalog（未来/可选）
Marketplace（未来/可选）
```

因此来源与本地实例分开：

```text
Source
├── Built-in
├── Local Package
├── Git / URL Package（未来）
├── Team Catalog
└── Public Marketplace

          ↓ install

Installed Agent Definition

          ↓ create

Agent Instance
```

即使未来 Marketplace 下线，已经创建的 Agent Instance 与它的 MemorySpace 仍然可以继续存在。

**Marketplace 不是 Agent 身份真源。**

---

# 178. Create Agent：从空白、模板、现有 Definition 创建

用户创建 Agent 至少有三条路径：

```text
Create from Blank
Create from Installed Definition
Create from Existing Agent Definition
```

创建向导第一阶段不应该暴露几十项底层配置，而先确认：

```text
Name
Role / Purpose
Work Profile
Model Policy: Auto / Manual default
Recommended Skills / Plugins
Memory Seed preview
```

高级设置再展开：

```text
Runtime compatibility
Skill routing preference
Plugin dependencies
Memory capture policy
Workspace defaults
UI metadata
```

创建完成时 Workbench 原子生成：

```text
agentId
memoryNamespaceId
instanceRevision = 1
Definition Binding
Owner Binding
```

如果其中 Memory Namespace 创建失败，则 Agent Instance 不进入 ACTIVE，避免出现“有 Agent 身份但没有自己的记忆域”的半成品状态。
---

# 179. Agent Instance Overlay：允许个体成长，但不污染上游 Definition

同一个 Definition 被安装后，用户可能修改：

```text
名称
头像
Persona
Agent Instructions 补充
Model Policy
Skill Preference
Plugin enable/disable
Core Memory
```

不能直接改掉公共 Definition。

因此采用：

```text
Effective Agent
=
Definition Revision
+
Instance Overlay
+
Agent Private Memory
+
Current Runtime / Model Binding
```

例如：

```text
Definition v3
“默认使用 architecture-analysis Skill”

Instance Overlay
“在当前 Agent 中更偏好 repo-analysis”

Private Memory
“在 Project X 中 repo-analysis 对 Rust monorepo 更有效”
```

三者是不同层，不应互相覆盖成一份无法追踪来源的 Prompt。

---

# 180. Agent 升级：升级 Definition，绝不自动覆盖 Private Memory

Agent 的 Definition 从：

```text
v2.4
→
v2.5
```

升级时：

```text
Agent Identity      不变
agentId             不变
memoryNamespaceId   不变
Private Memory      不变
Runtime history     不变
```

变化的是：

```text
Definition Binding Revision
Instructions
Skill / Plugin requirements
Compatibility metadata
Default policies
```

升级前必须生成：

```text
AgentDefinitionDiff
```

例如：

```text
v2.5 changes

+ 推荐 skill: security-audit
+ requires plugin: repo-security >= 1.4
~ instructions: review policy changed
~ model requirement: context >= 64k
- deprecated skill: legacy-review
```

如果升级引入新的插件、Runtime 或权限要求，则继续使用对应 Runtime / Plugin 的原生安装与批准流程，不因“Agent 更新”而静默获得能力。

---

# 181. Definition Upgrade 与 Core Memory 冲突必须可见

最危险情况不是升级失败，而是：

```text
New Definition
要求：优先使用 Rule A

Agent Core Memory
已有：长期使用 Rule B
```

不能简单把两者拼进 Context 后让模型猜。

升级时做：

```text
Definition / Core Compatibility Check
```

结果：

```text
Compatible
Conflict
Needs Review
```

如果冲突：

```text
Agent Update requires review

Definition now says:
A

Agent Core Memory says:
B

[Keep Agent Memory]
[Adopt New Definition]
[Edit Both]
[Postpone Update]
```

任何选择都产生 Revision / provenance。

---

# 182. Clone 与 Fork 必须区分

“复制 Agent”至少有两种完全不同的意图。

## Clone Definition

默认、安全：

```text
Agent A
     ↓
Clone Definition
     ↓
Agent B
new agentId
new memoryNamespaceId
empty / seeded private memory
```

适合：

> “我喜欢这个 Agent 的配置，再创建一个新的。”

## Fork with Memory Snapshot

高级、显式：

```text
Agent A
     ↓
Memory Snapshot @ revision 842
     ↓
Agent B
new agentId
new memoryNamespaceId
copied snapshot
lineage = Agent A
```

这不是两个 Agent 共用同一个 MemorySpace。

从 Fork 完成之后：

```text
Memory A
        ≠
Memory B
```

后续各自成长。

UI 必须明确提示“将复制哪些私人记忆”，并允许排除 Preference / sensitive / episodic 等类别。

---

# 183. Agent 导入 / 导出必须分成 Definition 与 Instance Snapshot

默认 Export：

```text
Export Agent Definition
```

只导出：

```text
Instructions
Skill / Plugin declaration
Runtime / Model policy
Memory policy
UI metadata
```

**默认不导出 Private Memory。**

如果用户显式执行：

```text
Export Agent Instance Snapshot
```

才允许包含：

```text
Definition revision
Instance overlay
Selected private memory snapshot
Memory lineage metadata
```

导出前必须展示：

```text
Private Data Included
```

并支持按 Memory type / sensitivity 排除。

Credential、API Key、Runtime secret、Workspace absolute secret path 永远不打包到可移植 Agent Package。

---

# 184. Agent Dependency Resolver：Agent 不直接安装任何东西

Definition 只声明：

```text
requires
recommends
optional
```

例如：

```text
requires:
- skill: code-review >= 2
- runtime-capability: repo-write

recommends:
- plugin: repo-tools >= 1.4

optional:
- skill: security-audit
```

Workbench 的 Agent Dependency Resolver 负责：

```text
Resolve installed capability
→ check version
→ check compatibility
→ check Runtime/Model availability
→ show missing dependencies
```

Agent Definition 自己不能偷偷执行：

```text
curl ... | sh
npm install -g ...
```

真正的 Plugin / Skill 安装继续走我们已经确定的 Plugin Host / Runtime-native extension 路径。

---

# 185. Agent Compatibility Projection

每个 Agent Definition / Instance 都维护一份增量投影：

```text
AgentCompatibilityProjection
```

例如：

```text
Architect Agent

Definition       ✓
Memory           ✓
Runtime          ✓ DeepSeek / ✓ Codex
Models           4 compatible
Skills           12 / 13 available
Plugins          5 / 5 active
Workspace        not required
Overall          READY
```

或者：

```text
Video Agent

Model            ✕ no video-capable model
Plugin           ◐ media-index disabled
Overall          DEGRADED
```

这样 Agent 首页不需要每次重新扫描所有 Registry。

---

# 186. Agent Library / Agent Detail UI

用户打开某一个 Agent，应可以直接看到：

```text
Architect Agent
● READY

[Chat] [Continue Work]

Identity
Memory
Skills
Plugins
Model
Runtime
Activity
Usage
Versions
Settings
```

其中首页优先展示：

```text
它是谁
最近在做什么
Memory 状态
当前 Model Policy
关键 Skills
当前 Runtime 健康
最近活动
```

不应该一打开就把大量开发参数全部铺满。

Developer / Admin 再进入 Agent Studio / Glass Box。

---

# 187. Marketplace / Team Catalog 的对象不是 Agent Instance

未来公共市场或团队目录发布的是：

```text
Agent Definition Package
```

绝不发布：

```text
正在运行中的某个用户 Agent Instance
```

Marketplace 页面可以展示：

```text
Name
Purpose
Author
Definition Version
Compatible Workbench Version
Required Skills / Plugins
Runtime / Model Requirements
License
Signature / Trust
Update history
Usage / rating（未来）
```

安装流程：

```text
Marketplace Definition
       ↓
Verify package
       ↓
Install Definition
       ↓
Review dependencies
       ↓
Create Local Agent Instance
       ↓
Allocate Private MemorySpace
```

因此“下载了同一个 Agent”并不意味着两个用户下载的是同一个长期人格。

---

# 188. Trust / Signature / License 是 Agent Package 的硬元数据

第三方 Agent 可能要求：

```text
Plugins
Skills
Runtime capabilities
Workspace access
```

所以 Package 至少要有：

```text
source
publisher
signature status
license
hash
version
requested dependencies
```

建议 Trust 状态：

```text
BUILT_IN
VERIFIED
SIGNED
UNVERIFIED
LOCAL_DEV
BLOCKED
```

Trust 影响的是：

```text
安装提示
依赖自动化程度
默认启用策略
更新策略
```

但不绕过 Runtime 自己的权限体系。

---

# 189. Agent Update Channel 与 Last-Good Definition

Agent Definition 更新也采用：

```text
Stable
Beta
Pinned
Manual
```

升级失败时：

```text
Definition v5 stage
→ dependency check failed
→ keep v4 active
```

即：

> **Last-Good Definition。**

已经存在的 Agent 不因为 Marketplace / Catalog 的新版本错误而无法继续运行。

对于正在执行的 Run：

```text
Run captures Definition Revision at start
```

Run 中途不自动切 Definition。

新 revision 默认从下一个 Turn / Run 的安全边界生效；如果改变 Core behavior / Skill graph / Plugin requirements，则优先从下一个 Run 生效。

---

# 190. Agent 删除采用 Archive-first，不做“一键永久消失”

删除 Agent 的默认路径：

```text
ACTIVE
→ DISABLED
→ ARCHIVED
→ retention window
→ optional export
→ PURGED
```

Archive 后：

```text
不再被 Router / Room 自动激活
不再接收新 Task
MemorySpace 冻结为只读
历史 Run / Conversation / provenance 仍可打开
```

真正 Purge 时才处理：

```text
Private Memory
Local derived cache
Agent-specific index
```

Project shared artifacts / Workspace 文件不能因为 Agent 被删除而级联删除。

---

# 191. Personal Primary Agent 也是 Agent Instance，但有系统级产品约束

Personal Primary Agent 不需要另做一套底层模型。

它仍然是：

```text
Agent Instance
+
Private MemorySpace
+
Model Policy
+
Skills / Plugins
```

只是额外具有：

```text
isPrimary = true
```

产品约束：

```text
每个用户默认至少一个 Primary Agent
Primary Agent 可以更换
不能在没有替代者时直接 Purge 当前 Primary
```

这样 Personal Agent 与普通专业 Agent 共享同一底层架构，不制造两套系统。

---

# 192. 第一阶段实施：不要先做公共 Marketplace

建议实现顺序：

```text
Phase 1
Agent Registry
Definition / Instance
Create / Archive
Private Memory binding
Model Policy
Skill / Plugin binding

Phase 2
Local Agent Package
Import / Export Definition
Clone Definition
Definition Diff / Upgrade

Phase 3
Fork with Memory Snapshot
Compatibility Projection
Agent Studio / Version History

Phase 4
Team Catalog
Signed packages
Update channel

Phase 5
Public Marketplace
Ratings / publisher verification / discovery
```

这能先证明“Agent 个体生命周期”正确，再增加内容分发系统。

---

# 193. Decision Log — v0.27 Agent Lifecycle / Package / Marketplace

## D-228 — Agent Definition 与 Agent Instance 永久分离

**决定：** Definition 是可复用模板；Instance 是具有稳定 `agentId`、独立 Private MemorySpace、个体配置与运行历史的长期实体。  
**状态：** Accepted

## D-229 — Agent Package 默认不携带个人长期记忆

**决定：** Package 可提供 Memory Seed / Core Seed，但默认不得携带某个已有 Agent 的 Private Episodic / Preference / Lesson 等长期经验。  
**状态：** Accepted

## D-230 — Agent Instance Overlay 不反向污染上游 Definition

**决定：** Agent 个体的 Persona、Model Policy、Skill Preference、Core Memory 修订等存储于 Instance Overlay / MemorySpace，上游 Definition 保持独立版本链。  
**状态：** Accepted

## D-231 — Definition Upgrade 不修改 Agent Identity / MemorySpace

**决定：** 升级只更换 Definition Binding revision；`agentId`、`memoryNamespaceId`、Private Memory 与历史不变。  
**状态：** Accepted

## D-232 — Definition 与 Core Memory 冲突必须显式处理

**决定：** Agent 升级执行 Definition/Core compatibility check；冲突不得静默拼接进入 Context。  
**状态：** Accepted

## D-233 — Clone Definition 与 Fork Memory 是两个不同操作

**决定：** 默认 Clone 仅复制 Definition / configuration 并分配全新空白 MemorySpace；复制 Private Memory 必须使用显式 Fork with Memory Snapshot，并生成独立 namespace lineage。  
**状态：** Accepted

## D-234 — Agent 导出默认只导出 Definition

**决定：** Private Memory 仅在显式 Instance Snapshot 导出时包含；Credential、Secret、可复用 API Key 永远不打包。  
**状态：** Accepted

## D-235 — Agent Dependency 只声明，不自行安装

**决定：** Definition 通过 `requires/recommends/optional` 声明 Skill / Plugin / Runtime capability；实际解析与安装由 Workbench Registry / Plugin Host / Runtime-native extension 流程执行。  
**状态：** Accepted

## D-236 — Marketplace 发布 Definition，不发布用户 Agent Instance

**决定：** Public Marketplace / Team Catalog 的发布单位是 Agent Definition Package；安装后本地创建新的 Agent Instance 与新的 Private MemorySpace。  
**状态：** Accepted

## D-237 — Agent Package 必须携带 Trust / Signature / License 元数据

**决定：** 第三方 Package 必须记录来源、publisher、hash、signature、license、version 与 dependency 声明；Trust 影响安装 / 更新提示，但不绕过 Harness 原生权限。  
**状态：** Accepted

## D-238 — Agent Definition 使用 Last-Good 与安全更新边界

**决定：** 更新先 Stage / Validate，再切换；失败继续运行上一版本。正在执行的 Run 固定其启动时 Definition Revision，不在中途隐式升级。  
**状态：** Accepted

## D-239 — Agent 删除采用 Archive-first

**决定：** 默认 Disable / Archive / Retention / Purge；Archive 不级联删除 Project shared data 或 Workspace 资源。  
**状态：** Accepted

## D-240 — Personal Primary Agent 复用统一 Agent Instance 架构

**决定：** Personal Primary Agent 不单独实现第二套 Agent 内核；它是带 `isPrimary` 产品约束的普通 Agent Instance。  
**状态：** Accepted


---

# 194. Agent Team / Agent Room：多 Agent 协作对象正式分层

随着 Agent Instance、独立 MemorySpace、Skill / Plugin、Model Policy、Workspace 与 Scheduler 都已经定义，下一步不能把多 Agent 协作简单实现成“几个机器人都加入一个群聊”。

正式区分四个对象：

```text
Agent Team
= 可复用的 Agent 组合 / 角色配置

Agent Room
= 人和 Agent 的可视沟通与协作空间

Work Item / Task Graph
= 真正工作的状态、依赖、负责人和完成条件

Handoff
= Agent / Runtime 之间正式的工作转移
```

因此：

```text
Room ≠ Task Graph
Room ≠ Shared Memory
Team ≠ Shared Brain
Chat Message ≠ Task State
```

Room 可以把 Task / Handoff / Decision / Artifact 以卡片方式投影出来，但不能反过来把群聊消息当成工作的唯一真源。

---

# 195. Agent Team 是“可复用编组”，不是新的 Agent

建议：

```ts
interface AgentTeam {
  teamId: string
  name: string
  ownerUserId: string
  members: TeamMember[]
  defaultRoomPolicyId?: string
  defaultBudgetPolicyId?: string
  createdAt: string
  status: 'active' | 'archived'
}

interface TeamMember {
  agentId: string
  roleLabel?: string
  participation: 'on-demand' | 'auto-eligible' | 'review-only' | 'observer'
  priority?: number
}
```

示例：

```text
产品开发 Team

Product Agent
role = Product

Architect Agent
role = Architecture

Coding Agent
role = Engineering

Reviewer Agent
role = Review
```

这里的 `roleLabel` 是当前 Team 中的协作角色，不改变 Agent Identity，也不创建新的 Memory。

同一个 Architect Agent 可以加入多个 Team，但始终只有自己的 Private MemorySpace。

Team 本身不拥有：

```text
Shared Agent Memory
独立 Runtime
独立 Task Truth
```

Team 的主要作用是：

```text
快速复用一组 Agent
+ 默认角色
+ 默认参与规则
+ 默认成本/并发策略
```

第一版甚至可以先只有“保存为 Team”能力，不必立即建设复杂的 Team Marketplace。

---

# 196. Agent Room 是协作表面，不是强制工作容器

Room 可以包含：

```text
Human User
Human Teammates
Agent A
Agent B
Agent C
```

但不是所有任务都必须建 Room。

例如：

```text
Personal Agent
  ↓
直接委派一个 Coding Task 给 Codex Agent
```

完全可以没有群聊。

当用户确实需要：

```text
讨论
多角色意见
现场协作
Review
Handoff
可视化多 Agent 过程
```

才进入 Room。

建议模型：

```ts
interface AgentRoom {
  roomId: string
  title: string
  projectId?: string
  workItemId?: string
  teamId?: string
  roomPolicyId: string
  createdBy: string
  createdAt: string
  status: 'active' | 'archived'
}
```

Room 可以绑定 Work Item，也可以只是一次临时讨论。

---

# 197. 多 Agent 最危险的问题：不能让所有 Agent 对每条消息都响应

假设 Room 有 30 个 Agent。

用户发一句：

```text
这个方案有什么风险？
```

错误实现：

```text
30 Agents
  ↓
30 Model Calls
  ↓
30 Memory Recall
  ↓
30 Responses
```

这会造成：

```text
成本爆炸
延迟爆炸
上下文爆炸
UI 噪声
Agent 相互触发形成聊天风暴
```

因此正式引入：

# Room Participation Router

它是确定性的参与者选择 / 排队组件，不实现新的 Agent Loop。

默认规则优先级：

```text
1. 用户明确 @Agent
   → 只向被点名 Agent 创建 Turn Request

2. Task / Handoff 已明确负责人
   → 负责人进入执行 / 回答资格

3. Room Policy 指定 Reviewer / Facilitator
   → 满足触发条件才进入

4. 用户没有点名
   → 自动选择最相关的 1 个 Agent

5. 只有用户显式要求 Panel / 多意见
   → 才允许多个 Agent 同轮响应
```

最关键原则：

> **Agent Message 默认不会自动触发其他 Agent 发言。**

否则 A 回复 B、B 回复 C、C 再回复 A，会形成无法控制的 Agent-to-Agent 对话循环。

---

# 198. RoomTurnRequest：Agent 发言必须是一个显式调度事件

建议新增：

```ts
interface RoomTurnRequest {
  requestId: string
  roomId: string
  agentId: string

  trigger:
    | 'user_mention'
    | 'user_room_message'
    | 'task_assignment'
    | 'handoff'
    | 'review_policy'
    | 'panel'
    | 'facilitator'

  sourceEventId: string
  objective?: string
  contextRefs: string[]
  priority: number

  status:
    | 'queued'
    | 'running'
    | 'completed'
    | 'cancelled'
    | 'blocked'
}
```

Room Controller 只负责：

```text
谁有资格发言
谁排队
谁正在执行
是否超过发言/并发/预算限制
```

真正进入 Agent Turn 时仍然执行：

```text
beforeTurnMemory()
→ Context Package
→ Runtime + Model
→ afterTurnMemory()
```

因此 Room Controller 不是第三套 Harness。

---

# 199. Room Participation Mode

建议至少提供四种模式：

```text
DIRECTED
用户主要通过 @Agent 点名；未点名时由默认 Agent / Facilitator 处理。

AUTO
未点名时 Participation Router 自动选择最合适的一个 Agent。

PANEL
用户显式要求多个 Agent 独立回答，可并行收集意见。

WORKFLOW
参与者主要由 Task Graph / Handoff / Review Policy 驱动，不要求每一步都发聊天消息。
```

默认推荐：

```text
AUTO
+ 单 Agent 自动响应
+ @Agent 精确覆盖
```

不要默认 Panel。

Panel 应是明确动作，例如：

```text
Ask Panel
Architect + Product + Reviewer
```

而不是 Room 中有几个人就全员回答。
