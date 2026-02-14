import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Link } from 'react-router-dom';

const Navbar = () => {
  const [isMenuOpen, setIsMenuOpen] = useState(false);

  return (
    <motion.header 
      className="fixed top-0 w-full bg-dark-primary/80 backdrop-blur-xl border-b border-primary-500/20 z-50"
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ type: "spring", stiffness: 100, damping: 20 }}
    >
      <nav className="container py-4">
        <div className="flex justify-between items-center">
          {/* Logo */}
          <motion.div 
            whileHover={{ scale: 1.05 }}
            transition={{ type: "spring", stiffness: 400, damping: 25 }}
          >
            <Link to="/" className="flex flex-col">
              <h1 className="text-3xl font-black bg-gradient-to-r from-primary-400 via-primary-500 to-secondary-500 bg-clip-text text-transparent">
                N0ctOS
              </h1>
              <span className="text-xs text-primary-400 font-mono">v2026.1</span>
            </Link>
          </motion.div>

          {/* Desktop Navigation */}
          <ul className="hidden lg:flex list-none gap-8">
            {['Home', 'Features', 'Download', 'Team'].map((item, index) => (
              <motion.li
                key={item}
                initial={{ y: -20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: index * 0.1, duration: 0.3 }}
                whileHover={{ scale: 1.1 }}
              >
                <Link 
                  to={`/${item.toLowerCase()}`}
                  className="text-gray-400 font-medium transition-all duration-300 hover:text-primary-400 hover:drop-shadow-[0_0_10px_rgba(0,212,255,0.5)] relative group"
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
              animate={isMenuOpen ? { rotate: -45, x: 10 } : { rotate: 0, x: 0 }}
              transition={{ duration: 0.3 }}
            />
          </button>
        </div>

        {/* Mobile Navigation */}
        <AnimatePresence>
          {isMenuOpen && (
            <motion.ul 
              className="lg:hidden absolute top-full left-0 w-full bg-dark-secondary/95 backdrop-blur-xl border-t border-primary-500/20 flex flex-col p-6 gap-6"
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: 'auto', opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.3 }}
            >
              {['Home', 'Features', 'Download', 'Team'].map((item) => (
                <motion.li
                  key={item}
                  whileTap={{ scale: 0.95 }}
                >
                  <Link 
                    to={item === 'Home' ? '/' : `/${item.toLowerCase()}`}
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
