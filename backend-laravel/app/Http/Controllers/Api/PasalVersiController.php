<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Pasal;
use App\Models\PasalVersi;
use App\Services\AuditService;
use App\Support\PasalTextNormalizer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Riwayat rumusan pasal yang diisi atau dikoreksi admin secara manual. */
class PasalVersiController extends Controller
{
    public function index(string $pasalId): JsonResponse
    {
        return response()->json(Pasal::withTrashed()->findOrFail($pasalId)->versi()->get());
    }

    public function store(Request $request, string $pasalId, AuditService $audit): JsonResponse
    {
        $pasal = Pasal::with('undangUndang')->findOrFail($pasalId);
        $payload = $this->validated($request);
        $extra = $request->validate([
            'terapkan' => ['sometimes', 'boolean'],
            // Pasal tanpa riwayat: simpan dulu rumusan sekarang sebagai versi asli.
            'simpan_asli' => ['sometimes', 'boolean'],
            'sumber_asli' => ['required_if_accepted:simpan_asli', 'nullable', 'string', 'max:100'],
        ]);

        $versi = DB::transaction(function () use ($request, $audit, $pasal, $payload, $extra) {
            if (($extra['simpan_asli'] ?? false) && ! $pasal->versi()->exists()) {
                $asli = $pasal->versi()->create([
                    'urutan' => 1,
                    'status' => 'asli',
                    'sumber' => $extra['sumber_asli'],
                    'judul_sumber' => $pasal->undangUndang?->nama_lengkap,
                    'naskah_resmi' => $pasal->undangUndang?->official_url,
                    'isi' => $pasal->isi,
                    'penjelasan' => $pasal->penjelasan,
                ]);
                $audit->log($request, 'CREATE', 'pasal_versi', $asli->id, null, $asli);
            }

            $versi = $pasal->versi()->create($payload + ['urutan' => ((int) $pasal->versi()->max('urutan')) + 1]);
            $audit->log($request, 'CREATE', 'pasal_versi', $versi->id, null, $versi);

            if ($extra['terapkan'] ?? false) {
                $this->applyToPasal($request, $audit, $pasal, $versi);
            }

            return $versi;
        });

        return response()->json($versi, 201);
    }

    public function update(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $versi = PasalVersi::with('pasal')->findOrFail($id);
        $payload = $this->validated($request);
        $apply = $request->validate(['terapkan' => ['sometimes', 'boolean']])['terapkan'] ?? false;

        DB::transaction(function () use ($request, $audit, $versi, $payload, $apply) {
            $old = $versi->replicate();
            $versi->update($payload);
            $audit->log($request, 'UPDATE', 'pasal_versi', $versi->id, $old, $versi);

            // Hanya versi terakhir yang mewakili rumusan berlaku.
            $latest = $versi->pasal->versi()->max('urutan');
            if ($apply && $versi->urutan === (int) $latest) {
                $this->applyToPasal($request, $audit, $versi->pasal, $versi);
            }
        });

        return response()->json($versi->fresh());
    }

    public function destroy(Request $request, string $id, AuditService $audit): JsonResponse
    {
        $versi = PasalVersi::findOrFail($id);
        $old = $versi->replicate();
        $versi->delete();
        $audit->log($request, 'DELETE', 'pasal_versi', $id, $old, null);

        return response()->json(['message' => 'Versi riwayat dihapus.']);
    }

    private function validated(Request $request): array
    {
        $request->merge(PasalTextNormalizer::normalizePayload($request->only(['isi', 'penjelasan'])));

        return $request->validate([
            'status' => ['required', Rule::in(PasalVersi::STATUSES)],
            'sumber' => ['required', 'string', 'max:100'],
            'judul_sumber' => ['nullable', 'string'],
            'diundangkan' => ['nullable', 'date_format:Y-m-d'],
            'berlaku_sejak' => ['nullable', 'date_format:Y-m-d'],
            'naskah_resmi' => ['nullable', 'url'],
            'isi' => ['required', 'string'],
            'penjelasan' => ['nullable', 'string'],
        ], [
            'naskah_resmi.url' => 'Link naskah resmi harus berupa URL lengkap (https://...).',
        ]);
    }

    /** Salin rumusan versi ke pasal, sama seperti admin mengedit isi pasal. */
    private function applyToPasal(Request $request, AuditService $audit, Pasal $pasal, PasalVersi $versi): void
    {
        $old = $pasal->replicate();
        $pasal->update([
            'isi' => $versi->isi,
            'penjelasan' => $versi->penjelasan,
            'updated_by' => $request->user()?->id,
        ]);
        $audit->log($request, 'UPDATE', 'pasal', $pasal->id, $old, $pasal);
    }
}
