import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import {  Routes, Route , Navigate, BrowserRouter} from "react-router-dom";
import "./index.css";
import "./App.css";

// Import pages
import Home from "./pages/Home";
import Features from "./pages/Features";
import Download from "./pages/Download";
import Team from "./pages/Team";

import { Pageunderbuild } from "./pageunderbuild";

createRoot(document.getElementById("root")!).render(
    <StrictMode>
        <BrowserRouter basename="/N0ctOS">
            <Routes>
                {/*uncomment 1st line and comment the 2nd line, to make the page live*/}
                {/*<Route path="/" element={<Navigate to="/home" replace />} /> // page is ready*/}
                <Route path="/" element={<Navigate to="/wall" replace />} /> // page under dev
                
                <Route path="/home" element={<Home />} />
                <Route path="/features" element={<Features />} />
                <Route path="/download" element={<Download />} />
                <Route path="/team" element={<Team />} />
                
                <Route path="/wall" element={<Pageunderbuild />} /> // show under dev page
            </Routes>
        </BrowserRouter>
    </StrictMode>,
);
