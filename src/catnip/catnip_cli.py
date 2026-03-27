#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Wrapper to call catnip bash script.
"""

import sys
import subprocess
import importlib.resources as r

def main():
    """
    Main entry point. Simply forwards all arguments to catnip.sh.
    """
    catnip_script = r.files("catnip") / "catnip.sh"

    if not catnip_script.is_file():
        print(f"Error: catnip.sh not found at {catnip_script}", file=sys.stderr)
        sys.exit(1)

    # Forward all command-line arguments to the bash script
    cmd = ["bash", str(catnip_script)] + sys.argv[1:]

    try:
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        sys.exit(130)


if __name__ == "__main__":
    main()