//============================================================================
// Module: envelope_detect
// Description: Digital envelope detector for audio signals
//              Used for dynamic range compression and AGC
//============================================================================

module envelope_detect (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [23:0] audio_in,     // Audio input signal
    input  logic [15:0] attack_coeff, // Attack coefficient (0.16 format)
    input  logic [15:0] release_coeff,// Release coefficient (0.16 format)
    output logic [23:0] envelope_out  // Envelope output
);

    // Internal signals
    logic [23:0] abs_audio;
    logic [23:0] envelope_reg;
    logic [39:0] mult_result;
    logic [23:0] filtered_env;
    logic        audio_rising;
    
    // Take absolute value of input
    always_comb begin
        abs_audio = audio_in[23] ? (~audio_in + 1'b1) : audio_in;
    end
    
    // Determine if signal is rising or falling
    always_comb begin
        audio_rising = (abs_audio > envelope_reg);
    end
    
    // Apply attack or release filtering
    always_comb begin
        if (audio_rising) begin
            // Fast attack: use attack coefficient
            mult_result = envelope_reg * attack_coeff;
        end else begin
            // Slow release: use release coefficient
            mult_result = envelope_reg * release_coeff;
        end
        
        // Scale down from 40-bit to 24-bit
        filtered_env = mult_result[39:16];
    end
    
    // Envelope tracking register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            envelope_reg <= 24'h0;
        end else if (enable) begin
            if (audio_rising) begin
                // Quick attack: blend with input
                envelope_reg <= abs_audio - filtered_env + envelope_reg;
            end else begin
                // Slow release: apply filtering
                envelope_reg <= filtered_env;
            end
        end
    end
    
    // Output assignment
    assign envelope_out = envelope_reg;
    
endmodule
