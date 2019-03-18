#!/bin/bash

read -r -d '' INPUT << "EOM"
@@@@@ TERMINAL=1 POSITION=100,10 SKIP=1 SLEEP_AFTER=0
[alban@neptune gif]$ echo foo@@@@@ PROMPT=1
foo
[alban@neptune gif]$ @@@@@ TERMINAL=2 POSITION=820,10 SKIP=1
./run-magic.pl@@@@@ PROMPT=1 TERMINAL=1 SLEEP_AFTER=50 PROMPT_CHAR=''
line 1   00000000001111111111222222222233333333334444444444555555555566666666667777777777888888888899999999990000000000
[alban@neptune gif]$ ./mfdkjsljflkdsjflkdsjfkldsjfkldsjgkfdjgsjglkfdsjglkfdj@@@@@ PROMPT=1
abcdefghijklmnopqrst
for i in $(seq 6 9) ; do echo "$i     $i     " ; done@@@@@ PROMPT=1 TERMINAL=2 DEFAULT_TERMINAL=2 POSITION=820,10 DEFAULT_POSITION=820,10 SLEEP_AFTER=3000
6     6     
7     7     
8     8     
9     9     
[alban@neptune gif]$ 
[alban@neptune gif]$ ./mfdkjsljflkdsjflkdsjfkldsjfkldsjgkfdjgsjglkfdsjglkfdj@@@@@ TERMINAL=1 DEFAULT_TERMINAL=1 POSITION=10,10 DEFAULT_POSITION=10,10 PROMPT=1
abcdefghijklmnopqrst
[alban@neptune gif]$ ./m@@@@@ PROMPT=1
foo
[alban@neptune gif]$ ./m@@@@@ PROMPT=1
bar
[alban@neptune gif]$ 
EOM

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
  (echo 'text 0,0 "' ; fold --characters < terminal-$TERMINAL.tmp | tail -23 ; echo '    "' ) > terminal-draw-$TERMINAL.tmp
  convert -size 800x435 'xc:#2E3436' -font "FreeMono" -pointsize 17 -fill '#D3D7CF' -draw @terminal-draw-$TERMINAL.tmp frame-${FRAME}.gif

  echo $P > position-$FRAME.tmp
  echo $S > sleep-$FRAME.tmp

  inc_frames
}


DEFAULT_PROMPT=0
DEFAULT_PROMPT_CHAR='$'
DEFAULT_TERMINAL=1
DEFAULT_SLEEP_CHAR=4
DEFAULT_SLEEP_BEFORE=4
DEFAULT_SLEEP_AFTER=4
DEFAULT_POSITION=10,10
DEFAULT_SKIP=0

echo "Computing frames..."
FRAME=000
while IFS= read -r LINE ; do
  PROMPT=$DEFAULT_PROMPT
  PROMPT_CHAR=$DEFAULT_PROMPT_CHAR
  TERMINAL=$DEFAULT_TERMINAL
  SLEEP_CHAR=$DEFAULT_SLEEP_CHAR
  SLEEP_BEFORE=$DEFAULT_SLEEP_BEFORE
  SLEEP_AFTER=$DEFAULT_SLEEP_AFTER
  POSITION=$DEFAULT_POSITION
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
        write_frame "${CHAR}" "$POSITION" "$SLEEP_CHAR"
      else
        CHAR_ACC="${CHAR_ACC}${CHAR}"
        if [ "$CHAR" = "$" ] ; then
          PROMPT_FOUND=1
          write_frame "${CHAR_ACC}" "$POSITION" "$SLEEP_CHAR"
        fi
      fi
    done <<<"$LINE"
    if [ "$PROMPT_FOUND" = 0 ] ; then
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
    write_frame "" "$POSITION" "$SLEEP_AFTER"
  fi
done <<<"$INPUT"

echo
echo "$FRAME frames"
FRAME=$(printf '%03d' "$((10#${FRAME#0}-1))")

gifsicle --colors 256 -m \
		--loopcount=forever \
		-d0 backgroundkinvolk.gif \
		$(for i in `seq -w 000 $FRAME` ; do
			echo "--position $(cat position-$i.tmp) -d$(cat sleep-$i.tmp) frame-$i.gif"
		done) \
		--optimize > output.gif

rm -f frame-*.gif terminal-*.tmp position-*.tmp sleep-*.tmp
