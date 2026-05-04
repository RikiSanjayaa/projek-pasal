<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Pasal extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $table = 'pasal';

    protected $fillable = [
        'undang_undang_id',
        'nomor',
        'judul',
        'isi',
        'penjelasan',
        'keywords',
        'is_active',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function getKeywordsAttribute(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        $trimmed = trim((string) $value, '{}');
        if ($trimmed === '') {
            return [];
        }

        return array_map(fn ($item) => trim($item, '"'), str_getcsv($trimmed));
    }

    public function setKeywordsAttribute(mixed $value): void
    {
        $items = is_array($value) ? $value : array_filter(array_map('trim', explode(',', (string) $value)));
        $escaped = array_map(fn ($item) => '"'.str_replace('"', '\"', (string) $item).'"', $items);
        $this->attributes['keywords'] = '{'.implode(',', $escaped).'}';
    }

    public function undangUndang(): BelongsTo
    {
        return $this->belongsTo(UndangUndang::class);
    }
}
