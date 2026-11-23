"""Check the actual web artifact without printing any private configuration."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--env", default=".env")
args = parser.parse_args()
root = Path("build/web")
if not (root / "main.dart.js").exists():
    raise SystemExit("Build Web dahulu.")
private_values = []
env = Path(args.env)
if env.exists():
    for line in env.read_text(encoding="utf-8-sig").splitlines():
        if "=" not in line or line.lstrip().startswith("#"):
            continue
        key, value = line.split("=", 1)
        if key.strip() in {"WAHA_API_KEY", "ONESIGNAL_REST_API_KEY", "SUPABASE_SERVICE_ROLE_KEY"}:
            value = value.strip().strip('"').strip("'")
            if len(value) >= 8:
                private_values.append(value.encode())
failures = set()
for path in root.rglob("*"):
    if not path.is_file():
        continue
    if path.name == ".env":
        failures.add("An environment file is present in the web artifact.")
    data = path.read_bytes()
    if any(value in data for value in private_values):
        failures.add("A private credential is present in the web artifact.")
if failures:
    raise SystemExit("\n".join(sorted(failures)))
print("PASS: no .env asset or configured private credentials in build/web.")
