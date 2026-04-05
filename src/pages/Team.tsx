import { motion } from "motion/react";
import { Github, Globe } from "lucide-react";

export default function Team() {
  const members = [
    {
      name: "N0ctane_Dev",
      role: "Lead Developer",
      bio: "The visionary behind N0ctOS. Focused on kernel optimization, system architecture, and pushing the boundaries of Arch Linux.",
      avatar: "https://github.com/N0ctaneDev.png",
      github: "https://github.com/N0ctaneDev"
    },
    {
      name: "Anagh.exe",
      role: "Website Developer",
      bio: "Crafting the digital presence of N0ctOS. Specialized in building high-performance, aesthetic web experiences.",
      avatar: "https://github.com/anaghsinghcodingo.png",
      github: "https://github.com/anaghsinghcodingo"
    }
  ];

  return (
    <div className="pt-32 pb-20 px-6 max-w-7xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex items-center justify-center flex-col h-[70dvh] mb-[10px]"
      >
        <h1 className="text-5xl md:text-7xl font-bold tracking-tighter mb-6">The Duo</h1>
        <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
          We're a small team of two working hard to bring N0ctOS to life.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-4xl mx-auto">
        {members.map((member, idx) => (
          <motion.div
            key={member.name}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: idx * 0.1 }}
            className="p-6 bg-muted/30 border border-white/5 rounded-[2rem] text-center group"
          >
            <div className="relative mb-6 inline-block">
              <img
                src={member.avatar}
                alt={member.name}
                className="w-32 h-32 rounded-full object-cover border-2 border-white/10 group-hover:border-primary transition-colors"
                referrerPolicy="no-referrer"
              />
              <div className="absolute -bottom-2 -right-2 bg-primary text-background p-2 rounded-full">
                <Globe className="w-4 h-4" />
              </div>
            </div>
            <h3 className="text-xl font-bold mb-1">{member.name}</h3>
            <p className="text-primary text-sm font-medium mb-4">{member.role}</p>
            <p className="text-muted-foreground text-sm leading-relaxed mb-6">
              {member.bio}
            </p>
            <div className="flex justify-center gap-4">
              <a href={member.github} target="_blank" rel="noopener noreferrer" className="text-muted-foreground hover:text-white transition-colors">
                <Github className="w-5 h-5" />
              </a>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
