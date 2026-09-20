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
