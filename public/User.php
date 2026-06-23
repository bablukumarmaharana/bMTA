<?php
class User {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function countUsers(): int {
        return $this->db->getPdo()->query('SELECT COUNT(*) FROM users')->fetchColumn();
    }

    public function create(string $email, string $password, string $name, string $role = 'user'): int {
        $hash = password_hash($password, PASSWORD_BCRYPT);
        $stmt = $this->db->getPdo()->prepare('INSERT INTO users (email, password, name, role) VALUES (?, ?, ?, ?)');
        $stmt->execute([$email, $hash, $name, $role]);
        return $this->db->getPdo()->lastInsertId();
    }

    public function login(string $email, string $password): bool {
        $stmt = $this->db->getPdo()->prepare('SELECT * FROM users WHERE email = ?');
        $stmt->execute([$email]);
        $user = $stmt->fetch();
        if ($user && password_verify($password, $user['password'])) {
            $_SESSION['user_id'] = $user['id'];
            return true;
        }
        return false;
    }

    public function isLoggedIn(): bool { return isset($_SESSION['user_id']); }
    public function currentUserId(): int { return $_SESSION['user_id'] ?? 0; }
    public function currentUserRole(): string {
        $stmt = $this->db->getPdo()->prepare('SELECT role FROM users WHERE id = ?');
        $stmt->execute([$this->currentUserId()]);
        return $stmt->fetchColumn() ?: 'user';
    }
    // ...
}