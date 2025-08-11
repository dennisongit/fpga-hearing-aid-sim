# Hearing Aid Presets

This document describes the predefined hearing aid presets available in the FPGA hearing aid system. These presets are optimized for different listening environments and hearing profiles.

## Overview

The system supports multiple preset configurations that can be loaded via the control interface. Each preset defines comprehensive settings for all processing modules including multi-band compression, noise reduction, and output limiting.

## Preset Definitions

### 1. Senior Default

**Target User**: Adults with age-related hearing loss (presbycusis)  
**Environment**: General-purpose preset for everyday use  
**Optimization**: High-frequency emphasis with gentle compression

#### Configuration Details
- **Number of Bands**: 5
- **Crossover Frequencies**: 250 Hz, 750 Hz, 2 kHz, 5 kHz

#### Per-Band Compression Settings

| Band | Frequency Range | Threshold (dBFS) | Ratio | Attack (ms) | Release (ms) | Makeup Gain (dB) |
|------|-----------------|------------------|-------|-------------|--------------|------------------|
| 1    | DC - 250Hz      | -35              | 2.0:1 | 10          | 100          | +2               |
| 2    | 250Hz - 750Hz   | -32              | 2.5:1 | 8           | 80           | +4               |
| 3    | 750Hz - 2kHz    | -28              | 3.0:1 | 5           | 60           | +8               |
| 4    | 2kHz - 5kHz     | -25              | 3.5:1 | 3           | 50           | +12              |
| 5    | 5kHz - Nyquist  | -20              | 3.5:1 | 2           | 40           | +15              |

#### Additional Settings
- **Noise Reduction**: Enabled, moderate aggressiveness (0.6)
- **Noise Gate Threshold**: -50 dBFS
- **Output Limiter**: -3 dBFS hard limit
- **Total Processing Delay**: <8ms

#### Rationale
- Progressive gain increase toward high frequencies compensates for typical age-related hearing loss
- Moderate compression ratios provide natural sound quality
- Fast attack/slow release preserves speech dynamics
- Conservative output limiting ensures user safety

---

### 2. Quiet Room

**Target User**: Any user in low-noise environments  
**Environment**: Libraries, bedrooms, quiet offices  
**Optimization**: Maximum speech clarity with minimal processing

#### Configuration Details
- **Number of Bands**: 5
- **Crossover Frequencies**: 250 Hz, 750 Hz, 2 kHz, 5 kHz

#### Per-Band Compression Settings

| Band | Frequency Range | Threshold (dBFS) | Ratio | Attack (ms) | Release (ms) | Makeup Gain (dB) |
|------|-----------------|------------------|-------|-------------|--------------|------------------|
| 1    | DC - 250Hz      | -45              | 1.5:1 | 15          | 150          | +1               |
| 2    | 250Hz - 750Hz   | -42              | 1.8:1 | 12          | 120          | +2               |
| 3    | 750Hz - 2kHz    | -38              | 2.2:1 | 8           | 100          | +4               |
| 4    | 2kHz - 5kHz     | -35              | 2.5:1 | 6           | 80           | +6               |
| 5    | 5kHz - Nyquist  | -30              | 2.8:1 | 4           | 60           | +8               |

#### Additional Settings
- **Noise Reduction**: Disabled (quiet environment assumption)
- **Noise Gate Threshold**: -60 dBFS (very sensitive)
- **Output Limiter**: -6 dBFS soft limit (conservative)
- **Total Processing Delay**: <6ms

#### Rationale
- Lower compression ratios preserve natural sound quality
- Higher thresholds avoid unnecessary processing of quiet sounds
- Noise reduction disabled to avoid artifacts in quiet environments
- Gentle limiting preserves dynamic range

---

### 3. Noisy Cafe

**Target User**: Any user in challenging acoustic environments  
**Environment**: Restaurants, cafes, busy streets, cocktail parties  
**Optimization**: Aggressive noise suppression with speech enhancement

#### Configuration Details
- **Number of Bands**: 5
- **Crossover Frequencies**: 250 Hz, 750 Hz, 2 kHz, 5 kHz

#### Per-Band Compression Settings

| Band | Frequency Range | Threshold (dBFS) | Ratio | Attack (ms) | Release (ms) | Makeup Gain (dB) |
|------|-----------------|------------------|-------|-------------|--------------|------------------|
| 1    | DC - 250Hz      | -25              | 4.0:1 | 3           | 30           | 0                |
| 2    | 250Hz - 750Hz   | -22              | 4.5:1 | 2           | 25           | +1               |
| 3    | 750Hz - 2kHz    | -18              | 5.0:1 | 1           | 20           | +6               |
| 4    | 2kHz - 5kHz     | -15              | 5.5:1 | 1           | 15           | +10              |
| 5    | 5kHz - Nyquist  | -12              | 6.0:1 | 0.5         | 10           | +8               |

#### Additional Settings
- **Noise Reduction**: Enabled, aggressive (0.9)
- **Noise Gate Threshold**: -35 dBFS (less sensitive to avoid noise)
- **Output Limiter**: 0 dBFS hard limit (maximum output)
- **Total Processing Delay**: <10ms

#### Rationale
- High compression ratios manage wide dynamic range of noisy environments
- Fast attack times handle sudden loud sounds
- Emphasis on speech frequencies (1-4 kHz) improves intelligibility
- Aggressive noise reduction suppresses background chatter
- Higher noise gate threshold prevents low-level noise amplification

---

## Preset Selection Guidelines

### When to Use Senior Default
- First-time hearing aid users
- General daily activities
- Mixed acoustic environments
- When unsure which preset to choose

### When to Use Quiet Room
- Reading or studying
- One-on-one conversations
- Television watching at reasonable volumes
- Sleep/relaxation environments

### When to Use Noisy Cafe
- Restaurants and social gatherings
- Public transportation
- Outdoor environments with traffic
- Any situation where background noise interferes with speech

## Implementation Notes

### Register Programming
Presets are implemented as register lookup tables that can be loaded with a single command:

```verilog
// Pseudo-code for preset loading
preset_select = 2'b00;  // Senior Default
preset_select = 2'b01;  // Quiet Room
preset_select = 2'b10;  // Noisy Cafe
load_preset = 1'b1;     // Trigger preset load
```

### Real-Time Switching
- Presets can be changed during operation without audio dropouts
- Smooth transitions using crossfade techniques
- Parameter changes applied gradually over 50ms to avoid artifacts

### Customization
- Users can modify preset parameters through the control interface
- Modified presets can be saved to non-volatile memory
- Factory reset function restores original preset values

### Memory Requirements
- Each preset requires ~64 bytes of parameter storage
- Total preset memory: <256 bytes
- Suitable for on-chip memory implementation

## Clinical Considerations

### Audiological Basis
- **Senior Default**: Based on typical presbycusis audiograms
- **Quiet Room**: Optimized for minimal processing artifacts
- **Noisy Cafe**: Implements noise reduction strategies from hearing aid research

### Safety Features
- All presets include output limiting to prevent acoustic trauma
- Maximum gain limited to prevent feedback
- Gradual onset prevention for sudden loud sounds

### User Training
- Presets should be introduced progressively
- Start with Senior Default for acclimatization
- Advance to specialized presets based on user needs
- Provide clear labeling and switching instructions

## Future Enhancements

### Adaptive Presets
- Automatic environment detection
- Machine learning for personalized optimization
- User behavior tracking for intelligent preset selection

### Additional Presets (Potential)
- **Music Listening**: Optimized for audio quality
- **Phone Conversation**: Emphasis on speech frequencies
- **Wind Noise**: Special filtering for outdoor use
- **Tinnitus Masking**: Therapeutic sound generation

### Advanced Features
- GPS-based automatic preset switching
- Bluetooth connectivity for smartphone control
- Cloud-based preset sharing and updates
- Professional fitting software integration

## Validation and Testing

Each preset has been validated through:
- Objective measurements (THD+N, frequency response)
- Subjective testing with target user groups
- Acoustic simulation in representative environments
- Long-term wear trials for comfort assessment

The preset parameters represent a balance between acoustic performance, user comfort, and system resource constraints.
