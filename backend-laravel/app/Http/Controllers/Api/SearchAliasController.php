<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SearchAlias;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class SearchAliasController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = SearchAlias::query();

        if ($request->filled('search')) {
            $search = trim((string) $request->query('search'));
            $query->where(function ($q) use ($search) {
                $q->where('term', 'ilike', "%{$search}%")
                    ->orWhere('category', 'ilike', "%{$search}%")
                    ->orWhereRaw("aliases::text ILIKE ?", ["%{$search}%"]);
            });
        }

        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }

        return response()->json(
            $query->orderBy('term')->paginate((int) $request->query('per_page', 100))
        );
    }

    public function suggestions(Request $request): JsonResponse
    {
        $search = $this->normalizeSearchText((string) $request->query('search', ''));
        if ($search === '') {
            return response()->json(['suggestions' => []]);
        }

        $tokens = array_values(array_filter(explode(' ', $search), fn ($token) => mb_strlen($token) > 1));
        $aliases = SearchAlias::query()
            ->where('is_active', true)
            ->get(['term', 'aliases'])
            ->flatMap(function (SearchAlias $alias) use ($search, $tokens) {
                $term = $this->normalizeSearchText($alias->term);
                $targets = collect($alias->aliases ?? [])
                    ->map(fn ($item) => $this->normalizeSearchText((string) $item))
                    ->filter();

                $isRelevant = str_contains($search, $term)
                    || collect($tokens)->contains(fn ($token) => $this->isLightTypo($token, $term))
                    || $targets->contains(fn ($target) => str_contains($target, $search) || str_contains($search, $target));

                return $isRelevant ? $targets->prepend($term) : [];
            })
            ->filter()
            ->unique()
            ->take(6)
            ->values();

        return response()->json(['suggestions' => $aliases]);
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        $payload = $this->validated($request);
        $payload['created_by'] = $request->user()?->id;
        $payload['updated_by'] = $request->user()?->id;
        $alias = SearchAlias::create($payload);
        $audit->log($request, 'CREATE', 'search_aliases', $alias->id, null, $alias);

        return response()->json($alias, 201);
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $alias = SearchAlias::findOrFail($id);
        $old = $alias->replicate();
        $payload = $this->validated($request, $alias);
        $payload['updated_by'] = $request->user()?->id;
        $alias->update($payload);
        $audit->log($request, 'UPDATE', 'search_aliases', $alias->id, $old, $alias);

        return response()->json($alias);
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $alias = SearchAlias::findOrFail($id);
        $old = $alias->replicate();
        $alias->delete();
        $audit->log($request, 'DELETE', 'search_aliases', $id, $old, null);

        return response()->json(['message' => 'Alias pencarian dihapus.']);
    }

    private function validated(Request $request, ?SearchAlias $alias = null): array
    {
        $payload = $request->validate([
            'term' => [
                'required',
                'string',
                'max:120',
                Rule::unique('search_aliases', 'term')->ignore($alias?->id),
            ],
            'aliases' => ['required', 'array', 'min:1'],
            'aliases.*' => ['required', 'string', 'max:160'],
            'category' => ['nullable', 'string', 'max:120'],
            'notes' => ['nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
        ], [
            'term.unique' => 'Kata pencarian ini sudah ada.',
            'aliases.min' => 'Minimal isi satu kata target.',
        ]);

        $payload['term'] = $this->normalizeSearchText($payload['term']);
        $payload['aliases'] = collect($payload['aliases'])
            ->map(fn ($item) => $this->normalizeSearchText((string) $item))
            ->filter()
            ->unique()
            ->values()
            ->all();

        return $payload;
    }

    private function normalizeSearchText(string $value): string
    {
        $value = Str::lower($value);
        $value = preg_replace('/[^a-z0-9]+/i', ' ', $value) ?? '';

        return trim(preg_replace('/\s+/', ' ', $value) ?? '');
    }

    private function isLightTypo(string $a, string $b): bool
    {
        if (mb_strlen($a) < 4 || mb_strlen($b) < 4) {
            return false;
        }

        $maxDistance = max(mb_strlen($a), mb_strlen($b)) <= 5 ? 1 : 2;

        return abs(mb_strlen($a) - mb_strlen($b)) <= $maxDistance
            && levenshtein($a, $b) <= $maxDistance;
    }
}
