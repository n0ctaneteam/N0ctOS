import { motion } from "motion/react";
import { Download as DownloadIcon, Cpu, HardDrive, ShieldCheck } from "lucide-react";

export default function Download() {
  const versions = [
    {
      name: "N0ctOS Alpha",
      version: "Development",
      kernel: "6.x.x-arch",
      size: "TBD",
      type: "Early Access Build",
      color: "primary"
    }
  ];

  return (
    <div className="pt-32 pb-20 px-6 max-w-7xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-center mb-16"
      >
        <h1 className="text-5xl md:text-7xl font-bold tracking-tighter mb-6">Coming Soon</h1>
        <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
          N0ctOS is currently in active development. Alpha builds will be available for testing soon.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 max-w-2xl mx-auto gap-8">
        {versions.map((v, idx) => (
          <motion.div
            key={v.name}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="p-10 bg-muted/30 border border-white/5 rounded-[2.5rem] relative overflow-hidden group"
          >
            <div className={`absolute top-0 right-0 w-32 h-32 bg-${v.color}/10 blur-3xl group-hover:bg-${v.color}/20 transition-colors`} />
            
            <h3 className="text-3xl font-bold mb-2">{v.name}</h3>
            <p className="text-muted-foreground mb-8">{v.type}</p>

            <div className="space-y-4 mb-10">
              <div className="flex items-center gap-3 text-sm">
                <Cpu className="w-5 h-5 text-primary" />
                <span>Kernel: {v.kernel}</span>
              </div>
              <div className="flex items-center gap-3 text-sm">
                <HardDrive className="w-5 h-5 text-secondary" />
                <span>Status: In Development</span>
              </div>
            </div>

            <button disabled className="w-full bg-white/10 text-white/50 py-4 rounded-2xl font-bold flex items-center justify-center gap-2 cursor-not-allowed">
              Coming Soon
            </button>
          </motion.div>
        ))}
      </div>

      <div className="mt-16 p-8 bg-muted/20 border border-white/5 rounded-3xl">
        <h4 className="font-bold mb-4 flex items-center gap-2">
          <ShieldCheck className="w-5 h-5 text-primary" />
          Checksums
        </h4>
        <div className="font-mono text-xs text-muted-foreground break-all space-y-2">
          <p>Stable: 8f2d3e...a1b2c3d4e5f6</p>
          <p>Gaming: 4a5b6c...f1e2d3c4b5a6</p>
        </div>
      </div>
    </div>
  );
}

