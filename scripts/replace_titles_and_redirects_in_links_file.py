"""
Replaces page names in the links file with their corresponding IDs, eliminates links containing
non-existing pages, and replaces redirects with the pages to which they redirect.

Output is written to stdout.
"""

import sys

# Validate inputs
if len(sys.argv) < 5:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <pages_pipe> <redirects_pipe> <target_pipe> <links_pipe>'.format(sys.argv[0]))
  sys.exit()

PAGES_PIPE = sys.argv[1]
REDIRECTS_PIPE = sys.argv[2]
TARGETS_PIPE = sys.argv[3]
LINKS_PIPE = sys.argv[4]

# Create a set of all page IDs and a dictionary of page titles to their corresponding IDs.
ALL_PAGE_IDS = set()
pagesf = open(PAGES_FILE,'rb')
for line in pagesf:
  [page_id, page_title, _] = line.rstrip(b'\n').split(b'\t')
  ALL_PAGE_IDS.add(page_id)

# Create a dictionary of page IDs to the target page ID to which they redirect.
REDIRECTS = {}
redirectsf = open(REDIRECTS_PIPE,'rb')
for line in redirectsf:
  [source_page_id, target_page_id] = line.rstrip(b'\n').split(b'\t')
  REDIRECTS[source_page_id] = target_page_id

# Create a dictionary of linktarget IDs to the target page ID
TARGETS = {}
targetsf = open(TARGETS_PIPE, 'rb')
for line in targetsf:
  [target_id, target_page_id] = line.rstrip(b'\n').split(b'\t')
  TARGETS[target_id] = target_page_id

# Loop through each line in the links file, replacing titles with IDs, applying redirects, and
# removing nonexistent pages, writing the result to stdout.
linksf = open(LINKS_PIPE, 'rb')
for line in linksf:
  [source_page_id, target_id] = line.rstrip(b'\n').split(b'\t')

  source_page_exists = source_page_id in ALL_PAGE_IDS

  if source_page_exists:
    source_page_id = REDIRECTS.get(source_page_id, source_page_id)

    target_page_id = TARGETS.get(target_id)
    if target_page_id is not None and source_page_id != target_page_id:
      target_page_id = REDIRECTS.get(target_page_id, target_page_id)
      print(b'\t'.join([source_page_id, target_page_id]).decode())
    else:
      pass
      #print("Target",target_id,"->",target_page_id,file=sys.stderr)

