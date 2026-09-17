<?php
require_once 'db.php';

// 1. Fetch latest reading
$sql_latest = "SELECT * FROM sensor_readings ORDER BY id DESC LIMIT 1";
$result_latest = $conn->query($sql_latest);
$latest = null;

if ($result_latest && $result_latest->num_rows > 0) {
    $row = $result_latest->fetch_assoc();
    $latest = [
        "ph" => (double)$row["ph"],
        "tds" => (double)$row["tds"],
        "turbidity" => (double)$row["turbidity"],
        "solarVoltage" => (double)$row["solar_voltage"],
        "filterHealth" => (double)$row["filter_health"],
        "valveOpen" => (int)$row["valve_open"] == 1,
        "timestamp" => $row["created_at"]
    ];
}

// 2. Fetch history (last 20 readings for graphing)
$sql_history = "SELECT * FROM (SELECT * FROM sensor_readings ORDER BY id DESC LIMIT 20) sub ORDER BY id ASC";
$result_history = $conn->query($sql_history);
$history = [];

if ($result_history && $result_history->num_rows > 0) {
    while ($row = $result_history->fetch_assoc()) {
        $history[] = [
            "ph" => (double)$row["ph"],
            "tds" => (double)$row["tds"],
            "turbidity" => (double)$row["turbidity"],
            "solarVoltage" => (double)$row["solar_voltage"],
            "filterHealth" => (double)$row["filter_health"],
            "valveOpen" => (int)$row["valve_open"] == 1,
            "timestamp" => $row["created_at"]
        ];
    }
}

// 3. Fetch historical logs (last 100 entries for Reports page)
$sql_logs = "SELECT * FROM (SELECT * FROM sensor_readings ORDER BY id DESC LIMIT 100) sub ORDER BY id ASC";
$result_logs = $conn->query($sql_logs);
$logs = [];

if ($result_logs && $result_logs->num_rows > 0) {
    while ($row = $result_logs->fetch_assoc()) {
        $logs[] = [
            "ph" => (double)$row["ph"],
            "tds" => (double)$row["tds"],
            "turbidity" => (double)$row["turbidity"],
            "solarVoltage" => (double)$row["solar_voltage"],
            "filterHealth" => (double)$row["filter_health"],
            "valveOpen" => (int)$row["valve_open"] == 1,
            "timestamp" => $row["created_at"]
        ];
    }
}

// 4. Fetch active controls
$sql_controls = "SELECT * FROM system_controls WHERE id = 1";
$result_controls = $conn->query($sql_controls);
$controls = [
    "manual_valve_override" => false,
    "valve_state" => true,
    "sync_interval" => 30
];

if ($result_controls && $result_controls->num_rows > 0) {
    $row = $result_controls->fetch_assoc();
    $controls = [
        "manual_valve_override" => (int)$row["manual_valve_override"] == 1,
        "valve_state" => (int)$row["valve_state"] == 1,
        "sync_interval" => (int)$row["sync_interval"]
    ];
}

echo json_encode([
    "success" => true,
    "latest" => $latest,
    "history" => $history,
    "logs" => $logs,
    "controls" => $controls
]);

$conn->close();
?>
