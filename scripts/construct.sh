#!/bin/bash

set -euo pipefail

# Force default language for output sorting to be bytewise. Necessary to ensure uniformity amongst
# UNIX commands.
export LC_ALL=C

HD=$(tput bold)$(tput setaf 5)
HDZ=$(tput sgr0)

TOT=19

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

ROOT_DIR=`pwd`
OUT_DIR="dump"

DOWNLOAD_URL="https://dumps.wikimedia.org/${WLANG}wiki/$DOWNLOAD_DATE"
TORRENT_URL="https://tools.wmflabs.org/dump-torrents/${WLANG}wiki/$DOWNLOAD_DATE"

SHA1SUM_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-sha1sums.txt"
REDIRECTS_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-redirect.sql.gz"
PAGES_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-page.sql.gz"
LINKS_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-pagelinks.sql.gz"
LINKTARGET_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-linktarget.sql.gz"


# Make the output directory if it doesn't already exist and move to it
mkdir -p $OUT_DIR
pushd $OUT_DIR > /dev/null


echo "Download date: $DOWNLOAD_DATE"
echo "Download URL: $DOWNLOAD_URL"
echo "Output directory: $OUT_DIR"
echo

##############################
#  DOWNLOAD WIKIPEDIA DUMPS  #
##############################

function download_file() {
  if [ ! -f $2 ]; then
    echo
    if [ $1 != sha1sums ] && command -v aria2c > /dev/null; then
      echo "$HD[$3/$TOT]$HDZ Downloading $1 file via torrent"
      time aria2c --summary-interval=0 --console-log-level=warn --seed-time=0 \
        "$TORRENT_URL/$2.torrent"
    else  
      echo "$HD[$3/$TOT]$HDZ Downloading $1 file via wget"
      time wget --progress=dot:giga "$DOWNLOAD_URL/$2"
    fi

    if [ $1 != sha1sums ]; then
      echo
      echo "Verifying SHA-1 hash for $1 file"
      time grep "$2" "$SHA1SUM_FILENAME" | sha1sum -c
      if [ $? -ne 0 ]; then
        echo
        echo "$HD[ERROR]$HDZ Downloaded $1 file has incorrect SHA-1 hash"
        rm $2
        exit 1
      fi
    fi
  else
    echo "$HD[$3/$TOT]$HDZ Already downloaded $1 file"
  fi
}

download_file "sha1sums" $SHA1SUM_FILENAME 1
download_file "redirects" $REDIRECTS_FILENAME 2
download_file "pages" $PAGES_FILENAME 3
download_file "links" $LINKS_FILENAME 4
download_file "linktarget" $LINKTARGET_FILENAME 5

##########################
#  TRIM WIKIPEDIA DUMPS  #
##########################
if [ ! -f redirects.txt.gz ]; then
  echo
  echo "$HD[5/$TOT]$HDZ Trimming redirects file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
    pv $REDIRECTS_FILENAME \
      | gunzip \
      | sed -n 's/^INSERT INTO `redirect` VALUES (//p' \
      | sed -e 's/),(/\'$'\n/g' \
      | egrep "^[0-9]+,0," \
      | sed -e $"s/,0,'/\t/g" \
      | sed -e "s/','.*//g" \
      | gzip --fast > redirects.txt.gz.tmp
  mv redirects.txt.gz.tmp redirects.txt.gz
else
  echo "$HD[5/$TOT]$HDZ Already trimmed redirects file"
fi

if [ ! -f pages.txt.gz ]; then
  echo
  echo "$HD[6/$TOT]$HDZ Trimming pages file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Splice out the page title and whether or not the page is a redirect
  # Zip into output file
  pv $PAGES_FILENAME \
    | gunzip \
    | sed -n 's/^INSERT INTO `page` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0," \
    | sed -e $"s/,0,'/\t/" \
    | sed -e $"s/',[^,]*,\([01]\).*/\t\1/" \
    | gzip --fast > pages.txt.gz.tmp
  mv pages.txt.gz.tmp pages.txt.gz
else
  echo "$HD[6/$TOT]$HDZ Already trimmed pages file"
fi

if [ ! -f links.txt.gz ]; then
  echo
  echo "$HD[7/$TOT]$HDZ Trimming links file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
  pv $LINKS_FILENAME \
    | gunzip \
    | sed -n 's/^INSERT INTO `pagelinks` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0,[0-9]+$" \
    | sed -e $"s/,0,/\t/g" \
    | gzip --fast > links.txt.gz.tmp

  mv links.txt.gz.tmp links.txt.gz
else
  echo "$HD[7/$TOT]$HDZ Already trimmed links file"
fi

if [ ! -f links.txt.gz ]; then
  echo
  echo "$HD[8/$TOT]$HDZ Trimming linktarget file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
  pv $LINKS_FILENAME \
    | gunzip \
    | sed -n 's/^INSERT INTO `pagelinks` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0,[0-9]+$" \
    | sed -e $"s/,0,/\t/g" \
    | gzip --fast > links.txt.gz.tmp

  mv links.txt.gz.tmp links.txt.gz
else
  echo "$HD[8/$TOT]$HDZ Already trimmed links file"
fi

if [ ! -f linktargets.txt.gz ]; then
  echo
  echo "$HD[7/$TOT]$HDZ Trimming linktarget file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Zip into output file
  pv $LINKTARGET_FILENAME \
    | gunzip \
    | sed -n 's/^INSERT INTO `linktarget` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep ",0," \
    | sed -e $"s/,0,/\t/g" \
    | gzip --fast > linktargets.txt.gz.tmp

  mv linktargets.txt.gz.tmp linktargets.txt.gz
else
  echo "$HD[7/$TOT]$HDZ Already trimmed linktarget file"
fi

pv links.txt.gz | gunzip | sqlite3 sdow.sqlite ".read ../links.sql"
pv linktargets.txt.gz | gunzip | sqlite3 sdow.sqlite ".read ../linktarget.sql"
pv page.txt.gz | gunzip | sqlite3 sdow.sqlite ".read ../page.sql"
pv redirect.txt.gz | gunzip | sqlite3 sdow.sqlite ".read ../redirect.sql"


exit

# Creating the named pipes for python programs
rm -f pipe1 pipe2 pipe3
mkfifo pipe1
mkfifo pipe2
mkfifo pipe3

###########################################
#  REPLACE TITLES AND REDIRECTS IN FILES  #
###########################################
if [ ! -f redirects.with_ids.txt.gz ]; then
  echo
  echo "$HD[8/$TOT]$HDZ Replacing titles in redirects file"
    (pv pages.txt.gz | gunzip > pipe1 ; pv redirects.txt.gz | gunzip > pipe2) \
    | python "$ROOT_DIR/replace_titles_in_redirects_file.py" pipe1 pipe2 \
    | sort -S 100% -t $'\t' -k 1n,1n \
    | gzip --fast > redirects.with_ids.txt.gz.tmp
  mv redirects.with_ids.txt.gz.tmp redirects.with_ids.txt.gz
else
  echo "$HD[8/$TOT]$HDZ Already replaced titles in redirects file"
fi

if [ ! -f links.with_ids.txt.gz ]; then
  echo
  echo "$HD[9/$TOT]$HDZ Replacing titles and redirects in links file"
  (pv pages.txt.gz | gunzip > pipe1 ; pv redirects.with_ids.txt.gz | gunzip > pipe2; pv links.txt.gz | gunzip > pipe3) \
    | python "$ROOT_DIR/replace_titles_and_redirects_in_links_file.py" pipe1 pipe2 pipe3 \
    | gzip --fast > links.with_ids.txt.gz.tmp
  mv links.with_ids.txt.gz.tmp links.with_ids.txt.gz
else
  echo "$HD[9/$TOT]$HDZ Already replaced titles and redirects in links file"
fi

if [ ! -f pages.pruned.txt.gz ]; then
  echo
  echo "$HD[10/$TOT]$HDZ Pruning pages which are marked as redirects but with no redirect"
  (pv redirects.with_ids.txt.gz | gunzip > pipe1 ; pv pages.txt.gz | gunzip > pipe2) \
    | python "$ROOT_DIR/prune_pages_file.py" pipe1 pipe2 \
    | gzip --fast > pages.pruned.txt.gz
else
  echo "$HD[10/$TOT]$HDZ Already pruned pages which are marked as redirects but with no redirect"
fi

#####################
#  SORT LINKS FILE  #
#####################
if [ ! -f links.sorted_by_source_id.txt.gz ]; then
  echo
  echo "$HD[11/$TOT]$HDZ Sorting links file by source page ID"
  pv links.with_ids.txt.gz \
    | gunzip \
    | sort -S 80% -t $'\t' -k 1n,1n \
    | uniq \
    | gzip --fast > links.sorted_by_source_id.txt.gz.tmp
  mv links.sorted_by_source_id.txt.gz.tmp links.sorted_by_source_id.txt.gz
else
  echo "$HD[11/$TOT]$HDZ Already sorted links file by source page ID"
fi

if [ ! -f links.sorted_by_target_id.txt.gz ]; then
  echo
  echo "$HD[12/$TOT]$HDZ Sorting links file by target page ID"
  pv links.with_ids.txt.gz \
    | gunzip \
    | sort -S 80% -t $'\t' -k 2n,2n \
    | uniq \
    | gzip --fast > links.sorted_by_target_id.txt.gz.tmp
  mv links.sorted_by_target_id.txt.gz.tmp links.sorted_by_target_id.txt.gz
else
  echo "$HD[12/$TOT]$HDZ Already sorted links file by target page ID"
fi


#############################
#  GROUP SORTED LINKS FILE  #
#############################
if [ ! -f links.grouped_by_source_id.txt.gz ]; then
  echo
  echo "$HD[13/$TOT]$HDZ Grouping source links file by source page ID"
  pv links.sorted_by_source_id.txt.gz \
   | gunzip \
   | awk -F '\t' '$1==last {printf "|%s",$2; next} NR>1 {print "";} {last=$1; printf "%s\t%s",$1,$2;} END{print "";}' \
   | gzip --fast > links.grouped_by_source_id.txt.gz.tmp
  mv links.grouped_by_source_id.txt.gz.tmp links.grouped_by_source_id.txt.gz
else
  echo "$HD[13/$TOT]$HDZ Already grouped source links file by source page ID"
fi

if [ ! -f links.grouped_by_target_id.txt.gz ]; then
  echo
  echo "$HD[14/$TOT]$HDZ Grouping target links file by target page ID"
  pv links.sorted_by_target_id.txt.gz \
    | gunzip \
    | awk -F '\t' '$2==last {printf "|%s",$1; next} NR>1 {print "";} {last=$2; printf "%s\t%s",$2,$1;} END{print "";}' \
    | gzip > links.grouped_by_target_id.txt.gz
else
  echo "$HD[14/$TOT]$HDZ Already grouped target links file by target page ID"
fi


################################
# COMBINE GROUPED LINKS FILES  #
################################
if [ ! -f links.with_counts.txt.gz ]; then
  echo
  echo "$HD[15/$TOT]$HDZ Combining grouped links files"
  (pv links.grouped_by_source_id.txt.gz | gunzip > pipe1 ; pv links.grouped_by_target_id.txt.gz | gunzip > pipe2) \
    | python "$ROOT_DIR/combine_grouped_links_files.py" pipe1 pipe2 \
    | gzip --fast > links.with_counts.txt.gz.tmp
  mv links.with_counts.txt.gz.tmp links.with_counts.txt.gz
else
  echo "$HD[15/$TOT]$HDZ Already combined grouped links files"
fi

# Removing the named pipes
rm pipe1 pipe2 pipe3

############################
#  CREATE SQLITE DATABASE  #
############################
if [ ! -f sdow.sqlite ]; then
  echo
  echo "$HD[16/$TOT]$HDZ Creating redirects table"
  pv redirects.with_ids.txt.gz | gunzip | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createRedirectsTable.sql"

  echo
  echo "$HD[17/$TOT]$HDZ Creating pages table"
  pv pages.pruned.txt.gz | gunzip | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createPagesTable.sql"

  echo
  echo "$HD[18/$TOT]$HDZ Creating links table"
  pv links.with_counts.txt.gz | gunzip | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createLinksTable.sql"

  echo
  echo "$HD[19/$TOT]$HDZ Compressing SQLite file"
  pv sdow.sqlite | gzip --best --keep > sdow.sqlite.gz
else
  echo "$HD[1X/$TOT]$HDZ Already created SQLite database"
fi


echo
echo "$HD[DONE]$HDZ All done!"
