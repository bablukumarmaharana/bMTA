<?php
session_start();
require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/User.php';

$config = require __DIR__ . '/../config/config.php';
$db = new Database($config['db']);
$user = new User($db);

// If no users exist, redirect to first‑time setup
if ($user->countUsers() === 0 && ($_GET['url'] ?? '') !== 'setup') {
    header('Location: setup');
    exit;
}

$url = $_GET['url'] ?? 'dashboard';
$url = rtrim($url, '/');

$protected = ['dashboard','domains','senders','bounce-servers','compose','queue','users','logout','domain-save','sender-save','bounce-server-save','queue-add','attachment-upload'];
$adminOnly = ['users'];  // admin pages

if (in_array($url, $protected)) {
    if (!$user->isLoggedIn()) {
        $url = 'login';
    } elseif ($user->currentUserRole() !== 'admin' && in_array($url, $adminOnly)) {
        http_response_code(403);
        die('Access denied');
    }
}

switch ($url) {
    case 'setup':
        require __DIR__ . '/setup.php';
        break;
    case 'login':
        require __DIR__ . '/../templates/login.php';
        break;
    case 'logout':
        $user->logout();
        header('Location: login');
        exit;
    // ... other routes (dashboard, domains, senders, bounce-servers, compose, queue, users)
    default:
        http_response_code(404);
        echo 'Page not found';
}