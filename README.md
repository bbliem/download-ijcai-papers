Download IJCAI 2016 Papers Liked on Confer
==========================================

The IJCAI 2016 conference allows you to mark papers that you are interested in
via the Confer web app. Unfortunately there are no PDF download links in
Confer. To make things worse, some paper titles in the IJCAI proceedings differ
slightly from the ones in Confer. This script downloads the papers whose title
is closest to the papers that you liked on Confer.

Prerequisites
-------------

Install Ruby (tested on 2.3) and then run the following to install the necessary dependencies:

```
  gem install amatch
  gem install mechanize
  gem install highline
```

Running
-------

```
  Usage: ./download-liked-papers.rb [-u user] [-p password] [-d paper_directory]
      -h, --help                       Print usage information
      -u username                      Confer user name (will prompt if missing)
      -p password                      Confer password (will prompt if missing)
      -d directory                     Directory where to put papers (default: ./papers)
```
