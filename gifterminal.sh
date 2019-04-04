#!/bin/bash

FILESRC=$1
FILEDST=$2
if [ ! -r "$FILESRC" ] ; then
  echo "cannot read file"
  exit 1
fi
if [ -z "$FILEDST" ] ; then
  echo "must specify output file"
  exit 1
fi

rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp

inc_frames () {
  FRAME=$(printf '%05d' "$((10#${FRAME}+1))")
  if [ $((10#${FRAME#0} % 5)) = "0" ] ; then
    echo -n '.'
  fi
}

write_frame () {
  C="$1"
  P="$2"
  S="$3"

  echo -n "${C}" | sed 's/\\/\\\\/g ; s/"/\\"/g' >> terminal-$TERMINAL.tmp
  (echo 'text 0,0 "' ; fold --characters < terminal-$TERMINAL.tmp | tail -23 ; echo '█    "' ) > terminal-draw-$TERMINAL.tmp
  cp terminal-draw-$TERMINAL.tmp terminal-draw-$TERMINAL-$FRAME.tmp
  convert -size 800x435 'xc:#2E3436' -font "FreeMono" -pointsize 17 -fill '#D3D7CF' -draw @terminal-draw-$TERMINAL-$FRAME.tmp frame-${FRAME}.gif &

  echo $P > position-$FRAME.tmp
  echo $S > sleep-$FRAME.tmp

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

declare -A POSITION

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

  if [[ "$LINE" =~ $PROMPT_REGEXP ]] ; then
    PROMPT=1
  fi

  if [[ "$LINE" =~ @@@@@ ]] ; then
    PARAMS=$(gawk --field-separator='@@@@@' '{print $2}' <<<"$LINE")
    LINE=$(gawk --field-separator='@@@@@' '{print $1}' <<<"$LINE")
    eval $PARAMS
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
		-d0 backgroundkinvolk.gif \
		$(for i in `seq -w 00000 $FRAME` ; do
			echo "--position $(cat position-$i.tmp) -d$(cat sleep-$i.tmp) frame-$i.gif"
		done) \
		--optimize > $FILEDST

rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp
