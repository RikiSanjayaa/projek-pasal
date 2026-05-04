<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class PasalLink extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $table = 'pasal_links';

    protected $fillable = [
        'source_pasal_id',
        'target_pasal_id',
        'keterangan',
        'is_active',
        'created_by',
    ];

    protected function casts(): array
    {
        return ['is_active' => 'boolean'];
    }

    public function sourcePasal(): BelongsTo
    {
        return $this->belongsTo(Pasal::class, 'source_pasal_id');
    }

    public function targetPasal(): BelongsTo
    {
        return $this->belongsTo(Pasal::class, 'target_pasal_id');
    }
}
