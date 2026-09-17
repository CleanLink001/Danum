<?php
require_once 'db.php';

// Accept JSON payload from ESP32
$data = json_decode(file_get_contents("php://input"), true);

if (
    !isset($data['ph']) || 
    !isset($data['tds']) || 
    !isset($data['turbidity']) || 
    !isset($data['solar_voltage']) || 
    !isset($data['filter_health']) || 
    !isset($data['valve_open'])
) {
    echo json_encode(["error" => "Incomplete sensor data"]);
    exit();
}

$ph = (double)$data['ph'];
$tds = (double)$data['tds'];
$turbidity = (double)$data['turbidity'];
$solar_voltage = (double)$data['solar_voltage'];
$filter_health = (double)$data['filter_health'];
$valve_open = (int)$data['valve_open'];

// 1. Insert sensor reading
$sql_insert = "INSERT INTO sensor_readings (ph, tds, turbidity, solar_voltage, filter_health, valve_open) 
               VALUES ($ph, $tds, $turbidity, $solar_voltage, $filter_health, $valve_open)";

$insert_success = $conn->query($sql_insert);

// 2. Fetch the current system controls to return to the ESP32 in the same round-trip
$sql_controls = "SELECT manual_valve_override, valve_state, sync_interval FROM system_controls WHERE id = 1";
$result_controls = $conn->query($sql_controls);

$controls = [
    "manual_valve_override" => 0,
    "valve_state" => 1,
    "sync_interval" => 30
];

if ($result_controls && $result_controls->num_rows > 0) {
    $row = $result_controls->fetch_assoc();
    $controls["manual_valve_override"] = (int)$row["manual_valve_override"];
    $controls["valve_state"] = (int)$row["valve_state"];
    $controls["sync_interval"] = (int)$row["sync_interval"];
}

echo json_encode([
    "success" => $insert_success === TRUE,
    "manual_valve_override" => $controls["manual_valve_override"],
    "valve_state" => $controls["valve_state"],
    "sync_interval" => $controls["sync_interval"]
]);

$conn->close();
?>
