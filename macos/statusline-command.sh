#!/bin/sh
# Claude Code status line - inspired by Starship Tokyo Night theme

input=$(cat)

# Extract fields from JSON input
cwd=$(echo "$input" | jq -r '.cwd')
model=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Username and hostname
user=$(whoami)
host=$(hostname -s)

# Shorten cwd: replace $HOME with ~, then keep last 3 segments
home="$HOME"
short_cwd="${cwd/#$home/~}"
short_cwd=$(echo "$short_cwd" | awk -F'/' '{
  n=NF
  if (n <= 3) { print $0 }
  else { print "..." "/" $(n-2) "/" $(n-1) "/" $n }
}')

# Git branch and status (skip locking to avoid conflicts)
git_info=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  git_status=$(git -C "$cwd" status --porcelain 2>/dev/null)
  dirty=""
  if [ -n "$git_status" ]; then
    dirty="*"
  fi
  git_info=" |  ${branch}${dirty}"
fi

# Time
time_now=$(date +%H:%M)

# Format a token count: <1000 as-is, >=1000 as X.Xk, >=1000000 as X.XM
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { printf "%.1fM", n / 1000000 }
    else if (n >= 1000) { printf "%.1fk", n / 1000 }
    else { printf "%d", n }
  }'
}

# Context usage - accumulate token counts across turns using a per-session temp file
ctx_info=""
turn_out=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
turn_in=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
if [ -n "$used_pct" ] && [ -n "$turn_out" ] && [ -n "$turn_in" ]; then
  token_file="/tmp/claude_tokens_${PPID}"

  # Read existing accumulated totals, defaulting to 0
  acc_out=0
  acc_in=0
  if [ -f "$token_file" ]; then
    acc_out=$(awk 'NR==1 {print $1}' "$token_file")
    acc_in=$(awk 'NR==2 {print $1}' "$token_file")
    # Guard against corrupt/empty reads
    acc_out=${acc_out:-0}
    acc_in=${acc_in:-0}
  fi

  # Add this turn's tokens to the running totals
  total_out=$(( acc_out + turn_out ))
  total_in=$(( acc_in + turn_in ))

  # Persist updated totals
  printf "%s\n%s\n" "$total_out" "$total_in" > "$token_file"

  ctx_int=$(printf "%.0f" "$used_pct")
  fmt_out=$(fmt_tokens "$total_out")
  fmt_in=$(fmt_tokens "$total_in")
  ctx_info=" | ${fmt_out}↓ ${fmt_in}↑ ${ctx_int}%"
fi

# Build and print status line with ANSI colors (Tokyo Night palette)
# Colors: #7aa2f7 (blue) = 38;2;122;162;247  |  #bb9af7 (purple) = 38;2;187;154;247
#         #00ff00 (green) = 32  |  #9ece6a (green) = 38;2;158;206;106
#         reset = 0

printf "\033[38;2;122;162;247m \033[0m" # macOS symbol (nerd font)
printf "\033[38;2;122;162;247m%s\033[0m" "$user"
printf " \033[38;2;187;154;247m%s\033[0m" "$short_cwd"
if [ -n "$git_info" ]; then
  printf "\033[38;2;187;154;247m%s\033[0m" "$git_info"
fi
printf " | \033[38;2;158;206;106m%s\033[0m" "$model"
printf "%s" "$ctx_info"
printf " | \033[38;2;0;255;0m%s\033[0m" "$time_now"
printf "\n"
