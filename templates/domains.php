<?php
require_once __DIR__ . '/header.php';

// Autoloader already handles DomainManager (via index.php)
$dm = new DomainManager($db);
$domains = $dm->getDomains($currentUser->currentUserId());

/**
 * Converts an OpenSSL PEM public key to the DKIM DNS TXT record value.
 * The format required is:  v=DKIM1; k=rsa; p=<base64_key>
 */
function pemToDkim($publicPem) {
    $key = str_replace(['-----BEGIN PUBLIC KEY-----','-----END PUBLIC KEY-----'], '', $publicPem);
    $key = trim(preg_replace('/\s+/', '', $key));            // remove newlines and spaces
    return 'v=DKIM1; k=rsa; p=' . $key;
}
?>
<h2>Domains</h2>

<?php if (isset($_SESSION['success'])): ?>
    <div class="alert alert-success"><?= $_SESSION['success']; unset($_SESSION['success']); ?></div>
<?php endif; ?>
<?php if (isset($_SESSION['error'])): ?>
    <div class="alert alert-danger"><?= $_SESSION['error']; unset($_SESSION['error']); ?></div>
<?php endif; ?>

<?php foreach ($domains as $d): ?>
<div class="card mb-4">
    <div class="card-header bg-primary text-white">
        <strong><?= Helpers::sanitize($d['domain']) ?></strong>
        <span class="float-end">
            <button class="btn btn-sm btn-light" onclick="navigator.clipboard.writeText('<?= addslashes($d['dkim_private']) ?>')">Copy DKIM Private</button>
            <a href="domain-delete?id=<?= $d['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete domain?')">Delete</a>
        </span>
    </div>
    <div class="card-body">
        <h5>DNS Records to Publish</h5>
        <p class="text-muted">Create the following records at your domain's DNS provider. TTL is recommended, adjust as needed.</p>

        <table class="table table-bordered">
            <thead class="table-light">
                <tr>
                    <th>Type</th>
                    <th>Host / Name</th>
                    <th>Value / Points to</th>
                    <th>TTL</th>
                </tr>
            </thead>
            <tbody>
                <!-- MX Record -->
                <tr>
                    <td><span class="badge bg-info">MX</span></td>
                    <td>@ (or leave blank)</td>
                    <td><code><?= Helpers::sanitize($d['mx_record'] ?: $d['domain']) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- SPF Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td>@ (or leave blank)</td>
                    <td><code><?= Helpers::sanitize($d['spf_record']) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- DKIM Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($d['dkim_selector'] . '._domainkey') ?></code></td>
                    <td style="word-break:break-all;"><code><?= Helpers::sanitize(pemToDkim($d['dkim_public'])) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- DMARC Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code>_dmarc</code></td>
                    <td><code><?= Helpers::sanitize($d['dmarc_record']) ?></code></td>
                    <td>3600</td>
                </tr>
            </tbody>
        </table>

        <div class="alert alert-warning">
            <strong>DKIM Private Key</strong> – Keep this secret! Use it in your bMTA sender settings. Never put it in DNS.
            <pre class="mb-0"><code><?= Helpers::sanitize($d['dkim_private']) ?></code></pre>
        </div>
    </div>
</div>
<?php endforeach; ?>

<h4>Add Domain</h4>
<form method="post" action="domain-save">
    <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
    <div class="row g-3">
        <div class="col-md-8">
            <input type="text" name="domain" class="form-control" placeholder="example.com" required>
        </div>
        <div class="col-md-4">
            <button type="submit" class="btn btn-primary">Add Domain</button>
        </div>
    </div>
</form>

<?php require_once __DIR__ . '/footer.php'; ?>
