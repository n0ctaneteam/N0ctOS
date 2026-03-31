import { Link } from "react-router-dom";
import { Github, Cpu } from "lucide-react";

export default function Footer() {
  return (
    <footer className="bg-muted/50 border-t border-white/5 py-12 px-6">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12">
        <div className="space-y-4">
          <div className="flex items-center gap-2 font-bold text-xl tracking-tighter">
            <Cpu className="w-6 h-6 text-primary" />
            <span>N0ctOS</span>
          </div>
          <p className="text-muted-foreground text-sm leading-relaxed">
            A performance-driven, Arch-based Linux distribution designed for the modern user. Sleek, fast, and nocturnal.
          </p>
        </div>
        
        <div>
          <h4 className="font-semibold mb-4">Project</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><Link to="/features" className="hover:text-primary transition-colors">Features</Link></li>
            <li><Link to="/download" className="hover:text-primary transition-colors">Download</Link></li>
            <li><Link to="/docs" className="hover:text-primary transition-colors">Documentation</Link></li>
          </ul>
        </div>

        <div>
          <h4 className="font-semibold mb-4">Community</h4>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li><a href="#" className="hover:text-primary transition-colors">Discord</a></li>
            <li><a href="#" className="hover:text-primary transition-colors">Forum</a></li>
            <li><a href="#" className="hover:text-primary transition-colors">Wiki</a></li>
          </ul>
        </div>

        <div>
          <h4 className="font-semibold mb-4">Social</h4>
          <div className="flex gap-4">
            <a href="https://github.com/n0ctaneteam/N0ctOS" target="_blank" rel="noopener noreferrer" className="text-muted-foreground hover:text-primary transition-colors">
              <Github className="w-5 h-5" />
            </a>
          </div>
        </div>
      </div>
      <div className="max-w-7xl mx-auto mt-12 pt-8 border-t border-white/5 text-center text-xs text-muted-foreground">
        &copy; {new Date().getFullYear()} N0ctOS Project. Built on Arch Linux.
      </div>
    </footer>
  );
}
