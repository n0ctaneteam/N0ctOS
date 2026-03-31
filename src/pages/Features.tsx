import { motion } from "motion/react";
import { Zap, Shield, Layout, Terminal, MousePointer2, Cpu } from "lucide-react";

export default function Features() {
  const features = [
    {
      title: "Lightning Fast",
      desc: "Optimized kernel and minimal background services for peak performance.",
      icon: <Zap className="w-8 h-8 text-primary" />
    },
    {
      title: "Hardened Security",
      desc: "Pre-configured firewall and security patches to keep your data safe.",
      icon: <Shield className="w-8 h-8 text-secondary" />
    },
    {
      title: "Custom DE",
      desc: "A beautifully crafted desktop environment designed for productivity.",
      icon: <Layout className="w-8 h-8 text-accent" />
    },
    {
      title: "Developer Friendly",
      desc: "All your favorite tools pre-installed and ready to go.",
      icon: <Terminal className="w-8 h-8 text-primary" />
    },
    {
      title: "Smooth Animations",
      desc: "Fluid UI interactions that make using your OS a delight.",
      icon: <MousePointer2 className="w-8 h-8 text-secondary" />
    },
    {
      title: "Arch Based",
      desc: "The power and flexibility of Arch Linux with a user-friendly touch.",
      icon: <Cpu className="w-8 h-8 text-accent" />
    }
  ];

  return (
    <div className="pt-32 pb-20 px-6 max-w-7xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-center mb-20"
      >
        <h1 className="text-5xl md:text-7xl font-bold tracking-tighter mb-6">OS Features</h1>
        <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
          N0ctOS isn't just another distribution. It's a carefully curated experience.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        {features.map((f, idx) => (
          <motion.div
            key={f.title}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: idx * 0.1 }}
            className="p-8 bg-muted/30 border border-white/5 rounded-3xl hover:bg-muted/50 transition-colors"
          >
            <div className="mb-6">{f.icon}</div>
            <h3 className="text-2xl font-bold mb-3">{f.title}</h3>
            <p className="text-muted-foreground leading-relaxed">{f.desc}</p>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

