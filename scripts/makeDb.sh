#!/bin/bash

set -euo pipefail

# Force default language for output sorting to be bytewise. Necessary to ensure uniformity amongst
# UNIX commands.
export LC_ALL=C

HD=$(tput bold)$(tput setaf 5)
HDZ=$(tput sgr0)

WLANG=fr

# By default, the latest Wikipedia dump will be downloaded. If a download date in the format
# YYYYMMDD is provided as the first argument, it will be used instead.
if [[ $# -eq 0 ]]; then
  DOWNLOAD_DATE=$(wget -q -O- https://dumps.wikimedia.org/${WLANG}wiki/ | grep -Po '\d{8}' | sort | tail -n1)
else
  if [ ${#1} -ne 8 ]; then
    echo "[ERROR] Invalid download date provided: $1"
    exit 1
  else
    DOWNLOAD_DATE=$1
  fi
fi

MYSQL_HOST="10.89.1.2"
MYSQL_USER="sdow"
MYSQL_PASSWORD="sdow"
MYSQL_DBNAME="sdow"

SQL_LINES_PER_FILE=10
SQL_SUFFIX_LENGTH=7

ROOT_DIR=`pwd`
OUT_DIR="./$DOWNLOAD_DATE/"

DOWNLOAD_URL="https://dumps.wikimedia.org/${WLANG}wiki/$DOWNLOAD_DATE"
TORRENT_URL="https://tools.wmflabs.org/dump-torrents/${WLANG}wiki/$DOWNLOAD_DATE"


# Make the output directory if it doesn't already exist and move to it
mkdir -p $OUT_DIR
pushd $OUT_DIR > /dev/null


echo "Download date: $DOWNLOAD_DATE"
echo "Download URL: $DOWNLOAD_URL"
echo "Output directory: $OUT_DIR"
echo

function callMysql () {
  mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "--password=$MYSQL_PASSWORD" "$MYSQL_DBNAME" --init-command="SET SESSION wait_timeout=10" $@
}

if callMysql "-e ;"
then echo "Database Connection Working !"
else
  echo "Could not connect to the database :("
  exit 1
fi

##############################
#  DOWNLOAD WIKIPEDIA DUMPS  #
##############################

rm -f "checksum-pipe"
mkfifo "checksum-pipe"
# Downloading checksum file
wget -O checksums.txt -q --show-progress "$DOWNLOAD_URL/${WLANG}wiki-$DOWNLOAD_DATE-sha1sums.txt"
function download_file() {
  if [ -f "$1-downloaded" ]
  then echo "File already downloaded, skipping"
  else
    FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-$1.sql.gz"
    expectedsum=`cat checksums.txt | grep "$FILENAME" | cut -d' ' -f1`
    sum=`(cat "checksum-pipe" | sha1sum | cut -d' ' -f1) & \
    (wget -O - -q --show-progress "$DOWNLOAD_URL/$FILENAME" | tee "checksum-pipe" | gunzip | split - "$1-" --filter='gzip > $FILE.sql.gz' -l$SQL_LINES_PER_FILE -a$SQL_SUFFIX_LENGTH)`
    if [ "$sum" = "$expectedsum" ]
    then echo "Downloaded $1 with checksum $sum"
    else
      echo "Checksum error : $sum != $expectedsum"
      exit 2
    fi
    touch "$1-downloaded"
  fi
  if [ -f "$1-merged" ]
  then echo "Files already merged, skipping"
  else
    echo "Merging the files"
    SQLFILES=`find . -name "$1-*.sql.gz" -type f | sort`
    lastfile=""
    IFS=$'\0'
    echo "$SQLFILES" | while read -r sqlfile
    do
      if [ $(cat $sqlfile | gunzip | head -n1 | grep -c "^INSERT INTO") -eq 1 ]
      then lastfile="$sqlfile"
      else
        if [ ! -z "$lastfile" ]
        then
          echo "Merging $lastfile with $sqlfile"
          cat "$lastfile" "$sqlfile" > tmp.sql.gz
          rm "$lastfile" "$sqlfile"
          mv tmp.sql.gz "$lastfile"
        else
          lastfile="$sqlfile"
        fi
      fi
    done
    touch "$1-merged"
  fi
}

echo "${HD}Downloading linktarget (1/4)${HDZ}"
download_file "linktarget"
echo "${HD}Downloading redirect (2/4)${HDZ}"
download_file "redirect"
echo "${HD}Downloading page (3/4)${HDZ}"
download_file "page"
echo "${HD}Downloading pagelinks (4/4)${HDZ}"
download_file "pagelinks"

rm -f "checksum-pipe"

########################
#  ADDING TO DATABASE  #
########################
echo "${HD}Executing SQL files (5/5)${HDZ}"
SQLFILES=`find . -name "*.sql.gz" -type f | sort`
if [ -z "SQLFILES" ]
then
  echo "No SQL file to process, skipping"
else
  filecount=`echo "$SQLFILES" | wc -l`
  echo "Processing $filecount sql files"

  rm -f sql-progress
  mkfifo sql-progress

  cat sql-progress | pv -ptera -s "$filecount" -i1 -N "SQL files" > /dev/null &

  nosigint=true
  function sigintHandler() {
    echo "${HD}Requesting stop${HDZ}"
    touch stopSQL
  }

  trap 'sigintHandler' INT

  rm -f stopSQL
  IFS=$'\0'
  (
    trap '' INT
    echo "$SQLFILES" | (echo "SET FOREIGN_KEY_CHECKS = 0;"; while [ ! -e stopSQL ] && read -r sqlfile
    do
      echo "$sqlfile" >&2
      cat "$sqlfile" | gunzip
      rm "$sqlfile"
      echo -n "0" >&3
    done 3> sql-progress ) | (setsid -w mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" "--password=$MYSQL_PASSWORD" "$MYSQL_DBNAME")
  ) &
  until wait; do :;done

  rm -f sql-progress

  if [ ! -f stopSQL ]
  then
    echo "SQL files all processed"
  else
    echo "SQL file processing has been canceled"
    exit 1
  fi
fi

## SQL ##
# DELETE FROM pagelinks WHERE pl_from_namespace != 0;



