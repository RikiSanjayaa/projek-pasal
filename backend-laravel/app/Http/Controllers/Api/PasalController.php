<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\SearchAlias;
use App\Services\AuditService;
use App\Services\ImportPasalService;
use App\Support\PasalTextNormalizer;
use Illuminate\Database\QueryException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class PasalController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Pasal::query()->with('undangUndang');
        if ($request->boolean('with_trashed') || $request->boolean('trash')) {
            $query->withTrashed();
        }
        if ($request->boolean('trash')) {
            $query->onlyTrashed();
        }
        if ($request->filled('undang_undang_id')) {
            $query->where('undang_undang_id', $request->query('undang_undang_id'));
        }
        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }
        $search = trim((string) $request->query('search', ''));
        if ($search !== '') {
            $this->applySmartSearch($query, $search);
        }
        $keywords = $request->query('keywords', []);
        if (is_string($keywords)) {
            $keywords = array_filter(explode(',', $keywords));
        }
        if (is_array($keywords) && count($keywords) > 0) {
            $query->where(function ($q) use ($keywords) {
                foreach ($keywords as $keyword) {
                    $q->orWhereRaw('? = ANY(keywords)', [$keyword]);
                }
            });
        }

        $sort = $request->boolean('trash') ? 'deleted_at' : ($search !== '' ? 'relevance' : 'nomor');
        $direction = $request->boolean('trash') ? 'desc' : 'asc';

        if ($sort === 'relevance') {
            $query->orderByDesc('search_score')->orderBy('nomor');
        } else {
            $query->orderBy($sort, $direction);
        }

        return response()->json($query->paginate((int) $request->query('per_page', 20)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $this->validated($request);
        $payload['created_by'] = $request->user()?->id;
        $payload['updated_by'] = $request->user()?->id;
        $pasal = Pasal::create($payload);
        $audit->log($request, 'CREATE', 'pasal', $pasal->id, null, $pasal);

        return response()->json($pasal->load('undangUndang'), 201);
    }

    public function show(string $id): JsonResponse
    {
        return response()->json(Pasal::withTrashed()->with('undangUndang')->findOrFail($id));
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $old = $pasal->replicate();
        $payload = $this->validated($request, true, $pasal);
        $payload['updated_by'] = $request->user()?->id;
        $pasal->update($payload);
        $audit->log($request, 'UPDATE', 'pasal', $pasal->id, $old, $pasal);

        return response()->json($pasal->load('undangUndang'));
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::findOrFail($id);
        $old = $pasal->replicate();
        $pasal->update(['is_active' => false, 'updated_by' => $request->user()?->id]);
        $pasal->delete();
        $audit->log($request, 'DELETE', 'pasal', $pasal->id, $old, $pasal);

        return response()->json(['message' => 'Pasal dihapus.']);
    }

    public function restore(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $pasal->restore();
        $pasal->update(['is_active' => true, 'updated_by' => $request->user()?->id]);
        $audit->log($request, 'RESTORE', 'pasal', $pasal->id, null, $pasal);

        return response()->json($pasal);
    }

    public function bulkDelete(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $deleted = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::find($id);
            if (! $pasal) {
                continue;
            }
            $old = $pasal->replicate();
            $pasal->update(['is_active' => false, 'updated_by' => $request->user()?->id]);
            $pasal->delete();
            $audit->log($request, 'DELETE', 'pasal', $pasal->id, $old, $pasal);
            $deleted++;
        }

        return response()->json(['deleted' => $deleted]);
    }

    public function bulkRestore(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $restored = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::withTrashed()->find($id);
            if (! $pasal) {
                continue;
            }
            $pasal->restore();
            $pasal->update(['is_active' => true, 'updated_by' => $request->user()?->id]);
            $audit->log($request, 'RESTORE', 'pasal', $pasal->id, null, $pasal);
            $restored++;
        }

        return response()->json(['restored' => $restored]);
    }

    public function forceDelete(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::withTrashed()->findOrFail($id);
        $old = $pasal->replicate();
        PasalLink::withTrashed()
            ->where('source_pasal_id', $id)
            ->orWhere('target_pasal_id', $id)
            ->forceDelete();
        $pasal->forceDelete();
        $audit->log($request, 'DELETE', 'pasal', $id, $old, null, ['force' => true]);

        return response()->json(['message' => 'Pasal dihapus permanen.']);
    }

    public function bulkForceDelete(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $request->validate(['ids' => ['required', 'array'], 'ids.*' => ['uuid']]);
        $deleted = 0;

        foreach ($payload['ids'] as $id) {
            $pasal = Pasal::withTrashed()->find($id);
            if (! $pasal) {
                continue;
            }
            $old = $pasal->replicate();
            PasalLink::withTrashed()
                ->where('source_pasal_id', $id)
                ->orWhere('target_pasal_id', $id)
                ->forceDelete();
            $pasal->forceDelete();
            $audit->log($request, 'DELETE', 'pasal', $id, $old, null, ['force' => true]);
            $deleted++;
        }

        return response()->json(['deleted' => $deleted]);
    }

    public function bulkImport(Request $request, ImportPasalService $importer, AuditService $audit): JsonResponse
    {
        $request->validate([
            'file' => ['nullable', 'file', 'mimes:xlsx,xls,csv'],
            'rows' => ['nullable', 'array'],
        ]);

        $result = $request->hasFile('file')
            ? $importer->importFile($request->file('file'), $request->user()?->id)
            : $importer->importRows($request->input('rows', []), $request->user()?->id);

        $audit->log($request, 'IMPORT', 'pasal', null, null, null, $result);

        return response()->json($result);
    }

    private function validated(Request $request, bool $partial = false, ?Pasal $pasal = null): array
    {
        $normalizable = [];
        foreach (['nomor', 'judul', 'isi', 'penjelasan'] as $field) {
            if ($request->has($field)) {
                $normalizable[$field] = $request->input($field);
            }
        }
        $request->merge(PasalTextNormalizer::normalizePayload($normalizable));

        $required = $partial ? 'sometimes' : 'required';
        $undangUndangId = $request->input('undang_undang_id', $pasal?->undang_undang_id);

        return $request->validate([
            'undang_undang_id' => [$required, 'uuid', 'exists:undang_undang,id'],
            'nomor' => [
                $required,
                'string',
                'max:100',
                Rule::unique('pasal', 'nomor')
                    ->where(fn ($query) => $query->where('undang_undang_id', $undangUndangId))
                    ->ignore($pasal?->id),
            ],
            'judul' => ['nullable', 'string', 'max:500'],
            'isi' => [$required, 'string'],
            'penjelasan' => ['nullable', 'string'],
            'keywords' => ['sometimes', 'array'],
            'keywords.*' => ['string'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'nomor.unique' => 'Nomor pasal ini sudah ada pada undang-undang yang dipilih.',
        ]);
    }

    private function applySmartSearch($query, string $search): void
    {
        $terms = $this->expandedSearchTerms($search);
        $likeTerms = array_map(fn ($term) => '%'.$term.'%', $terms);
        $tsQuery = implode(' ', array_slice($terms, 0, 8));
        $nomorQuery = $this->extractNomorQuery($search);

        $query->select('pasal.*')->selectRaw(
            <<<SQL
            (
                CASE WHEN lower(regexp_replace(nomor, '^pasal[[:space:]]+', '', 'i')) = ? THEN 1000 ELSE 0 END +
                CASE WHEN lower(nomor) = ? THEN 850 ELSE 0 END +
                CASE WHEN nomor ILIKE ? THEN 420 ELSE 0 END +
                CASE WHEN judul ILIKE ? THEN 260 ELSE 0 END +
                CASE WHEN array_to_string(keywords, ' ') ILIKE ? THEN 220 ELSE 0 END +
                CASE WHEN isi ILIKE ? THEN 90 ELSE 0 END +
                CASE WHEN penjelasan ILIKE ? THEN 45 ELSE 0 END +
                COALESCE(ts_rank_cd(search_vector, websearch_to_tsquery('simple', ?)), 0) * 120
            ) AS search_score
            SQL,
            [
                Str::lower($nomorQuery),
                Str::lower($search),
                '%'.$nomorQuery.'%',
                '%'.$search.'%',
                '%'.$search.'%',
                '%'.$search.'%',
                '%'.$search.'%',
                $tsQuery,
            ]
        );

        $query->where(function ($q) use ($likeTerms, $tsQuery) {
            $q->whereRaw("search_vector @@ websearch_to_tsquery('simple', ?)", [$tsQuery]);

            foreach ($likeTerms as $term) {
                $q->orWhere('nomor', 'ilike', $term)
                    ->orWhere('judul', 'ilike', $term)
                    ->orWhere('isi', 'ilike', $term)
                    ->orWhere('penjelasan', 'ilike', $term)
                    ->orWhereRaw("array_to_string(keywords, ' ') ILIKE ?", [$term]);
            }
        });
    }

    private function expandedSearchTerms(string $search): array
    {
        $normalized = $this->normalizeSearchText($search);
        $tokens = array_values(array_filter(explode(' ', $normalized), fn ($token) => mb_strlen($token) > 1));
        $terms = [$normalized, ...$tokens];
        $synonyms = $this->searchAliases();

        foreach ($tokens as $token) {
            array_push($terms, ...($synonyms[$token] ?? []));
        }

        if (str_contains($normalized, 'barang curian')) {
            array_push($terms, 'penadahan', 'hasil kejahatan');
        }
        if (str_contains($normalized, 'judi online')) {
            array_push($terms, 'perjudian', 'transaksi elektronik');
        }

        $stopWords = ['dan', 'atau', 'yang', 'dengan', 'untuk', 'pada', 'dalam', 'pasal'];

        $expanded = collect($terms)
            ->map(fn ($term) => $this->normalizeSearchText($term))
            ->filter(fn ($term) => $term !== '' && ! in_array($term, $stopWords, true))
            ->unique()
            ->take(16)
            ->values()
            ->all();

        return $expanded ?: [$normalized];
    }

    private function searchAliases(): array
    {
        $fallback = [
            'maling' => ['pencurian', 'mencuri', 'mengambil barang'],
            'curi' => ['pencurian', 'mencuri', 'mengambil barang'],
            'nyuri' => ['pencurian', 'mencuri', 'mengambil barang'],
            'barang curian' => ['penadahan', 'hasil kejahatan'],
            'penadah' => ['penadahan', 'hasil kejahatan'],
            'tipu' => ['penipuan', 'perbuatan curang'],
            'bohong' => ['penipuan', 'keterangan palsu', 'berita bohong'],
            'ancam' => ['pengancaman', 'ancaman kekerasan'],
            'aniaya' => ['penganiayaan', 'kekerasan'],
            'bunuh' => ['pembunuhan', 'menghilangkan nyawa'],
            'narkoba' => ['narkotika', 'psikotropika'],
            'sabu' => ['narkotika', 'psikotropika'],
            'ganja' => ['narkotika'],
            'judi' => ['perjudian'],
            'judi online' => ['perjudian', 'transaksi elektronik'],
            'korupsi' => ['tindak pidana korupsi', 'merugikan keuangan negara'],
            'suap' => ['gratifikasi', 'korupsi'],
            'fitnah' => ['pencemaran nama baik', 'penghinaan'],
            'hoax' => ['berita bohong', 'kabar bohong'],
            'palsu' => ['pemalsuan', 'surat palsu', 'keterangan palsu'],
            'gelap' => ['penggelapan'],
            'rampas' => ['perampasan', 'kekerasan'],
            'paksa' => ['pemaksaan', 'kekerasan'],
            'rusak' => ['perusakan', 'merusak'],
        ];

        try {
            return SearchAlias::query()
                ->where('is_active', true)
                ->get(['term', 'aliases'])
                ->mapWithKeys(fn (SearchAlias $alias) => [
                    $this->normalizeSearchText($alias->term) => collect($alias->aliases ?? [])
                        ->map(fn ($item) => $this->normalizeSearchText((string) $item))
                        ->filter()
                        ->values()
                        ->all(),
                ])
                ->filter()
                ->all() ?: $fallback;
        } catch (QueryException) {
            return $fallback;
        }
    }

    private function normalizeSearchText(string $value): string
    {
        $value = Str::lower($value);
        $value = preg_replace('/[^a-z0-9]+/i', ' ', $value) ?? '';

        return trim(preg_replace('/\s+/', ' ', $value) ?? '');
    }

    private function extractNomorQuery(string $search): string
    {
        $normalized = $this->normalizeSearchText($search);
        if (str_starts_with($normalized, 'pasal ')) {
            return trim(substr($normalized, 6));
        }

        return $normalized;
    }
}
