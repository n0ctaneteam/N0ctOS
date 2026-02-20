import { motion } from "framer-motion";

const LOGO_URL = "https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png";

function Team() {
  const teamMembers = [
    {
      name: "N0ctaneDev",
      role: "Lead Developer & OS Creator",
      github: "https://github.com/N0ctaneDev",
      description: "Building the N0ctOS operating system from the ground up",
    },
    {
      name: "anaghsinghcodingo",
      role: "Full Stack Developer",
      github: "https://github.com/anaghsinghcodingo",
      description: "Creating the website and applications for N0ctOS",
    },
  ];

  return (
    <div className=" text-white font-tektur flex flex-col">
      <main className="flex-grow py-24">
        <div className="container">
          <motion.h1
            className="text-5xl md:text-6xl font-bold text-center mb-16 bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent"
            initial={{ y: 30, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            transition={{ duration: 0.6 }}
          >
            <img 
              src={LOGO_URL} 
              alt="N0ctOS Logo" 
              className="w-[clamp(100px,100%,400px)] object-contain mx-auto mb-6 drop-shadow-[0_0_20px_rgba(139,92,246,0.5)]"
            />
            Meet the Visionaries
          </motion.h1>

          <div className="grid md:grid-cols-2 gap-12 max-w-4xl mx-auto">
            {teamMembers.map((member, index) => (
              <motion.div
                key={member.name}
                className="text-center group"
                initial={{ y: 20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                transition={{ delay: index * 0.2, duration: 0.6 }}
                whileHover={{ scale: 1.05 }}
              >
                <div className="w-32 h-32 rounded-full overflow-hidden mx-auto mb-6 border-4 border-primary-500 shadow-xl shadow-primary-500/30 group-hover:shadow-primary-500/50 transition-shadow">
                  <img
                    src={`https://github.com/${member.name}.png`}
                    alt={member.name}
                    className="w-full h-full object-cover"
                    onError={(e) => {
                      const target = e.target as HTMLImageElement;
                      target.src = `data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="%230d1117" width="100" height="100"/><text fill="%2300d4ff" x="50" y="50" text-anchor="middle" font-size="40">${member.name[0]}</text></svg>`;
                    }}
                  />
                </div>

                <h3 className="text-2xl font-bold mb-2 text-white">
                  {member.name}
                </h3>
                <p className="text-gray-400 mb-2 text-sm">
                  {member.description}
                </p>
                <p className="text-primary-400 font-medium mb-4">
                  {member.role}
                </p>

                <motion.div
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <a
                    href={member.github}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-2 text-primary-500 hover:text-primary-400 font-semibold transition-colors"
                  >
                    <svg
                      width="20"
                      height="20"
                      viewBox="0 0 24 24"
                      fill="currentColor"
                    >
                      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
                    </svg>
                    GitHub Profile
                  </a>
                </motion.div>
              </motion.div>
            ))}
          </div>
        </div>
      </main>
    </div>
  );
}

export default Team;
