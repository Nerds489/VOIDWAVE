#!/usr/bin/env python3
"""Test script to verify TUI implementation."""
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / "src"))

try:
    print("Testing TUI imports...")
    
    # Test basic imports
    from voidwave.tui import VoidwaveApp, run_app
    print("✓ Main app imports successful")
    
    from voidwave.tui.theme import NEON_CYAN, HOT_MAGENTA, DEEP_NAVY, MATRIX_GREEN
    print("✓ Theme constants imported")
    
    from voidwave.tui.screens.main import MainScreen, VOIDWAVE_BANNER
    print("✓ MainScreen imported")
    
    # Test widget imports
    from voidwave.tui.widgets import ToolOutput, TargetTree, ProgressPanel, StatusPanel
    print("✓ All widgets imported")
    
    # Test screen imports
    from voidwave.tui.screens import (
        WirelessScreen, ScanScreen, CredentialsScreen, OsintScreen,
        ReconScreen, TrafficScreen, ExploitScreen, StressScreen,
        StatusScreen, SettingsScreen, HelpScreen
    )
    print("✓ All screens imported")
    
    # Test wizard imports
    from voidwave.tui.wizards import FirstRunWizard, ScanWizard
    print("✓ Wizards imported")
    
    # Test command imports
    from voidwave.tui.commands import VoidwaveCommands
    print("✓ Commands imported")
    
    # Check CSS file exists
    from voidwave.tui.app import VoidwaveApp
    app = VoidwaveApp()
    if app.CSS_PATH.exists():
        print(f"✓ CSS file found: {app.CSS_PATH}")
        with open(app.CSS_PATH) as f:
            lines = len(f.readlines())
        print(f"  CSS file has {lines} lines")
    else:
        print(f"✗ CSS file not found: {app.CSS_PATH}")
    
    print("\n" + "="*60)
    print("✅ ALL TUI COMPONENTS SUCCESSFULLY IMPORTED!")
    print("="*60)
    print("\nTo run the TUI:")
    print("  python -m voidwave.tui.app")
    print("\nor:")
    print("  from voidwave.tui import run_app")
    print("  run_app()")
    
except ImportError as e:
    print(f"\n✗ Import error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"\n✗ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
