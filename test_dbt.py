#!/usr/bin/env python
import subprocess
import sys

# Test dbt project
print("=" * 60)
print("Testing dbt project...")
print("=" * 60)

# Run dbt debug
print("\n1. Running dbt debug...")
result = subprocess.run([sys.executable, "-m", "dbt", "debug"], cwd="C:\\work\\healthcare-db")
if result.returncode != 0:
    print("DEBUG FAILED - Check Snowflake connection")
    sys.exit(1)

print("\n2. Running dbt deps...")
result = subprocess.run([sys.executable, "-m", "dbt", "deps"], cwd="C:\\work\\healthcare-db")
if result.returncode != 0:
    print("DEPS FAILED")
    sys.exit(1)

print("\n3. Running dbt parse...")
result = subprocess.run([sys.executable, "-m", "dbt", "parse"], cwd="C:\\work\\healthcare-db")
if result.returncode != 0:
    print("PARSE FAILED")
    sys.exit(1)

print("\n4. Running dbt test (no execute)...")
result = subprocess.run([sys.executable, "-m", "dbt", "test", "--select", "tag:staging"], cwd="C:\\work\\healthcare-db")
if result.returncode != 0:
    print("TEST FAILED")
else:
    print("TEST PASSED!")

print("\n" + "=" * 60)
print("dbt project test complete")
print("=" * 60)
