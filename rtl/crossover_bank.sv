//------------------------------------------------------------------------------
// File: crossover_bank.sv
// Description: Multi-band Crossover Filter Bank
//              Splits audio into multiple frequency bands using cascaded filters
// Author: FPGA Hearing Aid Simulator Project
// Date: 2025
//------------------------------------------------------------------------------

import audio_fixed_pkg::*;

module crossover_bank (
  input  logic                clk,
  input  logic                rst_n,
  input  logic                en,
  
  // Audio data interface
  input  audio_sample_t       data_in,
  input  logic                data_in_valid,
  output audio_band_array_t   band_out,
  output logic                data_out_valid,
  
  // Crossover frequency control (coefficients for each crossover point)
  input  coeff_t              crossover_coeffs [NUM_BANDS-1:0][4:0]  // b0,b1,b2,a1,a2 for each band
);

  // Internal signals for filter stages
  audio_sample_t stage_data [NUM_BANDS:0];
  logic stage_valid [NUM_BANDS:0];
  
  // High-pass filter outputs for each stage
  audio_sample_t hp_out [NUM_BANDS-1:0];
  logic hp_valid [NUM_BANDS-1:0];
  
  // Low-pass filter cascade
  audio_sample_t lp_cascade [NUM_BANDS-1:0];
  logic lp_cascade_valid [NUM_BANDS-1:0];

  // Initialize the cascade
  assign stage_data[0] = data_in;
  assign stage_valid[0] = data_in_valid;

  // Generate crossover filters for each frequency band
  genvar i;
  generate
    for (i = 0; i < NUM_BANDS-1; i++) begin : gen_crossover_filters
      
      // Low-pass filter (creates next stage input)
      biquad_iir lp_filter (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .data_in(stage_data[i]),
        .data_in_valid(stage_valid[i]),
        .data_out(lp_cascade[i]),
        .data_out_valid(lp_cascade_valid[i]),
        .b0(crossover_coeffs[i][0]),
        .b1(crossover_coeffs[i][1]),
        .b2(crossover_coeffs[i][2]),
        .a1(crossover_coeffs[i][3]),
        .a2(crossover_coeffs[i][4])
      );
      
      // High-pass filter (creates band output)
      biquad_iir hp_filter (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .data_in(stage_data[i]),
        .data_in_valid(stage_valid[i]),
        .data_out(hp_out[i]),
        .data_out_valid(hp_valid[i]),
        // High-pass coefficients (complement of low-pass)
        .b0(~crossover_coeffs[i][0] + 1'b1),  // Complementary HP coefficients
        .b1(~crossover_coeffs[i][1] + 1'b1),
        .b2(~crossover_coeffs[i][2] + 1'b1),
        .a1(crossover_coeffs[i][3]),
        .a2(crossover_coeffs[i][4])
      );
      
      // Connect cascade
      assign stage_data[i+1] = lp_cascade[i];
      assign stage_valid[i+1] = lp_cascade_valid[i];
    end
  endgenerate

  // Output assignment
  generate
    for (i = 0; i < NUM_BANDS-1; i++) begin : gen_band_outputs
      assign band_out[i] = hp_out[i];
    end
  endgenerate
  
  // Last band is the final low-pass output
  assign band_out[NUM_BANDS-1] = stage_data[NUM_BANDS-1];
  
  // Output valid when all filters have valid output
  logic all_bands_valid;
  always_comb begin
    all_bands_valid = stage_valid[NUM_BANDS-1];
    for (int j = 0; j < NUM_BANDS-1; j++) begin
      all_bands_valid &= hp_valid[j];
    end
  end
  
  assign data_out_valid = all_bands_valid;

  // Synthesis attributes
  (* KEEP_HIERARCHY = "TRUE" *)
  
endmodule : crossover_bank
