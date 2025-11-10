# Description of the process

## Parsing of the tables

### links.txt
- `pl_from` -> Id of the "from" page of this link
- (`pl_namespace`) -> We keep only if equals 0 (= namespace of the "from" page of this link)
- `pl_target_id` -> Target of this link  (foreign key to `linktarget`)

### targets.txt
- `lt_id` -> Id of this link (index)
- (`lt_ns`) -> We keep only if equals 0 (= namespace of the targeted page)
- `lt_title` -> Title of the targeted page

### pages.txt
- `page_id` -> Id of the page
- (`page_namespace`) -> We keep only if equals 0 (= namespace of this page)
- `page_title` -> Title of this page
- `page_is_redirect` -> Boolean whether this page is a redirect
- Ignore the eight following

### redirects.txt
- `rd_from` -> Id of the page from which we are redirected
- (`rd_namespace`) -> We keep only if equals 0 (= namespace of the page we are redirected to)
- `rd_title` -> Title of the page we are redirected to
- Ignore the two following

## Joining the tables

### redirects.with_ids.txt (replace_titles_in_redirects_file.py)
Replaces for each redirection, `rd_title` with the targeted `page_id` by matching on `page_title`.
The targetted page_id is then computed as a redirect recursively, until we get on a "final" page.
- `rd_from` -> The id of the page we are redirected from
- `page_id` -> The id of the page we get to following redirections recursively

### targets.with_ids.txt (replace_titles_and_redirects_in_targets_file.py)
Replaces, for each linktarget, `lt_title` with the targeted `page_id` by matching on `page_title`.
We then compute the "final" page obtained from this page following redirection, with the file `redirects.with_ids.txt`.
- `lt_id` -> Id of this link
- `page_id` -> The id of the page this link is pointing to, after having followed all redirections

### links.with_ids.txt (replace_titles_and_redirects_in_links_file.py)
Replaces, for each pagelink, `lt_id` with the targeted `page_id` by joining with `links.with_ids.txt`.
- `pl_from` -> Id of the "from" page, after having followed all redirections
- `page_id` -> Id of the "to" page, after having followed all redirections

### page.pruned.txt (prune_pages_file.py)
Prunes the pages file by removing pages which are marked as redirects but have no corresponding redirect in the redirects file.

## Sorting, grouping, and counting the links

### links.sorted_by_XXX_id.txt
Then we sorts the `links.with_ids.txt` according to the first "source" id, into
the file `links.sorted_by_source_id.txt`, and according to the second "target" id 
into the file `links.sorted_by_target_id.txt`.

### links.grouped_by_XXX_id.txt
Then, we use those two files to *GROUP BY* the links by source and by target.
The file `links.grouped_by_source_id.txt` is like this
- `pl_from` -> Id of the "from" page
- `targets` -> A `|`-separated string of the ids the "from" page targets

The file `links.grouped_by_target_id.txt` is like this
- `froms` -> A `|`-separated string of the ids of the pages targeting the "target" page
- `pl_target` -> Id of the "target" page

### links.with_counts.txt (combine_grouped_links_files.py)
We *stream-merge* ( we dont load the two files into memory directly ) the two files `links.grouped_by_source_id.txt.gz` and `links.grouped_by_target_id.txt.gz` into a single sorted links file `links.with_counts.txt`.

## Making the database
We create three tables : `redirects`, `tables`, `links` from the files : `redirects.with_ids.txt.gz`, `pages.pruned.txt.gz`, `links.with_counts.txt.gz`  


# Notes on building the database locally (on Debian based machines) :

Depending on your hardware, you might need to change some values in the `buildDatabase.sh` script, most notably how much of the cpu the `sort` command should take, you can define the value as a percentage or in gigabytes, while running on a DigitalOcean droplet with 16 gb of ram it was best to give the sort command 4 gb of ram, The whole database generation took about two hours ( 14gb final size for the sdow.sqlite file ).

If the script keeps exiting with no error message, its possible that the system is killing it for taking too much ressources, you can investigate that by running : `dmesg | grep -i "killed process"`

after creating the database you can inspect its content using `sqlitebrowser`
