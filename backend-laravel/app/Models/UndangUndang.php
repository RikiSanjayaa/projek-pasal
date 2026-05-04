<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class UndangUndang extends Model
{
    use HasFactory, HasUuids, SoftDeletes;

    protected $table = 'undang_undang';

    protected $fillable = ['kode', 'nama', 'nama_lengkap', 'deskripsi', 'tahun', 'is_active'];

    protected function casts(): array
    {
        return [
            'tahun' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function pasal(): HasMany
    {
        return $this->hasMany(Pasal::class);
    }
}
