# Design: Typo Guardrail, Did-You-Mean Banner & PDF Export

## Component Architecture

### 1. PDF Export Service (`lib/core/services/pdf_export_service.dart`)
- Uses `pdf` and `printing` packages to render printable PDF documents in Flutter.
- Methods:
  - `exportSinglePasal({required PasalModel pasal, String searchQuery = ''})`: Builds a single article PDF with header logo, UU code, title, body, and explanation. Highlighted text spans are rendered using yellow background spans when `searchQuery` is provided.
  - `exportBatchPasal({required List<PasalModel> pasalList, required String searchQuery})`: Builds a formatted multi-page PDF document containing all matched articles with summary statistics and highlights.

### 2. Search Utils & Typo Guardrail (`lib/core/utils/search_utils.dart`)
- `_validLegalTerms`: Expanded dictionary set of valid Indonesian legal terms.
- `_hasFuzzyTokenMatch`: Returns false if the token exists in `_validLegalTerms` to prevent cross-word collisions (`pencurian` vs `pencarian`).
- `suggestTypoCorrection(query)`: Finds nearest valid term for non-dictionary typos (e.g. `penyudik` -> `penyidik`).

### 3. Single Article View (`lib/ui/screens/read_pasal_screen.dart`)
- Action bar updated: `[Bookmark] [Copy] [Cetak PDF]`.
- Calls `PdfExportService.exportSinglePasal` on tap.

### 4. HomeScreen Search Results Header (`lib/ui/screens/home_screen.dart`)
- When `_searchQuery` is active:
  - Renders "Mungkin maksud Anda" banner if `suggestTypoCorrection` returns a suggestion.
  - Renders search summary header: `"X pasal terkait ditemukan"` + `[Cetak ke PDF]` button.
- Calls `PdfExportService.exportBatchPasal` on tap.
