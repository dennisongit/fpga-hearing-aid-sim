//------------------------------------------------------------------------------
// File: audio_fixed_pkg.sv
// Description: Audio Fixed-Point Package
//              Defines common fixed-point types and parameters for audio processing
// Author: FPGA Hearing Aid Simulator Project
// Date: 2025
//------------------------------------------------------------------------------

package audio_fixed_pkg;

  // Audio sample parameters
  parameter int AUDIO_WIDTH = 24;        // Audio sample width in bits
  parameter int AUDIO_FRAC_BITS = 23;    // Fractional bits for audio samples
  parameter int COEFF_WIDTH = 18;        // Coefficient width for filters
  parameter int COEFF_FRAC_BITS = 17;    // Fractional bits for coefficients
  parameter int INTERNAL_WIDTH = 48;     // Internal computation width
  parameter int GAIN_WIDTH = 16;         // Gain value width
  parameter int GAIN_FRAC_BITS = 14;     // Fractional bits for gain values
  
  // Audio system parameters
  parameter int SAMPLE_RATE = 48000;     // Sample rate in Hz
  parameter int NUM_BANDS = 8;           // Number of frequency bands
  parameter int BLOCK_SIZE = 64;         // Processing block size
  
  // Audio sample type (signed fixed-point)
  typedef logic signed [AUDIO_WIDTH-1:0] audio_sample_t;
  
  // Filter coefficient type
  typedef logic signed [COEFF_WIDTH-1:0] coeff_t;
  
  // Gain value type
  typedef logic signed [GAIN_WIDTH-1:0] gain_t;
  
  // Internal computation type
  typedef logic signed [INTERNAL_WIDTH-1:0] internal_t;
  
  // Audio sample array for multi-band processing
  typedef audio_sample_t audio_band_array_t[NUM_BANDS-1:0];
  
  // Gain array for multi-band processing
  typedef gain_t gain_array_t[NUM_BANDS-1:0];
  
  // I2S interface parameters
  parameter int I2S_DATA_WIDTH = 24;
  parameter int I2S_FRAME_WIDTH = 64;
  
  // Audio processing constants
  parameter audio_sample_t AUDIO_MAX = (1 << (AUDIO_WIDTH-1)) - 1;
  parameter audio_sample_t AUDIO_MIN = -(1 << (AUDIO_WIDTH-1));
  parameter gain_t GAIN_UNITY = 1 << GAIN_FRAC_BITS;  // Unity gain (1.0)
  parameter gain_t GAIN_MAX = (1 << (GAIN_WIDTH-1)) - 1;
  
  // Filter order constants
  parameter int IIR_ORDER = 2;          // Biquad filter order
  parameter int FIR_ORDER = 64;         // FIR filter order
  
  // Envelope detector parameters
  parameter coeff_t ENV_ATTACK_COEFF = 18'h1999;   // Attack time coefficient
  parameter coeff_t ENV_RELEASE_COEFF = 18'h0066;  // Release time coefficient
  
  // Noise gate parameters
  parameter audio_sample_t NOISE_THRESHOLD = 24'h000800;  // Noise gate threshold
  parameter gain_t NOISE_GATE_RATIO = 16'h0400;           // Noise gate ratio (0.25)
  
  // Limiter parameters
  parameter audio_sample_t LIMITER_THRESHOLD = 24'h600000; // Limiter threshold
  parameter gain_t LIMITER_RATIO = 16'h0CCC;               // Limiter ratio (0.8)
  
  // Function to saturate audio samples
  function automatic audio_sample_t saturate_audio(internal_t value);
    if (value > AUDIO_MAX)
      return AUDIO_MAX;
    else if (value < AUDIO_MIN)
      return AUDIO_MIN;
    else
      return audio_sample_t'(value);
  endfunction
  
  // Function to multiply audio sample by gain
  function automatic audio_sample_t apply_gain(audio_sample_t sample, gain_t gain);
    internal_t result;
    result = internal_t'(sample) * internal_t'(gain);
    result = result >>> GAIN_FRAC_BITS;  // Shift to maintain fixed-point format
    return saturate_audio(result);
  endfunction
  
  // Function to add two audio samples with saturation
  function automatic audio_sample_t add_samples(audio_sample_t a, audio_sample_t b);
    internal_t result;
    result = internal_t'(a) + internal_t'(b);
    return saturate_audio(result);
  endfunction

endpackage : audio_fixed_pkg
