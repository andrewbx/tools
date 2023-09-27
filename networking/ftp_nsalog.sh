#!/bin/sh
########################################################################
# Extract FTP Transactions from Database.
# Produce Monthly Output.
########################################################################

PG_DUMP="/usr/syno/pgsql/bin/pg_dump"
PG_CMD="$PG_DUMP -a synolog -U admin -t xxxxxx"
PG_DEST="/volume1/nsaftp/ftplog"

CURR_MONTH=`date +"%b"`
CURR_YEAR=`date +"%Y"`

LOGFILE="ftp_activity_$CURR_MONTH-$CURR_YEAR.log"

rm $PG_DEST/$LOGFILE

$PG_CMD | grep nsaftp | while read a b c d e f

do
  if [ "$c" != "${c/nsaftp/}" ]; then
    realtime=`perl -e "print scalar(localtime($a))"`
    if [ "$realtime" != "${realtime/$CURR_MONTH/}" ] && [ "$realtime" != "${realtime/$CURR_YEAR/}" ]; then
       echo -e $realtime\\t$b\\t$c\\t$d\\t$e\\t$f >> $PG_DEST/$LOGFILE
    fi
  fi
done

#-EOF
