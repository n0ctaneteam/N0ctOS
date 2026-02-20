const isPublic: boolean = true;
// this variable decides if the wall is to be shown or not...
// true: publishes the app to isPublic
// false: replaces everything with wall(pageunderbuild)
// this doesnt even matter which path it is

// some react stuff
import { BrowserRouter } from "react-router-dom";
import { createRoot } from "react-dom/client";
import { StrictMode } from "react";
import "./index.css";

// Import pages
import { App } from "./App";
import { Pageunderbuild } from "./pageunderbuild";
import ScrollToTop from "./components/ScrollToTop";

// import './test.css'

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter basename="/N0ctOS">
      <><ScrollToTop/>{isPublic ? <App /> : <Pageunderbuild />}</> {/*decides what to render*/}
    </BrowserRouter>
  </StrictMode>,
);
