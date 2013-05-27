/* -*- Mode: vala; tab-width: 4; intend-tabs-mode: t -*- */
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
using Gee;

public class JournalArchiver : GLib.Object {

	// Variables
	private Map<int, YearFolder> yearFolders;
	public string archiveFilePath { get; private set; }
	private string archiveType = "html";
	
    // Constructor
    public JournalArchiver() {
		this.yearFolders = new TreeMap<int, YearFolder>();
		this.archiveFilePath = "";
    }

	/*public void createArchiveFileFromDateRange(DateTime startDate, DateTime endDate) {
		//
	}*/

	public void createCompleteArchiveFile() {
		Zystem.debug("-----\nCREATING JOURNAL ARCHIVE FILE\n-----");

		this.setCompleteArchiveFilename();

		// Make sure archive folder exists
		string path = UserData.getArchiveDirPath();
		FileUtility.createFolder(path);

		try {
			if (this.archiveType == "html") {
				this.beginHtmlArchiveFile();
			}
			
			File djDir = File.new_for_path(UserData.djDirPath);
			FileEnumerator enumerator = djDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			FileInfo fileInfo;

			while ((fileInfo = enumerator.next_file()) != null) {
				// If directory, processYearDir
				if (fileInfo.get_file_type() == FileType.DIRECTORY) {
					File subdir = djDir.resolve_relative_path(fileInfo.get_name());
					processYearDir(fileInfo, subdir);
				}
			}

			this.writeEntriesToArchiveFile();

			if (this.archiveType == "html") {
				this.endHtmlArchiveFile();
			}
		} catch (Error e) {
			stderr.printf("Error creating archive file. Error: %s\n", e.message);
		}
	}

	private void processYearDir(FileInfo yearDirInfo, File yearDir) {
		// Only want if dir name matches ####, so return if not
		if (!GLib.Regex.match_simple("[0-9][0-9][0-9][0-9]", yearDirInfo.get_name())) {
			return;
		}

		Zystem.debug("I found a year folder for " + yearDirInfo.get_name());

		YearFolder yearFolder = new YearFolder(yearDirInfo);
		
		FileEnumerator enumerator = yearDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo fileInfo;
		
		while ((fileInfo = enumerator.next_file()) != null) {
			// If directory, processMonthDir
			if (fileInfo.get_file_type() == FileType.DIRECTORY) {
				File subdir = yearDir.resolve_relative_path(fileInfo.get_name());
				processMonthDir(yearFolder, fileInfo, subdir);
			}
		}

		this.yearFolders.set(int.parse(yearDirInfo.get_name()), yearFolder);
	}

	private void processMonthDir(YearFolder yearFolder, FileInfo monthDirInfo, File monthDir) {
		// Only want if dir name matches ##, so return if not
		if (!GLib.Regex.match_simple("[0-9][0-9]", monthDirInfo.get_name())) {
			return;
		}

		Zystem.debug("I found a month folder for " + monthDirInfo.get_name());

		int month = int.parse(monthDirInfo.get_name());
		int year = yearFolder.year;
		
		MonthFolder monthFolder = new MonthFolder(monthDirInfo);
		
		FileEnumerator enumerator = monthDir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
		FileInfo fileInfo;
		// Go through it
		while ((fileInfo = enumerator.next_file()) != null) {
			// If it's an entry!
			if (fileInfo.get_file_type() == FileType.REGULAR 
			&& GLib.Regex.match_simple("[0-9][0-9].txt", fileInfo.get_name())) {
				Zystem.debug("I hath found unto thee a journal entry file. It hath a name of: " + fileInfo.get_name());
				int day = int.parse(fileInfo.get_name().slice(0, 2));
				Zystem.debug("Here is the day: " + day.to_string());
				var journalEntry = new JournalEntry(year, month, day);
				monthFolder.addEntry(day, journalEntry);
			}
		}

		yearFolder.addMonth(month, monthFolder);
	}

	private void beginHtmlArchiveFile() {
		string path = UserData.getArchiveDirPath();
		path = FileUtility.pathCombine(path, this.archiveFilePath);
		File file = File.new_for_path(path);
		FileOutputStream fileStream = file.append_to(FileCreateFlags.NONE);

		string html = "<html><head><title>Complete Journal Archive</title> ";

		html += "<style> ";
		html += "@media print { .entry { display: block; position: relative; page-break-inside:avoid; page-break-after: auto; } } ";
		html += "body { font-family: Ubuntu,'Droid Sans',Verdana,Geneva,sans-serif; font-size: 1em; } ";
		html += ".entry { margin: 1em 1em 2.5em 1em; line-height: 150%; border-top: 1px solid #555; } ";
		
		html += ".entryHeading { margin-left: 0.5em; margin-bottom: 0.7em; padding: 0 0.7em 1.3em 0.3em; display: block; "; 		html += "float: right; font-size: 1.2em; border-left: 1px solid #555; line-height: 90%; } ";
		
		html += "</style> ";
		html += "</head><body> ";
		
		this.appendStringToArchiveFile(fileStream, html);
	}

	private void endHtmlArchiveFile() {
		string path = UserData.getArchiveDirPath();
		path = FileUtility.pathCombine(path, this.archiveFilePath);
		File file = File.new_for_path(path);
		FileOutputStream fileStream = file.append_to(FileCreateFlags.NONE);

		this.appendStringToArchiveFile(fileStream, "</body></html>");
	}

	private void writeEntriesToArchiveFile() {
		// Get the path and File object
		string path = UserData.getArchiveDirPath();
		path = FileUtility.pathCombine(path, this.archiveFilePath);
		Zystem.debug("Hello. The filename is: " + this.archiveFilePath);
		File file = File.new_for_path(path);
		FileOutputStream fileStream = file.append_to(FileCreateFlags.NONE);

		// Loop it!
		foreach (Map.Entry<int, YearFolder> yearEntry in this.yearFolders.entries) {
//			Zystem.debug(yearEntry.value.year.to_string());
			foreach (Map.Entry<int, MonthFolder> monthEntry in yearEntry.value.monthMap.entries) {
//				Zystem.debug(monthEntry.value.month.to_string());
				foreach (Map.Entry<int, JournalEntry> entryEntry in monthEntry.value.entryMap.entries) {
//					Zystem.debug(entryEntry.value.day.to_string());
					this.writeJournalEntry(fileStream, entryEntry.value);
				}
			}
		}
	}

	private void setCompleteArchiveFilename() {
		string filename = "CompleteJournalArchive_";

		DateTime dateTime = new GLib.DateTime.now_local();
		
//		string timestamp = dateTime.format("%Y%m%d_%H%M%S");
		string timestamp = dateTime.format("%Y-%m-%d");

		if (this.archiveType == "txt") {
			this.archiveFilePath = filename + timestamp + ".txt";
		} else {
			this.archiveFilePath = filename + timestamp + ".html";
		}
	}

	private void writeJournalEntry(FileOutputStream fileStream, JournalEntry entry) {
		if (this.archiveType == "txt") {
			string entryHeading = "\n\n------------------\n";
			entryHeading = entryHeading + entry.year.to_string() + "-" + entry.month.to_string() + "-" + entry.day.to_string();
			entryHeading = entryHeading + "\n----\n\n";

			this.appendStringToArchiveFile(fileStream, entryHeading);
			this.appendStringToArchiveFile(fileStream, entry.getFileContents());
		} else {
			string entryHtml = "<div class='entry'>";
			entryHtml += "<div class='entryHeading'>" + entry.year.to_string() + "-" + entry.month.to_string() + "-" + entry.day.to_string() + "</div>";
			entryHtml += entry.getFileContents().replace("\n", "<br />");
			entryHtml += "</div>";

			this.appendStringToArchiveFile(fileStream, entryHtml);
		}
	}

	private void appendStringToArchiveFile(FileOutputStream fileStream, string text) {
		uint8[] data;
		if (this.archiveType == "html") {
			data = text.replace("’", "&apos;").data;
		} else {
			data = text.data;
		}
        long written = 0;
        while (written < data.length) { 
            // sum of the bytes of 'text' that already have been written to the stream
            written += fileStream.write (data[written:data.length]);
		}
	}
}

/**
 * YearFolder class
 **************************************/
public class YearFolder : GLib.Object {

	public int year { get; private set; }
	public Map<int, MonthFolder> monthMap { get; private set; }
	
	public YearFolder(FileInfo fileInfo) {
		this.year = int.parse(fileInfo.get_name());
		this.monthMap = new TreeMap<int, MonthFolder>();
	}

	public void addMonth(int monthNum, MonthFolder monthFolder) {
		this.monthMap.set(monthNum, monthFolder);
	}
}

/**
 * MonthFolder class
 ***************************************/
public class MonthFolder : GLib.Object {
	
	public int month { get; private set; }
	public Map<int, JournalEntry> entryMap { get; private set; }

	public MonthFolder(FileInfo fileInfo) {
		this.entryMap = new TreeMap<int, JournalEntry>();
		this.month = int.parse(fileInfo.get_name());
	}

	public void addEntry(int day, JournalEntry entry) {
		this.entryMap.set(day, entry);
	}
}
