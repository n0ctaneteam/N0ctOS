import { Link } from "react-router-dom";
import { Github, Cpu } from "lucide-react";

const LOGO_URL = "./logo-transparent.png";
export default function Footer() {
  return (
    <footer className="bg-muted/50 border-t border-white/5 py-12 px-6">
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-12">
        <div className="flex flex-col items-start">
            <Link to="/" className="mb-4 max-w-[35%]">
              <img 
                src={LOGO_URL} 
                alt="N0ctOS" 
                className="object-contain"
              />
            </Link>
            <p className="text-muted-foreground text-xs leading-relaxed">
              The Future of Linux. Built for developers, designed for humans.
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
