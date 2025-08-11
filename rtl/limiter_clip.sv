//============================================================================
// Module: limiter_clip
// Description: Audio limiter and clipping protection for hearing aid output
//              Prevents excessive output levels that could damage hearing
//============================================================================

module limiter_clip (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic [23:0] audio_in,       // Audio input signal
    input  logic [23:0] limit_threshold, // Maximum output threshold
    input  logic [7:0]  ratio,          // Limiting ratio above threshold
    input  logic [15:0] attack_time,    // Fast attack for limiting
    input  logic [15:0] release_time,   // Release time after limiting
    output logic [23:0] audio_out,      // Limited audio output
    output logic        limiting_active  // Limiting status indicator
);

    // Internal signals
    logic [23:0] abs_audio;
    logic [23:0] gain_reduction;
    logic [23:0] target_gain;
    logic [23:0] current_gain;
    logic [31:0] mult_result;
    logic [23:0] limited_audio;
    logic        above_threshold;
    logic [31:0] gain_diff;
    logic [31:0] gain_step;
    
    // Constants
    localparam logic [23:0] UNITY_GAIN = 24'h800000; // 1.0 in signed fixed point
    localparam logic [23:0] MAX_POSITIVE = 24'h7FFFFF;
    localparam logic [23:0] MAX_NEGATIVE = 24'h800000;
    
    // Take absolute value for level detection
    always_comb begin
        abs_audio = audio_in[23] ? (~audio_in + 1'b1) : audio_in;
    end
    
    // Check if signal exceeds limit threshold
    always_comb begin
        above_threshold = (abs_audio > limit_threshold);
    end
    
    // Calculate target gain reduction
    always_comb begin
        if (above_threshold) begin
            // Apply limiting: reduce gain based on how much signal exceeds threshold
            logic [31:0] excess = abs_audio - limit_threshold;
            logic [31:0] limited_excess = excess * ratio; // Apply ratio
            logic [31:0] target_level = limit_threshold + limited_excess[30:7]; // Scale back
            
            // Calculate gain reduction needed
            if (abs_audio > 24'h000100) begin // Avoid division by very small numbers
                target_gain = (target_level * UNITY_GAIN) / abs_audio;
            end else begin
                target_gain = UNITY_GAIN;
            end
            
            // Ensure gain doesn't exceed unity
            if (target_gain > UNITY_GAIN) begin
                target_gain = UNITY_GAIN;
            end
        end else begin
            // Below threshold: unity gain
            target_gain = UNITY_GAIN;
        end
    end
    
    // Smooth gain changes with fast attack, slower release
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_gain <= UNITY_GAIN;
        end else if (enable) begin
            gain_diff = target_gain > current_gain ? 
                       target_gain - current_gain :
                       current_gain - target_gain;
                       
            if (target_gain < current_gain) begin
                // Fast attack for gain reduction (limiting)
                gain_step = gain_diff * attack_time;
                current_gain <= current_gain - gain_step[30:7];
            end else begin
                // Slower release for gain recovery
                gain_step = gain_diff * release_time;
                current_gain <= current_gain + gain_step[30:7];
            end
            
            // Clamp gain to reasonable bounds
            if (current_gain < 24'h000100) begin // Minimum gain
                current_gain <= 24'h000100;
            end else if (current_gain > UNITY_GAIN) begin
                current_gain <= UNITY_GAIN;
            end
        end
    end
    
    // Apply gain to audio signal
    always_comb begin
        mult_result = audio_in * current_gain[15:0]; // Use lower 16 bits as multiplier
        limited_audio = mult_result[31:8]; // Scale down from 32-bit to 24-bit
    end
    
    // Final hard clipping protection
    always_comb begin
        if (limited_audio > MAX_POSITIVE) begin
            audio_out = MAX_POSITIVE;
        end else if (limited_audio < MAX_NEGATIVE) begin
            audio_out = MAX_NEGATIVE;
        end else begin
            audio_out = limited_audio;
        end
    end
    
    // Limiting status
    always_comb begin
        limiting_active = (current_gain < UNITY_GAIN) || above_threshold;
    end
    
    // Optional: Look-ahead limiter for even better protection
    logic [23:0] delay_line [0:7]; // 8-sample delay line
    logic [23:0] delayed_audio;
    logic [2:0]  delay_ptr;
    logic [23:0] peak_ahead;
    
    // Delay line for look-ahead limiting
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                delay_line[i] <= 24'h0;
            end
            delay_ptr <= 3'h0;
        end else if (enable) begin
            delay_line[delay_ptr] <= audio_in;
            delay_ptr <= delay_ptr + 1'b1;
        end
    end
    
    // Output delayed audio
    always_comb begin
        delayed_audio = delay_line[(delay_ptr + 4) & 3'h7]; // 4-sample delay
    end
    
    // Peak detection in look-ahead window
    always_comb begin
        peak_ahead = abs_audio; // Simplified - in practice would check multiple samples ahead
    end
    
endmodule
