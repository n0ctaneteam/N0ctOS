import { motion } from "motion/react";
import { Link } from "react-router-dom";
import { Cpu, ChevronRight, Github, Terminal } from "lucide-react";

export default function Home() {
  return (
    <div className="relative overflow-hidden">
      {/* Hero Section */}
      <section className="pt-40 pb-20 px-6">
        <div className="max-w-7xl mx-auto text-center relative z-10">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            <h1 className="text-6xl md:text-8xl lg:text-9xl font-bold tracking-tighter mb-8 leading-[0.9]">
              ARCH MADE <br />
              <span className="bg-clip-text text-transparent bg-gradient-to-r from-primary via-secondary to-accent uppercase">Simple.</span>
            </h1>
            <p className="text-xl md:text-2xl text-muted-foreground max-w-3xl mx-auto mb-12 leading-relaxed font-medium">
              N0ctOS is a performance-driven, Arch-based Linux distribution designed for those who value speed, aesthetics, and simplicity.
            </p>
            
            <div className="flex flex-col sm:flex-row items-center justify-center gap-6">
              <Link
                to="/download"
                className="group bg-white text-black px-10 py-4 rounded-2xl font-bold text-lg flex items-center gap-2 hover:bg-primary transition-all hover:scale-105"
              >
                Join the Waitlist
                <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </Link>
              <a
                href="https://github.com/n0ctaneteam/N0ctOS"
                className="flex items-center gap-2 text-muted-foreground hover:text-white transition-colors font-medium"
              >
                <Github className="w-6 h-6" />
                View Source
              </a>
            </div>
          </motion.div>
        </div>

        {/* Background Elements */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-full h-full -z-10 pointer-events-none">
          <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-primary/20 rounded-full blur-[120px] animate-pulse" />
          <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-secondary/20 rounded-full blur-[120px] animate-pulse delay-700" />
        </div>
      </section>

      {/* Stats Section Removed - Project in Early Stage */}

      {/* Terminal Preview */}
      <section className="py-32 px-6">
        <div className="max-w-5xl mx-auto">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            className="bg-[#0c0c0c] rounded-3xl border border-white/10 shadow-2xl overflow-hidden"
          >
            <div className="h-10 bg-white/5 flex items-center px-4 gap-2">
              <div className="w-3 h-3 rounded-full bg-red-500/50" />
              <div className="w-3 h-3 rounded-full bg-yellow-500/50" />
              <div className="w-3 h-3 rounded-full bg-green-500/50" />
              <div className="ml-4 text-xs text-muted-foreground font-mono">n0ctos@terminal ~</div>
            </div>
            <div className="p-8 font-mono text-sm space-y-2">
              <div className="flex gap-2">
                <span className="text-primary">➜</span>
                <span className="text-secondary">~</span>
                <span>neofetch</span>
              </div>
              <div className="flex gap-8 pt-4">
                <pre className="text-primary leading-tight">
{`      /\\
     /  \\
    /\\   \\
   /  \\   \\
  /    \\   \\
 /      \\   \\
/________\\___\\`}
                </pre>
                <div className="space-y-1">
                  <div className="font-bold text-primary">n0ctos@night-owl</div>
                  <div className="text-muted-foreground">-----------------</div>
                  <div><span className="text-secondary">OS:</span> N0ctOS Linux x86_64</div>
                  <div><span className="text-secondary">Host:</span> Custom Build</div>
                  <div><span className="text-secondary">Kernel:</span> 6.7.9-arch1-1</div>
                  <div><span className="text-secondary">Uptime:</span> 4 days, 12 hours</div>
                  <div><span className="text-secondary">Packages:</span> 842 (pacman)</div>
                  <div><span className="text-secondary">Shell:</span> zsh 5.9</div>
                  <div><span className="text-secondary">Resolution:</span> 3840x2160</div>
                  <div><span className="text-secondary">DE:</span> N0ct-DE (Plasma based)</div>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </section>
    </div>
  );
}

