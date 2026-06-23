<?php
require_once __DIR__ . '/../src/Database.php';
$config = require __DIR__ . '/../config/config.php';
$db = new Database($config['db']);
$user = new User($db);

if ($user->countUsers() > 0) {
    header('Location: login');
    exit;
}

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email    = trim($_POST['email'] ?? '');
    $name     = trim($_POST['name'] ?? '');
    $password = $_POST['password'] ?? '';
    $password2= $_POST['password2'] ?? '';

    if (!$email || !$password || $password !== $password2) {
        $error = 'Please fill all fields and ensure passwords match.';
    } else {
        $user->create($email, $password, $name, 'admin');
        $_SESSION['user_id'] = $user->getIdByEmail($email);
        header('Location: dashboard');
        exit;
    }
}
?>
<!DOCTYPE html>
<html>
<head><title>bMTA Setup</title></head>
<body>
<h1>Create Admin Account</h1>
<?php if ($error): ?><p style="color:red"><?= $error ?></p><?php endif; ?>
<form method="post">
    <input name="name" placeholder="Full name" required><br>
    <input type="email" name="email" placeholder="Admin email" required><br>
    <input type="password" name="password" placeholder="Password" required><br>
    <input type="password" name="password2" placeholder="Repeat password" required><br>
    <button type="submit">Create Admin</button>
</form>
</body>
</html>