import { Heartbeat } from '@phosphor-icons/react'

export function Header() {
  return (
    <header className="site-header">
      <a className="brand" href="#top" aria-label="DiVie home">
        <span className="brand-mark">
          <Heartbeat size={20} weight="bold" />
        </span>
        <span>DiVie</span>
      </a>

      <nav className="desktop-nav" aria-label="Điều hướng chính">
        <a href="#top">Sản phẩm</a>
        <a href="#tinh-nang">AI</a>
        <a href="#giai-phap">Giải pháp</a>
        <a href="#cong-nghe">Công nghệ</a>
      </nav>

      <div className="header-actions">
        <a className="login-link" href="#van-de">
          Câu chuyện
        </a>
        <a className="nav-cta" href="#demo">
          Xem demo
        </a>
      </div>
    </header>
  )
}
