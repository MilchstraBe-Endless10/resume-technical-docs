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