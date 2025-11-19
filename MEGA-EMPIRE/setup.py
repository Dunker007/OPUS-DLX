#!/usr/bin/env python3
"""
MEGA-EMPIRE Setup Script
========================
Ultimate Passive Income Automation System

Installation:
    pip install -e .

Development:
    pip install -e ".[dev]"
"""

from setuptools import setup, find_packages
from pathlib import Path

# Read README
readme_file = Path(__file__).parent / "README.md"
long_description = readme_file.read_text(encoding="utf-8") if readme_file.exists() else ""

# Read requirements
requirements_file = Path(__file__).parent / "requirements.txt"
requirements = []
if requirements_file.exists():
    requirements = [
        line.strip()
        for line in requirements_file.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ]

setup(
    name="mega-empire",
    version="1.0.0",
    description="Ultimate Passive Income Automation System",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="DLX-Phoenix Team",
    author_email="contact@dlx-phoenix.com",
    url="https://github.com/YourOrg/MEGA-EMPIRE",
    license="Proprietary",

    # Package discovery
    packages=find_packages(exclude=["tests", "tests.*", "*.tests", "*.tests.*"]),

    # Include non-Python files
    include_package_data=True,
    package_data={
        "": ["*.json", "*.yaml", "*.yml", "*.md", "*.txt"],
    },

    # Dependencies
    install_requires=requirements,

    # Optional dependencies
    extras_require={
        "dev": [
            "pytest>=7.4.0",
            "pytest-asyncio>=0.21.0",
            "black>=23.0.0",
            "pylint>=2.17.0",
            "mypy>=1.5.0",
        ],
        "full": [
            "openai>=1.0.0",
            "anthropic>=0.7.0",
            "google-api-python-client>=2.0.0",
            "tweepy>=4.14.0",
            "mailchimp-marketing>=3.0.0",
        ],
    },

    # Entry points for command-line scripts
    entry_points={
        "console_scripts": [
            "mega-empire=launcher:main",
            "mega-empire-master=MasterControl.master_control_center:main",
        ],
    },

    # Python version requirement
    python_requires=">=3.8",

    # Classification
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "Intended Audience :: Financial and Insurance Industry",
        "Topic :: Office/Business :: Financial",
        "Topic :: Internet :: WWW/HTTP :: Dynamic Content",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Operating System :: OS Independent",
        "Operating System :: Microsoft :: Windows",
        "Operating System :: POSIX :: Linux",
        "Operating System :: MacOS",
    ],

    # Keywords for PyPI
    keywords=[
        "passive-income",
        "automation",
        "content-generation",
        "revenue-optimization",
        "traffic-generation",
        "ai-automation",
        "multi-platform",
        "seo",
        "affiliate-marketing",
        "digital-products",
    ],

    # Project URLs
    project_urls={
        "Documentation": "https://github.com/YourOrg/MEGA-EMPIRE/blob/main/README.md",
        "Source": "https://github.com/YourOrg/MEGA-EMPIRE",
        "Tracker": "https://github.com/YourOrg/MEGA-EMPIRE/issues",
    },

    # Zip safe
    zip_safe=False,
)
