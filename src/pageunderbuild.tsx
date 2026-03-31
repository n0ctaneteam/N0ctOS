import { motion } from "motion/react";
import { Hammer } from "lucide-react";

export function PageUnderBuild() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 text-center bg-background">
      <motion.div
        animate={{ rotate: [0, 10, -10, 0] }}
        transition={{ repeat: Infinity, duration: 2 }}
        className="mb-8"
      >
        <Hammer className="w-24 h-24 text-secondary" />
      </motion.div>
      <h1 className="text-4xl md:text-6xl font-bold tracking-tighter mb-4">Under Construction</h1>
      <p className="text-xl text-muted-foreground max-w-lg">
        We're currently forging this part of the OS. Check back soon for updates from the forge.
      </p>
    </div>
  );
}
