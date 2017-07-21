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
using Gtk;
using GLib;

public class JournalEditor : Object {

	public TextBuffer buffer { get; private set; }

	private int undoMax;

	private ArrayList<Action> undos;
	private ArrayList<Action> redos;

	private ulong onInsertConnection;
	private ulong onDeleteConnection;

	/**
	 * Constructor for JournalEditor.
	 */
	public JournalEditor(TextBuffer buffer) {
		this.buffer = buffer;

		this.undoMax = 1000;

		this.undos = new ArrayList<Action>();
		this.redos = new ArrayList<Action>();

		this.connectSignals();
	}

	private TextIter getStartIter() {
		TextIter startIter;
		this.buffer.get_start_iter(out startIter);
		return startIter;
	}

	private TextIter getEndIter() {
		TextIter endIter;
		this.buffer.get_end_iter(out endIter);
		return endIter;
	}

	public string getText() {
		return buffer.text;
	}

	private string scrubText(string text) {
		return text.replace("’", "'");
	}

	private int getOffsetForText(string target, int startingAt) {
		for (int offset = startingAt; offset < this.buffer.text.length - target.length; offset++) {
			var iter1 = this.getIterAtOffset(offset);
			var iter2 = this.getIterAtOffset(offset + target.length);
			var text1 = this.buffer.get_text(iter1, iter2, false);

			if (target == text1) {
				Zystem.debug("target found! " + offset.to_string());
				return offset;
			}
		}
		return -1;
	}

	/*
	 * Start working on a new entry. Sets the passed in text as the buffer text and handles images.
	 */
	public void startNewEntry(string origText, TextView textView, JournalEntry entry) {
		string text = origText;
		
		this.undos.clear();
		this.redos.clear();

		this.disconnectSignals();
		
		this.buffer.set_text(this.scrubText(text));

		text = this.buffer.text;

		int i = this.getOffsetForText(EntryImageAnchors.IMG_TAG_START, 0);
		int iEnd = 0;
		while (i >= 0) {
			iEnd = this.getOffsetForText(EntryImageAnchors.IMG_TAG_END, i);

			// if iEnd < 0 that's bad
			iEnd += EntryImageAnchors.IMG_TAG_END.length;
			Zystem.debug("IMAGE FOUND AT " + i.to_string() + " to " + iEnd.to_string());
			
			var iIter = this.getIterAtOffset(i);
			var iEndIter = this.getIterAtOffset(iEnd);
			var tagText = this.buffer.get_text(iIter, iEndIter, false);
			Zystem.debug(tagText);

			var relativePath = FileUtility.getPathFromImgTag(tagText);
			var fullPath = relativePath.replace("..", UserData.djDirPath);
			
			if (tagText.has_prefix(EntryImageAnchors.IMG_TAG_START)
			    && tagText.has_suffix(EntryImageAnchors.IMG_TAG_END)) {
				
				this.buffer.delete(ref iIter, ref iEndIter);
				this.addImageAtIterForEntry(entry, textView, relativePath, fullPath, this.getIterAtOffset(i));
				i++;
				i = this.getOffsetForText(EntryImageAnchors.IMG_TAG_START, i);
			} else {
				Zystem.debug("Image tag not aligned with Iters, skipping all");
				Zystem.debug(tagText);
				break;
			}
		}

		this.connectSignals();
	}

	private void addImageAtIterForEntry(JournalEntry entry, TextView textView, string relativePath, string imgFilePath, 
	                                    TextIter imgIter) {
		Zystem.debug(relativePath);
		Zystem.debug(imgFilePath);

		Image img = new Image.from_file(imgFilePath);
		var anchor = this.buffer.create_child_anchor(imgIter);

		// resize image first
		var pixbuf = img.pixbuf;
		double w = pixbuf.width;
		double h = pixbuf.height;

		/*
		Zystem.debug("w " + w.to_string());
		Zystem.debug("h " + h.to_string());
		*/
		
		if (w > 400) {
			double newH = (1 - ((w - 400) / w)) * h;
			/*Zystem.debug("newH " + newH.to_string());
			Zystem.debug("w " + w.to_string());*/
			var newPixbuf = pixbuf.scale_simple(400, (int)newH, Gdk.InterpType.BILINEAR);
			img.set_from_pixbuf(newPixbuf);
		} else if (h > 400) {
			// Nothing
		}
		
		textView.add_child_at_anchor(img, anchor);
		img.show_now();

		entry.addImage(relativePath, imgFilePath, img, anchor, this.buffer);
	}

	private TextIter getIterAtOffset(int offset) {
		TextIter iter;
		this.buffer.get_iter_at_offset(out iter, offset);
		return iter;
	}

	public void append(string text) {
		TextIter iter = this.getEndIter();
		this.buffer.insert(ref iter, text, text.length);
	}

	public void prepend(string text) {
		TextIter startIter = this.getStartIter();
		this.buffer.insert(ref startIter, text, text.length);
	}

	public void prependDateToEntry(string dateHeading) {
		if (!this.buffer.text.has_prefix(dateHeading.strip())) {
			this.prepend(dateHeading);
		}
	}

	public void insertAtCursor(string text) {
		TextIter startIter = this.getCurrentIter();
		this.buffer.insert(ref startIter, text, text.length);
	}

	public void cursorToEnd() {
		this.buffer.place_cursor(this.getEndIter());
	}

	public void cursorToStart() {
		this.buffer.place_cursor(this.getStartIter());
	}

	public TextChildAnchor getAnchorAtCurrent() {
		return this.buffer.create_child_anchor(this.getCurrentIter());
	}

	private TextIter getCurrentIter() {
		TextIter iter;
		this.buffer.get_iter_at_offset(out iter, this.buffer.cursor_position);
		return iter;
	}

	private void highlight() {
		//

		TextIter startIter = this.getStartIter();
		TextIter endIter = this.getEndIter();
//		string text = this.buffer.get_text(startIter, endIter, false);
		this.buffer.remove_all_tags(startIter, endIter);
//		foreach (string s in this.highlightStrings) {
			//
			
//		}
	}

	/*public void addHighlight(string text) {
		if (!this.highlightStrings.contains(text)) {
			this.highlightStrings.add(text);
		}

		this.highlight();
	}*/

	/*public void clearHighlight(string text) {
		if (this.highlightStrings.contains(text)) {
			this.highlightStrings.remove(text);
		}

		this.highlight();
	}*/

	/*public void clearAllHighlights() {
		this.highlightStrings = new ArrayList<string>();
		this.highlight();
	}*/

	public void undo() {
		//
		if (this.undos.size == 0) {
			Zystem.debug("Nothing to undo");
			return;
		}

		this.disconnectSignals();

		Action undo = this.undos.last();
		Action redo = this.doAction(undo);
		this.redos.add(redo);
		this.undos.remove(undo);

		this.connectSignals();
	}

	public Action doAction(Action action) {
		//
		if (action.action == "delete") {
			TextIter start = this.getIterAtOffset(action.offset);
			TextIter end = this.getIterAtOffset(action.offset + action.text.length);
			this.buffer.delete(ref start, ref end);
			action.action = "insert";
		} else if (action.action == "insert") {
			TextIter start = this.getIterAtOffset(action.offset);
			TextIter end = this.getIterAtOffset(action.offset + action.text.length);
			this.buffer.insert(ref start, action.text, action.text.length);
			action.action = "delete";
		}

		return action;
	}

	public void redo() {
		//

		if (this.redos.size == 0) {
			Zystem.debug("Nothing to redo");
			return;
		}

		this.disconnectSignals();

		Action redo = this.redos.last();
		Action undo = this.doAction(redo);
		this.undos.add(undo);
		this.redos.remove(redo);

		this.connectSignals();

		this.highlight();
	}

	private void onInsertText(TextIter iter, string text, int length) {
		
		this.highlight();

		Action cmd = new Action("delete", iter.get_offset(), text);
		this.undos.add(cmd);
		this.redos.clear();
	}

	private void onDeleteRange(TextIter startIter, TextIter endIter) {
		Zystem.debug("In onDeleteRange()");

		this.highlight();

		string text = this.buffer.get_text(startIter, endIter, false);
		Zystem.debug("Text was: " + text);
		Action cmd = new Action("insert", startIter.get_offset(), text);
		this.addUndo(cmd);
	}

	private void addUndo(Action cmd) {

		if (this.undos.size >= this.undoMax) {
			// TODO
		}

		this.undos.add(cmd);
	}

	private void connectSignals() {
		//
		this.onInsertConnection = 
			this.buffer.insert_text.connect((ref iter,text,length) => { this.onInsertText(iter, text, length); });
		this.onDeleteConnection =
			this.buffer.delete_range.connect((startIter,endIter) => { this.onDeleteRange(startIter, endIter); });
	}

	private void disconnectSignals() {
		//
		this.buffer.disconnect(this.onInsertConnection);
		this.buffer.disconnect(this.onDeleteConnection);
	}

}

public class Action {

	public string action { get; set; }
	public string text { get; set; }
	public int offset { get; set; }

	public Action(string action, int offset, string text) {
		this.action = action;
		this.text = text;
		this.offset = offset;
	}

}
