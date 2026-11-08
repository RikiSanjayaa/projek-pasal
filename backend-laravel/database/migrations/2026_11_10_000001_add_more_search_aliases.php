<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Alias tambahan dari uji pencarian (November 2026): istilah sehari-hari yang tidak ada di teks
 * pasal sama sekali, jadi tanpa alias hasilnya kosong. Setiap alias menunjuk frasa yang memang ada
 * di teks KUHP, KUHAP, atau KUHPerdata. Istilah yang sudah dibuat admin tidak disentuh.
 */
return new class extends Migration
{
    private const NOTES = 'Alias bawaan (uji pencarian November 2026).';

    private const ALIASES = [
        ['kumpul kebo', ['hidup bersama sebagai suami istri'], 'Pidana umum'],
        ['santet', ['kekuatan gaib'], 'Pidana umum'],
        ['restorative justice', ['keadilan restoratif'], 'Acara pidana'],
        ['wanprestasi', ['lalai memenuhi perikatan', 'dinyatakan lalai'], 'Perdata'],
        ['ingkar janji', ['lalai memenuhi perikatan', 'dinyatakan lalai'], 'Perdata'],
        ['pmh', ['perbuatan melawan hukum'], 'Perdata'],
        ['hak asuh anak', ['kekuasaan orang tua', 'perwalian'], 'Perdata'],
        ['nikah', ['perkawinan'], 'Perdata'],
    ];

    public function up(): void
    {
        foreach (self::ALIASES as [$term, $aliases, $category]) {
            $exists = DB::table('search_aliases')->whereRaw('lower(term) = ?', [$term])->exists();
            if ($exists) {
                continue;
            }
            DB::table('search_aliases')->insert([
                'id' => (string) Str::uuid(),
                'term' => $term,
                'aliases' => json_encode($aliases, JSON_UNESCAPED_UNICODE),
                'category' => $category,
                'notes' => self::NOTES,
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        DB::table('search_aliases')->where('notes', self::NOTES)->delete();
    }
};
