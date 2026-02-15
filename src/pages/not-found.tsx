import { useNavigate } from "react-router-dom";
import logo from "/N0ctOS.png";
import { motion } from "framer-motion";

// import "/src/test.css";

import { useEffect } from "react";

export const NotFound = () => {
  useEffect(() => {
    const elements = document.querySelectorAll<HTMLElement>(".BAR");

    elements.forEach((el) => {
      el.style.display = "none";
    });
  }, []);

  const messages = [
    "Umm... Page not found",
    "You’re lost, bro",
    "This route doesn’t exist",
    "404 — skill issue",
  ];

  const randomMessage = messages[Math.floor(Math.random() * messages.length)];

  // Optimized particles
  const particles = Array.from({ length: 200 }, (_, i) => ({ id: i }));

  const navigate = useNavigate();
  const redirectToHome = () => {
    navigate("/home");
  };

  return (
    <>
      <div className="fixed inset-0 pointer-events-none -z-10 bg-gradient-to-br from-zinc-950 to-gray-950">
        {particles.map((particle) => (
          <motion.div
            key={particle.id}
            className="absolute w-2 h-2 bg-primary-400 rounded-full opacity-60 gpu-accelerated -z-500"
            style={{
              left: `${Math.random() * 100}%`,
              top: `${Math.random() * 100}%`,
            }}
            animate={{
              y: [0, -40, 0],
              x: [0, Math.random() * 40 - 20, 0],
              opacity: [0.1, 0.3, 0.1],
            }}
            transition={{
              duration: Math.random() * 6 + 2.5,
              repeat: Infinity,
              ease: "easeInOut",
            }}
          />
        ))}
      </div>
      <div className="min-h-dvh  flex flex-col flex-grow justify-between content-between pb-14 min-w-full outline outline-white">
        <div className="flex-1 flex-col items-center justify-between content-center">
          <div className="flex justify-center">
            <img className="" src={logo} />
          </div>
          <div className="flex flex-grow-1  flex-col bg-transparent font-tektur font-black text-center ">
            <h1 className="text-[clamp(1.9rem,10vw,3.8rem)] leading-none bg-gradient-to-br from-violet-600 via-blue-600 to-cyan-600 bg-clip-text text-transparent">
              {randomMessage}
            </h1>
            <div>
              <span className="text-2xl">So... </span>
              <button
                onClick={redirectToHome}
                className="text-3xl bg-gradient-to-br from-teal-400 to-cyan-600 bg-clip-text text-transparent underline underline-offset-4"
              >
                Go Back To Home
              </button>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};
