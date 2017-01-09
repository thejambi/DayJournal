## Process this file with automake to produce Makefile.in
## Created by Anjuta

SUBDIRS = src 

dayjournaldocdir = ${prefix}/doc/dayjournal
dayjournaldoc_DATA = \
	COPYING


EXTRA_DIST = $(dayjournaldoc_DATA)


# Remove doc directory on uninstall
uninstall-local:
	-rm -r $(dayjournaldocdir)
