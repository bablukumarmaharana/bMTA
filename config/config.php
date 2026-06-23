<?php
return [
    'db' => [
        'host'   => getenv('BMTA_DB_HOST') ?: 'localhost',
        'dbname' => getenv('BMTA_DB_NAME') ?: 'bmta',
        'user'   => getenv('BMTA_DB_USER') ?: 'bmta',
        'pass'   => getenv('BMTA_DB_PASS') ?: 'bmta_secret',  // only fallback if not set
        'charset'=> 'utf8mb4',
    ],
    'app' => [
        'base_url'       => getenv('BMTA_BASE_URL') ?: 'http://localhost/',
        'tracking_pixel' => 'track/open/',
        'click_rewrite'  => 'track/click/',
        'dkim_key_size'  => 2048,
        'upload_dir'     => __DIR__ . '/../public/uploads',
    ],
];