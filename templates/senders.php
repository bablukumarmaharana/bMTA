<?php
require_once __DIR__ . '/header.php';
$sm = new SenderManager($db);
$senders = $sm->getSenders($currentUser->currentUserId());
$domainList = (new DomainManager($db))->getDomains($currentUser->currentUserId());
$bounceServers = (new BounceServerManager($db))->getAll($currentUser->currentUserId());
?>
<h2>Senders</h2>
<?php if (isset($_SESSION['success'])): ?>
    <div class="alert alert-success"><?= $_SESSION['success']; unset($_SESSION['success']); ?></div>
<?php endif; ?>
<?php if (isset($_SESSION['error'])): ?>
    <div class="alert alert-danger"><?= $_SESSION['error']; unset($_SESSION['error']); ?></div>
<?php endif; ?>
<table class="table">
    <thead><tr><th>Email</th><th>Domain</th><th>Bounce Email</th><th>Headers</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach ($senders as $s): ?>
        <tr>
            <td><?= Helpers::sanitize($s['email']) ?></td>
            <td><?= $s['domain'] ?></td>
            <td><?= $s['bounce_email'] ?: 'N/A' ?></td>
            <td>
                <?php foreach ($s['headers'] as $h): ?>
                    <span class="badge bg-secondary"><?= $h['header_name'] ?>: <?= $h['header_value'] ?></span>
                    <a href="header-delete?id=<?= $h['id'] ?>" class="text-danger">&times;</a>
                <?php endforeach; ?>
                <button class="btn btn-sm btn-link" data-bs-toggle="modal" data-bs-target="#headerModal" data-sender="<?= $s['id'] ?>">+</button>
            </td>
            <td><a href="sender-delete?id=<?= $s['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete sender?')">Delete</a></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>

<h4>Add Sender</h4>
<form method="post" action="sender-save">
    <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
    <div class="row g-3">
        <div class="col-md-3">
            <select name="domain_id" class="form-control" required>
                <option value="">-- Domain --</option>
                <?php foreach ($domainList as $d): ?>
                    <option value="<?= $d['id'] ?>"><?= $d['domain'] ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="col-md-3">
            <input type="email" name="email" class="form-control" placeholder="sender@domain.com" required>
        </div>
        <div class="col-md-2">
            <input type="text" name="name" class="form-control" placeholder="Display name">
        </div>
        <div class="col-md-2">
            <input type="password" name="password" class="form-control" placeholder="SMTP password" required>
        </div>
        <div class="col-md-2">
            <input type="email" name="bounce_email" class="form-control" placeholder="bounce@domain.com">
        </div>
        <div class="col-md-3">
            <select name="bounce_server_id" class="form-control">
                <option value="">-- Bounce Server --</option>
                <?php foreach ($bounceServers as $bs): ?>
                    <option value="<?= $bs['id'] ?>"><?= $bs['name'] ?> (<?= $bs['host'] ?>)</option>
                <?php endforeach; ?>
            </select>
        </div>
        <!-- Custom headers (dynamic) -->
        <div class="col-12" id="headerContainer">
            <div class="row mb-2 header-row">
                <div class="col-md-5"><input type="text" name="header_names[]" class="form-control" placeholder="Header name"></div>
                <div class="col-md-5"><input type="text" name="header_values[]" class="form-control" placeholder="Value"></div>
            </div>
            <button type="button" class="btn btn-sm btn-outline-secondary" onclick="addHeaderRow()">+ Add Header</button>
        </div>
        <div class="col-12">
            <button type="submit" class="btn btn-primary">Add Sender</button>
        </div>
    </div>
</form>

<script>
function addHeaderRow() {
    let container = document.getElementById('headerContainer');
    let row = document.createElement('div');
    row.className = 'row mb-2 header-row';
    row.innerHTML = `
        <div class="col-md-5"><input type="text" name="header_names[]" class="form-control" placeholder="Header name"></div>
        <div class="col-md-5"><input type="text" name="header_values[]" class="form-control" placeholder="Value"></div>
        <div class="col-md-2"><button type="button" class="btn btn-danger btn-sm" onclick="this.parentNode.parentNode.remove()">Remove</button></div>
    `;
    container.insertBefore(row, container.querySelector('button'));
}
</script>

<!-- Modal for adding header to existing sender -->
<div class="modal fade" id="headerModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="post" action="header-save">
            <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
            <div class="modal-content">
                <div class="modal-header"><h5>Add Custom Header</h5></div>
                <div class="modal-body">
                    <input type="hidden" name="sender_id" id="headerSenderId">
                    <input type="text" name="header_name" class="form-control mb-2" placeholder="Header name">
                    <input type="text" name="header_value" class="form-control" placeholder="Value">
                </div>
                <div class="modal-footer"><button type="submit" class="btn btn-primary">Save</button></div>
            </div>
        </form>
    </div>
</div>
<script>
document.getElementById('headerModal').addEventListener('show.bs.modal', function(event) {
    var button = event.relatedTarget;
    document.getElementById('headerSenderId').value = button.getAttribute('data-sender');
});
</script>
<?php require_once __DIR__ . '/footer.php'; ?>