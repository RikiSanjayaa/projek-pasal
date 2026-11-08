<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Hasil perbandingan satu pasal dalam satu run, beserta pilihan admin untuk menerapkannya. */
class ImportRunItem extends Model
{
    use HasUuids;

    protected $table = 'import_run_items';

    protected $fillable = [
        'import_run_id',
        'pasal_id',
        'nomor',
        'category',
        'selected',
        'base',
        'current',
        'incoming',
        'incoming_riwayat',
        'current_riwayat',
        'incoming_links',
        'review',
        'notes',
        'sort_key',
        'applied_at',
    ];

    protected function casts(): array
    {
        return [
            'selected' => 'boolean',
            'base' => 'array',
            'current' => 'array',
            'incoming' => 'array',
            'incoming_riwayat' => 'array',
            'current_riwayat' => 'array',
            'incoming_links' => 'array',
            'review' => 'array',
            'notes' => 'array',
            'sort_key' => 'integer',
            'applied_at' => 'datetime',
        ];
    }

    public function run(): BelongsTo
    {
        return $this->belongsTo(ImportRun::class, 'import_run_id');
    }

    /** Bentuk respons API (Contract Item). incoming_links hanya dipakai saat apply. */
    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'nomor' => $this->nomor,
            'pasal_id' => $this->pasal_id,
            'category' => $this->category,
            'selected' => $this->selected,
            'base' => $this->base,
            'current' => $this->current,
            'incoming' => $this->incoming,
            'incoming_riwayat' => $this->incoming_riwayat,
            'current_riwayat' => $this->current_riwayat,
            'review' => $this->review,
            'notes' => $this->notes ?? [],
            'applied_at' => $this->applied_at?->toISOString(),
        ];
    }
}
