#!/usr/bin/bash

cleanup(){
  rm /tmp/btdep-*.log
  exit
}

trap cleanup SIGTERM
trap cleanup SIGINT

# The program has two jobs when it is started. It is determined by the arguments given to the script.
# This is due to the fact that the script calls itself.

# This if statement is for the secondary purpose of a program that parses the defrag log and shows status.
if [[ $1 == "1mrCNiro" ]]
then
  CLINES=0  #logfile line counter
  CFILES=0  #files defragged counter
  CSIZE=0   #size of files defragged
  TFILES=$2 #total files to defrag
  TSIZE=$3  #total size of files
  WINDOW=$4 #name of process/window/logfile
  DIR=$5    #defrag directory
  LOGSIZE=0 #lines in logfile

  clear
  echo -e '\033[1mBTDEP : btrfs defrag progress\033[0m'
  echo "Waiting for btrfs to start the defrag..."

  while true
  do
    if [[ $LOGSIZE != $(du -b /tmp/$WINDOW.log) ]] # Checks if logfile is updated by size (Faster than by number of lines)
    then
      LOGSIZE=$(du -b /tmp/$WINDOW.log)
      TLINES=$(cat /tmp/$WINDOW.log | wc -l)
    fi
    if [[ $TLINES -gt $CLINES ]]
    then
      BUFLEN=$(($TLINES-$CLINES))
      mapfile -t -s $CLINES -n $BUFLEN LINEBUF < /tmp/$WINDOW.log # Gets all new lines into memory
      # Calculates the size of new files and adds it to total
      CSIZE=$(($CSIZE + $(du --block-size=1 -sc ${LINEBUF[@]} 2>&1 | awk '/total/{print $1}' | tail -1 )))

      COUNT=0
      while [[ $TLINES -gt $CLINES ]] # Loop makes sure all lines in the log are files.
      do
        if [[ -f ${LINEBUF[$COUNT]} ]]
        then
          CFILE=${LINEBUF[$COUNT]}
          DOPRINT=1
          CFILES=$(($CFILES+1))

          # Useless debug line but I let it stay since its mostly not visible.
          echo -en "\r$(($TLINES - $CLINES))"
        elif [[ ${LINEBUF[$COUNT]}=="StREciZs" ]] # Checks if defrag done and sets script to exit
        then
          DOPRINT=1
          PRINTKILL=1
        fi
        CLINES=$(($CLINES+1))
        COUNT=$(($COUNT+1))
      done
    fi

    if [[ $DOPRINT == 1 ]] # This prints the status only when required
    then
      DOPRINT=0
      clear
      echo Btrfs Defrag Progress \($CFILES/$TFILES\) \($(numfmt --to=iec $CSIZE)/$TSIZE\)
      echo Current File : "$CFILE" \($(du -sh "$CFILE" | awk '{print $1}')\)

      if [[ $PRINTKILL == 1 ]] # Stores exit dialogue for printing.
      then
        echo "Files Processed : $CFILES" >> /tmp/$WINDOW.log
        echo "Data Processed : $(numfmt --to=iec $CSIZE) ($CSIZE bytes)" >> /tmp/$WINDOW.log
        echo "a4sfLdOf" >> /tmp/$WINDOW.log
        exit
      fi
    fi
    sleep 0.1
  done
else
    displaytime() {
    T=$1
    D=$((T/60/60/24))
    H=$((T/60/60%24))
    M=$((T/60%60))
    S=$((T%60))
    (( $D > 0 )) && printf '%d days ' $D
    (( $H > 0 )) && printf '%d hours ' $H
    (( $M > 0 )) && printf '%d minutes ' $M
    (( $D > 0 || $H > 0 || $M > 0 ))
    printf '%d seconds\n' $S
    }

  for test in "$@"
  do
    if [[ -d $test ]]
    then
      DIR=$test
      break
    fi
  done

  for test in "$@"
  do
    if [[ -d $test ]]
    then
      DIR1=$test
    fi
  done

  if [[ $(which tmux 2>&1 | grep "which: no tmux in") != "" ]] # Checks if tmux exists
  then
    echo -e '\033[1mBTDEP : This wrapper depends on tmux. Please install it to continue\033[0m'
    exit
  elif [[ $DIR == "" ]] # Checks if user has input a valid directory
  then
    echo 1
    echo -e '\033[1mBTDEP : Preliminary directory test failed. Not bothering to continue to multiplexing\033[0m'
    printf "\n \n"
    sudo btrfs filesystem defrag $@ --help
    exit
  elif [[ $DIR != $DIR1 ]] # Checks if user entered multiple directories.
  then
    echo -e '\033[1mBTDEP : You seemed to have entered more than 1 directory. We dont do that here\033[0m'
    exit
  fi

  # Initiates a variable with a random number that will be used for lots of things.
  WINDOW="btdep-$RANDOM"
  :> /tmp/$WINDOW.log

  # Logs start time, number of files and total size.
  STARTTIME=$(date +%s)
  echo "BTDEP : Calculating total files in directory..."
  TFILES=$(find "$DIR" -type f | wc -l)
  echo "BTDEP : Calculating directory size..."
  TSIZE=$(du -sh "$DIR" | awk '{print $1}')
  echo
  echo "BTDEP : All preliminary tests and calculations done. Starting multiplexer in a moment."
  sleep 1

  # Adds quotations to directory parameter so tmux processses it correctly.
  tmuxcmd=${@/$DIR/\""$DIR"\"}

  # Starts the defrag process and second instance of the program
  tmux new -d -s $WINDOW
  tmux split-window -t $WINDOW
  tmux send -t $WINDOW:0.1 "$0 1mrCNiro $TFILES $TSIZE $WINDOW $DIR" ENTER "exit" ENTER
  # stdbuf is used here to constantly buffer the verbose log to file.
  tmux send -t $WINDOW:0.0 "sudo stdbuf -i0 -o0 -e0 btrfs filesystem defrag $tmuxcmd -v | tee -a /tmp/$WINDOW.log" ENTER "echo StREciZs >> /tmp/$WINDOW.log" ENTER "exit" ENTER
  tmux resize-pane -t $WINDOW:0.1 -y 6
  tmux select-pane -t $WINDOW:0.0
  tmux attach -t $WINDOW

  # This loop waits for the program to end and then prints out the end dialogue.
  while true
  do
    if [[ $(tail -1 /tmp/$WINDOW.log) == "a4sfLdOf" ]]
    then
      echo
      echo
      echo -e '\033[1mBTDEP : Process has completed its task.\033[0m'
      tail -3 /tmp/$WINDOW.log | head -2
      echo "Time Taken : $(displaytime $(($(date +%s)-$STARTTIME)))"
      cleanup
    fi
  done
fi

