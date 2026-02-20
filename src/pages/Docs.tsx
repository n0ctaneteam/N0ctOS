import { motion } from "framer-motion";
import { useState } from "react";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

const LOGO_URL = "https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png";

const Quick_Links=[
  { icon: "📥", title: "Download", desc: "Get N0ctOS" },
  { icon: "🚀", title: "Quick Start", desc: "5 min setup" },
  { icon: "💬", title: "Community", desc: "Get help" },
]

const docsSections = [
  {
    title: "Getting Started",
    items: [
      { name: "Installation Guide", desc: "Step-by-step installation instructions" },
      { name: "System Requirements", desc: "Hardware and software prerequisites" },
      { name: "First Boot", desc: "What to expect on your first boot" },
    ],
  },
  {
    title: "Core Features",
    items: [
      { name: "Quantum Core", desc: "Understanding the quantum optimization engine" },
      { name: "AI Integration", desc: "Built-in AI assistants and automation" },
      { name: "Security Model", desc: "Zero-trust security architecture" },
    ],
  },
  {
    title: "Development",
    items: [
      { name: "Building Packages", desc: "Create and distribute N0ctOS packages" },
      { name: "API Reference", desc: "System APIs and integration points" },
      { name: "Contributing", desc: "How to contribute to N0ctOS" },
    ],
  },
];

function Docs() {
  const [searchQuery, setSearchQuery] = useState("");

  // Filter sections based on search query
  const filteredSections = docsSections.map((section) => ({
    ...section,
    items: section.items.filter(
      (item) =>
        item.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        item.desc.toLowerCase().includes(searchQuery.toLowerCase())
    ),
  })).filter((section) => section.items.length > 0);

  return (
    <div className=" text-white font-tektur flex flex-col">
      <main className="flex-grow py-24">
        <div className="container max-w-6xl">
          {/* Header */}
          <motion.div
            className="text-center mb-16"
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
          >
            <img 
              src={LOGO_URL} 
              alt="N0ctOS Logo" 
              className="w-[clamp(100px,100%,400px)] object-contain mx-auto mb-6 drop-shadow-[0_0_20px_rgba(139,92,246,0.5)]"
            />
            <h1 className="text-5xl md:text-6xl font-bold mb-4 bg-gradient-to-r from-primary-400 to-secondary-500 bg-clip-text text-transparent">
              Documentation
            </h1>
            <p className="text-xl text-gray-400 max-w-2xl mx-auto">
              Everything you need to know about N0ctOS - from installation to advanced configuration.
            </p>
          </motion.div>

          {/* Search Bar */}
          <motion.div
            className="max-w-2xl mx-auto mb-12"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2, duration: 0.5 }}
          >
            <div className="relative">
              <input
                type="text"
                placeholder="Search documentation..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-dark-secondary border border-gray-700 rounded-xl px-6 py-4 pl-12 text-white placeholder-gray-500 focus:outline-none focus:border-primary-500 transition-colors"
              />
              <svg
                className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
            </div>
          </motion.div>

          {/* Quick Links */}
          <motion.div
            className="grid md:grid-cols-3 gap-6 mb-16"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.3, duration: 0.5 }}
          >
            {Quick_Links.map((item, i) => (
              <motion.div
                key={item.title}
                className="bg-dark-secondary/50 border border-gray-800 rounded-xl p-6 hover:border-primary-500/50 transition-all cursor-pointer group"
                whileHover={{ y: -4 }}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 + i * 0.1 }}
              >
                <div className="text-3xl mb-3">{item.icon}</div>
                <h3 className="text-xl font-bold text-white group-hover:text-primary-400 transition-colors">
                  {item.title}
                </h3>
                <p className="text-gray-500">{item.desc}</p>
              </motion.div>
            ))}
          </motion.div>

          {/* Documentation Sections */}
          <div className="grid md:grid-cols-3 gap-8">
            {filteredSections.map((section, sectionIndex) => (
              <motion.div
                key={section.title}
                className="bg-dark-secondary/30 border border-gray-800 rounded-2xl p-6"
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.4 + sectionIndex * 0.1, duration: 0.5 }}
              >
                <h2 className="text-2xl font-bold mb-6 text-primary-400">
                  {section.title}
                </h2>
                <ul className="space-y-4">
                  {section.items.map((item, itemIndex) => (
                    <motion.li
                      key={item.name}
                      className="group cursor-pointer"
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: 0.5 + sectionIndex * 0.1 + itemIndex * 0.05 }}
                    >
                      <div className="flex items-start gap-3">
                        <span className="text-primary-500 mt-1 group-hover:translate-x-1 transition-transform">
                          →
                        </span>
                        <div>
                          <h3 className="font-semibold text-white group-hover:text-primary-400 transition-colors">
                            {item.name}
                          </h3>
                          <p className="text-sm text-gray-500">{item.desc}</p>
                        </div>
                      </div>
                    </motion.li>
                  ))}
                </ul>
              </motion.div>
            ))}
          </div>

          {/* Version Info */}
          <motion.div
            className="mt-16 text-center"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.8 }}
          >
            <p className="text-gray-600">
              Documentation version: 2026.1 | Last updated: February 2026
            </p>
          </motion.div>
        </div>
      </main>
    </div>
  );
}

export default Docs;
