module image_processor(
    input wire clk,
    input wire rst_n,
    input wire [15:0] pixel_in,
    input wire data_valid_in,
    output wire [15:0] pixel_out,
    output wire data_valid_out,
    input wire [2:0] threshold
);

    // Face detection signals
    wire face_detected;
    wire [9:0] face_x, face_y;
    wire [9:0] face_width, face_height;
    wire [15:0] face_pixel_out;

    // Original neural network signals
    wire nn_out;
    wire [15:0] enhanced_pixel;

    // Instantiate face detection module
    face_detection face_detector (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_in(pixel_in),
        .data_valid_in(data_valid_in),
        .pixel_out(face_pixel_out),
        .face_detected(face_detected),
        .face_x(face_x),
        .face_y(face_y),
        .face_width(face_width),
        .face_height(face_height)
    );

    // Instantiate original dense layer for additional processing
    dense_layer neural_net (
        .clk(clk),
        .rst(~rst_n),
        .out(nn_out)
    );

    // Image enhancement processing
    reg [15:0] enhanced_pixel_reg;
    reg process_valid;
    wire [3:0] enhance_factor = {1'b0, threshold};

    // Pixel enhancement logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enhanced_pixel_reg <= 16'h0000;
            process_valid <= 1'b0;
        end else begin
            if (data_valid_in) begin
                // Apply enhancement based on neural network output
                if (nn_out) begin
                    enhanced_pixel_reg <= {
                        // Red component enhancement
                        pixel_in[15:11] + ((5'h1F - pixel_in[15:11]) >> enhance_factor),
                        // Green component enhancement
                        pixel_in[10:5] + ((6'h3F - pixel_in[10:5]) >> enhance_factor),
                        // Blue component enhancement
                        pixel_in[4:0] + ((5'h1F - pixel_in[4:0]) >> enhance_factor)
                    };
                end else begin
                    enhanced_pixel_reg <= pixel_in;
                end
                process_valid <= 1'b1;
            end else begin
                process_valid <= 1'b0;
            end
        end
    end

    // Output multiplexer - choose between face detection and enhanced output
    assign pixel_out = face_detected ? face_pixel_out : enhanced_pixel_reg;
    assign data_valid_out = process_valid;

    // Debug monitor (optional)
    // synthesis translate_off
    always @(posedge clk) begin
        if (face_detected) begin
            $display("Face detected at X:%d Y:%d", face_x, face_y);
        end
    end
    // synthesis translate_on

endmodule