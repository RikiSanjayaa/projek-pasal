<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ai_chat_logs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('mobile_user_id')->nullable();
            $table->text('question');
            $table->text('normalized_question');
            $table->text('answer')->nullable();
            $table->string('model', 120)->nullable();
            $table->jsonb('sources')->nullable();
            $table->jsonb('metadata')->nullable();
            $table->unsignedInteger('response_ms')->nullable();
            $table->timestampsTz();

            $table->foreign('mobile_user_id')
                ->references('id')
                ->on('mobile_users')
                ->nullOnDelete();
            $table->index('mobile_user_id');
            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_chat_logs');
    }
};
