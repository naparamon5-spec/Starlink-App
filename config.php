<?php
// Database configuration
$host = 'localhost';
$dbname = 'ardent_ticket';
$username = 'root';  // Make sure this user has proper permissions
$password = '';      // Your database password

try {
    $pdo = new PDO(
        "mysql:host=$host;dbname=$dbname;charset=utf8mb4",
        $username,
        $password,
        [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false
        ]
    );
    
    // Test the connection
    $pdo->query("SELECT 1");
    error_log("Database connection successful");
    
} catch(PDOException $e) {
    error_log("Database connection failed: " . $e->getMessage());
    die(json_encode([
        'status' => 'error',
        'message' => 'Database connection failed'
    ]));
}
?> 