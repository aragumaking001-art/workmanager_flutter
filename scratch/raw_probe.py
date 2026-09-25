import urllib.request
import json
import ssl

url = "http://192.168.10.177/app"
headers = {"Content-Type": "application/json"}

# Try common Tapo endpoints
for path in ["/app", "/app/handshake1", "/"]:
    try:
        req = urllib.request.Request(f"http://192.168.10.177{path}", headers={"User-Agent": "TapoApp"})
        with urllib.request.urlopen(req, timeout=2) as resp:
            print(f"Path {path}: Status={resp.status}, Body={resp.read().decode('utf-8', errors='replace')[:200]}")
    except urllib.error.HTTPError as e:
        print(f"Path {path}: HTTPError {e.code}, Body={e.read().decode('utf-8', errors='replace')[:200]}")
    except Exception as e:
        print(f"Path {path}: {type(e).__name__}: {e}")
