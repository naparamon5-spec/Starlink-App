<?php
// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config.php';

header('Content-Type: application/json');

try {
    // Test the connection by querying the test table
    $stmt = $pdo->query('SELECT * FROM test_connection ORDER BY test_date DESC LIMIT 1');
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        echo json_encode([
            'status' => 'success',
            'message' => 'Database connection successful',
            'data' => $result
        ]);
    } else {
        echo json_encode([
            'status' => 'error',
            'message' => 'No test records found'
        ]);
    }
} catch(PDOException $e) {
    echo json_encode([
        'status' => 'error',
        'message' => 'Database connection failed: ' . $e->getMessage(),
        'error_details' => [
            'code' => $e->getCode(),
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
    ]);
}
?> 