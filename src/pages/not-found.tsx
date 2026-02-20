import { useNavigate } from "react-router-dom";
import { motion } from "framer-motion";

export const NotFound = () => {
  const navigate = useNavigate();
  const redirectToHome = () => {
    navigate("/home");
  };

  const messages = [
    "Umm... Page not found",
    "You're lost, bro",
    "This route doesn't exist",
    "404 — skill issue",
  ];

  const randomMessage = messages[Math.floor(Math.random() * messages.length)];

  return (
    <div className=" text-white font-tektur flex justify-center content-center items-center">      
      <div className="flex flex-col items-center justify-center w-[clamp(0px,98vw,130vh)] py-20">
        <motion.div
          initial={{ scale: 0.8, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ duration: 0.5 }}
        >
          <img 
            className="object-contain mb-8 px-[clamp(1, )]" 
            src="https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png" 
            alt="N0ctOS"
          />
        </motion.div>
        
        <motion.h1
          className="text-[clamp(2rem,8vw,4rem)] leading-none font-black text-center mb-6"
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
        >
          <span className="bg-gradient-to-r from-primary-400 to-secondary-500 bg-clip-text text-transparent">
            {randomMessage}
          </span>
        </motion.h1>
        
        <motion.div
          className="flex flex-col items-center gap-4"
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.4 }}
        >
          <button
            onClick={redirectToHome}
            className="px-8 py-3 bg-primary-500 hover:bg-primary-600 text-white rounded-lg font-semibold transition-colors"
          >
            Go Back To Home
          </button>
        </motion.div>
      </div>
    </div>
  );
};
