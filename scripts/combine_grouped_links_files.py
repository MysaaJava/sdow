"""
Combines the incoming and outgoing links (as well as their counts) for each page.

Output is written to stdout.
"""

from __future__ import print_function

import sys
from collections import defaultdict
from tqdm import tqdm

# Validate input arguments.
if len(sys.argv) < 2:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <outgoing_links_file> <incoming_links_file>'.format(sys.argv[0]))
  sys.exit()

OUTGOING_LINKS_FILE = sys.argv[1]
INCOMING_LINKS_FILE = sys.argv[2]

olf = open(OUTGOING_LINKS_FILE,'r')
# Create a dictionary of page IDs to their incoming and outgoing links.
LINKS = defaultdict(lambda: defaultdict(str))
for line in olf.readline():
  [source_page_id, target_page_ids] = line.rstrip('\n').split('\t')
  LINKS[source_page_id]['outgoing'] = target_page_ids

ilf = open(INCOMING_LINKS_FILE,'r')
for line in ilf.readlines():
  decoded = line.rstrip('\n').split('\t')
  if len(decoded)<2:
    print("One line is illegal :/",file=sys.stderr)
    continue
  [target_page_id, source_page_ids] = decoded
  LINKS[target_page_id]['incoming'] = source_page_ids

# For each page in the links dictionary, print out its incoming and outgoing links as well as their
# counts.
for page_id, links in tqdm(LINKS.items(),total=len(LINKS)):
  outgoing_links = links.get('outgoing', '')
  outgoing_links_count = 0 if (outgoing_links == '') else len(
      outgoing_links.split('|'))

  incoming_links = links.get('incoming', '')
  incoming_links_count = 0 if (incoming_links == '') else len(
      incoming_links.split('|'))
  
  page_id = page_id.replace("\x00","")

  columns = [page_id, str(outgoing_links_count), str(
      incoming_links_count), outgoing_links, incoming_links]
  dgz = [c.isdigit() for c in columns]
  if not dgz[0]:
    print(columns,file=sys.stderr)

  print('\t'.join(columns))
