<?php

namespace Tests\Feature;

use App\Models\AdminDevice;
use App\Models\AdminUser;
use App\Models\MobileUser;
use App\Models\UserDevice;
use App\Services\UserDeviceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\PersonalAccessToken;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Akses mobile untuk admin/super_admin dan user biasa. Butuh PostgreSQL (migrasi memakai SQL Postgres).
 */
class MobileAccessTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD = 'Rahasia-12345';

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-11-08 10:00:00', 'UTC'));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    // ---- helpers -------------------------------------------------------------------------

    private function admin(string $role = 'admin', string $email = 'admin@example.test', ?string $password = null, bool $active = true): AdminUser
    {
        return AdminUser::create([
            'email' => $email,
            'password' => $password ?? self::PASSWORD,
            'nama' => 'Admin '.$role,
            'role' => $role,
            'is_active' => $active,
        ]);
    }

    private function mobileUser(string $email = 'user@example.test', ?string $password = null, mixed $expiresAt = null, bool $active = true): MobileUser
    {
        return MobileUser::create([
            'email' => $email,
            'password' => $password ?? self::PASSWORD,
            'nama' => 'User Mobile',
            'is_active' => $active,
            'expires_at' => $expiresAt ?? now()->addYears(3),
        ]);
    }

    private function api(string $method, string $uri, ?string $token = null, ?string $deviceId = null, array $data = []): TestResponse
    {
        // Guard Sanctum menyimpan user per request cycle; reset agar tiap panggilan memakai token barunya.
        $this->app['auth']->forgetGuards();

        $headers = ['Accept' => 'application/json'];
        if ($token) {
            $headers['Authorization'] = 'Bearer '.$token;
        }
        if ($deviceId) {
            $headers['X-Device-ID'] = $deviceId;
        }

        return $this->json($method, $uri, $data, $headers);
    }

    private function mobileLogin(string $email, string $deviceId, ?string $password = null, ?string $name = null): TestResponse
    {
        $this->app['auth']->forgetGuards();

        return $this->postJson('/api/mobile/login', [
            'email' => $email,
            'password' => $password ?? self::PASSWORD,
            'device_id' => $deviceId,
            'device_name' => $name ?? 'Perangkat '.$deviceId,
            'platform' => 'android',
        ]);
    }

    private function mobileToken(string $email, string $deviceId): string
    {
        return $this->mobileLogin($email, $deviceId)->assertOk()->json('token');
    }

    private function dashboardToken(string $email, ?string $password = null): string
    {
        $this->app['auth']->forgetGuards();

        return $this->postJson('/api/admin/login', ['email' => $email, 'password' => $password ?? self::PASSWORD])
            ->assertOk()->json('token');
    }

    // ---- login & access metadata ---------------------------------------------------------

    #[DataProvider('adminRoles')]
    public function test_admin_roles_login_on_mobile_with_no_expiry_and_30_day_lease(string $role): void
    {
        $admin = $this->admin($role);

        $response = $this->mobileLogin($admin->email, 'dev-1')->assertOk();

        $response->assertJsonPath('user.id', $admin->id)
            ->assertJsonPath('user.role', $role)
            ->assertJsonPath('access.account_type', 'admin')
            ->assertJsonPath('access.expires_at', null)
            ->assertJsonPath('device.device_id', 'dev-1')
            ->assertJsonMissingPath('user.password');
        $this->assertEquals(now()->addDays(30)->getTimestamp(), Carbon::parse($response->json('access.offline_access_until'))->getTimestamp());
        $this->assertDatabaseHas('admin_devices', ['admin_user_id' => $admin->id, 'device_id' => 'dev-1', 'is_active' => true]);

        $token = PersonalAccessToken::findToken($response->json('token'));
        $this->assertSame(['mobile'], $token->abilities);
        $this->assertSame(UserDeviceService::tokenName('dev-1'), $token->name);
    }

    public static function adminRoles(): array
    {
        return ['admin' => ['admin'], 'super_admin' => ['super_admin']];
    }

    public function test_login_without_account_type_selects_admin_then_mobile_by_credentials(): void
    {
        $admin = $this->admin();
        $user = $this->mobileUser();

        $this->postJson('/api/mobile/login', ['email' => $admin->email, 'password' => self::PASSWORD, 'device_id' => 'dev-1'])
            ->assertOk()->assertJsonPath('user.id', $admin->id)->assertJsonPath('access.account_type', 'admin');
        $this->postJson('/api/mobile/login', ['email' => $user->email, 'password' => self::PASSWORD, 'device_id' => 'dev-1'])
            ->assertOk()->assertJsonPath('user.id', $user->id)->assertJsonPath('access.account_type', 'mobile');
        $this->postJson('/api/mobile/login', ['email' => $user->email, 'password' => 'salah-salah', 'device_id' => 'dev-2'])
            ->assertStatus(422);
    }

    public function test_mobile_user_lease_is_capped_by_account_expiry_and_keeps_expiry(): void
    {
        $soon = $this->mobileUser('soon@example.test', null, now()->addDays(5));
        $later = $this->mobileUser('later@example.test', null, now()->addYears(1));

        $response = $this->mobileLogin($soon->email, 'dev-1')->assertOk();
        $this->assertEquals($soon->expires_at->getTimestamp(), Carbon::parse($response->json('access.expires_at'))->getTimestamp());
        $this->assertEquals($soon->expires_at->getTimestamp(), Carbon::parse($response->json('access.offline_access_until'))->getTimestamp());

        $response = $this->mobileLogin($later->email, 'dev-1')->assertOk();
        $this->assertEquals($later->expires_at->getTimestamp(), Carbon::parse($response->json('access.expires_at'))->getTimestamp());
        $this->assertEquals(now()->addDays(30)->getTimestamp(), Carbon::parse($response->json('access.offline_access_until'))->getTimestamp());

        $this->assertSame(['mobile'], PersonalAccessToken::findToken($response->json('token'))->abilities);
        $this->assertDatabaseHas('user_devices', ['device_id' => 'dev-1', 'is_active' => true]);
    }

    public function test_expired_or_inactive_mobile_user_cannot_login_but_expiry_never_applies_to_admin(): void
    {
        $expired = $this->mobileUser('expired@example.test', null, now()->subMinute());
        $inactive = $this->mobileUser('inactive@example.test', null, null, false);
        $admin = $this->admin();
        $inactiveAdmin = $this->admin('admin', 'off@example.test', null, false);

        $this->mobileLogin($expired->email, 'dev-1')->assertStatus(422);
        $this->mobileLogin($inactive->email, 'dev-1')->assertStatus(422);
        $this->mobileLogin($inactiveAdmin->email, 'dev-1')->assertStatus(422);
        $this->mobileLogin($admin->email, 'dev-1', 'salah-salah')->assertStatus(422);

        Carbon::setTestNow(now()->addYears(10));
        $token = $this->mobileToken($admin->email, 'dev-1');
        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertOk()->assertJsonPath('access.expires_at', null);
    }

    public function test_same_email_with_different_passwords_selects_the_matching_principal(): void
    {
        $admin = $this->admin('admin', 'sama@example.test', 'Password-Admin-1');
        $user = $this->mobileUser('sama@example.test', 'Password-Mobile-1');

        $this->mobileLogin('sama@example.test', 'dev-1', 'Password-Admin-1')->assertOk()
            ->assertJsonPath('user.id', $admin->id)->assertJsonPath('access.account_type', 'admin');
        $this->mobileLogin('sama@example.test', 'dev-1', 'Password-Mobile-1')->assertOk()
            ->assertJsonPath('user.id', $user->id)->assertJsonPath('access.account_type', 'mobile');
        $this->mobileLogin('sama@example.test', 'dev-2', 'Password-Lain-1')->assertStatus(422);
    }

    public function test_same_email_and_same_password_selects_admin(): void
    {
        $admin = $this->admin('admin', 'sama@example.test');
        $this->mobileUser('sama@example.test');

        $this->mobileLogin('sama@example.test', 'dev-1')->assertOk()
            ->assertJsonPath('user.id', $admin->id)->assertJsonPath('access.account_type', 'admin');
        $this->assertDatabaseCount('user_devices', 0);
    }

    public function test_disabled_matching_admin_does_not_fall_back_to_mobile_identity(): void
    {
        $this->admin('admin', 'sama@example.test', null, false);
        $this->mobileUser('sama@example.test');

        $this->mobileLogin('sama@example.test', 'dev-1')->assertStatus(422);
        $this->assertDatabaseCount('admin_devices', 0);
        $this->assertDatabaseCount('user_devices', 0);
    }

    public function test_password_reset_without_type_sends_separate_typed_links_for_each_active_identity(): void
    {
        $this->admin('admin', 'sama@example.test', 'Password-Admin-1');
        $this->mobileUser('sama@example.test', 'Password-Mobile-1');

        $sent = [];
        Event::listen(MessageSent::class, function (MessageSent $event) use (&$sent) {
            $sent[] = ['to' => array_map(fn ($address) => $address->getAddress(), $event->message->getTo()), 'html' => (string) $event->message->getHtmlBody()];
        });

        $this->postJson('/api/password/forgot', ['email' => 'sama@example.test'])->assertOk();

        $this->assertCount(2, $sent);
        $types = [];
        foreach ($sent as $mail) {
            $this->assertSame(['sama@example.test'], array_map('strtolower', $mail['to']));
            preg_match('/type=(admin|mobile)(?:&amp;|&)token=/', $mail['html'], $match);
            $this->assertNotEmpty($match, 'Link reset bertipe tidak ditemukan di email.');
            $types[] = $match[1];
        }
        sort($types);
        $this->assertSame(['admin', 'mobile'], $types);
        $this->assertSame(['admin', 'mobile'], DB::table('password_reset_tokens')->where('email', 'sama@example.test')->orderBy('user_type')->pluck('user_type')->all());

        $sent = [];
        DB::table('password_reset_tokens')->delete();
        $this->postJson('/api/password/forgot', ['email' => 'sama@example.test', 'user_type' => 'mobile'])->assertOk();
        $this->assertCount(1, $sent);
        $this->assertStringContainsString('type=mobile', $sent[0]['html']);
        $this->assertSame(['mobile'], DB::table('password_reset_tokens')->pluck('user_type')->all());
        $this->postJson('/api/password/forgot', ['email' => 'sama@example.test', 'user_type' => 'superuser'])
            ->assertStatus(422)->assertJsonValidationErrors('user_type');
    }

    public function test_dashboard_login_issues_admin_scoped_token(): void
    {
        $this->admin();

        $token = PersonalAccessToken::findToken($this->dashboardToken('admin@example.test'));

        $this->assertSame(['admin'], $token->abilities);
        $this->assertSame('admin-dashboard', $token->name);
    }

    // ---- /mobile/me, sync, logout, heartbeat ----------------------------------------------

    #[DataProvider('accountTypes')]
    public function test_me_and_sync_work_for_both_account_types_and_me_refreshes_lease(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $token = $this->mobileToken($account->email, 'dev-1');

        Carbon::setTestNow(now()->addDays(20));
        $me = $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertOk()
            ->assertJsonPath('user.id', $account->id)
            ->assertJsonPath('user.email', $account->email)
            ->assertJsonPath('access.account_type', $type);
        $this->assertEquals(now()->addDays(30)->getTimestamp(), Carbon::parse($me->json('access.offline_access_until'))->getTimestamp());

        $this->api('GET', '/api/mobile/sync/check', $token, 'dev-1')->assertOk()->assertJsonStructure(['has_updates', 'server_time']);
        $this->api('GET', '/api/mobile/sync/full', $token, 'dev-1')->assertOk();
    }

    public static function accountTypes(): array
    {
        return ['admin' => ['admin'], 'mobile' => ['mobile']];
    }

    public function test_unauthenticated_mobile_requests_are_401(): void
    {
        $this->api('GET', '/api/mobile/me', null, 'dev-1')->assertStatus(401);
        $this->api('GET', '/api/mobile/sync/check', 'bukan-token', 'dev-1')->assertStatus(401);
    }

    #[DataProvider('accountTypes')]
    public function test_logout_revokes_only_that_device_session(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $first = $this->mobileToken($account->email, 'dev-1');
        $second = $this->mobileToken($account->email, 'dev-2');

        $this->api('POST', '/api/mobile/logout', $first, 'dev-1')->assertOk();

        $this->api('GET', '/api/mobile/me', $first, 'dev-1')->assertStatus(401);
        $this->assertSame(0, $account->tokens()->where('name', UserDeviceService::tokenName('dev-1'))->count());
        $this->assertSame(0, $account->devices()->where('device_id', 'dev-1')->where('is_active', true)->count());
        $this->api('GET', '/api/mobile/me', $second, 'dev-2')->assertOk();
    }

    public function test_admin_mobile_logout_keeps_dashboard_session(): void
    {
        $this->admin();
        $dashboard = $this->dashboardToken('admin@example.test');
        $mobile = $this->mobileToken('admin@example.test', 'dev-1');

        $this->api('POST', '/api/mobile/logout', $mobile, 'dev-1')->assertOk();

        $this->api('GET', '/api/admin/me', $dashboard)->assertOk();
    }

    #[DataProvider('accountTypes')]
    public function test_heartbeat_touches_bound_device_and_rejects_other_device_id(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $token = $this->mobileToken($account->email, 'dev-1');

        $this->api('POST', '/api/mobile/device/heartbeat', $token, 'dev-1', ['device_id' => 'dev-1', 'device_name' => 'Nama Baru'])
            ->assertOk()->assertJsonPath('device.device_id', 'dev-1')->assertJsonPath('device.device_name', 'Nama Baru');
        $this->api('POST', '/api/mobile/device/heartbeat', $token, 'dev-1', ['device_id' => 'dev-lain'])->assertStatus(403);
        $this->assertSame(0, $account->devices()->where('device_id', 'dev-lain')->count());
    }

    #[DataProvider('accountTypes')]
    public function test_heartbeat_authorized_before_revocation_cannot_reactivate_device(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $token = $this->mobileToken($account->email, 'dev-1');
        $account->withAccessToken(PersonalAccessToken::findToken($token));
        $devices = app(UserDeviceService::class);
        $request = \Illuminate\Http\Request::create('/api/mobile/device/heartbeat', 'POST', ['device_id' => 'dev-1']);
        $request->setUserResolver(fn () => $account);
        $request->attributes->set('mobile_device', $devices->findActive($account, 'dev-1'));

        // Middleware has authorized this request, but dashboard revocation wins before the write.
        $devices->deactivate($account, 'dev-1');
        try {
            app(\App\Http\Controllers\Api\AuthController::class)->mobileHeartbeat($request, $devices);
            $this->fail('A stale heartbeat must not reactivate a revoked device.');
        } catch (\Symfony\Component\HttpKernel\Exception\HttpException $error) {
            $this->assertSame(403, $error->getStatusCode());
        }
        $this->assertFalse($account->devices()->where('device_id', 'dev-1')->firstOrFail()->is_active);
        $this->assertNull(PersonalAccessToken::findToken($token));
    }

    // ---- device binding, cap, revocation --------------------------------------------------

    #[DataProvider('accountTypes')]
    public function test_device_cap_is_three_active_devices_and_relogin_on_known_device_is_allowed(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $tokens = [];
        foreach (['dev-1', 'dev-2', 'dev-3'] as $device) {
            $tokens[$device] = $this->mobileLogin($account->email, $device, name: 'Web Browser (chrome)')->assertOk()->json('token');
        }

        $this->mobileLogin($account->email, 'dev-4', name: 'Web Browser (chrome)')->assertStatus(422)->assertJsonValidationErrors('device_id');
        $this->assertSame(0, $account->devices()->where('device_id', 'dev-4')->count());
        foreach ($tokens as $device => $token) {
            $this->api('GET', '/api/mobile/me', $token, $device)->assertOk();
        }
        $this->mobileLogin($account->email, 'dev-2', name: 'Web Browser (chrome)')->assertOk();
        $this->assertSame(3, $account->devices()->where('is_active', true)->count());
    }

    #[DataProvider('accountTypes')]
    public function test_token_is_bound_to_its_device_and_device_header_is_required(string $type): void
    {
        $account = $type === 'admin' ? $this->admin() : $this->mobileUser();
        $first = $this->mobileToken($account->email, 'dev-1');
        $this->mobileToken($account->email, 'dev-2');

        $this->api('GET', '/api/mobile/me', $first)->assertStatus(403);
        $this->api('GET', '/api/mobile/me', $first, 'dev-2')->assertStatus(403);
        $this->api('GET', '/api/mobile/me', $first, 'dev-tidak-ada')->assertStatus(403);
        $this->api('GET', '/api/mobile/me', $first, 'dev-1')->assertOk();
    }

    public function test_relogin_on_same_device_replaces_the_previous_token(): void
    {
        $this->admin();
        $old = $this->mobileToken('admin@example.test', 'dev-1');
        $new = $this->mobileToken('admin@example.test', 'dev-1');

        $this->api('GET', '/api/mobile/me', $old, 'dev-1')->assertStatus(401);
        $this->api('GET', '/api/mobile/me', $new, 'dev-1')->assertOk();
    }

    public function test_revoking_a_mobile_user_device_from_dashboard_blocks_that_device_only(): void
    {
        $this->admin('super_admin', 'root@example.test');
        $user = $this->mobileUser();
        $revoked = $this->mobileToken($user->email, 'dev-1');
        $kept = $this->mobileToken($user->email, 'dev-2');
        $dashboard = $this->dashboardToken('root@example.test');
        $row = UserDevice::where('device_id', 'dev-1')->firstOrFail();

        $this->api('DELETE', "/api/admin/mobile-users/{$user->id}/devices/{$row->id}", $dashboard)->assertOk();

        $this->api('GET', '/api/mobile/me', $revoked, 'dev-1')->assertStatus(401);
        $this->assertFalse($row->fresh()->is_active);
        $this->api('GET', '/api/mobile/me', $kept, 'dev-2')->assertOk();
        // Perangkat yang dicabut membebaskan slot dan hanya bisa kembali lewat login baru.
        $this->mobileLogin($user->email, 'dev-3')->assertOk();
        $this->mobileLogin($user->email, 'dev-1')->assertOk();
        $this->api('GET', '/api/mobile/me', $revoked, 'dev-1')->assertStatus(401);
    }

    public function test_revoking_an_admin_device_through_admin_devices_endpoint_blocks_that_device(): void
    {
        $root = $this->admin('super_admin', 'root@example.test');
        $admin = $this->admin('admin', 'staff@example.test');
        $revoked = $this->mobileToken($admin->email, 'dev-1');
        $kept = $this->mobileToken($admin->email, 'dev-2');
        $dashboard = $this->dashboardToken($root->email);
        $row = AdminDevice::where('device_id', 'dev-1')->firstOrFail();

        $this->api('DELETE', "/api/admin/admin-users/{$admin->id}/devices/{$row->id}", $dashboard)->assertOk();

        $this->api('GET', '/api/mobile/me', $revoked, 'dev-1')->assertStatus(401);
        $this->assertFalse($row->fresh()->is_active);
        $this->api('GET', '/api/mobile/me', $kept, 'dev-2')->assertOk();
        $this->mobileLogin($admin->email, 'dev-1')->assertOk();
        $this->api('GET', '/api/mobile/me', $revoked, 'dev-1')->assertStatus(401);
    }

    public function test_a_device_row_deactivated_directly_is_rejected_with_403_even_if_token_exists(): void
    {
        $admin = $this->admin();
        $token = $this->mobileToken($admin->email, 'dev-1');

        AdminDevice::where('device_id', 'dev-1')->update(['is_active' => false]);

        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(403);

        // Login ulang menerbitkan token baru; token lama tidak hidup kembali.
        $this->mobileLogin($admin->email, 'dev-1')->assertOk();
        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(401);
    }

    // ---- account state changes ------------------------------------------------------------

    public function test_admin_disable_revokes_mobile_and_dashboard_sessions_and_devices(): void
    {
        $this->admin('super_admin', 'root@example.test');
        $staff = $this->admin('admin', 'staff@example.test');
        $mobile = $this->mobileToken($staff->email, 'dev-1');
        $dashboardOfStaff = $this->dashboardToken($staff->email);
        $root = $this->dashboardToken('root@example.test');

        $this->api('PATCH', "/api/admin/admin-users/{$staff->id}/deactivate", $root)->assertOk();

        $this->assertSame(0, $staff->tokens()->count());
        $this->assertSame(0, $staff->devices()->where('is_active', true)->count());
        $this->api('GET', '/api/mobile/me', $mobile, 'dev-1')->assertStatus(401);
        $this->api('GET', '/api/admin/me', $dashboardOfStaff)->assertStatus(401);
        $this->mobileLogin($staff->email, 'dev-1')->assertStatus(422);
    }

    public function test_disabled_admin_with_surviving_token_is_forbidden_on_mobile(): void
    {
        $admin = $this->admin();
        $token = $this->mobileToken($admin->email, 'dev-1');

        $admin->update(['is_active' => false]);

        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(403);
    }

    public function test_mobile_user_disable_and_password_reset_revoke_sessions(): void
    {
        $this->admin('admin', 'staff@example.test');
        $user = $this->mobileUser();
        $token = $this->mobileToken($user->email, 'dev-1');
        $dashboard = $this->dashboardToken('staff@example.test');

        $this->api('PATCH', "/api/admin/mobile-users/{$user->id}/deactivate", $dashboard)->assertOk();
        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(401);
        $this->assertSame(0, $user->devices()->where('is_active', true)->count());

        $this->api('PATCH', "/api/admin/mobile-users/{$user->id}/activate", $dashboard)->assertOk();
        $token = $this->mobileToken($user->email, 'dev-1');
        $this->api('PATCH', "/api/admin/mobile-users/{$user->id}/password", $dashboard, null, ['password' => 'Password-Baru-99'])->assertOk();

        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(401);
        $this->assertSame(0, $user->devices()->where('is_active', true)->count());
        $this->mobileLogin($user->email, 'dev-1', 'Password-Baru-99')->assertOk();
    }

    public function test_mobile_user_expiring_while_logged_in_loses_access_but_extension_restores_it(): void
    {
        $user = $this->mobileUser('user@example.test', null, now()->addDays(2));
        $token = $this->mobileToken($user->email, 'dev-1');

        Carbon::setTestNow(now()->addDays(3));
        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertStatus(403);

        $user->update(['expires_at' => now()->addYear()]);
        $this->api('GET', '/api/mobile/me', $token, 'dev-1')->assertOk();
    }

    // ---- scope separation -----------------------------------------------------------------

    public function test_mobile_scoped_tokens_never_reach_dashboard_routes(): void
    {
        $admin = $this->admin('super_admin', 'root@example.test');
        $user = $this->mobileUser();
        $adminMobile = $this->mobileToken($admin->email, 'dev-1');
        $userMobile = $this->mobileToken($user->email, 'dev-1');

        foreach (['/api/admin/me', '/api/admin/dashboard/summary', '/api/admin/mobile-users', '/api/admin/admin-users'] as $uri) {
            $this->api('GET', $uri, $adminMobile, 'dev-1')->assertStatus(403);
            $this->api('GET', $uri, $userMobile, 'dev-1')->assertStatus(403);
        }
        $this->api('POST', '/api/admin/logout', $adminMobile, 'dev-1')->assertStatus(403);
        $this->assertSame(1, $admin->tokens()->where('name', UserDeviceService::tokenName('dev-1'))->count());
    }

    public function test_dashboard_tokens_never_reach_mobile_routes(): void
    {
        $admin = $this->admin();
        $dashboard = $this->dashboardToken($admin->email);
        $this->mobileToken($admin->email, 'dev-1');

        $this->api('GET', '/api/mobile/me', $dashboard, 'dev-1')->assertStatus(403);
        $this->api('GET', '/api/mobile/sync/check', $dashboard, 'dev-1')->assertStatus(403);
        $this->api('GET', '/api/admin/me', $dashboard)->assertOk();
    }

    public function test_legacy_dashboard_wildcard_token_still_works_but_legacy_mobile_token_needs_relogin(): void
    {
        $admin = $this->admin();
        $user = $this->mobileUser();
        $legacyDashboard = $admin->createToken('admin-dashboard')->plainTextToken;
        $legacyMobile = $user->createToken('mobile-app')->plainTextToken;
        $user->devices()->create(['device_id' => 'dev-1', 'device_name' => 'Lama', 'platform' => 'android', 'is_active' => true]);
        $legacyAdminMobile = $admin->createToken('mobile-app')->plainTextToken;

        $this->api('GET', '/api/admin/me', $legacyDashboard)->assertOk();
        $this->api('GET', '/api/mobile/me', $legacyMobile, 'dev-1')->assertStatus(401);
        $this->api('GET', '/api/mobile/me', $legacyDashboard, 'dev-1')->assertStatus(403);
        $this->api('GET', '/api/admin/me', $legacyAdminMobile)->assertStatus(403);
        $this->api('GET', '/api/mobile/me', $legacyAdminMobile, 'dev-1')->assertStatus(401);
    }

    public function test_reader_mobile_user_tokens_cannot_use_admin_mobile_endpoints_of_other_accounts(): void
    {
        $admin = $this->admin();
        $user = $this->mobileUser();
        $adminMobile = $this->mobileToken($admin->email, 'dev-1');
        $userMobile = $this->mobileToken($user->email, 'dev-1');

        // Device id yang sama di dua akun berbeda tidak saling membuka sesi.
        $this->api('GET', '/api/mobile/me', $adminMobile, 'dev-1')->assertOk()->assertJsonPath('access.account_type', 'admin');
        $this->api('GET', '/api/mobile/me', $userMobile, 'dev-1')->assertOk()->assertJsonPath('access.account_type', 'mobile');
    }
}
