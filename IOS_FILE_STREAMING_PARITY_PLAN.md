# iOS File Streaming Parity Plan (Android -> iOS)

This document defines the implementation approach for bringing Android file-streaming stability changes to iOS with the same behavior and safety guarantees.

## Goal

Implement iOS file streaming flow with parity for:
- timeout/recovery tuning
- retry and cooldown control
- py_msg purpose scoping (race/loop prevention)
- corruption detection and re-confirmation strategy
- upload/remove behavior consistency

## Implementation Strategy

- Use **Phase-wise rollout** (safe by default).
- Keep each phase independently testable.
- Enable remove (`rm_file`) only in final phase after validation.
- Prefer feature parity first, then iOS-specific optimizations.

## Master Checklist

- [ ] Phase 1 complete
- [ ] Phase 2 complete
- [ ] Phase 3 complete
- [ ] Phase 4 complete
- [ ] Phase 5 complete
- [ ] Phase 6 complete
- [ ] Phase 7 complete
- [ ] Phase 8 complete
- [ ] Phase 9 complete
- [ ] QA matrix complete
- [ ] Definition of done complete

## Phase Plan

### Phase 1 - Core Timing and Retry Foundation (Do First)

Implement:
- [x] `STREAM_FILE_TIMEOUT_MS = 60000`
- [x] `FILE_STREAMING_RECOVERY_INTERVAL_MS = 120000`
- [ ] `MAX_FILE_STREAM_RETRIES = 2`
- [ ] `fileStreamRetryCounts[fileNo]` tracking

Expected outcome:
- iOS streaming does not fail prematurely.
- Retry count is maintained per file.

Acceptance checks:
- [ ] Stream timeout triggers only after 60s.
- [ ] Recovery loop runs at 120s interval.
- [ ] A file retries max 2 times before fallback path.

---

### Phase 2 - Anti-Race / Anti-Loop State Controls

Implement:
- [ ] `isFileStreamCooldownActive`
- [ ] `lastPyMsgPurpose` with allowed values: `"get_files"` or `"stream_file"`

Expected outcome:
- Recovery and retry flows do not overlap.
- py_msg responses are interpreted only in correct context.

Acceptance checks:
- [ ] During cooldown, recovery does not re-trigger stream flow.
- [ ] `lastPyMsgPurpose` changes correctly on each py_msg enqueue/response.

---

### Phase 3 - Shared Helper Methods (Critical Refactor)

Implement helpers:
- [ ] `cancelAllFileStreamingTimers()`
  - [ ] cancel stream timeout
  - [ ] stop recovery timer
  - [ ] cancel delayed next-file runnable/task
  - [ ] cancel get_files timeout runnable/task
  - [ ] reset cooldown flag
- [ ] `enqueuePyMsg(purpose)`
  - [ ] set `lastPyMsgPurpose`
  - [ ] send py_msg
- [ ] `scheduleRetryCurrentFileAfterDelay(fileNumber, retryCount)`
  - [ ] wait cooldown
  - [ ] retry same file
  - [ ] prevent overlap with recovery during cooldown
- [ ] `handleCurrentFileStreamFailure(reason)`
  - [ ] single failure entry point
  - [ ] retry up to max
  - [ ] on exceed: prepare remove + move next/previous according to current iOS flow

Expected outcome:
- Timeout/error handling logic is centralized and predictable.

Acceptance checks:
- [ ] All failure paths (timeout/error/corruption policy outcome) pass through common handlers.
- [ ] No duplicated timer-cancel code remains in iOS streaming module.

---

### Phase 4 - Timer Cancellation / Reset Wiring

Apply helper usage at control points:
- Before each new stream request:
  - [ ] `startFileStreaming()` calls `cancelAllFileStreamingTimers()`
  - [ ] `requestNextFile()` calls `cancelAllFileStreamingTimers()`
- On stop:
  - [ ] `stopFileStreaming()` calls `cancelAllFileStreamingTimers()`
  - [ ] clear `fileStreamRetryCounts`
- Recovery restart guard must include:
  - [ ] `!isFileStreamCooldownActive`

Expected outcome:
- No stale timers survive between file transitions.
- Retry cooldown is respected globally.

Acceptance checks:
- [ ] Starting/stopping repeatedly does not spawn duplicated timers.
- [ ] Recovery timer cannot race retry timer while cooldown active.

---

### Phase 5 - py_msg Error Interception Fix (Second-File Skip Fix)

Implement stream-error interception condition for `ERROR py_msg` only when all are true:
- [ ] currently waiting for stream response
- [ ] stream response time window is valid
- [ ] `lastPyMsgPurpose == "stream_file"`

Also:
- [ ] clear `lastPyMsgPurpose` on valid stream response/error transitions
- [ ] all get_files retries must use `enqueuePyMsg("get_files")`

Expected outcome:
- Delayed get_files errors are not misclassified as stream-file failures.

Acceptance checks:
- [ ] Reproduce prior "second file skipped" scenario and confirm no skip.
- [ ] get_files retry errors do not trigger stream failure handler.

---

### Phase 6 - Corruption Detection Parity

Mark file as corrupted when any condition is true:
- [x] missing header row
- [x] first data packet session missing
- [x] unwanted characters detected

Unwanted characters include:
- [x] previous checks (`/`, `M`, `m`)
- [x] UTF replacement char `\uFFFD` (visual `�` / diamond question mark)

Packet-level rule:
- [x] if `receivedString` contains `\uFFFD`, mark unwanted/corrupted signal.

Expected outcome:
- iOS catches same corruption patterns as Android.

Acceptance checks:
- [ ] Synthetic payloads with each corruption type are flagged correctly.
- [ ] Clean payloads are never falsely marked as corrupted.

---

### Phase 7 - Corrupted File Retry + Upload Policy

At ETX:
- If file is corrupted:
  - [x] increment per-file attempt count
  - [x] attempt 1/2: no upload, retry same file after cooldown
  - attempt 2/2 still corrupted:
    - [x] upload/store with `corrupted_file = true`
    - [x] include `raw_data`
    - [x] prepare/remove file (send disabled during test mode)
    - [x] move to next/previous file according to iOS traversal
- If file is clean:
  - [x] upload immediately
  - [x] move to next/previous file normally

Implementation note:
- [x] Non-UTF8/decode-failure corrupted path now follows the same 2-attempt policy (first retry same file, second upload as corrupted + remove path + move next/previous).
- [x] Guard added to ignore incoming stream bytes during corrupted retry cooldown, so attempt 2 is counted only after an actual same-file retry request.
- [x] Corrupted upload with raw payload is allowed even when parsed entry snapshot is empty.
- [x] Hard guard added: `requestNextFile()` refuses to send `stream_file` while `isFileStreamingActive == true`.
- [x] `OK py_msg stream_file ...` is now ignored unless `waitingForStreamFileResponse == true` (prevents unrelated `py_msg` responses from affecting active stream state).

Expected outcome:
- Corrupted files are not dropped permanently.
- Diagnostics are preserved on confirmed corruption.

Acceptance checks:
- [ ] First corrupted attempt does not upload.
- [ ] Second corrupted attempt uploads with `corrupted_file=true` and `raw_data`.
- [ ] Clean file uploads immediately at ETX.

---

### Phase 8 - Raw Data Lifecycle Safety

- [ ] Fix ordering so raw buffer reset happens **after** upload/branch decision logic.

Expected outcome:
- Confirmed corrupted uploads always include correct raw payload.

Acceptance checks:
- [ ] On second failed corruption confirmation, backend payload includes non-empty `raw_data`.

---

### Phase 9 - rm_file Final Activation (After Validation)

Currently keep remove sends disabled during test cycle at both points:
- [ ] normal ETX success path (disabled in test mode)
- [ ] confirmed corrupted path after second failed attempt (disabled in test mode)

Final activation step:
- [ ] uncomment/enable remove send in both paths
- [ ] verify no duplicate remove command sends

Expected outcome:
- Normal and confirmed-corrupted files are removed exactly once.

Acceptance checks:
- [ ] Device file list decreases correctly after each completed file.
- [ ] No accidental remove for first corrupted attempt (retry stage).

## Parallelization Guidance

Safe to do in parallel:
- Phase 1 + initial constants plumbing in Phase 2
- Phase 3 helper scaffolding + unit-test scaffolding
- Phase 6 corruption detector implementation + test payload generation

Should be sequential:
- Phase 4 after Phase 3
- Phase 5 after Phase 2 + Phase 3
- Phase 7 after Phase 1 + Phase 6
- Phase 8 after Phase 7
- Phase 9 only after all QA sign-off

## Suggested Task Breakdown (Tickets)

- [ ] Ticket A: Timing/retry constants + per-file retry map
- [ ] Ticket B: Cooldown + py_msg purpose state
- [ ] Ticket C: Timer/retry/failure shared helpers
- [ ] Ticket D: Control-point rewiring (`start/requestNext/stop/recovery`)
- [ ] Ticket E: py_msg interception bug fix and regression test
- [ ] Ticket F: Corruption detector expansion (`\uFFFD` + packet-level)
- [ ] Ticket G: Corrupted retry-to-upload flow at ETX
- [ ] Ticket H: Raw data clear-order fix
- [ ] Ticket I: rm_file enablement (final release gate)

## QA Matrix (Must Pass Before rm_file Enable)

- [ ] Normal file success path upload and move flow
- [ ] Timeout retry path and max-retry fallback
- [ ] get_files retry delayed error does not break stream flow
- [ ] Second-file continuity regression case
- [ ] Corrupted first attempt retry (no upload)
- [ ] Corrupted second attempt upload with `corrupted_file=true` and `raw_data`
- [ ] Cooldown prevents recovery overlap
- [ ] Start/stop stress test with no orphan timers

## Definition of Done

- [ ] iOS behavior matches Android for all 10 listed change groups.
- [ ] Regression cases are reproducible and pass.
- [ ] rm_file remains disabled in test builds and enabled only in release-ready phase.
- [ ] Logs clearly show state transitions for retry/cooldown/purpose/corruption decisions.

