<?php
session_start();
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/User.php';
require_once __DIR__ . '/../src/Helpers.php';

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
$protected = ['dashboard','domains','senders','bounce-servers','compose','queue','users',
              'logout','domain-save','domain-delete','sender-save','sender-delete',
              'bounce-server-save','bounce-server-delete','queue-add','attachment-upload',
              'header-save','header-delete'];
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

// CSRF protection for POST actions (simple token check)
if ($method === 'POST' && in_array($url, $protected)) {
    $token = $_POST['csrf_token'] ?? '';
    if (!Helpers::verifyCsrf($token)) {
        http_response_code(403);
        die('CSRF token mismatch');
    }
}

// Routing
switch ($url) {
    case 'setup':
        require __DIR__ . '/setup.php';
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
    case 'logout':
        $user->logout();
        header('Location: login');
        exit;
    case 'dashboard':
        require __DIR__ . '/../templates/dashboard.php';
        break;
    case 'domains':
        if ($method === 'POST') {
            // handled by domain-save
            require __DIR__ . '/../templates/domains.php';
        } else {
            require __DIR__ . '/../templates/domains.php';
        }
        break;
    case 'domain-save':
        require_once __DIR__ . '/../src/DomainManager.php';
        $dm = new DomainManager($db);
        $dm->saveDomain($user->currentUserId());
        break;
    case 'domain-delete':
        require_once __DIR__ . '/../src/DomainManager.php';
        $dm = new DomainManager($db);
        $dm->deleteDomain($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'senders':
        require __DIR__ . '/../templates/senders.php';
        break;
    case 'sender-save':
        require_once __DIR__ . '/../src/SenderManager.php';
        $sm = new SenderManager($db);
        $sm->save($user->currentUserId());
        break;
    case 'sender-delete':
        require_once __DIR__ . '/../src/SenderManager.php';
        $sm = new SenderManager($db);
        $sm->delete($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'header-save':
        require_once __DIR__ . '/../src/SenderManager.php';
        $sm = new SenderManager($db);
        $sm->saveHeader($user->currentUserId());
        break;
    case 'header-delete':
        require_once __DIR__ . '/../src/SenderManager.php';
        $sm = new SenderManager($db);
        $sm->deleteHeader($user->currentUserId(), $_GET['id'] ?? 0);
        break;
    case 'bounce-servers':
        require __DIR__ . '/../templates/bounce_servers.php';
        break;
    case 'bounce-server-save':
        require_once __DIR__ . '/../src/BounceServerManager.php';
        $bsm = new BounceServerManager($db);
        $bsm->save($user->currentUserId());
        break;
    case 'bounce-server-delete':
        require_once __DIR__ . '/../src/BounceServerManager.php';
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
        require_once __DIR__ . '/../src/QueueManager.php';
        $qm = new QueueManager($db);
        $qm->addToQueue($user->currentUserId());
        break;
    case 'attachment-upload':
        require_once __DIR__ . '/../src/QueueManager.php';
        $qm = new QueueManager($db);
        $qm->uploadAttachment($user->currentUserId());
        break;
    case 'users':
        require __DIR__ . '/../templates/users.php';
        break;
    case 'user-save':
        if ($method === 'POST') {
            if ($user->currentUserRole() === 'admin') {
                $user->create($_POST['email'], $_POST['password'], $_POST['name'], $_POST['role']);
            }
            header('Location: users');
            exit;
        }
        break;
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
