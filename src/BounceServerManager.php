<?php
class BounceServerManager {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function save(int $userId): void {
        $stmt = $this->db->getPdo()->prepare(
            'INSERT INTO bounce_servers (user_id, name, host, port, encryption, username, password) VALUES (?,?,?,?,?,?,?)'
        );
        $stmt->execute([
            $userId,
            $_POST['name'],
            $_POST['host'],
            $_POST['port'] ?? 993,
            $_POST['encryption'] ?? 'ssl',
            $_POST['username'],
            $_POST['password']
        ]);
        $_SESSION['success'] = 'Bounce server added.';
        header('Location: bounce-servers');
        exit;
    }

    public function getAll(int $userId): array {
        $stmt = $this->db->getPdo()->prepare('SELECT * FROM bounce_servers WHERE user_id = ? ORDER BY name');
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    }

    public function delete(int $userId, int $id): void {
        $stmt = $this->db->getPdo()->prepare('DELETE FROM bounce_servers WHERE id = ? AND user_id = ?');
        $stmt->execute([$id, $userId]);
        $_SESSION['success'] = 'Bounce server removed.';
        header('Location: bounce-servers');
        exit;
    }
}