/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
/* DayJournal
 *
 * Copyright (C) Zach Burnham 2013 <thejambi@gmail.com>
 *
DayJournal is free software: you can redistribute it and/or modify it
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

public class BlipLoader : GLib.Object {

	private DateTime dateBegin { get; private set; }
	private DateTime dateEnd { get; private set; }
	private DateTime lastLoadedBlipDate;

	private string blipDirPath { get; private set; }

	private int numBlipsLoadedForToday;
	private int numBlipsLoaded;
	private bool hasLoaded;

	private List<BlipData> blipDataList;

	public static string decideWhichBlipDirToUse(string dir1, string dir2) {
		BlipLoader bl = new BlipLoader.forLookup(dir1);
		DateTime dir1Date = bl.lookupLastBlipTime();

		bl = new BlipLoader.forLookup(dir2);
		DateTime dir2Date = bl.lookupLastBlipTime();

		Zystem.debug("BlipLoader lookup dir1: " + dir1Date.format("%Y/%m/%d %H:%M:%S"));
		Zystem.debug("BlipLoader lookup dir2: " + dir2Date.format("%Y/%m/%d %H:%M:%S"));

		if (dir1Date.compare(dir2Date) > 0) {
			return dir1;
		} else {
			return dir2;
		}
	}

	public BlipLoader.forLookup(string dir) {

		this.blipDirPath = dir;

		this.dateBegin = new DateTime.now_local();
		this.dateBegin = this.dateBegin.add_weeks(-3);

		// Set dateEnd. It's this very moment.
		this.dateEnd = new DateTime.now_local();

		Zystem.debug("BlipLoader begin for lookup: " + this.dateBegin.format("%Y/%m/%d %H:%M:%S"));
		Zystem.debug("BlipLoader end for lookup: " + this.dateEnd.format("%Y/%m/%d %H:%M:%S"));

		this.numBlipsLoadedForToday = 0;
		this.numBlipsLoaded = 0;
		this.hasLoaded = false;

		this.blipDataList = new List<BlipData>();
	}

    /**
	 * Create BlipLoader. Set dateBegin and dateEnd.
	 */
    public BlipLoader() {
		this.blipDirPath = UserData.blipDirPath;
		Zystem.debug("Blip dir is: " + this.blipDirPath);
		
        // Set dateBegin. It's the exact time from the settings.
		this.dateBegin = new DateTime.from_unix_local(UserData.lastBlipLoadDate);

		// Set dateEnd. It's this very moment.
		// Let's try right now instead.
		this.dateEnd = new DateTime.now_local();

		Zystem.debug("BlipLoader begin: " + this.dateBegin.format("%Y/%m/%d %H:%M:%S"));
		Zystem.debug("BlipLoader end: " + this.dateEnd.format("%Y/%m/%d %H:%M:%S"));

		this.numBlipsLoadedForToday = 0;
		this.numBlipsLoaded = 0;
		this.hasLoaded = false;

		this.blipDataList = new List<BlipData>();
    }

	public DateTime lookupLastBlipTime() {
		processBlipDir();
		this.sortBlips();
		this.loadLastBlipTimeFromList();
		return this.lastLoadedBlipDate;
	}

	public void loadBlips() {
		if (this.hasLoaded) {
			return;
		}
		this.hasLoaded = true;
		Zystem.debug("Commence blip loading.");

		// Go through blip dir (der!)
		try {
			processBlipDir();
			processDayOneDir();
			this.sortBlips();
			this.loadAllBlipsInList();
			Zystem.debug("Blip loading sequence complete.");
			// Success, save date to settings
			//UserData.setLastBlipLoadDateToYesterday();
			if (this.numBlipsLoadedForToday > 0 && this.numBlipsLoaded > 0) {
				Zystem.debug("Loaded blips for today");
				UserData.setLastBlipLoadDate(this.lastLoadedBlipDate);
			} else if (this.numBlipsLoaded > 0) {
				Zystem.debug("Other blips before today were loaded");
//				UserData.setLastBlipLoadDateToYesterday();
				UserData.setLastBlipLoadDate(this.lastLoadedBlipDate);
			}
			if (this.numBlipsLoaded == 1) {
				UserData.showNotification("Blip Entries Loaded", "Latest blip entry was loaded into DayJournal.");
			} else if (this.numBlipsLoaded > 1) {
				UserData.showNotification("Blip Entries Loaded", this.numBlipsLoaded.to_string() + " blip entries were loaded into your DayJournal entries.");
			}
		} catch (Error e) {
			UserData.showNotification("Blip loading error", "Error loading latest blip entries. Sorry! Please contact via the website if you would like help.");
			Zystem.debug("Error processing blips.");
		}

		Zystem.debug("Loaded this many blips from today: " + this.numBlipsLoadedForToday.to_string());
	}

	private void processBlipDir() throws GLib.Error {
		if (!FileUtility.isDirectory(this.blipDirPath)) {
			return; // No Blip dir to process.
		}
		// Loop through directory. 4 digit folders are are years.

		File blipDir = File.new_for_path(this.blipDirPath);
		FileEnumerator enumerator = blipDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo file;

		// Go through the files
		while((file = enumerator.next_file()) != null) {
			if (file.get_file_type() == FileType.DIRECTORY && file.get_name().length == 4) {
				Zystem.debug("Year dir found: " + file.get_name());
				processYearDir(FileUtility.pathCombine(this.blipDirPath, file.get_name()), file.get_name());
			}
		}
	}

	private void processYearDir(string path, string year) throws GLib.Error {
		var pathTime = new DateTime.local(int.parse(year),12,31,24,0,0);
		//Zystem.debug(pathTime.format("%Y/%m/%d %H:%M:%S"));
		//Zystem.debug(this.dateBegin.format("%Y/%m/%d %H:%M:%S"));
		if (this.dateBegin.compare(pathTime) > 0) {
			return;
		}
		
		// Loop through directory to find month dirs
		File yearDir = File.new_for_path(path);
		FileEnumerator enumerator = yearDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo file;

		// Go through files
		while((file = enumerator.next_file()) != null) {
			if (file.get_file_type() == FileType.DIRECTORY && file.get_name().length == 2) {
				Zystem.debug("Month dir found: " + file.get_name());
				processMonthDir(FileUtility.pathCombine(path, file.get_name()), year, file.get_name());
			}
		}
	}

	private void processMonthDir(string path, string year, string month) throws GLib.Error {
		var pathTime = new DateTime.local(int.parse(year),int.parse(month),31,24,0,0);
		//Zystem.debug(pathTime.format("%Y/%m/%d %H:%M:%S"));
		//Zystem.debug(this.dateBegin.format("%Y/%m/%d %H:%M:%S"));
		if (this.dateBegin.compare(pathTime) > 0) {
			return;
		}
		
		// Loop through directory to find day dirs
		File yearDir = File.new_for_path(path);
		FileEnumerator enumerator = yearDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo file;

		// Go through files
		while((file = enumerator.next_file()) != null) {
			Zystem.debug("Looking for files in Month Dir");
			Zystem.debug(file.get_name());
			// Check for Day dirs
			if (file.get_file_type() == FileType.DIRECTORY && file.get_name().length == 2) {
				Zystem.debug("Day dir found: " + file.get_name());
				processDayDir(FileUtility.pathCombine(path, file.get_name()), year, month, file.get_name());
			}

			// Check for new Blip Journal entry files
			if (file.get_file_type() == FileType.REGULAR && file.get_name().length == 19 
			    && FileUtility.getFileExtension(file) == ".txt") {
				grabNewBlipFile(FileUtility.pathCombine(path, file.get_name()), file.get_name(), year, month);
			} else if (file.get_file_type() == FileType.REGULAR && file.get_name().length == 19
			    && FileUtility.isImageFile(file)) {
				grabNewPicBlipFile(FileUtility.pathCombine(path, file.get_name()), file.get_name(), year, month);
			}
		}
	}

	private void processDayDir(string path, string year, string month, string day) throws GLib.Error {
		var pathTime = new DateTime.local(int.parse(year),int.parse(month),int.parse(day),24,0,0);
		//Zystem.debug(pathTime.format("%Y/%m/%d %H:%M:%S"));
		//Zystem.debug(this.dateBegin.format("%Y/%m/%d %H:%M:%S"));
		Zystem.debug("-----PROCESSING DAY DIR----------");
		if (this.dateBegin.compare(pathTime) > 0) {
			return;
		}
		
		// Loop through directory to find day dirs
		File yearDir = File.new_for_path(path);
		FileEnumerator enumerator = yearDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo file;

		// Go through files
		// 08_04_39_325.txt is an example blip file name
		while((file = enumerator.next_file()) != null) {
			if (file.get_file_type() == FileType.REGULAR && file.get_name().length == 16 
			    && FileUtility.getFileExtension(file) == ".txt") {
				//Zystem.debug("Blip found: " + file.get_name());
				grabBlipFile(FileUtility.pathCombine(path, file.get_name()), file.get_name(), year, month, day);
			} else if (file.get_file_type() == FileType.REGULAR && file.get_name().length == 16
			    && FileUtility.isImageFile(file)) {
				grabPicBlipFile(FileUtility.pathCombine(path, file.get_name()), file.get_name(), year, month, day);
			}
		}
	}

	private void grabBlipFile(string path, string filename, string year, string month, string day) throws GLib.Error {
		Blip blip = new TextBlip(path, filename, year, month, day);
		this.blipDataList.append(blip.getBlipData());
	}

	private void grabPicBlipFile(string path, string filename, string year, string month, string day) throws GLib.Error {
		Blip blip = new PicBlip(path, filename, year, month, day);
		this.blipDataList.append(blip.getBlipData());
	}

	private void grabNewBlipFile(string path, string filename, string year, string month) throws GLib.Error {
		Blip blip = new TextBlip.newStyle(path, filename, year, month);
		this.blipDataList.append(blip.getBlipData());
	}

	private void grabNewPicBlipFile(string path, string filename, string year, string month) throws GLib.Error {
		Blip blip = new PicBlip.newStyle(path, filename, year, month);
		this.blipDataList.append(blip.getBlipData());
	}

	private void loadAllBlipsInList() {

		foreach (BlipData blip in this.blipDataList) {
			bool added = blip.addToCorrespondingEntryIfBetweenDates(this.dateBegin, this.dateEnd);

			if (added) {
				this.numBlipsLoaded++;
				
				if (this.dateEnd.format("%Y%m%d") == blip.dateTime.format("%Y%m%d")) {
					this.numBlipsLoadedForToday++;
				}

				// keep most recent blip date
				this.lastLoadedBlipDate = blip.dateTime.add_seconds(1);

				// Archive blip entry file
				//blip.archiveEntryFile();  // Doesn't work well with Blip Journal app
			}
		}
	}

	/**
	 * This needs to process Day One dir and convert entries into Blips and add them.
	 */
	private void processDayOneDir() {
		if (!FileUtility.isDirectory(UserData.getDayOneEntriesDir()) || !FileUtility.isDirectory(UserData.getDayOnePhotosDir())) {
			return; // No Day One dir to process.
		}
		// Loop through directory to find day dirs
		File entriesDir = File.new_for_path(UserData.getDayOneEntriesDir());
		File photosDir = File.new_for_path(UserData.getDayOnePhotosDir());
		FileEnumerator enumerator = entriesDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo file;

		// Go through files
		while((file = enumerator.next_file()) != null) {
			if (file.get_file_type() == FileType.REGULAR && FileUtility.getFileExtension(file) == ".doentry") {
				Zystem.debug("Day One entry found: " + file.get_name());
				var converter = new DayOneToBlipConverter(FileUtility.pathCombine(UserData.getDayOneEntriesDir(), file.get_name()));

				// Skip if before begin date
				if (this.dateBegin.compare(converter.blipData.dateTime) > 0) {
					Zystem.debug("SKIPPING BECAUSE OLD DAY ONE ENTRY");
					continue;
				}

				converter.loadPhoto();
				
				if (converter.hasPicBlip) {
					this.blipDataList.append(converter.picBlipData);
				}
				this.blipDataList.append(converter.blipData);
			}
		}
	}

	private void loadLastBlipTimeFromList() {
		foreach (BlipData blip in this.blipDataList) {
			// keep most recent blip date
			this.lastLoadedBlipDate = blip.dateTime.add_seconds(1);
		}
	}

	/**
	 * Sort the list of blips.
	 */
	public void sortBlips() {
		this.blipDataList.sort((blip, otherBlip) => {
			return blip.compare_to(otherBlip);
		});
	}

}
