import json
import re
import os

transcript_path = r"C:\Users\SAI GAGAN\.gemini\antigravity\brain\31eade12-4f3b-455d-be4c-7655deebe98a\.system_generated\logs\transcript.jsonl"

with open(transcript_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

last_user_input = ""
for line in reversed(lines):
    try:
        data = json.loads(line)
        if data.get("type") == "USER_INPUT":
            last_user_input = data.get("content", "")
            break
    except:
        pass

# The text contains JSONs. We can use a regex to find all JSON-like structures that start with {"v":"
matches = re.finditer(r'\{"v":"5\.[^"]+",.*?"assets":\[.*?\]\}', last_user_input, re.DOTALL)
lotties = []
for m in matches:
    lotties.append(m.group(0))

print(f"Found {len(lotties)} lotties")

for i, lottie in enumerate(lotties):
    # Try to extract the name
    name = f"animation_{i+1}"
    try:
        parsed = json.loads(lottie)
        if "nm" in parsed:
            name = parsed["nm"].replace(" ", "_").lower()
            name = "".join(c for c in name if c.isalnum() or c == '_')
    except:
        pass
        
    out_path = f"assets/lottie/{name}.json"
    with open(out_path, 'w', encoding='utf-8') as out_f:
        out_f.write(lottie)
    print(f"Saved {out_path}")
