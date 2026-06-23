<?php
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/EmailComposer.php';
$config = require __DIR__ . '/../config/config.php';
$db = new Database($config['db']);
$pdo = $db->getPdo();

$stmt = $pdo->prepare(
    "SELECT e.*, s.email as sender_email, s.name as sender_name, s.bounce_email, d.domain
     FROM email_queue e
     JOIN senders s ON e.sender_id = s.id
     JOIN domains d ON s.domain_id = d.id
     WHERE e.status = 'pending' AND e.attempts < 3
     ORDER BY e.created_at ASC LIMIT 20"
);
$stmt->execute();
$emails = $stmt->fetchAll();

foreach ($emails as $email) {
    $pdo->prepare("UPDATE email_queue SET status='sending', attempts=attempts+1, last_attempt=NOW() WHERE id=?")
        ->execute([$email['id']]);

    // Add tracking pixel
    $trackId = dechex($email['id']);
    $html = $email['body_html'];
    $html .= '<img src="' . $config['app']['base_url'] . $config['app']['tracking_pixel'] . $trackId . '.png" width="1" height="1" style="display:none" alt=""/>';
    $html = preg_replace_callback('/<a\s+[^>]*href=(["\'])(.*?)\1/i', function($m) use ($config, $trackId) {
        return str_replace($m[2], $config['app']['base_url'] . $config['app']['click_rewrite'] . $trackId . '?url=' . urlencode($m[2]), $m[0]);
    }, $html);

    $from = "{$email['sender_name']} <{$email['sender_email']}>";
    $returnPath = $email['bounce_email'] ?: $email['sender_email'];

    // Attachments
    $attData = [];
    $attStmt = $pdo->prepare("SELECT a.filename, a.mime_type, a.file_path FROM attachments a
                              JOIN email_attachments ea ON a.id = ea.attachment_id WHERE ea.queue_id = ?");
    $attStmt->execute([$email['id']]);
    foreach ($attStmt->fetchAll() as $att) {
        $attData[] = ['path' => $att['file_path'], 'filename' => $att['filename'], 'mime' => $att['mime_type']];
    }

    // Merge sender custom headers
    $customHeaders = json_decode($email['custom_headers'] ?? '{}', true) ?: [];
    $senderHeaders = $pdo->prepare("SELECT header_name, header_value FROM sender_custom_headers WHERE sender_id = ?");
    $senderHeaders->execute([$email['sender_id']]);
    foreach ($senderHeaders->fetchAll() as $h) {
        $customHeaders[$h['header_name']] = $h['header_value'];
    }

    $rawMessage = EmailComposer::build(
        $from, $email['recipient'], $email['subject'],
        $html, $email['body_text'] ?? '', $email['amp_html'] ?? '',
        $customHeaders, $attData
    );

    $handle = popen('/usr/sbin/sendmail -t -f ' . escapeshellarg($returnPath), 'w');
    fwrite($handle, $rawMessage);
    pclose($handle);

    $pdo->prepare("UPDATE email_queue SET status='sent', message_id=? WHERE id=?")
        ->execute(["<{$email['sender_email']}-" . time() . "-{$email['id']}@{$email['domain']}>", $email['id']]);

    usleep(500000); // throttle
}