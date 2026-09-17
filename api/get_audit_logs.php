<?php
require_once 'db.php';

// Check if audit_logs table exists
$table_check = $conn->query("SHOW TABLES LIKE 'audit_logs'");
if ($table_check->num_rows == 0) {
    // Auto-create table if not yet imported into MySQL
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
}

$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
$sql = "SELECT id, user_name, user_email, category, action, details, ip_address, created_at FROM audit_logs ORDER BY created_at DESC LIMIT $limit";

$result = $conn->query($sql);
$logs = [];

if ($result && $result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $logs[] = [
            "id" => (int)$row["id"],
            "user_name" => $row["user_name"],
            "user_email" => $row["user_email"],
            "category" => $row["category"],
            "action" => $row["action"],
            "details" => $row["details"],
            "ip_address" => $row["ip_address"],
            "created_at" => $row["created_at"]
        ];
    }
}

echo json_encode(["success" => true, "logs" => $logs]);
$conn->close();
?>
