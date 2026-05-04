<?php

namespace App\Services;

use App\Models\Pasal;
use App\Models\PasalLink;
use App\Models\UndangUndang;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

class SyncService
{
    public function hasUpdates(?string $since): bool
    {
        if (! $since) {
            return true;
        }

        $time = CarbonImmutable::parse($since);

        return UndangUndang::withTrashed()->where('updated_at', '>', $time)->orWhere('deleted_at', '>', $time)->exists()
            || Pasal::withTrashed()->where('updated_at', '>', $time)->orWhere('deleted_at', '>', $time)->exists()
            || PasalLink::withTrashed()->where('updated_at', '>', $time)->orWhere('deleted_at', '>', $time)->exists();
    }

    public function updates(?string $since): array
    {
        $time = $since ? CarbonImmutable::parse($since) : null;

        return [
            'server_time' => now()->toISOString(),
            'updated_uu' => $this->updated(UndangUndang::class, $time)->values(),
            'updated_pasal' => $this->updated(Pasal::class, $time)->values(),
            'updated_links' => $this->updated(PasalLink::class, $time)->values(),
            'deleted_uu_ids' => $this->deletedIds(UndangUndang::class, $time),
            'deleted_pasal_ids' => $this->deletedIds(Pasal::class, $time),
            'deleted_link_ids' => $this->deletedIds(PasalLink::class, $time),
        ];
    }

    public function full(): array
    {
        return [
            'server_time' => now()->toISOString(),
            'undang_undang' => UndangUndang::query()->where('is_active', true)->orderByDesc('tahun')->get(),
            'pasal' => Pasal::query()->where('is_active', true)->get(),
            'pasal_links' => PasalLink::query()->where('is_active', true)->get(),
        ];
    }

    private function updated(string $model, ?CarbonImmutable $time): Collection
    {
        $query = $model::withTrashed()->where('is_active', true)->whereNull('deleted_at');
        if ($time) {
            $query->where('updated_at', '>', $time);
        }

        return $query->get();
    }

    private function deletedIds(string $model, ?CarbonImmutable $time): array
    {
        $query = $model::withTrashed()->where(function ($query) {
            $query->where('is_active', false)->orWhereNotNull('deleted_at');
        });
        if ($time) {
            $query->where(function ($query) use ($time) {
                $query->where('updated_at', '>', $time)->orWhere('deleted_at', '>', $time);
            });
        }

        return $query->pluck('id')->all();
    }
}
