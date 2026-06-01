#!/usr/bin/env python3
"""Check live service endpoints and rewrite the status table in README.md."""

import urllib.request
import urllib.error
import socket
from datetime import datetime, timezone
from pathlib import Path

README = Path(__file__).parent.parent / "README.md"
MARKER_START = "<!-- SERVICE_STATUS_START -->"
MARKER_END = "<!-- SERVICE_STATUS_END -->"
TIMEOUT = 6  # seconds per check

SERVICES = [
    # (display name, url, expected status codes)
    ("Traefik",     "http://10.0.4.10:8080/ping",          [200]),
    ("LiteLLM",     "http://10.0.6.10:4000/health",        [200]),
    ("Ollama",      "http://10.0.6.10:11434/",             [200]),
    ("Qdrant",      "http://10.0.6.10:6333/",              [200]),
    ("SearXNG",     "http://10.0.6.10:8081/",              [200]),
    ("Langfuse",    "http://10.0.6.10:3002/api/public/health", [200]),
    ("MinIO",       "http://10.0.6.10:9000/minio/health/live", [200]),
    ("Neo4j",       "http://10.0.6.10:7474/",              [200]),
    ("Open WebUI",  "http://10.0.6.11:3000/",              [200]),
    ("n8n",         "http://10.0.6.11:5678/",              [200]),
    ("Flowise",     "http://10.0.6.11:3001/",              [200]),
    ("Grafana",     "http://10.0.6.15:3100/api/health",    [200]),
    ("Prometheus",  "http://10.0.6.15:9090/-/healthy",     [200]),
    ("Uptime Kuma", "http://10.0.6.15:3201/",              [200]),
    ("Portainer",   "https://10.0.6.15:9443/",             [200]),
    ("Authentik",   "http://10.0.6.5:9000/-/health/live/", [204, 200]),
]


def check(url: str, ok_codes: list[int]) -> tuple[str, str]:
    """Returns (emoji, latency_ms_or_error)."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "status-check/1.0"})
        ctx = __import__("ssl").create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = __import__("ssl").CERT_NONE
        start = __import__("time").monotonic()
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as resp:
            ms = int((__import__("time").monotonic() - start) * 1000)
            if resp.status in ok_codes:
                return "🟢", f"{ms} ms"
            return "🟡", f"HTTP {resp.status}"
    except urllib.error.HTTPError as e:
        if e.code in ok_codes:
            return "🟢", "ok"
        return "🔴", f"HTTP {e.code}"
    except (urllib.error.URLError, socket.timeout, OSError) as e:
        return "🔴", "unreachable"


def build_table(results: list[tuple[str, str, str]]) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        MARKER_START,
        f"*Last checked: {now}*",
        "",
        "| Service | Status | Latency |",
        "|---------|--------|---------|",
    ]
    for name, emoji, detail in results:
        lines.append(f"| {name} | {emoji} | {detail} |")
    lines.append(MARKER_END)
    return "\n".join(lines)


def main():
    results = []
    for name, url, ok_codes in SERVICES:
        emoji, detail = check(url, ok_codes)
        print(f"  {emoji}  {name:15} {detail}")
        results.append((name, emoji, detail))

    table = build_table(results)

    text = README.read_text()
    if MARKER_START not in text:
        print("ERROR: status markers not found in README.md")
        raise SystemExit(1)

    start_idx = text.index(MARKER_START)
    end_idx = text.index(MARKER_END) + len(MARKER_END)
    new_text = text[:start_idx] + table + text[end_idx:]
    README.write_text(new_text)
    print("README.md updated.")


if __name__ == "__main__":
    main()
