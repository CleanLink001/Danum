<?php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!$data || !isset($data['action'])) {
    echo json_encode(["error" => "Action description is required"]);
    exit();
}

$user_name = isset($data['user_name']) ? $conn->real_escape_string($data['user_name']) : 'System';
$user_email = isset($data['user_email']) ? $conn->real_escape_string($data['user_email']) : 'system@danum.local';
$category = isset($data['category']) ? strtoupper($conn->real_escape_string($data['category'])) : 'SYSTEM';
$action = $conn->real_escape_string($data['action']);
$details = isset($data['details']) ? $conn->real_escape_string($data['details']) : '';
$ip_address = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';

// Ensure audit_logs table exists
$sql_create = "CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_name VARCHAR(255) DEFAULT 'System',
    user_email VARCHAR(255) DEFAULT 'system@danum.local',
    category VARCHAR(100) NOT NULL DEFAULT 'SYSTEM',
    action VARCHAR(255) NOT NULL,
    details TEXT DEFAULT NULL,
    ip_address VARCHAR(50) DEFAULT '127.0.0.1',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)";
$conn->query($sql_create);

$sql = "INSERT INTO audit_logs (user_name, user_email, category, action, details, ip_address) 
        VALUES ('$user_name', '$user_email', '$category', '$action', '$details', '$ip_address')";

if ($conn->query($sql) === TRUE) {
    echo json_encode(["success" => true, "id" => $conn->insert_id]);
} else {
    echo json_encode(["error" => "Failed to log audit: " . $conn->error]);
}

$conn->close();
?>
