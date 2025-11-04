"""
Replaces page titles in the redirects file with their corresponding IDs.

Output is written to stdout.
"""

import sys
from tqdm import tqdm

# Validate input arguments.
if len(sys.argv) < 3:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <pages_pipe> <redirects_pipe>'.format(sys.argv[0]))
  sys.exit()

PAGES_PIPE = sys.argv[1]
REDIRECTS_PIPE = sys.argv[2]

# Create a set of all page IDs and a dictionary of page titles to their corresponding IDs.
pagesf = open(PAGES_PIPE,'rb')
ALL_PAGE_IDS = set()
PAGE_TITLES_TO_IDS = {}
for line in pagesf:
  [page_id, page_title,_] = line.rstrip(b'\n').split(b'\t')
  ALL_PAGE_IDS.add(page_id)
  PAGE_TITLES_TO_IDS[page_title] = page_id

# Create a dictionary of redirects, replace page titles in the redirects file with their
# corresponding IDs and ignoring pages which do not exist.
redirectsf = open(REDIRECTS_PIPE,'rb')
REDIRECTS = {}
for line in redirectsf:
  [source_page_id, target_page_title] = line.rstrip(b'\n').split(b'\t')

  source_page_exists = source_page_id in ALL_PAGE_IDS
  target_page_id = PAGE_TITLES_TO_IDS.get(target_page_title)

  if source_page_exists and target_page_id is not None:
    REDIRECTS[source_page_id] = target_page_id

# Loop through the redirects dictionary and remove redirects which redirect to another redirect,
# writing the remaining redirects to stdout.
for source_page_id, target_page_id in REDIRECTS.items():
  start_target_page_id = target_page_id

  redirected_count = 0
  while target_page_id in REDIRECTS:
    target_page_id = REDIRECTS[target_page_id]

    redirected_count += 1

    # Break out if there is a circular path, meaning the redirects only point to other redirects,
    # not an acutal page.
    if target_page_id == start_target_page_id or redirected_count > 100:
      target_page_id = None

  if target_page_id is not None:
    print(b'\t'.join([source_page_id, target_page_id]).decode())
