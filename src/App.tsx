import { useState } from 'react'
import { motion, AnimatePresence, useScroll, useTransform } from 'framer-motion'
import './App.css'

function App() {
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const { scrollY } = useScroll()
  
  const heroY = useTransform(scrollY, [0, 1000], [0, -200])
  const featuresY = useTransform(scrollY, [0, 1000], [0, -100])
  
  // Optimized particles
  const particles = Array.from({ length: 20 }, (_, i) => ({ id: i }))

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.2,
      },
    },
  }

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: {
        type: "spring",
        stiffness: 100,
        damping: 20,
      },
    },
  }

  return (
    <div className="min-h-screen bg-dark-primary text-white overflow-hidden relative font-tektur">
      {/* Optimized particle background */}
      <div className="fixed inset-0 pointer-events-none">
        {particles.map((particle) => (
          <motion.div
            key={particle.id}
            className="absolute w-1 h-1 bg-primary-500 rounded-full opacity-30 gpu-accelerated"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
            }}
            animate={{
              y: [0, -40, 0],
              x: [0, Math.random() * 40 - 20, 0],
              opacity: [0.1, 0.3, 0.1],
            }}
            transition={{
              duration: Math.random() * 6 + 4,
              repeat: Infinity,
              ease: "easeInOut",
            }}
          />
        ))}
      </div>

      <motion.header 
        className="fixed top-0 w-full bg-dark-primary/80 backdrop-blur-xl border-b border-primary-500/20 z-50 gpu-accelerated"
        initial={{ y: -100 }}
        animate={{ y: 0 }}
        transition={{ type: "spring", stiffness: 100, damping: 20 }}
      >
        <nav className="py-6">
          <div className="container flex justify-between items-center">
            <motion.div 
              className="logo"
              whileHover={{ scale: 1.05 }}
              transition={{ type: "spring", stiffness: 400, damping: 25 }}
            >
              <h1 className="text-4xl font-black bg-gradient-to-r from-primary-400 via-primary-500 to-secondary-500 bg-clip-text text-transparent animate-pulse">
                N0ctOS
              </h1>
              <div className="text-xs text-primary-400 font-mono mt-1">v2026.1</div>
            </motion.div>

            <ul className="hidden lg:flex list-none gap-8">
              {['Home', 'Features', 'Download', 'Team'].map((item, index) => (
                <motion.li
                  key={item}
                  initial={{ y: -20, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  transition={{ delay: index * 0.1, duration: 0.3 }}
                  whileHover={{ scale: 1.1 }}
                >
                  <a 
                    href={`#${item.toLowerCase()}`}
                    className="text-gray-400 font-medium transition-all duration-300 hover:text-primary-400 hover:drop-shadow-[0_0_10px_rgba(0,212,255,0.5)] relative group"
                  >
                    {item}
                    <motion.div
                      className="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-primary-400 to-secondary-500"
                      whileHover={{ width: '100%' }}
                      transition={{ duration: 0.3 }}
                    />
                  </a>
                </motion.li>
              ))}
            </ul>

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
                      <a 
                        href={`#${item.toLowerCase()}`}
                        className="text-gray-400 font-medium transition-all duration-300 hover:text-primary-400 text-lg block py-3"
                        onClick={() => setIsMenuOpen(false)}
                      >
                        {item}
                      </a>
                    </motion.li>
                  ))}
                </motion.ul>
              )}
            </AnimatePresence>
          </div>
        </nav>
      </motion.header>

      <main>
        <section id="home" className="min-h-screen flex items-center px-4 relative">
          <motion.div 
            className="absolute inset-0 bg-gradient-radial opacity-50"
            style={{ y: heroY }}
          />
          
          <div className="container grid lg:grid-cols-2 gap-16 items-center relative z-20">
            <motion.div 
              className="hero-content"
              initial={{ x: -100, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ duration: 0.8, damping: 25 }}
            >
              <motion.div
                className="inline-flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/30 rounded-full px-4 py-2 mb-6"
                initial={{ opacity: 0, scale: 0.8 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.5, duration: 0.5 }}
              >
                <div className="w-2 h-2 bg-yellow-400 rounded-full animate-pulse" />
                <span className="text-yellow-400 text-sm font-medium">🚧 Work in Progress</span>
              </motion.div>

              <motion.h1 
                className="text-6xl md:text-8xl font-black mb-6 leading-tight"
                initial={{ y: 30, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.2, duration: 0.6 }}
              >
                <span className="bg-gradient-to-r from-primary-400 via-primary-500 to-secondary-500 bg-clip-text text-transparent">
                  N0ct
                </span>
                <motion.span 
                  className="bg-gradient-to-r from-secondary-500 to-accent bg-clip-text text-transparent"
                  animate={{ 
                    textShadow: [
                      "0 0 20px rgba(255, 107, 53, 0.5)",
                      "0 0 40px rgba(255, 107, 53, 0.8)",
                      "0 0 20px rgba(255, 107, 53, 0.5)"
                    ]
                  }}
                  transition={{ duration: 2, repeat: Infinity }}
                >
                  OS
                </motion.span>
              </motion.h1>
              
              <motion.p 
                className="text-2xl md:text-3xl text-primary-400 font-bold mb-4"
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.3, duration: 0.6 }}
              >
                The Future of Linux is Here
              </motion.p>
              
              <motion.p 
                className="text-lg text-gray-400 mb-8 leading-relaxed"
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.4, duration: 0.6 }}
              >
                Experience quantum-level performance with our revolutionary Arch-based distribution. 
                Built for developers, designed for humans, optimized for 2026.
              </motion.p>
              
              <motion.div 
                className="flex flex-wrap gap-4"
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: 0.5, duration: 0.6 }}
              >
                <motion.a 
                  href="#download" 
                  className="btn btn-primary relative overflow-hidden group"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <span className="relative z-10 flex items-center gap-2">
                    <span className="text-xl">🚧</span>
                    Join Development
                  </span>
                  <motion.div
                    className="absolute inset-0 bg-gradient-to-r from-yellow-500 to-orange-500"
                    initial={{ x: '-100%' }}
                    whileHover={{ x: '0%' }}
                    transition={{ duration: 0.3 }}
                  />
                </motion.a>
                
                <motion.a 
                  href="#features" 
                  className="btn btn-secondary border-2 border-primary-500/50 hover:border-primary-400"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <span className="flex items-center gap-2">
                    <span className="text-xl">🚀</span>
                    Explore Features
                  </span>
                </motion.a>
              </motion.div>

              <motion.div 
                className="flex gap-6 mt-8"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.8, duration: 1 }}
              >
                <div className="text-center">
                  <div className="text-3xl font-bold text-primary-400">10x</div>
                  <div className="text-sm text-gray-500">Faster Boot</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-primary-400">50%</div>
                  <div className="text-sm text-gray-500">Less Memory</div>
                </div>
                <div className="text-center">
                  <div className="text-3xl font-bold text-primary-400">99.9%</div>
                  <div className="text-sm text-gray-500">Uptime</div>
                </div>
              </motion.div>
            </motion.div>

            <motion.div 
              className="hero-visual flex justify-center lg:justify-end"
              initial={{ x: 100, opacity: 0 }}
              animate={{ x: 0, opacity: 1 }}
              transition={{ duration: 0.8, delay: 0.2, damping: 25 }}
            >
              <motion.div 
                className="relative"
                animate={{ 
                  rotate: [0, 2, -2, 0],
                  y: [0, -10, 0],
                }}
                transition={{ 
                  duration: 4,
                  repeat: Infinity,
                  ease: "easeInOut"
                }}
              >
                <motion.div
                  className="absolute inset-0 w-96 h-96 bg-primary-500/20 rounded-full blur-3xl"
                  animate={{
                    scale: [1, 1.2, 1],
                    opacity: [0.3, 0.6, 0.3],
                  }}
                  transition={{
                    duration: 3,
                    repeat: Infinity,
                    ease: "easeInOut"
                  }}
                />
                
                <motion.div 
                  className="terminal relative z-10"
                  style={{
                    boxShadow: '0 25px 50px rgba(0, 212, 255, 0.3), 0 0 100px rgba(0, 212, 255, 0.1)',
                  }}
                >
                  <div className="terminal-header bg-gradient-to-r from-dark-tertiary to-dark-secondary">
                    <div className="terminal-buttons">
                      <span className="btn-close shadow-lg shadow-red-500/50"></span>
                      <span className="btn-minimize shadow-lg shadow-yellow-500/50"></span>
                      <span className="btn-maximize shadow-lg shadow-green-500/50"></span>
                    </div>
                    <div className="terminal-title text-primary-400 font-mono">n0ctos@quantum-installer</div>
                  </div>
                  <div className="terminal-body bg-dark-secondary/90 backdrop-blur">
                    <motion.div 
                      className="terminal-line text-primary-400"
                      initial={{ width: 0 }}
                      animate={{ width: '100%' }}
                      transition={{ delay: 1, duration: 2 }}
                    >
                      $ sudo ./quantum-install.sh --2026
                    </motion.div>
                    <motion.div 
                      className="terminal-line text-gray-400"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: 3, duration: 0.5 }}
                    >
                      🚀 Initializing quantum core...
                    </motion.div>
                    <motion.div 
                      className="terminal-line text-gray-400"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: 4, duration: 0.5 }}
                    >
                      ⚡ Optimizing neural pathways...
                    </motion.div>
                    <motion.div 
                      className="terminal-line success text-green-400 font-bold"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: 5, duration: 0.5 }}
                    >
                      ✓ N0ctOS 2026 installed successfully!
                    </motion.div>
                    <motion.div 
                      className="terminal-line text-primary-400 animate-pulse"
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: 6, duration: 0.5 }}
                    >
                      🌟 Ready to launch into the future...
                    </motion.div>
                  </div>
                </motion.div>
              </motion.div>
            </motion.div>
          </div>
        </section>

        <section id="features" className="py-24 bg-gradient-to-b from-dark-secondary to-dark-primary relative">
          <motion.div 
            className="absolute inset-0 bg-gradient-radial opacity-30"
            style={{ y: featuresY }}
          />
          
          <div className="container relative z-10">
            <motion.h2 
              className="section-title text-5xl md:text-6xl"
              initial={{ y: 30, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              Why Choose <span className="bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent">N0ctOS</span>?
            </motion.h2>
            
            <motion.div 
              className="grid md:grid-cols-2 lg:grid-cols-4 gap-8"
              variants={containerVariants}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true }}
            >
              {[
                { 
                  icon: '⚡', 
                  title: 'Quantum Speed', 
                  description: 'Lightning-fast boot times and instant application launches with quantum-optimized kernel',
                  color: 'from-yellow-400 to-orange-500'
                },
                { 
                  icon: '🧠', 
                  title: 'AI-Powered', 
                  description: 'Machine learning algorithms optimize system performance in real-time',
                  color: 'from-purple-400 to-pink-500'
                },
                { 
                  icon: '🛡️', 
                  title: 'Fortress Security', 
                  description: 'Military-grade encryption with quantum-resistant cryptography',
                  color: 'from-blue-400 to-cyan-500'
                },
                { 
                  icon: '🌐', 
                  title: 'Future Ready', 
                  description: 'Built for tomorrow with cutting-edge technology stack',
                  color: 'from-green-400 to-emerald-500'
                },
              ].map((feature) => (
                <motion.div 
                  key={feature.title}
                  className="feature-card group relative overflow-hidden"
                  variants={itemVariants}
                  whileHover={{ 
                    scale: 1.05,
                    rotateY: 5,
                    boxShadow: "0 30px 60px rgba(0, 212, 255, 0.4)"
                  }}
                >
                  <motion.div 
                    className={`absolute inset-0 bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-10 transition-opacity duration-300`}
                  />
                  
                  <motion.div 
                    className="text-6xl mb-6 relative z-10"
                    whileHover={{ scale: 1.2, rotate: 10 }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  >
                    {feature.icon}
                  </motion.div>
                  
                  <h3 className="text-2xl font-bold mb-4 text-white relative z-10 group-hover:text-primary-400 transition-colors">
                    {feature.title}
                  </h3>
                  
                  <p className="text-gray-400 leading-relaxed relative z-10 text-sm">
                    {feature.description}
                  </p>
                  
                  <motion.div
                    className="absolute bottom-0 left-0 w-0 h-1 bg-gradient-to-r opacity-0 group-hover:opacity-100"
                    style={{
                      backgroundImage: `linear-gradient(to right, ${feature.color.split(' ')[1]}, ${feature.color.split(' ')[3]})`
                    }}
                    initial={{ width: 0 }}
                    whileHover={{ width: '100%' }}
                    transition={{ duration: 0.3 }}
                  />
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>

        <section id="download" className="py-24 relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-br from-primary-500/10 to-accent/10" />
          
          <div className="container relative z-10">
            <motion.h2 
              className="section-title text-5xl md:text-6xl"
              initial={{ y: 30, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              Download <span className="bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent">N0ctOS 2026</span>
            </motion.h2>
            
            <motion.div 
              className="grid lg:grid-cols-2 gap-16 items-center"
              initial={{ y: 50, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.8 }}
            >
              <div className="download-info">
                <motion.div 
                  className="inline-flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/30 rounded-full px-4 py-2 mb-6"
                  initial={{ opacity: 0, scale: 0.8 }}
                  whileInView={{ opacity: 1, scale: 1 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.3, duration: 0.5 }}
                >
                  <div className="w-2 h-2 bg-yellow-400 rounded-full animate-pulse" />
                  <span className="text-yellow-400 text-sm font-medium">Development Status</span>
                </motion.div>
                
                <h3 className="text-4xl font-bold mb-6 bg-gradient-to-r from-yellow-400 to-orange-500 bg-clip-text text-transparent">
                  Join the Development Journey
                </h3>
                
                <p className="text-gray-400 mb-8 leading-relaxed text-lg">
                  N0ctOS is currently under active development. Be part of community building the future of Linux - 
                  contribute, test, or follow our progress as we create something revolutionary.
                </p>
                
                <div className="download-requirements bg-dark-tertiary/50 backdrop-blur rounded-2xl p-6 border border-primary-500/20">
                  <h4 className="text-2xl font-semibold mb-6 text-white flex items-center gap-2">
                    <span className="text-2xl">🔧</span>
                    System Requirements
                  </h4>
                  <div className="grid md:grid-cols-2 gap-4">
                    {[
                      { icon: '💾', label: 'RAM', value: '4GB (8GB recommended)' },
                      { icon: '💿', label: 'Storage', value: '30GB SSD' },
                      { icon: '⚡', label: 'Processor', value: '64-bit Quad Core' },
                      { icon: '🎮', label: 'Graphics', value: 'OpenGL 4.0+' },
                    ].map((req) => (
                      <motion.div 
                        key={req.label}
                        className="flex items-center gap-3 p-3 rounded-lg bg-dark-secondary/50 border border-gray-700"
                        whileHover={{ scale: 1.05, borderColor: 'rgba(0, 212, 255, 0.5)' }}
                      >
                        <span className="text-2xl">{req.icon}</span>
                        <div>
                          <div className="text-sm text-gray-500">{req.label}</div>
                          <div className="text-white font-medium">{req.value}</div>
                        </div>
                      </motion.div>
                    ))}
                  </div>
                </div>
              </div>
              
              <div className="download-buttons text-center">
                <motion.div 
                  className="relative inline-block"
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                >
                  <motion.button 
                    className="btn btn-primary btn-large relative overflow-hidden group"
                    animate={{
                      boxShadow: [
                        "0 0 30px rgba(255, 193, 7, 0.4)", 
                        "0 0 50px rgba(255, 193, 7, 0.8)", 
                        "0 0 30px rgba(255, 193, 7, 0.4)"
                      ]
                    }}
                    transition={{
                      duration: 2,
                      repeat: Infinity,
                      ease: "easeInOut"
                    }}
                  >
                    <span className="relative z-10 flex items-center gap-3">
                      <span className="text-2xl">🚧</span>
                      <div className="text-left">
                        <div className="text-xl font-bold">Join Development</div>
                        <div className="text-sm opacity-80">Help Build N0ctOS</div>
                      </div>
                    </span>
                    
                    <motion.div
                      className="absolute inset-0 bg-gradient-to-r from-yellow-500 via-orange-500 to-yellow-600"
                      initial={{ x: '-100%' }}
                      whileHover={{ x: '0%' }}
                      transition={{ duration: 0.5 }}
                    />
                  </motion.button>
                  
                  <motion.div
                    className="absolute -inset-1 bg-gradient-to-r from-yellow-500 to-orange-500 rounded-2xl opacity-50 blur-lg"
                    animate={{
                      opacity: [0.3, 0.6, 0.3],
                    }}
                    transition={{
                      duration: 2,
                      repeat: Infinity,
                      ease: "easeInOut"
                    }}
                  />
                </motion.div>
                
                <div className="mt-6 space-y-3">
                  <div className="flex items-center justify-center gap-2 text-sm text-gray-400">
                    <span className="text-yellow-400">🚧</span>
                    <span>Currently in Development</span>
                  </div>
                  <div className="flex items-center justify-center gap-2 text-sm text-gray-400">
                    <span className="text-yellow-400">👥</span>
                    <span>Join our Community</span>
                  </div>
                  <div className="flex items-center justify-center gap-2 text-sm text-gray-400">
                    <span className="text-yellow-400">🔄</span>
                    <span>Follow Progress Updates</span>
                  </div>
                </div>
              </div>
            </motion.div>
          </div>
        </section>

        <section id="team" className="py-24 bg-gradient-to-b from-dark-primary to-dark-secondary relative">
          <div className="absolute inset-0 bg-gradient-radial opacity-20" />
          
          <div className="container relative z-10">
            <motion.h2 
              className="section-title text-5xl md:text-6xl"
              initial={{ y: 30, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              Meet the <span className="bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent">Visionaries</span>
            </motion.h2>
            
            <motion.div 
              className="grid md:grid-cols-2 gap-12 justify-items-center"
              variants={containerVariants}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true }}
            >
              {[
                { 
                  name: 'anagh.exe', 
                  role: 'Quantum Architect', 
                  github: 'https://github.com/anagh.exe',
                  description: 'Lead developer and system architect'
                },
                { 
                  name: 'N0ctaneDev', 
                  role: 'AI Integration Expert', 
                  github: 'https://github.com/N0ctaneDev',
                  description: 'Machine learning and automation specialist'
                }
              ].map((member) => (
                <motion.div 
                  key={member.name}
                  className="team-member group"
                  variants={itemVariants}
                  whileHover={{ scale: 1.05 }}
                >
                  <motion.div 
                    className="member-avatar relative"
                    whileHover={{ 
                      boxShadow: "0 0 50px rgba(0, 212, 255, 0.8)",
                      rotate: [0, 5, -5, 0]
                    }}
                    transition={{ 
                      boxShadow: { duration: 0.3 },
                      rotate: { duration: 0.5, repeat: Infinity, repeatDelay: 2 }
                    }}
                  >
                    <img 
                      src={`https://github.com/${member.name}.png`} 
                      alt={member.name} 
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        const target = e.target as HTMLImageElement;
                        target.src = `data:image/svg+xml;base64,${btoa(`
                          <svg width="100" height="100" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <defs>
                              <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
                                <stop offset="0%" style="stop-color:#00d4ff;stop-opacity:1" />
                                <stop offset="100%" style="stop-color:#0099cc;stop-opacity:1" />
                              </linearGradient>
                            </defs>
                            <rect width="100" height="100" fill="#1a1a1a"/>
                            <circle cx="50" cy="50" r="45" fill="url(#grad)" opacity="0.2"/>
                            <text x="50" y="50" text-anchor="middle" dy="0.3em" fill="url(#grad)" font-family="monospace" font-size="12" font-weight="bold">${member.name.length > 8 ? member.name.substring(0, 8) : member.name}</text>
                          </svg>
                        `)}`; 
                      }} 
                    />
                  </motion.div>
                  
                  <h3 className="text-2xl font-bold mb-2 text-white">{member.name}</h3>
                  <p className="text-gray-400 mb-2 text-sm">{member.description}</p>
                  <p className="text-primary-400 font-medium mb-4">{member.role}</p>
                  <motion.div
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                  >
                    <a 
                      href={member.github} 
                      target="_blank" 
                      rel="noopener noreferrer" 
                      className="github-link inline-flex items-center gap-2"
                    >
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599 1.795 1.092 3.365 1.092 2.267 0 4.818-1.854 5.632-4.648.315-1.089-2.143-2.895-2.895-2.752-.052-.098-.105-.203-.105-.329 0-1.98 1.353-4.206 2.23-4.206.919 0 1.517-.588 2.799-1.551 3.771-2.828 2.262-2.892 3.789-1.831 3.789-1.831 0 0 0 .645.364 1.365 1.063 1.063.855 0 1.548-.688 2.815-1.887 3.127-2.815.744-1.607-2.465-3.045-2.465-3.045 0-2.127 1.674-4.857 5.232-4.857z"/>
                      </svg>
                      GitHub
                    </a>
                  </motion.div>
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>
      </main>

      <footer className="bg-dark-tertiary py-8 border-t border-gray-800 relative">
        <div className="absolute inset-0 bg-gradient-radial opacity-10" />
        <div className="container relative z-10 text-center">
          <motion.p 
            className="text-gray-500"
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
          >
            &copy; 2026 N0ctOS. Quantum-powered open source operating system.
          </motion.p>
        </div>
      </footer>
    </div>
  )
}

export default App
