<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AiChatLog;
use App\Services\GeminiService;
use App\Services\LegalContextService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Log;
use Illuminate\Http\Request;
use Throwable;

class AiChatController extends Controller
{
    public function mobileChat(
        Request $request,
        LegalContextService $contextService,
        GeminiService $gemini,
    ): JsonResponse {
        $payload = $request->validate([
            'question' => ['required', 'string', 'min:3', 'max:1000'],
        ], [
            'question.required' => 'Pertanyaan wajib diisi.',
            'question.min' => 'Pertanyaan terlalu pendek.',
            'question.max' => 'Pertanyaan terlalu panjang.',
        ]);

        $startedAt = microtime(true);
        $question = trim($payload['question']);
        $sources = $contextService->relevantPasal($question, 6);
        $answer = null;
        $metadata = [
            'source_count' => count($sources),
            'configured' => $gemini->isConfigured(),
        ];

        try {
            $answer = $gemini->answer(
                $question,
                $sources,
                $contextService->buildContextText($sources),
            );
        } catch (Throwable $e) {
            report($e);
            $metadata['error'] = $e->getMessage();
            $answer = 'Asisten sedang tidak bisa menghubungi layanan AI. Coba lagi nanti, atau gunakan pencarian pasal biasa terlebih dahulu.';
        }

        $responseMs = (int) round((microtime(true) - $startedAt) * 1000);

        try {
            AiChatLog::create([
                'mobile_user_id' => $request->user()?->id,
                'question' => $question,
                'normalized_question' => $contextService->normalize($question),
                'answer' => $answer,
                'model' => $gemini->model(),
                'sources' => $sources,
                'metadata' => $metadata,
                'response_ms' => $responseMs,
            ]);
        } catch (Throwable $e) {
            Log::warning('AI chat log could not be saved.', [
                'mobile_user_id' => $request->user()?->id,
                'message' => $e->getMessage(),
            ]);
        }

        return response()->json([
            'answer' => $answer,
            'sources' => $sources,
            'model' => $gemini->model(),
            'response_ms' => $responseMs,
            'is_configured' => $gemini->isConfigured(),
        ]);
    }
}
