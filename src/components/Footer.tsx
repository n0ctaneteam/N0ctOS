import { motion } from 'framer-motion';
import { Link } from 'react-router-dom';

const Footer = () => {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-dark-secondary border-t border-gray-800 relative z-10">
      <div className="container py-8">
        <div className="flex flex-col md:flex-row justify-between items-center gap-4">
          {/* Brand */}
          <Link to="/" className="text-2xl font-black bg-gradient-to-r from-primary-400 to-secondary-500 bg-clip-text text-transparent">
            N0ctOS
          </Link>

          {/* Links */}
          <div className="flex gap-6">
            <Link to="/features" className="text-gray-400 hover:text-primary-400 transition-colors text-sm">Features</Link>
            <Link to="/download" className="text-gray-400 hover:text-primary-400 transition-colors text-sm">Download</Link>
            <Link to="/team" className="text-gray-400 hover:text-primary-400 transition-colors text-sm">Team</Link>
          </div>

          {/* GitHub */}
          <motion.div whileHover={{ scale: 1.1 }}>
            <a
              href="https://github.com/n0ctaneteam"
              target="_blank"
              rel="noopener noreferrer"
              className="text-gray-400 hover:text-primary-400 transition-colors"
            >
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.44 9.8 8.2 11.37.6.1.82-.27.82-.6v-2.2c-3.34.73-4.04-1.6-4.04-1.6-.55-1.4-1.33-1.77-1.33-1.77-1.09-.75.08-.73.08-.73 1.2.09 1.84 1.24 1.84 1.24 1.07 1.84 2.8 1.3 3.49 1 .1-.78.42-1.3.76-1.6-2.67-.3-5.47-1.33-5.47-5.93 0-1.3.47-2.38 1.24-3.22-.13-.3-.54-1.52.12-3.17 0 0 1-.33 3.3 1.23a11.5 11.5 0 0 1 6 0c2.28-1.56 3.29-1.23 3.29-1.23.66 1.65.24 2.87.12 3.17.77.84 1.24 1.9 1.24 3.22 0 4.6-2.8 5.63-5.48 5.92.43.37.82 1.1.82 2.22v3.3c0 .32.22.7.82.58C20.56 21.8 24 17.3 24 12c0-6.63-5.37-12-12-12z"/>
              </svg>
            </a>
          </motion.div>
        </div>

        {/* Copyright */}
        <div className="text-center mt-6 pt-6 border-t border-gray-800">
          <p className="text-gray-500 text-xs">
            © {currentYear} N0ctOS. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;
