<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;

/** Daftar sumber import yang dikonfigurasi developer, di-cache beberapa menit supaya halaman admin tidak memanggil Python tiap muat. */
class ImportSourceCatalog
{
    private const CACHE_KEY = 'import_sources:list';

    private const TTL_SECONDS = 300;

    public function __construct(private readonly DatahukumPipeline $pipeline) {}

    /** @return list<array<string, mixed>> */
    public function all(): array
    {
        return Cache::remember(self::CACHE_KEY, self::TTL_SECONDS, fn () => $this->pipeline->listSources());
    }

    /** @return array<string, mixed>|null */
    public function find(string $slug): ?array
    {
        foreach ($this->all() as $source) {
            if (($source['slug'] ?? null) === $slug) {
                return $source;
            }
        }

        return null;
    }
}
