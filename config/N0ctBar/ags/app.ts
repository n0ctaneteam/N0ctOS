import app from "ags/gtk4/app"
import style from "./styling/style.scss"
import Dashboard from "./widget/dashboard/Dashboard"
import Live from "./widget/live"
import { Astal, Gtk, Gdk } from "ags/gtk4"


app.start({
  css: style,
  main() {
    Dashboard()
    Live()
  },
})
