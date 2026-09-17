<?php
require_once 'db.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['email']) || !isset($data['name'])) {
    echo json_encode(["error" => "Incomplete data"]);
    exit();
}

$email = $conn->real_escape_string($data['email']);
$name = $conn->real_escape_string($data['name']);
$image = isset($data['image']) ? $conn->real_escape_string($data['image']) : null;

$sql = "UPDATE users SET name = '$name', image = " . ($image ? "'$image'" : "NULL") . " WHERE email = '$email'";

if ($conn->query($sql) === TRUE) {
    echo json_encode(["success" => true]);
} else {
    echo json_encode(["error" => "Update failed: " . $conn->error]);
}

$conn->close();
?>
