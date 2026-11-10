<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UndangUndang;
use App\Services\AuditService;
use App\Services\LawSourceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\BinaryFileResponse;
use Throwable;

class UndangUndangController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = UndangUndang::with('sourceRegistration');
        if ($request->boolean('with_trashed')) {
            $query->withTrashed();
        }
        if ($search = $request->query('search')) {
            $query->where(fn ($q) => $q->where('kode', 'ilike', "%{$search}%")->orWhere('nama', 'ilike', "%{$search}%"));
        }
        if ($request->has('is_active')) {
            $query->where('is_active', filter_var($request->query('is_active'), FILTER_VALIDATE_BOOLEAN));
        }
        if ($request->boolean('with_pasal')) {
            $query->with(['pasal' => fn ($query) => $query->select('id', 'undang_undang_id', 'nomor')->orderByNomor()]);
        }
        $rows = $query->orderBy('kode')->paginate(min(200, max(1, (int) $request->query('per_page', 100))));
        return response()->json($rows->through(fn ($uu) => $this->response($uu)));
    }

    public function store(Request $request, AuditService $audit): JsonResponse
    {
        return $this->save($request, new UndangUndang, $audit, false);
    }

    public function show(string $id): JsonResponse
    {
        return response()->json($this->response(UndangUndang::withTrashed()->findOrFail($id)));
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        return $this->save($request, UndangUndang::withTrashed()->findOrFail($id), $audit, true);
    }

    private function save(Request $request, UndangUndang $uu, AuditService $audit, bool $partial): JsonResponse
    {
        $data = $this->validated($request, $partial);
        $documentPath = null;
        try {
            if ($request->hasFile('official_document')) {
                $file = $request->file('official_document');
                if (file_get_contents($file->getRealPath(), false, null, 0, 5) !== '%PDF-') {
                    throw ValidationException::withMessages(['official_document' => 'Berkas harus berupa dokumen PDF asli.']);
                }
                $name = Str::uuid().'.pdf';
                $documentPath = $file->storeAs('law-documents', $name, 'local');
                if (! $documentPath) {
                    throw new \RuntimeException('Dokumen asli gagal disimpan.');
                }
                $document = ['path' => $name, 'name' => $file->getClientOriginalName(), 'size' => $file->getSize(), 'sha256' => hash_file('sha256', $file->getRealPath())];
            } else {
                $document = $request->boolean('remove_official_document') ? null : $uu->official_document;
            }
            DB::transaction(function () use ($request, $uu, $audit, $partial, $data, $document) {
                if ($partial) {
                    $uu->setRawAttributes(UndangUndang::withTrashed()->lockForUpdate()->findOrFail($uu->id)->getAttributes());
                }
                $old = $partial ? $uu->replicate() : null;
                $fields = array_diff_key($data, array_flip(['import_config', 'official_document', 'remove_official_document']));
                $uu->fill($fields);
                if ($request->hasFile('official_document') || $request->boolean('remove_official_document')) {
                    $uu->official_document = $document;
                }
                $uu->save();
                app(LawSourceService::class)->save($uu, $data['import_config'] ?? []);
                $audit->log($request, $partial ? 'UPDATE' : 'CREATE', 'undang_undang', $uu->id, $old, $uu);
            });
        } catch (Throwable $error) {
            if ($documentPath) {
                Storage::disk('local')->delete($documentPath);
            }
            throw $error;
        }
        return response()->json($this->response($uu->fresh()), $partial ? 200 : 201);
    }

    public function document(string $id): BinaryFileResponse
    {
        $uu = UndangUndang::withTrashed()->findOrFail($id);
        $document = $uu->official_document;
        abort_unless($document, 404, 'Dokumen asli belum tersedia.');
        $path = Storage::disk('local')->path('law-documents/'.$document['path']);
        abort_unless(is_file($path), 404, 'Dokumen asli tidak ditemukan.');
        return response()->download($path, $document['name'], ['Content-Type' => 'application/pdf', 'X-Content-Type-Options' => 'nosniff']);
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::findOrFail($id);
        $old = $uu->replicate();
        $uu->update(['is_active' => false]);
        $uu->delete();
        $audit->log($request, 'DELETE', 'undang_undang', $uu->id, $old, $uu);
        return response()->json(['message' => 'Undang-undang dihapus.']);
    }

    public function restore(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $uu = UndangUndang::withTrashed()->findOrFail($id);
        $uu->restore();
        $uu->update(['is_active' => true]);
        $audit->log($request, 'RESTORE', 'undang_undang', $uu->id, null, $uu);
        return response()->json($this->response($uu));
    }

    private function response(UndangUndang $uu): array
    {
        $sources = app(LawSourceService::class);
        $source = $uu->source_url ? $uu->sourceRegistration : null;
        return [...$uu->toArray(), 'official_document' => $sources->document($uu->official_document, $uu->id), 'import_source' => $source ? $sources->summary($source) : null];
    }

    private function validated(Request $request, bool $partial): array
    {
        if (is_string($request->input('import_config'))) {
            try {
                $decoded = json_decode($request->input('import_config'), true, flags: JSON_THROW_ON_ERROR);
            } catch (\JsonException) {
                throw ValidationException::withMessages(['import_config' => 'Konfigurasi sumber tidak valid.']);
            }
            $request->merge(['import_config' => $decoded]);
        }
        $required = $partial ? 'sometimes' : 'required';
        $data = $request->validate([
            'kode' => [$required, 'string', 'max:50'], 'nama' => [$required, 'string', 'max:255'],
            'nama_lengkap' => ['nullable', 'string'], 'deskripsi' => ['nullable', 'string'],
            'tahun' => ['nullable', 'integer', 'between:1000,9999'],
            'official_url' => ['nullable', 'url:https,http', 'max:2000'],
            'source_url' => ['nullable', 'url:https,http', 'max:2000'],
            'official_pdf_url' => ['nullable', 'url:https', 'max:2000'],
            'official_document' => ['nullable', 'file', 'mimetypes:application/pdf', 'max:20480'],
            'remove_official_document' => ['sometimes', 'boolean'], 'is_active' => ['sometimes', 'boolean'],
            'import_config' => ['sometimes', 'array:'.implode(',', LawSourceService::EDITABLE)],
            'import_config.doc_class' => ['nullable', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/'],
            'import_config.label' => ['nullable', 'string', 'max:255'],
            'import_config.diundangkan' => ['nullable', 'date_format:Y-m-d'],
            'import_config.berlaku_sejak' => ['nullable', 'date_format:Y-m-d'],
            'import_config.body_pages' => ['sometimes', 'array', 'size:2'],
            'import_config.body_pages.*' => ['integer', 'min:0', 'max:10000'],
            'import_config.penjelasan_pages' => ['sometimes', 'array', 'size:2'],
            'import_config.penjelasan_pages.*' => ['integer', 'min:0', 'max:10000'],
        ]);
        foreach (['body_pages', 'penjelasan_pages'] as $key) {
            $range = $data['import_config'][$key] ?? [0, 0];
            if (($range[0] === 0) !== ($range[1] === 0) || $range[0] > $range[1]) {
                throw ValidationException::withMessages(['import_config.'.$key => 'Rentang halaman harus berurutan atau keduanya 0.']);
            }
        }
        $pdf = $data['official_pdf_url'] ?? null;
        if ($pdf) {
            $url = parse_url($pdf);
            if (! in_array(strtolower($url['host'] ?? ''), ['peraturan.bpk.go.id', 'peraturan.go.id', 'jdih.setneg.go.id'], true)
                || isset($url['user']) || isset($url['pass']) || (isset($url['port']) && $url['port'] !== 443)) {
                throw ValidationException::withMessages(['official_pdf_url' => 'Gunakan PDF dari peraturan.bpk.go.id, peraturan.go.id, atau jdih.setneg.go.id; situs lain dapat memakai unggahan PDF.']);
            }
        }
        return $data;
    }
}
