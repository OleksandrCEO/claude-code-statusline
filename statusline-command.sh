#!/bin/sh

input=$(cat)
[ -z "$input" ] && input="$1"

# Pass the input data safely through an environment variable
export PLUGIN_JSON_INPUT="$input"

python3 -c '
import os, sys, json, datetime

input_data = os.environ.get("PLUGIN_JSON_INPUT", "").strip()
if not input_data:
    print("🌳 No Data | 🌿 0% | ⏱️ --", end="")
    sys.exit(0)

try:
    data = json.loads(input_data)
except Exception:
    print("🌳 Parse Error | 🌿 0% | ⏱️ --", end="")
    sys.exit(0)

# 1. Parse Model
model_data = data.get("model", {})
model = model_data.get("display_name", "") if isinstance(model_data, dict) else str(model_data)
if not model or model == "{}":
    model = "Unknown Model"

# 2. Parse Context Window
cw = data.get("context_window", {})
used = cw.get("used_percentage")
usage_str = str(int(used)) + "%" if used is not None else "0%"

# 3. Parse Rate Limits
rl = data.get("rate_limits", {})
rl_5h = rl.get("five_hour", {})
pct = rl_5h.get("used_percentage")
reset_ts = rl_5h.get("resets_at")

rate_limit_str = "--"
if pct is not None:
    pct_int = int(pct)

    # Define colors
    if pct_int >= 90: color = "\033[31m"   # RED
    elif pct_int >= 70: color = "\033[33m" # YELLOW
    else: color = "\033[90m"               # GRAY (Dark Gray) for normal state
    reset_color = "\033[0m"

    # Calculate reset time (24-hour format)
    reset_time = "--"
    if reset_ts:
        try:
            dt = datetime.datetime.fromtimestamp(reset_ts)
            reset_time = dt.strftime("%H:%M")
        except Exception:
            pass

    # Draw progress bar
    width = 10
    filled = int((pct_int * width) / 100)
    bar = "█" * filled + "░" * (width - filled)

    rate_limit_str = color + "5h " + bar + " " + str(pct_int) + "% resets " + reset_time + reset_color

# Output final string explicitly without a newline
print("🌳 " + model + " | 🌿 " + usage_str + " | ⏱️ " + rate_limit_str, end="")
'
