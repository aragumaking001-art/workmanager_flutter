import socket
import urllib.request
import ssl

IP = "192.168.10.177"
ports = [80, 443, 20002, 10443]

print(f"=== Port Scan for {IP} ===")
for p in ports:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(1.5)
    result = s.connect_ex((IP, p))
    s.close()
    print(f"Port {p}: {'OPEN' if result == 0 else 'CLOSED'}")

# Try direct HTTP/HTTPS handshake info
print("\n=== Direct probe ===")
for proto, p in [("http", 80), ("https", 443)]:
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        url = f"{proto}://{IP}:{p}/"
        req = urllib.request.Request(url, headers={"User-Agent": "TapoApp"})
        with urllib.request.urlopen(req, timeout=2, context=ctx if proto=="https" else None) as resp:
            print(f"{proto.upper()} {p}: Code {resp.getcode()}, Headers: {dict(resp.headers)}")
    except urllib.error.HTTPError as e:
        print(f"{proto.upper()} {p}: HTTPError {e.code}, Headers: {dict(e.headers)}")
    except Exception as e:
        print(f"{proto.upper()} {p}: {type(e).__name__}: {e}")
