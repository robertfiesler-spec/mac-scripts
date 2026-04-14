#!/bin/zsh
# ============================================
# ascii.sh
# ASCII Art Generator — turns any text into
# big, bold ASCII block letters in your terminal
# Author: Rob Fiesler | BiXBiT USA
# Usage:  ./ascii.sh "your text"
#         ./ascii.sh "your text" slant
#         ./ascii.sh --fonts   (to see all fonts)
# ============================================

# --- Colors ---
# Pick a random color each time for fun variety
# We store all options in an array, then pick one randomly
COLORS=(
  "\033[1;31m"   # bold red
  "\033[1;32m"   # bold green
  "\033[1;33m"   # bold yellow
  "\033[1;34m"   # bold blue
  "\033[1;35m"   # bold magenta
  "\033[1;36m"   # bold cyan
)
RESET="\033[0m"

# $RANDOM is a built-in zsh variable that gives a random number 0–32767
# We use % (modulo) to keep it within the size of our array
COLOR=${COLORS[$(( (RANDOM % ${#COLORS[@]}) + 1 ))]}

# --- Show available fonts ---
# If the user runs ./ascii.sh --fonts, list all available pyfiglet fonts
if [[ "$1" == "--fonts" ]]; then
  printf "\nAvailable fonts:\n\n"
  python3 -c "
import pyfiglet
fonts = pyfiglet.FigletFont.getFonts()
for f in sorted(fonts):
    print('  ' + f)
"
  printf "\nUsage: ./ascii.sh \"your text\" fontname\n\n"
  exit 0
fi

# --- Check for input ---
# $# is the number of arguments passed to the script
# $1 is the first argument (the text), $2 is optional (the font)
if [[ $# -eq 0 ]]; then
  echo "\nUsage: ./ascii.sh \"your text\""
  echo "       ./ascii.sh \"your text\" slant"
  echo "       ./ascii.sh --fonts   (see all fonts)\n"
  exit 1
fi

TEXT="$1"

# --- Pick the font ---
# If no font was given, default to "big" which is bold and readable
# Common fun fonts: big, slant, banner3, doom, larry3d, epic, nancyj
FONT="${2:-big}"

# --- Generate and display the ASCII art ---
# We pass the text and font into Python, which uses pyfiglet to render it
# pyfiglet is a Python port of the classic FIGlet tool
printf "\n${COLOR}"

python3 -c "
import pyfiglet, sys
text = sys.argv[1]
font = sys.argv[2]
try:
    result = pyfiglet.figlet_format(text, font=font)
    print(result)
except pyfiglet.FontNotFound:
    print(f\"Font '{font}' not found. Run ./ascii.sh --fonts to see all options.\")
    sys.exit(1)
" "$TEXT" "$FONT"

printf "${RESET}"
