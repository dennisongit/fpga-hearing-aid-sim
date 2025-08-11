# FPGA Hearing Aid System - Design Notes

This document contains technical design details and rationale for the FPGA hearing aid implementation.

## Overview

The FPGA hearing aid system is designed as a simulation-first, vendor-agnostic SystemVerilog RTL implementation optimized for 48 kHz audio processing. The design prioritizes flexibility, maintainability, and accuracy for research and development purposes.

## System Architecture

### Vendor-Agnostic Design
- **Language**: SystemVerilog RTL
- **Approach**: Simulation-first development
- **Target**: Hardware-agnostic design with optional vendor-specific optimizations
- **Testbench**: Comprehensive verification environment with WAV I/O support

### Sample Rate and Timing
- **Audio Sample Rate**: 48 kHz
- **System Clock**: Configurable (typically 48 MHz for simple 1000:1 ratio)
- **Target Latency**: <10ms end-to-end processing pipeline
- **Buffer Depth**: Configurable for latency vs. stability trade-offs

## Fixed-Point Arithmetic

### Data Formats
- **Audio Samples**: Q1.23 format (24-bit)
  - 1 sign bit, 23 fractional bits
  - Range: [-1.0, +1.0) with ~7.15 µV precision
  - Suitable for high-quality audio processing

- **Filter Coefficients**: Q2.30 format (32-bit)
  - 2 integer bits (sign + 1 integer), 30 fractional bits
  - Range: [-2.0, +2.0) with ~0.93 nV precision
  - Accommodates filter coefficients with headroom

- **DSP Accumulators**: 48-bit precision
  - Prevents overflow in multiply-accumulate operations
  - Sufficient headroom for cascaded filtering
  - Rounds down to output format after processing

### Overflow Protection
- Saturation arithmetic on all audio paths
- Configurable overflow detection and reporting
- Safe accumulator sizing for worst-case scenarios

## Multi-Band Filterbank Design

### 5-Band Configuration
The system implements a 5-band crossover network:
1. **Band 1**: DC to ~250 Hz (low frequencies)
2. **Band 2**: ~250 Hz to ~750 Hz (low-mid frequencies)
3. **Band 3**: ~750 Hz to ~2 kHz (mid frequencies)
4. **Band 4**: ~2 kHz to ~5 kHz (high-mid frequencies)
5. **Band 5**: ~5 kHz to Nyquist (high frequencies)

### Filter Implementation
- **Type**: Linkwitz-Riley cascaded biquad filters
- **Order**: 4th order (2 biquads per crossover)
- **Characteristics**: Flat magnitude response when bands recombined
- **Phase**: Linear phase preservation where possible

### Crossover Frequencies
Chosen to align with typical hearing loss patterns:
- **250 Hz**: Separates fundamental speech energy
- **750 Hz**: Critical for vowel intelligibility
- **2 kHz**: Important for consonant clarity
- **5 kHz**: High-frequency hearing loss boundary

## Wide Dynamic Range Compression (WDRC)

### Per-Band Processing
- **Independent Control**: Each frequency band has dedicated compression
- **Threshold**: Configurable per band (-60 to -10 dBFS)
- **Ratio**: 1.5:1 to 10:1 compression ratios
- **Attack Time**: 1-100ms (optimized for speech)
- **Release Time**: 50-1000ms (prevents pumping)

### Age-Related Hearing Loss Compensation
- **Presbycusis Profile**: Higher gain for high frequencies
- **Recruitment Compensation**: Gentle compression for comfort
- **Speech Clarity**: Emphasis on 1-4 kHz range
- **Adaptive Gain**: Real-time adjustment based on input level

### Compressor Architecture
- **Peak/RMS Detection**: Configurable envelope detection
- **Logarithmic Processing**: dB-domain gain calculation
- **Smooth Gain Changes**: Anti-aliasing in gain control
- **Makeup Gain**: Per-band output level adjustment

## Noise Reduction and Gating

### Background Noise Suppression
- **Spectral Subtraction**: Classic noise reduction algorithm
- **Adaptive Threshold**: Automatic noise floor estimation
- **Musical Noise**: Reduction techniques for artifacts
- **Aggressiveness**: User-configurable processing strength

### Noise Gate
- **Threshold**: Configurable gating level (-80 to -20 dBFS)
- **Hold Time**: Prevents chattering on low-level signals
- **Release Slope**: Gradual gate closing to avoid artifacts
- **Frequency-Selective**: Per-band gating capability

## Output Limiting and Safety

### Ear Safety Features
- **Hard Limiter**: Absolute maximum output level protection
- **Soft Clipper**: Gentle peak reduction to prevent distortion
- **RMS Limiting**: Average level control for long-term safety
- **Emergency Shutdown**: Fault detection and safe mode

### Output Characteristics
- **Maximum SPL**: Configurable based on hearing aid specifications
- **THD Targets**: <1% THD for normal listening levels
- **Frequency Response**: Flat response with user EQ adjustments
- **Latency Budget**: Limiter contributes <1ms to total latency

## Control Interface

### Register Map
- **Base Address**: Memory-mapped register access
- **Real-Time Updates**: Parameter changes during operation
- **Preset Storage**: Multiple configuration profiles
- **Status Reporting**: System health and performance metrics

### Default Presets
- **Senior Default**: Optimized for age-related hearing loss
- **Quiet Room**: Settings for low-noise environments
- **Noisy Cafe**: Aggressive noise reduction for challenging acoustics

## Testing and Validation

### Testbench Architecture
- **WAV File I/O**: Read input files, write processed output
- **Python Integration**: THD+N analysis and statistics generation
- **Automated Regression**: Continuous integration testing
- **Golden Reference**: Bit-exact output verification

### Performance Metrics
- **THD+N Measurement**: Automated distortion analysis
- **Frequency Response**: Swept sine wave testing
- **Latency Measurement**: Input-to-output delay characterization
- **Power Estimation**: Resource utilization reporting

### Hardware Verification
- **FPGA Targets**: Xilinx and Intel development boards
- **Real-Time Testing**: Live audio processing verification
- **Resource Usage**: LUT, DSP, and memory utilization
- **Timing Closure**: Meeting clock constraints across vendors

## Implementation Strategy

### Development Flow
1. **SystemVerilog RTL**: Vendor-neutral implementation
2. **Simulation Testing**: Comprehensive verification first
3. **Hardware Mapping**: Optional vendor-specific optimization
4. **Integration Testing**: Full system validation

### Build System
- **Hardware-Agnostic Scripts**: Common build infrastructure
- **Vivado Support**: Xilinx FPGA project generation (optional)
- **Quartus Support**: Intel FPGA project generation (optional)
- **Simulation Priority**: Design verified in simulation first

## Future Enhancements

### Wireless Charging Interface
- **Digital Interface Stub**: Simulation framework ready
- **Status Monitoring**: Battery level and charging state
- **Power Management**: Dynamic performance scaling
- **Communication Protocol**: Standard interface for external control

### Advanced Features (Potential)
- **Machine Learning**: Adaptive noise reduction algorithms
- **Directional Processing**: Multi-microphone beamforming
- **Tinnitus Masking**: Therapeutic sound generation
- **Remote Tuning**: Wireless parameter adjustment

## Design Philosophy

This implementation prioritizes:
1. **Accuracy**: Bit-exact, reproducible results
2. **Flexibility**: Easy parameter adjustment and experimentation
3. **Maintainability**: Clear, well-documented code structure
4. **Portability**: Vendor-agnostic design with optional optimizations
5. **Research-Friendly**: Comprehensive analysis and measurement tools

The goal is to provide a solid foundation for hearing aid research while maintaining the quality and performance standards required for real-world applications.
