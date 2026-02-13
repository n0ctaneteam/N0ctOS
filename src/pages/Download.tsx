import { motion } from 'framer-motion'
import Navbar from '../components/Navbar'
import Footer from '../components/Footer'

function Download() {
  // Optimized particles
  const particles = Array.from({ length: 20 }, (_, i) => ({ id: i }))

  return (
    <div className="min-h-screen bg-dark-primary text-white overflow-x-hidden relative font-tektur">
      
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

      <Navbar />

      <main className="pt-20">
        <section className="py-24 relative overflow-hidden">
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
                  Join Development Journey
                </h3>
                
                <p className="text-gray-400 mb-8 leading-relaxed text-lg">
                  N0ctOS is currently under active development. Be part of the community building the future of Linux - 
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
      </main>
      <Footer />
    </div>
  )
}

export default Download
