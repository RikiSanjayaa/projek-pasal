<?php

namespace App\Jobs;

use App\Models\ImportRun;
use App\Services\ImportRunProcessor;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Throwable;

/** Mengambil dan membandingkan satu sumber datahukum di queue `imports`. Hanya menulis draft run. */
class RunDatahukumImport implements ShouldQueue
{
    use Queueable;

    /** Harus lebih besar dari services.datahukum.timeout dan lebih kecil dari retry_after queue. */
    public int $timeout = 900;

    /** Run yang gagal tidak diulang otomatis; admin menekan Periksa lagi. */
    public int $tries = 1;

    public function __construct(public readonly string $runId)
    {
        $this->onQueue('imports');
    }

    public function handle(ImportRunProcessor $processor): void
    {
        $run = ImportRun::find($this->runId);
        if (! $run || $run->status !== ImportRun::QUEUED) {
            return;
        }

        $processor->process($run);
    }

    public function failed(?Throwable $exception): void
    {
        $run = ImportRun::find($this->runId);
        if ($run && in_array($run->status, [ImportRun::QUEUED, ImportRun::RUNNING], true)) {
            $run->update([
                'status' => ImportRun::FAILED,
                'finished_at' => now(),
                'error' => 'Import terhenti karena kesalahan sistem'.($exception ? ': '.mb_substr($exception->getMessage(), 0, 300) : '.'),
            ]);
        }
    }
}
