"""
Combines the incoming and outgoing links (as well as their counts) for each page.

Output is written to stdout.
"""

import sys
import gzip

# validate input arguments.
if len(sys.argv) < 2:
  print('[ERROR] Not enough arguments provided!')
  print('[INFO] Usage: {0} <outgoing_links_file> <incoming_links_file>'.format(sys.argv[0]), file=sys.stderr)
  sys.exit()

OUTGOING_LINKS_FILE = sys.argv[1]
INCOMING_LINKS_FILE = sys.argv[2]

if not OUTGOING_LINKS_FILE.endswith('.gz'):
  print('[ERROR] Outgoing links file must be gzipped.', file=sys.stderr)
  sys.exit()

if not INCOMING_LINKS_FILE.endswith('.gz'):
  print('[ERROR] Incoming links file must be gzipped.', file=sys.stderr)
  sys.exit()

def parse_line(line):
  parts = line.rstrip(b'\n').split(b'\t', 1)
  return (int(parts[0]), parts[1] if len(parts) > 1 else b'')

def file_iterator(filename):
  with gzip.open(filename, 'rb') as f:
    for line in f:
      yield parse_line(line)

# Merge the two sorted files, we're using gnerators instead of dicts to stream the content
# and not load the entire files into memory, this helps with RAM consumption a lot.

outgoing_iter = file_iterator(OUTGOING_LINKS_FILE)
incoming_iter = file_iterator(INCOMING_LINKS_FILE)

outgoing_current = next(outgoing_iter, None)
incoming_current = next(incoming_iter, None)

while outgoing_current is not None or incoming_current is not None:
  if outgoing_current is None:
    page_id, incoming_links = incoming_current
    outgoing_links = b''
    incoming_current = next(incoming_iter, None)
  elif incoming_current is None:
    page_id, outgoing_links = outgoing_current
    incoming_links = b''
    outgoing_current = next(outgoing_iter, None)
  elif outgoing_current[0] < incoming_current[0]:
    page_id, outgoing_links = outgoing_current
    incoming_links = b''
    outgoing_current = next(outgoing_iter, None)
  elif incoming_current[0] < outgoing_current[0]:
    page_id, incoming_links = incoming_current
    outgoing_links = b''
    incoming_current = next(incoming_iter, None)
  else:
    page_id = outgoing_current[0]
    outgoing_links = outgoing_current[1]
    incoming_links = incoming_current[1]
    outgoing_current = next(outgoing_iter, None)
    incoming_current = next(incoming_iter, None)
  
  outgoing_links_count = 0 if outgoing_links == b'' else len(outgoing_links.split(b'|'))
  incoming_links_count = 0 if incoming_links == b'' else len(incoming_links.split(b'|'))
  
  columns = [str(page_id).encode(), str(outgoing_links_count).encode(), 
             str(incoming_links_count).encode(), outgoing_links, incoming_links]
  
 
