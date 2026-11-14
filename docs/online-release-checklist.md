# Online release acceptance checklist

Scope: preserve existing behavior while restoring the online functions. No intermediate APK should be presented as the complete release.

## Automated gate (every release candidate)
- [ ] Dart analysis succeeds; no newly introduced errors.
- [ ] All Flutter tests pass, including the pre-existing suite.
- [ ] Official search: normal results, single-book redirect, explicit zero results, unexpected HTML, session errors, request cooldown.
- [ ] Multi-source search: independently selected source set, disabled homepage excluded, results survive a failing source, disabled sources issue no requests, saved switches survive restart and compatibility migration.
- [ ] ARM64 release APK builds; Android native unit tests pass before upload.
- [ ] Confirm artifact is built from the intended commit, with the expected application ID and ABI. Never substitute an earlier successful artifact.

## Physical Android device acceptance (PJA110 or equivalent)
- [ ] Install and cold-start. Verify package/signature compatibility before attempting an in-place update; do not uninstall or clear the original app.
- [ ] Official site login, verification, persistent session, logout, reconnection, and correct failure messages.
- [ ] Discover recent updates, rankings, categories; refresh and pagination.
- [ ] Search by title, author, tag, ID; test known existing titles and author names; distinguish empty results, rate limits and network errors.
- [ ] Switch homepage independently from search selection; add a preset, enable/disable a source, import/edit a custom configuration, and restart.
- [ ] Open search result from each supported source, verify cover/details/table of contents/body/illustrations, next chapter and offline cached reading.
- [ ] Preserve local imports, shelf membership, progress, bookmarks, reader settings and source configs; test update with an existing library.
- [ ] For restored account features: real profile, cloud shelf read/add/remove/merge, recommendation, read/post/reply reviews. Use explicit user actions for remote writes; preserve drafts on uncertain responses; never delete local books automatically.
- [ ] Daily check-in and other unavailable server interfaces must be clearly identified, not presented as working.

Passing CI is necessary but does not replace actual website and device testing. Report unverified or unavailable functions explicitly. Keep the established distribution unchanged until the full candidate has passed the relevant checks.
