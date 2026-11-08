<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
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
        'source_snapshot',
        'created_by',
        'updated_by',
    ];

    /**
     * source_snapshot hanya untuk perbandingan import; tidak ikut respons API maupun sync mobile.
     * Hanya import datahukum (ApplyImportRun) yang mengisinya, import xlsx tidak menyentuhnya.
     */
    protected $hidden = ['source_snapshot'];

    protected function casts(): array
    {
        return [
            'source_snapshot' => 'array',
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

    /**
     * Urutan nomor pasal seperti di naskah: 1, 2, 10, 599, 599A, 600.
     * Nomor tetap teks karena pasal sisipan memakai huruf (599A), jadi urutan string biasa salah (1, 10, 100).
     */
    public function scopeOrderByNomor(Builder $query, string $direction = 'asc'): Builder
    {
        $direction = strtolower($direction) === 'desc' ? 'desc' : 'asc';
        $column = $query->qualifyColumn('nomor');
        $number = $query->getConnection()->getDriverName() === 'pgsql'
            ? "NULLIF(substring({$column} from '^[0-9]+'), '')::int"
            : "CAST({$column} AS INTEGER)";

        return $query->orderByRaw("{$number} {$direction} NULLS LAST")->orderBy($column, $direction);
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

    /** Riwayat rumusan, urut dari yang paling lama. */
    public function versi(): HasMany
    {
        return $this->hasMany(PasalVersi::class)->orderBy('urutan');
    }

    /** Versi terakhir = rumusan yang berlaku; dipakai untuk link naskah resmi saat verifikasi. */
    public function versiTerakhir(): HasOne
    {
        // Bukan ofMany(): Laravel menambah max(id) sebagai pemecah seri, dan Postgres tidak punya max(uuid).
        // Eager load hasOne mengambil baris pertama per pasal, jadi urutan menurun memberi versi terakhir.
        return $this->hasOne(PasalVersi::class)->orderByDesc('urutan');
    }
}
