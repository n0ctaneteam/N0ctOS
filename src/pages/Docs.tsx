import { motion } from "motion/react";
import { Book, Terminal, Shield, Zap } from "lucide-react";

export default function Docs() {
  const sections = [
    {
      title: "Getting Started",
      icon: <Zap className="w-6 h-6 text-primary" />,
      items: ["Installation Guide", "System Requirements", "First Boot Setup"]
    },
    {
      title: "Configuration",
      icon: <Terminal className="w-6 h-6 text-secondary" />,
      items: ["Package Management", "Desktop Environments", "Kernel Tuning"]
    },
    {
      title: "Security",
      icon: <Shield className="w-6 h-6 text-accent" />,
      items: ["Firewall Setup", "Disk Encryption", "User Permissions"]
    }
  ];

  return (
    <div className="pt-32 pb-20 px-6 max-w-7xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="flex flex-col items-center justify-center h-[70dvh] mb-[10px]"
      >
        <h1 className="text-5xl md:text-7xl font-bold tracking-tighter mb-6">Documentation</h1>
        <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
          Everything you need to know about installing, configuring, and mastering N0ctOS.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        {sections.map((section, idx) => (
          <motion.div
            key={section.title}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: idx * 0.1 }}
            className="p-8 bg-muted/30 border border-white/5 rounded-3xl hover:border-primary/50 transition-colors group"
          >
            <div className="mb-6 p-4 bg-background rounded-2xl w-fit group-hover:scale-110 transition-transform">
              {section.icon}
            </div>
            <h3 className="text-2xl font-bold mb-4">{section.title}</h3>
            <ul className="space-y-3">
              {section.items.map(item => (
                <li key={item}>
                  <a href="#" className="text-muted-foreground hover:text-primary transition-colors flex items-center gap-2">
                    <Book className="w-4 h-4" />
                    {item}
                  </a>
                </li>
              ))}
            </ul>
          </motion.div>
        ))}
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="mt-20 p-12 bg-gradient-to-br from-primary/10 to-secondary/10 border border-white/5 rounded-[3rem] text-center"
      >
        <h2 className="text-3xl font-bold mb-4">Can't find what you're looking for?</h2>
        <p className="text-muted-foreground mb-8">Join our community Discord or check the Wiki for more in-depth guides.</p>
        <button className="bg-white text-black px-8 py-3 rounded-full font-bold hover:scale-105 transition-transform">
          Visit Wiki
        </button>
      </motion.div>
    </div>
  );
}
