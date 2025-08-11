# FPGA Hearing Aid Simulator

A comprehensive FPGA-based hearing aid simulation system designed for real-time audio processing and digital signal processing research. This project implements various hearing aid algorithms on FPGA hardware to provide low-latency audio enhancement for hearing-impaired individuals.

## Overview

This project provides a complete hearing aid simulation environment using FPGA technology. The system implements multiple digital signal processing algorithms commonly found in modern hearing aids, including noise reduction, frequency shaping, compression, and feedback cancellation.

### Key Features

- **Real-time Audio Processing**: Low-latency audio input/output processing
- **Configurable Algorithms**: Multiple DSP algorithms for different hearing loss profiles
- **FPGA Implementation**: Optimized for Xilinx and Intel/Altera FPGA families
- **Simulation Environment**: Complete testbench and simulation framework
- **Audio Interface**: Support for various audio codecs and I/O standards
- **Parameter Tuning**: Real-time adjustment of hearing aid parameters

## Repository Structure

```
fpga-hearing-aid-sim/
├── rtl/                    # RTL source files
│   ├── audio_interface/    # Audio I/O modules
│   ├── dsp_core/          # Digital signal processing modules
│   ├── control/           # Control and configuration modules
│   └── top/               # Top-level design files
├── testbench/             # Simulation testbenches
│   ├── unit_tests/        # Individual module tests
│   └── system_tests/      # Full system simulations
├── constraints/           # Timing and pin constraints
│   ├── xilinx/           # Xilinx-specific constraints
│   └── intel/            # Intel/Altera constraints
├── scripts/              # Build and simulation scripts
│   ├── build/            # Synthesis and implementation scripts
│   └── sim/              # Simulation automation scripts
├── docs/                 # Documentation
│   ├── algorithms/       # Algorithm descriptions
│   ├── hardware/         # Hardware specifications
│   └── user_guide/       # User documentation
├── tools/                # Utility tools and software
│   └── parameter_tuning/ # GUI tools for parameter adjustment
└── examples/             # Example designs and configurations
    ├── basic_hearing_aid/ # Simple hearing aid implementation
    └── advanced_features/ # Advanced algorithm examples
```

## Build Instructions

### Prerequisites

- **FPGA Development Tools**:
  - Xilinx Vivado 2022.1 or later (for Xilinx FPGAs)
  - Intel Quartus Prime 21.1 or later (for Intel FPGAs)
- **Simulation Tools**:
  - ModelSim/QuestaSim (recommended)
  - Vivado Simulator (for Xilinx)
  - Xilinx XSIM (alternative)
- **Software Dependencies**:
  - Python 3.8+ (for scripts and tools)
  - MATLAB/Octave (for algorithm verification)
  - Git (for version control)

### Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/dennisongit/fpga-hearing-aid-sim.git
   cd fpga-hearing-aid-sim
   ```

2. **Set Up Environment**
   ```bash
   # For Xilinx Vivado
   source /path/to/vivado/settings64.sh
   
   # For Intel Quartus
   source /path/to/quartus/bin/quartus_sh --64bit
   ```

3. **Run Basic Simulation**
   ```bash
   cd scripts/sim
   ./run_basic_sim.sh
   ```

4. **Build for Target FPGA**
   ```bash
   cd scripts/build
   # For Xilinx
   ./build_xilinx.sh <target_board>
   # For Intel
   ./build_intel.sh <target_board>
   ```

### Detailed Build Process

#### Xilinx FPGA Build

1. **Create Vivado Project**
   ```bash
   cd scripts/build/xilinx
   vivado -mode batch -source create_project.tcl
   ```

2. **Add Source Files**
   ```bash
   vivado -mode batch -source add_sources.tcl
   ```

3. **Synthesize and Implement**
   ```bash
   vivado -mode batch -source build.tcl
   ```

#### Intel FPGA Build

1. **Create Quartus Project**
   ```bash
   cd scripts/build/intel
   quartus_sh -t create_project.tcl
   ```

2. **Compile Design**
   ```bash
   quartus_sh --flow compile fpga_hearing_aid_sim
   ```

## Supported Hardware Platforms

### Xilinx Platforms
- Zynq-7000 SoC (ZedBoard, ZC702, ZC706)
- Zynq UltraScale+ (ZCU102, ZCU104, ZCU106)
- Kintex-7 (KC705, KC724)
- Virtex-7 (VC707, VC709)

### Intel Platforms
- Cyclone V (DE1-SoC, DE0-Nano-SoC)
- Arria 10 (Arria 10 SoC Development Kit)
- Stratix 10 (Stratix 10 SX Development Kit)

## Algorithm Implementation

The simulator implements several key hearing aid algorithms:

- **Multi-band Compression**: Dynamic range compression across frequency bands
- **Noise Reduction**: Spectral subtraction and Wiener filtering
- **Feedback Cancellation**: Adaptive feedback suppression
- **Frequency Shaping**: Configurable frequency response adjustment
- **Directional Processing**: Beamforming for multiple microphones
- **Tinnitus Masking**: White/pink noise generation for tinnitus relief

## Testing and Validation

### Running Testbenches

```bash
# Run all unit tests
cd testbench/unit_tests
./run_all_tests.sh

# Run system-level tests
cd testbench/system_tests
./run_system_tests.sh
```

### Audio Quality Metrics

The system includes automated testing for:
- Signal-to-noise ratio (SNR)
- Total harmonic distortion (THD)
- Latency measurements
- Power consumption analysis

## Configuration and Customization

### Parameter Files

Hearing aid parameters are configured through JSON files:

```json
{
  "compression": {
    "bands": 8,
    "ratios": [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0],
    "thresholds": [40, 45, 50, 55, 60, 65, 70, 75]
  },
  "noise_reduction": {
    "enabled": true,
    "aggressiveness": 0.7
  },
  "feedback_cancellation": {
    "enabled": true,
    "filter_length": 128
  }
}
```

### Real-time Tuning

Use the provided GUI tool for real-time parameter adjustment:

```bash
cd tools/parameter_tuning
python hearing_aid_tuner.py
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-algorithm`)
3. Commit your changes (`git commit -am 'Add new algorithm'`)
4. Push to the branch (`git push origin feature/new-algorithm`)
5. Create a Pull Request

### Development Guidelines

- Follow coding standards defined in `docs/coding_standards.md`
- Include testbenches for new modules
- Update documentation for new features
- Ensure synthesis and timing closure on target platforms

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Research contributions from the digital signal processing community
- FPGA development boards provided by Xilinx and Intel
- Audio processing algorithms based on published research

## Contact

For questions and support:
- Create an issue on GitHub
- Email: [project maintainer email]
- Project Wiki: [link to project wiki]

## Citation

If you use this project in your research, please cite:

```bibtex
@misc{fpga-hearing-aid-sim,
  title={FPGA Hearing Aid Simulator},
  author={dennisongit},
  year={2025},
  url={https://github.com/dennisongit/fpga-hearing-aid-sim}
}
```
