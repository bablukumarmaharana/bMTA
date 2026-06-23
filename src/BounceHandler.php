<?php
class BounceHandler {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    public function processAll(): int {
        $servers = $this->db->getPdo()->query('SELECT * FROM bounce_servers')->fetchAll();
        $total = 0;
        foreach ($servers as $s) {
            $total += $this->processOne($s);
        }
        return $total;
    }

    private function processOne(array $server): int {
        $mailbox = @imap_open(
            "{{$server['host']}:{$server['port']}/imap/{$server['encryption']}}INBOX",
            $server['username'], $server['password']
        );
        if (!$mailbox) return 0;

        $emails = imap_search($mailbox, 'UNSEEN');
        if (!$emails) { imap_close($mailbox); return 0; }

        $count = 0;
        foreach ($emails as $num) {
            $body = imap_body($mailbox, $num);
            if (preg_match('/X-Original-Message-Id:\s*<(.+?)>/i', $body, $m)) {
                $mid = $m[1];
                $stmt = $this->db->getPdo()->prepare("SELECT id, recipient FROM email_queue WHERE message_id = ?");
                $stmt->execute([$mid]);
                $queue = $stmt->fetch();
                if ($queue) {
                    $this->db->getPdo()->prepare("UPDATE email_queue SET status='bounced' WHERE id=?")->execute([$queue['id']]);
                    $this->db->getPdo()->prepare("INSERT IGNORE INTO suppression_list (recipient) VALUES (?)")->execute([$queue['recipient']]);
                    $count++;
                }
            }
            imap_setflag_full($mailbox, $num, "\\Seen");
        }
        imap_close($mailbox);
        return $count;
    }
}