<?php

namespace App\Services;

use App\Models\ImportSource;
use App\Models\ImportRun;

/** Registrasi sumber disimpan bersama UU; pembacaan katalog tidak mengakses jaringan. */
class ImportSourceCatalog
{
    public function __construct(private readonly LawSourceService $sources) {}

    /** @return list<array<string, mixed>> */
    public function all(): array
    {
        return ImportSource::with('undangUndang')->orderBy('created_at')->get()
            ->filter(fn ($source) => (bool) $source->undangUndang?->source_url)
            ->map(fn ($source) => $this->entry($source))->values()->all();
    }

    /** @return array<string, mixed>|null */
    public function find(string $slug): ?array
    {
        $source = ImportSource::with('undangUndang')->where('slug', $slug)->first();
        return $source?->undangUndang?->source_url ? $this->entry($source) : null;
    }

    private function entry(ImportSource $source): array
    {
        $uu = $source->undangUndang;
        return [
            ...$this->sources->summary($source),
            'parse_status' => $this->parseStatus($source),
            'kode' => $uu->kode, 'nama' => $uu->nama,
            'label' => $source->config['label'] ?? $uu->kode,
            'datahukum_url' => $source->url, 'undang_undang_id' => $uu->id,
            'official_pdf_url' => $uu->official_pdf_url,
            'official_document' => $this->sources->document($uu->official_document, $uu->id),
        ];
    }

    private function parseStatus(ImportSource $source): string
    {
        // Only a completed check of this exact configuration/document proves parser compatibility.
        $run = ImportRun::where('undang_undang_id', $source->undang_undang_id)
            ->whereNotIn('status', [ImportRun::QUEUED, ImportRun::RUNNING])
            ->whereRaw('source_config = ?::jsonb', [json_encode($this->sources->snapshot($source), JSON_THROW_ON_ERROR)])
            ->orderByDesc('created_at')->orderByDesc('id')->first();
        if (! $run) {
            return 'unverified';
        }
        if (in_array($run->status, [ImportRun::FAILED, ImportRun::NEEDS_CONFIG], true)) {
            return 'failed';
        }
        return $run->html_sha256 && ! $run->unknown_versions ? 'passed' : 'unverified';
    }
}
