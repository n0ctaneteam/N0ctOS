import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';

const CustomCursor = () => {
  const cursorRef = useRef<HTMLDivElement>(null);
  const trailRef = useRef<HTMLDivElement>(null);
  const [isHovering, setIsHovering] = useState(false);
  const [isVisible, setIsVisible] = useState(false);
  const positionRef = useRef({ x: 0, y: 0 });
  const rafRef = useRef<number>();

  useEffect(() => {
    const updateCursor = () => {
      if (cursorRef.current) {
        cursorRef.current.style.transform = `translate(${positionRef.current.x - 10}px, ${positionRef.current.y - 10}px)`;
      }
      if (trailRef.current) {
        trailRef.current.style.transform = `translate(${positionRef.current.x - 20}px, ${positionRef.current.y - 20}px)`;
      }
    };

    const handleMouseMove = (e: MouseEvent) => {
      positionRef.current = { x: e.clientX, y: e.clientY };
      
      if (!isVisible) setIsVisible(true);
      
      // Cancel pending RAF and schedule new one
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
      rafRef.current = requestAnimationFrame(updateCursor);
    };

    // Check if element or any parent is clickable
    const isClickable = (el: HTMLElement): boolean => {
      return !!(
        el.tagName === 'A' ||
        el.tagName === 'BUTTON' ||
        el.closest('a') ||
        el.closest('button') ||
        el.closest('.btn') ||
        el.closest('[role="button"]') ||
        el.closest('label') ||
        el.onclick ||
        el.getAttribute('role') === 'button'
      );
    };

    const handleMouseOver = (e: MouseEvent) => {
      if (isClickable(e.target as HTMLElement)) {
        setIsHovering(true);
      }
    };

    const handleMouseOut = (e: MouseEvent) => {
      if (isClickable(e.target as HTMLElement)) {
        setIsHovering(false);
      }
    };

    document.addEventListener('mousemove', handleMouseMove, { passive: true });
    document.addEventListener('mouseover', handleMouseOver, { passive: true });
    document.addEventListener('mouseout', handleMouseOut, { passive: true });

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseover', handleMouseOver);
      document.removeEventListener('mouseout', handleMouseOut);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [isVisible]);

  if (!isVisible) return null;

  return (
    <>
      {/* Main cursor - direct DOM manipulation for smooth tracking */}
      <motion.div
        ref={cursorRef}
        className="fixed top-0 left-0 w-5 h-5 bg-primary-500 rounded-full pointer-events-none z-[9999] mix-blend-difference"
        initial={{ scale: 1 }}
        animate={{ scale: isHovering ? 2 : 1 }}
        transition={{ type: 'spring', stiffness: 500, damping: 28, mass: 0.5 }}
        style={{
          boxShadow: '0 0 20px rgba(0, 212, 255, 0.5)',
          willChange: 'transform',
        }}
      />
      
      {/* Cursor trail */}
      <motion.div
        ref={trailRef}
        className="fixed top-0 left-0 w-10 h-10 border-2 border-primary-400 rounded-full pointer-events-none z-[9998] mix-blend-difference"
        initial={{ scale: 1 }}
        animate={{ scale: isHovering ? 1.5 : 1 }}
        transition={{ type: 'spring', stiffness: 200, damping: 20, mass: 0.8 }}
        style={{ willChange: 'transform' }}
      />
    </>
  );
};

export default CustomCursor;
