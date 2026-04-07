#!/bin/zsh
# ============================================
# quote.sh
# Quote of the Day — pulls a fresh quote from
# the ZenQuotes API and displays it beautifully.
# Also throws up a random ASCII art banner each
# morning for a little extra energy.
# Author: Rob Fiesler | BiXBiT USA
# Usage: ./quote.sh
# ============================================

# --- Colors ---
# ANSI escape codes tell your terminal to change text color.
# \033[1;36m = bold cyan | \033[1;33m = bold yellow | \033[0m = reset to normal
# We use printf instead of echo so the color codes actually render.
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# --- Random ASCII Art Banner ---
# Every morning gets a different word + font + color combo.
# We build arrays for each, pick a random index, and let pyfiglet render it.

# Words to randomly cycle through — motivational, short, punchy
ASCII_WORDS=("RISE" "GRIND" "WIN" "FOCUS" "HUSTLE" "EXECUTE" "MOVE" "BUILT" "BIG DAY" "LOCK IN" "LETS GO" "DOMINATE")

# A curated set of fonts that look great in a terminal
# (These are all built into pyfiglet — no extra installs needed)
ASCII_FONTS=("big" "slant" "doom" "epic" "banner3" "graffiti" "speed" "block" "colossal" "larry3d" "lean" "standard")

# All the bold color options
COLORS=(
  "\033[1;31m"   # bold red
  "\033[1;32m"   # bold green
  "\033[1;33m"   # bold yellow
  "\033[1;34m"   # bold blue
  "\033[1;35m"   # bold magenta
  "\033[1;36m"   # bold cyan
)

# $RANDOM is a zsh built-in: a random number 0–32767 each time you read it.
# % (modulo) keeps the number within our array bounds.
# +1 because zsh arrays are 1-indexed (unlike Python/JS which start at 0).
RAND_WORD=${ASCII_WORDS[$(( (RANDOM % ${#ASCII_WORDS[@]}) + 1 ))]}
RAND_FONT=${ASCII_FONTS[$(( (RANDOM % ${#ASCII_FONTS[@]}) + 1 ))]}
ART_COLOR=${COLORS[$(( (RANDOM % ${#COLORS[@]}) + 1 ))]}

# Print the ASCII art in the random color
# We silently swallow any font errors — if something goes wrong, just skip it
printf "\n${ART_COLOR}"
python3 -c "
import pyfiglet, sys
try:
    result = pyfiglet.figlet_format(sys.argv[1], font=sys.argv[2])
    print(result)
except Exception:
    pass  # if the font fails for any reason, just print nothing
" "$RAND_WORD" "$RAND_FONT"
printf "${RESET}"

# --- Fetch the quote ---
# curl -s = silent mode (no progress bar clutter)
# ZenQuotes is free, no API key needed
# It returns JSON like: [{"q":"The quote text","a":"Author Name"}]
RAW=$(curl -s --max-time 5 "https://zenquotes.io/api/random")

# --- Check we actually got something ---
if [[ -z "$RAW" ]]; then
  printf "\n${CYAN}========================================${RESET}\n"
  printf "${CYAN}  💬 QUOTE OF THE DAY${RESET}\n"
  printf "${CYAN}========================================${RESET}\n\n"
  printf "  Could not reach ZenQuotes. Check your connection.\n\n"
  printf "${CYAN}========================================${RESET}\n\n"
  exit 1
fi

# --- Parse the JSON with Python ---
# We pipe the raw JSON into a tiny Python script.
# Python's json library reads it and we grab:
#   data[0]['q']  →  the quote text
#   data[0]['a']  →  the author name
# We join them with || so we can split them back apart in zsh.
QUOTE=$(echo "$RAW" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    q = data[0]['q']
    a = data[0]['a']
    print(q + '||' + a)
except Exception as e:
    print('Could not parse response.||Unknown')
")

# --- Split quote and author apart ---
# zsh string slicing tricks:
# ${VAR%%||*}  →  everything BEFORE the first ||
# ${VAR##*||}  →  everything AFTER the last ||
TEXT="${QUOTE%%||*}"
AUTHOR="${QUOTE##*||}"

# --- Display it ---
printf "\n${CYAN}========================================${RESET}\n"
printf "${CYAN}  💬 QUOTE OF THE DAY${RESET}\n"
printf "${CYAN}========================================${RESET}\n\n"

# fold -s -w 50 wraps long lines at 50 characters without cutting words mid-word
echo "$TEXT" | fold -s -w 50 | while IFS= read -r line; do
  printf "  %s\n" "$line"
done

printf "\n  ${YELLOW}— ${AUTHOR}${RESET}\n"
printf "\n${CYAN}========================================${RESET}\n\n"
