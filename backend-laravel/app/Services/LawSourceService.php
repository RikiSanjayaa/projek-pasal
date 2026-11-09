<?php

namespace App\Services;

use App\Models\ImportSource;
use App\Models\UndangUndang;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Storage;

class LawSourceService
{
    public const EDITABLE = ['doc_class', 'label', 'diundangkan', 'berlaku_sejak', 'body_pages', 'penjelasan_pages'];

    public function save(UndangUndang $uu, array $input): void
    {
        $source = ImportSource::where('undang_undang_id', $uu->id)->first();
        if (! $uu->source_url) {
            // Keep the stable identity so restoring the source retains drafts and cooldowns.
            $uu->unsetRelation('sourceRegistration');
            return;
        }
        $config = $source?->config ?? [];
        $changedUrl = $source && $source->url !== $uu->source_url;
        if ($changedUrl) {
            // Reviewed law-specific rules must never silently apply to a different document.
            $config = [];
            if (($input['doc_class'] ?? '') === ($source->config['doc_class'] ?? '')) {
                unset($input['doc_class']);
            }
        }
        $config = array_replace($config, $input);
        if (! ($config['doc_class'] ?? '')) {
            $config['doc_class'] = $this->documentClass($uu->source_url) ?? '';
        }
        $slug = $source?->slug ?? 'uu-'.Str::lower(Str::uuid()->toString());
        $config = array_replace($config, [
            'slug' => $slug, 'xlsx_name' => $slug.'.xlsx', 'kode' => $uu->kode,
            'nama' => $uu->nama, 'nama_lengkap' => $uu->nama_lengkap ?: $uu->nama,
            'tahun' => $uu->tahun ?: 0, 'label' => $config['label'] ?? $uu->kode,
            'datahukum_url' => $uu->source_url,
            'bpk_detail_url' => $uu->official_url ?: '', 'bpk_pdf_url' => $uu->official_pdf_url ?: '',
        ]);
        if (! $source || $changedUrl) {
            $config['amendments_from_html'] = true;
        }
        $source ??= new ImportSource(['undang_undang_id' => $uu->id, 'slug' => $slug]);
        $source->fill(['parser' => 'datahukum', 'url' => $uu->source_url, 'config' => $config])->save();
        $uu->unsetRelation('sourceRegistration');
    }

    public function documentClass(string $url): ?string
    {
        $path = parse_url($url, PHP_URL_PATH) ?: '';
        return preg_match('~/UU_(\d+)_Tahun_(\d{4})\.html$~i', $path, $matches)
            ? 'uu-'.$matches[1].$matches[2] : null;
    }

    public function status(ImportSource $source): array
    {
        $uu = $source->undangUndang;
        if (! $uu || $uu->trashed() || ! $uu->is_active) {
            return ['status' => 'inactive', 'status_message' => 'UU tidak aktif atau berada di Sampah.'];
        }
        $url = parse_url($source->url);
        if (! is_array($url) || ($url['scheme'] ?? '') !== 'https'
            || ! in_array(strtolower($url['host'] ?? ''), ['datahukum.com', 'www.datahukum.com'], true)
            || isset($url['user']) || isset($url['pass']) || (isset($url['port']) && $url['port'] !== 443)) {
            return ['status' => 'unsupported', 'status_message' => 'Parser hanya mendukung halaman HTTPS datahukum.com. Sumber tersimpan, tetapi belum dapat diimpor.'];
        }
        if (! preg_match('/^[a-z0-9-]+$/', $source->config['doc_class'] ?? '') || ! $uu->tahun) {
            return ['status' => 'incomplete', 'status_message' => 'Lengkapi tahun UU dan penanda versi asli pada pengaturan sumber.'];
        }
        return ['status' => 'ready', 'status_message' => null];
    }

    public function summary(ImportSource $source): array
    {
        return [
            'id' => $source->id, 'slug' => $source->slug, 'parser' => $source->parser,
            ...$this->status($source),
            'config' => array_intersect_key($source->config, array_flip(self::EDITABLE)),
        ];
    }

    public function snapshot(ImportSource $source): array
    {
        $uu = $source->undangUndang;
        $config = $source->config;
        // Snapshot document metadata, not the mutable law attachment reference.
        if ($uu->official_document) {
            $config['official_pdf_path'] = Storage::disk('local')->path('law-documents/'.$uu->official_document['path']);
        }
        return $config;
    }

    public function document(?array $document, string $id): ?array
    {
        return $document ? [
            'name' => $document['name'], 'size' => $document['size'], 'sha256' => $document['sha256'],
            'download_url' => '/admin/undang-undang/'.$id.'/official-document',
        ] : null;
    }
}
