import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"

export default function Live() {
  return (
    <window
      name="live"
      class="Live"
      visible
      layer={Astal.Layer.TOP}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={Astal.WindowAnchor.BOTTOM }
      application={app}
      $={(self) => app.add_window(self)}

      css={`font-size:11px; font-family: "Hurmit Nerd Font Propo"; color: #fcc; background-color: alpha(#3d0000, 0.97); border: 2px solid #f00; padding: 2px 14px; border-radius: 18px 18px 0px 0px; margin: 0px;`}
    >
      <box>
        <label label="AGS running / click to Reload" />
      </box>
    </window>
  )
}