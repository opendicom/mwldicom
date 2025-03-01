#!/bin/bash

while true
do
sleep 30;
ECHO=`/usr/bin/curl --silent http://localhost:11115/echo`;
if [ "$ECHO" == "echo" ]
then
printf '.';
else
DATE=`date +%Y-%m-%d:%H:%M:%S`;
printf "\r\n$DATE [ERROR] no echo from 11115\r\n";
killall -c mwldicom;
sleep 3;
/Users/Shared/mwldicom/bin/mwldicomexport /Users/Shared/mwldicom/deploy/ 11115 INFO -0400 1.3.6.1.4.1.23650.152.0.2.738280.1&

ECHO=`/usr/bin/curl --silent http://localhost:11115/echo`;
if [ "$ECHO" == "echo" ]
then
printf "successfully restarted\r\n";
else
printf "could not restart\r\n";
fi
fi
done

