<?php
require_once __DIR__ . '/header.php';
$dm = new DomainManager($db);
$domains = $dm->getDomains($currentUser->currentUserId());
?>
<h2>Domains</h2>
<?php if (isset($_SESSION['success'])): ?>
    <div class="alert alert-success"><?= $_SESSION['success']; unset($_SESSION['success']); ?></div>
<?php endif; ?>
<?php if (isset($_SESSION['error'])): ?>
    <div class="alert alert-danger"><?= $_SESSION['error']; unset($_SESSION['error']); ?></div>
<?php endif; ?>
<table class="table">
    <thead>
        <tr><th>Domain</th><th>DKIM Selector</th><th>SPF Record</th><th>DMARC Record</th><th>Action</th></tr>
    </thead>
    <tbody>
    <?php foreach ($domains as $d): ?>
        <tr>
            <td><?= Helpers::sanitize($d['domain']) ?></td>
            <td><code><?= $d['dkim_selector'] ?>._domainkey</code></td>
            <td><small><?= Helpers::sanitize($d['spf_record']) ?></small></td>
            <td><small><?= Helpers::sanitize($d['dmarc_record']) ?></small></td>
            <td>
                <button class="btn btn-sm btn-info" onclick="alert('DKIM Public Key:\n\n<?= addslashes(str_replace("\n", "\\n", $d['dkim_public'])) ?>')">View DKIM</button>
                <a href="domain-delete?id=<?= $d['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete domain?')">Delete</a>
            </td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>

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