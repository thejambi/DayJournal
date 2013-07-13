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

class UserData : Object {
	//
	public static string homeDirPath { get; private set; }
	public static string defaultDjDirName { get; private set; }
	public static string djDirPath { get; set; }
	public static bool lockPastEntries { get; set; }
	public static bool seldomSave { get; set; }
	public static string newEntrySectionText { get; set; }
	public static int windowWidth { get; set; default = 550; }
	public static int windowHeight { get; set; default = 430; }
	public static int fontSize { get; set; default = 10; }
	public  static const int defaultFontSize = 10;
	public static int calendarFontSize { get; set; }
	
	private static UserSettingsManager settings;

	public static void initializeUserData() {

		defaultDjDirName = "DayJournal";
		/*seldomSave = true;*/
		seldomSave = false;

		homeDirPath = Environment.get_home_dir();

		Zystem.debug("Loading settings...");
		// Fire up the settings
		settings = new UserSettingsManager();
		Zystem.debug("Done Loading settings...");

		if (calendarFontSize < 4) {
			calendarFontSize = new Gtk.Calendar().get_pango_context().get_font_description().get_size() / Pango.SCALE;
		}

		Zystem.debug("Done Loading UserData...");
		Zystem.debug("Lock past entries is: " + lockPastEntries.to_string());
	}

	public static void setDjDir(string path) {
		//
		Zystem.debug("Setting DayJournal directory");
		djDirPath = path;
		settings.setDjDir(path);

		FileUtility.convertToNewJournalStructure();
	}

	public static string getDefaultDjDir() {
		return FileUtility.pathCombine(homeDirPath, defaultDjDirName);
	}

	public static string getNewEntrySectionText() {
		//

		string newSectionText = "\n\n-----\n\n";

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

	public static void saveFontSize(int size) {
		if (fontSize != size) {
			settings.setInt(UserSettingsManager.fontSizeKey, size);
		}
	}

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

	public static ArrayList<string> getJournalList() {
		return settings.getJournalList();
	}

	
}
