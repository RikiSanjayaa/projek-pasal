<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    use HasFactory, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'admin_id',
        'admin_email',
        'actor_type',
        'actor_id',
        'action',
        'table_name',
        'record_id',
        'old_data',
        'new_data',
        'metadata',
        'ip_address',
        'user_agent',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'old_data' => 'array',
            'new_data' => 'array',
            'metadata' => 'array',
            'created_at' => 'datetime',
        ];
    }
}
