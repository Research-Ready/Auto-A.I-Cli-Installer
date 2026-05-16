#!/usr/bin/env python3
import json
import os
import subprocess
import time
from typing import List, Dict, Any

# Simple benchmark script for OpenRouter free models

API_KEY_FILE = os.path.expanduser("~/.config/opencode/openrouter.key")
REPORT_FILE = "openrouter_free_model_report.md"
RESULTS_FILE = "openrouter_free_model_results.json"

def get_api_key():
    if "OPENROUTER_API_KEY" in os.environ:
        return os.environ["OPENROUTER_API_KEY"]
    if os.path.exists(API_KEY_FILE):
        return open(API_KEY_FILE).read().strip()
    return None

def fetch_models(api_key: str) -> List[Dict[str, Any]]:
    print("Fetching models from OpenRouter...")
    cmd = [
        "curl", "-s",
        "-H", f"Authorization: Bearer {api_key}",
        "https://openrouter.ai/api/v1/models"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("Failed to fetch models.")
        return []
    try:
        data = json.loads(result.stdout)
        return data.get("data", [])
    except Exception as e:
        print(f"Error parsing models: {e}")
        return []

def test_model(api_key: str, model_id: str, prompt: str) -> Dict[str, Any]:
    start_time = time.time()
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}]
    }
    cmd = [
        "curl", "-s",
        "-X", "POST",
        "-H", f"Authorization: Bearer {api_key}",
        "-H", "Content-Type: application/json",
        "-d", json.dumps(payload),
        "https://openrouter.ai/api/v1/chat/completions"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    latency = time.time() - start_time
    
    success = False
    error = ""
    response_text = ""
    
    if result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            if "choices" in data:
                success = True
                response_text = data["choices"][0]["message"]["content"]
            else:
                error = data.get("error", {}).get("message", "Unknown error")
        except Exception as e:
            error = f"Parse error: {e}"
    else:
        error = "Curl failed"
        
    return {
        "success": success,
        "latency": latency,
        "response": response_text,
        "error": error
    }

def main():
    api_key = get_api_key()
    if not api_key:
        print("Error: No OpenRouter API key found. Set OPENROUTER_API_KEY or run the installer first.")
        return

    models = fetch_models(api_key)
    free_models = [m for m in models if m.get("pricing", {}).get("prompt") == "0" and m.get("pricing", {}).get("completion") == "0"]
    
    if not free_models:
        print("No free models found.")
        # Sometimes pricing is 0.0 or "0.0000"
        free_models = [m for m in models if float(m.get("pricing", {}).get("prompt", 1)) == 0]

    print(f"Found {len(free_models)} free models. Starting benchmark...")
    
    results = []
    
    # Benchmarking logic
    prompts = {
        "chat": "Say 'Hello' and nothing else.",
        "coding": "Write a python function to add two numbers.",
    }

    for model in free_models:
        model_id = model["id"]
        print(f"Testing {model_id}...")
        
        model_results = {"id": model_id, "tests": {}}
        for test_name, prompt in prompts.items():
            res = test_model(api_key, model_id, prompt)
            model_results["tests"][test_name] = res
            
        results.append(model_results)

    # Save raw results
    with open(RESULTS_FILE, "w") as f:
        json.dump(results, f, indent=2)
        
    # Generate report
    with open(REPORT_FILE, "w") as f:
        f.write("# OpenRouter Free Model Benchmark Report\n\n")
        f.write(f"Generated on: {time.ctime()}\n\n")
        f.write("| Model ID | Chat Success | Coding Success | Latency (avg) |\n")
        f.write("| --- | --- | --- | --- |\n")
        
        for r in results:
            chat_ok = "✅" if r["tests"]["chat"]["success"] else "❌"
            code_ok = "✅" if r["tests"]["coding"]["success"] else "❌"
            avg_latency = (r["tests"]["chat"]["latency"] + r["tests"]["coding"]["latency"]) / 2
            f.write(f"| {r['id']} | {chat_ok} | {code_ok} | {avg_latency:.2f}s |\n")

    print(f"Benchmark complete! Report saved to {REPORT_FILE}")

if __name__ == "__main__":
    main()
