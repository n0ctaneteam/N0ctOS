import { Routes, Route, Navigate } from "react-router-dom";
import { useState, useEffect } from "react";
import Navbar from "./components/Navbar";
import Footer from "./components/Footer";

// Pages
import Home from "./pages/Home";
import Features from "./pages/Features";
import Download from "./pages/Download";
import Docs from "./pages/Docs";
import Team from "./pages/Team";
import NotFound from "./pages/not-found";
import { PageUnderBuild } from "./pageunderbuild";

export function App() {
  return (
    <div className="w-dvw min-h-dvh flex flex-col content-between justify-between gap-0 overflow-hidden bg-background text-foreground selection:bg-primary/30 selection:text-primary transition-colors duration-300">
      <Navbar />
      <div className="px-1 py-5 flex-grow mt-[clamp(50px,10dvh,100px)] ">
      <Routes>
        <Route path="/" element={<Navigate to="/home" replace/>}/>
        <Route path="/home" element={<Home />} />
        <Route path="/features" element={<Features />} />
        <Route path="/download" element={<Download />} />
        <Route path="/docs" element={<Docs />} />
        <Route path="/team" element={<Team />} />
        
        <Route path="*" element={<Navigate to="/notfound" replace/>} />
        <Route path="/notfound" element={<NotFound/>}/>
      </Routes>
      </div>
      <Footer/>
    </div>
  );
}

