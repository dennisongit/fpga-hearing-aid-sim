#!/usr/bin/env python3
"""
WAV File Analyzer for FPGA Hearing Aid Simulation

This script analyzes WAV audio files to extract key parameters for
FPGA hearing aid algorithm development and testing.

Author: FPGA Hearing Aid Simulator Project
Date: August 2025
"""

import argparse
import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
from scipy.io import wavfile
from scipy.fft import fft, fftfreq
import sys
import os

class WavAnalyzer:
    """Analyze WAV files for hearing aid simulation parameters."""
    
    def __init__(self, wav_file):
        """Initialize analyzer with WAV file."""
        self.wav_file = wav_file
        self.sample_rate = None
        self.audio_data = None
        self.duration = None
        self.load_wav()
    
    def load_wav(self):
        """Load WAV file and extract basic parameters."""
        try:
            self.sample_rate, self.audio_data = wavfile.read(self.wav_file)
            
            # Convert to mono if stereo
            if len(self.audio_data.shape) > 1:
                self.audio_data = np.mean(self.audio_data, axis=1)
            
            # Normalize to [-1, 1] range
            if self.audio_data.dtype == np.int16:
                self.audio_data = self.audio_data.astype(np.float32) / 32768.0
            elif self.audio_data.dtype == np.int32:
                self.audio_data = self.audio_data.astype(np.float32) / 2147483648.0
            
            self.duration = len(self.audio_data) / self.sample_rate
            print(f"Loaded {self.wav_file}: {self.sample_rate}Hz, {self.duration:.2f}s")
            
        except Exception as e:
            print(f"Error loading WAV file: {e}")
            sys.exit(1)
    
    def analyze_spectrum(self, plot=False):
        """Analyze frequency spectrum of the audio."""
        # Compute FFT
        n_fft = 2**int(np.log2(len(self.audio_data))) + 1
        fft_data = fft(self.audio_data, n_fft)
        freqs = fftfreq(n_fft, 1/self.sample_rate)
        
        # Only positive frequencies
        pos_mask = freqs >= 0
        freqs = freqs[pos_mask]
        magnitude = np.abs(fft_data[pos_mask])
        magnitude_db = 20 * np.log10(magnitude + 1e-12)
        
        # Find dominant frequencies
        peaks, _ = signal.find_peaks(magnitude_db, height=-60, distance=50)
        dominant_freqs = freqs[peaks]
        dominant_powers = magnitude_db[peaks]
        
        if plot:
            plt.figure(figsize=(12, 8))
            
            # Time domain plot
            plt.subplot(2, 1, 1)
            time = np.linspace(0, self.duration, len(self.audio_data))
            plt.plot(time, self.audio_data)
            plt.title('Time Domain Signal')
            plt.xlabel('Time (s)')
            plt.ylabel('Amplitude')
            plt.grid(True)
            
            # Frequency domain plot
            plt.subplot(2, 1, 2)
            plt.plot(freqs[:len(freqs)//2], magnitude_db[:len(magnitude_db)//2])
            plt.plot(dominant_freqs, dominant_powers, 'ro', markersize=8)
            plt.title('Frequency Spectrum')
            plt.xlabel('Frequency (Hz)')
            plt.ylabel('Magnitude (dB)')
            plt.grid(True)
            plt.xlim(0, self.sample_rate/2)
            
            plt.tight_layout()
            plt.show()
        
        return {
            'freqs': freqs,
            'magnitude_db': magnitude_db,
            'dominant_freqs': dominant_freqs,
            'dominant_powers': dominant_powers
        }
    
    def analyze_dynamic_range(self):
        """Analyze dynamic range characteristics."""
        # RMS level
        rms_level = np.sqrt(np.mean(self.audio_data**2))
        rms_db = 20 * np.log10(rms_level + 1e-12)
        
        # Peak level
        peak_level = np.max(np.abs(self.audio_data))
        peak_db = 20 * np.log10(peak_level + 1e-12)
        
        # Crest factor
        crest_factor = peak_level / (rms_level + 1e-12)
        crest_factor_db = 20 * np.log10(crest_factor)
        
        # Dynamic range (difference between 95th and 5th percentile)
        percentiles = np.percentile(np.abs(self.audio_data), [5, 95])
        dynamic_range = 20 * np.log10(percentiles[1] / (percentiles[0] + 1e-12))
        
        return {
            'rms_level': rms_level,
            'rms_db': rms_db,
            'peak_level': peak_level,
            'peak_db': peak_db,
            'crest_factor': crest_factor,
            'crest_factor_db': crest_factor_db,
            'dynamic_range_db': dynamic_range
        }
    
    def analyze_hearing_aid_bands(self):
        """Analyze signal in typical hearing aid frequency bands."""
        # Typical hearing aid frequency bands (Hz)
        band_edges = [125, 250, 500, 1000, 2000, 4000, 8000, self.sample_rate//2]
        band_names = ['125-250', '250-500', '500-1k', '1k-2k', '2k-4k', '4k-8k', '8k+']
        
        band_analysis = []
        
        for i in range(len(band_edges) - 1):
            # Design bandpass filter
            low_freq = band_edges[i]
            high_freq = band_edges[i + 1]
            
            # Avoid filter design issues at Nyquist frequency
            if high_freq >= self.sample_rate // 2:
                high_freq = self.sample_rate // 2 - 100
            
            nyquist = self.sample_rate / 2
            low_norm = low_freq / nyquist
            high_norm = high_freq / nyquist
            
            # Design Butterworth bandpass filter
            b, a = signal.butter(4, [low_norm, high_norm], btype='band')
            
            # Filter the signal
            filtered_signal = signal.filtfilt(b, a, self.audio_data)
            
            # Calculate RMS power in this band
            rms_power = np.sqrt(np.mean(filtered_signal**2))
            rms_db = 20 * np.log10(rms_power + 1e-12)
            
            band_analysis.append({
                'band': band_names[i],
                'freq_range': f"{low_freq}-{high_freq} Hz",
                'rms_power': rms_power,
                'rms_db': rms_db
            })
        
        return band_analysis
    
    def generate_test_vectors(self, output_file=None):
        """Generate test vectors for FPGA simulation."""
        # Convert to 16-bit signed integers for FPGA
        audio_int16 = np.clip(self.audio_data * 32767, -32768, 32767).astype(np.int16)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write("// WAV file test vectors for FPGA simulation\n")
                f.write(f"// Source: {self.wav_file}\n")
                f.write(f"// Sample rate: {self.sample_rate} Hz\n")
                f.write(f"// Duration: {self.duration:.2f} seconds\n")
                f.write(f"// Samples: {len(audio_int16)}\n\n")
                
                # Write as hex values for Verilog
                for i, sample in enumerate(audio_int16):
                    # Convert to unsigned 16-bit for hex representation
                    unsigned_val = sample if sample >= 0 else sample + 65536
                    f.write(f"mem[{i}] = 16'h{unsigned_val:04x}; // {sample}\n")
            
            print(f"Test vectors written to {output_file}")
        
        return audio_int16
    
    def print_summary(self):
        """Print comprehensive analysis summary."""
        print("\n" + "="*60)
        print(f"WAV FILE ANALYSIS: {os.path.basename(self.wav_file)}")
        print("="*60)
        
        # Basic parameters
        print(f"Sample Rate: {self.sample_rate} Hz")
        print(f"Duration: {self.duration:.2f} seconds")
        print(f"Total Samples: {len(self.audio_data)}")
        
        # Dynamic range analysis
        dynamic_info = self.analyze_dynamic_range()
        print("\nDynamic Range Analysis:")
        print(f"  RMS Level: {dynamic_info['rms_db']:.1f} dB")
        print(f"  Peak Level: {dynamic_info['peak_db']:.1f} dB")
        print(f"  Crest Factor: {dynamic_info['crest_factor_db']:.1f} dB")
        print(f"  Dynamic Range: {dynamic_info['dynamic_range_db']:.1f} dB")
        
        # Frequency analysis
        spectrum_info = self.analyze_spectrum()
        print("\nSpectral Analysis:")
        print(f"  Dominant Frequencies (top 5):")
        sorted_indices = np.argsort(spectrum_info['dominant_powers'])[::-1]
        for i, idx in enumerate(sorted_indices[:5]):
            freq = spectrum_info['dominant_freqs'][idx]
            power = spectrum_info['dominant_powers'][idx]
            print(f"    {freq:.1f} Hz: {power:.1f} dB")
        
        # Band analysis
        band_info = self.analyze_hearing_aid_bands()
        print("\nHearing Aid Band Analysis:")
        for band in band_info:
            print(f"  {band['band']:8} ({band['freq_range']:12}): {band['rms_db']:6.1f} dB")

def main():
    """Main function for command-line interface."""
    parser = argparse.ArgumentParser(
        description='Analyze WAV files for FPGA hearing aid simulation'
    )
    parser.add_argument('wav_file', help='Input WAV file path')
    parser.add_argument('--plot', action='store_true', 
                       help='Display time and frequency domain plots')
    parser.add_argument('--vectors', type=str, 
                       help='Output file for FPGA test vectors')
    parser.add_argument('--summary-only', action='store_true',
                       help='Print only summary information')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.wav_file):
        print(f"Error: WAV file '{args.wav_file}' not found")
        sys.exit(1)
    
    # Create analyzer and run analysis
    analyzer = WavAnalyzer(args.wav_file)
    
    if not args.summary_only:
        # Detailed analysis
        spectrum = analyzer.analyze_spectrum(plot=args.plot)
        dynamic = analyzer.analyze_dynamic_range()
        bands = analyzer.analyze_hearing_aid_bands()
    
    # Generate test vectors if requested
    if args.vectors:
        analyzer.generate_test_vectors(args.vectors)
    
    # Print summary
    analyzer.print_summary()

if __name__ == '__main__':
    main()
