#!/bin/bash
# Claude Code status line - Tokyo Night Storm, flat.
#
# Deliberately does NOT mirror starship's powerline styling: no background
# blocks,  arrows, or trailing $character glyph. Each section is plain text
# in its own distinct Storm hue, joined by a dim separator, so the bar reads
# as information rather than decoration.
#
# Sections 1-4 and 7 track starship modules (user@host, directory,
# git_branch/git_status, rust/golang/nodejs/python, time). Sections 5-6
# (model, context/tokens) are Claude-only and have no starship equivalent.

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
# Fall back rather than render a literal "null" if a field is ever absent.
cwd=${cwd:-$PWD}
model=${model:-Claude}
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
turn_out=$(printf '%s' "$input" | jq -r '.context_window.current_usage.output_tokens // empty')
turn_in=$(printf '%s' "$input" | jq -r '.context_window.current_usage.input_tokens // empty')

home="$HOME"

# ---- Tokyo Night Storm palette - foregrounds only, one per section ----
BLUE="122;162;247"      # #7aa2f7  user@host
TEAL="115;218;202"      # #73daca  directory
MAGENTA="187;154;247"   # #bb9af7  git branch
GREEN="158;206;106"     # #9ece6a  language runtimes
ORANGE="255;158;100"    # #ff9e64  model
CYAN="125;207;255"      # #7dcfff  context / tokens
PURE_GREEN="0;255;0"    # #00ff00  time - deliberately outside the Storm palette
COMMENT="86;95;137"     # #565f89  separators
RED="247;118;142"       # #f7768e  root user (starship's style_root)

# Colorize $2 in the truecolor triplet $1. Content goes through %s so a literal
# % in a segment (the context percentage) is never read as a format spec.
paint() { printf '\033[38;2;%sm%s\033[0m' "$1" "$2"; }

sections=()

# ---- 1. user@host ----
user=$(whoami)
host=$(hostname -s 2>/dev/null)
user_fg="$BLUE"
[ "$user" = "root" ] && user_fg="$RED"
sections+=("$(paint "$user_fg" "$user@$host")")

# ---- 2. directory - full path from ~, no truncation, as starship is configured ----
sections+=("$(paint "$TEAL" "${cwd/#$home/~}")")

# ---- 3. git branch + dirty status - only inside a repo ----
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || \
           git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  dirty=""
  [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ] && dirty=" *"
  sections+=("$(paint "$MAGENTA" " $branch$dirty")")
fi

# ---- 4. language runtime versions - only if a marker file is present ----
# Order matches starship's $rust$golang$nodejs$python; each check is a cheap
# file test (mirrors how starship itself gates these modules) before
# shelling out to the version binary, to keep the status line fast.
lang=""
if [ -f "$cwd/Cargo.toml" ] && command -v rustc >/dev/null 2>&1; then
  v=$(rustc --version 2>/dev/null | awk '{print $2}')
  lang="${lang}🦀 ${v} "
fi
if [ -f "$cwd/go.mod" ] && command -v go >/dev/null 2>&1; then
  v=$(go version 2>/dev/null | awk '{print $3}' | sed 's/^go//')
  lang="${lang}🐹 ${v} "
fi
if [ -f "$cwd/package.json" ] && command -v node >/dev/null 2>&1; then
  v=$(node --version 2>/dev/null | sed 's/^v//')
  lang="${lang}node ${v} "
fi
if { [ -f "$cwd/requirements.txt" ] || [ -f "$cwd/pyproject.toml" ] || [ -f "$cwd/setup.py" ]; } \
   && command -v python3 >/dev/null 2>&1; then
  v=$(python3 --version 2>/dev/null | awk '{print $2}')
  lang="${lang}py ${v} "
fi
[ -n "$lang" ] && sections+=("$(paint "$GREEN" "${lang% }")")

# ---- 5. model name (Claude-only) ----
sections+=("$(paint "$ORANGE" "✦ $model")")

# ---- 6. context / token usage (Claude-only) ----
fmt_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) { printf "%.1fM", n / 1000000 }
    else if (n >= 1000) { printf "%.1fk", n / 1000 }
    else { printf "%d", n }
  }'
}
if [ -n "$used_pct" ] && [ -n "$turn_out" ] && [ -n "$turn_in" ]; then
  token_file="/tmp/claude_tokens_${PPID}"
  acc_out=0
  acc_in=0
  if [ -f "$token_file" ]; then
    acc_out=$(awk 'NR==1 {print $1}' "$token_file"); acc_out=${acc_out:-0}
    acc_in=$(awk 'NR==2 {print $1}' "$token_file");  acc_in=${acc_in:-0}
  fi
  total_out=$(( acc_out + turn_out ))
  total_in=$(( acc_in + turn_in ))
  printf '%s\n%s\n' "$total_out" "$total_in" > "$token_file"

  ctx_int=$(printf '%.0f' "$used_pct")
  sections+=("$(paint "$CYAN" "$(fmt_tokens "$total_out")↓ $(fmt_tokens "$total_in")↑ ${ctx_int}%")")
fi

# ---- 7. time - %R matches starship's time_format ----
sections+=("$(paint "$PURE_GREEN" "$(date +%R)")")

# ---- join: dim separator only between sections that actually rendered ----
sep=$(paint "$COMMENT" " │ ")
line=""
for s in "${sections[@]}"; do
  [ -n "$line" ] && line="${line}${sep}"
  line="${line}${s}"
done
printf '%s\n' "$line"
