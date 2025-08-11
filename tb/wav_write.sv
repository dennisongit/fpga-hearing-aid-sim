//
// SystemVerilog module for writing WAV files in simulation
// Compatible with FPGA hearing aid simulation testbenches
//

`timescale 1ns/1ps

module wav_write #(
    parameter DATA_WIDTH = 16,
    parameter SAMPLE_RATE = 48000,
    parameter MAX_SAMPLES = 1000000,
    parameter FILENAME = "output.wav"
) (
    input logic clk,
    input logic rst_n,
    input logic enable,
    input logic signed [DATA_WIDTH-1:0] audio_data,
    input logic valid,
    output logic ready,
    input logic finish_write
);

    // File handle
    integer file_handle;
    logic file_opened;
    
    // Sample counter
    logic [31:0] sample_count;
    
    // WAV header parameters
    localparam BYTES_PER_SAMPLE = DATA_WIDTH / 8;
    localparam BITS_PER_SAMPLE = DATA_WIDTH;
    
    // Internal signals
    logic [7:0] byte_data;
    logic [1:0] byte_index;
    
    // State machine
    typedef enum logic [2:0] {
        IDLE,
        OPEN_FILE,
        WRITE_HEADER,
        WRITE_DATA,
        UPDATE_HEADER,
        CLOSE_FILE,
        ERROR
    } state_t;
    
    state_t current_state, next_state;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            file_opened <= 1'b0;
            sample_count <= 0;
            byte_index <= 0;
            ready <= 1'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    ready <= 1'b0;
                    if (enable && !file_opened) begin
                        file_handle = $fopen(FILENAME, "wb");
                        if (file_handle != 0) begin
                            file_opened <= 1'b1;
                        end
                    end
                end
                
                WRITE_HEADER: begin
                    // Write WAV header (44 bytes)
                    write_wav_header();
                    ready <= 1'b1;
                end
                
                WRITE_DATA: begin
                    ready <= 1'b1;
                    if (valid && ready) begin
                        // Write audio sample (little-endian)
                        if (BYTES_PER_SAMPLE == 2) begin
                            $fwrite(file_handle, "%c", audio_data[7:0]);   // LSB first
                            $fwrite(file_handle, "%c", audio_data[15:8]);  // MSB second
                        end else if (BYTES_PER_SAMPLE == 4) begin
                            $fwrite(file_handle, "%c", audio_data[7:0]);
                            $fwrite(file_handle, "%c", audio_data[15:8]);
                            $fwrite(file_handle, "%c", audio_data[23:16]);
                            $fwrite(file_handle, "%c", audio_data[31:24]);
                        end
                        sample_count <= sample_count + 1;
                    end
                end
                
                UPDATE_HEADER: begin
                    ready <= 1'b0;
                    // Update header with actual file size
                    update_wav_header();
                end
                
                CLOSE_FILE: begin
                    if (file_opened) begin
                        $fclose(file_handle);
                        file_opened <= 1'b0;
                    end
                    ready <= 1'b0;
                end
                
                ERROR: begin
                    ready <= 1'b0;
                    $display("Error: WAV file write failed");
                end
            endcase
        end
    end
    
    // State machine logic
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (enable && file_opened)
                    next_state = WRITE_HEADER;
                else if (enable && !file_opened)
                    next_state = ERROR;
            end
            
            WRITE_HEADER: begin
                next_state = WRITE_DATA;
            end
            
            WRITE_DATA: begin
                if (finish_write || sample_count >= MAX_SAMPLES)
                    next_state = UPDATE_HEADER;
            end
            
            UPDATE_HEADER: begin
                next_state = CLOSE_FILE;
            end
            
            CLOSE_FILE: begin
                next_state = IDLE;
            end
            
            ERROR: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Task to write WAV header
    task write_wav_header();
        // RIFF header
        $fwrite(file_handle, "RIFF");
        $fwrite(file_handle, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); // File size placeholder
        $fwrite(file_handle, "WAVE");
        
        // fmt chunk
        $fwrite(file_handle, "fmt ");
        $fwrite(file_handle, "%c%c%c%c", 8'h10, 8'h00, 8'h00, 8'h00); // Chunk size = 16
        $fwrite(file_handle, "%c%c", 8'h01, 8'h00);                    // Audio format = PCM
        $fwrite(file_handle, "%c%c", 8'h01, 8'h00);                    // Number of channels = 1
        
        // Sample rate (little-endian)
        $fwrite(file_handle, "%c", SAMPLE_RATE[7:0]);
        $fwrite(file_handle, "%c", SAMPLE_RATE[15:8]);
        $fwrite(file_handle, "%c", SAMPLE_RATE[23:16]);
        $fwrite(file_handle, "%c", SAMPLE_RATE[31:24]);
        
        // Byte rate = sample_rate * channels * bytes_per_sample
        automatic logic [31:0] byte_rate = SAMPLE_RATE * 1 * BYTES_PER_SAMPLE;
        $fwrite(file_handle, "%c", byte_rate[7:0]);
        $fwrite(file_handle, "%c", byte_rate[15:8]);
        $fwrite(file_handle, "%c", byte_rate[23:16]);
        $fwrite(file_handle, "%c", byte_rate[31:24]);
        
        // Block align = channels * bytes_per_sample
        $fwrite(file_handle, "%c%c", BYTES_PER_SAMPLE, 8'h00);
        
        // Bits per sample
        $fwrite(file_handle, "%c%c", BITS_PER_SAMPLE, 8'h00);
        
        // data chunk
        $fwrite(file_handle, "data");
        $fwrite(file_handle, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00); // Data size placeholder
    endtask
    
    // Task to update WAV header with correct file sizes
    task update_wav_header();
        automatic logic [31:0] data_size = sample_count * BYTES_PER_SAMPLE;
        automatic logic [31:0] file_size = data_size + 36; // 44 - 8 bytes
        
        // Seek to file size position (offset 4)
        $fseek(file_handle, 4, 0);
        $fwrite(file_handle, "%c", file_size[7:0]);
        $fwrite(file_handle, "%c", file_size[15:8]);
        $fwrite(file_handle, "%c", file_size[23:16]);
        $fwrite(file_handle, "%c", file_size[31:24]);
        
        // Seek to data size position (offset 40)
        $fseek(file_handle, 40, 0);
        $fwrite(file_handle, "%c", data_size[7:0]);
        $fwrite(file_handle, "%c", data_size[15:8]);
        $fwrite(file_handle, "%c", data_size[23:16]);
        $fwrite(file_handle, "%c", data_size[31:24]);
    endtask
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (valid && ready && current_state == WRITE_DATA) begin
            $display("WAV Write: Sample %0d, Data = %0d", sample_count, $signed(audio_data));
        end
    end
    
    // Final block to ensure file is closed
    final begin
        if (file_opened) begin
            update_wav_header();
            $fclose(file_handle);
            $display("WAV file '%s' written with %0d samples", FILENAME, sample_count);
        end
    end
    
endmodule
