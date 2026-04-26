#!/bin/sh

SHOW_TOKENS=false
for arg in "$@"; do
  case "$arg" in
    --tokens) SHOW_TOKENS=true ;;
  esac
done

input=$(cat)

# Pass the input data safely through environment variables
export PLUGIN_JSON_INPUT="$input"
export PLUGIN_SHOW_TOKENS="$SHOW_TOKENS"

python3 -c '
import os, sys, json, datetime

input_data = os.environ.get("PLUGIN_JSON_INPUT", "").strip()
show_tokens = os.environ.get("PLUGIN_SHOW_TOKENS", "false") == "true"

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

# 3. Parse Session Tokens
total_in = cw.get("total_input_tokens", 0) or 0
total_out = cw.get("total_output_tokens", 0) or 0

def fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}m"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)

tokens_str = fmt_tokens(total_in) + " in / " + fmt_tokens(total_out) + " out"

# 4. Parse Rate Limits
rl = data.get("rate_limits", {})
rl_5h = rl.get("five_hour", {})
pct = rl_5h.get("used_percentage")
reset_ts = rl_5h.get("resets_at")

rate_limit_str = "--"
if pct is not None:
    pct_int = int(pct)

    # Define colors
    if pct_int >= 90: color = "\033[38;5;160m"   # RED (Red3)
    elif pct_int >= 70: color = "\033[38;5;214m" # YELLOW (Orange1)
    else: color = "\033[90m"                     # GRAY (Dark Gray) for normal state
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

# Build output
parts = ["🌳 " + model, "🌿 " + usage_str]
if show_tokens:
    parts.append("🦥 " + tokens_str)
parts.append("⏱️ " + rate_limit_str)
print(" | ".join(parts), end="")
'
