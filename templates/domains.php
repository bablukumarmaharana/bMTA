<?php
require_once __DIR__ . '/header.php';

$dm = new DomainManager($db);
$domains = $dm->getDomains($currentUser->currentUserId());

/**
 * Convert PEM public key to DKIM TXT value (v=DKIM1; k=rsa; p=...)
 */
function pemToDkim($publicPem) {
    $key = str_replace(['-----BEGIN PUBLIC KEY-----','-----END PUBLIC KEY-----'], '', $publicPem);
    $key = trim(preg_replace('/\s+/', '', $key));
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

<?php foreach ($domains as $d):
    $domain = $d['domain'];                     // e.g., "example.com" or "bulkmail.example.com"
    $selector = $d['dkim_selector'];            // e.g., "default"
    $isApex = substr_count($domain, '.') == 1;  // simple heuristic: apex if only one dot (com, org, etc.)

    // Relative hostnames
    $spf_host  = '@';                                  // SPF for root
    $dkim_host = $selector . '._domainkey';            // relative to domain
    $dmarc_host = '_dmarc';                            // relative to domain

    // Full hostnames (FQDN) – add domain with trailing dot
    $spf_full   = $domain . '.';                       // trailing dot = absolute
    $dkim_full  = $dkim_host . '.' . $domain . '.';
    $dmarc_full = $dmarc_host . '.' . $domain . '.';

    // MX record
    $mx_value = $d['mx_record'] ?: $domain;
    $mx_host  = $isApex ? '@' : $domain;               // if subdomain, MX host is the subdomain itself
    $mx_full  = $isApex ? $domain . '.' : $domain . '.';
?>
<div class="card mb-4">
    <div class="card-header bg-primary text-white">
        <strong><?= Helpers::sanitize($domain) ?></strong>
        <span class="float-end">
            <button class="btn btn-sm btn-light" onclick="navigator.clipboard.writeText('<?= addslashes($d['dkim_private']) ?>')">Copy DKIM Private</button>
            <a href="domain-delete?id=<?= $d['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete domain?')">Delete</a>
        </span>
    </div>
    <div class="card-body">
        <h5>DNS Records to Publish for <em><?= Helpers::sanitize($domain) ?></em></h5>
        <p class="text-muted">Some providers use relative hostnames, others require fully qualified domain names (FQDN). We show both – pick the format your DNS host expects. TTL is recommended.</p>

        <table class="table table-bordered">
            <thead class="table-light">
                <tr>
                    <th>Type</th>
                    <th>Host (Relative)</th>
                    <th>Host (FQDN)</th>
                    <th>Value / Points to</th>
                    <th>TTL</th>
                </tr>
            </thead>
            <tbody>
                <!-- MX Record -->
                <tr>
                    <td><span class="badge bg-info">MX</span></td>
                    <td><code><?= Helpers::sanitize($mx_host) ?></code></td>
                    <td><code><?= Helpers::sanitize($mx_full) ?></code></td>
                    <td><code><?= Helpers::sanitize($mx_value) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- SPF Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($spf_host) ?></code></td>
                    <td><code><?= Helpers::sanitize($spf_full) ?></code></td>
                    <td><code><?= Helpers::sanitize($d['spf_record']) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- DKIM Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($dkim_host) ?></code></td>
                    <td><code><?= Helpers::sanitize($dkim_full) ?></code></td>
                    <td style="word-break:break-all;"><code><?= Helpers::sanitize(pemToDkim($d['dkim_public'])) ?></code></td>
                    <td>3600</td>
                </tr>
                <!-- DMARC Record -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($dmarc_host) ?></code></td>
                    <td><code><?= Helpers::sanitize($dmarc_full) ?></code></td>
                    <td><code><?= Helpers::sanitize($d['dmarc_record']) ?></code></td>
                    <td>3600</td>
                </tr>
            </tbody>
        </table>

        <div class="alert alert-warning">
            <strong>DKIM Private Key</strong> – Keep this secret! It is automatically used by bMTA to sign emails. Never publish it in DNS.
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
