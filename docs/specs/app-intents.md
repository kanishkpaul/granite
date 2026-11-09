# Spec: App Intents, Siri and Spotlight

Status: **built**. Plan refs: §3 (App Intents, Spotlight), §8 phase 4 ("App Intents entities: Spotlight and Siri").

## Entities and intents
- `NoteEntity` (an `IndexedEntity`): id = vault path, title, folder, text. Query by title words, suggested = recent notes.
- `OpenNoteIntent` ("Open ‹note› in granite"), `SearchNotesIntent` ("Search granite": keywords → notes), `AskNotesIntent` ("Ask granite": grounded Q&A, verified sentences with their note titles, or "I have no note on that"), and the existing `CaptureToGraniteIntent`. All four are App Shortcuts with Siri phrases.

## Spotlight
- Notes are indexed with `CSSearchableIndex.indexAppEntities` (title, description, first 4,000 characters): the whole vault on open (at most once a day), then each changed path as the watcher reports it; gone or disallowed notes are removed.
- Only notes labelled `cloud` or `pcc`, outside `mcp: hidden` folders and outside `AI/`, are indexed: Spotlight feeds Siri and Apple Intelligence. Settings → AI toggles it (off clears the index).

## Files
`App/Intents/NoteIntents.swift`, `App/Capture/CaptureIntent.swift`; the build's `Metadata.appintents` lists the four intents, the entity and four shortcuts.

## Done when
- [x] Builds with App Intents metadata extracted.
- [ ] Spotlight finds a note, and "Ask granite" answers in Siri, from the installed app (you: needs the signed app in /Applications).
