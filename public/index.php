<?php
session_start();

// ================= AUTOLOADER =================
spl_autoload_register(function ($class) {
    $file = __DIR__ . '/../src/' . $class . '.php';
    if (file_exists($file)) {
        require_once $file;
    }
});

// Manually load the first three (they are used immediately)
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/User.php';
require_once __DIR__ . '/../src/Helpers.php';
// ==============================================

$config = require __DIR__ . '/../config/config.php';
$db = new Database($config['db']);
$user = new User($db);

// First run: if no users, redirect to setup
if ($user->countUsers() === 0 && ($_GET['url'] ?? '') !== 'setup') {
    header('Location: setup');
    exit;
}

$url = $_GET['url'] ?? 'dashboard';
$url = rtrim($url, '/');
$method = $_SERVER['REQUEST_METHOD'];

// Routes that require authentication
$protected = [
    'dashboard','domains','senders','bounce-servers','compose','queue','users',
    'logout','domain-save','domain-delete','sender-save','sender-delete',
    'bounce-server-save','bounce-server-delete','queue-add','attachment-upload',
    'header-save','header-delete'
];
$adminOnly = ['users','user-save','user-delete'];

if (in_array($url, $protected)) {
    if (!$user->isLoggedIn()) {
        $_SESSION['error'] = 'Please log in.';
        header('Location: login');
        exit;
    }
    if (in_array($url, $adminOnly) && $user->currentUserRole() !== 'admin') {
        http_response_code(403);
        die('Access denied');
    }
}

// CSRF protection for POST actions
if ($method === 'POST' && in_array($url, $protected)) {
    $token = $_POST['csrf_token'] ?? '';
    if (!Helpers::verifyCsrf($token)) {
        http_response_code(403);
        die('CSRF token mismatch');
    }
}

// ---- ROUTING ----
switch ($url) {
    case 'setup':
        require __DIR__ . '/../templates/setup.php';
        break;
    case 'login':
        if ($method === 'POST') {
            if ($user->login($_POST['email'], $_POST['password'])) {
                header('Location: dashboard');
                exit;
            }
            $_SESSION['error'] = 'Invalid credentials.';
            header('Location: login');
            exit;
        }
        require __DIR__ . '/../templates/login.php';
	break;
    case 'domain-verify':
    	$dm = new DomainManager($db);
    	$domainId = (int)($_GET['id'] ?? 0);
    	$result = $dm->verifyDnsRecords($domainId, $user->currentUserId());
    	header('Content-Type: application/json');
    	echo json_encode($result);
    	exit;

    case 'logout':
        $user->logout();
        header('Location: login');
        exit;
    case 'dashboard':
        require __DIR__ . '/../templates/dashboard.php';
        break;
    case 'domains':
        require __DIR__ . '/../templates/domains.php';
        break;
    case 'domain-save':
        $dm = new DomainManager($db);
        $dm->saveDomain($user->currentUserId());
        break;
    case 'domain-delete':
        $dm = new DomainManager($db);
        $dm->deleteDomain($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'senders':
        require __DIR__ . '/../templates/senders.php';
        break;
    case 'sender-save':
        $sm = new SenderManager($db);
        $sm->save($user->currentUserId());
        break;
    case 'sender-delete':
        $sm = new SenderManager($db);
        $sm->delete($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'header-save':
        $sm = new SenderManager($db);
        $sm->saveHeader($user->currentUserId());
        break;
    case 'header-delete':
        $sm = new SenderManager($db);
        $sm->deleteHeader($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'bounce-servers':
        require __DIR__ . '/../templates/bounce_servers.php';
        break;
    case 'bounce-server-save':
        $bsm = new BounceServerManager($db);
        $bsm->save($user->currentUserId());
        break;
    case 'bounce-server-delete':
        $bsm = new BounceServerManager($db);
        $bsm->delete($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'compose':
        require __DIR__ . '/../templates/email_compose.php';
        break;
    case 'queue':
        require __DIR__ . '/../templates/queue.php';
        break;
    case 'queue-add':
        $qm = new QueueManager($db);
        $qm->addToQueue($user->currentUserId());
        break;
    case 'attachment-upload':
        $qm = new QueueManager($db);
        $qm->uploadAttachment($user->currentUserId());
        break;
    case 'users':
        require __DIR__ . '/../templates/users.php';
        break;
    case 'user-save':
        if ($user->currentUserRole() === 'admin') {
            $user->create($_POST['email'], $_POST['password'], $_POST['name'], $_POST['role']);
        }
        header('Location: users');
        exit;
    case 'user-delete':
        if ($user->currentUserRole() === 'admin') {
            $user->delete($_GET['id'] ?? 0);
        }
        header('Location: users');
        exit;
    default:
        http_response_code(404);
        echo 'Page not found';
}
