"""Generate a public allowlist; never copy private provider keys into assets."""
import argparse
import base64
import json
from pathlib import Path

ALLOWED = ("SUPABASE_URL", "SUPABASE_ANON_KEY", "APP_ENVIRONMENT")

def public_config(raw):
    values = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.removeprefix("export ").strip()
        if key in ALLOWED:
            values[key] = value.strip().strip('"').strip("'")
    key = values.get("SUPABASE_ANON_KEY", "")
    if key.startswith("sb_secret_"):
        raise ValueError("SUPABASE_ANON_KEY must be a publishable/anon key.")
    if key.count(".") == 2:
        try:
            payload = json.loads(base64.urlsafe_b64decode(key.split(".")[1] + "==="))
        except (ValueError, UnicodeDecodeError):
            raise ValueError("Invalid public JWT key.") from None
        if not isinstance(payload, dict) or payload.get("role") != "anon":
            raise ValueError("Only an anon JWT is allowed in the public bundle.")
    if not values.get("SUPABASE_URL", "").startswith("https://") or not key:
        raise ValueError("Public Supabase URL and key are required.")
    values.setdefault("APP_ENVIRONMENT", "development")
    return values

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", default=".env")
    args = parser.parse_args()
    try:
        config = public_config(Path(args.env).read_text(encoding="utf-8-sig"))
        Path("assets/public_config.json").write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError) as error:
        raise SystemExit(str(error)) from None
    print("Generated assets/public_config.json with public fields only.")
