# File Streaming — Planned Changes & Updates

This document describes **future** behavior we want for file streaming (not yet implemented). It builds on `FILE_STREAMING_CURRENT_APPROACH.md`.

---

## 1. Corrupted or empty file when `fileCheck == 1`

**Problem today:** The device can report that the file exists (`fileCheck == 1`), but the stream may still be unusable: empty payload, parse failures, missing header, or other integrity issues. Today we still advance to the next file after ETX.

**Desired behavior:**

- After a full stream for `fileNo` (we reached ETX or equivalent end-of-stream), evaluate whether the file was **successfully processed** (valid structure, non-empty meaningful data).
- On ETX finalization, persist data to internal storage first (upload can happen now or later).
- After ETX finalization and local persistence, send **`app_msg rm_file <fileNo>`** regardless of Firebase upload success, so device storage is cleared and cloud sync can continue from local pending data.
- If **`fileCheck == 1` but the file is corrupted, empty, or otherwise failed processing:**
  - **Do not** increment `currentFile`.
  - **Re-request** the same file: send `stream_file` again for the same `fileNo` (with bounded retries, e.g. max N attempts, to avoid infinite loops).
- If after retry (or after max attempts) the file is **still** corrupted or empty:
  - Send **`app_msg rm_file <fileNo>`** (and `py_msg` if the protocol requires it) to remove the bad file from the device, then **advance** to the next file.
- Optionally log or surface a metric so support can see “removed after repeated bad stream.”

**Pseudocode (retry + rm_file):**

```text
MAX_RETRY_SAME_FILE = 2   // example: 1 initial + 1 retry; tune with firmware/QA

onStreamComplete(fileNo, outcome):
  if outcome == OK:
    persistLocally(fileNo)
    enqueueRmFile(fileNo)         // always remove after ETX + local persist
    uploadNowOrQueueForLater()
    advanceToNextFile()
    return

  // Bad stream but device said file exists
  if fileCheckWas1 and (outcome == CORRUPT or outcome == EMPTY or outcome == PROCESS_FAILED):
    retryCount[fileNo]++
    if retryCount[fileNo] <= MAX_RETRY_SAME_FILE:
      resetStreamStateFor(fileNo)
      requestStreamFile(fileNo)   // same index, no advance
    else:
      enqueueRmFile(fileNo)
      clearRetry(fileNo)
      advanceToNextFile()
    return

  // Missing / other paths unchanged from product spec
  handleMissingOrError(...)
```

---

## 2. Delays today — clearer explanation, and goal to remove them

**Why delays exist now (plain language):**

| What | Typical constant / value | Role |
|------|---------------------------|------|
| **Post-file gap** | ~7 s (`FILE_STREAMING_DELAY_MS`) | After ETX (or after treating a file as “done” / missing), wait before asking for the **next** file so the BLE stack and Leo firmware are not hammered back-to-back. |
| **Stream response wait** | ~10 s (`STREAM_FILE_TIMEOUT_MS`) | After sending `stream_file`, if there is no acceptable response in time, the app treats the request as stuck and applies **timeout handling** (advance or retry — current code picks one path). |
| **Recovery tick** | ~10 s (`FILE_STREAMING_RECOVERY_INTERVAL_MS`) | Periodic “nudge” when streaming is idle but should be progressing, to recover from missed notifications or odd states. |
| **Small command gaps** | ~250–500 ms | Space between `app_msg` and `py_msg`, or between UART commands, so responses do not overlap the next write. |

**Future direction — remove “artificial” delays:**

- **Remove fixed 7 s (and similar) sleeps** between files. Progress should be **event-driven**: as soon as a file is finished (success, discard after rm_file, or explicit “skip”), immediately request the next file **unless** we need a minimal inter-command gap for protocol stability.
- **Replace long fixed timeouts** where possible with **clear state machines**: response received → proceed; error → retry or rm_file per rules above; no arbitrary multi-second wait between healthy steps.
- **Recovery:** prefer **immediate** resume on disconnect/reconnect or on explicit “idle but incomplete queue” detection, or a **much shorter** watchdog only if firmware requires it — not a 10 s poll-by-default.
- **UART pacing:** keep only the **minimum** gap the device actually needs (if any), measured or specified by firmware — not blanket 7–10 s user-visible pauses.

**Pseudocode (no fixed between-file delay):**

```text
onFileFinished(fileNo):
  scheduleNextFileRequest(delayMs = 0)   // or COMMAND_MIN_GAP_MS only if required

requestNextFile():
  if not protocolNeedsGap():
    sendStreamFile(currentFile)
  else:
    postDelayed(COMMAND_MIN_GAP_MS) { sendStreamFile(currentFile) }
```

---

## 3. Firmware (OTA) update gated on file streaming

**Desired UX and behavior:**

- When the user starts or confirms a firmware update, the app should show a blocking state such as **“Preparing update…”** (or equivalent copy).
- **While file streaming is active** (or while there are still files to pull / sync per a single “streaming session” definition), **do not** start OTA.
- Once streaming is **fully complete** (all files handled per the new rules, or explicitly no files left), allow OTA to proceed.
- If the user opens the update flow during streaming, either:
  - disable the primary action with explanation, or
  - queue the update intent and auto-start when streaming completes.

**Pseudocode (gating):**

```text
canStartOta():
  return !isFileStreamingActive() && !hasPendingFilesToStream()

onUserTapFirmwareUpdate():
  if !canStartOta():
    showMessage("Preparing update… File sync must finish first.")
    setUiState(PREPARING_UPDATE_WAITING_ON_STREAM)
    return
  showMessage("Preparing update…")
  proceedWithOta()

// Optional: auto-continue when stream ends
onFileStreamingFullyComplete():
  if uiState == PREPARING_UPDATE_WAITING_ON_STREAM:
    proceedWithOta()
```

---

## Combined future flow (high level)

```text
onBleReady -> get_files -> stream loop

for each fileNo:
  stream until ETX
  if OK -> persist locally -> rm_file (always) -> upload/queue -> next file (no 7s wait)
  if bad but fileCheck was 1 -> retry same file (bounded) -> else rm_file -> next file
  if missing -> next file (no 7s wait unless min UART gap)

recovery: event-driven or minimal watchdog only

OTA: blocked until streaming complete; UI shows preparing/waiting until allowed
```

---

## Implementation notes (for engineers)

- Define **exactly** what counts as “empty” vs “corrupt” (row count, header present, session field, checksum if added later).
- Keep the order strict: **ETX -> local persist success -> `rm_file` -> upload/sync path**. If local persist fails, do not `rm_file` yet.
- Removing delays may require **firmware stress testing** and possibly **MTU / chunk** tuning so removing 7 s does not increase error rates.
- OTA gating must use the **same** “streaming active” flag the native service already maintains (or a single source of truth exposed to Flutter).
