<?php
require_once __DIR__ . '/../src/Helpers.php';
$currentUser = new User($GLOBALS['db']);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>bMTA - Bulk Mail Transfer Agent</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="assets/style.css" rel="stylesheet">
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
    <div class="container">
        <a class="navbar-brand" href="dashboard">bMTA</a>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#nav">
            <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="nav">
            <ul class="navbar-nav me-auto">
                <li class="nav-item"><a class="nav-link" href="dashboard">Dashboard</a></li>
                <li class="nav-item"><a class="nav-link" href="domains">Domains</a></li>
                <li class="nav-item"><a class="nav-link" href="senders">Senders</a></li>
                <li class="nav-item"><a class="nav-link" href="bounce-servers">Bounce Servers</a></li>
                <li class="nav-item"><a class="nav-link" href="compose">Compose</a></li>
                <li class="nav-item"><a class="nav-link" href="queue">Queue</a></li>
                <?php if ($currentUser->currentUserRole() === 'admin'): ?>
                <li class="nav-item"><a class="nav-link" href="users">Users</a></li>
                <?php endif; ?>
            </ul>
            <span class="navbar-text">
                <?= Helpers::sanitize($currentUser->currentUserRole()) ?> | 
                <a href="logout" class="text-light">Logout</a>
            </span>
        </div>
    </div>
</nav>
<div class="container">