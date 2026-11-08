#!/usr/bin/env python3
"""
Convert raw binary file to 32-bit word Verilog hex file for $readmemh.
Usage: python bin2hex.py <input.bin> <output.hex> [word_depth]
"""
import sys
import struct

def bin_to_hex(bin_path, hex_path, depth=4096):
    with open(bin_path, "rb") as f:
        data = f.read()

    words = []
    # Pad to multiple of 4 bytes
    if len(data) % 4 != 0:
        data += b"\x00" * (4 - (len(data) % 4))

    for i in range(0, len(data), 4):
        # Little-endian 32-bit word
        val = struct.unpack("<I", data[i:i+4])[0]
        words.append(f"{val:08x}")

    with open(hex_path, "w") as f:
        for w in words:
            f.write(f"{w}\n")

    print(f"[bin2hex] Converted {len(data)} bytes ({len(words)} words) to {hex_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python bin2hex.py <input.bin> <output.hex> [word_depth]")
        sys.exit(1)
    depth = int(sys.argv[3]) if len(sys.argv) > 3 else 4096
    bin_to_hex(sys.argv[1], sys.argv[2], depth)
