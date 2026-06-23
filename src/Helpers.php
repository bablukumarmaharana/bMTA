<?php
class Helpers {
    public static function generateCsrf(): string {
        $token = bin2hex(random_bytes(32));
        $_SESSION['csrf_token'] = $token;
        return $token;
    }
    public static function verifyCsrf(string $token): bool {
        return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
    }
    public static function sanitize(string $data): string {
        return htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    }
}