<?php

namespace App\Services;

use RuntimeException;
use Symfony\Component\Process\Exception\ProcessTimedOutException;
use Symfony\Component\Process\Process;

/**
 * Pembungkus tipis untuk CLI pipeline Python (import-tools/prepare_import.py).
 * Semua argumen dikirim sebagai array (tanpa shell), jadi slug tidak bisa menyisipkan perintah.
 */
class DatahukumPipeline
{
    /**
     * Daftar UU yang sudah dikonfigurasi di import-tools/laws.
     *
     * @return list<array{slug: string, kode: string, nama: string, label: string, datahukum_url: string, bpk_detail_url?: string}>
     */
    public function listSources(): array
    {
        $process = $this->process(['--list', '--json']);
        $process->setTimeout(30);
        try {
            $process->run();
        } catch (ProcessTimedOutException) {
            throw new RuntimeException('Daftar sumber import tidak merespons (waktu habis).');
        }

        if (! $process->isSuccessful()) {
            throw new RuntimeException('Daftar sumber import gagal dimuat: '.$this->tail($process->getErrorOutput() ?: $process->getOutput()));
        }

        $data = json_decode($process->getOutput(), true);
        if (! is_array($data) || ! array_is_list($data)) {
            throw new RuntimeException('Daftar sumber import tidak berupa JSON yang valid.');
        }

        return $data;
    }

    /**
     * Jalankan pipeline untuk satu UU dan kembalikan hasilnya.
     *
     * @return array{exit: int, data: array<string, mixed>|null, stderr: string}
     *
     * @throws ProcessTimedOutException
     */
    public function fetch(string $slug, ?int $previousCount = null): array
    {
        $out = tempnam(sys_get_temp_dir(), 'import_');
        try {
            $args = [$slug, '--json', $out, '--refresh'];
            if ($previousCount !== null && $previousCount > 0) {
                $args[] = '--previous-count';
                $args[] = (string) $previousCount;
            }
            $process = $this->process($args);
            $process->setTimeout((int) config('services.datahukum.timeout'));
            $process->run();

            $raw = is_file($out) ? (string) file_get_contents($out) : '';
            $data = $raw === '' ? null : json_decode($raw, true);

            return [
                'exit' => (int) $process->getExitCode(),
                'data' => is_array($data) ? $data : null,
                'stderr' => $this->tail($process->getErrorOutput()),
            ];
        } finally {
            @unlink($out);
        }
    }

    /** @param list<string> $args */
    private function process(array $args): Process
    {
        $toolsDir = rtrim((string) config('services.datahukum.tools_dir'), '/');
        $script = $toolsDir.'/prepare_import.py';
        if (! is_file($script)) {
            throw new RuntimeException('Pipeline import tidak ditemukan di '.$toolsDir.'. Periksa IMPORT_TOOLS_DIR.');
        }

        $env = ['PYTHONIOENCODING' => 'utf-8', 'PYTHONUNBUFFERED' => '1'];
        if ($cache = config('services.datahukum.cache_dir')) {
            $env['IMPORT_CACHE_DIR'] = (string) $cache;
        }

        return new Process([(string) config('services.datahukum.python'), $script, ...$args], $toolsDir, $env);
    }

    private function tail(string $text, int $length = 500): string
    {
        $text = trim($text);

        return mb_strlen($text) > $length ? '...'.mb_substr($text, -$length) : $text;
    }
}
