<?php

namespace App\Services;

use App\Models\AdminUser;
use App\Models\AuditLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;

class AuditService
{
    public function log(Request $request, string $action, string $table, ?string $recordId = null, mixed $old = null, mixed $new = null, array $metadata = []): void
    {
        $actor = $request->user();
        $admin = $actor instanceof AdminUser ? $actor : null;

        AuditLog::create([
            'admin_id' => $admin?->id,
            'admin_email' => $admin?->email,
            'actor_type' => $actor ? class_basename($actor) : 'system',
            'actor_id' => $actor?->id,
            'action' => strtoupper($action),
            'table_name' => $table,
            'record_id' => $recordId,
            'old_data' => $old instanceof Model ? $old->getOriginal() : $old,
            'new_data' => $new instanceof Model ? $new->toArray() : $new,
            'metadata' => $metadata ?: null,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);
    }
}
