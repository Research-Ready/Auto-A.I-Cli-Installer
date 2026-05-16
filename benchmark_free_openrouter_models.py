#!/usr/bin/env python3
import json
import os
import subprocess
import time
from typing import List, Dict, Any

# Enhanced benchmark script for OpenRouter models

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

def test_model(api_key: str, model_id: str, prompt: str, tools: List[Dict[str, Any]] = None) -> Dict[str, Any]:
    start_time = time.time()
    payload = {
        "model": model_id,
        "messages": [{"role": "user", "content": prompt}]
    }
    if tools:
        payload["tools"] = tools
        
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
    tool_calls = False
    
    if result.returncode == 0:
        try:
            data = json.loads(result.stdout)
            if "choices" in data:
                success = True
                msg = data["choices"][0]["message"]
                response_text = msg.get("content", "")
                if "tool_calls" in msg:
                    tool_calls = True
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
        "tool_calls": tool_calls,
        "error": error
    }

def main():
    api_key = get_api_key()
    if not api_key:
        print("Error: No OpenRouter API key found. Set OPENROUTER_API_KEY or run the installer first.")
        return

    models = fetch_models(api_key)
    free_models = [m for m in models if float(m.get("pricing", {}).get("prompt", 1)) == 0]

    print(f"Found {len(free_models)} free models. Starting enhanced benchmark...")
    
    results = []
    
    # Benchmarking logic
    prompts = {
        "chat": "Say 'Hello' and nothing else.",
        "coding": "Write a python function to add two numbers.",
    }
    
    # Mock tool for tool-use testing
    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get current weather",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string"}
                }
            }
        }
    }]
    tool_prompt = "What is the weather in Amsterdam?"

    for model in free_models:
        model_id = model["id"]
        print(f"Testing {model_id}...")
        
        model_results = {"id": model_id, "tests": {}}
        
        # Standard tests
        for test_name, prompt in prompts.items():
            res = test_model(api_key, model_id, prompt)
            model_results["tests"][test_name] = res
            
        # Tool-use test
        print(f"  Testing tool-use for {model_id}...")
        tool_res = test_model(api_key, model_id, tool_prompt, tools=tools)
        model_results["tests"]["tool_use"] = tool_res
        
        # Context window verification (brief check)
        context_len = model.get("context_length", 0)
        model_results["advertised_context"] = context_len
            
        results.append(model_results)

    # Save raw results
    with open(RESULTS_FILE, "w") as f:
        json.dump(results, f, indent=2)
        
    # Generate report
    with open(REPORT_FILE, "w") as f:
        f.write("# OpenRouter Free Model Enhanced Benchmark Report\n\n")
        f.write(f"Generated on: {time.ctime()}\n\n")
        f.write("| Model ID | Chat | Coding | Tool-Use | Context | Latency (avg) |\n")
        f.write("| --- | --- | --- | --- | --- | --- |\n")
        
        for r in results:
            chat_ok = "✅" if r["tests"]["chat"]["success"] else "❌"
            code_ok = "✅" if r["tests"]["coding"]["success"] else "❌"
            tool_ok = "🛠️" if r["tests"]["tool_use"]["tool_calls"] else ("✅" if r["tests"]["tool_use"]["success"] else "❌")
            ctx = f"{r['advertised_context']//1024}k" if r['advertised_context'] else "unk"
            
            # Avg latency of chat and coding
            avg_latency = (r["tests"]["chat"]["latency"] + r["tests"]["coding"]["latency"]) / 2
            f.write(f"| {r['id']} | {chat_ok} | {code_ok} | {tool_ok} | {ctx} | {avg_latency:.2f}s |\n")

    print(f"Benchmark complete! Report saved to {REPORT_FILE}")

if __name__ == "__main__":
    main()
