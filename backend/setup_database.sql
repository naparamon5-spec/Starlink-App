-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS starlink_db;

-- Use the database
USE starlink_db;

-- Create a test table to verify the connection
CREATE TABLE IF NOT EXISTS test_connection (
    id INT AUTO_INCREMENT PRIMARY KEY,
    test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50)
);

-- Insert a test record
INSERT INTO test_connection (status) VALUES ('Database setup successful'); 