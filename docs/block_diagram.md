# FPGA Hearing Aid System - Block Diagram

This document provides an ASCII block diagram of the FPGA hearing aid system architecture.

## System Block Diagram

```
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────────────┐
│  Audio Input    │    │   Multi-band         │    │  Per-band WDRC         │
│                 │    │   Filterbank/        │    │                         │
│ • I2S Interface │───▶│   Crossover          │───▶│ • Band 1: ~250Hz       │
│ • WAV Simulation│    │                      │    │ • Band 2: ~750Hz       │
│                 │    │ • 5-band system      │    │ • Band 3: ~2kHz        │
└─────────────────┘    │ • Linkwitz-Riley     │    │ • Band 4: ~5kHz        │
                       │   cascaded biquads   │    │ • Band 5: >5kHz        │
                       │ • Crossovers:        │    │                         │
                       │   250Hz, 750Hz,      │    │ Wide Dynamic Range     │
                       │   2kHz, 5kHz         │    │ Compression per band   │
                       └──────────────────────┘    └─────────────────────────┘
                                                                   │
                                                                   ▼
┌─────────────────┐    ┌──────────────────────┐    ┌─────────────────────────┐
│  Audio Output   │    │   Output Limiter/    │    │  Noise Gate &           │
│                 │    │   Soft Clipper       │    │  Noise Reduction        │
│ • I2S Interface │◀───│                      │◀───│                         │
│ • WAV Simulation│    │ • Ear safety         │    │ • Background noise      │
│                 │    │ • <10ms latency      │    │   suppression           │
└─────────────────┘    │   target             │    │ • Gating threshold      │
                       └──────────────────────┘    │   adjustable            │
                                                   └─────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            Control Interface                                │
│                                                                             │
│ • Register-based configuration                                              │
│ • "Senior" preset defaults                                                  │
│ • Per-band compression settings (threshold, ratio, attack/release)         │
│ • Noise reduction parameters                                                │
│ • Output limiter settings                                                   │
│ • Real-time parameter adjustment                                            │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Optional Wireless Charging Status Interface                │
│                                                                             │
│ • Digital interface stub for simulation                                     │
│ • Charging status monitoring                                                │
│ • Battery level indication                                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Processing Chain

1. **Audio Input**: 48 kHz audio samples (I2S or WAV simulation)
2. **Filterbank**: 5-band crossover filtering at 250Hz, 750Hz, 2kHz, 5kHz
3. **WDRC**: Per-band compression for age-related hearing loss compensation
4. **Noise Processing**: Background noise reduction and gating
5. **Output Limiting**: Safety limiter with soft clipping
6. **Audio Output**: Processed audio output (I2S or WAV simulation)

## Data Formats

- **Audio Samples**: Q1.23 fixed-point format
- **Coefficients**: Q2.30 fixed-point format  
- **Accumulators**: 48-bit precision in DSP blocks
- **Target Latency**: <10ms end-to-end processing

## Control and Configuration

- Register-based parameter control
- Default "Senior" preset for age-related hearing loss
- Real-time adjustment capability
- Preset management for different environments
