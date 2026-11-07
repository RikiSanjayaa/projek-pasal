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

    public const UNVERIFIED = 'perlu_verifikasi';

    public const VERIFIED = 'terverifikasi';

    protected $fillable = [
        'undang_undang_id',
        'nomor',
        'judul',
        'isi',
        'penjelasan',
        'keywords',
        'is_active',
        'verification_status',
        'verified_by',
        'verified_at',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'verified_at' => 'datetime',
        ];
    }

    /** Atribut untuk menandai pasal sudah dicek admin terhadap naskah resmi. */
    public static function verifiedBy(?string $adminId): array
    {
        return ['verification_status' => self::VERIFIED, 'verified_by' => $adminId, 'verified_at' => now()];
    }

    /** Atribut untuk mengembalikan pasal ke antrean verifikasi. */
    public static function unverified(): array
    {
        return ['verification_status' => self::UNVERIFIED, 'verified_by' => null, 'verified_at' => null];
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

    public function verifier(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'verified_by');
    }
}
