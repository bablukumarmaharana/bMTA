<?php require_once __DIR__ . '/header.php';
$bsm = new BounceServerManager($db);
$servers = $bsm->getAll($currentUser->currentUserId());
?>
<h2>Bounce Servers</h2>
<?php if (isset($_SESSION['success'])): ?>
    <div class="alert alert-success"><?= $_SESSION['success']; unset($_SESSION['success']); ?></div>
<?php endif; ?>
<table class="table">
    <thead><tr><th>Name</th><th>Host</th><th>Port</th><th>Encryption</th><th>Actions</th></tr></thead>
    <tbody>
    <?php foreach ($servers as $s): ?>
        <tr>
            <td><?= Helpers::sanitize($s['name']) ?></td>
            <td><?= $s['host'] ?></td>
            <td><?= $s['port'] ?></td>
            <td><?= $s['encryption'] ?></td>
            <td><a href="bounce-server-delete?id=<?= $s['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete?')">Delete</a></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>

<h4>Add Bounce Server</h4>
<form method="post" action="bounce-server-save">
    <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
    <div class="row g-3">
        <div class="col-md-3"><input type="text" name="name" class="form-control" placeholder="Name" required></div>
        <div class="col-md-3"><input type="text" name="host" class="form-control" placeholder="Host" required></div>
        <div class="col-md-2"><input type="number" name="port" class="form-control" placeholder="993" value="993"></div>
        <div class="col-md-2">
            <select name="encryption" class="form-control"><option value="ssl">SSL</option><option value="tls">TLS</option></select>
        </div>
        <div class="col-md-2"><input type="text" name="username" class="form-control" placeholder="Username" required></div>
        <div class="col-md-2"><input type="password" name="password" class="form-control" placeholder="Password" required></div>
        <div class="col-12"><button type="submit" class="btn btn-primary">Add Server</button></div>
    </div>
</form>
<?php require_once __DIR__ . '/footer.php'; ?>