#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Redirect wrapper for backward compatibility.
Points directly to run_multi_seed_trace_36k.py.
"""
import sys
import subprocess
from pathlib import Path

target = Path(__file__).parent / "run_multi_seed_trace_36k.py"
sys.exit(subprocess.run([sys.executable, str(target)] + sys.argv[1:]).returncode)
