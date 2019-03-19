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
  FRAME=$(printf '%03d' "$((10#${FRAME}+1))")
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
  convert -size 800x435 'xc:#2E3436' -font "FreeMono" -pointsize 17 -fill '#D3D7CF' -draw @terminal-draw-$TERMINAL.tmp frame-${FRAME}.gif

  echo $P > position-$FRAME.tmp
  echo $S > sleep-$FRAME.tmp

  inc_frames
}


DEFAULT_PROMPT=0
DEFAULT_PROMPT_CHAR='$'
DEFAULT_TERMINAL=1
DEFAULT_SLEEP_CHAR=8
DEFAULT_SLEEP_BEFORE=4
DEFAULT_SLEEP_AFTER=4
DEFAULT_SKIP=0

declare -A POSITION

echo "Computing frames..."
FRAME=000
while IFS= read -r LINE ; do
  PROMPT=$DEFAULT_PROMPT
  PROMPT_CHAR=$DEFAULT_PROMPT_CHAR
  TERMINAL=$DEFAULT_TERMINAL
  SLEEP_CHAR=$DEFAULT_SLEEP_CHAR
  SLEEP_BEFORE=$DEFAULT_SLEEP_BEFORE
  SLEEP_AFTER=$DEFAULT_SLEEP_AFTER
  SKIP=$DEFAULT_SKIP

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
        if [ "$CHAR" = $'\n' -a "$SKIP" = 1 ] ; then
          continue
        fi
        write_frame "${CHAR}" "${POSITION[$TERMINAL]}" "$SLEEP_CHAR"
      else
        CHAR_ACC="${CHAR_ACC}${CHAR}"
        if [ "$CHAR" = "$" ] ; then
          PROMPT_FOUND=1
          write_frame "${CHAR_ACC}" "${POSITION[$TERMINAL]}" "$SLEEP_CHAR"
        fi
      fi
    done <<<"$LINE"
    if [ "$PROMPT_FOUND" = 0 ] ; then
      echo "Prompt not found"
      echo "Line was: $LINE"
      echo "Chars were: $CHAR_ACC"
    fi
  else
    echo -n "${LINE}" | sed 's/\\/\\\\/g ; s/"/\\"/g' >> terminal-$TERMINAL.tmp
    if [ "$SKIP" = 0 ] ; then
      echo >> terminal-$TERMINAL.tmp
    fi
  fi

  if [ "$PROMPT" = 0 -o "$SKIP" = 0 ] ; then
    write_frame "" "${POSITION[$TERMINAL]}" "$SLEEP_AFTER"
  fi
done < $FILESRC

echo
echo "$FRAME frames"
FRAME=$(printf '%03d' "$((10#${FRAME#0}-1))")

gifsicle --colors 256 -m \
		--loopcount=forever \
		-d0 backgroundkinvolk.gif \
		$(for i in `seq -w 000 $FRAME` ; do
			echo "--position $(cat position-$i.tmp) -d$(cat sleep-$i.tmp) frame-$i.gif"
		done) \
		--optimize > $FILEDST

rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp
