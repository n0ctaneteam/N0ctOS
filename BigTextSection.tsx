import { motion } from "motion/react";

export default function BigTextSection() {
  return (
    <section className="relative w-full h-[40vh] md:h-[60vh] flex items-center justify-center bg-[#0a1120] overflow-hidden select-none">
      {/* Large Background Text */}
      <motion.h2 
        initial={{ opacity: 0, scale: 0.8 }}
        whileInView={{ opacity: 1, scale: 1 }}
        transition={{ duration: 1, ease: "easeOut" }}
        className="absolute text-[30vw] font-black text-[#192337] tracking-tighter leading-none"
      >
        N0CTOS
      </motion.h2>

      {/* Foreground Text */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.2 }}
        className="relative z-10 text-center"
      >
        <h3 className="text-xl md:text-4xl font-bold text-[#FFD700] tracking-[0.4em] md:tracking-[0.6em] uppercase">
          Arch Made Simple
        </h3>
      </motion.div>
    </section>
  );
}
