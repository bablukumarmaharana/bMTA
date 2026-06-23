<?php
class DomainManager {
    private $db;
    public function __construct(Database $db) { $this->db = $db; }

    private function getServerIp(): string {
        return $_SERVER['SERVER_ADDR'] ?? gethostbyname(trim(`hostname`));
    }

    public function saveDomain(int $userId): void {
        $domain = trim($_POST['domain'] ?? '');
        if (!$domain) {
            $_SESSION['error'] = 'Domain name is required.';
            header('Location: domains');
            exit;
        }

        // Generate DKIM keys (openssl required)
        $selector = 'default';
        $keySize = 2048;
        $tempDir = '/tmp/dkim_' . md5($domain . uniqid());
        @mkdir($tempDir, 0700);
        exec("openssl genrsa -out {$tempDir}/private.pem {$keySize} 2>/dev/null");
        exec("openssl rsa -in {$tempDir}/private.pem -pubout -out {$tempDir}/public.pem 2>/dev/null");
        $priv = file_get_contents("{$tempDir}/private.pem");
        $pub  = file_get_contents("{$tempDir}/public.pem");
        exec("rm -rf {$tempDir}");

        // Suggested SPF, DMARC
        $ip = $this->getServerIp();
        $spf   = "v=spf1 a mx ip4:{$ip} ~all";
        $dmarc = "v=DMARC1; p=none; rua=mailto:dmarc@{$domain}; ruf=mailto:dmarc@{$domain}; fo=1";
        $mx    = gethostbyname($domain); // simplistic

        $stmt = $this->db->getPdo()->prepare(
            'INSERT INTO domains (user_id, domain, dkim_private, dkim_public, dkim_selector, spf_record, dmarc_record, mx_record) VALUES (?,?,?,?,?,?,?,?)'
        );
        $stmt->execute([$userId, $domain, $priv, $pub, $selector, $spf, $dmarc, $mx]);
        $_SESSION['success'] = 'Domain added. Update DNS records accordingly.';
        header('Location: domains');
        exit;
    }

    public function getDomains(int $userId): array {
        $stmt = $this->db->getPdo()->prepare('SELECT * FROM domains WHERE user_id = ? ORDER BY domain');
        $stmt->execute([$userId]);
        return $stmt->fetchAll();
    }

    public function deleteDomain(int $userId, int $id): void {
        $stmt = $this->db->getPdo()->prepare('DELETE FROM domains WHERE id = ? AND user_id = ?');
        $stmt->execute([$id, $userId]);
        $_SESSION['success'] = 'Domain deleted.';
        header('Location: domains');
        exit;
    }
}