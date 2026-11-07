<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Satu rumusan pasal pada satu titik riwayat (asli, diubah, disisipkan, dihapus). */
class PasalVersi extends Model
{
    use HasUuids;

    protected $table = 'pasal_versi';

    public const STATUSES = ['asli', 'diubah', 'disisipkan', 'dihapus'];

    protected $fillable = [
        'pasal_id',
        'urutan',
        'status',
        'sumber',
        'judul_sumber',
        'diundangkan',
        'berlaku_sejak',
        'naskah_resmi',
        'isi',
        'penjelasan',
    ];

    protected function casts(): array
    {
        return [
            'urutan' => 'integer',
            'diundangkan' => 'date:Y-m-d',
            'berlaku_sejak' => 'date:Y-m-d',
        ];
    }

    public function pasal(): BelongsTo
    {
        return $this->belongsTo(Pasal::class);
    }
}
