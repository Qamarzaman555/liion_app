# Existing File Streaming Approach (Current) + Pseudocode

## Current Approach (Bullet Points)

- File streaming sequence starts after BLE is connected and UART/data-notification setup is complete.
- The app requests file bounds using `app_msg get_files` followed by `py_msg`.
- On valid response (`OK py_msg get_files <startFile> <endFile>`), it sets the file window and begins file-by-file streaming.
- For each file, it sends `app_msg stream_file <fileNo>` then `py_msg`, and waits for stream response.
- If stream response indicates file exists (`fileCheck == 1`), app waits for data frames.
- File payload starts on `STX` and ends on `ETX`.
- The app uploads/stores only after ETX is detected (end-of-file boundary).
- After each file completion (ETX path), the next file request is delayed by `FILE_STREAMING_DELAY_MS` (currently 7 seconds).
- If device replies missing/intercepted (`fileCheck == -1` or timed `ERROR py_msg`), app skips that file and also waits the same delay before requesting next.
- Stream-file response timeout exists (`STREAM_FILE_TIMEOUT_MS`, currently 10 seconds); on timeout it advances/retries per current index logic.
- Recovery loop runs (`FILE_STREAMING_RECOVERY_INTERVAL_MS`, currently 10 seconds) to restart requests if streaming stalls and conditions are safe.

## Corrupted File Handling (Current)

- Corruption is flagged when expected structure is not complete (for example, missing header packet before ETX).
- Corrupted state is marked in upload metadata (`corrupted_file` flag).
- Corrupted files are still finalized through the same end-of-file ETX path and then processed for storage/upload handling.
- Parsing issues are handled defensively so bad rows do not crash the stream flow.

## Upload Behavior (What Triggers Upload)

- Upload/storage logic is triggered once ETX is detected for a file.
- At ETX:
  - Data object is prepared (including session/file metadata and corruption flag if applicable).
  - If online, it attempts Firebase upload immediately.
  - If upload succeeds, session is marked as sent and `rm_file <fileNo>` is sent back to device (after short delay) to remove source file.
  - If offline or upload fails, payload is stored locally as pending for later sync.

## No Internet Behavior (Current)

- If internet is unavailable, file data is saved locally in pending storage (`pending_upload_*` entries).
- Pending uploads are synced automatically when network becomes available again (network callback + post-connect sync trigger).
- Sync path also checks already-sent sessions before re-uploading pending data.

## Duplicate Avoidance / Session Tracking (Current)

- Yes, duplicate prevention is implemented.
- Sent-session registry is persisted in SharedPreferences as `sentSessions_<deviceAddressKey>`.
- Before upload, app checks if current session already exists in sent set:
  - If yes: skip duplicate upload.
  - If no: upload and then add session to sent set on success.
- During pending-sync replay, it again compares pending session IDs against `sentSessions_*` and removes already-sent pending entries.
- Note: this duplicate guard is session-based (not full payload hash-based).

## High-Level Pseudocode

- `onBleReady -> requestGetFiles()`
- `if get_files response valid -> currentFile = startFile`
- `while currentFile <= endFile`
  - `send stream_file currentFile`
  - `wait for response/timeout`
  - `if file missing or intercepted -> wait 7s -> currentFile++ -> continue`
  - `collect bytes until STX...ETX`
  - `on ETX -> finalize file payload`
  - `mark corrupted if structure incomplete`
  - `if session already in sentSessions -> skip upload`
  - `else if internet available -> upload now`
    - `if success -> add session to sentSessions -> send rm_file`
    - `if failure -> save pending locally`
  - `else -> save pending locally`
  - `wait 7s`
  - `currentFile++`
- `background recovery timer checks stalled state and resumes next file request`
- `network callback triggers syncPendingUploads() for offline backlog`

