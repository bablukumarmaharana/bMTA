<?php
require_once __DIR__ . '/header.php';

$dm = new DomainManager($db);
$domains = $dm->getDomains($currentUser->currentUserId());

function pemToDkim($publicPem) {
    $key = str_replace(['-----BEGIN PUBLIC KEY-----','-----END PUBLIC KEY-----'], '', $publicPem);
    $key = trim(preg_replace('/\s+/', '', $key));
    return 'v=DKIM1; k=rsa; p=' . $key;
}

function copyButton($text) {
    $esc = htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
    return '<button type="button" class="btn btn-outline-secondary btn-sm py-0 px-1 ms-1" 
                   title="Copy" 
                   onclick="copyToClipboard(\'' . $esc . '\', this)">⧉</button>';
}
?>
<h2>Domains</h2>

<script>
function copyToClipboard(text, btn) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(() => {
            btn.innerHTML = '✓';
            setTimeout(() => btn.innerHTML = '⧉', 2000);
        }).catch(() => fallbackCopy(text, btn));
    } else {
        fallbackCopy(text, btn);
    }
}
function fallbackCopy(text, btn) {
    var textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.style.position = 'fixed';
    textarea.style.opacity = 0;
    document.body.appendChild(textarea);
    textarea.select();
    try {
        document.execCommand('copy');
        btn.innerHTML = '✓';
        setTimeout(() => btn.innerHTML = '⧉', 2000);
    } catch (err) {
        alert('Unable to copy. Please copy manually.');
    }
    document.body.removeChild(textarea);
}

function verifyDomain(domainId) {
    const container = document.getElementById('verify-results-' + domainId);
    const btn = document.getElementById('verify-btn-' + domainId);
    btn.disabled = true;
    btn.textContent = 'Verifying...';
    container.innerHTML = '<span class="text-muted">Checking DNS...</span>';

    fetch('domain-verify?id=' + domainId)
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                container.innerHTML = '<span class="text-danger">' + data.error + '</span>';
                return;
            }
            let html = '<table class="table table-sm table-bordered mt-2"><thead><tr><th>Record</th><th>Status</th></tr></thead><tbody>';
            const records = [
                {key:'mx', label:'MX'},
                {key:'spf', label:'SPF'},
                {key:'dkim', label:'DKIM'},
                {key:'dmarc', label:'DMARC'}
            ];
            records.forEach(r => {
                const status = data[r.key] ? '✅ Verified' : '❌ Not found';
                html += '<tr><td>' + r.label + '</td><td>' + status + '</td></tr>';
            });
            html += '</tbody></table>';
            container.innerHTML = html;
        })
        .catch(err => {
            container.innerHTML = '<span class="text-danger">Error verifying.</span>';
        })
        .finally(() => {
            btn.disabled = false;
            btn.textContent = 'Verify Records';
        });
}
</script>

<?php if (isset($_SESSION['success'])): ?>
    <div class="alert alert-success"><?= $_SESSION['success']; unset($_SESSION['success']); ?></div>
<?php endif; ?>
<?php if (isset($_SESSION['error'])): ?>
    <div class="alert alert-danger"><?= $_SESSION['error']; unset($_SESSION['error']); ?></div>
<?php endif; ?>

<?php foreach ($domains as $d):
    $domain = $d['domain'];
    $selector = $d['dkim_selector'];
    
    // Full Host values (FQDN with trailing dot)
    $mx_host_fqdn   = $domain . '.';
    $spf_host_fqdn  = $domain . '.';
    $dkim_host_fqdn = $selector . '._domainkey.' . $domain . '.';
    $dmarc_host_fqdn = '_dmarc.' . $domain . '.';
    
    // MX value with priority
    $mx_mail_server = $d['mx_record'] ?: $domain;
    $mx_full_value  = '10 ' . $mx_mail_server;
?>
<div class="card mb-4">
    <div class="card-header bg-primary text-white">
        <strong><?= Helpers::sanitize($domain) ?></strong>
        <span class="float-end">
            <button class="btn btn-sm btn-light" onclick="copyToClipboard('<?= addslashes($d['dkim_private']) ?>', this)">Copy DKIM Private</button>
            <a href="domain-delete?id=<?= $d['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete domain?')">Delete</a>
        </span>
    </div>
    <div class="card-body">
        <h5>DNS Records for <em><?= Helpers::sanitize($domain) ?></em></h5>
        <p class="text-muted">All hosts are shown as full domain names (FQDN) – ready to paste into your DNS provider. Click ⧉ to copy.</p>

        <table class="table table-bordered">
            <thead class="table-light">
                <tr>
                    <th>Type</th>
                    <th>Host</th>
                    <th>Value</th>
                    <th>TTL</th>
                </tr>
            </thead>
            <tbody>
                <!-- MX -->
                <tr>
                    <td><span class="badge bg-info">MX</span></td>
                    <td><code><?= Helpers::sanitize($mx_host_fqdn) ?></code><?= copyButton($mx_host_fqdn) ?></td>
                    <td><code><?= Helpers::sanitize($mx_full_value) ?></code><?= copyButton($mx_full_value) ?></td>
                    <td>3600</td>
                </tr>
                <!-- SPF -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($spf_host_fqdn) ?></code><?= copyButton($spf_host_fqdn) ?></td>
                    <td><code><?= Helpers::sanitize($d['spf_record']) ?></code><?= copyButton($d['spf_record']) ?></td>
                    <td>3600</td>
                </tr>
                <!-- DKIM -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($dkim_host_fqdn) ?></code><?= copyButton($dkim_host_fqdn) ?></td>
                    <td style="word-break:break-all;"><code><?= Helpers::sanitize(pemToDkim($d['dkim_public'])) ?></code><?= copyButton(pemToDkim($d['dkim_public'])) ?></td>
                    <td>3600</td>
                </tr>
                <!-- DMARC -->
                <tr>
                    <td><span class="badge bg-success">TXT</span></td>
                    <td><code><?= Helpers::sanitize($dmarc_host_fqdn) ?></code><?= copyButton($dmarc_host_fqdn) ?></td>
                    <td><code><?= Helpers::sanitize($d['dmarc_record']) ?></code><?= copyButton($d['dmarc_record']) ?></td>
                    <td>3600</td>
                </tr>
            </tbody>
        </table>

        <div class="row align-items-center">
            <div class="col-auto">
                <button id="verify-btn-<?= $d['id'] ?>" class="btn btn-outline-info btn-sm" onclick="verifyDomain(<?= $d['id'] ?>)">Verify Records</button>
            </div>
            <div class="col" id="verify-results-<?= $d['id'] ?>"></div>
        </div>

        <div class="alert alert-warning mt-3">
            <strong>DKIM Private Key</strong> – Keep this secret. Never publish it in DNS.
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
