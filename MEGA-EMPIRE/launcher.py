#!/usr/bin/env python3
"""
MEGA-EMPIRE MASTER LAUNCHER
============================
One-click launcher for the complete passive income automation system

Usage:
  python launcher.py                    # Start all modules
  python launcher.py --category ContentFactory  # Start specific category
  python launcher.py --module 1         # Start specific module
  python launcher.py --stop             # Stop all modules
  python launcher.py --status           # Show system status
"""

import os
import sys
import json
import time
import signal
import subprocess
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

# ==============================================================================
# CONFIGURATION
# ==============================================================================

BASE_DIR = Path(__file__).parent
CONFIG_FILE = BASE_DIR / "Config" / "system_config.json"

# Load configuration
with open(CONFIG_FILE) as f:
    CONFIG = json.load(f)

# ==============================================================================
# MODULE MANAGER
# ==============================================================================

class ModuleLauncher:
    """Manages module processes"""

    def __init__(self):
        self.processes: Dict[int, subprocess.Popen] = {}
        self.module_paths = self._discover_modules()

    def _discover_modules(self) -> Dict[int, Path]:
        """Discover all module files"""
        modules = {}

        for category in CONFIG['categories'].keys():
            category_dir = BASE_DIR / category
            if not category_dir.exists():
                continue

            for module_file in category_dir.glob("module_*.py"):
                # Extract module ID from filename
                try:
                    module_id = int(module_file.stem.split('_')[1])
                    modules[module_id] = module_file
                except:
                    pass

        return modules

    def start_module(self, module_id: int) -> bool:
        """Start a specific module"""
        if module_id in self.processes:
            print(f"⚠️  Module {module_id} already running")
            return False

        if module_id not in self.module_paths:
            print(f"❌ Module {module_id} not found")
            return False

        module_path = self.module_paths[module_id]

        try:
            process = subprocess.Popen(
                [sys.executable, str(module_path)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                cwd=BASE_DIR
            )

            self.processes[module_id] = process
            print(f"✓ Started Module {module_id} (PID: {process.pid})")
            return True

        except Exception as e:
            print(f"❌ Failed to start Module {module_id}: {e}")
            return False

    def stop_module(self, module_id: int) -> bool:
        """Stop a specific module"""
        if module_id not in self.processes:
            print(f"⚠️  Module {module_id} not running")
            return False

        try:
            process = self.processes[module_id]
            process.terminate()

            # Wait for graceful shutdown
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()

            del self.processes[module_id]
            print(f"✓ Stopped Module {module_id}")
            return True

        except Exception as e:
            print(f"❌ Failed to stop Module {module_id}: {e}")
            return False

    def start_category(self, category: str) -> int:
        """Start all modules in a category"""
        if category not in CONFIG['categories']:
            print(f"❌ Category '{category}' not found")
            return 0

        category_config = CONFIG['categories'][category]

        if not category_config['enabled']:
            print(f"⚠️  Category '{category}' is disabled")
            return 0

        started = 0
        for module_id in category_config['modules']:
            if self.start_module(module_id):
                started += 1
                time.sleep(0.5)  # Stagger starts

        return started

    def start_all(self) -> int:
        """Start all enabled modules"""
        started = 0

        for category, config in CONFIG['categories'].items():
            if config['enabled']:
                print(f"\n📂 Starting {category}...")
                started += self.start_category(category)

        return started

    def stop_all(self) -> int:
        """Stop all running modules"""
        stopped = 0
        module_ids = list(self.processes.keys())

        for module_id in module_ids:
            if self.stop_module(module_id):
                stopped += 1

        return stopped

    def get_status(self) -> Dict[str, any]:
        """Get status of all modules"""
        status = {
            "total_modules": len(self.module_paths),
            "running_modules": len(self.processes),
            "by_category": {}
        }

        for category, config in CONFIG['categories'].items():
            running = sum(1 for mid in config['modules'] if mid in self.processes)
            status["by_category"][category] = {
                "total": len(config['modules']),
                "running": running,
                "enabled": config['enabled']
            }

        return status

    def print_status(self):
        """Print formatted status"""
        status = self.get_status()

        print("\n" + "="*80)
        print("MEGA-EMPIRE SYSTEM STATUS".center(80))
        print("="*80)
        print(f"\nRunning: {status['running_modules']}/{status['total_modules']} modules")

        for category, cat_status in status['by_category'].items():
            enabled_str = "✓" if cat_status['enabled'] else "✗"
            print(f"\n{enabled_str} {category}:")
            print(f"   {cat_status['running']}/{cat_status['total']} modules running")

        print("\n" + "="*80 + "\n")

# ==============================================================================
# CONTROL CENTER LAUNCHER
# ==============================================================================

def start_master_control():
    """Start the Master Control Center"""
    print("🚀 Starting Master Control Center...")

    master_control = BASE_DIR / "MasterControl" / "master_control_center.py"

    if not master_control.exists():
        print("❌ Master Control Center not found")
        return None

    try:
        process = subprocess.Popen(
            [sys.executable, str(master_control)],
            cwd=BASE_DIR
        )

        print(f"✓ Master Control Center started (PID: {process.pid})")
        return process

    except Exception as e:
        print(f"❌ Failed to start Master Control Center: {e}")
        return None

# ==============================================================================
# MAIN
# ==============================================================================

def print_banner():
    """Print startup banner"""
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║                    MEGA-EMPIRE MASTER LAUNCHER                            ║
    ║                                                                           ║
    ║             Ultimate Passive Income Automation System                     ║
    ║                                                                           ║
    ║                         DLX-Phoenix Team                                  ║
    ║                         Version 1.0.0                                     ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
    """)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="MEGA-EMPIRE System Launcher")
    parser.add_argument('--category', type=str, help="Start specific category")
    parser.add_argument('--module', type=int, help="Start specific module ID")
    parser.add_argument('--stop', action='store_true', help="Stop all modules")
    parser.add_argument('--status', action='store_true', help="Show system status")
    parser.add_argument('--master', action='store_true', help="Start Master Control only")

    args = parser.parse_args()

    print_banner()

    launcher = ModuleLauncher()

    # Handle different commands
    if args.status:
        launcher.print_status()
        return

    if args.stop:
        print("🛑 Stopping all modules...")
        stopped = launcher.stop_all()
        print(f"\n✓ Stopped {stopped} modules")
        return

    if args.master:
        master_process = start_master_control()
        if master_process:
            try:
                master_process.wait()
            except KeyboardInterrupt:
                print("\n\n🛑 Shutting down Master Control...")
                master_process.terminate()
        return

    if args.module:
        launcher.start_module(args.module)
        return

    if args.category:
        started = launcher.start_category(args.category)
        print(f"\n✓ Started {started} modules in {args.category}")
        return

    # Default: Start everything
    print("🚀 Starting MEGA-EMPIRE System...")
    print("="*80)

    # Start Master Control Center
    master_process = start_master_control()
    time.sleep(2)

    # Start all modules
    print("\n📦 Starting all modules...")
    started = launcher.start_all()

    print("\n" + "="*80)
    print(f"✓ System started successfully!")
    print(f"✓ Master Control Center running")
    print(f"✓ {started} modules started")
    print("="*80)
    print("\nPress Ctrl+C to stop all modules\n")

    # Setup signal handler
    def signal_handler(sig, frame):
        print("\n\n🛑 Shutting down MEGA-EMPIRE System...")
        print("="*80)

        # Stop all modules
        stopped = launcher.stop_all()
        print(f"✓ Stopped {stopped} modules")

        # Stop Master Control
        if master_process:
            master_process.terminate()
            print("✓ Stopped Master Control Center")

        print("="*80)
        print("✓ Shutdown complete")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # Wait for Master Control to finish
    if master_process:
        try:
            master_process.wait()
        except:
            pass


if __name__ == "__main__":
    main()
