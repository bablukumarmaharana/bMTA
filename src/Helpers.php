<?php
class Helpers {
    public static function generateCsrf(): string {
        // Only generate a new token if none exists in the session
        if (empty($_SESSION['csrf_token'])) {
            $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf_token'];
    }

    public static function verifyCsrf(string $token): bool {
        return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
    }

    public static function sanitize(string $data): string {
        return htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
    }
}
