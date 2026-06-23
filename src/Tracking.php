<?php
class Tracking {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function logOpen(string $trackingId, string $ip, string $ua): void {
        $queueId = hexdec($trackingId);
        $stmt = $this->db->getPdo()->prepare('SELECT recipient FROM email_queue WHERE id = ?');
        $stmt->execute([$queueId]);
        $row = $stmt->fetch();
        if ($row) {
            $this->db->getPdo()->prepare(
                'INSERT INTO tracking_opens (queue_id, recipient, ip, user_agent) VALUES (?,?,?,?)'
            )->execute([$queueId, $row['recipient'], $ip, $ua]);
        }
    }

    public function logClick(string $trackingId, string $url, string $ip, string $ua): void {
        $queueId = hexdec($trackingId);
        $stmt = $this->db->getPdo()->prepare('SELECT recipient FROM email_queue WHERE id = ?');
        $stmt->execute([$queueId]);
        $row = $stmt->fetch();
        if ($row) {
            $this->db->getPdo()->prepare(
                'INSERT INTO tracking_clicks (queue_id, recipient, url, ip, user_agent) VALUES (?,?,?,?,?)'
            )->execute([$queueId, $row['recipient'], $url, $ip, $ua]);
        }
    }
}