<?php require_once __DIR__ . '/header.php'; ?>
<div class="row justify-content-center">
    <div class="col-md-5">
        <div class="card shadow">
            <div class="card-header bg-primary text-white"><h4>Login</h4></div>
            <div class="card-body">
                <?php if (isset($_SESSION['error'])): ?>
                    <div class="alert alert-danger"><?= $_SESSION['error'] ?><?php unset($_SESSION['error']); ?></div>
                <?php endif; ?>
                <form method="post">
                    <div class="mb-3">
                        <label>Email</label>
                        <input type="email" name="email" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label>Password</label>
                        <input type="password" name="password" class="form-control" required>
                    </div>
                    <button type="submit" class="btn btn-primary w-100">Sign In</button>
                </form>
            </div>
        </div>
    </div>
</div>
<?php require_once __DIR__ . '/footer.php'; ?>