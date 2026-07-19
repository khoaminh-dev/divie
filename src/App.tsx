import './App.css'
import { Header } from './components/Header'
import { Hero } from './components/Hero'
import { ProblemSection } from './components/ProblemSection'
import { ResearchInsight } from './components/ResearchInsight'
import { SolutionSection } from './components/SolutionSection'
import { FeatureBento } from './components/FeatureBento'
import { AiSection } from './components/AiSection'
import { TechSection } from './components/TechSection'
import { ProductScope } from './components/ProductScope'
import { FinalCta } from './components/FinalCta'
import { Footer } from './components/Footer'

function App() {
  return (
    <div className="site-shell">
      <Header />
      <main>
        <Hero />
        <ProblemSection />
        <ResearchInsight />
        <SolutionSection />
        <FeatureBento />
        <AiSection />
        <TechSection />
        <ProductScope />
        <FinalCta />
      </main>
      <Footer />
    </div>
  )
}

export default App
