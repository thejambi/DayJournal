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

using Gee;
using Gtk;

public class EntryImageAnchors : GLib.Object {

	public static TextBuffer buffer { get; private set; }

	private GLib.List<ImageAnchorAndFile> imgList;

	public static const string IMG_TAG_START = "<img class='dayjournalimage' src='";
	public static const string IMG_TAG_END = "' />";
	public static const string IMG_TAG_REGEX = EntryImageAnchors.IMG_TAG_START + ".*?" + EntryImageAnchors.IMG_TAG_END;
	
    // Constructor
    public EntryImageAnchors() {
		this.imgList = new GLib.List<ImageAnchorAndFile>();
    }

	public void add(string relativePath, string fullPath, Image img, TextChildAnchor anchor, TextBuffer buffer) {
		this.imgList.append(new ImageAnchorAndFile(relativePath, fullPath, img, anchor));
	}

	public string replaceImagesWithTags(TextBuffer buffer) {
		EntryImageAnchors.buffer = buffer;
		
		if (this.imgList.length() == 0) {
			return buffer.text;
		}
		foreach (ImageAnchorAndFile imgAnchorFile in this.imgList) {
			TextChildAnchor anchor = imgAnchorFile.anchor;
			if (anchor.get_deleted()) {
				// Delete corresponding image file because it's deleted from entry
				Zystem.debug("I am SOOOO removing this image and it's corresponding file. " + imgAnchorFile.fullPath);
				this.imgList.remove(imgAnchorFile);
				imgAnchorFile.deleteFile();
			} else {
				TextIter iter;
				buffer.get_iter_at_child_anchor(out iter, anchor);
				Zystem.debug("Iter offset! :::::: " + iter.get_offset().to_string());
			}
		}
		Zystem.debug("SORTING NOW");
		this.sortList();
		foreach (ImageAnchorAndFile imgAnchorFile in this.imgList) {
			TextChildAnchor anchor = imgAnchorFile.anchor;
			if (!anchor.get_deleted()) {
				TextIter iter;
				buffer.get_iter_at_child_anchor(out iter, anchor);
				Zystem.debug("Iter offset! :::::: " + iter.get_offset().to_string());
			}
		}
		
		string newText = buffer.text;
		uint offsetLength = this.imgList.length() - 1;
		// for each image in map, add text tag for image
		foreach (ImageAnchorAndFile imgAnchorFile in this.imgList) {
			TextChildAnchor anchor = imgAnchorFile.anchor;
			string relativePath = imgAnchorFile.relativePath;
			if (!anchor.get_deleted()) {
				TextIter iter;
				buffer.get_iter_at_child_anchor(out iter, anchor);
				string txt = IMG_TAG_START + relativePath + IMG_TAG_END;
				uint offsetPos = iter.get_offset() - offsetLength;
				var tmp = newText.substring(0, offsetPos) + txt + newText.substring(offsetPos);
				newText = tmp;
				offsetLength--;
			}
		}
		return newText;
	}

	/**
	 * Sort the list.
	 */
	public void sortList() {
		this.imgList.sort((imgAnFile, otherImgAnFile) => {
			return imgAnFile.compare_to(otherImgAnFile);
		});
	}

}

public class ImageAnchorAndFile : GLib.Object, Comparable<ImageAnchorAndFile> {

	public string relativePath { get; private set; }
	public string fullPath { get; private set; }
	public TextChildAnchor anchor { get; private set; }
	public Image img { get; private set; }

	public ImageAnchorAndFile(string relativePath, string fullPath, Image img, TextChildAnchor textAnchor) {
		this.relativePath = relativePath;
		this.fullPath = fullPath;
		this.anchor = textAnchor;
		this.img = img;
	}

	public void deleteFile() {
		var file = File.new_for_path(this.fullPath);
		try {
			file.delete();
		} catch (Error e) {
			Zystem.debug("There was an error removing the image file");
		}
	}

	public int compare_to(ImageAnchorAndFile otherImgAnFile) {
		TextIter iter;
		EntryImageAnchors.buffer.get_iter_at_child_anchor(out iter, this.anchor);
		Zystem.debug("Comparing this:  " + iter.get_offset().to_string());
		int thisOffset = iter.get_offset();
		EntryImageAnchors.buffer.get_iter_at_child_anchor(out iter, otherImgAnFile.anchor);
		Zystem.debug("Comparing other: " + iter.get_offset().to_string());
		int otherOffset = iter.get_offset();
		return otherOffset - thisOffset;
	}
}


/*public class ImageSaveChecker : GLib.Object {
	public static string beforeText { get; set; }
	public static string afterText { get; set; }

	public static bool test() {
		bool theSame = (beforeText == afterText);
		if (theSame) {
			Zystem.debug("GOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOD JOB! EAT THE COOKIES!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
		} else {
			Zystem.debug("D= :( :'( sad\n\n\nTHEY ARE NOT SAME\n\nFAIIIIL");
		}
		return theSame;
	}
}*/
