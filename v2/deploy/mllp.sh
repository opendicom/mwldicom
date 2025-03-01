#!/bin/bash
echo '0:'"$0"
echo '1:'"$1"

exec 3>/dev/tcp/172.16.0.3/2575; cat /Users/Shared/mwldicom/deploy/orm.txt >&3
