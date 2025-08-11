//============================================================================
// File: tb_hearing_aid_wav.sv
// Description: SystemVerilog testbench for FPGA hearing aid simulation
//              Reads input WAV file, processes through hearing aid pipeline,
//              and writes output WAV file
// Author: FPGA Hearing Aid Simulator Project
// Date: August 2025
//============================================================================

`timescale 1ns/1ps

`include "coeffs_default.svh"

module tb_hearing_aid_wav;

  //=========================================================================
  // Parameters
  //=========================================================================
  
  // Audio specifications
  parameter SAMPLE_RATE = 48000;         // 48 kHz sample rate
  parameter SAMPLE_WIDTH = 24;           // Q1.23 fixed-point format
  parameter COEFF_WIDTH = 32;            // Q2.30 coefficient format
  parameter ACCUM_WIDTH = 48;            // 48-bit accumulator width
  
  // Simulation parameters
  parameter CLK_FREQ = 100_000_000;      // 100 MHz system clock
  parameter CLK_PERIOD = 1_000_000_000 / CLK_FREQ; // Clock period in ns
  parameter SIM_TIMEOUT = 10_000_000;    // 10ms simulation timeout
  
  // File paths
  parameter INPUT_WAV_FILE = "input_speech.wav";
  parameter OUTPUT_WAV_FILE = "output_speech.wav";
  parameter MAX_SAMPLES = 480000;        // Maximum samples (10 seconds at 48kHz)
  
  //=========================================================================
  // Signals
  //=========================================================================
  
  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Audio interface signals
  logic signed [SAMPLE_WIDTH-1:0] audio_in;
  logic signed [SAMPLE_WIDTH-1:0] audio_out;
  logic audio_valid;
  logic audio_ready;
  
  // Sample counter and control
  logic [31:0] sample_count;
  logic [31:0] total_samples;
  logic processing_active;
  logic simulation_complete;
  
  // Audio sample arrays
  logic signed [SAMPLE_WIDTH-1:0] input_samples[0:MAX_SAMPLES-1];
  logic signed [SAMPLE_WIDTH-1:0] output_samples[0:MAX_SAMPLES-1];
  
  //=========================================================================
  // Clock Generation
  //=========================================================================
  
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  //=========================================================================
  // Reset Generation
  //=========================================================================
  
  initial begin
    rst_n = 0;
    #(CLK_PERIOD * 10);
    rst_n = 1;
    $display("[%0t] Reset released", $time);
  end
  
  //=========================================================================
  // WAV File Reader Instance
  //=========================================================================
  
  wav_read #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .MAX_SAMPLES(MAX_SAMPLES)
  ) u_wav_read (
    .clk(clk),
    .rst_n(rst_n),
    .filename(INPUT_WAV_FILE),
    .samples(input_samples),
    .num_samples(total_samples),
    .read_complete(/* not used in this simple version */)
  );
  
  //=========================================================================
  // Hearing Aid Top Module Instance
  //=========================================================================
  
  hearing_aid_top #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .COEFF_WIDTH(COEFF_WIDTH),
    .ACCUM_WIDTH(ACCUM_WIDTH)
  ) u_hearing_aid_top (
    .clk(clk),
    .rst_n(rst_n),
    
    // Audio interface
    .audio_in(audio_in),
    .audio_out(audio_out),
    .audio_valid(audio_valid),
    .audio_ready(audio_ready),
    
    // Configuration (using default coefficients from include file)
    .filter_coeffs_b0(FILTER_COEFFS_B0),
    .filter_coeffs_b1(FILTER_COEFFS_B1),
    .filter_coeffs_b2(FILTER_COEFFS_B2),
    .filter_coeffs_a1(FILTER_COEFFS_A1),
    .filter_coeffs_a2(FILTER_COEFFS_A2),
    
    .compressor_thresholds(COMPRESSOR_THRESHOLDS),
    .compressor_ratios(COMPRESSOR_RATIOS),
    .compressor_attack_coeffs(COMPRESSOR_ATTACK_COEFFS),
    .compressor_release_coeffs(COMPRESSOR_RELEASE_COEFFS),
    .compressor_makeup_gains(COMPRESSOR_MAKEUP_GAINS),
    
    .noise_gate_threshold(NOISE_GATE_THRESHOLD),
    .limiter_threshold(LIMITER_THRESHOLD)
  );
  
  //=========================================================================
  // WAV File Writer Instance
  //=========================================================================
  
  wav_write #(
    .SAMPLE_WIDTH(SAMPLE_WIDTH),
    .SAMPLE_RATE(SAMPLE_RATE)
  ) u_wav_write (
    .clk(clk),
    .rst_n(rst_n),
    .filename(OUTPUT_WAV_FILE),
    .samples(output_samples),
    .num_samples(sample_count),
    .write_enable(simulation_complete)
  );
  
  //=========================================================================
  // Audio Sample Processing Loop
  //=========================================================================
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sample_count <= 0;
      processing_active <= 0;
      simulation_complete <= 0;
      audio_in <= 0;
      audio_valid <= 0;
    end else begin
      // Start processing after reset
      if (!processing_active && rst_n) begin
        processing_active <= 1;
        $display("[%0t] Starting audio processing with %0d samples", $time, total_samples);
      end
      
      // Process samples sequentially
      if (processing_active && !simulation_complete) begin
        if (sample_count < total_samples && audio_ready) begin
          // Feed next sample to hearing aid
          audio_in <= input_samples[sample_count];
          audio_valid <= 1;
          
          // Store output sample
          if (audio_valid) begin
            output_samples[sample_count] <= audio_out;
            sample_count <= sample_count + 1;
            
            // Progress indication
            if (sample_count % 4800 == 0) begin // Every 0.1 seconds
              $display("[%0t] Processed %0d/%0d samples (%.1f%%)", 
                      $time, sample_count, total_samples, 
                      (real'(sample_count) / real'(total_samples)) * 100.0);
            end
          end
        end else if (sample_count >= total_samples) begin
          // Processing complete
          processing_active <= 0;
          simulation_complete <= 1;
          audio_valid <= 0;
          $display("[%0t] Audio processing complete", $time);
        end
      end
    end
  end
  
  //=========================================================================
  // Audio Quality Metrics and Analysis
  //=========================================================================
  
  real snr_db;
  real thd_percent;
  real rms_input, rms_output;
  real peak_input, peak_output;
  
  task calculate_metrics();
    real sum_input_sq, sum_output_sq;
    real sum_noise_sq;
    real peak_in_abs, peak_out_abs;
    integer i;
    
    sum_input_sq = 0.0;
    sum_output_sq = 0.0;
    sum_noise_sq = 0.0;
    peak_input = 0.0;
    peak_output = 0.0;
    
    for (i = 0; i < sample_count; i++) begin
      // RMS calculation
      sum_input_sq += (real'(input_samples[i]) * real'(input_samples[i]));
      sum_output_sq += (real'(output_samples[i]) * real'(output_samples[i]));
      
      // Peak detection
      peak_in_abs = (input_samples[i] < 0) ? -real'(input_samples[i]) : real'(input_samples[i]);
      peak_out_abs = (output_samples[i] < 0) ? -real'(output_samples[i]) : real'(output_samples[i]);
      
      if (peak_in_abs > peak_input) peak_input = peak_in_abs;
      if (peak_out_abs > peak_output) peak_output = peak_out_abs;
      
      // Noise calculation (simple difference)
      sum_noise_sq += ((real'(output_samples[i]) - real'(input_samples[i])) ** 2);
    end
    
    rms_input = $sqrt(sum_input_sq / real'(sample_count));
    rms_output = $sqrt(sum_output_sq / real'(sample_count));
    
    // SNR calculation (simplified)
    snr_db = 20.0 * $log10(rms_output / $sqrt(sum_noise_sq / real'(sample_count)));
    
    // THD calculation (placeholder - would need FFT for accurate calculation)
    thd_percent = (sum_noise_sq / sum_output_sq) * 100.0;
    
    $display("\n======== AUDIO QUALITY METRICS ========");
    $display("Input RMS:  %.6f", rms_input);
    $display("Output RMS: %.6f", rms_output);
    $display("Input Peak: %.6f", peak_input);
    $display("Output Peak: %.6f", peak_output);
    $display("SNR: %.2f dB", snr_db);
    $display("THD: %.3f%%", thd_percent);
    $display("=======================================\n");
  endtask
  
  //=========================================================================
  // Simulation Control and Monitoring
  //=========================================================================
  
  initial begin
    $display("\n================================================");
    $display("FPGA Hearing Aid Simulation Testbench");
    $display("================================================");
    $display("Input file:  %s", INPUT_WAV_FILE);
    $display("Output file: %s", OUTPUT_WAV_FILE);
    $display("Sample rate: %0d Hz", SAMPLE_RATE);
    $display("Sample width: %0d bits (Q1.%0d)", SAMPLE_WIDTH, SAMPLE_WIDTH-1);
    $display("Coefficient width: %0d bits (Q2.%0d)", COEFF_WIDTH, COEFF_WIDTH-2);
    $display("================================================\n");
    
    // Wait for simulation to complete
    wait(simulation_complete);
    
    // Allow a few clock cycles for final processing
    repeat(10) @(posedge clk);
    
    // Calculate and display metrics
    calculate_metrics();
    
    $display("[%0t] Simulation completed successfully!", $time);
    $display("Results written to: %s", OUTPUT_WAV_FILE);
    $display("\n=== SIMULATION INSTRUCTIONS ===");
    $display("1. Place input WAV file '%s' in simulation directory", INPUT_WAV_FILE);
    $display("2. Run simulation: vsim -do 'run -all; quit'");
    $display("3. Check output file '%s' for processed audio", OUTPUT_WAV_FILE);
    $display("4. Compare input/output using audio analysis tools");
    $display("5. Adjust coefficients in coeffs_default.svh as needed");
    $display("===============================\n");
    
    $finish;
  end
  
  // Simulation timeout watchdog
  initial begin
    #SIM_TIMEOUT;
    $error("[%0t] Simulation timeout! Check input file and processing.", $time);
    $finish;
  end
  
  //=========================================================================
  // Debug and Waveform Dumping
  //=========================================================================
  
  `ifdef DUMP_WAVEFORMS
  initial begin
    $dumpfile("hearing_aid_sim.vcd");
    $dumpvars(0, tb_hearing_aid_wav);
    $display("[%0t] Waveform dumping enabled", $time);
  end
  `endif
  
  // Sample data logging for debugging
  `ifdef DEBUG_SAMPLES
  integer debug_file;
  initial begin
    debug_file = $fopen("debug_samples.txt", "w");
    $display("[%0t] Sample debugging enabled", $time);
  end
  
  always @(posedge clk) begin
    if (audio_valid && processing_active) begin
      $fwrite(debug_file, "%0d, %0d, %0d\n", sample_count, audio_in, audio_out);
    end
  end
  `endif
  
endmodule

//============================================================================
// End of tb_hearing_aid_wav.sv
//============================================================================
