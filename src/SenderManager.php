<?php
class SenderManager {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function save(int $userId): void {
        $domainId = (int)$_POST['domain_id'];
        $email    = trim($_POST['email']);
        $name     = trim($_POST['name'] ?? '');
        $password = $_POST['password'] ?? '';
        $bounceEmail = $_POST['bounce_email'] ?? null;
        $bounceServerId = $_POST['bounce_server_id'] ? (int)$_POST['bounce_server_id'] : null;

        if (!$domainId || !$email || !$password) {
            $_SESSION['error'] = 'Domain, email, and password are required.';
            header('Location: senders');
            exit;
        }

        $hash = password_hash($password, PASSWORD_BCRYPT);
        $stmt = $this->db->getPdo()->prepare(
            'INSERT INTO senders (user_id, domain_id, email, name, password, bounce_email, bounce_server_id) VALUES (?,?,?,?,?,?,?)'
        );
        $stmt->execute([$userId, $domainId, $email, $name, $hash, $bounceEmail, $bounceServerId]);

        // Handle custom headers (if submitted)
        if (!empty($_POST['header_names']) && is_array($_POST['header_names'])) {
            $senderId = $this->db->getPdo()->lastInsertId();
            $names  = $_POST['header_names'];
            $values = $_POST['header_values'] ?? [];
            $this->saveHeaders($senderId, $names, $values);
        }

        $_SESSION['success'] = 'Sender added.';
        header('Location: senders');
        exit;
    }

    private function saveHeaders(int $senderId, array $names, array $values): void {
        $stmt = $this->db->getPdo()->prepare('INSERT INTO sender_custom_headers (sender_id, header_name, header_value) VALUES (?,?,?)');
        foreach ($names as $i => $name) {
            $name = trim($name);
            $value = trim($values[$i] ?? '');
            if ($name !== '') {
                $stmt->execute([$senderId, $name, $value]);
            }
        }
    }

    public function saveHeader(int $userId): void {
        $senderId = (int)$_POST['sender_id'];
        $name  = trim($_POST['header_name']);
        $value = trim($_POST['header_value']);
        // Verify ownership
        $stmt = $this->db->getPdo()->prepare('SELECT id FROM senders WHERE id = ? AND user_id = ?');
        $stmt->execute([$senderId, $userId]);
        if ($stmt->fetch()) {
            $this->db->getPdo()->prepare('INSERT INTO sender_custom_headers (sender_id, header_name, header_value) VALUES (?,?,?)')
                ->execute([$senderId, $name, $value]);
        }
        header('Location: senders');
        exit;
    }

    public function deleteHeader(int $userId, int $id): void {
        // Ensure header belongs to user's sender
        $stmt = $this->db->getPdo()->prepare(
            'DELETE h FROM sender_custom_headers h JOIN senders s ON h.sender_id = s.id WHERE h.id = ? AND s.user_id = ?'
        );
        $stmt->execute([$id, $userId]);
        header('Location: senders');
        exit;
    }

    public function getSenders(int $userId): array {
        $stmt = $this->db->getPdo()->prepare(
            'SELECT s.*, d.domain FROM senders s JOIN domains d ON s.domain_id = d.id WHERE s.user_id = ? ORDER BY s.email'
        );
        $stmt->execute([$userId]);
        $senders = $stmt->fetchAll();
        // Attach custom headers
        $headerStmt = $this->db->getPdo()->prepare('SELECT * FROM sender_custom_headers WHERE sender_id = ?');
        foreach ($senders as &$sender) {
            $headerStmt->execute([$sender['id']]);
            $sender['headers'] = $headerStmt->fetchAll();
        }
        return $senders;
    }

    public function delete(int $userId, int $id): void {
        $stmt = $this->db->getPdo()->prepare('DELETE FROM senders WHERE id = ? AND user_id = ?');
        $stmt->execute([$id, $userId]);
        $_SESSION['success'] = 'Sender deleted.';
        header('Location: senders');
        exit;
    }
}