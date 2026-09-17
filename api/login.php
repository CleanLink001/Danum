<?php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['email']) || !isset($data['password'])) {
    echo json_encode(["error" => "Incomplete data"]);
    exit();
}

$email = $conn->real_escape_string($data['email']);
$password = $data['password'];

$sql = "SELECT id, name, email, image, password FROM users WHERE email = '$email'";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $user = $result->fetch_assoc();
    if ($password == $user['password']) {
        unset($user['password']); // Don't send password back

        // Audit Log
        $u_name = $conn->real_escape_string($user['name']);
        $u_email = $conn->real_escape_string($user['email']);
        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $conn->query("INSERT INTO audit_logs (user_name, user_email, category, action, details, ip_address) VALUES ('$u_name', '$u_email', 'SECURITY', 'User Login', 'User authenticated successfully', '$ip')");

        echo json_encode([
            "success" => true,
            "user" => $user
        ]);
    } else {
        echo json_encode(["error" => "Invalid password"]);
    }
} else {
    echo json_encode(["error" => "User not found"]);
}

$conn->close();
?>
