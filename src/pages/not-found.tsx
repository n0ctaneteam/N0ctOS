import { motion } from "motion/react";
import { Link } from "react-router-dom";
import { Home, Ghost } from "lucide-react";

export default function NotFound() {
  const redirectToHome = () => {
    navigate("/home");
  };
  
  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6 text-center">
      <motion.div
        initial={{ opacity: 0, scale: 0.5 }}
        animate={{ opacity: 1, scale: 1 }}
        className="mb-8"
      >
        <Ghost className="w-32 h-32 text-primary animate-bounce" />
      </motion.div>
      <h1 className="text-8xl font-bold tracking-tighter mb-4">404</h1>
      <p className="text-2xl text-muted-foreground mb-12 max-w-md">
        Oops! It seems you've wandered into the dark. This page doesn't exist.
      </p>
      <button
        onClick={redirectToHome}
        className="bg-primary text-background px-8 py-3 rounded-full font-bold flex items-center gap-2 hover:scale-105 transition-transform"
      >
        <Home className="w-5 h-5" />
        Back to Home
      </button>
    </div>
  );
}
