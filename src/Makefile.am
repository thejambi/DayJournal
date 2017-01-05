## Process this file with automake to produce Makefile.in

## Created by Anjuta



AM_CPPFLAGS = \
	-DPACKAGE_LOCALE_DIR=\""$(localedir)"\" \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	-DPACKAGE_DATA_DIR=\""$(pkgdatadir)"\" \
	$(DAYJOURNAL_CFLAGS)

AM_CFLAGS =\
	 -Wall\
	 -g

bin_PROGRAMS = dayjournal

dayjournal_SOURCES = \
	dayjournal.vala config.vapi DateUtility.vala FileUtility.vala JournalEditor.vala JournalEntry.vala UserData.vala UserSettingsManager.vala Zystem.vala JournalArchiver.vala BlipLoader.vala Blip.vala EntryImageAnchors.vala DayOneToBlipConverter.vala

dayjournal_VALAFLAGS =  --pkg gio-2.0 --pkg glib-2.0 --pkg gee-0.8 --pkg gtk+-3.0 --pkg libnotify  \
	--pkg gtk+-3.0

dayjournal_LDFLAGS = \
	-Wl,--export-dynamic

dayjournal_LDADD = $(DAYJOURNAL_LIBS)


