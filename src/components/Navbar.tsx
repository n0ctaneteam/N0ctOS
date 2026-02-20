import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Link } from "react-router-dom";

const LOGO_URL = "https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png";

const Navbar = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <motion.header
      className="BAR fixed top-0px justify-center content-center w-dvw h-[clamp(50px,10dvh,10px)] bg-dark-primary/80 backdrop-blur-sm border-b border-primary-500/20 z-50"
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ type: "spring", stiffness: 100, damping: 20 }}
    >
      <nav className="flex py-1 h-full px-[clamp(10px,10rem,20px)] justify-center content-center items-center max-h-full">
        <div className="flex flex-grow justify-between gap-7 items-center w-[clamp(0px,100vdw,500px)]">
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

          {/* Desktop Navigation */}
          <ul className="hidden lg:flex list-none gap-8">
            {["Home", "Features", "Download", "Docs", "Team"].map((item, index) => (
              <motion.li
                key={item}
                initial={{ y: -20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{
                  delay: index * 0.1,
                  duration: 0.3,
                }}
                whileHover={{ scale: 1.1 }}
              >
                <Link
                  to={`/${item.toLowerCase()}`}
                  className="text-gray-400 font-medium transition-all duration-300 hover:text-primary-400 hover:drop-shadow-[0_0_10px_rgba(139,92,246,0.5)] relative group"
                >
                  {item}
                  <span className="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-primary-400 to-secondary-500 group-hover:w-full transition-all duration-300" />
                </Link>
              </motion.li>
            ))}
          </ul>

          {/* Mobile Menu Button */}
          <button
            className="lg:hidden flex flex-col gap-1 bg-transparent border-none cursor-pointer p-3"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <motion.span
              className="w-8 h-1 bg-white block origin-left"
              animate={isMenuOpen ? { rotate: 45, x: 10 } : { rotate: 0, x: 0 }}
              transition={{ duration: 0.3 }}
            />
            <motion.span
              className="w-8 h-1 bg-white block"
              animate={{ opacity: isMenuOpen ? 0 : 1 }}
              transition={{ duration: 0.3 }}
            />
            <motion.span
              className="w-8 h-1 bg-white block origin-left"
              animate={
                isMenuOpen ? { rotate: -45, x: 10 } : { rotate: 0, x: 0 }
              }
              transition={{ duration: 0.3 }}
            />
          </button>
        </div>

        {/* Mobile Navigation */}
        <AnimatePresence>
          {isMenuOpen && (
            <motion.ul
              className="lg:hidden absolute top-full left-0 w-full bg-gradient-to-br from-violet-950 via-slate-950/80 to-slate-950/60 backdrop-blur-3xl border-t border-primary-500/20 flex flex-col p-6 gap-6"
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.3 }}
            >
              {["Home", "Features", "Download", "Docs", "Team"].map((item) => (
                <motion.li key={item} whileTap={{ scale: 0.95 }}>
                  <Link
                    to={`/${item.toLowerCase()}`}
                    className="text-gray-400 font-medium transition-all duration-300 hover:text-primary-400 text-lg block py-3"
                    onClick={() => setIsMenuOpen(false)}
                  >
                    {item}
                  </Link>
                </motion.li>
              ))}
            </motion.ul>
          )}
        </AnimatePresence>
      </nav>
    </motion.header>
  );
};

export default Navbar;
