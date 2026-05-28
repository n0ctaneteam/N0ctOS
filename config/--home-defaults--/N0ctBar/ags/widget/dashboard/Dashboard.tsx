import app from "ags/gtk4/app"
import { Astal, Gtk, Gdk } from "ags/gtk4"

import "../../config"
import { dash_Margin, dash_Scale } from "../../config"
import { createState, This } from "ags"

const DASH_GAP = 8
const DASH_WIDTH = 700
const DASH_HEIGHT = 400

const TABS=["Home", "Settings", "About"]
const currentTab="Home"
const CONTENT = {
  "Home": "Welcome to the Dashboard!",
  "Settings": "Here you can adjust your preferences.",
  "About": "This dashboard is built with AGS and React!"
}

export default function Dashboard() {
  return (
    <window
      name="dashboard"
      class="Dashboard"
      visible={false}
      layer={Astal.Layer.TOP}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={Astal.WindowAnchor.TOP}
      application={app}

      defaultHeight={DASH_HEIGHT * dash_Scale}
      defaultWidth={DASH_WIDTH * dash_Scale}

      $={(self) => app.add_window(self)}
      css={`margin: ${dash_Margin}px;`}
    >
      <box hexpand>
        {/* left spacer */}
        <box hexpand />

        {/* dashboard body */}
        <box orientation={Gtk.Orientation.VERTICAL}
          class="dashboard"
          spacing={10}
        >
          <box orientation={Gtk.Orientation.HORIZONTAL} spacing={10}>
            {TABS.map((tab) => (
              <button
                label={tab}
              />
            ))} 
          </box> 
          <box> 
            <label label={currentTab} />
            <label label={currentTab} />
          </box>
        </box>

        {/* right spacer */}
        <box hexpand />
      </box>
    </window>
  )
}
