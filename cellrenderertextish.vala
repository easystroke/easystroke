/* compile with  valac -c cellrenderertextish.vala --pkg gtk+-3.0 -C -H cellrenderertextish.h */

public class CellRendererTextish : Gtk.CellRendererText {
	public enum Mode { Text, Key, Popup, Combo }
        public new Mode mode;
	public string[] items;

	public signal void key_edited(string path, Gdk.ModifierType mods, uint code);
	public signal void combo_edited(string path, uint row);

	private Gtk.CellEditable? cell;

	public CellRendererTextish() {
		mode = Mode.Text;
		cell = null;
		items = null;
	}

	public CellRendererTextish.with_items(string[] items) {
		mode = Mode.Text;
		cell = null;
		this.items = items;
	}

	public override unowned Gtk.CellEditable? start_editing (Gdk.Event? event, Gtk.Widget widget, string path, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
		cell = null;
		if (!editable)
			return cell;
		switch (mode) {
			case Mode.Text:
				cell = base.start_editing(event, widget, path, background_area, cell_area, flags);
				break;
			case Mode.Key:
				cell = new CellEditableAccel(this, path, widget);
				break;
			case Mode.Combo:
				cell = new CellEditableCombo(this, path, widget, items);
				break;
			case Mode.Popup:
				cell = new CellEditableDummy();
				break;
		}
		return cell;
	}
}

class CellEditableDummy : Gtk.EventBox, Gtk.CellEditable {
	public bool editing_canceled { get; set; }
	protected virtual void start_editing(Gdk.Event? event) {
		editing_done();
		remove_widget();
	}
}

class CellEditableAccel : Gtk.EventBox, Gtk.CellEditable {
	public bool editing_canceled { get; set; }
	new CellRendererTextish parent;
	new string path;

	public static string color_to_css(Gdk.RGBA c) {
		return "rgba(" + ((int)(c.red*255)).to_string() + "," + ((int)(c.green*255)).to_string() + "," + ((int)(c.blue*255)).to_string() + "," + c.alpha.to_string() + ")";
	}

	public CellEditableAccel(CellRendererTextish parent, string path, Gtk.Widget widget) {
		this.parent = parent;
		this.path = path;
		editing_done.connect(on_editing_done);
		Gtk.Label label = new Gtk.Label(_("Key combination..."));
		label.set_alignment(0.0f, 0.5f);
		add(label);
		label.get_style_context().add_class("selected-label");
		Gtk.CssProvider css = new Gtk.CssProvider();
		try {
			css.load_from_data(".selected-label { color: " + CellEditableAccel.color_to_css(widget.get_style_context().get_color(Gtk.StateFlags.SELECTED)) + "; }");
		} catch (Error e) {
			warning("Failed to load CSS: %s", e.message);
		}
		label.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		show_all();

		this.draw.connect((cr) => {
			Gtk.StyleContext context = widget.get_style_context();
			Gdk.Rectangle alloc;
			this.get_allocation(out alloc);
			context.save();
			context.set_state(Gtk.StateFlags.SELECTED);
			context.render_background(cr, alloc.x, alloc.y, alloc.width, alloc.height);
			context.restore();
			return false;
		});
	}

	protected virtual void start_editing(Gdk.Event? event) {
		Gtk.grab_add(this);
		
		Gdk.Device? keyboard = get_window().get_display().get_default_seat().get_keyboard();
		if (keyboard != null) {
			keyboard.grab(get_window(), Gdk.GrabOwnership.NONE, false, Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK, null, event != null ? event.get_time() : Gdk.CURRENT_TIME);
		}
		
		key_press_event.connect(on_key);
	}

	bool on_key(Gdk.EventKey event) {
		if (event.is_modifier != 0)
			return true;
		switch (event.keyval) {
			case Gdk.Key.Super_L:
			case Gdk.Key.Super_R:
			case Gdk.Key.Hyper_L:
			case Gdk.Key.Hyper_R:
				return true;
		}
		Gdk.ModifierType mods = event.state & Gtk.accelerator_get_default_mod_mask();

		editing_done();
		remove_widget();

		parent.key_edited(path, mods, event.hardware_keycode);
		return true;
	}
	void on_editing_done() {
		Gtk.grab_remove(this);
		
		Gdk.Device? keyboard = get_window().get_display().get_default_seat().get_keyboard();
		if (keyboard != null) {
			keyboard.ungrab(Gdk.CURRENT_TIME);
		}
	}
}


class CellEditableCombo : Gtk.ComboBoxText, Gtk.CellEditable {
	new CellRendererTextish parent;
	new string path;

	public CellEditableCombo(CellRendererTextish parent, string path, Gtk.Widget widget, string[] items) {
		this.parent = parent;
		this.path = path;
		foreach (string item in items) {
			append_text(_(item));
		}
		changed.connect(() => parent.combo_edited(path, active));
	}
	
	public virtual void start_editing(Gdk.Event? event) {
		base.start_editing(event);
		show_all();
	}
}
