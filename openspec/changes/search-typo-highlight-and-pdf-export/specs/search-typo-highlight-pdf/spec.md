# Search Typo & PDF Export Spec

## Capability: `search-typo-highlight-pdf`

### 1. Typo Guardrail Requirement
- **Requirement**: The search system MUST NOT treat distinct valid legal terms (e.g. `pencurian` and `pencarian`) as typos of each other.
- **Validation**:
  - Searching `pencurian` MUST return articles containing `pencurian`.
  - Searching `pencarian` MUST return articles containing `pencarian`.

### 2. "Mungkin Maksud Anda" Banner Requirement
- **Requirement**: When a search query contains a misspelled term (e.g. `penyudik`), the system MUST display a "Mungkin maksud Anda: **penyidik**" banner above the search result list on `HomeScreen`.
- **Interaction**: Tapping the banner replaces the search query with the suggested term and re-executes the search.

### 3. Single Article PDF Export Requirement
- **Requirement**: On `ReadPasalScreen`, a "Cetak PDF" action MUST be placed alongside the existing Bookmark and Copy action buttons.
- **Highlight Preservation**: If the screen was opened with an active `searchQuery`, matching search terms in the PDF output MUST be visually highlighted.

### 4. Batch Search Results PDF Export Requirement
- **Requirement**: When a search query is active on `HomeScreen`, a summary bar MUST be displayed showing total count (e.g., "10 pasal terkait ditemukan") and a "Cetak ke PDF" button.
- **Export Behavior**: Clicking "Cetak ke PDF" MUST generate and open/download a PDF file containing all matching articles in the search result set with active search terms highlighted.
