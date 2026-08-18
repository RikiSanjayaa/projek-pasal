<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SearchAlias extends Model
{
    use HasFactory, HasUuids;

    protected $fillable = [
        'term',
        'aliases',
        'category',
        'notes',
        'is_active',
        'created_by',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'aliases' => 'array',
            'is_active' => 'boolean',
        ];
    }
}
