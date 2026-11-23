# ROCKS Chapter Directory Implementation

## Summary

The 13 requested chapters are included in the bundled directory using the exact names supplied. Existing bundled chapter and interest-group records remain in place; the requested entries reuse their stable local identifiers rather than creating duplicate sample records.

## Requested chapters

1. Washington D.C. Chapter
2. Phantom Warriors ROCKS
3. Hampton Roads ROCKS
4. Hampton University ROCKS
5. JBLM Rainer ROCKS
6. Fort Huachuca chapter
7. Alamo ROCKS
8. All American Chapter ROCKS
9. MG Charles Rogers ROCKS
10. Climb to Glory ROCKS
11. Henry O. Flipper ROCKS
12. Aloha Chapter of the ROCKS
13. Buffalo Soldier ROCKS

## Verified information

| Information | Count |
| --- | ---: |
| Official mailing addresses | 7 |
| Chapter email addresses | 12 |
| Primary contact names | 13 |
| Verified HTTPS websites | 4 |
| Verified latitude/longitude pairs | 0 |
| Entries with a verified textual location for a Maps search | 11 |

Maps actions search the official location text and are explicitly described as approximate; they do not represent a chapter office or mailing address. Entries without enough location information do not show a Maps action.

The official directory's Phantom Warriors map entry lists Fort Cavazos, TX, while its contact card still says Fort Hood, TX. The app uses the current org-chart location, preserves the discrepancy as a note, and does not present either as a chapter mailing address.

## Supabase and offline status

- The existing `mailing_address` and `contact_person` columns from migration `003_chapter_locator.sql` are reused. The existing `website`, `city`, `state`, `installation`, `latitude`, and `longitude` fields are also reused.
- Migration `006_official_chapter_directory.sql` matches canonical and previously listed chapter-name variants, updates existing records without replacing non-empty metadata, inserts missing records with stable UUIDs, and scopes write access to assigned chapter administrators or national administrators. Public reads continue to use the existing active-chapter policy.
- `ChapterRow` now maps `mailing_address` and `contact_person` to the correct model fields. The app loads approved live rows when configured, adds bundled requested entries if the live result omits them, and shows the bundled directory with a status message if live loading fails.
- All 13 requested entries are available without Supabase. Other bundled chapters and interest groups are preserved.
- The migration was not applied to a live Supabase project in this workspace. The live service query was not integration-tested; the row-decoding and mapping path was tested with a Supabase-shaped fixture.

## Files changed

- `ROCKS/Models/Chapter.swift`
- `ROCKS/Services/SupabaseRepositories.swift`
- `ROCKS/Views/ChapterListView.swift`
- `ROCKSTests/ROCKSTests.swift`
- `supabase/migrations/006_official_chapter_directory.sql`
- `CHAPTER_DIRECTORY_IMPLEMENTATION.md`

## Tests

Executed:

```text
xcodebuild test -project ROCKS.xcodeproj -scheme ROCKS \
  -destination 'platform=iOS Simulator,name=iPhone 16,arch=arm64' \
  -only-testing:ROCKSTests ONLY_ACTIVE_ARCH=YES
```

The final simulator run completed with 38 tests and no failures.

Coverage includes the exact requested names, bundled uniqueness, legacy-name normalization, case/whitespace-insensitive search, location keywords, graceful handling of missing fields, valid email/website/Maps actions, offline repository data, and Supabase row mapping.

## Remaining verification

- Six chapters have no verified mailing address: Climb to Glory, Fort Huachuca, Hampton University, JBLM, MG Charles Rogers, and Phantom Warriors.
- Hampton Roads has no published chapter email in the official directory.
- Nine chapters have no verified website URL.
- No chapter-specific coordinates were published in the sources reviewed.
- The chapter directory should be rechecked against the live Supabase project after migration `006` is applied.

## Sources

- [Official ROCKS Chapter Finder](https://www.rocksinc.org/content.aspx?page_id=225&club_id=459944)
- [Washington D.C. Chapter official website](https://therocksdc.org/)
