<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** Satu pengecekan pembaruan dari sumber (datahukum). Draft sampai admin menerapkan atau membuangnya. */
class ImportRun extends Model
{
    use HasUuids;

    public const QUEUED = 'queued';

    public const RUNNING = 'running';

    public const READY = 'ready';

    public const APPLIED = 'applied';

    public const FAILED = 'failed';

    public const DISCARDED = 'discarded';

    public const NEEDS_CONFIG = 'needs_config';

    /** Status yang menahan run baru untuk UU yang sama. */
    public const ACTIVE_STATUSES = [self::QUEUED, self::RUNNING, self::READY];

    protected $table = 'import_runs';

    protected $fillable = [
        'slug',
        'undang_undang_id',
        'status',
        'requested_by',
        'applied_by',
        'started_at',
        'finished_at',
        'applied_at',
        'error',
        'source_url',
        'html_sha256',
        'unknown_versions',
        'warnings',
        'summary',
    ];

    protected function casts(): array
    {
        return [
            'unknown_versions' => 'array',
            'warnings' => 'array',
            'summary' => 'array',
            'started_at' => 'datetime',
            'finished_at' => 'datetime',
            'applied_at' => 'datetime',
        ];
    }

    public function items(): HasMany
    {
        return $this->hasMany(ImportRunItem::class)->orderBy('sort_key');
    }

    public function requester(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'requested_by')->withTrashed();
    }

    public function applier(): BelongsTo
    {
        return $this->belongsTo(AdminUser::class, 'applied_by')->withTrashed();
    }

    public function undangUndang(): BelongsTo
    {
        return $this->belongsTo(UndangUndang::class);
    }

    /** Bentuk respons API (Contract Run). */
    public function toApi(): array
    {
        $this->loadMissing('requester:id,nama', 'applier:id,nama');
        $summary = $this->summary ?: [];

        return [
            'id' => $this->id,
            'slug' => $this->slug,
            'undang_undang_id' => $this->undang_undang_id,
            'status' => $this->status,
            'requested_by' => $this->requester ? ['id' => $this->requester->id, 'nama' => $this->requester->nama] : null,
            'applied_by' => $this->applier ? ['id' => $this->applier->id, 'nama' => $this->applier->nama] : null,
            'created_at' => $this->created_at?->toISOString(),
            'started_at' => $this->started_at?->toISOString(),
            'finished_at' => $this->finished_at?->toISOString(),
            'applied_at' => $this->applied_at?->toISOString(),
            'error' => $this->error,
            'warnings' => $this->warnings ?? [],
            'unknown_versions' => $this->unknown_versions ?? [],
            'summary' => $summary + [
                'counts' => array_fill_keys(\App\Services\ImportDiffService::CATEGORIES, 0),
                'selected' => 0,
                'total_pasal' => 0,
                'large_change' => false,
                'pdf_flagged' => 0,
            ],
            'source_url' => $this->source_url,
            'html_sha256' => $this->html_sha256,
        ];
    }
}
