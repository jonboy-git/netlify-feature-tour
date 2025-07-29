-- Initialize IPTV Panel Database
USE iptv_panel;

-- Import the original schema
SOURCE /var/www/html/sql.sql;

-- Performance optimizations
ALTER TABLE users ADD INDEX idx_username (username);
ALTER TABLE users ADD INDEX idx_email (email);
ALTER TABLE users ADD INDEX idx_status (status);
ALTER TABLE users ADD INDEX idx_created_at (created_at);

-- Streaming optimizations (if tables exist)
ALTER TABLE streams ADD INDEX idx_status (status) IF EXISTS;
ALTER TABLE streams ADD INDEX idx_category (category) IF EXISTS;
ALTER TABLE streams ADD INDEX idx_created_at (created_at) IF EXISTS;

-- Session optimization
CREATE TABLE IF NOT EXISTS user_sessions (
    id VARCHAR(128) NOT NULL PRIMARY KEY,
    user_id INT,
    data TEXT,
    last_activity TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_last_activity (last_activity)
) ENGINE=InnoDB;

-- Cache table for frequent queries
CREATE TABLE IF NOT EXISTS query_cache (
    cache_key VARCHAR(255) NOT NULL PRIMARY KEY,
    cache_data TEXT,
    expires_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_expires (expires_at)
) ENGINE=InnoDB;

-- Statistics table for monitoring
CREATE TABLE IF NOT EXISTS stream_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    stream_id INT,
    user_id INT,
    action ENUM('play', 'stop', 'pause', 'seek') DEFAULT 'play',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address VARCHAR(45),
    user_agent TEXT,
    INDEX idx_stream_id (stream_id),
    INDEX idx_user_id (user_id),
    INDEX idx_timestamp (timestamp),
    INDEX idx_ip (ip_address)
) ENGINE=InnoDB;

-- Load balancer health check table
CREATE TABLE IF NOT EXISTS health_check (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_name VARCHAR(100),
    status ENUM('healthy', 'unhealthy') DEFAULT 'healthy',
    last_check TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    response_time INT DEFAULT 0,
    INDEX idx_server (server_name),
    INDEX idx_status (status)
) ENGINE=InnoDB;

-- Insert initial health check records
INSERT INTO health_check (server_name, status) VALUES 
('web1', 'healthy'),
('web2', 'healthy'),
('web3', 'healthy'),
('streaming-server', 'healthy'),
('db-master', 'healthy'),
('redis', 'healthy')
ON DUPLICATE KEY UPDATE last_check = CURRENT_TIMESTAMP;

-- Performance monitoring table
CREATE TABLE IF NOT EXISTS performance_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    metric_name VARCHAR(100),
    metric_value DECIMAL(10,2),
    server_name VARCHAR(100),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_metric_name (metric_name),
    INDEX idx_server (server_name),
    INDEX idx_timestamp (timestamp)
) ENGINE=InnoDB;

-- Create replication user for slave server
CREATE USER IF NOT EXISTS 'replication'@'%' IDENTIFIED BY 'replication_password_123';
GRANT REPLICATION SLAVE ON *.* TO 'replication'@'%';

-- Create monitoring user
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor_password_123';
GRANT SELECT ON iptv_panel.* TO 'monitor'@'%';
GRANT SELECT ON performance_schema.* TO 'monitor'@'%';

-- Optimize existing tables
OPTIMIZE TABLE users;

FLUSH PRIVILEGES;