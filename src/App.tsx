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
  const [theme, setTheme] = useState<"light" | "dark">(() => {
    const saved = localStorage.getItem("theme");
    if (saved) return saved as "light" | "dark";
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  });

  useEffect(() => {
    document.documentElement.classList.toggle("dark", theme === "dark");
    localStorage.setItem("theme", theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => (prev === "light" ? "dark" : "light"));
  };

  return (
    <div className="min-h-screen bg-background text-foreground selection:bg-primary/30 selection:text-primary transition-colors duration-300">
      <Navbar theme={theme} toggleTheme={toggleTheme} />
      
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

      <Footer />
    </div>
  );
}

