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

using Gee;

public interface Blip : GLib.Object {

	public abstract DateTime dateTime { get; protected set; }
	public abstract JournalEntry entry { get; protected set; }
	public abstract string amOrPm { get; protected set; }
	public abstract File blipFile { get; protected set; }
	public abstract bool contentsLoaded { get; protected set; default = false; }
	public abstract string blipText { get; protected set; }

	protected abstract string blipString(int numNewLines);
	public abstract BlipData getBlipData();

	protected void initializeEntry(string year, string month, string day) {
		this.entry = new JournalEntry(int.parse(year), int.parse(month), int.parse(day));
		this.entry.createPath();
	}
	
	protected void initializeBlip(string fullPath, string filename, string year, string month, string day) {
		// Create dateTime
		string[] chunks = filename.split("_");

		Zystem.debug("CHUNKS " + chunks.length.to_string());

		var i = 0;
		if (chunks.length > 4) {	// Changing to a 4.
			i++;
		}
		var chunk1 = int.parse(chunks[i++]);
		var chunk2 = int.parse(chunks[i++]);
		var chunk3 = int.parse(chunks[i++]);

		Zystem.debug(chunk1.to_string());
		Zystem.debug(chunk2.to_string());
		Zystem.debug(chunk3.to_string());
		
		this.dateTime = new DateTime.local(int.parse(year), int.parse(month), int.parse(day), 
		                                   chunk1, chunk2, chunk3);
		this.amOrPm = "am";
		if (this.dateTime.get_hour() >= 12) {
			this.amOrPm = "pm";
		}
		Zystem.debug("Blip: " + this.dateTime.format("%Y/%m/%d %I:%M:%S") + amOrPm);

		this.blipFile = File.new_for_path(fullPath);
	}
	
	protected string getFileContents() {
		if (this.contentsLoaded) {
			return this.blipText;
		}
		try {
			string contents;
			FileUtils.get_contents(this.blipFile.get_path(), out contents);
			this.contentsLoaded = true;
			this.blipText = contents;
			return contents;
		} catch(FileError e) {
			return "";
		}
	}

}

public class TextBlip : GLib.Object, Blip {

	public DateTime dateTime { get; protected set; }
	public JournalEntry entry { get; protected set; }
	public string amOrPm { get; protected set; }
	public File blipFile { get; protected set; }
	public bool contentsLoaded { get; protected set; default = false; }
	public string blipText { get; protected set; }
	
    // Constructor
    public TextBlip (string fullPath, string filename, string year, string month, string day) {
		this.initializeEntry(year, month, day);
		this.initializeBlip(fullPath, filename, year, month, day);
    }

	public TextBlip.newStyle (string fullPath, string filename, string year, string month) {
		var day = FileUtility.getNewStyleBlipDay(filename);
		this(fullPath, filename, year, month, day);
	}

	private string blipString(int numNewlines) {
		string blipString = "";
		for (int i = 0; i < numNewlines; i++) {
			blipString += " \n";
		}
		blipString += this.dateTime.format("%l:%M").strip() + amOrPm + " |  ";
		return blipString + this.getFileContents();
	}

	public BlipData getBlipData() {
		return new BlipData(this.blipFile, this.dateTime, this.getFileContents(), this.entry);
	}
}

public class PicBlip : GLib.Object, Blip {

	public DateTime dateTime { get; protected set; }
	public JournalEntry entry { get; protected set; }
	public string amOrPm { get; protected set; }
	public File blipFile { get; protected set; }
	public bool contentsLoaded { get; protected set; default = false; }
	public string blipText { get; protected set; }

//	private string fullPath;
	private string relativePath;
	
    // Constructor
    public PicBlip(string fullPath, string filename, string year, string month, string day) {
		this.initializeEntry(year, month, day);
		
		// copy image file to journal first.
		var file = File.new_for_path(fullPath);
		var picDateEntry = new JournalEntry(int.parse(year), int.parse(month), int.parse(day));
		string fileDestPath = picDateEntry.monthDirPath + "/" + day + "_" + filename;
		this.relativePath = picDateEntry.archiveRelativeMonthPath + "/" + day + "_" + filename;
		Zystem.debug("*****************************Copying from: " + fullPath);
		Zystem.debug("Copying to:   " + fileDestPath);

		var destFile = File.new_for_path(fileDestPath);

		destFile = File.new_for_path(fileDestPath);

		// Only do action if destination file does not exist. We don't want to write over any files.
		if (!destFile.query_exists()) {
			file.copy(destFile, FileCopyFlags.NONE);
		}
		
        this.initializeBlip(fileDestPath, filename, year, month, day);
    }
	public PicBlip.newStyle (string fullPath, string filename, string year, string month) {
		var day = FileUtility.getNewStyleBlipDay(filename);
		this(fullPath, filename, year, month, day);
	}

	private string blipString(int numNewlines) {
		string blipString = "";
		for (int i = 0; i < numNewlines; i++) {
			blipString += " \n";
		}
		blipString += this.dateTime.format("%l:%M").strip() + amOrPm + " |  \n";
		return blipString + EntryImageAnchors.IMG_TAG_START + this.relativePath + EntryImageAnchors.IMG_TAG_END;
	}

	public BlipData getBlipData() {
		string txt = EntryImageAnchors.IMG_TAG_START + this.relativePath + EntryImageAnchors.IMG_TAG_END;
		return new BlipData(this.blipFile, this.dateTime, txt, this.entry);
	}
}

public class BlipData : GLib.Object {

	public DateTime dateTime { get; private set; }
	private string blipContents;
	public JournalEntry entry { get; private set; }
	private File file;
	/*private string amOrPm;*/
	
	public BlipData(File file, DateTime dateTime, string blipContents, JournalEntry entry) {
		this.file = file;
		this.dateTime = dateTime;
		this.blipContents = blipContents;
		this.entry = entry;
	}

	public void incrementTimeEverSoSlightly() {
		this.dateTime = this.dateTime.add_seconds(1.0);
	}

	public static string amOrPm(DateTime dateTime) {
		string amOrPm = "am";
		if (dateTime.get_hour() >= 12) {
			amOrPm = "pm";
		}
		return amOrPm;
	}

	public bool addToCorrespondingEntryIfBetweenDates(DateTime start, DateTime end) {
		//Zystem.debug("Entry contents: " + this.blipContents);
		// If the blip is empty, then don't add it.
		if (this.blipContents.strip() == "") {
			Zystem.debug("EMPTY BLIIIIP I skip: " + this.dateTime.format("%Y/%m/%d %H:%M:%S"));
			return false;
		}

		if (this.dateTime.compare(start) >= 0) {
			Zystem.debug("After start");
		} else if (this.dateTime.compare(end) < 0) {
			//Zystem.debug("Before end");
		}
		
		// Check dates
		if (this.dateTime.compare(start) >= 0 && this.dateTime.compare(end) < 0) {
			// Check entry for.. empty, ends with newline, else
			string contents = this.entry.getFileContents();
			int numNewlines = 2;	// Two is default
			if (contents == "" || contents == null) {
				// Add with no newlines
				numNewlines = 0;
			} else if (contents.has_suffix("\n")) {
				// Add wth one newline
				numNewlines = 1;
			}
			string entryContents = this.entry.getFileContents();
			if (!(this.blipString(0) in entryContents)) {
				this.entry.saveEntryFileNonAsync(entryContents + this.blipString(numNewlines));
			} else {
				Zystem.debug("Entry already contains blip, not saving.");
				return false;   // Not added, return false
			}
			return true;
		}
		return false;
	}

	public void archiveEntryFile() {
		// Move to Archive folder
		Zystem.debug("****************** Archive Blip Entry File Notes ***************");
		Zystem.debug(this.file.get_path());
		if ("Blip Journal" in this.file.get_path()) {
			Zystem.debug("We're talking about Blip Journal!");
			//var newFilePath = FileUtility.addStringToFilePath(this.file.get_path(), "__" + this.dateTime.format("%Y%m%d_%H%M%S"));
			var newFilePath = FileUtility.pathCombine(this.file.get_parent().get_path(), "Archived");
			Zystem.debug(newFilePath);
			FileUtility.moveFile(this.file, this.file.get_parent().get_path(), newFilePath);
		}
	}

	private string blipString(int numNewlines) {
		string blipString = "";
		for (int i = 0; i < numNewlines; i++) {
			blipString += " \n";
		}
		blipString += this.dateTime.format("%l:%M").strip() + amOrPm(this.dateTime) + " |  ";
		return blipString + blipContents;
	}

	public int compare_to(BlipData otherBlip) {
		return this.dateTime.compare(otherBlip.dateTime);
	}
}

