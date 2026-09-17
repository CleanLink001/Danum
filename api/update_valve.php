<?php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!$data) {
    echo json_encode(["error" => "Incomplete request data"]);
    exit();
}

$updates = [];

if (isset($data['manual_valve_override'])) {
    $override = (int)$data['manual_valve_override'];
    $updates[] = "manual_valve_override = $override";
}

if (isset($data['valve_state'])) {
    $state = (int)$data['valve_state'];
    $updates[] = "valve_state = $state";
}

if (isset($data['sync_interval'])) {
    $interval = (int)$data['sync_interval'];
    $updates[] = "sync_interval = $interval";
}

if (empty($updates)) {
    echo json_encode(["error" => "No parameters to update"]);
    exit();
}

$sql_update = "UPDATE system_controls SET " . implode(", ", $updates) . " WHERE id = 1";

if ($conn->query($sql_update) === TRUE) {
    $detail_str = implode(", ", $updates);
    $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    $conn->query("INSERT INTO audit_logs (user_name, user_email, category, action, details, ip_address) VALUES ('User/Operator', 'operator@danum.local', 'VALVE_CONTROL', 'System Control Updated', '$detail_str', '$ip')");
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["error" => "Update failed: " . $conn->error]);
}

$conn->close();
?>
