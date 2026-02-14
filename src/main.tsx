import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route , Navigate} from "react-router-dom";
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
                {/*uncomment the line below, to make the page live*/}
                {/*<Route path="/" element={<Navigate to="/home" replace />} /> // when page is ready*/}
                <Route path="/" element={<Pageunderbuild />} /> // for building the App
                
                <Route path="/home" element={<Home />} />
                <Route path="/features" element={<Features />} />
                <Route path="/download" element={<Download />} />
                <Route path="/team" element={<Team />} />
            </Routes>
        </BrowserRouter>
    </StrictMode>,
);
