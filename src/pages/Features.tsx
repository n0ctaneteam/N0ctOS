import { motion, useScroll, useTransform } from "framer-motion";
import Navbar from "../components/Navbar";
import Footer from "../components/Footer";

const LOGO_URL =
  "https://res.cloudinary.com/drysfsc1b/image/upload/v1771153631/N0ctOS_ritdbv.png";

const features_list = [
  {
    icon: "⚡",
    title: "Super Speed",
    description:
      "Lightning-fast boot times and instant application launches with well-optimizations",
    color: "from-yellow-400 to-orange-500",
  },
  {
    icon: "🛡️",
    title: "Fortress Security*",
    description: "No Tracking & user-data collection. Plus Linux Security",
    color: "from-purple-400 to-purple-500",
  },
  {
    icon: "🌐",
    title: "Future Ready",
    description: "Built for tomorrow with cutting-edge stable technology stack",
    color: "from-green-400 to-emerald-500",
  },
  {
    icon: "🔧",
    title: "Developer Tools",
    description:
      "Comprehensive development environment with modern tools and libraries",
    color: "from-indigo-400 to-purple-500",
  },
  {
    icon: "📱",
    title: "Own Apps & Utils",
    description: "We have made some own apps, to simplify linux... reduce terminal headache",
    color:""
  },
  {
    icon: "📖",
    title: "Docs for Everything",
    description: "We have curated docs for N0ctOS, apps, Arch, Hyprland, FAQs and much more",
    color:""
  },
  {
    icon: "👥",
    title: "Community support",
    description: "Discord Server, Reddit, Github Issues... You will get help from everywhere",
    color:""
  },
  {
    icon: "💪",
    title: "Battle-tested Stable",
    description: "We do 3 step Stability check, before releasing a major Version",
    color:""
  },
  {
    icon: "🧰",
    title: "Anyone can Fix us",
    description: "Found a bug ? Just report us, or fix yourself and merge your fix",
    color:""
  },
  {
    icon: "👶",
    title: "Easy For Beginners",
    description: "Easy install, Easy daily drive, Easy fixes... Arch made simple",
    color:""
  },
  {
    icon: "💻",
    title: "Customized Desktop",
    description: "We have done all customizations, that you need",
    color:""
  },
  {
    icon: "🚫",
    title: "No AI, No BLOAT",
    description: "We only give Essentials, You install what you need",
    color:""
  },
];

function Features() {
  const { scrollY } = useScroll();
  const featuresY = useTransform(scrollY, [0, 1000], [0, -100]);

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1,
        delayChildren: 0.2,
      },
    },
  };

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: {
        type: "spring",
        stiffness: 100,
        damping: 20,
      },
    },
  };

  return (
    <div className=" text-white font-tektur flex flex-col justify-center content-center items-center">
      <main className="flex-grow">
        <section className="py-24 relative">
          <motion.div
            className="absolute inset-0 bg-gradient-radial opacity-30"
            style={{ y: featuresY }}
          />

          <div className="container relative z-10">
            <motion.h2
              className="section-title text-5xl md:text-6xl"
              initial={{ y: 30, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6 }}
            >
              <img
                src={LOGO_URL}
                alt="N0ctOS Logo"
                className="w-[clamp(100px,100%,400px)] object-contain mx-auto mb-6 drop-shadow-[0_0_20px_rgba(139,92,246,0.5)]"
              />
              Why Choose{" "}
              <span className="bg-gradient-to-r from-accent to-primary-500 bg-clip-text text-transparent">
                N0ctOS
              </span>
              ?
            </motion.h2>

            <motion.div
              className="grid md:grid-cols-2 lg:grid-cols-4 gap-8"
              variants={containerVariants}
              initial="hidden"
              whileInView="visible"
              viewport={{ once: true }}
            >
              {features_list.map((feature) => (
                <motion.div
                  key={feature.title}
                  className="feature-card group relative overflow-hidden"
                  variants={itemVariants}
                  whileHover={{
                    scale: 1.05,
                    rotateY: 5,
                    borderColor: "rgba(128, 0, 128, 0.5)",
                  }}
                >
                  <motion.div
                    className={`absolute inset-0 bg-gradient-to-br ${feature.color} opacity-0 group-hover:opacity-10 transition-opacity duration-300`}
                  />

                  <motion.div
                    className="text-6xl mb-6 relative z-10"
                    whileHover={{ scale: 1.2, rotate: 10 }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  >
                    {feature.icon}
                  </motion.div>

                  <h3 className="text-2xl font-bold mb-4 text-white relative z-10 group-hover:text-primary-400 transition-colors">
                    {feature.title}
                  </h3>

                  <p className="text-gray-400 leading-relaxed relative z-10 text-sm">
                    {feature.description}
                  </p>

                  <motion.div
                    className="absolute bottom-0 left-0 w-0 h-1 bg-gradient-to-r opacity-0 group-hover:opacity-100"
                    style={{
                      backgroundImage: `linear-gradient(to right, ${feature.color.split(" ")[1]}, ${feature.color.split(" ")[3]})`,
                    }}
                    initial={{ width: 0 }}
                    whileHover={{ width: "100%" }}
                    transition={{ duration: 0.3 }}
                  />
                </motion.div>
              ))}
            </motion.div>
          </div>
        </section>
      </main>
      <span className="self-center text-slate-700 text-xs">*security breach is responsibility of user. Although we provide open source and safe softwares, user may install breach-er softwares</span>
    </div>
  );
}

export default Features;
