#!/bin/bash

#RADIOIMAGENexport.sh dir ...
printf '\n  -----------'"$(date '+%Y%m%d %T')"'------------'
today=$(date '+%Y%m%d')
for reading in "$@"; do
  dir="/Users/Shared/RADIOIMAGENexport/$today/$reading"
  if [ ! -f "$dir" ]
  then
     mkdir -p "$dir"
  fi
  cd "$dir"
  for dst in $( ls -1 ); do
    if [ -f "$dst/$dst.done" ]
    then
       echo "√ $reading/$dst"
    elif [ -f "$dst/$dst" ]
    then
       echo "· $reading/$dst"
       /usr/local/bin/storescu  -ll warn 164.77.96.138 104 +sd +r +sp '*[0-9]' +rn -R +C -xe -aec RADIOIMAGEN "$dst"
    else
       echo "? $reading/$dst"
    fi
    
    
    for src in $( find /Volumes/IN/TEST/CLASSIFIED -maxdepth 2 -mindepth 2 -type d -name "*$dst*" ); do
       dicm=$(find  $src -maxdepth 2 -mindepth 2 -type f | wc -l | awk '{print $1}')
       sent=$(find  $src -maxdepth 2 -mindepth 2 -type f -name "*.done" | wc -l | awk '{print $1}')
       fail=$(find  $src -maxdepth 2 -mindepth 2 -type f -name "*.bad" | wc -l | awk '{print $1}')
       left="$(( dicm - sent - fail ))"
       if [[ "$left" = 0 ]]
       then
            echo "√ ($dicm-$sent-$fail) $src"
       else
            echo "$left ($dicm-$sent-$fail) $src"
            /usr/local/bin/storescu  -ll warn 164.77.96.138 104 +sd +r +sp '*[0-9]' +rn -R +C -xe -aec RADIOIMAGEN "$src"
       fi
    done
  done
done

