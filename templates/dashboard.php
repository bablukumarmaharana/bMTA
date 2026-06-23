<?php
require_once __DIR__ . '/header.php';
$userId = $currentUser->currentUserId();
$queueStats = (new QueueManager($db))->getStats($userId);
?>
<h2>Dashboard</h2>
<div class="row">
    <div class="col-md-6">
        <div class="card mb-3">
            <div class="card-header">Queue Summary</div>
            <div class="card-body">
                <table class="table">
                    <thead><tr><th>Status</th><th>Count</th></tr></thead>
                    <tbody>
                    <?php foreach ($queueStats as $stat): ?>
                        <tr>
                            <td><span class="badge bg-<?= $stat['status']==='sent'?'success':($stat['status']==='pending'?'warning':'secondary') ?>"><?= $stat['status'] ?></span></td>
                            <td><?= $stat['cnt'] ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
                <a href="queue" class="btn btn-sm btn-outline-primary">View Queue</a>
            </div>
        </div>
    </div>
    <div class="col-md-6">
        <div class="card">
            <div class="card-header">Quick Actions</div>
            <div class="card-body d-grid gap-2">
                <a href="compose" class="btn btn-primary">New Campaign</a>
                <a href="domains" class="btn btn-outline-secondary">Manage Domains</a>
                <a href="senders" class="btn btn-outline-secondary">Manage Senders</a>
            </div>
        </div>
    </div>
</div>
<?php require_once __DIR__ . '/footer.php'; ?>