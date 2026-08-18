<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class GeminiService
{
    public function isConfigured(): bool
    {
        return filled(config('services.gemini.api_key'));
    }

    public function model(): string
    {
        return (string) config('services.gemini.model', 'gemini-3.1-flash-lite');
    }

    public function answer(string $question, array $sources, string $contextText): string
    {
        if (! $this->isConfigured()) {
            return 'Asisten AI belum dikonfigurasi di server. Admin perlu mengisi GEMINI_API_KEY terlebih dahulu.';
        }

        if (empty($sources)) {
            return 'Saya belum menemukan pasal yang cukup relevan di database aplikasi untuk menjawab pertanyaan ini.';
        }

        $response = Http::timeout((int) config('services.gemini.timeout', 20))
            ->retry(1, 250)
            ->withHeaders([
                'x-goog-api-key' => config('services.gemini.api_key'),
                'Content-Type' => 'application/json',
            ])
            ->post('https://generativelanguage.googleapis.com/v1beta/interactions', [
                'model' => $this->model(),
                'system_instruction' => $this->systemInstruction(),
                'input' => $this->buildInput($question, $contextText),
                'generation_config' => [
                    'temperature' => 0.2,
                    'top_p' => 0.8,
                    'max_output_tokens' => 900,
                    'thinking_level' => 'low',
                ],
            ])
            ->throw();

        return $this->extractOutputText($response->json());
    }

    private function systemInstruction(): string
    {
        return <<<'TEXT'
Anda adalah Asisten CariPasal. Jawab dalam Bahasa Indonesia yang jelas, natural, dan ringkas.
Gunakan HANYA konteks pasal yang diberikan oleh sistem. Jangan menambah pasal, aturan, atau fakta yang tidak ada di konteks.
Jika konteks tidak cukup, katakan bahwa data di aplikasi belum cukup untuk menjawab.
Jangan menyatakan jawaban sebagai nasihat hukum resmi. Gunakan frasa seperti "berdasarkan data di aplikasi" dan "perlu dicek unsur perkaranya".
Selalu tutup jawaban dengan bagian "Rujukan:" berisi pasal dan undang-undang yang relevan dari konteks.
TEXT;
    }

    private function buildInput(string $question, string $contextText): string
    {
        return <<<TEXT
Pertanyaan pengguna:
{$question}

Konteks pasal dari database aplikasi:
{$contextText}

Tugas:
1. Jawab pertanyaan pengguna berdasarkan konteks di atas.
2. Jelaskan kemungkinan pasal yang terkait dan unsur pentingnya.
3. Jika ada beberapa kemungkinan, bedakan secara sederhana.
4. Jangan melebihi 5 paragraf pendek.
TEXT;
    }

    private function extractOutputText(array $payload): string
    {
        if (isset($payload['output_text']) && is_string($payload['output_text'])) {
            return trim($payload['output_text']);
        }

        if (isset($payload['outputText']) && is_string($payload['outputText'])) {
            return trim($payload['outputText']);
        }

        $parts = data_get($payload, 'candidates.0.content.parts', []);
        if (is_array($parts)) {
            $text = collect($parts)
                ->map(fn ($part) => is_array($part) ? ($part['text'] ?? '') : '')
                ->filter()
                ->implode("\n");
            if (trim($text) !== '') {
                return trim($text);
            }
        }

        $stepText = collect($payload['steps'] ?? [])
            ->filter(fn ($step) => is_array($step) && ($step['type'] ?? null) === 'model_output')
            ->flatMap(fn ($step) => is_array($step['content'] ?? null) ? $step['content'] : [])
            ->map(fn ($content) => is_array($content) ? ($content['text'] ?? '') : '')
            ->filter()
            ->implode("\n");
        if (trim($stepText) !== '') {
            return trim($stepText);
        }

        throw new RuntimeException('Response Gemini tidak berisi teks jawaban.');
    }
}
