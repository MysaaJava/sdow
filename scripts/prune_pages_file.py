"""
Prunes the pages file by removing pages which are marked as redirects but have no corresponding
redirect in the redirects file.

Output is written to stdout.
"""

from __future__ import print_function

import io
import sys
import gzip

# Validate input arguments.
if len(sys.argv) < 3:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <pages_file> <redirects_file>'.format(sys.argv[0]))
  sys.exit()

REDIRECTS_FILE = sys.argv[1]
PAGES_FILE = sys.argv[2]

redirectsf = open(REDIRECTS_FILE)
pagesf = open(PAGES_FILE)

# Create a dictionary of redirects.
REDIRECTS = {}
for line in redirects.readlines():
  [source_page_id, _] = line.decode().rstrip('\n').split('\t')
  REDIRECTS[source_page_id] = True

# Loop through the pages file, ignoring pages which are marked as redirects but which do not have a
# corresponding redirect in the redirects dictionary, printing the remaining pages to stdout.
for line in pages.readlines():
  [page_id, page_title, is_redirect] = line.decode().rstrip('\n').split('\t')

  if is_redirect == '0' or page_id in REDIRECTS:
    print('\t'.join([page_id, page_title, is_redirect]))
