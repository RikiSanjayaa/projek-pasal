<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ImportSource extends Model
{
    use HasUuids;

    protected $fillable = ['undang_undang_id', 'slug', 'parser', 'url', 'config'];

    protected function casts(): array
    {
        return ['config' => 'array'];
    }

    public function undangUndang(): BelongsTo
    {
        return $this->belongsTo(UndangUndang::class)->withTrashed();
    }
}
