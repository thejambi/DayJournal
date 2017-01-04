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
using Notify;

class UserData : Object {
	//
	public static string homeDirPath { get; private set; }
	public static string defaultDjDirName { get; private set; }
	public static string djDirPath { get; set; }
	public static string importJournalPath { get; set; }
	public static string blipDirPath { get; set; }
	public static int64 lastBlipLoadDate { get; set; }
	public static bool lockPastEntries { get; set; }
	public static bool seldomSave { get; set; }
	public static string newEntrySectionText { get; set; }
	public static int windowWidth { get; set; default = 550; }
	public static int windowHeight { get; set; default = 430; }
	public static int fontSize { get; set; default = 10; }
	public  static const int defaultFontSize = 10;
	public static int calendarFontSize { get; set; }
	public static bool rememberCurrentJournalAfterInit { get; set; default = false; }
	public static string fontString { get; set; default = ""; }
	
	private static UserSettingsManager settings;

	public static void initializeUserData() {

		defaultDjDirName = "DayJournal";
		/*seldomSave = true;*/
		seldomSave = false;

		homeDirPath = Environment.get_home_dir();

		Zystem.debug("Loading settings...");
		// Fire up the settings
		settings = new UserSettingsManager();
		if (importJournalPath == null || importJournalPath == "") {
			setCurrentJournalAsImportJournal();
		}
		Zystem.debug("Done Loading settings...");

		if (calendarFontSize < 4) {
			calendarFontSize = new Gtk.Calendar().get_pango_context().get_font_description().get_size() / Pango.SCALE;
		}

		if (blipDirPath == "") {
			loadBlipDir();
		}

		Zystem.debug("Import? " + UserData.importJournalPath);

		if (rememberCurrentJournalAfterInit) {
			UserData.rememberCurrentJournal();
		}
	}

	private static void loadBlipDir() {
		bool hasDbxBlipJournal = false;
		bool hasU1BlipJournal = false;
		string blipPathDbx = FileUtility.pathCombine(homeDirPath, "Dropbox");
		blipPathDbx = FileUtility.pathCombine(FileUtility.pathCombine(blipPathDbx, "Apps"), "Blip Journal");
		
		if (FileUtility.isDirectory(blipPathDbx)) {
			hasDbxBlipJournal = true;
			Zystem.debug("YAYYYYYYYYYYYYYY Dropbox Blip dir path found: " + blipPathDbx);
		}

		string blipPathU1 = FileUtility.pathCombine(homeDirPath, "Ubuntu One");
		blipPathU1 = FileUtility.pathCombine(blipPathU1, ".Blip Journal");

		if (FileUtility.isDirectory(blipPathU1)) {
			hasU1BlipJournal = true;
			Zystem.debug("U1 Blip Journal path: " + blipPathU1);
		}

		if (hasDbxBlipJournal && hasU1BlipJournal) {
			// Need to ask
			// How about we just find out ourselves before asking?
			blipDirPath = BlipLoader.decideWhichBlipDirToUse(blipPathDbx, blipPathU1);
		} else if (hasDbxBlipJournal) {
			// use dropbox
			blipDirPath = blipPathDbx;
		} else if (hasU1BlipJournal) {
			// use u1
			blipDirPath = blipPathU1;
		} else {
			// No blip dir :(
			blipDirPath = "";
		}

		settings.setString(UserSettingsManager.blipDirKey, blipDirPath);
	}

	public static void setDjDir(string path) {
		//
		Zystem.debug("Setting DayJournal directory");
		djDirPath = path;
		settings.setDjDir(path);

		// NOTE: We are no longer attempting to convert the old journal! Remember that please.
		/* FileUtility.convertToNewJournalStructure(); */
	}

	public static string getDefaultDjDir() {
		return FileUtility.pathCombine(homeDirPath, defaultDjDirName);
	}

	public static string getNewEntrySectionText() {
		var dateTime = new DateTime.now_local();
		string newSectionText = "\n\n" + dateTime.format("%l:%M").strip() + BlipData.amOrPm(dateTime) + " |  ";
//		string newSectionText = "\n\n-----\n\n";

		return newSectionText;
	}

	public static void setLockPastEntries(bool lockEm) {
		settings.setLockPastEntries(lockEm);
		lockPastEntries = lockEm;
	}

	public static void saveWindowSize(int width, int height) {
		Zystem.debug(width.to_string() + " and the height: " + height.to_string());
		if (windowWidth != width) {
			settings.setInt(UserSettingsManager.windowWidthKey, width);
		}
		if (windowHeight != height) {
			settings.setInt(UserSettingsManager.windowHeightKey, height);
		}
	}

	/*public static void saveFontSize(int size) {
		if (fontSize != size) {
			settings.setInt(UserSettingsManager.fontSizeKey, size);
		}
	}*/

	public static void saveCalendarFontSize(int size) {
		if (calendarFontSize != size) {
			settings.setInt(UserSettingsManager.calendarFontSizeKey, size);
		}
	}

	public static string getArchiveDirPath() {
		return FileUtility.pathCombine(UserData.djDirPath, "Journal Archives");
	}

	public static void deleteUISettings() {
		settings.deleteUISettings();
	}

	public static void rememberCurrentJournal() {
		settings.addJournal(djDirPath, djDirPath);
	}

	public static void forgetCurrentJournal() {
		settings.removeJournal(djDirPath);
	}

	public static void setCurrentJournalAsImportJournal() {
		importJournalPath = djDirPath;
		settings.setString(UserSettingsManager.importJournalDirKey, djDirPath);
	}

	public static void setNoImportJournal() {
		importJournalPath = UserSettingsManager.NONE;
		settings.setString(UserSettingsManager.importJournalDirKey, UserSettingsManager.NONE);
	}

	public static bool currentJournalIsImportJournal() {
		return djDirPath == importJournalPath;
	}

	public static ArrayList<string> getJournalList() {
		return settings.getJournalList();
	}

	public static void setLastBlipLoadDateToYesterday() {
		var today = new DateTime.now_local();
		var time = new DateTime.local(today.get_year(), today.get_month(), today.get_day_of_month(), 0,0,0);
		string timeStr = time.to_unix().to_string();
		settings.setString(UserSettingsManager.lastBlipLoadDateKey, timeStr);
	}

	public static void setLastBlipLoadDate(DateTime time) {
		string timeStr = time.to_unix().to_string();
		settings.setString(UserSettingsManager.lastBlipLoadDateKey, timeStr);
	}

	public static void showNotification(string title, string message) {
		Notify.init("DayJournal");
		var notification = new Notify.Notification(title, message, "dayjournal");
		notification.show();
	}

	public static string getDayOneEntriesDir() {
		return FileUtility.pathCombine(homeDirPath, "Dropbox/Apps/Day One/Journal.dayone/entries");
	}

	public static string getDayOnePhotosDir() {
		return FileUtility.pathCombine(homeDirPath, "Dropbox/Apps/Day One/Journal.dayone/photos");
	}

	public static void setFont(string fontStr) {
		settings.setString(UserSettingsManager.fontKey, fontStr);
		fontString = fontStr;
	}
	
}
