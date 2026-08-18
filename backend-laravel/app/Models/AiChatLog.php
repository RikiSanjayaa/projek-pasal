<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AiChatLog extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'mobile_user_id',
        'question',
        'normalized_question',
        'answer',
        'model',
        'sources',
        'metadata',
        'response_ms',
    ];

    protected function casts(): array
    {
        return [
            'sources' => 'array',
            'metadata' => 'array',
            'response_ms' => 'integer',
        ];
    }
}
