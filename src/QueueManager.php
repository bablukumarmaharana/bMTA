<?php
class QueueManager {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function addToQueue(int $userId): void {
        $senderId   = (int)$_POST['sender_id'];
        $recipient  = trim($_POST['recipient']);
        $subject    = trim($_POST['subject']);
        $bodyHtml   = $_POST['body_html'] ?? '';
        $bodyText   = $_POST['body_text'] ?? '';
        $ampHtml    = $_POST['amp_html'] ?? '';
        $headerNames  = $_POST['header_names'] ?? [];
        $headerValues = $_POST['header_values'] ?? [];
        $attachmentIds = $_POST['attachment_ids'] ?? []; // previously uploaded attachments

        if (!$senderId || !$recipient || !$subject) {
            $_SESSION['error'] = 'Missing required fields.';
            header('Location: compose');
            exit;
        }

        // Build custom headers JSON
        $customHeaders = [];
        if (!empty($headerNames)) {
            foreach ($headerNames as $i => $name) {
                $name = trim($name);
                $value = trim($headerValues[$i] ?? '');
                if ($name !== '') {
                    $customHeaders[$name] = $value;
                }
            }
        }

        // Insert into queue
        $stmt = $this->db->getPdo()->prepare(
            'INSERT INTO email_queue (user_id, sender_id, recipient, subject, body_html, body_text, amp_html, custom_headers, status) VALUES (?,?,?,?,?,?,?,?,?)'
        );
        $stmt->execute([
            $userId,
            $senderId,
            $recipient,
            $subject,
            $bodyHtml,
            $bodyText,
            $ampHtml,
            json_encode($customHeaders),
            'pending'
        ]);
        $queueId = $this->db->getPdo()->lastInsertId();

        // Link attachments
        if (!empty($attachmentIds)) {
            $attStmt = $this->db->getPdo()->prepare('INSERT INTO email_attachments (queue_id, attachment_id) VALUES (?,?)');
            foreach ($attachmentIds as $attId) {
                $attStmt->execute([$queueId, (int)$attId]);
            }
        }

        $_SESSION['success'] = 'Email queued successfully.';
        header('Location: queue');
        exit;
    }

    public function uploadAttachment(int $userId): void {
        if (empty($_FILES['file'])) {
            $_SESSION['error'] = 'No file uploaded.';
            header('Location: compose');
            exit;
        }
        $file = $_FILES['file'];
        $filename = basename($file['name']);
        $tmpPath  = $file['tmp_name'];
        $size     = $file['size'];
        $mime     = mime_content_type($tmpPath);

        // Save to uploads dir (create if needed)
        $uploadDir = (require __DIR__.'/../config/config.php')['app']['upload_dir'];
        if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);
        $newName = uniqid('att_') . '_' . $filename;
        $destPath = $uploadDir . '/' . $newName;
        move_uploaded_file($tmpPath, $destPath);

        $stmt = $this->db->getPdo()->prepare(
            'INSERT INTO attachments (user_id, filename, mime_type, file_path, size) VALUES (?,?,?,?,?)'
        );
        $stmt->execute([$userId, $filename, $mime, $destPath, $size]);
        $attId = $this->db->getPdo()->lastInsertId();

        // Return JSON for AJAX (or redirect)
        header('Content-Type: application/json');
        echo json_encode(['id' => $attId, 'filename' => $filename]);
        exit;
    }

    public function getQueue(int $userId, string $status = ''): array {
        $sql = 'SELECT e.*, s.email as sender_email FROM email_queue e JOIN senders s ON e.sender_id = s.id WHERE e.user_id = ?';
        $params = [$userId];
        if ($status && $status !== 'all') {
            $sql .= ' AND e.status = ?';
            $params[] = $status;
        }
        $sql .= ' ORDER BY e.created_at DESC LIMIT 100';
        $stmt = $this->db->getPdo()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function getStats(int $userId): array {
        $stmt = $this->db->getPdo()->prepare(
            "SELECT status, COUNT(*) as cnt FROM email_queue WHERE user_id = ? GROUP BY status"
        );
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    }
}