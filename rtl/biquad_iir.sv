//------------------------------------------------------------------------------
// File: biquad_iir.sv
// Description: Biquad IIR Filter Implementation
//              Second-order IIR filter with configurable coefficients
// Author: FPGA Hearing Aid Simulator Project
// Date: 2025
//------------------------------------------------------------------------------

import audio_fixed_pkg::*;

module biquad_iir (
  input  logic                clk,
  input  logic                rst_n,
  input  logic                en,
  
  // Audio data interface
  input  audio_sample_t       data_in,
  input  logic                data_in_valid,
  output audio_sample_t       data_out,
  output logic                data_out_valid,
  
  // Filter coefficients (Direct Form I)
  input  coeff_t              b0,  // Feed-forward coefficient 0
  input  coeff_t              b1,  // Feed-forward coefficient 1
  input  coeff_t              b2,  // Feed-forward coefficient 2
  input  coeff_t              a1,  // Feed-back coefficient 1 (negated)
  input  coeff_t              a2   // Feed-back coefficient 2 (negated)
);

  // Internal signals
  internal_t x_mult_b0, x_mult_b1, x_mult_b2;
  internal_t y_mult_a1, y_mult_a2;
  internal_t sum_ff, sum_fb, sum_total;
  
  // Delay line registers for input (x) samples
  audio_sample_t x_reg [0:2];
  
  // Delay line registers for output (y) samples
  audio_sample_t y_reg [0:2];
  
  // Pipeline registers
  logic data_valid_reg;
  
  // Multipliers for feed-forward path
  always_comb begin
    x_mult_b0 = internal_t'(x_reg[0]) * internal_t'(b0);
    x_mult_b1 = internal_t'(x_reg[1]) * internal_t'(b1);
    x_mult_b2 = internal_t'(x_reg[2]) * internal_t'(b2);
  end
  
  // Multipliers for feed-back path
  always_comb begin
    y_mult_a1 = internal_t'(y_reg[1]) * internal_t'(a1);
    y_mult_a2 = internal_t'(y_reg[2]) * internal_t'(a2);
  end
  
  // Sum feed-forward terms
  always_comb begin
    sum_ff = (x_mult_b0 >>> COEFF_FRAC_BITS) + 
             (x_mult_b1 >>> COEFF_FRAC_BITS) + 
             (x_mult_b2 >>> COEFF_FRAC_BITS);
  end
  
  // Sum feed-back terms
  always_comb begin
    sum_fb = (y_mult_a1 >>> COEFF_FRAC_BITS) + 
             (y_mult_a2 >>> COEFF_FRAC_BITS);
  end
  
  // Total sum (feed-forward - feed-back)
  always_comb begin
    sum_total = sum_ff - sum_fb;
  end
  
  // Update delay lines and compute output
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all delay line registers
      for (int i = 0; i < 3; i++) begin
        x_reg[i] <= '0;
        y_reg[i] <= '0;
      end
      data_valid_reg <= 1'b0;
    end else if (en) begin
      if (data_in_valid) begin
        // Shift input delay line
        x_reg[2] <= x_reg[1];
        x_reg[1] <= x_reg[0];
        x_reg[0] <= data_in;
        
        // Shift output delay line and store new output
        y_reg[2] <= y_reg[1];
        y_reg[1] <= y_reg[0];
        y_reg[0] <= saturate_audio(sum_total);
        
        data_valid_reg <= 1'b1;
      end else begin
        data_valid_reg <= 1'b0;
      end
    end else begin
      data_valid_reg <= 1'b0;
    end
  end
  
  // Output assignment
  assign data_out = y_reg[0];
  assign data_out_valid = data_valid_reg;

  // Synthesis attributes for optimal implementation
  (* KEEP_HIERARCHY = "TRUE" *)
  (* USE_DSP = "YES" *)
  
endmodule : biquad_iir
