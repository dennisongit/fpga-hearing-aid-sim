//============================================================================
// Module: hearing_aid_top
// Description: Top-level hearing aid system integrating all processing blocks
//              Main system controller and signal routing
//============================================================================

module hearing_aid_top (
    input  logic        clk,              // System clock
    input  logic        rst_n,            // Active-low reset
    input  logic        enable,           // System enable
    
    // Audio I/O
    input  logic [23:0] audio_in_l,      // Left channel input
    input  logic [23:0] audio_in_r,      // Right channel input
    output logic [23:0] audio_out_l,     // Left channel output
    output logic [23:0] audio_out_r,     // Right channel output
    
    // Control interface
    input  logic [7:0]  control_addr,    // Control register address
    input  logic [31:0] control_data,    // Control data
    input  logic        control_write,   // Control write enable
    output logic [31:0] status_data,     // Status readback
    
    // Configuration parameters
    input  logic [23:0] limit_threshold, // Output limiter threshold
    input  logic [23:0] gate_threshold,  // Noise gate threshold
    input  logic [15:0] compression_ratio, // WDRC compression ratio
    input  logic [7:0]  band_gains [0:7], // Per-band gain settings
    
    // Status outputs
    output logic        limiting_active,  // Limiter engaged
    output logic        gate_active,      // Noise gate active
    output logic        system_ready      // System ready indicator
);

    // Internal audio signals
    logic [23:0] crossover_bands_l [0:7];
    logic [23:0] crossover_bands_r [0:7];
    logic [23:0] processed_bands_l [0:7];
    logic [23:0] processed_bands_r [0:7];
    logic [23:0] summed_audio_l;
    logic [23:0] summed_audio_r;
    logic [23:0] limited_audio_l;
    logic [23:0] limited_audio_r;
    
    // Control and status signals
    logic [23:0] envelope_l, envelope_r;
    logic        bands_ready;
    logic        processing_enable;
    
    // System control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_enable <= 1'b0;
            system_ready <= 1'b0;
        end else begin
            processing_enable <= enable;
            system_ready <= enable && bands_ready;
        end
    end
    
    // Crossover filter bank for left channel
    crossover_bank u_crossover_l (
        .clk(clk),
        .rst_n(rst_n),
        .enable(processing_enable),
        .audio_in(audio_in_l),
        .band_out_0(crossover_bands_l[0]),
        .band_out_1(crossover_bands_l[1]),
        .band_out_2(crossover_bands_l[2]),
        .band_out_3(crossover_bands_l[3]),
        .band_out_4(crossover_bands_l[4]),
        .band_out_5(crossover_bands_l[5]),
        .band_out_6(crossover_bands_l[6]),
        .band_out_7(crossover_bands_l[7])
    );
    
    // Crossover filter bank for right channel
    crossover_bank u_crossover_r (
        .clk(clk),
        .rst_n(rst_n),
        .enable(processing_enable),
        .audio_in(audio_in_r),
        .band_out_0(crossover_bands_r[0]),
        .band_out_1(crossover_bands_r[1]),
        .band_out_2(crossover_bands_r[2]),
        .band_out_3(crossover_bands_r[3]),
        .band_out_4(crossover_bands_r[4]),
        .band_out_5(crossover_bands_r[5]),
        .band_out_6(crossover_bands_r[6]),
        .band_out_7(crossover_bands_r[7])
    );
    
    // Per-band processing (envelope detection and WDRC)
    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : g_band_processing
            logic [23:0] envelope_band_l, envelope_band_r;
            
            // Envelope detection for left channel
            envelope_detect u_env_l (
                .clk(clk),
                .rst_n(rst_n),
                .enable(processing_enable),
                .audio_in(crossover_bands_l[i]),
                .attack_coeff(16'h1000),  // Fast attack
                .release_coeff(16'h0100), // Slow release
                .envelope_out(envelope_band_l)
            );
            
            // WDRC for left channel
            wdrc_band u_wdrc_l (
                .clk(clk),
                .rst_n(rst_n),
                .enable(processing_enable),
                .audio_in(crossover_bands_l[i]),
                .envelope_in(envelope_band_l),
                .threshold(24'h200000),   // Configurable threshold
                .ratio(8'h80),            // 2:1 compression ratio
                .makeup_gain({8'h0, band_gains[i], 8'h0}),
                .attack_time(8'h10),      // Fast attack
                .release_time(8'h04),     // Slower release
                .audio_out(processed_bands_l[i])
            );
            
            // Similar processing for right channel
            envelope_detect u_env_r (
                .clk(clk),
                .rst_n(rst_n),
                .enable(processing_enable),
                .audio_in(crossover_bands_r[i]),
                .attack_coeff(16'h1000),
                .release_coeff(16'h0100),
                .envelope_out(envelope_band_r)
            );
            
            wdrc_band u_wdrc_r (
                .clk(clk),
                .rst_n(rst_n),
                .enable(processing_enable),
                .audio_in(crossover_bands_r[i]),
                .envelope_in(envelope_band_r),
                .threshold(24'h200000),
                .ratio(8'h80),
                .makeup_gain({8'h0, band_gains[i], 8'h0}),
                .attack_time(8'h10),
                .release_time(8'h04),
                .audio_out(processed_bands_r[i])
            );
        end
    endgenerate
    
    // Sum processed bands
    always_comb begin
        summed_audio_l = processed_bands_l[0] + processed_bands_l[1] + 
                        processed_bands_l[2] + processed_bands_l[3] + 
                        processed_bands_l[4] + processed_bands_l[5] + 
                        processed_bands_l[6] + processed_bands_l[7];
                        
        summed_audio_r = processed_bands_r[0] + processed_bands_r[1] + 
                        processed_bands_r[2] + processed_bands_r[3] + 
                        processed_bands_r[4] + processed_bands_r[5] + 
                        processed_bands_r[6] + processed_bands_r[7];
    end
    
    // Output limiting for left channel
    limiter_clip u_limiter_l (
        .clk(clk),
        .rst_n(rst_n),
        .enable(processing_enable),
        .audio_in(summed_audio_l),
        .limit_threshold(limit_threshold),
        .ratio(8'h20),             // 8:1 limiting ratio
        .attack_time(16'h8000),    // Very fast attack
        .release_time(16'h0200),   // Medium release
        .audio_out(limited_audio_l),
        .limiting_active(limiting_active)
    );
    
    // Output limiting for right channel
    limiter_clip u_limiter_r (
        .clk(clk),
        .rst_n(rst_n),
        .enable(processing_enable),
        .audio_in(summed_audio_r),
        .limit_threshold(limit_threshold),
        .ratio(8'h20),
        .attack_time(16'h8000),
        .release_time(16'h0200),
        .audio_out(limited_audio_r),
        .limiting_active() // Not used for right channel
    );
    
    // Final output assignment
    assign audio_out_l = system_ready ? limited_audio_l : 24'h0;
    assign audio_out_r = system_ready ? limited_audio_r : 24'h0;
    
    // Status monitoring
    assign bands_ready = 1'b1; // Simplified - could monitor individual band status
    
    // Status register
    always_comb begin
        status_data = {
            7'b0, system_ready,        // [31:25] Reserved, [24] System ready
            7'b0, limiting_active,     // [23:17] Reserved, [16] Limiting active
            7'b0, gate_active,         // [15:9]  Reserved, [8]  Gate active
            8'b0                       // [7:0]   Reserved
        };
    end
    
endmodule
