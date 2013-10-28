#!/bin/sh

read cvmPid < /var/run/cvm.pid

caption=

if [[ -z "$cvmPid" ]]; then
  echo "cvm isn't running..."
  exit 2
fi

if [[ ! -e "/var/run/progRem.pid" ]]; then
  echo "Hack to enhance progress bar starting up" | /mnt/us/progRem/fbout
  echo $$ > "/var/run/progRem.pid"
else
  exit 1
fi

clean_up() {
  echo "Hack to enhance progress bar shut down" | /mnt/us/progRem/fbout
  rm /var/run/progRem.pid
  exit
}

trap clean_up SIGINT SIGTERM

# Print white space over progress bar
eraseProgress() {
  waitForEink
  
  eips -n 8 38 "$caption"
}

## Check if we need to look for a book/check if current book is open
bookCheck() {
  ## Check if cvm has a open file descriptor for a file in /mnt/us/documents/
  if [[ -n "$fd" -a -n "$book" ]]; then
    if [[ "$(realpath /proc/$cvmPid/fd/$fd 2> /dev/null)" == "$book" ]]; then
      if [[ "$bookType" != "BAD" ]]; then
        eraseProgress
      fi
    else
      book=""
      bookType=""
      findBook
    fi
  else
    findBook
  fi
}

## Check if cvm has a file descriptor open in /mnt/us/documents
findBook() {
  fd="$(ls -l /proc/$cvmPid/fd/ | awk '/\/mnt\/us\/documents\// {print $9}')"
  if [[ -n "$fd" ]]; then
    book="$(realpath /proc/$cvmPid/fd/$fd 2> /dev/null)"
    bookType="${book##*.}"
    case $bookType in
      [Mm][Oo][Bb][Ii]|[Pp][Dd][Ff]|[Pp][Rr][Cc]|[Aa][Zz][Ww]*|[Tt][Xx][Tt])
        eraseProgress
      ;;
      *)
        bookType="BAD"
      ;;
    esac
  fi
}

## Check if /var/log/messages has changed within the last second
waitForEink() {
  c=1
  while [[ "$(stat -c %Y /var/log/messages)" -lt "$time" -a "$c" -lt "10" ]]; do
    let c+=1
    usleep 100000
  done
}

## Wait for page turn
while :; do
  keypressed="$(waitforkey)"
  case "$keypressed" in 
    193*|109*)
      # back
      time="$(($(date +%s)-1))"
      bookCheck
    ;;
    191*|104*)
      time="$(($(date +%s)-1))"
      bookCheck
      # forward

      tstamps="$(date +%s) $tstamps"
      new_tstamps=""
      i=0
      avg=0
      for ts in $tstamps; do
        if test $i -ne 0; then
          avg=$(( $avg - $ts + $prev ))
        fi
        prev=$ts
        # roll values
        new_tstamps="$new_tstamps$ts "
        i=$(( $i+1 ))
        if test $i -ge 5 ; then break; fi
      done
      tstamps=$new_tstamps
      if test $i -ne 0; then
        caption="est: $(( ${avg}/${i} / 6 ))min/10pages"
      fi
    ;;
  esac
done
