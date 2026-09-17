CREATE DATABASE IF NOT EXISTS danum_db;
USE danum_db;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    image LONGTEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Test Accounts
INSERT INTO users (name, email, password) VALUES 
('Developer', 'test@example.com', 'Password123!'),
('User Account', 'user@example.com', 'Password123!')
ON DUPLICATE KEY UPDATE password = VALUES(password);

-- Table to store IoT sensor readings history
CREATE TABLE IF NOT EXISTS sensor_readings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ph DOUBLE NOT NULL,
    tds DOUBLE NOT NULL,
    turbidity DOUBLE NOT NULL,
    solar_voltage DOUBLE NOT NULL,
    filter_health DOUBLE NOT NULL,
    valve_open TINYINT(1) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to hold the active control parameters
CREATE TABLE IF NOT EXISTS system_controls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    manual_valve_override TINYINT(1) DEFAULT 0,
    valve_state TINYINT(1) DEFAULT 1,
    sync_interval INT DEFAULT 30,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Seed dynamic control settings (Row 1 represents active controls)
INSERT INTO system_controls (id, manual_valve_override, valve_state, sync_interval) VALUES 
(1, 0, 1, 30)
ON DUPLICATE KEY UPDATE id = id;

-- Table to store system and user activity audit trail
CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_name VARCHAR(255) DEFAULT 'System',
    user_email VARCHAR(255) DEFAULT 'system@danum.local',
    category VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    action VARCHAR(255) NOT NULL,
    details TEXT DEFAULT NULL,
    ip_address VARCHAR(50) DEFAULT '127.0.0.1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed initial audit log history
INSERT INTO audit_logs (user_name, user_email, category, action, details) VALUES
('Developer', 'test@example.com', 'SECURITY', 'User Login', 'Successful authentication via Android Client'),
('System', 'system@danum.local', 'VALVE_CONTROL', 'Auto Safety Rule Triggered', 'Valve set to OPEN (Water quality Nominal: pH 7.2, TDS 180ppm)'),
('User Account', 'user@example.com', 'SETTINGS', 'Sync Interval Updated', 'Cloud telemetry refresh interval changed to 10 seconds');


