//============================================================================
// Module: noise_gate
// Description: Noise gate for audio signals to reduce background noise
//              Gates audio below threshold to improve signal-to-noise ratio
//============================================================================

module noise_gate (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [23:0] audio_in,       // Audio input signal
    input  logic [23:0] threshold,      // Gate threshold level
    input  logic [15:0] attack_time,    // Gate opening time (fast)
    input  logic [15:0] release_time,   // Gate closing time (slow)
    input  logic [7:0]  ratio,         // Reduction ratio below threshold
    output logic [23:0] audio_out,      // Gated audio output
    output logic        gate_active     // Gate status indicator
);

    // Internal signals
    logic [23:0] abs_audio;
    logic [23:0] envelope;
    logic [23:0] smoothed_envelope;
    logic [23:0] gate_gain;
    logic [31:0] mult_result;
    logic        above_threshold;
    logic [31:0] envelope_diff;
    logic [31:0] envelope_step;
    
    // Take absolute value of input for level detection
    always_comb begin
        abs_audio = audio_in[23] ? (~audio_in + 1'b1) : audio_in;
    end
    
    // Simple envelope follower (peak detector with decay)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            envelope <= 24'h0;
        end else if (enable) begin
            if (abs_audio > envelope) begin
                // Fast attack for rising signals
                envelope <= abs_audio;
            end else begin
                // Slow decay for falling signals
                envelope <= envelope - (envelope >> 8); // Divide by 256
            end
        end
    end
    
    // Threshold comparison
    always_comb begin
        above_threshold = (envelope > threshold);
    end
    
    // Smooth gate control with attack/release
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            smoothed_envelope <= 24'h0;
        end else if (enable) begin
            envelope_diff = envelope > smoothed_envelope ? 
                           envelope - smoothed_envelope :
                           smoothed_envelope - envelope;
                           
            if (above_threshold) begin
                // Fast attack: open gate quickly
                if (envelope > smoothed_envelope) begin
                    envelope_step = envelope_diff * attack_time;
                    smoothed_envelope <= smoothed_envelope + envelope_step[30:7];
                end else begin
                    smoothed_envelope <= envelope;
                end
            end else begin
                // Slow release: close gate slowly
                envelope_step = envelope_diff * release_time;
                if (envelope < smoothed_envelope) begin
                    smoothed_envelope <= smoothed_envelope - envelope_step[30:7];
                end else begin
                    smoothed_envelope <= envelope;
                end
            end
        end
    end
    
    // Calculate gate gain
    always_comb begin
        if (above_threshold) begin
            // Above threshold: unity gain
            gate_gain = 24'h800000; // 1.0 in signed fixed point
        end else begin
            // Below threshold: apply reduction ratio
            // Simplified ratio calculation
            gate_gain = {8'h0, ratio, 8'h0}; // Convert ratio to 24-bit
        end
    end
    
    // Apply gating to audio signal
    always_comb begin
        mult_result = audio_in * gate_gain[15:0]; // Use lower 16 bits as multiplier
        audio_out = mult_result[31:8]; // Scale result
    end
    
    // Gate status output
    always_comb begin
        gate_active = above_threshold;
    end
    
    // Optional: Add hysteresis to prevent gate chattering
    logic [23:0] threshold_high;
    logic [23:0] threshold_low;
    logic        gate_state;
    
    always_comb begin
        threshold_high = threshold + (threshold >> 4); // +6.25% hysteresis
        threshold_low = threshold - (threshold >> 4);  // -6.25% hysteresis
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gate_state <= 1'b0;
        end else if (enable) begin
            case (gate_state)
                1'b0: begin // Gate closed
                    if (envelope > threshold_high) begin
                        gate_state <= 1'b1;
                    end
                end
                1'b1: begin // Gate open
                    if (envelope < threshold_low) begin
                        gate_state <= 1'b0;
                    end
                end
            endcase
        end
    end
    
endmodule
