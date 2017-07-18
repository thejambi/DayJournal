/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * DayJournal
 *
 * Copyright (C) 2013 Zach Burnham <thejambi@gmail.com>
 *
 * DayJournal is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * DayJournal is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gee;
using GLib;
using Gtk;
using Notify;

public class Main : Window {

	// SET THIS TO TRUE BEFORE BUILDING TARBALL
	private const bool isInstalled = true;

	private const string shortcutsText = 
			"Ctrl+L: Go to next day\n" + 
			"Ctrl+J: Go to previous day\n" + 
			"Ctrl+I: Jump a week back\n" + 
			"Ctrl+K: Jump a week forward\n" + 
			"Ctrl+T: Go to Today\n" + 
			"Ctrl+D: Start entry with the date\n" + 
			"Ctrl+N: Insert a new entry section\n" + 
			"Ctrl+=: Increase font size\n" + 
			"Ctrl+-: Decrease font size\n" +
			"Ctrl+Shift+=: Increase calendar font size\n" +
			"Ctrl+Shift+-: Decrease calendar font size";

	// Variables for the DayJournal GUI
	private int width;
	private int height;
	
	private Calendar calendar;
	private JournalEditor editor;
	private JournalEntry entry;
	private TextView entryTextView;
	
//	private int startingFontSize;
//	private int fontSize;
	
	private bool isOpening;
	private bool needsSave = false;
	private bool entryLocked = false;
	private string lastKeyName;

	private Gtk.Menu journalMenu;
	private Gtk.Menu settingsMenu;
	private Gtk.MenuItem menuChangeDjDir;
	private Gtk.MenuItem menuOpenDjLocation;
	private Gtk.MenuItem menuCreateJournalArchive;
	private Gtk.MenuItem menuClose;
	private Gtk.Menu helpMenu;
//	private Gtk.Menu menuKeyboardShortcuts;
//	private Gtk.MenuItem menuAbout;
	private Gtk.MenuToolButton openButton;
	private Gtk.Menu openJournalsMenu;

	private Gtk.MenuItem journalsMenuItem;

	private Gdk.RGBA selectionColor;
	private Gdk.RGBA lockedBgColor;
	private Gdk.RGBA unlockedBgColor;

	private ScrolledWindow scroll;

	private bool forgetUISettings = false;

	private ToolButton unlockButton;

	/**
	 * Constructor for main DayJournal window.
	 */
	public Main() {

		//this.setUIFiles();

		Zystem.debugOn = !isInstalled;

		UserData.initializeUserData();

		this.lastKeyName = "";

		this.title = "DayJournal";  // Add location? Maybe that isn't as cool
		var headerBar = new Gtk.HeaderBar();
		headerBar.set_title("DayJournal");
		headerBar.set_show_close_button(true);
		this.set_titlebar(headerBar);
		this.window_position = WindowPosition.CENTER;
		//set_default_size (550, 430);
		set_default_size(UserData.windowWidth, UserData.windowHeight);

		this.configure_event.connect(() => {
			// Record window size if not maximized
			if (!(Gdk.WindowState.MAXIMIZED in this.get_window().get_state())) {
				this.get_size(out this.width, out this.height);
			}
			return false;
		});

		// Set up Journal menu
		journalMenu = new Gtk.Menu();
		menuChangeDjDir = new Gtk.MenuItem.with_label("Change Journal Folder");
		menuChangeDjDir.activate.connect(() => { menuChangeDjDirClicked(); });
		menuOpenDjLocation = new Gtk.MenuItem.with_label("View Current Journal Files");
		menuOpenDjLocation.activate.connect(() => { menuOpenDjLocationClicked(); });
		var menuAddImage = new Gtk.MenuItem.with_label("Add Image to Entry");
		menuAddImage.activate.connect(() => { this.chooseImage(); });
		menuCreateJournalArchive = new Gtk.MenuItem.with_label("Create Complete Journal Archive");
		menuCreateJournalArchive.activate.connect(() => { this.createCompleteJournalArchive(JournalArchiver.TYPE_HTML); });
		menuClose = new Gtk.MenuItem.with_label("Close DayJournal");
		menuClose.activate.connect(() => { this.on_destroy(); });
		journalMenu.append(menuChangeDjDir);
		journalMenu.append(menuOpenDjLocation);
		journalMenu.append(new SeparatorMenuItem());
		journalMenu.append(menuAddImage);
		journalMenu.append(new SeparatorMenuItem());
		journalMenu.append(menuCreateJournalArchive);
		journalMenu.append(new SeparatorMenuItem());
		journalMenu.append(menuClose);

		var journalMenuItem = new Gtk.MenuItem.with_label("DayJournal");
		journalMenuItem.set_submenu(journalMenu);
		//menubar.append(journalMenuItem);

		// Set up Journals menu
		this.journalsMenuItem = new Gtk.MenuItem.with_label("Journals");
		//menubar.append(this.journalsMenuItem);

		// Set up Settings menu
		settingsMenu = new Gtk.Menu();
		Gtk.MenuItem menuUnlockEntry = new Gtk.MenuItem.with_label("Unlock entry");
		menuUnlockEntry.activate.connect(() => { 
			this.unlockEntry(); 
		});
		var menuIncreaseFontSize = new Gtk.MenuItem.with_label("Increase font size");
		menuIncreaseFontSize.activate.connect(() => { 
			this.increaseFontSize(); 
		});
		var menuDecreaseFontSize = new Gtk.MenuItem.with_label("Decrease font size");
		menuDecreaseFontSize.activate.connect(() => { 
			this.decreaseFontSize(); 
		});
		var menuLockPastEntries = new CheckMenuItem.with_label("Lock past entries by default");
		menuLockPastEntries.active = UserData.lockPastEntries;
		menuLockPastEntries.toggled.connect(() => {
			this.menuLockPastEntriesToggled(menuLockPastEntries);
		});
		var menuIncreaseCalendarFontSize = new Gtk.MenuItem.with_label("Increase calendar size");
		menuIncreaseCalendarFontSize.activate.connect(() => { 
			this.increaseCalendarFontSize(); 
		});
		var menuDecreaseCalendarFontSize = new Gtk.MenuItem.with_label("Decrease calendar size");
		menuDecreaseCalendarFontSize.activate.connect(() => { 
			this.decreaseCalendarFontSize(); 
		});
		var menuChooseFont = new Gtk.MenuItem.with_label("Change Entry Font...");
		menuChooseFont.activate.connect(() => {
			this.chooseFont();
		});
		settingsMenu.append(menuUnlockEntry);
		settingsMenu.append(menuIncreaseFontSize);
		settingsMenu.append(menuDecreaseFontSize);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuChooseFont);
		settingsMenu.append(menuLockPastEntries);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuIncreaseCalendarFontSize);
		settingsMenu.append(menuDecreaseCalendarFontSize);

		var settingsMenuItem = new Gtk.MenuItem.with_label("Settings");
		settingsMenuItem.set_submenu(settingsMenu);
		//menubar.append(settingsMenuItem);

		// Set up Help menu
		helpMenu = new Gtk.Menu();
		Gtk.MenuItem menuKeyboardShortcuts = new Gtk.MenuItem.with_label("Keyboard Shortcuts");
		menuKeyboardShortcuts.activate.connect(() => { menuKeyboardShortcutsClicked(); });
		Gtk.MenuItem menuAbout = new Gtk.MenuItem.with_label("About DayJournal");
		menuAbout.activate.connect(() => { this.menuAboutClicked(); });
		helpMenu.append(menuKeyboardShortcuts);
		helpMenu.append(menuAbout);

		var helpMenuItem = new Gtk.MenuItem.with_label("Help");
		helpMenuItem.set_submenu(helpMenu);

		this.entryTextView = new TextView();

		this.selectionColor = this.entryTextView.get_style_context().get_background_color(StateFlags.SELECTED);
		this.unlockedBgColor = this.entryTextView.get_style_context().get_background_color(StateFlags.ACTIVE);
		this.lockedBgColor = this.get_style_context().get_background_color(StateFlags.NORMAL);
		
		if (this.unlockedBgColor.to_string() == this.lockedBgColor.to_string()) {
			this.unlockedBgColor = Gdk.RGBA();
			this.unlockedBgColor.parse("#FFFFFF");
		}

		this.unlockButton = new ToolButton(null, null);

		this.openButton = new MenuToolButton.from_stock(Stock.OPEN);
		openButton.tooltip_text = "Change journal folder";
		openButton.clicked.connect(() => {
			this.menuChangeDjDirClicked();
		});

		// Set up Open Journals menu
		this.setOpenJournalsMenuItems();

		this.unlockButton = new ToolButton.from_stock(Stock.EDIT);
		unlockButton.tooltip_text = "Unlock entry";
		unlockButton.clicked.connect(() => {
			this.unlockEntry();
		});

		var addImageButton = new ToolButton.from_stock(Stock.ADD);
		addImageButton.tooltip_text = "Add image to entry";
		addImageButton.clicked.connect(() => {
			this.chooseImage();
		});

		var increaseFontSizeButton = new ToolButton.from_stock(Stock.ZOOM_IN);
		increaseFontSizeButton.tooltip_text = "Increase font size";
		increaseFontSizeButton.clicked.connect(() => {
			this.increaseFontSize();
		});

		var decreaseFontSizeButton = new ToolButton.from_stock(Stock.ZOOM_OUT);
		decreaseFontSizeButton.tooltip_text = "Decrease font size";
		decreaseFontSizeButton.clicked.connect(() => {
			this.decreaseFontSize();
		});

		var settingsMenuButton = new MenuToolButton.from_stock(Stock.INFO);

		// Set up Settings menu
		var settingsMenu = new Gtk.Menu();
		var menuKeyboardShortcutsToolbar = new Gtk.MenuItem.with_label("Keyboard Shortcuts");
		menuKeyboardShortcutsToolbar.activate.connect(() => {
			this.menuKeyboardShortcutsClicked();
		});
		var menuAboutToolbar = new Gtk.MenuItem.with_label("About DayJournal");
		menuAboutToolbar.activate.connect(() => {
			this.menuAboutClicked();
		});

		// Set up Settings menu
		settingsMenu = new Gtk.Menu();

		menuCreateJournalArchive = new Gtk.MenuItem.with_label("Create Complete Journal Archive");
		menuCreateJournalArchive.activate.connect(() => {
			this.createCompleteJournalArchive(JournalArchiver.TYPE_HTML);
		});

		var menuCreateJournalArchiveTxt = new Gtk.MenuItem.with_label("Create Plain Text Journal Archive");
		menuCreateJournalArchiveTxt.activate.connect(() => {
			this.createCompleteJournalArchive(JournalArchiver.TYPE_TEXT);
		});

		menuOpenDjLocation = new Gtk.MenuItem.with_label("View Current Journal Files");
		menuOpenDjLocation.activate.connect(() => {
			menuOpenDjLocationClicked();
		});

		menuLockPastEntries = new CheckMenuItem.with_label("Lock past entries by default");
		menuLockPastEntries.active = UserData.lockPastEntries;
		menuLockPastEntries.toggled.connect(() => {
			this.menuLockPastEntriesToggled(menuLockPastEntries);
		});
		menuIncreaseCalendarFontSize = new Gtk.MenuItem.with_label("Increase calendar size");
		menuIncreaseCalendarFontSize.activate.connect(() => { 
			this.increaseCalendarFontSize(); 
		});
		menuDecreaseCalendarFontSize = new Gtk.MenuItem.with_label("Decrease calendar size");
		menuDecreaseCalendarFontSize.activate.connect(() => { 
			this.decreaseCalendarFontSize(); 
		});
		menuChooseFont = new Gtk.MenuItem.with_label("Change Entry Font...");
		menuChooseFont.activate.connect(() => {
			this.chooseFont();
		});

		settingsMenu.append(menuCreateJournalArchive);
		settingsMenu.append(menuCreateJournalArchiveTxt);
		settingsMenu.append(menuOpenDjLocation);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuChooseFont);
		settingsMenu.append(menuLockPastEntries);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuIncreaseCalendarFontSize);
		settingsMenu.append(menuDecreaseCalendarFontSize);
		settingsMenu.append(new SeparatorMenuItem());
		settingsMenu.append(menuKeyboardShortcutsToolbar);
		settingsMenu.append(menuAboutToolbar);

		settingsMenuButton.set_menu(settingsMenu);

		settingsMenu.show_all();

		settingsMenuButton.clicked.connect(() => {
			this.menuAboutClicked();
		});
		
		headerBar.pack_start(openButton);
		headerBar.pack_start(unlockButton);
		headerBar.pack_start(addImageButton);
		headerBar.pack_end(settingsMenuButton);

		this.entryTextView.buffer.changed.connect(() => { onTextChanged(this.entryTextView.buffer); });
		this.editor = new JournalEditor(this.entryTextView.buffer);
		this.entryTextView.pixels_above_lines = 2;
		this.entryTextView.pixels_below_lines = 2;
		this.entryTextView.pixels_inside_wrap = 4;
		this.entryTextView.wrap_mode = WrapMode.WORD_CHAR;
		this.entryTextView.left_margin = 4;
		this.entryTextView.right_margin = 4;
		this.entryTextView.accepts_tab = true;

		this.scroll = new ScrolledWindow (null, null);
		scroll.shadow_type = ShadowType.ETCHED_OUT;
		scroll.set_policy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
		scroll.min_content_width = 251;
		scroll.min_content_height = 280;
		scroll.add (this.entryTextView);
		scroll.expand = true;

		var entryBox = new Box(Orientation.VERTICAL, 0);
		entryBox.pack_start(scroll, true, true, 0);

		var btnToday = new Button.with_label("Today");
		btnToday.clicked.connect(() => { btnTodayClicked(btnToday); });

		this.calendar = new Calendar();
		this.calendar.expand = false;
		this.resetCalendarFont();
		this.calendar.day_selected.connect(() => { daySelected(); });

		var hbox = new Box(Orientation.HORIZONTAL, 2);
		hbox.pack_start(entryBox, true, true, 2);
		var calendarBox = new Box(Orientation.VERTICAL, 0);
		calendarBox.pack_start(btnToday, false, false, 0);
		calendarBox.pack_start(this.calendar, false, false, 2);
		hbox.pack_start(calendarBox, false, false, 2);

		var vbox = new Box (Orientation.VERTICAL, 0);
		
		vbox.pack_start (hbox, true, true, 2);
		add (vbox);

		this.setDjDirLocationMenuLabel();

		var font = Pango.FontDescription.from_string(UserData.fontString);
		this.entryTextView.override_font(font);

		// Connect keypress signal
		this.key_press_event.connect((window,event) => { return this.onKeyPress(event); });

		this.destroy.connect(() => { this.on_destroy(); });

		this.loadBlips();
		this.goToTodaysEntry();
	}

	private void chooseImage() {
		var fileChooser = new FileChooserDialog("Choose Image", this,
												FileChooserAction.OPEN,
												Stock.CANCEL, ResponseType.CANCEL,
												Stock.OPEN, ResponseType.ACCEPT);
		var filter = new FileFilter();
		filter.set_filter_name("Images");
		filter.add_pixbuf_formats();
		fileChooser.add_filter(filter);
		if (fileChooser.run() == ResponseType.ACCEPT) {
			string imgFilePath = fileChooser.get_filename();
			this.addImageNow(imgFilePath);
		}
		fileChooser.destroy();
	}

	private void addImageNow(string imgFilePath) {
		/* Images! */

		// Copy image file
		var file = File.new_for_path(imgFilePath);
		string fileDestPath = FileUtility.pathCombine(this.entry.monthDirPath, this.entry.getDayString());
		string relativePath = FileUtility.pathCombine(this.entry.archiveRelativeMonthPath, this.entry.getDayString());

		// If file already exists, add timestamp to file name
		fileDestPath = fileDestPath + FileUtility.getFileExtensionFromString(imgFilePath);
		relativePath = relativePath + FileUtility.getFileExtensionFromString(imgFilePath);
		fileDestPath = FileUtility.addTimestampToFilePath(fileDestPath);
		relativePath = FileUtility.addTimestampToFilePath(relativePath);
		
		var destFile = File.new_for_path(fileDestPath);

		// Only do action if destination file does not exist. We don't want to write over any files.
		if (!destFile.query_exists()) {
			file.copy(destFile, FileCopyFlags.NONE);
		}
		
		Image img = new Image.from_file(imgFilePath);
		var anchor = this.editor.getAnchorAtCurrent();


		// resize image first
		var pixbuf = img.pixbuf;
		double w = pixbuf.width;
		double h = pixbuf.height;

		Zystem.debug("w " + w.to_string());
		Zystem.debug("h " + h.to_string());
		Zystem.debug("wwwwwwwwwwwwwwwwwwwww ");
		
		if (w > 400) {
			double newH = (1 - ((w - 400) / w)) * h;
			Zystem.debug("newH " + newH.to_string());
			Zystem.debug("w " + w.to_string());
			var newPixbuf = pixbuf.scale_simple(400, (int)newH, Gdk.InterpType.BILINEAR);
			img.set_from_pixbuf(newPixbuf);
		} else if (h > 400) {
			//
		}
		
		this.entryTextView.add_child_at_anchor(img, anchor);
		img.show_now();

		this.entry.addImage(relativePath, fileDestPath, img, anchor, this.editor.buffer);

//		this.entry.replaceImagesWithTags(this.editor.buffer);

		this.needsSave = true;
		this.autoSave();
	}

	// Change for DayJournal
	private void setOpenJournalsMenuItems() {
		this.openJournalsMenu = new Gtk.Menu();
		
		// Add list of user's journals to menu
		foreach (string s in UserData.getJournalList()) {
			var menuItem = new Gtk.CheckMenuItem.with_label(s);
			menuItem.active = s == UserData.djDirPath;
			menuItem.activate.connect(() => {
				this.setJournalDir(s);
			});
			
			this.openJournalsMenu.append(menuItem);
		}

		// Then, add the "Add" and "Remove" options
		/*var rememberJournal = new Gtk.MenuItem.with_label("Remember current journal");
		rememberJournal.activate.connect(() => { this.rememberCurrentJournal(); });*/
		
		var forgetJournal = new Gtk.MenuItem.with_label("Forget current journal");
		forgetJournal.activate.connect(() => { this.forgetCurrentJournal(); });

		this.openJournalsMenu.append(new Gtk.SeparatorMenuItem());
		this.openJournalsMenu.append(forgetJournal);

		var setAsImport = new CheckMenuItem.with_label("Import mobile entries to this journal");
		setAsImport.active = UserData.currentJournalIsImportJournal();
		setAsImport.toggled.connect(() => {
			this.setCurrentJournalAsImportJournalClicked(setAsImport.active);
		});

		this.openJournalsMenu.append(new Gtk.SeparatorMenuItem());
		this.openJournalsMenu.append(setAsImport);

		this.openButton.set_menu(openJournalsMenu);
		this.journalsMenuItem.set_submenu(openJournalsMenu);
		this.openJournalsMenu.show_all();
	}

	private void setCurrentJournalAsImportJournalClicked(bool importSet) {
		Zystem.debug("Import? " + UserData.importJournalPath);
		Zystem.debug("HELLO THERE IMPORT SET TO " + importSet.to_string());
		if (importSet) {
			UserData.setCurrentJournalAsImportJournal();
		} else {
			UserData.setNoImportJournal();
		}
		Zystem.debug("Import? " + UserData.importJournalPath);
	}

	private void lockEntry() {
		this.entryLocked = true;
		this.entryTextView.editable = false;
		this.entryTextView.cursor_visible = false;
		this.changeEntryBgColor(this.lockedBgColor);
		this.scroll.shadow_type = ShadowType.NONE;

		this.unlockButton.set_sensitive(true);
	}

	private void unlockEntry() {
		this.entryLocked = false;
		this.entryTextView.editable = true;
		this.entryTextView.cursor_visible = true;
		this.changeEntryBgColor(this.unlockedBgColor);
		this.scroll.shadow_type = ShadowType.ETCHED_OUT;

		this.unlockButton.set_sensitive(false);
	}

	/*private void changeEntryBgColor(string hexColor) {
		Gdk.RGBA bgColor = Gdk.RGBA();
		bgColor.parse(hexColor);
		this.entryTextView.override_background_color(Gtk.StateFlags.NORMAL, bgColor);
		this.entryTextView.override_background_color(Gtk.StateFlags.SELECTED, this.originalBgColor);
	}*/

	private void changeEntryBgColor(Gdk.RGBA color) {
		/* //Disabling 
		this.entryTextView.override_background_color(Gtk.StateFlags.NORMAL, color);
		this.entryTextView.override_background_color(Gtk.StateFlags.SELECTED, this.selectionColor);
		 */
	}

	private async void callSave() {
		try {
			//yield this.entry.saveEntryFile(this.editor.getText());
			yield this.entry.saveEntryFile(this.editor.buffer);
			this.needsSave = false;
		} catch (Error e) {
			Zystem.debug("There was an error saving the file.");
		}
	}

	private async void seldomSave() {
//		Zystem.debug("THIS IS A SELDOM SAVE POINT AND needsSave is " + this.needsSave.to_string());
		if (UserData.seldomSave && this.needsSave) {
			this.callSave();
		}
	}

	private void autoSave() {
		if (!UserData.seldomSave) {
			this.callSave();
		}
	}

	/**
	 * Quit DayJournal.
	 */
	public void on_destroy () {
		if (UserData.seldomSave && this.needsSave) {
			Zystem.debug("Saving file on exit.");
			try {
				this.entry.saveEntryFileNonAsync(this.editor.getText());
			} catch (Error e) {
				Zystem.debug("There was an error saving the file.");
			}
		}

		if (!this.forgetUISettings) {
			// Save window size
			Zystem.debug("Width and height: " + this.width.to_string() + " and " + this.height.to_string());
			UserData.saveWindowSize(this.width, this.height);

			// Save font size
//			UserData.saveFontSize(this.fontSize);

			// Save calendar font size
			UserData.saveCalendarFontSize(this.getCalendarFontSize());
		}
		
		Gtk.main_quit();
	}

	private int getCalendarFontSize() {
		return this.calendar.get_pango_context().get_font_description().get_size() / Pango.SCALE;
	}

	public void onTextChanged(TextBuffer buffer) {
		if (!this.isOpening) {
			this.needsSave = true;
			this.autoSave();
		} else {
//			Zystem.debug("Not saving because we're only just opening the file. Saving now is dumb.");
		}
	}

	public void btnTodayClicked(Button button) {
		this.goToTodaysEntry();
	}

	public void daySelected() {

		if (this.entry != null) {
			this.seldomSave();
//			Zystem.debug("Seldom save went swimmingly");
		}

		int year = this.calendar.year;
		int month = this.calendar.month + 1;
		int day = this.calendar.day;

		var now = new DateTime.now_local();
		if (new DateTime.local(year, month, day + 1, 0, 0, 0).compare(now) >= 0) {
			this.unlockEntry();
		} else if (UserData.lockPastEntries) {
			this.lockEntry();
		} else {
			this.unlockEntry();
		}

		this.isOpening = true;
		
		this.entry = new JournalEntry(year, month, day);
		this.editor.startNewEntry(this.entry.getFileContents(), this.entryTextView, this.entry);
		
		this.needsSave = false;

		this.isOpening = false;
		
		this.markEntryDaysOnCalendar();
	}

	/*
	 * Select today in the calendar to switch to today's entry.
	 */
	private void goToTodaysEntry() {
		var dateTime = new DateTime.now_local();
		this.calendar.year = dateTime.get_year();
		this.calendar.month = dateTime.get_month() - 1;
		this.calendar.day = dateTime.get_day_of_month();
	}
	
	public bool onKeyPress(Gdk.EventKey key) {
		uint keyval;
		keyval = key.keyval;
		Gdk.ModifierType state;
		state = key.state;
		bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
		bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

		string keyName = Gdk.keyval_name(keyval);
		
//		Zystem.debug("Key:\t" + keyName);

		if (ctrl && shift) { // Ctrl+Shift+?
			Zystem.debug("Ctrl+Shift+" + keyName);
			switch (keyName) {
				case "Z":
					this.editor.redo();
					break;
				case "plus":
					this.changeCalendarFontSize(1);
					break;
				case "underscore":
					this.changeCalendarFontSize(-1);
					break;
				case "exclam":
					this.askResetSomeSettings();
					break;
				default:
//					Zystem.debug("What should Ctrl+Shift+" + keyName + " do?");
					break;
			}
		}
		else if (ctrl) { // Ctrl+?
			switch (keyName) {
				case "l":
					this.addDaysToSelectedDate(1);
					break;
				case "j":
					this.addDaysToSelectedDate(-1);
					break;
				case "i":
					this.addDaysToSelectedDate(-7);
					break;
				case "k":
					this.addDaysToSelectedDate(7);
					break;
				case "t":
					this.goToTodaysEntry();
					break;
				case "u":
					this.unlockEntry();
					break;
				case "z":
					this.editor.undo();
					break;
				case "y":
					this.editor.redo();
					break;
				case "d":
					if (!this.entryLocked) {
						this.editor.prependDateToEntry(this.entry.getEntryDateHeading());
					}
					break;
				case "n":
					this.tryInsertEntrySection();
					break;
				case "equal":
					this.increaseFontSize();
					break;
				case "minus":
					this.decreaseFontSize();
					break;
				case "0":
//					this.resetFontSize();
					this.clearFontPrefs();
					break;
				case "p":
					this.chooseImage();
					break;
				default:
//					Zystem.debug("What should Ctrl+" + keyName + " do?");
					break;
			}
		}
		else if (!(ctrl || shift || keyName == this.lastKeyName)) { // Just the one key
			switch (keyName) {
				case "period":
				case "Return":
				case "space":
					this.seldomSave();
					break;
				case "Escape":
					this.on_destroy();
					break;
				default:
					break;
			}
		}

		this.lastKeyName = keyName;
		
		// Return false or the entry does not get updated.
		return false;
	}

	/**
	 * 
	 */
	private void tryInsertEntrySection() {
		if (this.entryLocked) {
//			Zystem.debug("Entry is locked, cannot do that");
			return;
		}
		
		/*var dateTime = new DateTime.now_local();

		if (this.entry.year == dateTime.get_year() && this.entry.month == dateTime.get_month() 
													&& this.entry.day == dateTime.get_day_of_month()) {*/
			this.editor.insertAtCursor(UserData.getNewEntrySectionText());
			//this.seldomSave();
		/*} else { 
			Zystem.debug("THAT DID NOT WORK.");
			Zystem.debug(this.entry.month.to_string());
			Zystem.debug(dateTime.get_month().to_string());
		}*/
	}

	/**
	 * Font size methods
	 */
	/*private void resetFontSize() {
		this.changeFontSize(UserData.fontSize - this.fontSize);
	}*/

	private int getFontSize() {
		return this.entryTextView.get_style_context().get_font(StateFlags.NORMAL).get_size() / Pango.SCALE;
	}

	private void increaseFontSize() {
		this.changeFontSize(1);
	}
	private void decreaseFontSize() {
		this.changeFontSize(-1);
	}

	private void changeFontSize(int byThisMuch) {
		int fontSize = this.getFontSize();
		
		// If font would be too small or too big, no way man
		if (fontSize + byThisMuch < 6 || fontSize + byThisMuch > 50) {
//			Zystem.debug("Not changing font size, because it would be: " + fontSize.to_string());
			return;
		}

		fontSize += byThisMuch;
//		Zystem.debug("Changing font size to: " + fontSize.to_string());

		Pango.FontDescription font = this.entryTextView.style.context.get_font(StateFlags.NORMAL);
		double newFontSize = (fontSize) * Pango.SCALE;
		font.set_size((int)newFontSize);
		this.entryTextView.override_font(font);
		UserData.setFont(font.to_string());
	}

	private void clearFontPrefs() {
		UserData.setFont("");
		this.entryTextView.override_font(null);
		this.changeFontSize(10 - this.getFontSize());
	}

	private void chooseFont() {
		Gtk.FontChooserDialog dialog = new Gtk.FontChooserDialog ("Choose Entry Font", this);
		if (dialog.run () == Gtk.ResponseType.OK) {
			UserData.setFont(dialog.font);
			this.entryTextView.override_font(dialog.font_desc);
		}

		// Close the FontChooserDialog
		dialog.close ();
	}

	/*
	 * Add the given number of days to the selected calendar date.
	 */
	private void addDaysToSelectedDate(int days) {
		DateTime dateTime = new DateTime.local(this.calendar.year, this.calendar.month + 1, this.calendar.day, 0, 0, 0);
		dateTime = dateTime.add_days(days);
		this.calendar.year = dateTime.get_year();
		this.calendar.month = dateTime.get_month() - 1;
		this.calendar.day = dateTime.get_day_of_month();
	}

	private async void markEntryDaysOnCalendar() {
		this.calendar.clear_marks();
		ArrayList<int> daysToMark = yield this.getDaysToMark(this.calendar.year, this.calendar.month + 1);
		
		foreach (int day in daysToMark) {
			this.calendar.mark_day(day);
		}
	}

	private async ArrayList<int> getDaysToMark(int year, int month) {
		ArrayList<int> days = new ArrayList<int>(null);

		// See if month directory exists
		var monthDir = File.new_for_path(this.entry.monthDirPath);
		if (monthDir.query_exists()) {
			FileEnumerator enumerator = monthDir.enumerate_children(FILE_ATTRIBUTE_STANDARD_NAME, 0);
			FileInfo file;

			// Go through the files
			while((file = enumerator.next_file()) != null) {
				if (file.get_file_type() == FileType.REGULAR && FileUtility.getFileExtension(file) == ".txt") {
					int day = int.parse(file.get_name().substring(0, file.get_name().last_index_of(".")));
					days.add(day);
				}
			}
		}

		return days;
	}

	public void menuChangeDjDirClicked() {
		var fileChooser = new FileChooserDialog("Open File", this,
												FileChooserAction.SELECT_FOLDER,
												Stock.CANCEL, ResponseType.CANCEL,
												Stock.OPEN, ResponseType.ACCEPT);
		if (fileChooser.run() == ResponseType.ACCEPT) {
			string dirPath = fileChooser.get_filename();
			this.setJournalDir(dirPath);
			this.rememberCurrentJournal();
		}
		fileChooser.destroy();
	}

	private void setJournalDir(string dirPath) {
		UserData.setDjDir(dirPath);
		this.setDjDirLocationMenuLabel();
		this.setOpenJournalsMenuItems();

		this.loadBlips();
		
		// Open new entry for the selected date from the new location
		this.daySelected();
	}

	private void setDjDirLocationMenuLabel() {
		this.menuOpenDjLocation.label = "View Journal Files (" + UserData.djDirPath + ")";
	}

	public void menuOpenDjLocationClicked() {
		try {
			Gtk.show_uri(null, "file://" + UserData.djDirPath, Gdk.CURRENT_TIME);
		} catch (IOError e) {
			var dialog = new Gtk.MessageDialog(null,Gtk.DialogFlags.MODAL,Gtk.MessageType.INFO, 
					Gtk.ButtonsType.OK, "%s", this.getNoEntriesText());
			dialog.set_title("Message Dialog");
			dialog.run();
			dialog.destroy();
		}
	}

	private void createCompleteJournalArchive(string archiveType) {
		var archiver = new JournalArchiver(archiveType);

		archiver.createCompleteArchiveFile();

		string message = archiver.archiveFilePath + " created in your DayJournal folder.";

		Notify.init("DayJournal");
		var notification = new Notify.Notification("Journal Archive File", message, "dayjournal");
//		notification.set_timeout(5000);
		notification.show();
	}

	private void createJournalArchive() {
		// TODO!
		
	}

	private void loadBlips() {
		if (UserData.currentJournalIsImportJournal()) {
			BlipLoader blipLoader = new BlipLoader();
			blipLoader.loadBlips();
		}
	}

	private string getNoEntriesText() {
		return "You do not have any entries yet. \n" 
				+ "Keeping a journal will pay off in the end. You can do it!";
	}

	private void menuAboutClicked() {
		var about = new AboutDialog();
		about.set_program_name("DayJournal");
		about.comments = "Like typing on paper.";
		about.website = "http://burnsoftware.wordpress.com/dayjournal";
		about.logo_icon_name = "dayjournal";
		about.set_copyright("by Zach Burnham");
		about.run();
		about.hide();
	}

	private void menuKeyboardShortcutsClicked() {
		var dialog = new Gtk.MessageDialog(null,Gtk.DialogFlags.MODAL,Gtk.MessageType.INFO, 
						Gtk.ButtonsType.OK, this.shortcutsText);
		dialog.set_title("Message Dialog");
		dialog.run();
		dialog.destroy();
	}

	private void menuLockPastEntriesToggled(CheckMenuItem menu) {
		UserData.setLockPastEntries(menu.active);
	}

	private void rememberCurrentJournal() {
		UserData.rememberCurrentJournal();
		this.setOpenJournalsMenuItems();
	}

	private void forgetCurrentJournal() {
		UserData.forgetCurrentJournal();

		ArrayList<string> journalList = UserData.getJournalList();
		if (journalList.size > 0) {
			this.setJournalDir(journalList.get(0));
			this.setOpenJournalsMenuItems();
		} else {
			this.setJournalDir(UserData.getDefaultDjDir());
			this.rememberCurrentJournal();
		}
	}

	/*
	public void chkMenuSeldomSaveClicked(CheckMenuItem menu) {
		UserData.seldomSave = menu.active;
		Zystem.debug("Seldom Save: " + UserData.seldomSave.to_string());
	}*/

	/*
	private void makeCalendarFontBig() {
		Pango.Context context = new Calendar().get_pango_context();
		Pango.FontDescription tempFont = context.get_font_description();

		double newFontSize = tempFont.get_size() / Pango.SCALE;
		newFontSize = newFontSize + 2;
		newFontSize = newFontSize * Pango.SCALE;
		
		Pango.FontDescription calendarFont = this.calendar.get_pango_context().get_font_description();
		calendarFont.set_size((int)newFontSize);
		this.calendar.override_font(calendarFont);
	}

	private void makeCalendarFontBigger() {
		Pango.Context context = new Calendar().get_pango_context();
		Pango.FontDescription tempFont = context.get_font_description();

		double newFontSize = tempFont.get_size() / Pango.SCALE;
		newFontSize = newFontSize + 4;
		newFontSize = newFontSize * Pango.SCALE;
		
		Pango.FontDescription calendarFont = this.calendar.get_pango_context().get_font_description();
		calendarFont.set_size((int)newFontSize);
		this.calendar.override_font(calendarFont);
	}*/

	private void changeCalendarFontSize(int byThisMuch) {
		Pango.Context context = this.calendar.get_pango_context();
		Pango.FontDescription calendarFont = context.get_font_description();
		
		// Steps to calculate new font size
		double newFontSize = calendarFont.get_size() / Pango.SCALE;
		newFontSize = newFontSize + byThisMuch;
		newFontSize = newFontSize * Pango.SCALE;
		
		calendarFont.set_size((int)newFontSize);
		this.calendar.override_font(calendarFont);
	}

	private void resetCalendarFont() {
		this.changeCalendarFontSize(UserData.calendarFontSize - this.getCalendarFontSize());
	}

	private void increaseCalendarFontSize() {
		this.changeCalendarFontSize(2);
	}
	private void decreaseCalendarFontSize() {
		this.changeCalendarFontSize(-2);
	}

	private void askResetSomeSettings() {
		var dialog = new Gtk.MessageDialog(null,Gtk.DialogFlags.MODAL,Gtk.MessageType.QUESTION, 
						Gtk.ButtonsType.YES_NO, "Do you want to reset the UI settings?");
		dialog.set_title("Reset UI Settings?");
		
		if (dialog.run() == ResponseType.YES) {
			Zystem.debug("Indeed was YES");
			UserData.deleteUISettings();
			this.forgetUISettings = true;
		}
		dialog.destroy();
	}

	/*private void makeCalendarFontSmall() {
		Pango.Context context = new Calendar().get_pango_context();
		Pango.FontDescription tempFont = context.get_font_description();
		Pango.FontDescription fontDesc = this.calendar.get_pango_context().get_font_description();
		//double newFontSize = 10 * Pango.SCALE;
		fontDesc.set_size(tempFont.get_size());
		this.calendar.override_font(fontDesc);
	}*/
	

	/**
	 * Main method.
	 */
	static int main (string[] args) 
	{
		Gtk.init (ref args);

		var window = new Main ();
		window.destroy.connect (Gtk.main_quit);
		window.show_all ();

		Gtk.main ();
		return 0;
	}
}
