<?php
require_once __DIR__ . '/../src/Tracking.php';
require_once __DIR__ . '/../src/Database.php';

$config = require __DIR__ . '/../config/config.php';
$db = new Database($config['db']);

$tracking = new Tracking($db);

$type = $_GET['type'] ?? '';
$id   = $_GET['id'] ?? '';

if ($type === 'open' && $id) {
    $tracking->logOpen($id, $_SERVER['REMOTE_ADDR'] ?? '', $_SERVER['HTTP_USER_AGENT'] ?? '');
    // Output 1x1 transparent GIF
    header('Content-Type: image/gif');
    echo base64_decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7');
    exit;
}

if ($type === 'click' && $id && isset($_GET['url'])) {
    $tracking->logClick($id, $_GET['url'], $_SERVER['REMOTE_ADDR'] ?? '', $_SERVER['HTTP_USER_AGENT'] ?? '');
    header('Location: ' . $_GET['url']);
    exit;
}

http_response_code(400);
echo 'Invalid tracking request';