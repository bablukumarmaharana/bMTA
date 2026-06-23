<?php require_once __DIR__ . '/header.php';
$users = $user->getAll();
?>
<h2>Users</h2>
<table class="table">
    <thead><tr><th>Email</th><th>Name</th><th>Role</th><th>Created</th><th>Action</th></tr></thead>
    <tbody>
    <?php foreach ($users as $u): ?>
        <tr>
            <td><?= $u['email'] ?></td>
            <td><?= $u['name'] ?></td>
            <td><?= $u['role'] ?></td>
            <td><?= $u['created_at'] ?></td>
            <td><a href="user-delete?id=<?= $u['id'] ?>" class="btn btn-sm btn-danger" onclick="return confirm('Delete user?')">Delete</a></td>
        </tr>
    <?php endforeach; ?>
    </tbody>
</table>

<h4>Add User</h4>
<form method="post" action="user-save">
    <input type="hidden" name="csrf_token" value="<?= Helpers::generateCsrf() ?>">
    <div class="row g-3">
        <div class="col-md-3"><input type="text" name="name" class="form-control" placeholder="Name" required></div>
        <div class="col-md-3"><input type="email" name="email" class="form-control" placeholder="Email" required></div>
        <div class="col-md-3"><input type="password" name="password" class="form-control" placeholder="Password" required></div>
        <div class="col-md-2">
            <select name="role" class="form-control"><option value="user">User</option><option value="admin">Admin</option></select>
        </div>
        <div class="col-md-1"><button type="submit" class="btn btn-primary">Add</button></div>
    </div>
</form>
<?php require_once __DIR__ . '/footer.php'; ?>