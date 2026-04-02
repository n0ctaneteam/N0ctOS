import { Link, useLocation } from "react-router-dom";
import { motion } from "motion/react";
import { Cpu, Menu, X, Sun, Moon } from "lucide-react";
import { useState, useEffect } from "react";
// import { cn } from "@/src/lib/utils";

const navLinks = [
  { name: "Home", path: "/home" },
  { name: "Features", path: "/features" },
  { name: "Download", path: "/download" },
  { name: "Docs", path: "/docs" },
  { name: "Team", path: "/team" },
];

const LOGO_URL = "./logo-transparent.png";
interface NavbarProps {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

export default function Navbar({ theme, toggleTheme }: NavbarProps) {
  const [isOpen, setIsOpen] = useState(false);
  const location = useLocation();

  useEffect(() => {
    // This code runs every time the location changes (i.e., a route change)
    console.log('Route changed to:', location.pathname);
    setIsOpen(false); // Set the variable to false
  }, [location.pathname]);
  
  return (
    <nav className="fixed top-0 left-0 w-full z-50 bg-background/80 backdrop-blur-md border-b border-foreground/5">
      <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
        {/* Logo */}
          <motion.div
            transition={{
              type: "spring",
              stiffness: 400,
              damping: 25,
            }}
            className="flex flex-grow-0 max-h-full"
          >
            <Link to="/home" className="flex items-center flex-grow-0 w-fit gap-3 max-h-full">
              <img 
                src={LOGO_URL} 
                alt="N0ctOS" 
                className="object-contain max-h-full max-w-36"
              />
              <span className="text-xs text-primary-400 font-mono object-contain">
                v2026.1
              </span>
            </Link>
          </motion.div>

        {/* Desktop Nav */}
        <div className="hidden md:flex items-center gap-8">
          {navLinks.map((link) => (
            <Link
              key={link.path}
              to={link.path}
              className={
                `text-sm font-medium transition-colors hover:text-primary relative py-2 ${location.pathname === link.path ? "text-primary" : "text-muted-foreground"}`
              }
            >
              {link.name}
              {location.pathname === link.path && (
                <motion.div
                  layoutId="nav-underline"
                  className="absolute bottom-0 left-0 w-full h-0.5 bg-primary"
                />
              )}
            </Link>
          ))}
          
          <button
            onClick={toggleTheme}
            className="p-2 rounded-full hover:bg-foreground/5 transition-colors"
            aria-label="Toggle theme"
          >
            {theme === "light" ? <Moon className="w-5 h-5" /> : <Sun className="w-5 h-5" />}
          </button>

          <Link
            to="/download"
            className="bg-primary text-background dark:text-background px-5 py-2 rounded-full text-sm font-bold hover:scale-105 transition-transform"
          >
            Get N0ctOS
          </Link>
        </div>

        {/* Mobile Toggle */}
        <div className="flex items-center gap-4 md:hidden">
          <button
            onClick={toggleTheme}
            className="p-2 rounded-full hover:bg-foreground/5 transition-colors"
            aria-label="Toggle theme"
          >
            {theme === "light" ? <Moon className="w-5 h-5" /> : <Sun className="w-5 h-5" />}
          </button>
          <button className="text-foreground" onClick={() => setIsOpen(!isOpen)}>
            {isOpen ? <X /> : <Menu />}
          </button>
        </div>
      </div>

      {/* Mobile Nav */}
      {isOpen && (
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="md:hidden absolute top-20 left-0 w-full bg-background border-b border-foreground/5 p-6 space-y-4"
        >
          {navLinks.map((link) => (
            <Link
              key={link.path}
              to={link.path}
              onClick={() => setIsOpen(false)}
              className={
                `block text-lg font-medium ${location.pathname === link.path ? "text-primary" : "text-muted-foreground"}`
              }
            >
              {link.name}
            </Link>
          ))}
          <Link
            to="/download"
            onClick={() => setIsOpen(false)}
            className="block bg-primary text-background dark:text-background px-5 py-3 rounded-xl text-center font-bold"
          >
            Get N0ctOS
          </Link>
        </motion.div>
      )}
    </nav>
  );
}
