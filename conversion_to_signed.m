% MATLAB code to convert input.txt numbers to Q10.6 fixed-point representation

% Read the input file
fid = fopen('input.txt', 'r');
if fid == -1
    error('Cannot open input.txt');
end
input_data = textscan(fid, '%f');
fclose(fid);
input_data = input_data{1}; % Extract from cell array

% Number of data points
n = length(input_data);

% Define fixed-point parameters
integer_bits = 10;
fractional_bits = 6;
total_bits = integer_bits + fractional_bits;

% Calculate representable range for Q10.6
min_value = -2^(integer_bits-1);                      % -512 for Q10.6
max_value = 2^(integer_bits-1) - 2^(-fractional_bits); % Approx 511.984375 for Q10.6

% Print input range for diagnostics
fprintf('Input data range: %f to %f\n', min(input_data), max(input_data));
fprintf('Q10.6 representable range: %f to %f\n', min_value, max_value);

% Check if any values are outside the representable range
out_of_range = sum(input_data < min_value | input_data > max_value);
if out_of_range > 0
    fprintf('WARNING: %d values are outside the representable range!\n', out_of_range);
    fprintf('Consider scaling your data or using a different fixed-point format.\n');
end

% Clamp values to the representable range
input_data_clamped = max(min(input_data, max_value), min_value);

% Convert to Q10.6 fixed-point representation (multiply by 2^fractional_bits)
fixed_point_values = round(input_data_clamped * 2^fractional_bits);

% Convert to 16-bit signed integers
fixed_point_16bit = int16(fixed_point_values);

% Open file for writing the hex values
fid = fopen('fixed_point_values.txt', 'w');
for i = 1:n
    % Get proper 16‑bit two's‑complement bit pattern
    raw_bits = typecast(fixed_point_16bit(i), 'uint16');
    hex_value = dec2hex(raw_bits, 4);

    % Print diagnostic info to console
    fprintf('Original: %f, Fixed-point: %d, Hex: 16''h%s\n', ...
            input_data(i), fixed_point_16bit(i), hex_value);
    
    % Write to file (ONLY ONCE)
    fprintf(fid, '16''h%s\n', hex_value);
end
fclose(fid);

% Alternative hex conversion method for verification
fid = fopen('fixed_point_values_alt.txt', 'w');
for i = 1:n
    % Convert directly to 16-bit unsigned hex
    raw_bits = typecast(fixed_point_16bit(i), 'uint16');
    hex_value = dec2hex(raw_bits, 4);
    
    fprintf(fid, '16''h%s // %f\n', hex_value, input_data(i));
end
fclose(fid);

% Also create a more detailed testbench input file
fid = fopen('testbench_input.txt', 'w');
fprintf(fid, '// Fixed-point Q10.6 representation of input data\n');
fprintf(fid, '// Original range: %f to %f\n', min(input_data), max(input_data));
fprintf(fid, '// 16-bit signed integers (Q10.6 format)\n\n');

% Generate the in_data assignments for the testbench
for i = 1:32:n
    end_idx = min(i+31, n);
    fprintf(fid, '// Batch %d\n', ceil(i/32));
    
    % For each batch of 32 values
    for j = i:end_idx
        idx = j-i;
        % Get proper hex representation
        raw_bits = typecast(fixed_point_16bit(j), 'uint16');
        hex_value = dec2hex(raw_bits, 4);
        
        fprintf(fid, 'in_data[%d:%d] = 16''h%s;  // %f\n', ...
                (idx*16+15), (idx*16), hex_value, input_data(j));
    end
    
    % If we don't have a full batch of 32, pad with zeros
    if end_idx < i+31
        for j = (end_idx-i+1):31
            fprintf(fid, 'in_data[%d:%d] = 16''h0000;  // Padding\n', ...
                    (j*16+15), (j*16));
        end
    end
    
    fprintf(fid, '\n');
end
fclose(fid);

fprintf('Conversion completed. Files generated: fixed_point_values.txt, fixed_point_values_alt.txt, testbench_input.txt\n');

% Create a verification function to convert back from fixed-point to floating-point
fid = fopen('fixed_to_float.m', 'w');
fprintf(fid, 'function float_value = fixed_to_float(fixed_value)\n');
fprintf(fid, '    %% Convert Q10.6 fixed-point values back to floating-point\n');
fprintf(fid, '    %% Input: 16-bit signed integer in Q10.6 format\n');
fprintf(fid, '    %% Output: Floating-point value\n\n');
fprintf(fid, '    float_value = double(fixed_value) / 2^6;\n');
fprintf(fid, 'end\n');
fclose(fid);

% Create a verification script
fid = fopen('verify_conversion.m', 'w');
fprintf(fid, '%% Script to verify the fixed-point conversion\n\n');
fprintf(fid, '%% Read original data\n');
fprintf(fid, 'fid = fopen(''input.txt'', ''r'');\n');
fprintf(fid, 'original_data = textscan(fid, ''%%f'');\n');
fprintf(fid, 'fclose(fid);\n');
fprintf(fid, 'original_data = original_data{1};\n\n');

fprintf(fid, '%% Convert to fixed-point\n');
fprintf(fid, 'fixed_point = int16(round(original_data * 2^6));\n\n');

fprintf(fid, '%% Generate hex values\n');
fprintf(fid, 'hex_values = cell(length(fixed_point), 1);\n');
fprintf(fid, 'for i = 1:length(fixed_point)\n');
fprintf(fid, '    raw_bits = typecast(fixed_point(i), ''uint16'');\n');
fprintf(fid, '    hex_values{i} = dec2hex(raw_bits, 4);\n');
fprintf(fid, 'end\n\n');

fprintf(fid, '%% Display results\n');
fprintf(fid, 'for i = 1:length(original_data)\n');
fprintf(fid, '    fprintf(''Original: %%f, Fixed-point: %%d, Hex: 16\\''h%%s\\n'', ...\n');
fprintf(fid, '        original_data(i), fixed_point(i), hex_values{i});\n');
fprintf(fid, 'end\n');
fclose(fid);