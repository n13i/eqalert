#!/bin/sh
SCRIPT_NAME=`readlink -f "$0"`
SCRIPT_PATH=`dirname "${SCRIPT_NAME}"`
EXEC="bin/eqalert_listener.pl"
PIDFILE="$SCRIPT_PATH/.pid"
LOGFILE="$SCRIPT_PATH/log/eqalert.log"

case "$1" in
start)
    echo "Starting $0"
    cd "$SCRIPT_PATH"
    nohup $EXEC 2>&1 1>>"$LOGFILE" &
    echo "$!" > "$PIDFILE"
    ;;
stop)
    echo "Stopping $0"
    kill `cat "$PIDFILE"`
    rm "$PIDFILE"
    ;;
*)
    echo "Usage: $0 {start|stop}"
    ;;
esac

