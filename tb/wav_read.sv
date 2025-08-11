//============================================================================
// File: wav_read.sv
// Description: SystemVerilog module for reading PCM16/24 WAV files
//              in simulation environment
// Author: FPGA Hearing Aid Simulator Project
// Date: August 2025
//============================================================================

`timescale 1ns/1ps

module wav_read #(
  parameter SAMPLE_WIDTH = 24,        // Audio sample width (16 or 24 bits)
  parameter MAX_SAMPLES = 480000      // Maximum number of samples to read
) (
  input  logic clk,
  input  logic rst_n,
  input  string filename,             // WAV file to read
  output logic signed [SAMPLE_WIDTH-1:0] samples[0:MAX_SAMPLES-1],
  output logic [31:0] num_samples,    // Number of samples read
  output logic read_complete          // Read operation complete flag
);

  //=========================================================================
  // WAV File Header Structure (44 bytes)
  //=========================================================================
  
  typedef struct packed {
    logic [31:0] chunk_id;        // "RIFF" in ASCII
    logic [31:0] chunk_size;      // File size - 8 bytes
    logic [31:0] format;          // "WAVE" in ASCII
    logic [31:0] subchunk1_id;    // "fmt " in ASCII
    logic [31:0] subchunk1_size;  // 16 for PCM
    logic [15:0] audio_format;    // 1 for PCM
    logic [15:0] num_channels;    // Number of channels
    logic [31:0] sample_rate;     // Sample rate in Hz
    logic [31:0] byte_rate;       // Byte rate
    logic [15:0] block_align;     // Block alignment
    logic [15:0] bits_per_sample; // Bits per sample
    logic [31:0] subchunk2_id;    // "data" in ASCII
    logic [31:0] subchunk2_size;  // Data size in bytes
  } wav_header_t;
  
  //=========================================================================
  // Internal Variables
  //=========================================================================
  
  wav_header_t header;
  integer file_handle;
  integer bytes_read;
  integer sample_index;
  logic [7:0] byte_buffer[0:7]; // Buffer for multi-byte reads
  logic [23:0] sample_24bit;
  logic [15:0] sample_16bit;
  logic file_opened;
  logic header_parsed;
  logic reading_samples;
  
  // File reading state machine
  typedef enum logic [2:0] {
    IDLE,
    OPEN_FILE,
    READ_HEADER,
    PARSE_HEADER,
    READ_SAMPLES,
    COMPLETE,
    ERROR
  } state_t;
  
  state_t current_state, next_state;
  
  //=========================================================================
  // State Machine - Sequential Logic
  //=========================================================================
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end
  
  //=========================================================================
  // State Machine - Combinational Logic
  //=========================================================================
  
  always_comb begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (rst_n && filename != "") begin
          next_state = OPEN_FILE;
        end
      end
      
      OPEN_FILE: begin
        if (file_opened) begin
          next_state = READ_HEADER;
        end else begin
          next_state = ERROR;
        end
      end
      
      READ_HEADER: begin
        if (header_parsed) begin
          next_state = READ_SAMPLES;
        end
      end
      
      READ_SAMPLES: begin
        if (sample_index >= num_samples || sample_index >= MAX_SAMPLES) begin
          next_state = COMPLETE;
        end
      end
      
      COMPLETE: begin
        // Stay in complete state
      end
      
      ERROR: begin
        // Stay in error state
      end
      
      default: next_state = IDLE;
    endcase
  end
  
  //=========================================================================
  // File Operations and Data Processing
  //=========================================================================
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      file_handle <= 0;
      file_opened <= 0;
      header_parsed <= 0;
      reading_samples <= 0;
      sample_index <= 0;
      num_samples <= 0;
      read_complete <= 0;
      
      // Initialize header
      header <= '0;
      
      // Initialize sample array
      for (int i = 0; i < MAX_SAMPLES; i++) begin
        samples[i] <= '0;
      end
      
    end else begin
      
      case (current_state)
        
        IDLE: begin
          file_opened <= 0;
          header_parsed <= 0;
          reading_samples <= 0;
          sample_index <= 0;
          read_complete <= 0;
        end
        
        OPEN_FILE: begin
          // Open WAV file for reading (binary mode)
          file_handle = $fopen(filename, "rb");
          if (file_handle != 0) begin
            file_opened <= 1;
            $display("[%0t] WAV Reader: Opened file %s", $time, filename);
          end else begin
            $error("[%0t] WAV Reader: Failed to open file %s", $time, filename);
            file_opened <= 0;
          end
        end
        
        READ_HEADER: begin
          if (!header_parsed) begin
            // Read WAV header (44 bytes)
            bytes_read = $fread(header, file_handle);
            if (bytes_read == 44) begin
              header_parsed <= 1;
              
              // Parse and validate header
              if (validate_header()) begin
                // Calculate number of samples
                if (header.bits_per_sample == 16) begin
                  num_samples <= header.subchunk2_size / (2 * header.num_channels);
                end else if (header.bits_per_sample == 24) begin
                  num_samples <= header.subchunk2_size / (3 * header.num_channels);
                end else begin
                  $error("[%0t] WAV Reader: Unsupported bit depth: %0d", 
                         $time, header.bits_per_sample);
                end
                
                $display("[%0t] WAV Reader: Header parsed successfully", $time);
                $display("  Sample Rate: %0d Hz", header.sample_rate);
                $display("  Channels: %0d", header.num_channels);
                $display("  Bits per Sample: %0d", header.bits_per_sample);
                $display("  Number of Samples: %0d", num_samples);
                
              end else begin
                $error("[%0t] WAV Reader: Invalid WAV file format", $time);
              end
            end else begin
              $error("[%0t] WAV Reader: Failed to read header", $time);
            end
          end
        end
        
        READ_SAMPLES: begin
          if (sample_index < num_samples && sample_index < MAX_SAMPLES) begin
            
            // Read sample data based on bit depth
            if (header.bits_per_sample == 16) begin
              // Read 16-bit sample
              bytes_read = $fread(byte_buffer[0:1], file_handle);
              if (bytes_read == 2) begin
                sample_16bit = {byte_buffer[1], byte_buffer[0]}; // Little endian
                
                // Convert to target sample width
                if (SAMPLE_WIDTH == 24) begin
                  // Sign extend 16-bit to 24-bit
                  samples[sample_index] <= {{8{sample_16bit[15]}}, sample_16bit};
                end else if (SAMPLE_WIDTH == 16) begin
                  samples[sample_index] <= sample_16bit;
                end
                
                sample_index <= sample_index + 1;
                
                // Skip other channel data if stereo (use only left channel)
                if (header.num_channels > 1) begin
                  $fseek(file_handle, 2 * (header.num_channels - 1), 1); // Skip other channels
                end
              end
            end else if (header.bits_per_sample == 24) begin
              // Read 24-bit sample
              bytes_read = $fread(byte_buffer[0:2], file_handle);
              if (bytes_read == 3) begin
                sample_24bit = {byte_buffer[2], byte_buffer[1], byte_buffer[0]}; // Little endian
                
                // Convert to target sample width
                if (SAMPLE_WIDTH == 24) begin
                  samples[sample_index] <= sample_24bit;
                end else if (SAMPLE_WIDTH == 16) begin
                  // Truncate 24-bit to 16-bit (keep MSBs)
                  samples[sample_index] <= sample_24bit[23:8];
                end
                
                sample_index <= sample_index + 1;
                
                // Skip other channel data if stereo (use only left channel)
                if (header.num_channels > 1) begin
                  $fseek(file_handle, 3 * (header.num_channels - 1), 1); // Skip other channels
                end
              end
            end
            
            // Progress indication
            if (sample_index % 4800 == 0 && sample_index > 0) begin
              $display("[%0t] WAV Reader: Read %0d/%0d samples (%.1f%%)", 
                      $time, sample_index, num_samples,
                      (real'(sample_index) / real'(num_samples)) * 100.0);
            end
          end
        end
        
        COMPLETE: begin
          if (!read_complete) begin
            $fclose(file_handle);
            read_complete <= 1;
            $display("[%0t] WAV Reader: Successfully read %0d samples from %s", 
                    $time, sample_index, filename);
          end
        end
        
        ERROR: begin
          if (file_handle != 0) begin
            $fclose(file_handle);
          end
          $error("[%0t] WAV Reader: Error state reached", $time);
        end
        
      endcase
    end
  end
  
  //=========================================================================
  // Header Validation Function
  //=========================================================================
  
  function automatic logic validate_header();
    logic valid;
    valid = 1;
    
    // Check RIFF signature
    if (header.chunk_id != 32'h46464952) begin // "RIFF" in little endian
      $error("[%0t] WAV Reader: Invalid RIFF signature", $time);
      valid = 0;
    end
    
    // Check WAVE format
    if (header.format != 32'h45564157) begin // "WAVE" in little endian
      $error("[%0t] WAV Reader: Invalid WAVE format", $time);
      valid = 0;
    end
    
    // Check audio format (must be PCM)
    if (header.audio_format != 16'h0001) begin
      $error("[%0t] WAV Reader: Non-PCM format not supported (format: %0d)", 
             $time, header.audio_format);
      valid = 0;
    end
    
    // Check sample rate (should be 48kHz for hearing aid)
    if (header.sample_rate != 48000) begin
      $warning("[%0t] WAV Reader: Sample rate is %0d Hz, expected 48000 Hz", 
               $time, header.sample_rate);
    end
    
    // Check bits per sample
    if (header.bits_per_sample != 16 && header.bits_per_sample != 24) begin
      $error("[%0t] WAV Reader: Unsupported bits per sample: %0d (only 16/24 supported)", 
             $time, header.bits_per_sample);
      valid = 0;
    end
    
    return valid;
  endfunction
  
  //=========================================================================
  // Debug and Utility Functions
  //=========================================================================
  
  // Task to manually trigger file read (useful for testbenches)
  task read_wav_file(input string file_path);
    filename = file_path;
    wait(read_complete);
    $display("[%0t] WAV Reader: File read task completed", $time);
  endtask
  
  // Function to get sample at specific index
  function automatic logic signed [SAMPLE_WIDTH-1:0] get_sample(input integer index);
    if (index >= 0 && index < sample_index) begin
      return samples[index];
    end else begin
      $warning("[%0t] WAV Reader: Sample index %0d out of range (0-%0d)", 
               $time, index, sample_index-1);
      return '0;
    end
  endfunction
  
  // Function to get file information
  function automatic void get_file_info(
    output integer samp_rate,
    output integer channels,
    output integer bit_depth,
    output integer total_samples
  );
    samp_rate = header.sample_rate;
    channels = header.num_channels;
    bit_depth = header.bits_per_sample;
    total_samples = sample_index;
  endfunction
  
endmodule

//============================================================================
// End of wav_read.sv
//============================================================================
