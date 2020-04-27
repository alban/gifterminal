#!/bin/bash

FILESRC=$(readlink -f "$1")
FILEDST=$(readlink -f "$2")
BACKGROUND="${BACKGROUND-backgroundkinvolk-white.gif}"

if [ ! -r "$BACKGROUND" ] ; then
  BACKGROUND="`dirname $0`/$BACKGROUND"
fi
BACKGROUND=$(readlink -f "$BACKGROUND")

# 23 or 11
TERM_HEIGHT="${TERM_HEIGHT-23}"
# 800x435 or 800x216
TERM_SIZE_PIXEL="${TERM_SIZE_PIXEL-800x435}"
DEFAULT_TERMINAL_COLOR_BACKGROUND="${DEFAULT_TERMINAL_COLOR_BACKGROUND-1E2426}"
DEFAULT_TERMINAL_COLOR_FONT="${DEFAULT_TERMINAL_COLOR_FONT-E3E7DF}"

if [ ! -r "$FILESRC" ] ; then
  echo "cannot read file"
  exit 1
fi
if [ -z "$FILEDST" ] ; then
  echo "must specify output file"
  exit 1
fi

cd /tmp
rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp

declare -A POSITION_ARR
declare -A SLEEP_ARR

inc_frames () {
  FRAME=$(printf '%05d' "$((10#${FRAME}+1))")
  if [ $((10#${FRAME#0} % 5)) = "0" ] ; then
    echo -n '.'
  fi
}

write_frame () {
  FRAME_CHARACTERS="$1"
  FRAME_POSITION="$2"
  FRAME_SLEEP="$3"

  echo -n "${FRAME_CHARACTERS}" | sed 's/\\/\\\\/g ; s/"/\\"/g' >> terminal-$TERMINAL.tmp
  (echo 'text 0,0 "' ; fold --characters < terminal-$TERMINAL.tmp | tail -${TERMINAL_HEIGHT[$TERMINAL]-$TERM_HEIGHT} ; \
      if [[ "${TERMINAL_HIDE_CURSOR[$TERMINAL]}" = "1" ]] ; then
        echo '    "'
      else
        echo '█    "'
      fi
  ) > terminal-draw-$TERMINAL.tmp
  cp terminal-draw-$TERMINAL.tmp terminal-draw-$TERMINAL-$FRAME.tmp
  convert -size "${TERMINAL_SIZE_PIXEL[$TERMINAL]-$TERM_SIZE_PIXEL}" \
    "xc:#${TERMINAL_COLOR_BACKGROUND[$TERMINAL]-$DEFAULT_TERMINAL_COLOR_BACKGROUND}" \
    -font "$FONT" \
    -pointsize 17 \
    -fill "#${TERMINAL_COLOR_FONT[$TERMINAL]-$DEFAULT_TERMINAL_COLOR_FONT}" \
    -draw @terminal-draw-$TERMINAL-$FRAME.tmp \
    frame-${FRAME}.gif &

  POSITION_ARR[$FRAME]="$FRAME_POSITION"
  SLEEP_ARR[$FRAME]="$FRAME_SLEEP"

  if [ $((10#${FRAME#0} % 32)) = "0" ] ; then
    wait
  fi

  inc_frames
}


DEFAULT_PROMPT=0
DEFAULT_PROMPT_CHAR='$ '
DEFAULT_PROMPT_REGEXP='\]\$\ '
DEFAULT_TERMINAL=1
DEFAULT_SLEEP_PROMPT=100      # After printing the prompt
DEFAULT_SLEEP_PROMPT_EOL=100  # After printing the prompt
DEFAULT_SLEEP_PROMPT_NL=10    # After printing the new line after the command
DEFAULT_SLEEP_CHAR=8          # After printing each char of the command
DEFAULT_SLEEP_EOL=4           # End of line, before the new line character
DEFAULT_SLEEP_NL=4            # After the new line character
DEFAULT_SKIP=0
DEFAULT_RESET_TERMINAL=""
DEFAULT_FONT="FreeMono"

# arrays for each terminal
declare -A POSITION
declare -A TERMINAL_SIZE_PIXEL
declare -A TERMINAL_HEIGHT
declare -A TERMINAL_COLOR_FONT
declare -A TERMINAL_COLOR_BACKGROUND
declare -A TERMINAL_HIDE_CURSOR

echo "Computing frames..."
FRAME=00000
while IFS= read -r LINE ; do
  PROMPT="$DEFAULT_PROMPT"
  PROMPT_CHAR="$DEFAULT_PROMPT_CHAR"
  PROMPT_REGEXP="$DEFAULT_PROMPT_REGEXP"
  TERMINAL="$DEFAULT_TERMINAL"
  SLEEP_PROMPT=$DEFAULT_SLEEP_PROMPT
  SLEEP_PROMPT_EOL=$DEFAULT_SLEEP_PROMPT_EOL
  SLEEP_PROMPT_NL=$DEFAULT_SLEEP_PROMPT_NL
  SLEEP_CHAR=$DEFAULT_SLEEP_CHAR
  SLEEP_EOL=$DEFAULT_SLEEP_EOL
  SLEEP_NL=$DEFAULT_SLEEP_NL
  SKIP=$DEFAULT_SKIP
  FONT="$DEFAULT_FONT"
  RESET_TERMINAL="$DEFAULT_RESET_TERMINAL"

  if [[ "$LINE" =~ $PROMPT_REGEXP ]] ; then
    PROMPT=1
  fi

  if [[ "$LINE" =~ @@@@@ ]] ; then
    PARAMS=$(gawk --field-separator='@@@@@' '{print $2}' <<<"$LINE")
    LINE=$(gawk --field-separator='@@@@@' '{print $1}' <<<"$LINE")
    eval $PARAMS
  fi
  if [[ "$RESET_TERMINAL" = "$TERMINAL" ]] ; then
    rm -f terminal-$TERMINAL.tmp
  fi
  touch terminal-$TERMINAL.tmp

  if [ "$PROMPT" = 1 ] ; then
    CHAR_ACC=""
    PROMPT_FOUND=0
    if [ "$PROMPT_CHAR" = "" ] ; then
      PROMPT_FOUND=1
    fi
    while IFS= read -r -N 1 CHAR ; do
      if [ "$PROMPT_FOUND" = 1 ] ; then
        if [ "x$CHAR" = "x"$'\n' -a "$SKIP" = 1 ] ; then
          continue
        fi
        if [ "x$CHAR" = "x"$'\n' ] ; then
          write_frame "" "${POSITION[$TERMINAL]}" "$SLEEP_PROMPT_EOL"
          write_frame "${CHAR}" "${POSITION[$TERMINAL]}" "$SLEEP_PROMPT_NL"
        else
          write_frame "${CHAR}" "${POSITION[$TERMINAL]}" "$SLEEP_CHAR"
        fi
      else
        CHAR_ACC="${CHAR_ACC}${CHAR}"
        if [ "${CHAR_ACC: -${#PROMPT_CHAR}}" = "$PROMPT_CHAR" ] ; then
          PROMPT_FOUND=1
          write_frame "${CHAR_ACC}" "${POSITION[$TERMINAL]}" "$SLEEP_PROMPT"
        fi
      fi
    done <<<"$LINE"
    if [ "$PROMPT_FOUND" = 0 ] ; then
      echo "Prompt not found"
      echo "Line was: $LINE"
      echo "Chars were: $CHAR_ACC"
    fi
  else
    write_frame "$LINE" "${POSITION[$TERMINAL]}" "$SLEEP_EOL"
    if [ "$SKIP" = 0 ] ; then
      NL=$'\n'
      write_frame "$NL" "${POSITION[$TERMINAL]}" "$SLEEP_NL"
    fi
  fi
done < $FILESRC

wait

echo
echo "$FRAME frames"
FRAME=$(printf '%05d' "$((10#${FRAME#0}-1))")

gifsicle --colors 256 -m \
		--loopcount=forever \
		-d0 "$BACKGROUND" \
		$(for i in `seq -w 00000 $FRAME` ; do
			echo "--position ${POSITION_ARR[$i]} -d${SLEEP_ARR[$i]} frame-$i.gif"
		done) \
		--optimize > $FILEDST

rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp
