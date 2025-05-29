<?php
require_once 'config.php';

// Enable CORS
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Get the request method and action
$method = $_SERVER['REQUEST_METHOD'];
$action = isset($_GET['action']) ? $_GET['action'] : '';

// Function to send JSON response
function sendResponse($data, $status = 200) {
    http_response_code($status);
    echo json_encode($data);
    exit();
}

// Function to handle errors
function handleError($message, $status = 500) {
    sendResponse([
        'status' => 'error',
        'message' => $message
    ], $status);
}

try {
    switch ($method) {
        case 'GET':
            switch ($action) {
                case 'get_current_user':
                    // Get user ID from request
                    $userId = $_GET['user_id'] ?? null;

                    if (!$userId) {
                        handleError('User ID is required', 400);
                    }

                    try {
                        // Prepare and execute the query
                        $stmt = $pdo->prepare("
                            SELECT id, name, first_name, email, role, created_at, updated_at
                            FROM ardent_ticket.users 
                            WHERE id = ?
                        ");
                        $stmt->execute([$userId]);
                        $user = $stmt->fetch(PDO::FETCH_ASSOC);

                        if ($user) {
                            sendResponse([
                                'success' => true,
                                'data' => $user
                            ]);
                        } else {
                            handleError('User not found', 404);
                        }
                    } catch (PDOException $e) {
                        error_log('Database error in get_current_user: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'get_tickets':
                    try {
                        // First check if the tables exist
                        $checkTables = $pdo->query("
                            SELECT COUNT(*) as table_count 
                            FROM information_schema.tables 
                            WHERE table_schema = 'ardent_ticket' 
                            AND table_name IN ('tickets', 'ticket_categories', 'ticket_attachments')
                        ");
                        $tableCount = $checkTables->fetch(PDO::FETCH_ASSOC)['table_count'];
                        
                        if ($tableCount < 3) {
                            handleError('Required tables are missing. Please run the database setup script.');
                        }

                        // Updated query to include file data and contact information
                        $query = "SELECT 
                                    t.id,
                                    t.user_id,
                                    t.ticket_type,
                                    t.assigned_agent,
                                    t.subscription_id,
                                    t.description,
                                    t.status,
                                    t.created_at,
                                    CONCAT(u.name, ' ', u.first_name) as contact_name,
                                    GROUP_CONCAT(ta.original_name) as attachments
                                FROM ardent_ticket.tickets t
                                LEFT JOIN ardent_ticket.ticket_attachments ta ON t.id = ta.ticket_id
                                LEFT JOIN ardent_ticket.users u ON t.assigned_agent = u.id
                                GROUP BY t.id
                                ORDER BY t.created_at DESC";
                        
                        $result = $pdo->query($query);
                        
                        if ($result) {
                            $tickets = array();
                            while ($row = $result->fetch(PDO::FETCH_ASSOC)) {
                                $attachments = [];
                                if ($row['attachments']) {
                                    $attachment_names = explode(',', $row['attachments']);
                                    foreach ($attachment_names as $name) {
                                        if (!empty($name)) {
                                            $attachments[] = ['original_name' => $name];
                                        }
                                    }
                                }
                                
                                $tickets[] = array(
                                    'id' => $row['id'] ?? null,
                                    'user_id' => $row['user_id'] ?? null,
                                    'type' => $row['ticket_type'] ?? 'Uncategorized',
                                    'contact' => $row['assigned_agent'] ?? 'Not Assigned',
                                    'contact_name' => $row['contact_name'] ?? 'Not Assigned',
                                    'subscription' => $row['subscription_id'] ?? null,
                                    'description' => $row['description'] ?? 'No description',
                                    'attachments' => $attachments,
                                    'status' => $row['status'] ?? 'open',
                                    'created_at' => $row['created_at'] ?? null
                                );
                            }
                            sendResponse(['status' => 'success', 'data' => $tickets]);
                        } else {
                            handleError('Failed to fetch tickets');
                        }
                    } catch (Exception $e) {
                        error_log('Exception in get_tickets: ' . $e->getMessage());
                        handleError('Error fetching tickets: ' . $e->getMessage());
                    }
                    break;

                case 'get_categories':
                    $stmt = $pdo->query("SELECT * FROM ardent_ticket.ticket_categories");
                    $categories = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    sendResponse(['status' => 'success', 'data' => $categories]);
                    break;

                case 'get_agents':
                    $stmt = $pdo->query("SELECT * FROM ardent_ticket.users WHERE role = 'agent'");
                    $agents = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    sendResponse(['status' => 'success', 'data' => $agents]);
                    break;

                case 'get_subscriptions':
                    $stmt = $pdo->query("SELECT * FROM ardent_ticket.subscription_header");
                    $subscriptions = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    sendResponse(['status' => 'success', 'data' => $subscriptions]);
                    break;

                case 'get_billing_cycles':
                    try {
                        $subscription_id = $_GET['subscription_id'] ?? null;
                        
                        if (!$subscription_id) {
                            handleError('Subscription ID is required', 400);
                        }

                        $stmt = $pdo->prepare("
                            SELECT 
                                bc.id,
                                bc.subscriptionId,
                                bc.startDate,
                                bc.endDate,
                                bc.usageLimitGB,
                                bc.consumedAmountGB,
                                bc.totalPriorityGB,
                                bc.totalStandardGB,
                                bc.totalOptInPriorityGB,
                                bc.totalNonBillableGB,
                                sh.subscription_number as subscriptionNumber,
                                sh.customer_name as customerName,
                                sh.status as subscriptionStatus
                            FROM ardent_ticket.billingcycles bc
                            JOIN ardent_ticket.subscription_header sh ON bc.subscriptionId = sh.id
                            WHERE bc.subscriptionId = ?
                            ORDER BY bc.startDate DESC
                        ");
                        
                        $stmt->execute([$subscription_id]);
                        $cycles = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        
                        // Format the data for display
                        $formatted_cycles = array_map(function($cycle) {
                            return [
                                'id' => $cycle['id'],
                                'subscriptionId' => $cycle['subscriptionId'],
                                'subscriptionNumber' => $cycle['subscriptionNumber'],
                                'customerName' => $cycle['customerName'],
                                'subscriptionStatus' => $cycle['subscriptionStatus'],
                                'startDate' => $cycle['startDate'],
                                'endDate' => $cycle['endDate'],
                                'usageLimitGB' => number_format($cycle['usageLimitGB'], 2),
                                'consumedAmountGB' => number_format($cycle['consumedAmountGB'], 2),
                                'totalPriorityGB' => number_format($cycle['totalPriorityGB'], 2),
                                'totalStandardGB' => number_format($cycle['totalStandardGB'], 2),
                                'totalOptInPriorityGB' => number_format($cycle['totalOptInPriorityGB'], 2),
                                'totalNonBillableGB' => number_format($cycle['totalNonBillableGB'], 2),
                                'usagePercentage' => $cycle['usageLimitGB'] > 0 ? 
                                    number_format(($cycle['consumedAmountGB'] / $cycle['usageLimitGB']) * 100, 2) : 0
                            ];
                        }, $cycles);
                        
                        sendResponse([
                            'status' => 'success',
                            'data' => $formatted_cycles
                        ]);
                    } catch (PDOException $e) {
                        error_log('Database error in get_billing_cycles: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'get_end_users':
                    try {
                        $customer_code = $_GET['customer_code'] ?? null;
                        
                        $query = "
                            SELECT 
                                id,
                                eu_code,
                                eu_name,
                                inactive,
                                customer_code,
                                created_at,
                                updated_at
                            FROM ardent_ticket.end_users
                        ";
                        
                        $params = [];
                        if ($customer_code) {
                            $query .= " WHERE customer_code = ?";
                            $params[] = $customer_code;
                        }
                        
                        $query .= " ORDER BY eu_name ASC";
                        
                        $stmt = $pdo->prepare($query);
                        $stmt->execute($params);
                        $end_users = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        
                        sendResponse([
                            'status' => 'success',
                            'data' => $end_users
                        ]);
                    } catch (PDOException $e) {
                        error_log('Database error in get_end_users: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'get_customers':
                    try {
                        // Query to get all customers (users with role 'customer')
                        $stmt = $pdo->query("
                            SELECT id, name, first_name, email, role, created_at, updated_at 
                            FROM ardent_ticket.users 
                            WHERE role = 'customer' 
                            ORDER BY name ASC
                        ");
                        $customers = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        
                        if ($customers) {
                            sendResponse([
                                'status' => 'success',
                                'data' => $customers
                            ]);
                        } else {
                            sendResponse([
                                'status' => 'success',
                                'data' => []
                            ]);
                        }
                    } catch (PDOException $e) {
                        error_log('Database error in get_customers: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'download_attachment':
                    if (!isset($_GET['attachment_id'])) {
                        handleError('Missing attachment ID', 400);
                    }

                    try {
                        $stmt = $pdo->prepare("
                            SELECT original_name, file_data, file_type 
                            FROM ardent_ticket.ticket_attachments 
                            WHERE id = ?
                        ");
                        $stmt->execute([$_GET['attachment_id']]);
                        $attachment = $stmt->fetch(PDO::FETCH_ASSOC);

                        if (!$attachment) {
                            handleError('Attachment not found', 404);
                        }

                        // Set headers for file download
                        header('Content-Type: ' . $attachment['file_type']);
                        header('Content-Disposition: attachment; filename="' . $attachment['original_name'] . '"');
                        header('Content-Length: ' . strlen($attachment['file_data']));
                        
                        // Output the file data
                        echo $attachment['file_data'];
                        exit();
                    } catch (PDOException $e) {
                        error_log('Database error in download_attachment: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                default:
                    handleError('Invalid action', 400);
                    break;
            }
            break;

        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            
            switch ($action) {
                case 'create_ticket':
                    // Debug log the received data
                    error_log('Received ticket data: ' . json_encode($data));
                    
                    // Check for all required fields
                    if (!isset($data['type']) || !isset($data['contact']) || !isset($data['subscription']) || !isset($data['description']) || !isset($data['user_id'])) {
                        error_log('Missing required fields in request: ' . json_encode($data));
                        handleError('Missing required fields', 400);
                    }

                    $pdo->beginTransaction();
                    
                    try {
                        // Debug log for user check
                        error_log('Checking user ID: ' . $data['user_id']);

                        // First verify that the user exists
                        $userCheck = $pdo->prepare("SELECT id FROM ardent_ticket.users WHERE id = :user_id");
                        $userCheck->execute([':user_id' => $data['user_id']]);
                        $user = $userCheck->fetch();
                        
                        if (!$user) {
                            error_log('User not found with ID: ' . $data['user_id']);
                            throw new Exception('User not found with ID: ' . $data['user_id']);
                        }

                        error_log('User found, proceeding with ticket creation');

                        // Insert the ticket
                        $stmt = $pdo->prepare("
                            INSERT INTO ardent_ticket.tickets 
                            (user_id, ticket_type, assigned_agent, subscription_id, description, status) 
                            VALUES (:user_id, :ticket_type, :assigned_agent, :subscription_id, :description, 'open')
                        ");
                        
                        $stmt->execute([
                            ':user_id' => $data['user_id'],
                            ':ticket_type' => $data['type'],
                            ':assigned_agent' => $data['contact'],
                            ':subscription_id' => $data['subscription'],
                            ':description' => $data['description']
                        ]);
                        
                        $ticket_id = $pdo->lastInsertId();
                        error_log('Ticket created with ID: ' . $ticket_id);

                        // Process attachments if present
                        if (isset($data['attachments']) && is_array($data['attachments'])) {
                            error_log('Processing ' . count($data['attachments']) . ' attachments');
                            
                            $attachment_stmt = $pdo->prepare("
                                INSERT INTO ardent_ticket.ticket_attachments 
                                (ticket_id, original_name, file_name, file_type, file_size, file_data, uploaded_by) 
                                VALUES (:ticket_id, :original_name, :file_name, :file_type, :file_size, :file_data, :uploaded_by)
                            ");

                            foreach ($data['attachments'] as $index => $attachment) {
                                error_log('Processing attachment ' . ($index + 1) . ': ' . json_encode($attachment));
                                
                                if (isset($attachment['file_data']) && isset($attachment['original_name'])) {
                                    // Decode base64 file data
                                    $file_data = base64_decode($attachment['file_data']);
                                    if ($file_data === false) {
                                        error_log('Failed to decode base64 data for file: ' . $attachment['original_name']);
                                        throw new Exception('Invalid file data format for file: ' . $attachment['original_name']);
                                    }

                                    error_log('Successfully decoded file data for: ' . $attachment['original_name']);

                                    $attachment_stmt->execute([
                                        ':ticket_id' => $ticket_id,
                                        ':original_name' => $attachment['original_name'],
                                        ':file_name' => $attachment['file_name'] ?? $attachment['original_name'],
                                        ':file_type' => $attachment['file_type'] ?? 'application/octet-stream',
                                        ':file_size' => $attachment['file_size'] ?? strlen($file_data),
                                        ':file_data' => $file_data,
                                        ':uploaded_by' => $data['user_id']
                                    ]);

                                    error_log('Successfully stored attachment: ' . $attachment['original_name']);
                                } else {
                                    error_log('Skipping attachment due to missing required fields: ' . json_encode($attachment));
                                }
                            }
                        } else {
                            error_log('No attachments found in request');
                        }

                        $pdo->commit();
                        error_log('Transaction committed successfully');
                        
                        sendResponse([
                            'status' => 'success',
                            'message' => 'Ticket created successfully',
                            'ticket_id' => $ticket_id
                        ]);
                    } catch (Exception $e) {
                        $pdo->rollBack();
                        error_log('Exception creating ticket: ' . $e->getMessage());
                        handleError($e->getMessage());
                    }
                    break;

                case 'update_ticket_status':
                    // Validate required fields
                    if (!isset($data['ticket_id']) || !isset($data['status'])) {
                        handleError('Missing required fields', 400);
                    }
                    
                    $ticket_id = $data['ticket_id'];
                    $new_status = strtolower($data['status']);
                    
                    // Validate status value
                    $valid_statuses = ['open', 'closed', 'done', 'in progress'];
                    if (!in_array($new_status, $valid_statuses)) {
                        handleError('Invalid status value', 400);
                    }
                    
                    try {
                        // Update the ticket status in the database
                        $stmt = $pdo->prepare("
                            UPDATE ardent_ticket.tickets 
                            SET status = ? 
                            WHERE id = ?
                        ");
                        $result = $stmt->execute([$new_status, $ticket_id]);
                        
                        if ($result) {
                            sendResponse([
                                'status' => 'success',
                                'message' => 'Ticket status updated successfully'
                            ]);
                        } else {
                            handleError('Failed to update ticket status');
                        }
                    } catch (PDOException $e) {
                        error_log('Database error in update_ticket_status: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'update_password':
                    // Validate required fields
                    if (!isset($data['user_id']) || !isset($data['current_password']) || !isset($data['new_password'])) {
                        handleError('Missing required fields', 400);
                    }

                    try {
                        // First verify the current password
                        $stmt = $pdo->prepare("
                            SELECT password 
                            FROM ardent_ticket.users 
                            WHERE id = ?
                        ");
                        $stmt->execute([$data['user_id']]);
                        $user = $stmt->fetch();

                        if (!$user) {
                            handleError('User not found', 404);
                        }

                        // Verify current password
                        if (!password_verify($data['current_password'], $user['password'])) {
                            handleError('Current password is incorrect', 400);
                        }

                        // Update the password
                        $new_password_hash = password_hash($data['new_password'], PASSWORD_DEFAULT);
                        $update_stmt = $pdo->prepare("
                            UPDATE ardent_ticket.users 
                            SET password = ? 
                            WHERE id = ?
                        ");
                        
                        if ($update_stmt->execute([$new_password_hash, $data['user_id']])) {
                            sendResponse([
                                'status' => 'success',
                                'message' => 'Password updated successfully'
                            ]);
                        } else {
                            handleError('Failed to update password');
                        }
                    } catch (PDOException $e) {
                        error_log('Database error in update_password: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                default:
                    handleError('Invalid action', 400);
                    break;
            }
            break;

        default:
            handleError('Method not allowed', 405);
            break;
    }
} catch (Exception $e) {
    handleError($e->getMessage());
}
?> 