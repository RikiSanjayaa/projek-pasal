<?php

namespace App\Support;

class PasalTextNormalizer
{
    private const TYPO_REPLACEMENTS = [
        '/\bPTIESIDEN\b/i' => 'PRESIDEN',
        '/\bPRESID[BEFN]\b/i' => 'PRESIDEN',
        '/\bREPUB[UI]K\b/i' => 'REPUBLIK',
        '/\btqjuh\b|\btqiuh\b/i' => 'tujuh',
        '/\btahy\b|\btahur\b|\btatun\b/i' => 'tahun',
        '/\btqiuan\b|\btqjuan\b/i' => 'tujuan',
        '/\bKetenluan\b/i' => 'Ketentuan',
        '/\bUndang-\s+Undang\b/i' => 'Undang-Undang',
        '/\bpaling\s+ba[ny]{1,3}ak\b/i' => 'paling banyak',
        '/\bpaling\s+la[rm]a\b/i' => 'paling lama',
        '/\bl0(?=\s*%|\s*persen\b)/i' => '10',
    ];

    public static function normalizePayload(array $payload): array
    {
        if (array_key_exists('nomor', $payload)) {
            $payload['nomor'] = self::normalizeNomor($payload['nomor']);
        }

        if (array_key_exists('judul', $payload)) {
            $judul = self::applyCommonCorrections($payload['judul']);
            $payload['judul'] = trim((string) preg_replace('/\s+/', ' ', $judul)) ?: null;
        }

        if (array_key_exists('isi', $payload)) {
            $payload['isi'] = self::normalizeBody($payload['isi']);
        }

        if (array_key_exists('penjelasan', $payload)) {
            $payload['penjelasan'] = self::normalizeBody($payload['penjelasan']) ?: null;
        }

        return $payload;
    }

    public static function normalizeNomor(mixed $value): string
    {
        $nomor = trim((string) preg_replace('/\s+/', ' ', (string) $value));
        $nomor = preg_replace('/^pasal\s+/i', '', $nomor) ?? $nomor;
        $nomor = preg_replace('/^nom[oe]r\s+/i', '', $nomor) ?? $nomor;
        $nomor = preg_replace('/^([0-9]{1,4})\s+([a-z])$/i', '$1$2', $nomor) ?? $nomor;

        return trim($nomor, " \t\n\r\0\x0B.,;:");
    }

    public static function normalizeBody(mixed $value): string
    {
        $text = self::applyCommonCorrections($value);
        $text = str_replace(["\r\n", "\r", "\u{00A0}", '|', "\u{00A6}", "\u{00A2}", "\u{2022}", "\u{00B7}"], ["\n", "\n", ' ', ' ', ' ', ' ', ' ', ' '], $text);
        $text = preg_replace('/\(\s*[Il]\s*\)/', '(1)', $text) ?? $text;
        $text = preg_replace('/\s+([,.;:])/', '$1', $text) ?? $text;
        $text = preg_replace('/([\(\[])\s+/', '$1', $text) ?? $text;
        $text = preg_replace('/\s+([)\]])/', '$1', $text) ?? $text;
        $text = preg_replace('/[ \t]+((?:\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+)/i', "\n$1", $text) ?? $text;

        $lines = array_values(array_filter(array_map(
            fn ($line) => trim((string) preg_replace('/[ \t]+/', ' ', $line)),
            explode("\n", $text),
        ), function ($line) {
            if ($line === '') {
                return false;
            }
            if (preg_match('/^[-*_]{2,}/', $line)) {
                return false;
            }
            if (preg_match('/^PRESIDEN\s+REPUBLIK\s+INDONESIA$/i', $line)) {
                return false;
            }
            if (preg_match('/^KUHP\s*\(Kitab\s+Undang-Undang\s+Hukum\s+Pidana\)/i', $line)) {
                return false;
            }
            if (preg_match('/^\d+\s*$/', $line)) {
                return false;
            }

            return true;
        }));

        $blocks = [];
        foreach ($lines as $line) {
            if (empty($blocks) || self::startsNewBlock($line)) {
                $blocks[] = $line;
            } else {
                $blocks[count($blocks) - 1] = trim((string) preg_replace('/[ \t]+/', ' ', $blocks[count($blocks) - 1].' '.$line));
            }
        }

        return trim((string) preg_replace("/\n{3,}/", "\n\n", implode("\n", $blocks)));
    }

    public static function applyCommonCorrections(mixed $value): string
    {
        $text = (string) $value;

        foreach (self::TYPO_REPLACEMENTS as $pattern => $replacement) {
            $text = preg_replace($pattern, $replacement, $text) ?? $text;
        }

        return $text;
    }

    private static function startsNewBlock(string $line): bool
    {
        return (bool) preg_match(
            '/^(Pasal|Nom[oe]r)\s+[0-9]|^(Penjelasan|Pendapat\s+Ahli|Catatan\s+Ahli)\s*:?|^(\([0-9ivxlcdm]+[a-z]?\)|[0-9]+[a-z]?\.|\([a-z]\)|[a-z]\.)\s+/i',
            $line,
        );
    }
}
