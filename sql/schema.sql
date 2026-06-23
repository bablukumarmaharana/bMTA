SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;

CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `role` enum('admin','user') DEFAULT 'user',
  `reset_token` varchar(64) DEFAULT NULL,
  `reset_expires` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `domains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `domain` varchar(255) NOT NULL,
  `dkim_private` text DEFAULT NULL,
  `dkim_public` text DEFAULT NULL,
  `dkim_selector` varchar(50) DEFAULT 'default',
  `spf_record` varchar(255) DEFAULT NULL,
  `dmarc_record` varchar(255) DEFAULT NULL,
  `mx_record` varchar(255) DEFAULT NULL,
  `verified` tinyint(1) DEFAULT 0,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `domain` (`domain`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `domains_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `bounce_servers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `host` varchar(255) NOT NULL,
  `port` smallint(6) DEFAULT 993,
  `encryption` enum('ssl','tls','none') DEFAULT 'ssl',
  `username` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `bounce_servers_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `senders` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `domain_id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `password` varchar(255) NOT NULL,         -- SMTP auth (bcrypt)
  `bounce_email` varchar(255) DEFAULT NULL, -- return-path
  `bounce_server_id` int(11) DEFAULT NULL,
  `active` tinyint(1) DEFAULT 1,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `domain_id` (`domain_id`),
  KEY `user_id` (`user_id`),
  KEY `bounce_server_id` (`bounce_server_id`),
  CONSTRAINT `senders_ibfk_1` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`id`) ON DELETE CASCADE,
  CONSTRAINT `senders_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `senders_ibfk_3` FOREIGN KEY (`bounce_server_id`) REFERENCES `bounce_servers` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `sender_custom_headers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sender_id` int(11) NOT NULL,
  `header_name` varchar(255) NOT NULL,
  `header_value` text NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sender_id` (`sender_id`),
  CONSTRAINT `sender_headers_ibfk_1` FOREIGN KEY (`sender_id`) REFERENCES `senders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `attachments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `filename` varchar(255) NOT NULL,
  `mime_type` varchar(100) NOT NULL,
  `file_path` varchar(500) NOT NULL,
  `size` int(11) NOT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `attachments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `email_queue` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `recipient` varchar(255) NOT NULL,
  `subject` varchar(998) NOT NULL,
  `body_html` text DEFAULT NULL,
  `body_text` text DEFAULT NULL,
  `amp_html` text DEFAULT NULL,
  `custom_headers` text DEFAULT NULL,     -- JSON: {"Header":"value",...}
  `status` enum('pending','sending','sent','failed','bounced') DEFAULT 'pending',
  `message_id` varchar(255) DEFAULT NULL,
  `attempts` tinyint(4) DEFAULT 0,
  `last_attempt` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `status` (`status`),
  KEY `sender_id` (`sender_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `email_queue_ibfk_1` FOREIGN KEY (`sender_id`) REFERENCES `senders` (`id`) ON DELETE CASCADE,
  CONSTRAINT `email_queue_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `email_attachments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `queue_id` bigint(20) NOT NULL,
  `attachment_id` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `queue_id` (`queue_id`),
  KEY `attachment_id` (`attachment_id`),
  CONSTRAINT `email_att_ibfk_1` FOREIGN KEY (`queue_id`) REFERENCES `email_queue` (`id`) ON DELETE CASCADE,
  CONSTRAINT `email_att_ibfk_2` FOREIGN KEY (`attachment_id`) REFERENCES `attachments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `tracking_opens` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `queue_id` bigint(20) NOT NULL,
  `recipient` varchar(255) NOT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `event_time` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `queue_id` (`queue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `tracking_clicks` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `queue_id` bigint(20) NOT NULL,
  `recipient` varchar(255) NOT NULL,
  `url` varchar(2048) NOT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `user_agent` varchar(500) DEFAULT NULL,
  `event_time` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `queue_id` (`queue_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `suppression_list` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `recipient` varchar(255) NOT NULL,
  `reason` enum('bounce','complaint','manual') DEFAULT 'bounce',
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `recipient` (`recipient`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

COMMIT;