import { motion } from "framer-motion";

const LOGO_URL = "https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png";

function Download() {
  return (
    <div className=" text-white font-tektur flex flex-col">
      <main className="flex-grow">
        <section className="py-24 relative overflow-hidden">
          <div className="container relative z-10">
            <motion.h2
              className="section-title text-5xl md:text-6xl"
              initial={{ y: 30, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <img 
                src={LOGO_URL} 
                alt="N0ctOS Logo" 
                className="w-[clamp(100px,100%,400px)] object-contain mx-auto mb-6 drop-shadow-[0_0_20px_rgba(139,92,246,0.5)]"
              />
              Download{" "}
              <span className="bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent">
                N0ctOS 2026
              </span>
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
                  <span className="text-yellow-400 text-sm font-medium">
                    Development Status
                  </span>
                </motion.div>

                <h3 className="text-4xl font-bold mb-6 bg-gradient-to-r from-yellow-400 to-orange-500 bg-clip-text text-transparent">
                  Join Development Journey
                </h3>

                <p className="text-gray-400 mb-8 leading-relaxed text-lg">
                  N0ctOS is currently under active development. Be part of the
                  community building the future of Linux - contribute, test, or
                  follow our progress as we create something revolutionary.
                </p>

                <div className="download-requirements bg-dark-tertiary/50 backdrop-blur rounded-2xl p-6 border border-primary-500/20">
                  <h4 className="text-2xl font-semibold mb-6 text-white flex items-center gap-2">
                    <span className="text-2xl">🔧</span>
                    System Requirements
                  </h4>
                  <div className="grid md:grid-cols-2 gap-4">
                    {[
                      {
                        icon: "💾",
                        label: "RAM",
                        value: "4GB (8GB+ recommended)",
                      },
                      { icon: "💿", label: "Storage", value: "30GB+" },
                    ].map((req) => (
                      <motion.div
                        key={req.label}
                        className="flex items-center gap-3 p-3 rounded-lg bg-dark-secondary/50 border border-gray-700"
                        whileHover={{
                          scale: 1.05,
                          borderColor: "rgba(139, 92, 246, 0.5)",
                        }}
                      >
                        <span className="text-2xl">{req.icon}</span>
                        <div>
                          <div className="text-sm text-gray-500">
                            {req.label}
                          </div>
                          <div className="text-white font-medium">
                            {req.value}
                          </div>
                        </div>
                      </motion.div>
                    ))}
                  </div>
                </div>
              </div>

              {/* Terminal Effect */}
              <motion.div
                className="flex justify-center lg:justify-end"
                initial={{ x: 100, opacity: 0 }}
                whileInView={{ x: 0, opacity: 1 }}
                viewport={{ once: true }}
                transition={{ duration: 0.8, delay: 0.3 }}
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
                    ease: "easeInOut",
                  }}
                >
                  <motion.div
                    className="absolute inset-0 w-80 h-80 bg-primary-500/20 rounded-full blur-3xl"
                    animate={{
                      scale: [1, 1.2, 1],
                      opacity: [0.3, 0.6, 0.3],
                    }}
                    transition={{
                      duration: 3,
                      repeat: Infinity,
                      ease: "easeInOut",
                    }}
                  />

                  <motion.div
                    className="terminal relative z-10"
                    style={{
                      boxShadow: "0 25px 50px rgba(139, 92, 246, 0.3), 0 0 100px rgba(139, 92, 246, 0.1)",
                    }}
                  >
                    <div className="terminal-header bg-gradient-to-r from-dark-tertiary to-dark-secondary">
                      <div className="terminal-buttons">
                        <span className="btn-close shadow-lg shadow-red-500/50"></span>
                        <span className="btn-minimize shadow-lg shadow-yellow-500/50"></span>
                        <span className="btn-maximize shadow-lg shadow-green-500/50"></span>
                      </div>
                      <div className="terminal-title text-primary-400 font-mono">
                        n0ctos@n1tro-installer
                      </div>
                    </div>
                    <div className="terminal-body bg-dark-secondary/90 backdrop-blur">
                      <motion.div
                        className="terminal-line text-primary-400 text-nowrap overflow-hidden"
                        initial={{ width: 0 }}
                        whileInView={{ width: "100%" }}
                        viewport={{ once: true }}
                        transition={{ delay: 0.5, duration: 2 }}
                      >
                        $ sudo ./download-n0ctos.sh --2026
                      </motion.div>
                      <motion.div
                        className="terminal-line text-gray-400"
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        transition={{ delay: 2.5, duration: 0.5 }}
                      >
                        📦 Preparing download packages...
                      </motion.div>
                      <motion.div
                        className="terminal-line text-gray-400"
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        transition={{ delay: 3.5, duration: 0.5 }}
                      >
                        🔐 Verifying signatures...
                      </motion.div>
                      <motion.div
                        className="terminal-line success text-green-400 font-bold"
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        transition={{ delay: 4.5, duration: 0.5 }}
                      >
                        ✓ Ready to download N0ctOS 2026!
                      </motion.div>
                      <motion.div
                        className="terminal-line text-primary-400 animate-pulse"
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        transition={{ delay: 5.5, duration: 0.5 }}
                      >
                        🚀 Join the development journey...
                      </motion.div>
                    </div>
                  </motion.div>
                </motion.div>
              </motion.div>

              <div className="download-buttons text-center">
                {/*<motion.div
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
                        "0 0 30px rgba(255, 193, 7, 0.4)",
                      ],
                    }}
                    transition={{
                      duration: 2,
                      repeat: Infinity,
                      ease: "easeInOut",
                    }}
                  >
                    <span className="relative z-10 flex items-center gap-3">
                      <span className="text-2xl">🚧</span>
                      <div className="text-left">
                        <div className="text-xl font-bold">
                          Join Development
                        </div>
                        <div className="text-sm opacity-80">
                          Help Build N0ctOS
                        </div>
                      </div>
                    </span>

                    <motion.div
                      className="absolute inset-0 bg-gradient-to-r from-yellow-500 via-orange-500 to-yellow-600"
                      initial={{ x: "-100%" }}
                      whileHover={{ x: "0%" }}
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
                      ease: "easeInOut",
                    }}
                  />
                </motion.div>*/}

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
    </div>
  );
}

export default Download;
