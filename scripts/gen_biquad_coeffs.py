#!/usr/bin/env python3
"""
Biquad Coefficient Generator for FPGA Hearing Aid Simulator

This script generates biquad filter coefficients for digital audio filtering.
Supports various filter types including low-pass, high-pass, band-pass,
band-stop, and parametric EQ filters.

Usage:
    python gen_biquad_coeffs.py [options]
    
Options:
    --filter-type    Type of filter (lowpass, highpass, bandpass, bandstop, peaking)
    --freq          Filter frequency in Hz
    --sample-rate   Sample rate in Hz (default: 48000)
    --q             Quality factor (default: 0.707)
    --gain          Gain in dB for peaking filters (default: 0)
    --output        Output format (verilog, c, matlab, json)
    --file          Output file name

Author: FPGA Hearing Aid Simulator Project
License: MIT
"""

import argparse
import math
import json
import sys
from typing import Tuple, Dict, Any

class BiquadCoeffGenerator:
    """Generator for biquad filter coefficients"""
    
    def __init__(self, sample_rate: float = 48000):
        self.sample_rate = sample_rate
    
    def lowpass(self, freq: float, q: float = 0.707) -> Tuple[float, ...]:
        """Generate low-pass filter coefficients"""
        omega = 2.0 * math.pi * freq / self.sample_rate
        sin_omega = math.sin(omega)
        cos_omega = math.cos(omega)
        alpha = sin_omega / (2.0 * q)
        
        b0 = (1.0 - cos_omega) / 2.0
        b1 = 1.0 - cos_omega
        b2 = (1.0 - cos_omega) / 2.0
        a0 = 1.0 + alpha
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha
        
        return self._normalize(b0, b1, b2, a0, a1, a2)
    
    def highpass(self, freq: float, q: float = 0.707) -> Tuple[float, ...]:
        """Generate high-pass filter coefficients"""
        omega = 2.0 * math.pi * freq / self.sample_rate
        sin_omega = math.sin(omega)
        cos_omega = math.cos(omega)
        alpha = sin_omega / (2.0 * q)
        
        b0 = (1.0 + cos_omega) / 2.0
        b1 = -(1.0 + cos_omega)
        b2 = (1.0 + cos_omega) / 2.0
        a0 = 1.0 + alpha
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha
        
        return self._normalize(b0, b1, b2, a0, a1, a2)
    
    def bandpass(self, freq: float, q: float = 1.0) -> Tuple[float, ...]:
        """Generate band-pass filter coefficients"""
        omega = 2.0 * math.pi * freq / self.sample_rate
        sin_omega = math.sin(omega)
        cos_omega = math.cos(omega)
        alpha = sin_omega / (2.0 * q)
        
        b0 = sin_omega / 2.0
        b1 = 0.0
        b2 = -sin_omega / 2.0
        a0 = 1.0 + alpha
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha
        
        return self._normalize(b0, b1, b2, a0, a1, a2)
    
    def bandstop(self, freq: float, q: float = 1.0) -> Tuple[float, ...]:
        """Generate band-stop (notch) filter coefficients"""
        omega = 2.0 * math.pi * freq / self.sample_rate
        sin_omega = math.sin(omega)
        cos_omega = math.cos(omega)
        alpha = sin_omega / (2.0 * q)
        
        b0 = 1.0
        b1 = -2.0 * cos_omega
        b2 = 1.0
        a0 = 1.0 + alpha
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha
        
        return self._normalize(b0, b1, b2, a0, a1, a2)
    
    def peaking(self, freq: float, q: float = 1.0, gain_db: float = 0.0) -> Tuple[float, ...]:
        """Generate peaking EQ filter coefficients"""
        omega = 2.0 * math.pi * freq / self.sample_rate
        sin_omega = math.sin(omega)
        cos_omega = math.cos(omega)
        A = 10.0 ** (gain_db / 40.0)
        alpha = sin_omega / (2.0 * q)
        
        b0 = 1.0 + alpha * A
        b1 = -2.0 * cos_omega
        b2 = 1.0 - alpha * A
        a0 = 1.0 + alpha / A
        a1 = -2.0 * cos_omega
        a2 = 1.0 - alpha / A
        
        return self._normalize(b0, b1, b2, a0, a1, a2)
    
    def _normalize(self, b0: float, b1: float, b2: float, 
                   a0: float, a1: float, a2: float) -> Tuple[float, ...]:
        """Normalize coefficients by a0"""
        return (b0/a0, b1/a0, b2/a0, a1/a0, a2/a0)

class CoeffFormatter:
    """Format coefficients for different output formats"""
    
    @staticmethod
    def to_verilog(coeffs: Tuple[float, ...], width: int = 18, frac_bits: int = 16) -> str:
        """Format coefficients as Verilog parameters"""
        b0, b1, b2, a1, a2 = coeffs
        scale = 2 ** frac_bits
        
        def to_fixed(val: float) -> int:
            return int(val * scale) & ((1 << width) - 1)
        
        return f"""// Biquad Filter Coefficients (Q{frac_bits}.{width-frac_bits-1})
parameter B0 = {width}'h{to_fixed(b0):0{width//4}X}; // {b0:8.6f}
parameter B1 = {width}'h{to_fixed(b1):0{width//4}X}; // {b1:8.6f}
parameter B2 = {width}'h{to_fixed(b2):0{width//4}X}; // {b2:8.6f}
parameter A1 = {width}'h{to_fixed(a1):0{width//4}X}; // {a1:8.6f}
parameter A2 = {width}'h{to_fixed(a2):0{width//4}X}; // {a2:8.6f}"""
    
    @staticmethod
    def to_c(coeffs: Tuple[float, ...]) -> str:
        """Format coefficients as C arrays"""
        b0, b1, b2, a1, a2 = coeffs
        return f"""// Biquad Filter Coefficients
const float b_coeffs[3] = {{{b0:12.9f}, {b1:12.9f}, {b2:12.9f}}};
const float a_coeffs[2] = {{{a1:12.9f}, {a2:12.9f}}};"""
    
    @staticmethod
    def to_matlab(coeffs: Tuple[float, ...]) -> str:
        """Format coefficients as MATLAB arrays"""
        b0, b1, b2, a1, a2 = coeffs
        return f"""% Biquad Filter Coefficients
b = [{b0:12.9f}, {b1:12.9f}, {b2:12.9f}];
a = [1.0, {a1:12.9f}, {a2:12.9f}];"""
    
    @staticmethod
    def to_json(coeffs: Tuple[float, ...], metadata: Dict[str, Any] = None) -> str:
        """Format coefficients as JSON"""
        b0, b1, b2, a1, a2 = coeffs
        data = {
            "coefficients": {
                "b": [b0, b1, b2],
                "a": [1.0, a1, a2]
            }
        }
        if metadata:
            data["metadata"] = metadata
        return json.dumps(data, indent=2)

def main():
    parser = argparse.ArgumentParser(
        description="Generate biquad filter coefficients for FPGA implementation"
    )
    parser.add_argument("--filter-type", 
                       choices=["lowpass", "highpass", "bandpass", "bandstop", "peaking"],
                       default="lowpass", help="Filter type")
    parser.add_argument("--freq", type=float, required=True, 
                       help="Filter frequency in Hz")
    parser.add_argument("--sample-rate", type=float, default=48000,
                       help="Sample rate in Hz")
    parser.add_argument("--q", type=float, default=0.707,
                       help="Quality factor")
    parser.add_argument("--gain", type=float, default=0.0,
                       help="Gain in dB (for peaking filters)")
    parser.add_argument("--output", 
                       choices=["verilog", "c", "matlab", "json"],
                       default="verilog", help="Output format")
    parser.add_argument("--file", type=str, help="Output file name")
    parser.add_argument("--width", type=int, default=18,
                       help="Coefficient width in bits (for Verilog)")
    parser.add_argument("--frac-bits", type=int, default=16,
                       help="Fractional bits (for Verilog)")
    
    args = parser.parse_args()
    
    # Validate arguments
    if args.freq <= 0 or args.freq >= args.sample_rate / 2:
        print(f"Error: Frequency must be between 0 and {args.sample_rate/2} Hz", file=sys.stderr)
        sys.exit(1)
    
    if args.q <= 0:
        print("Error: Q factor must be positive", file=sys.stderr)
        sys.exit(1)
    
    # Generate coefficients
    gen = BiquadCoeffGenerator(args.sample_rate)
    
    if args.filter_type == "lowpass":
        coeffs = gen.lowpass(args.freq, args.q)
    elif args.filter_type == "highpass":
        coeffs = gen.highpass(args.freq, args.q)
    elif args.filter_type == "bandpass":
        coeffs = gen.bandpass(args.freq, args.q)
    elif args.filter_type == "bandstop":
        coeffs = gen.bandstop(args.freq, args.q)
    elif args.filter_type == "peaking":
        coeffs = gen.peaking(args.freq, args.q, args.gain)
    
    # Create metadata
    metadata = {
        "filter_type": args.filter_type,
        "frequency": args.freq,
        "sample_rate": args.sample_rate,
        "q_factor": args.q,
        "gain_db": args.gain if args.filter_type == "peaking" else None
    }
    
    # Format output
    formatter = CoeffFormatter()
    if args.output == "verilog":
        output = formatter.to_verilog(coeffs, args.width, args.frac_bits)
    elif args.output == "c":
        output = formatter.to_c(coeffs)
    elif args.output == "matlab":
        output = formatter.to_matlab(coeffs)
    elif args.output == "json":
        output = formatter.to_json(coeffs, metadata)
    
    # Write output
    if args.file:
        with open(args.file, 'w') as f:
            f.write(output)
        print(f"Coefficients written to {args.file}")
    else:
        print(output)

if __name__ == "__main__":
    main()
