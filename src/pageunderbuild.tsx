import logo from "./assets/N0ctOS.png";
import { motion } from "framer-motion";

// import "./test.css";

export const Pageunderbuild = () => {
    // Optimized particles
    const particles = Array.from({ length: 200 }, (_, i) => ({ id: i }));

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
                <div
                    className="h-5 min-w-screen"
                    style={{
                        backgroundImage:
                            "repeating-linear-gradient(45deg, #facc15 0px, #facc15 20px, #000 20px, #000 40px)",
                    }}
                />
                <div className="flex-1 flex-col items-center justify-between content-center">
                    <img src={logo} />
                    <div className="flex flex-grow-1  flex-col bg-transparent font-tektur font-black text-center ">
                        <h1 className="text-[clamp(2.5rem,10vw,4.8rem)] leading-none bg-gradient-to-br from-violet-600 via-blue-600 to-cyan-600 bg-clip-text text-transparent">
                            Page Is Under Development..
                        </h1>
                        <div>
                            <span>Meanwhile, Checkout our </span>
                            <a
                                href="https://github.com/n0ctaneteam/N0ctOS"
                                className="text-xl text-cyan-300 underline underline-offset-4"
                            >
                                Github
                            </a>
                        </div>
                    </div>
                </div>
                <div
                    className="h-5 w-full fixed bottom-0"
                    style={{
                        backgroundImage:
                            "repeating-linear-gradient(45deg, #facc15 0px, #facc15 20px, #000 20px, #000 40px)",
                    }}
                />
            </div>
        </>
    );
};
