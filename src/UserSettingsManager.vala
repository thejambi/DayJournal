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



/**
 * Manages User's Settings. This class deals with interactions with
 * data in the DayFolder settings file.
 */
class UserSettingsManager : Object {

	// Instance variables
	KeyFile keyFile;
	string djConfPath;

	public static const string djDirKey = "djDirectory";
	public static const string djGroup = "DayJournal";
	public static const string lockPastEntriesKey = "lockPastEntries";
	public static const string windowWidthKey = "width";
	public static const string windowHeightKey = "height";
	public static const string calendarFontSizeKey = "calFontSize";
	public static const string fontSizeKey = "fontSize";
	public static const string journalsGroup = "Journals";

	/**
	 * Constructor.
	 */
	public UserSettingsManager() {

		// Make sure the settings folder exists
		string settingsDirPath = UserData.homeDirPath + "/.config/dayjournal";
		FileUtility.createFolder(settingsDirPath);

		// Get path to dayjournal.conf file
		this.djConfPath = settingsDirPath + "/dayjournal.conf";

		// Make sure that settings files exist
		File settingsFile = File.new_for_path(this.djConfPath);

		if (!settingsFile.query_exists()) {
			try {
				settingsFile.create(FileCreateFlags.NONE);
			} catch(Error e) {
				stderr.printf ("Error creating settings file: %s\n", e.message);
			}
		}

		// Initialize variables
		keyFile = new KeyFile();

		try {
			keyFile.load_from_file(this.djConfPath, 0);
		} catch(Error e) {
			stderr.printf ("Error in UserSettingsManager(): %s\n", e.message);
		}

		// Process keyFile and save keyFile to disk if needed
		if (processKeyFile()) {
			this.writeKeyFile();
		}
	}

	/**
	 * Process the key file. Return true if keyFile needs to be written.
	 */
	private bool processKeyFile() {
		string originalKeyFileData = keyFile.to_data();

		try {
			UserData.djDirPath = keyFile.get_string(djGroup , djDirKey);
		} catch (KeyFileError e) {
			// Set default
			UserData.djDirPath = UserData.getDefaultDjDir();
		}

		try {
			UserData.lockPastEntries = keyFile.get_boolean(djGroup , lockPastEntriesKey);
		} catch (KeyFileError e) {
			// Return default
			UserData.lockPastEntries = true;
		}

		try {
			UserData.windowWidth = keyFile.get_integer(djGroup , windowWidthKey);
			UserData.windowHeight = keyFile.get_integer(djGroup , windowHeightKey);
		} catch (KeyFileError e) {
			Zystem.debug("Error loading window size; using default.");
		}

		try {
			UserData.calendarFontSize = keyFile.get_integer(djGroup , calendarFontSizeKey);
		} catch (KeyFileError e) {
			Zystem.debug("No saved calendar font size.");
		}

		try {
			UserData.fontSize = keyFile.get_integer(djGroup , fontSizeKey);
		} catch (KeyFileError e) {
			Zystem.debug("No saved font size.");
		}
		
		// Return true if the keyFile data has been updated (if it's no longer the same as it was)
		return originalKeyFileData != keyFile.to_data();
	}

	public void setDjDir(string path) {
		keyFile.set_string(djGroup , this.djDirKey, path);
		writeKeyFile();
	}

	public void setLockPastEntries(bool lockEm) {
		keyFile.set_boolean(djGroup , this.lockPastEntriesKey, lockEm);
		writeKeyFile();
	}

	// public bool getLockPastEntries() {
	// 	return keyFile.get_boolean(djGroup , this.lockPastEntriesKey);
	// }

	/**
	 * Write settings file.
	 */
	private void writeKeyFile() {
		try {
			FileUtils.set_contents(this.djConfPath, this.keyFile.to_data());
			Zystem.debug("Wrote KeyFile");
		} catch(Error e) {
			stderr.printf("Error writing keyFile: %s\n", e.message);
		}
	}

	public void setInt(string key, int val) {
		keyFile.set_integer(djGroup , key, val);
		writeKeyFile();
	}

	public void deleteUISettings() {
		try {
			keyFile.remove_key(djGroup, windowWidthKey);
			keyFile.remove_key(djGroup, windowHeightKey);
			keyFile.remove_key(djGroup, calendarFontSizeKey);
			keyFile.remove_key(djGroup, fontSizeKey);
			this.writeKeyFile();
		} catch (KeyFileError e) {
			Zystem.debug("Failed to delete some settings.");
		}
	}

	public void addJournal(string name, string path) {
		keyFile.set_string(this.journalsGroup, name, path);
		writeKeyFile();
	}

	public void removeJournal(string name) {
		keyFile.remove_key(this.journalsGroup, name);
		writeKeyFile();
	}

	public ArrayList<string> getJournalList() {
		var list = new ArrayList<string>();

		foreach (string s in keyFile.get_keys(this.journalsGroup)) {
			list.add(s);
		}

		return list;
	}

}
