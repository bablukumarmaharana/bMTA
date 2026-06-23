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
            $_SESSION['user_role'] = $user['role'];
            return true;
        }
        return false;
    }

    public function isLoggedIn(): bool { return isset($_SESSION['user_id']); }
    public function currentUserId(): int { return $_SESSION['user_id'] ?? 0; }
    public function currentUserRole(): string { return $_SESSION['user_role'] ?? 'user'; }

    public function getIdByEmail(string $email): ?int {
        $stmt = $this->db->getPdo()->prepare('SELECT id FROM users WHERE email = ?');
        $stmt->execute([$email]);
        return $stmt->fetchColumn() ?: null;
    }

    public function getAll(): array {
        return $this->db->getPdo()->query('SELECT id, email, name, role, created_at FROM users ORDER BY created_at DESC')->fetchAll();
    }

    public function delete(int $id): void {
        $stmt = $this->db->getPdo()->prepare('DELETE FROM users WHERE id = ?');
        $stmt->execute([$id]);
    }

    public function logout(): void {
        unset($_SESSION['user_id'], $_SESSION['user_role']);
    }
}