#!/usr/bin/env python3
"""
Binary patch WeChatLiquidGlass.dylib:
Change CydiaSubstrate dependency from strong (LC_LOAD_DYLIB) to weak (LC_LOAD_WEAK_DYLIB).

Usage: python patch.py <input.dylib> [output.dylib]
"""

import struct
import sys
import os

LC_LOAD_DYLIB = 0x0C
LC_LOAD_WEAK_DYLIB = 0x80000028

CYDIASUBSTRATE_PATH = b"/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"


def patch_arch_slice(data, base_offset):
    """Patch one architecture slice. Returns absolute offset of cmd field or None."""
    ncmds = struct.unpack_from(b"<I", data, base_offset + 16)[0]
    pos = base_offset + 32  # after mach_header_64

    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from(b"<II", data, pos)
        if cmd == LC_LOAD_DYLIB:
            name_offset = struct.unpack_from(b"<I", data, pos + 8)[0]
            name_end = data.find(b"\x00", pos + name_offset)
            name = data[pos + name_offset : name_end]
            if name == CYDIASUBSTRATE_PATH:
                return pos  # absolute offset of cmd field
        pos += cmdsize
    return None


def main():
    if len(sys.argv) < 2:
        sys.exit(f"Usage: {sys.argv[0]} <input.dylib> [output.dylib]")

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else input_path

    with open(input_path, "rb") as f:
        data = bytearray(f.read())

    magic = struct.unpack_from(b"<I", data, 0)[0]
    patches = []

    if magic == 0xBEBAFECA:
        narchs = struct.unpack_from(b">I", data, 4)[0]
        print(f"FAT binary with {narchs} architectures")
        for i in range(narchs):
            cputype, cpusubtype, offset, size, _ = struct.unpack_from(
                b">IIIII", data, 8 + i * 20
            )
            cpu_name = {16777228: "ARM64E", 12: "ARM64"}.get(cputype, str(cputype))
            print(f"  Arch {i}: {cpu_name}")
            patch_off = patch_arch_slice(data, offset)
            if patch_off is not None:
                patches.append(patch_off)
    else:
        print("Thin binary")
        patch_off = patch_arch_slice(data, 0)
        if patch_off is not None:
            patches.append(patch_off)

    if not patches:
        print("ERROR: CydiaSubstrate framework reference not found!")
        print("The dylib may already be patched or uses a different format.")
        sys.exit(1)

    for off in patches:
        old_cmd = struct.unpack_from(b"<I", data, off)[0]
        struct.pack_into(b"<I", data, off, LC_LOAD_WEAK_DYLIB)
        print(
            f"  Patched offset {off:#010x}: {old_cmd:#010x} -> {LC_LOAD_WEAK_DYLIB:#010x}"
        )

    with open(output_path, "wb") as f:
        f.write(data)

    print(f"\nDone! Patched dylib saved to: {output_path}")
    print(
        "CydiaSubstrate is now a WEAK link — dyld will not abort if it's missing."
    )


if __name__ == "__main__":
    main()
