#!/bin/bash
set -euo pipefail

# Force default language for output sorting to be bytewise. Necessary to ensure uniformity amongst
# UNIX commands.
export LC_ALL=C
PYTHON=python3

# These variable can be set by calling env
WLANG=${WLANG:-en}
ROOT_DIR=${ROOT_DIR:-$(dirname "$0")}
OUT_DIR=${OUT_DIR:-$PWD/dump/}

# Set to string "true" if you want the program to delete files progressively
DELETE_PROGRESSIVELY=${DELETE_PROGRESSIVELY:-false}
DISABLE_FINAL_COMPRESSION=${DISABLE_FINAL_COMPRESSION:-false}

DOWNLOAD_URL_BASE=${DOWNLOAD_URL_BASE:-https://dumps.wikimedia.org/}
TORRENT_URL_BASE=${TORRENT_URL_BASE:-https://tools.wmflabs.org/dump-torrents/}

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

DOWNLOAD_URL="$DOWNLOAD_URL_BASE/${WLANG}wiki/$DOWNLOAD_DATE"
TORRENT_URL="$TORRENT_URL_BASE/${WLANG}wiki/$DOWNLOAD_DATE"

SHA1SUM_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-sha1sums.txt"

REDIRECTS_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-redirect.sql.gz"
PAGES_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-page.sql.gz"
LINKS_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-pagelinks.sql.gz"
TARGETS_FILENAME="${WLANG}wiki-$DOWNLOAD_DATE-linktarget.sql.gz"

if which pv
then cat=pv
else cat=cat
fi
if which pigz
then gz=pigz --fast
else gz=gzip
fi
if which pigz
then ugz=pigz -dc
else ugz=gunzip
fi

# Make the output directory if it doesn't already exist and move to it
mkdir -p $OUT_DIR
pushd $OUT_DIR > /dev/null


echo "[INFO] Download date: $DOWNLOAD_DATE"
echo "[INFO] Download URL: $DOWNLOAD_URL"
echo "[INFO] Output directory: $OUT_DIR"
echo

##############################
#  DOWNLOAD WIKIPEDIA DUMPS  #
##############################

function download_file() {
  if [ ! -f $2 ]; then
    echo
    if [ $1 != sha1sums ] && command -v aria2c > /dev/null; then
      echo "[INFO] Downloading $1 file via torrent"
      time aria2c --summary-interval=0 --console-log-level=warn --seed-time=0 \
        "$TORRENT_URL/$2.torrent" 2>&1 | grep -v "ERROR\|Exception" || true
    fi
    
    if [ ! -f $2 ]; then
      echo "[INFO] Downloading $1 file via wget"
      time wget --progress=dot:giga "$DOWNLOAD_URL/$2"
    fi

    if [ $1 != sha1sums ]; then
      echo
      echo "[INFO] Verifying SHA-1 hash for $1 file"
      time grep "$2" "$SHA1SUM_FILENAME" | sha1sum -c
      if [ $? -ne 0 ]; then
        echo
        echo "[ERROR] Downloaded $1 file has incorrect SHA-1 hash"
        rm $2
        exit 1
      fi
    fi
  else
    echo "[WARN] Already downloaded $1 file"
  fi
}

download_file "sha1sums" $SHA1SUM_FILENAME
download_file "redirects" $REDIRECTS_FILENAME
download_file "pages" $PAGES_FILENAME
download_file "links" $LINKS_FILENAME
download_file "targets" $TARGETS_FILENAME

##########################
#  TRIM WIKIPEDIA DUMPS  #
##########################
if [ ! -f redirects.txt.gz ]; then
  echo
  echo "[INFO] Trimming redirects file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
  $cat $REDIRECTS_FILENAME \
    | $ugz \
    | sed -n 's/^INSERT INTO `redirect` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0," \
    | sed -e $"s/,0,'/\t/g" \
    | sed -e "s/','.*//g" \
    | $gz --fast > redirects.txt.gz.tmp
  mv redirects.txt.gz.tmp redirects.txt.gz
else
  echo "[WARN] Already trimmed redirects file"
fi
if $DELETE_PROGRESSIVELY; then rm $REDIRECTS_FILENAME; fi

if [ ! -f pages.txt.gz ]; then
  echo
  echo "[INFO] Trimming pages file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Splice out the page title and whether or not the page is a redirect
  # Zip into output file
  $cat $PAGES_FILENAME \
    | $ugz \
    | sed -n 's/^INSERT INTO `page` VALUES //p' \
    | egrep -o "\([0-9]+,0,'([^']*(\\\\')?)+',[01]," \
    | sed -re $"s/^\(([0-9]+),0,'/\1\t/" \
    | sed -re $"s/',([01]),/\t\1/" \
    | $gz --fast > pages.txt.gz.tmp
  mv pages.txt.gz.tmp pages.txt.gz
else
  echo "[WARN] Already trimmed pages file"
fi
if $DELETE_PROGRESSIVELY; then rm $PAGES_FILENAME; fi

if [ ! -f links.txt.gz ]; then
  echo
  echo "[INFO] Trimming links file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
  $cat $LINKS_FILENAME \
    | $ugz \
    | sed -n 's/^INSERT INTO `pagelinks` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0,[0-9]+$" \
    | sed -e $"s/,0,/\t/g" \
    | $gz --fast > links.txt.gz.tmp
  mv links.txt.gz.tmp links.txt.gz
else
  echo "[WARN] Already trimmed links file"
fi
if $DELETE_PROGRESSIVELY; then rm $LINKS_FILENAME; fi

if [ ! -f targets.txt.gz ]; then
  echo
  echo "[INFO] Trimming targets file"

  # Unzip
  # Remove all lines that don't start with INSERT INTO...
  # Split into individual records
  # Only keep records in namespace 0
  # Replace namespace with a tab
  # Remove everything starting at the to page name's closing apostrophe
  # Zip into output file
  $cat $TARGETS_FILENAME \
    | $ugz \
    | sed -n 's/^INSERT INTO `linktarget` VALUES (//p' \
    | sed -e 's/),(/\'$'\n/g' \
    | egrep "^[0-9]+,0,.*$" \
    | sed -e $"s/,0,'/\t/g" \
    | sed -e "s/'$//g" \
    | $gz --fast > targets.txt.gz.tmp
  mv targets.txt.gz.tmp targets.txt.gz
else
  echo "[WARN] Already trimmed targets file"
fi
if $DELETE_PROGRESSIVELY; then rm $TARGETS_FILENAME; fi


# Creating the named pipes for python programs
rm -f pipe1 pipe2 pipe3
mkfifo pipe1
mkfifo pipe2
mkfifo pipe3
mkfifo pipe4

###########################################
#  REPLACE TITLES AND REDIRECTS IN FILES  #
###########################################
if [ ! -f redirects.with_ids.txt.gz ]; then
  echo
  echo "[INFO] Replacing titles in redirects file"
    ($cat pages.txt.gz | $ugz > pipe1 ; $cat redirects.txt.gz | $ugz > pipe2) \
    | $PYTHON "$ROOT_DIR/replace_titles_in_redirects_file.py" pipe1 pipe2 \
    | sort -S 100% -t $'\t' -k 1n,1n \
    | $gz > redirects.with_ids.txt.gz.tmp
  mv redirects.with_ids.txt.gz.tmp redirects.with_ids.txt.gz
else
  echo "[WARN] Already replaced titles in redirects file"
fi
if $DELETE_PROGRESSIVELY; then rm redirects.txt.gz; fi

if [ ! -f targets.with_ids.txt.gz ]; then
  echo
  echo "[INFO] Replacing titles and redirects in targets file"
  ($cat pages.txt.gz | $ugz > pipe1 ; $cat redirects.with_ids.txt.gz | $ugz > pipe2; $cat targets.txt.gz | $ugz > pipe3 ; $cat links.txt.gz | $ugz > pipe4) \
    | $PYTHON "$ROOT_DIR/replace_titles_and_redirects_in_targets_file.py" pipe1 pipe2 pipe3 pipe4 \
    | $gz > targets.with_ids.txt.gz.tmp
  mv targets.with_ids.txt.gz.tmp targets.with_ids.txt.gz
else
  echo "[WARN] Already replaced titles and redirects in targets file"
fi
if $DELETE_PROGRESSIVELY; then rm targets.txt.gz; fi

if [ ! -f links.with_ids.txt.gz ]; then
  echo
  ($cat pages.txt.gz | $ugz > pipe1 ; $cat redirects.with_ids.txt.gz | $ugz > pipe2; $cat links.txt.gz | $ugz > pipe3) \
  | $PYTHON "$ROOT_DIR/replace_titles_and_redirects_in_links_file.py" pipe1 pipe2 pipe3 \
  | $gz > links.with_ids.txt.gz.tmp
  mv targets.with_ids.txt.gz.tmp targets.with_ids.txt.gz
  mv links.with_ids.txt.gz.tmp links.with_ids.txt.gz
else
  echo "[WARN] Already replaced titles and redirects in links file"
fi
if $DELETE_PROGRESSIVELY; then rm links.txt.gz targets.with_ids.txt.gz; fi

if [ ! -f pages.pruned.txt.gz ]; then
  echo
  echo "[INFO] Pruning pages which are marked as redirects but with no redirect"
  ($cat redirects.with_ids.txt.gz | $ugz > pipe1 ; $cat pages.txt.gz | $ugz > pipe2) \
    | $PYTHON "$ROOT_DIR/prune_pages_file.py" pipe1 pipe2 \
    | $gz > pages.pruned.txt.gz
else
  echo "[WARN] Already pruned pages which are marked as redirects but with no redirect"
fi
if $DELETE_PROGRESSIVELY; then rm pages.txt.gz; fi

#####################
#  SORT LINKS FILE  #
#####################
if [ ! -f links.sorted_by_source_id.txt.gz ]; then
  echo
  echo "[INFO] Sorting links file by source page ID"
  $cat links.with_ids.txt.gz \
    | $ugz \
    | sort -S 80% -t $'\t' -k 1n,1n \
    | uniq \
    | $gz > links.sorted_by_source_id.txt.gz.tmp
  mv links.sorted_by_source_id.txt.gz.tmp links.sorted_by_source_id.txt.gz
else
  echo "[WARN] Already sorted links file by source page ID"
fi

if [ ! -f links.sorted_by_target_id.txt.gz ]; then
  echo
  echo "[INFO] Sorting links file by target page ID"
  $cat links.with_ids.txt.gz \
    | $ugz \
    | sort -S 80% -t $'\t' -k 2n,2n \
    | uniq \
    | $gz > links.sorted_by_target_id.txt.gz.tmp
  mv links.sorted_by_target_id.txt.gz.tmp links.sorted_by_target_id.txt.gz
else
  echo "[WARN] Already sorted links file by target page ID"
fi
if $DELETE_PROGRESSIVELY; then rm links.with_ids.txt.gz; fi


#############################
#  GROUP SORTED LINKS FILE  #
#############################
if [ ! -f links.grouped_by_source_id.txt.gz ]; then
  echo
  echo "[INFO] Grouping source links file by source page ID"
  $cat links.sorted_by_source_id.txt.gz \
   | $ugz \
   | awk -F '\t' '$1==last {printf "|%s",$2; next} NR>1 {print "";} {last=$1; printf "%s\t%s",$1,$2;} END{print "";}' \
   | $gz > links.grouped_by_source_id.txt.gz.tmp
  mv links.grouped_by_source_id.txt.gz.tmp links.grouped_by_source_id.txt.gz
else
  echo "[WARN] Already grouped source links file by source page ID"
fi
if $DELETE_PROGRESSIVELY; then rm links.sorted_by_source_id.txt.gz; fi

if [ ! -f links.grouped_by_target_id.txt.gz ]; then
  echo
  echo "[INFO] Grouping target links file by target page ID"
  $cat links.sorted_by_target_id.txt.gz \
    | $ugz \
    | awk -F '\t' '$2==last {printf "|%s",$1; next} NR>1 {print "";} {last=$2; printf "%s\t%s",$2,$1;} END{print "";}' \
    | $gz > links.grouped_by_target_id.txt.gz
else
  echo "[WARN] Already grouped target links file by target page ID"
fi
if $DELETE_PROGRESSIVELY; then rm links.sorted_by_target_id.txt.gz; fi


################################
# COMBINE GROUPED LINKS FILES  #
################################
if [ ! -f links.with_counts.txt.gz ]; then
  echo
  echo "[INFO] Combining grouped links files"
  ($cat links.grouped_by_source_id.txt.gz | $ugz > pipe1 ; $cat links.grouped_by_target_id.txt.gz | $ugz > pipe2) \
  | $PYTHON "$ROOT_DIR/combine_grouped_links_files.py" pipe1 pipe2\
    | $gz > links.with_counts.txt.gz.tmp
  mv links.with_counts.txt.gz.tmp links.with_counts.txt.gz
else
  echo "[WARN] Already combined grouped links files"
fi
if $DELETE_PROGRESSIVELY; then rm links.grouped_by_source_id.txt.gz links.grouped_by_target_id.txt.gz; fi


############################
#  CREATE SQLITE DATABASE  #
############################
if [ ! -f sdow.sqlite ]; then
  echo
  echo "[INFO] Creating redirects table"
  $cat redirects.with_ids.txt.gz | $ugz | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createRedirectsTable.sql"
  if $DELETE_PROGRESSIVELY; then rm redirects.with_ids.txt.gz; fi

  echo
  echo "[INFO] Creating pages table"
  $cat pages.pruned.txt.gz | $ugz | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createPagesTable.sql"
  if $DELETE_PROGRESSIVELY; then rm pages.pruned.txt.gz; fi

  echo
  echo "[INFO] Creating links table"
  $cat links.with_counts.txt.gz | $ugz | sqlite3 sdow.sqlite ".read $ROOT_DIR/../sql/createLinksTable.sql"
  if $DELETE_PROGRESSIVELY; then rm links.with_counts.txt.gz; fi
else
  echo "[WARN] Already created SQLite database"
fi

if [ -f sdow.sqlite.gz ];
then echo "[WARN] Already compressed SQLite database"
elif $DISABLE_COMPRESS
then echo "[WARN] Skipping compressing SQLite database"
else
  echo
  echo "[INFO] Compressing SQLite database"
  pv sdow.sqlite | gzip --best --keep > sdow.sqlite.gz.tmp
  mv sdow.sqlite.gz.tmp sdow.sqlite.gz
fi

echo
echo "[INFO] All done!"
