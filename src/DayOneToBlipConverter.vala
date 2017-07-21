/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
/* DayJournal
 *
 * Copyright (C) Zach Burnham 2014 <thejambi@gmail.com>
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

public class DayOneToBlipConverter : GLib.Object {

	private const string ENTRY_TEXT_KEY_TAG = "<key>Entry Text</key>";
	private const string STRING_TAG_START = "<string>";
	private const string STRING_TAG_END = "</string>";
	private const string CREATION_DATE_KEY_TAG = "<key>Creation Date</key>";
	private const string DATE_TAG_START = "<date>";
	private const string DATE_TAG_END = "</date>";

	private string entryPath;
	public BlipData blipData { get; private set; }
	public bool hasPicBlip { get; private set; }
	public BlipData picBlipData { get; private set; }
	public bool photoLoaded { get; private set; default = false; }
	
    // Constructor
    public DayOneToBlipConverter(string dayOneEntryPath) {
        this.entryPath = dayOneEntryPath;

		/* Right now, parse entry, check for photo, etc */
		this.blipData = this.parseEntryToBlip();
    }

	public void loadPhoto() {
		if (this.photoLoaded) {
			return;
		}
		File entryFile = File.new_for_path(this.entryPath);

		FileInfo entryInfo = entryFile.query_info("*",0);
		string photoPath = FileUtility.pathCombine(UserData.getDayOnePhotosDir(), FileUtility.getFileNameWithoutExtension(entryInfo.get_name()));
		photoPath = photoPath + ".jpg";
		File photoFile = File.new_for_path(photoPath);

		this.hasPicBlip = photoFile.query_exists();
		
		if (!this.hasPicBlip) {
			return;
		}

		Zystem.debug("DAY ONE PHOTO FOUND FOR THIS ENTRY! AT " + photoPath);

		FileInfo photoInfo = photoFile.query_info("*",0);
		string filename = photoInfo.get_name();
		// copy image file to journal first.
		var file = File.new_for_path(photoPath);
		JournalEntry picDateEntry = this.blipData.entry;
		picDateEntry.createPath();
		string fileDestPath = picDateEntry.monthDirPath + "/" + this.blipData.dateTime.get_day_of_month().to_string() + "_" + filename;
		string relativePath = picDateEntry.archiveRelativeMonthPath + "/" + this.blipData.dateTime.get_day_of_month().to_string() + "_" + filename;
		Zystem.debug("*****************************Copying from: " + photoPath);
		Zystem.debug("Copying to:   " + fileDestPath);

		var destFile = File.new_for_path(fileDestPath);

		destFile = File.new_for_path(fileDestPath);

		// Only do action if destination file does not exist. We don't want to write over any files.
		if (!destFile.query_exists()) {
			file.copy(destFile, FileCopyFlags.NONE);
		}

		// Load pic blip data
		string blipContents = "\n" + EntryImageAnchors.IMG_TAG_START + relativePath + EntryImageAnchors.IMG_TAG_END;
		this.picBlipData = new BlipData(file, this.blipData.dateTime, blipContents, picDateEntry);
		this.blipData.incrementTimeEverSoSlightly();
		
		this.photoLoaded = true;
	}

	private BlipData parseEntryToBlip() {

//		DateTime dateTime = null;
//		string blipContents = null;
//		JournalEntry entry = null;
		
		// Get file of entryPath
		File entryFile = File.new_for_path(this.entryPath);

		// Get contents of file
		string entryContents = this.getContentText();

		// Get time
		int iDateKeyTag = entryContents.index_of(CREATION_DATE_KEY_TAG);
		int iDateTag = entryContents.index_of(DATE_TAG_START, iDateKeyTag);
		int iEndDateTag = entryContents.index_of(DATE_TAG_END, iDateTag);

		string dateString = entryContents.slice(iDateTag + DATE_TAG_START.length, iEndDateTag);
		Zystem.debug("\nEntry DATE: \n" + dateString + "\n");

		// Now parse date into DateTime
		DateTime dateTime = this.parseDateStringToDateTime(dateString);

		Zystem.debug(dateTime.format("%Y/%m/%d %H:%M:%S"));

		// get entry text
		int iEntryTextKeyTag = entryContents.index_of(ENTRY_TEXT_KEY_TAG, iEndDateTag);
		int iStringTag = entryContents.index_of(STRING_TAG_START, iEntryTextKeyTag);
		int iEndStringTag = entryContents.index_of(STRING_TAG_END, iEntryTextKeyTag);
		
		string blipContents = entryContents.slice(iStringTag + STRING_TAG_START.length, iEndStringTag);

		// get JournalEntry
		var entry = new JournalEntry(dateTime.get_year(), dateTime.get_month(), dateTime.get_day_of_month());

		return new BlipData(entryFile, dateTime, blipContents, entry);
	}

	private string getContentText() {
		try {
			string contents;
			FileUtils.get_contents(this.entryPath, out contents);
			return contents;
		} catch(FileError e) {
			return "";
		}
	}

	private DateTime parseDateStringToDateTime(string dateString) {
		//Example: 2014-03-13T16:08:44Z
		string[] mainChunks = dateString.split("T");

		string[] dateChunks = mainChunks[0].split("-");
		string year = dateChunks[0];
		string month = dateChunks[1];
		string day = dateChunks[2];

		string[] timeChunks = mainChunks[1].split(":");
		string hour = timeChunks[0];
		string minute = timeChunks[1];
		string second = timeChunks[2].slice(0, 2);
		if ("59" == second) {
			second = "58";
		}
		
		try {
			var dateTime = new DateTime.local(int.parse(year), int.parse(month), int.parse(day), 
		                          int.parse(hour), int.parse(minute), int.parse(second));

			// Account for UTC offset
			try {
				dateTime = dateTime.add(dateTime.get_utc_offset());
				return dateTime;
			} catch (Error e) {
				Zystem.debug("Error getting utc offset");
				return dateTime;
			}
		} catch (Error e) {
			Zystem.debug("Error getting time");
			return new DateTime.now_local();
		}

	}

}
