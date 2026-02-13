import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import './index.css'
import './App.css'

// Import pages
import Home from './pages/Home'
import Features from './pages/Features'
import Download from './pages/Download'
import Team from './pages/Team'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter basename="/N0ctOS">
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/features" element={<Features />} />
        <Route path="/download" element={<Download />} />
        <Route path="/team" element={<Team />} />
      </Routes>
    </BrowserRouter>
  </StrictMode>,
)
