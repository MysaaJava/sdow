"""
Replaces page names in the links file with their corresponding IDs, eliminates links containing
non-existing pages, and replaces redirects with the pages to which they redirect.

Output is written to stdout.
"""

from __future__ import print_function

import sys

# Validate inputs
if len(sys.argv) < 4:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <pages_file> <redirects_file> <links_file>'.format(sys.argv[0]))
  sys.exit()

PAGES_FILE = sys.argv[1]
REDIRECTS_FILE = sys.argv[2]
LINKS_FILE = sys.argv[3]

pagesf = open(PAGES_FILE,'r')
# Create a set of all page IDs and a dictionary of page titles to their corresponding IDs.
ALL_PAGE_IDS = set()
PAGE_TITLES_TO_IDS = {}
for line in pagesf.readlines():
  [page_id, page_title, _] = line.decode().rstrip('\n').split('\t')
  ALL_PAGE_IDS.add(page_id)
  PAGE_TITLES_TO_IDS[page_title] = page_id

redirectsf = open(REDIRECTS_FILE,'r')
# Create a dictionary of page IDs to the target page ID to which they redirect.
REDIRECTS = {}
for line in redirectsf.readlines():
  [source_page_id, target_page_id] = line.decode().rstrip('\n').split('\t')
  REDIRECTS[source_page_id] = target_page_id

linksf = open(LINKS_FILE,'r')
# Loop through each line in the links file, replacing titles with IDs, applying redirects, and
# removing nonexistent pages, writing the result to stdout.
for line in linksf.readlines():
  [source_page_id, target_page_title] = line.decode().rstrip('\n').split('\t')
  
  source_page_exists = source_page_id in ALL_PAGE_IDS

  #if (int(source_page_id) % 1000) == 0:
  #  print(str(source_page_id) + "/" + str(page_id),file=sys.stderr)

  if source_page_exists:
    source_page_id = REDIRECTS.get(source_page_id, source_page_id)

    target_page_id = PAGE_TITLES_TO_IDS.get(target_page_title)

    if target_page_id is not None and source_page_id != target_page_id:
      target_page_id = REDIRECTS.get(target_page_id, target_page_id)
      print('\t'.join([source_page_id, target_page_id]))
