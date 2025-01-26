module face_detection (
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output reg [15:0] pixel_out,
    output reg face_detected,
    output reg [9:0] face_x,
    output reg [9:0] face_y,
    output reg [9:0] face_width,
    output reg [9:0] face_height
);

    // Parameters
    parameter IMG_WIDTH = 640;
    parameter IMG_HEIGHT = 480;
    parameter FACE_MIN_SIZE = 60;
    
    // Line buffers
    reg [15:0] line_buffer [0:IMG_WIDTH-1];
    reg [23:0] integral_line [0:IMG_WIDTH-1];
    
    // Position tracking
    reg [9:0] pixel_x;
    reg [9:0] pixel_y;
    reg processing_active;
    
    // Face detection thresholds
    parameter INTENSITY_THRESHOLD = 24'h1000;
    parameter EDGE_THRESHOLD = 24'h0800;
    
    // Detection state
    reg [1:0] state;
    localparam IDLE = 0,
               DETECT = 1,
               DRAW = 2;
    
    // Feature accumulation
    reg [23:0] region_sum;
    reg [23:0] edge_strength;

    // RGB565 to grayscale conversion
    function [7:0] rgb565_to_gray;
        input [15:0] rgb;
        reg [7:0] r, g, b;
        begin
            r = {rgb[15:11], 3'b000};
            g = {rgb[10:5], 2'b00};
            b = {rgb[4:0], 3'b000};
            rgb565_to_gray = (r >> 2) + (g >> 1) + (b >> 2);
        end
    endfunction

    // Main processing block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_x <= 0;
            pixel_y <= 0;
            processing_active <= 0;
            face_detected <= 0;
            state <= IDLE;
            region_sum <= 0;
            edge_strength <= 0;
        end
        else if (data_valid_in) begin
            // Update position counters
            if (pixel_x == IMG_WIDTH-1) begin
                pixel_x <= 0;
                if (pixel_y == IMG_HEIGHT-1)
                    pixel_y <= 0;
                else
                    pixel_y <= pixel_y + 1;
            end
            else begin
                pixel_x <= pixel_x + 1;
            end
            
            // Store in line buffer
            line_buffer[pixel_x] <= rgb565_to_gray(pixel_in);
            
            // Calculate integral value
            if (pixel_x == 0)
                integral_line[0] <= rgb565_to_gray(pixel_in);
            else
                integral_line[pixel_x] <= integral_line[pixel_x-1] + rgb565_to_gray(pixel_in);

            case (state)
                IDLE: begin
                    if (pixel_x >= FACE_MIN_SIZE && pixel_y >= FACE_MIN_SIZE) begin
                        state <= DETECT;
                        region_sum <= 0;
                        edge_strength <= 0;
                    end
                end

                DETECT: begin
                    // Calculate region properties
                    region_sum <= calculate_region_sum(pixel_x, pixel_y);
                    edge_strength <= calculate_edge_strength(pixel_x, pixel_y);
                    
                    // Face detection logic
                    if (region_sum > INTENSITY_THRESHOLD && edge_strength > EDGE_THRESHOLD) begin
                        face_detected <= 1;
                        face_x <= pixel_x - FACE_MIN_SIZE/2;
                        face_y <= pixel_y - FACE_MIN_SIZE/2;
                        face_width <= FACE_MIN_SIZE;
                        face_height <= FACE_MIN_SIZE;
                        state <= DRAW;
                    end
                    else begin
                        face_detected <= 0;
                    end
                end

                DRAW: begin
                    // Reset after drawing face rectangle
                    if (pixel_x == IMG_WIDTH-1 && pixel_y == IMG_HEIGHT-1)
                        state <= IDLE;
                end
            endcase
        end
    end

    // Output pixel processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 0;
        end
        else if (data_valid_in) begin
            if (face_detected && 
                pixel_x >= face_x && pixel_x <= face_x + face_width &&
                pixel_y >= face_y && pixel_y <= face_y + face_height) begin
                // Draw face rectangle
                if (pixel_x == face_x || pixel_x == face_x + face_width ||
                    pixel_y == face_y || pixel_y == face_y + face_height)
                    pixel_out <= 16'hF800;  // Red rectangle
                else
                    pixel_out <= pixel_in;
            end
            else begin
                pixel_out <= pixel_in;
            end
        end
    end

    // Region sum calculation
    function [23:0] calculate_region_sum;
        input [9:0] x, y;
        reg [23:0] sum;
        begin
            sum = 0;
            // Calculate sum of 5x5 region
            if (x >= 5 && y >= 5)
                sum = integral_line[x] - integral_line[x-5];
            calculate_region_sum = sum;
        end
    endfunction

    // Edge strength calculation
    function [23:0] calculate_edge_strength;
        input [9:0] x, y;
        reg [23:0] diff;
        begin
            diff = 0;
            // Calculate horizontal edge strength
            if (x >= 2)
                diff = abs_diff(integral_line[x], integral_line[x-2]);
            calculate_edge_strength = diff;
        end
    endfunction

    // Absolute difference helper
    function [23:0] abs_diff;
        input [23:0] a, b;
        begin
            abs_diff = (a > b) ? (a - b) : (b - a);
        end
    endfunction

endmodule