% MATLAB script to test the UDP/TCP server
clc;
clear;

% Server configuration
server_address  = '127.0.0.1'; % Localhost
UDP_localPort   = 51000;
port_M2B        = 51001;             % UDP port for sending data
port_B2M        = 30001;             % TCP port for receiving data
buffer_size     = 512;           % Size of data to send (in bytes)

% Create and configure UDP client
udp_client = udpport("Datagram", "LocalPort", UDP_localPort, 'ByteOrder','big-endian');

% Create and configure TCP client
tcp_client = tcpclient(server_address, port_B2M, "Timeout", 5);

% Generate test data
num_doubles = 28; % Number of doubles to send
data_to_send = rand(1, num_doubles, 'double'); % Random double data
data_bytes = typecast(data_to_send, 'uint8');  % Convert doubles to bytes

try
    % Step 1: Send data via UDP
    fprintf('Sending data to server via UDP...\n');
    write(udp_client, data_bytes, server_address, port_M2B);
    pause(1); % Allow server to process data

    % Step 2: Wait for a response via TCP
    fprintf('Waiting for server response via TCP...\n');
    if tcp_client.NumBytesAvailable > 0
        response_data = read(tcp_client, tcp_client.NumBytesAvailable, "uint8");
        received_values = typecast(response_data, 'double');
        fprintf('Received response from server:\n');
        disp(received_values);
    else
        error('No response received from server.');
    end
    
    % Step 3: Validate response
    fprintf('Validating server response...\n');
    if length(received_values) ~= num_doubles
        error('Server response size does not match expected size.');
    end
    
    % Compare sent and received data if applicable (optional)
    % For simplicity, assume server echoes the data
    if isequal(received_values, data_to_send)
        fprintf('Server response is correct.\n');
    else
        error('Mismatch in server response.');
    end
catch ME
    fprintf('Test failed: %s\n', ME.message);
end

% Cleanup
clear udp_client tcp_client;
fprintf('Test complete.\n');
