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
                    $userId = isset($_GET['user_id']) ? intval($_GET['user_id']) : null;

                    if (!$userId) {
                        handleError('User ID is required', 400);
                    }

                    try {
                        $stmt = $pdo->prepare("
                            SELECT id, name, first_name, email, role, created_at, updated_at
                            FROM ardent_ticket.users 
                            WHERE id = ?
                        ");
                        $stmt->execute([$userId]);
                        $user = $stmt->fetch(PDO::FETCH_ASSOC);

                        if ($user) {
                            sendResponse([
                                'status' => 'success',
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
                        $query = "SELECT 
                                    t.id,
                                    t.user_id,
                                    t.ticket_type,
                                    t.assigned_agent,
                                    t.subscription_id,
                                    t.description,
                                    t.status,
                                    t.subject,
                                    t.created_at,
                                    CONCAT(u.name, ' ', u.first_name) as contact_name,
                                    GROUP_CONCAT(ta.original_name) as attachments
                                FROM ardent_ticket.tickets t
                                LEFT JOIN ardent_ticket.ticket_attachments ta ON t.id = ta.ticket_id
                                LEFT JOIN ardent_ticket.users u ON t.assigned_agent = u.id
                                GROUP BY t.id, t.user_id, t.ticket_type, t.assigned_agent, 
                                         t.subscription_id, t.description, t.status, 
                                         t.subject, t.created_at, u.name, u.first_name
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
                                    'id' => intval($row['id']),
                                    'user_id' => intval($row['user_id']),
                                    'type' => $row['ticket_type'],
                                    'contact' => intval($row['assigned_agent']),
                                    'contact_name' => $row['contact_name'],
                                    'subscription' => $row['subscription_id'],
                                    'description' => $row['description'],
                                    'subject' => $row['subject'],
                                    'attachments' => $attachments,
                                    'status' => $row['status'],
                                    'created_at' => $row['created_at']
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
                    try {
                        $stmt = $pdo->query("SELECT * FROM ardent_ticket.ticket_categories");
                        $categories = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        sendResponse(['status' => 'success', 'data' => $categories]);
                    } catch (PDOException $e) {
                        error_log('Database error in get_categories: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'get_agents':
                    try {
                        $stmt = $pdo->query("SELECT id, name, first_name, email, role FROM ardent_ticket.users WHERE role = 'agent'");
                        $agents = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        sendResponse(['status' => 'success', 'data' => $agents]);
                    } catch (PDOException $e) {
                        error_log('Database error in get_agents: ' . $e->getMessage());
                        handleError('Database error: ' . $e->getMessage());
                    }
                    break;

                case 'get_subscriptions':
                    try {
                        $stmt = $pdo->query("SELECT * FROM ardent_ticket.subscription_header");
                        $subscriptions = $stmt->fetchAll(PDO::FETCH_ASSOC);
                        sendResponse(['status' => 'success', 'data' => $subscriptions]);
                    } catch (PDOException $e) {
                        error_log('Database error in get_subscriptions: ' . $e->getMessage());
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
                        $userCheck->execute([':user_id' => intval($data['user_id'])]);
                        $user = $userCheck->fetch();
                        
                        if (!$user) {
                            error_log('User not found with ID: ' . $data['user_id']);
                            throw new Exception('User not found with ID: ' . $data['user_id']);
                        }

                        error_log('User found, proceeding with ticket creation');

                        // Insert the ticket
                        $stmt = $pdo->prepare("
                            INSERT INTO ardent_ticket.tickets 
                            (user_id, ticket_type, assigned_agent, subscription_id, description, status, subject) 
                            VALUES (:user_id, :ticket_type, :assigned_agent, :subscription_id, :description, 'open', :subject)
                        ");
                        
                        $stmt->execute([
                            ':user_id' => intval($data['user_id']),
                            ':ticket_type' => $data['type'],
                            ':assigned_agent' => intval($data['contact']),
                            ':subscription_id' => $data['subscription'],
                            ':description' => $data['description'],
                            ':subject' => $data['subject'] ?? $data['type'] // Use type as fallback for subject
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

                            foreach ($data['attachments'] as $attachment) {
                                if (isset($attachment['data']) && isset($attachment['name'])) {
                                    $file_data = base64_decode($attachment['data']);
                                    if ($file_data === false) {
                                        throw new Exception('Invalid file data format');
                                    }

                                    $attachment_stmt->execute([
                                        ':ticket_id' => $ticket_id,
                                        ':original_name' => $attachment['name'],
                                        ':file_name' => $attachment['name'],
                                        ':file_type' => $attachment['type'] ?? 'application/octet-stream',
                                        ':file_size' => $attachment['size'] ?? strlen($file_data),
                                        ':file_data' => $file_data,
                                        ':uploaded_by' => intval($data['user_id'])
                                    ]);
                                }
                            }
                        }

                        $pdo->commit();
                        sendResponse([
                            'status' => 'success',
                            'message' => 'Ticket created successfully',
                            'ticket_id' => $ticket_id
                        ]);
                    } catch (Exception $e) {
                        $pdo->rollBack();
                        error_log('Error creating ticket: ' . $e->getMessage());
                        handleError('Error creating ticket: ' . $e->getMessage());
                    }
                    break;

                case 'update_ticket_status':
                    if (!isset($data['ticket_id']) || !isset($data['status'])) {
                        handleError('Missing required fields', 400);
                    }
                    
                    try {
                        $stmt = $pdo->prepare("
                            UPDATE ardent_ticket.tickets 
                            SET status = ? 
                            WHERE id = ?
                        ");
                        $result = $stmt->execute([$data['status'], intval($data['ticket_id'])]);
                        
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
    error_log('General error: ' . $e->getMessage());
    handleError('An unexpected error occurred: ' . $e->getMessage());
}
?> 