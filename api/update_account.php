<?php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['old_email']) || !isset($data['new_email']) || !isset($data['old_password']) || !isset($data['new_password'])) {
    echo json_encode(["error" => "Incomplete data"]);
    exit();
}

$old_email = $conn->real_escape_string($data['old_email']);
$new_email = $conn->real_escape_string($data['new_email']);
$old_password = $conn->real_escape_string($data['old_password']);
$new_password = $conn->real_escape_string($data['new_password']);

// 1. Verify old password
$checkPass = $conn->query("SELECT id FROM users WHERE email = '$old_email' AND password = '$old_password'");
if ($checkPass->num_rows == 0) {
    echo json_encode(["error" => "Incorrect old password"]);
    exit();
}

// 2. Check if new email exists and isn't the current one
if ($old_email != $new_email) {
    $check = $conn->query("SELECT id FROM users WHERE email = '$new_email'");
    if ($check->num_rows > 0) {
        echo json_encode(["error" => "New email is already in use"]);
        exit();
    }
}

// 3. Update account
$sql = "UPDATE users SET email = '$new_email', password = '$new_password' WHERE email = '$old_email'";

if ($conn->query($sql) === TRUE) {
    $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
    $conn->query("INSERT INTO audit_logs (user_name, user_email, category, action, details, ip_address) VALUES ('User', '$new_email', 'SECURITY', 'Account Credentials Updated', 'Email/Password updated', '$ip')");
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["error" => "Update failed: " . $conn->error]);
}

$conn->close();
?>
