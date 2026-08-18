<?php

namespace App\Services;

use App\Models\Pasal;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Str;

class LegalContextService
{
    /**
     * @return array<int, array<string, mixed>>
     */
    public function relevantPasal(string $question, int $limit = 6): array
    {
        $normalized = $this->normalize($question);
        if ($normalized === '') {
            return [];
        }

        $exactNomor = $this->extractSpecificNomor($normalized);
        if ($exactNomor !== null) {
            $exact = Pasal::query()
                ->with('undangUndang')
                ->where('is_active', true)
                ->whereRaw("lower(regexp_replace(nomor, '^pasal[[:space:]]+', '', 'i')) = ?", [$exactNomor])
                ->orderBy('nomor')
                ->limit($limit)
                ->get();

            if ($exact->isNotEmpty()) {
                return $this->formatSources($exact);
            }
        }

        $terms = $this->expandedTerms($normalized);
        $likeTerms = array_map(fn ($term) => '%'.$term.'%', $terms);
        $tsQuery = implode(' ', array_slice($terms, 0, 8));

        $query = Pasal::query()
            ->with('undangUndang')
            ->where('is_active', true)
            ->select('pasal.*');

        if ($tsQuery !== '') {
            $query->selectRaw(
                "COALESCE(ts_rank_cd(search_vector, websearch_to_tsquery('simple', ?)), 0) AS ai_search_rank",
                [$tsQuery],
            );
        }

        $query->where(function ($q) use ($likeTerms, $tsQuery) {
            if ($tsQuery !== '') {
                $q->whereRaw("search_vector @@ websearch_to_tsquery('simple', ?)", [$tsQuery]);
            }

            foreach ($likeTerms as $term) {
                $q->orWhere('nomor', 'ilike', $term)
                    ->orWhere('judul', 'ilike', $term)
                    ->orWhere('isi', 'ilike', $term)
                    ->orWhere('penjelasan', 'ilike', $term)
                    ->orWhereRaw("array_to_string(keywords, ' ') ILIKE ?", [$term]);
            }
        });

        return $this->formatSources(
            $query->orderByDesc('ai_search_rank')
                ->orderBy('nomor')
                ->limit($limit)
                ->get(),
        );
    }

    public function buildContextText(array $sources): string
    {
        return collect($sources)
            ->map(function (array $source, int $index) {
                $number = $index + 1;
                $parts = [
                    "SUMBER {$number}",
                    "UU: {$source['undang_undang']['kode']} - {$source['undang_undang']['nama']}",
                    "Pasal: {$source['nomor']}",
                ];

                if (! empty($source['judul'])) {
                    $parts[] = "Judul: {$source['judul']}";
                }

                $parts[] = "Isi: {$source['isi']}";

                if (! empty($source['penjelasan'])) {
                    $parts[] = "Penjelasan: {$source['penjelasan']}";
                }

                return implode("\n", $parts);
            })
            ->implode("\n\n---\n\n");
    }

    public function normalize(string $value): string
    {
        $value = Str::lower($value);
        $value = preg_replace('/[^a-z0-9]+/i', ' ', $value) ?? '';

        return trim(preg_replace('/\s+/', ' ', $value) ?? '');
    }

    private function extractSpecificNomor(string $normalized): ?string
    {
        $nomor = str_starts_with($normalized, 'pasal ')
            ? trim(substr($normalized, 6))
            : $normalized;

        return preg_match('/^[0-9]{1,4}[a-z]?(?:\s+(?:bis|ter))?$/i', $nomor)
            ? $nomor
            : null;
    }

    /**
     * @return array<int, string>
     */
    private function expandedTerms(string $normalized): array
    {
        $tokens = collect(explode(' ', $normalized))
            ->filter(fn ($token) => mb_strlen($token) > 1)
            ->reject(fn ($token) => in_array($token, [
                'dan', 'atau', 'yang', 'dengan', 'untuk', 'pada', 'dalam',
                'pasal', 'kalau', 'jika', 'apa', 'bagaimana', 'kena',
                'saya', 'aku', 'kami', 'mengalami', 'terjadi', 'hukum',
                'hukuman', 'sanksi', 'bagi', 'buat', 'pelaku', 'korban',
            ], true));

        $aliases = [
            'maling' => ['pencurian', 'mencuri', 'mengambil barang'],
            'curi' => ['pencurian', 'mencuri', 'mengambil barang'],
            'copet' => ['pencurian', 'mencuri', 'mengambil barang'],
            'pencopetan' => ['pencurian', 'mencuri', 'mengambil barang'],
            'jambret' => ['pencurian', 'pencurian dengan kekerasan', 'mengambil barang'],
            'penjambretan' => ['pencurian', 'pencurian dengan kekerasan', 'mengambil barang'],
            'tipu' => ['penipuan', 'perbuatan curang'],
            'bohong' => ['penipuan', 'keterangan palsu', 'berita bohong'],
            'ancam' => ['pengancaman', 'ancaman kekerasan'],
            'aniaya' => ['penganiayaan', 'kekerasan'],
            'bunuh' => ['pembunuhan', 'menghilangkan nyawa'],
            'gelap' => ['penggelapan'],
            'narkoba' => ['narkotika', 'psikotropika'],
            'judi' => ['perjudian'],
            'korupsi' => ['tindak pidana korupsi', 'merugikan keuangan negara'],
        ];

        $terms = collect([$normalized])->merge($tokens);
        foreach ($tokens as $token) {
            $terms = $terms->merge($aliases[$token] ?? []);
        }

        return $terms
            ->map(fn ($term) => $this->normalize((string) $term))
            ->filter()
            ->unique()
            ->take(16)
            ->values()
            ->all();
    }

    /**
     * @param EloquentCollection<int, Pasal> $pasal
     * @return array<int, array<string, mixed>>
     */
    private function formatSources(EloquentCollection $pasal): array
    {
        return $pasal->map(fn (Pasal $item) => [
            'id' => $item->id,
            'nomor' => $item->nomor,
            'judul' => $item->judul,
            'isi' => Str::limit($item->isi, 1600, '...'),
            'penjelasan' => $item->penjelasan ? Str::limit($item->penjelasan, 900, '...') : null,
            'keywords' => $item->keywords,
            'undang_undang' => [
                'id' => $item->undangUndang?->id,
                'kode' => $item->undangUndang?->kode,
                'nama' => $item->undangUndang?->nama,
            ],
        ])->values()->all();
    }
}
