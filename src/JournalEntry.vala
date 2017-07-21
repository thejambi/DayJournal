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

using GLib;
using Gtk;

public class JournalEntry : Object {

	string yearDirPath;
	public string archiveRelativeMonthPath { get; private set; }
	public string monthDirPath { get; private set; }
	public string filePath { get; private set; }
	File entryFile;
	private int saveCounter;
	private EntryImageAnchors images;

	public bool fileSavingLock { get; private set; default = false; }
	public bool fileSaveRequested { get; private set; default = false; }

	public DateTime dateTime { get; private set; }
	
	public int year {
		get { return dateTime.get_year(); } 
	}
	public int month {
		get { return dateTime.get_month(); } 
	}
	public int day {
		get { return dateTime.get_day_of_month(); }
	}

	/**
	 * Constructor.
	 */
	public JournalEntry(int year, int month, int day) {

		this.dateTime = new DateTime.local(year, month, day, 0, 0, 0);

		this.yearDirPath = Path.build_path(Path.DIR_SEPARATOR_S, this.getDayJournalDirectory(), year.to_string("%04i"));
		this.monthDirPath = Path.build_path(Path.DIR_SEPARATOR_S, this.yearDirPath, month.to_string("%02i"));
		this.filePath = Path.build_path(Path.DIR_SEPARATOR_S, this.monthDirPath, this.getDayString() + ".txt");
		this.entryFile = File.new_for_path(this.filePath);

		this.archiveRelativeMonthPath = Path.build_path(Path.DIR_SEPARATOR_S, "..", year.to_string("%04i"), month.to_string("%02i"));

		this.saveCounter = 0;

		this.images = new EntryImageAnchors();
	}

	public void addImage(string relativePath, string fullPath, Image img, TextChildAnchor anchor, TextBuffer buffer) {
		this.images.add(relativePath, fullPath, img, anchor, buffer);
	}

	public string replaceImagesWithTags(TextBuffer buffer) {
		var txt = this.images.replaceImagesWithTags(buffer);
		Zystem.debug("Got replaced text: " + txt);
		return txt;
	}

	private string getDayJournalDirectory() {
		return UserData.djDirPath;
	}

	public string getFileContents() {
		try {
			string contents;
			FileUtils.get_contents(this.filePath, out contents);
			return contents;
		} catch(FileError e) {
			return "";
		}
	}

	public async void saveEntryFile(TextBuffer buffer) throws GLib.Error {
		
		var monthDir = File.new_for_path(this.monthDirPath);

		string entryText = this.replaceImagesWithTags(buffer);
		
		if (entryText == "") {
			this.removeEntryFile();
		} else {
			// Make sure monthDirPath exists because it might have been empty and removed
			if (!monthDir.query_exists()) {
				GLib.DirUtils.create_with_parents(this.monthDirPath, 0775);
			}
			yield this.saveFileContentsAsync(entryText);
		}
	}

	private async void saveFileContentsAsync(string entryText) throws GLib.Error {
		yield this.entryFile.replace_contents_async(entryText.data, null, false, FileCreateFlags.NONE, null, null);
		//Zystem.debug("SAVE COUNTER IS: " + (++this.saveCounter).to_string());
	}

	public void saveEntryFileNonAsync(string entryText) throws GLib.Error {
		var monthDir = File.new_for_path(this.monthDirPath);
		
		if (entryText == "") {
			this.removeEntryFile();
		} else {
			// Make sure monthDirPath exists because it might have been empty and removed
			if (!monthDir.query_exists()) {
				GLib.DirUtils.create_with_parents(this.monthDirPath, 0775);
			}
			this.saveFileContents(entryText);
		}
	}

	public void createPath() {
		var monthDir = File.new_for_path(this.monthDirPath);
		
		// Make sure monthDirPath exists because it might have been empty and removed
		if (!monthDir.query_exists()) {
			GLib.DirUtils.create_with_parents(this.monthDirPath, 0775);
		}
	}

	private void saveFileContents(string entryText) throws GLib.Error {
		this.entryFile.replace_contents(entryText.data, null, false, FileCreateFlags.NONE, null, null);
		//Zystem.debug("SAVE COUNTER IS: " + (++this.saveCounter).to_string());
	}

	private void removeEntryFile() {
		Zystem.debug("Should remove file");

		var file = File.new_for_path(this.filePath);

		if (file.query_exists()) {
			try {
				file.delete();
				this.removeMonthDirIfEmpty();
			} catch (Error e) {
				Zystem.debug("There was an error removing the entry file");
			}
		}
	}

	/**
	 * Remove the month directory for the entry if it is empty.
	 */
	private void removeMonthDirIfEmpty() throws GLib.Error {
		if (FileUtility.isDirectoryEmpty(this.monthDirPath)) {
			var monthDir = File.new_for_path(this.monthDirPath);
			monthDir.delete();
			this.removeYearDirIfEmpty();
		}
	}

	/**
	 * Remove the year directory for the entry if it is empty.
	 */
	private void removeYearDirIfEmpty() throws GLib.Error {
		if (FileUtility.isDirectoryEmpty(this.yearDirPath)) {
			var yearDir = File.new_for_path(this.yearDirPath);
			yearDir.delete();
		}
	}

	public string getEntryDateHeading() {
		return dateTime.format("%B %e, %Y\n\n");
	}

	public string getDayString() {
		return day.to_string("%02i");
	}
	
}

