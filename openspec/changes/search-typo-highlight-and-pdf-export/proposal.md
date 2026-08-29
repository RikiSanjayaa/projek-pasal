# Proposal: Search Typo Guardrail, Did-You-Mean Banner & PDF Export (Single + Batch Search Results)

## Why
Users need:
1. Accurate typo suggestions without false-positive collisions on valid legal terms (e.g., `pencurian` must never be suggested/matched as a typo for `pencarian`).
2. Visual "Mungkin maksud Anda" (Did You Mean) search banner on `HomeScreen` when a genuine typo is searched.
3. Single Pasal PDF Export on `ReadPasalScreen` (beside Bookmark and Copy buttons), preserving active search highlights in the generated PDF.
4. Batch Search Results PDF Export on `HomeScreen` when a search is active (e.g., banner "10 pasal terkait ditemukan" + "Cetak ke PDF" button), generating a consolidated PDF of all matching articles with search highlights preserved.

## What Changes
1. **Typo Guardrail & Banner**:
   - Enforce exact valid dictionary check to block false-positive fuzzy matches between distinct words (`pencurian` vs `pencarian`).
   - Render "Mungkin maksud Anda: [saran]" banner at top of `HomeScreen` search list.
2. **Single Pasal PDF Export (`ReadPasalScreen`)**:
   - Add "Cetak PDF" action button beside Bookmark and Copy.
   - Render PDF document containing UU code, Pasal number, Title, Content, and Explanation.
   - Highlight matching search terms in the PDF if opened from a search query.
3. **Batch Search Results PDF Export (`HomeScreen`)**:
   - Add summary banner when search query is active ("X pasal terkait ditemukan" + "Cetak ke PDF").
   - Generate multi-page PDF formatted with all matching articles and search highlights preserved.

## Impact & Scope
- Flutter Mobile App (`pasal_mobile_app`):
  - `lib/core/utils/search_utils.dart`
  - `lib/core/services/pdf_export_service.dart` (new)
  - `lib/ui/screens/home_screen.dart`
  - `lib/ui/screens/read_pasal_screen.dart`
  - `pubspec.yaml` (add `pdf` & `printing` dependencies if missing)
