"""
Replaces page names in the links file with their corresponding IDs, eliminates links containing
non-existing pages, and replaces redirects with the pages to which they redirect.

Output is written to stdout.
"""

import sys

# Validate inputs
if len(sys.argv) < 4:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <pages_pipe> <redirects_pipe> <targets_pipe>'.format(sys.argv[0]))
  sys.exit()

PAGES_PIPE = sys.argv[1]
REDIRECTS_PIPE = sys.argv[2]
TARGETS_PIPE = sys.argv[3]

# Create a set of all page IDs and a dictionary of page titles to their corresponding IDs.
ALL_PAGE_IDS = set()
PAGE_TITLES_TO_IDS = {}
linesf = open(PAGES_PIPE, 'rb')
for line in linesf:
  [page_id, page_title, _] = line.rstrip(b'\n').split(b'\t')
  ALL_PAGE_IDS.add(page_id)
  PAGE_TITLES_TO_IDS[page_title] = page_id
  if int(page_id)==12207:
    print("Found",line.decode(),len(page_title),"'"+page_title.decode()+"'",page_title==b"Geology",file=sys.stderr)

print("-->",len(PAGE_TITLES_TO_IDS),file=sys.stderr)

# Create a dictionary of page IDs to the target page ID to which they redirect.
REDIRECTS = {}
for line in io.BufferedReader(gzip.open(REDIRECTS_FILE, 'rb')):
  [source_page_id, target_page_id] = line.rstrip(b'\n').split(b'\t')
  REDIRECTS[source_page_id] = target_page_id

print("Reading Targets File",file=sys.stderr)
# Loop through each line in the links file, replacing titles with IDs, applying redirects, and
# removing nonexistent pages, writing the result to stdout.
for line in io.BufferedReader(gzip.open(TARGETS_FILE, 'rb')):
  [target_id, target_page_title] = line.rstrip(b'\n').split(b'\t')

  target_page_id = PAGE_TITLES_TO_IDS.get(target_page_title)
  if target_page_title==b"Geology":
    print("Found geology",target_page_id,file=sys.stderr)
  if int(target_id)==578:
    print("Found 2th geology",target_page_id,file=sys.stderr)

  if target_page_id is not None:
    target_page_id = REDIRECTS.get(target_page_id, target_page_id)
    if int(target_id)==578:
      print("Found 3rd geology",source_page_id,target_page_id,file=sys.stderr)

    print(b'\t'.join([target_id, target_page_id]).decode())
  else:
    pass
    #print("Target not found for page",target_page_title,file=sys.stderr)


