<?php require_once __DIR__ . '/header.php';
$qm = new QueueManager($db);
$statusFilter = $_GET['status'] ?? 'all';
$queue = $qm->getQueue($currentUser->currentUserId(), $statusFilter);
?>
<h2>Email Queue</h2>
<div class="mb-3">
    <a href="?status=all" class="btn btn-sm btn-outline-secondary">All</a>
    <a href="?status=pending" class="btn btn-sm btn-outline-warning">Pending</a>
    <a href="?status=sent" class="btn btn-sm btn-outline-success">Sent</a>
    <a href="?status=bounced" class="btn btn-sm btn-outline-danger">Bounced</a>
</div>
<table class="table table-striped">
    <thead><tr><th>Recipient</th><th>Subject</th><th>Sender</th><th>Status</th><th>Created</th></tr></thead>
    <tbody>
    <?php foreach ($queue as $q): ?>
        <tr>
            <td><?= Helpers::sanitize($q['recipient']) ?></td>
            <td><?= Helpers::sanitize($q['subject']) ?></td>
            <td><?= $q['sender_email'] ?></td>
            <td><span class="badge bg-<?= $q['status']==='sent'?'success':($q['status']==='pending'?'warning':'secondary') ?>"><?= $q['status'] ?></span></td>
            <td><?= $q['created_at'] ?></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>
<?php require_once __DIR__ . '/footer.php'; ?>