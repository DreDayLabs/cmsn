"use client";

import { useState, useEffect } from "react";

const CMSN = () => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [scrolled, setScrolled] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [activeTab, setActiveTab] = useState("women");
  const [hoveredPillar, setHoveredPillar] = useState(null);

  useEffect(() => {
    setTimeout(() => setLoaded(true), 150);
    const handleScroll = () => setScrolled(window.scrollY > 60);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  const products = {
    women: [
      { name: "Commission Bra", category: "Training", price: "$68", tag: "BESTSELLER" },
      { name: "Earn Legging", category: "Performance", price: "$98", tag: "NEW" },
      { name: "Studio Hoodie", category: "Recovery", price: "$128", tag: null },
      { name: "// Seamless Set", category: "Training", price: "$148", tag: "LOW STOCK" },
    ],
    men: [
      { name: "Commission Short", category: "Training", price: "$78", tag: "BESTSELLER" },
      { name: "Earn Jogger", category: "Performance", price: "$108", tag: "NEW" },
      { name: "Studio Quarter Zip", category: "Recovery", price: "$118", tag: null },
      { name: "// Compression Set", category: "Training", price: "$138", tag: "COMING SOON" },
    ],
  };

  // Unsplash gym/fitness images — no brands, luxury editorial feel
  const heroImages = [
    "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1600&q=80&auto=format&fit=crop",
    "https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=1600&q=80&auto=format&fit=crop",
    "https://images.unsplash.com/photo-1549060279-7e168fcee0c2?w=1600&q=80&auto=format&fit=crop",
  ];

  const editorialImages = [
    "https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800&q=80&auto=format&fit=crop",
    "https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=800&q=80&auto=format&fit=crop",
    "https://images.unsplash.com/photo-1583500178450-e59e4309b57d?w=800&q=80&auto=format&fit=crop",
    "https://images.unsplash.com/photo-1507398941214-572c25f4b1dc?w=800&q=80&auto=format&fit=crop",
  ];

  const productImages: Record<string, string[]> = {
    women: [
      "https://images.unsplash.com/photo-1518611012118-696072aa579a?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1594737625785-a6cbdabd333c?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1544216717-3bbf52512659?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1571945153237-4929e783af4a?w=600&q=80&auto=format&fit=crop",
    ],
    men: [
      "https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=600&q=80&auto=format&fit=crop",
      "https://images.unsplash.com/photo-1533681904393-9ab6eee7e408?w=600&q=80&auto=format&fit=crop",
    ],
  };

  return (
    <div style={{ background: "#0A0A0A", color: "#FAFAF8", minHeight: "100vh", fontFamily: "'Helvetica Neue', Arial, sans-serif", overflowX: "hidden" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:ital,opsz,wght@0,9..40,200;0,9..40,300;0,9..40,400;1,9..40,200;1,9..40,300&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }

        .menu-overlay {
          position: fixed; inset: 0; background: #000; z-index: 300;
          display: flex; flex-direction: column; justify-content: center;
          padding: 80px 100px;
          clip-path: inset(0 100% 0 0);
          transition: clip-path 0.7s cubic-bezier(0.76,0,0.24,1);
        }
        .menu-overlay.open { clip-path: inset(0 0% 0 0); }

        .menu-item {
          font-family: 'Bebas Neue', sans-serif;
          font-size: clamp(48px, 9vw, 100px);
          color: #FAFAF8; line-height: 1.0; cursor: pointer;
          display: block; text-decoration: none;
          letter-spacing: 0.02em;
          border-bottom: 1px solid rgba(250,250,248,0.08);
          padding: 12px 0;
          transition: color 0.2s, padding-left 0.3s;
        }
        .menu-item:hover { color: rgba(250,250,248,0.3); padding-left: 20px; }

        .nav-link {
          font-size: 9px; letter-spacing: 0.22em; text-transform: uppercase;
          cursor: pointer; transition: opacity 0.2s; text-decoration: none;
          font-family: 'Helvetica Neue', sans-serif;
        }
        .nav-link:hover { opacity: 0.4; }

        .btn-white {
          font-family: 'Helvetica Neue', sans-serif; font-size: 9px;
          letter-spacing: 0.25em; text-transform: uppercase;
          background: #FAFAF8; color: #0A0A0A; border: none;
          padding: 16px 44px; cursor: pointer; transition: opacity 0.2s;
        }
        .btn-white:hover { opacity: 0.82; }

        .btn-ghost-white {
          font-family: 'Helvetica Neue', sans-serif; font-size: 9px;
          letter-spacing: 0.25em; text-transform: uppercase;
          background: transparent; color: #FAFAF8;
          border: 1px solid rgba(250,250,248,0.25);
          padding: 16px 44px; cursor: pointer; transition: border-color 0.2s;
        }
        .btn-ghost-white:hover { border-color: rgba(250,250,248,0.7); }

        .btn-ghost-black {
          font-family: 'Helvetica Neue', sans-serif; font-size: 9px;
          letter-spacing: 0.25em; text-transform: uppercase;
          background: transparent; color: #0A0A0A;
          border: 1px solid rgba(10,10,10,0.25);
          padding: 16px 44px; cursor: pointer; transition: border-color 0.2s;
        }
        .btn-ghost-black:hover { border-color: #0A0A0A; }

        .product-card { cursor: pointer; }
        .product-img-wrap {
          position: relative; overflow: hidden;
          aspect-ratio: 3/4; margin-bottom: 18px;
          background: #1A1A1A;
        }
        .product-img-wrap img {
          width: 100%; height: 100%; object-fit: cover;
          transition: transform 0.8s cubic-bezier(0.22,1,0.36,1), filter 0.4s;
          filter: grayscale(20%);
        }
        .product-card:hover .product-img-wrap img { transform: scale(1.04); filter: grayscale(0%); }

        .tab-btn {
          font-family: 'Helvetica Neue', sans-serif; font-size: 9px;
          letter-spacing: 0.22em; text-transform: uppercase;
          background: transparent; border: none; cursor: pointer;
          padding: 12px 0; color: rgba(250,250,248,0.3);
          border-bottom: 1px solid transparent;
          transition: all 0.2s;
        }
        .tab-btn.active { color: #FAFAF8; border-bottom-color: #FAFAF8; }

        .editorial-img {
          width: 100%; height: 100%; object-fit: cover;
          filter: grayscale(100%) contrast(1.05);
          transition: filter 0.6s, transform 0.8s cubic-bezier(0.22,1,0.36,1);
        }
        .editorial-block:hover .editorial-img { filter: grayscale(60%) contrast(1.05); transform: scale(1.03); }

        .marquee-track {
          display: flex; gap: 80px;
          animation: marqueeL 28s linear infinite; white-space: nowrap;
        }
        @keyframes marqueeL {
          0% { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }

        @keyframes fadeUp {
          from { opacity: 0; transform: translateY(40px); }
          to { opacity: 1; transform: translateY(0); }
        }
        .hero-in { animation: fadeUp 1.1s cubic-bezier(0.22,1,0.36,1) both; }

        .stat-line {
          border-top: 1px solid rgba(250,250,248,0.1);
          padding: 32px 0;
          display: grid; grid-template-columns: 120px 1fr;
          gap: 40px; align-items: center;
        }

        input[type=email] {
          background: transparent; border: none;
          border-bottom: 1px solid rgba(250,250,248,0.2);
          outline: none; font-family: 'DM Sans', sans-serif;
          font-size: 14px; color: #FAFAF8; padding: 12px 0;
          width: 280px; letter-spacing: 0.03em;
          transition: border-color 0.2s;
        }
        input[type=email]:focus { border-bottom-color: rgba(250,250,248,0.7); }
        input[type=email]::placeholder { color: rgba(250,250,248,0.2); font-style: italic; }

        .tag-pill {
          font-family: 'Helvetica Neue', sans-serif; font-size: 7px;
          letter-spacing: 0.2em; text-transform: uppercase;
          padding: 4px 10px; border: 1px solid rgba(250,250,248,0.3);
          color: rgba(250,250,248,0.6);
        }
        .tag-pill.new { border-color: #FAFAF8; color: #FAFAF8; }
      `}</style>

      {/* MENU */}
      <div className={`menu-overlay ${menuOpen ? "open" : ""}`}>
        <div style={{ position: "absolute", top: 28, right: 52 }}>
          <span className="nav-link" style={{ color: "#FAFAF8" }} onClick={() => setMenuOpen(false)}>CLOSE ✕</span>
        </div>
        {["Shop Women", "Shop Men", "Training", "Recovery", "About", "Moris Hill"].map((item, i) => (
          <a key={item} className="menu-item">{item}</a>
        ))}
        <div style={{ marginTop: 40, display: "flex", gap: 40 }}>
          {["Instagram", "TikTok", "Newsletter"].map(s => (
            <span key={s} className="nav-link" style={{ color: "rgba(250,250,248,0.3)", fontSize: 9 }}>{s}</span>
          ))}
        </div>
      </div>

      {/* NAV */}
      <nav style={{
        position: "fixed", top: 0, left: 0, right: 0, zIndex: 200,
        padding: "24px 52px", display: "flex", justifyContent: "space-between", alignItems: "center",
        background: scrolled ? "rgba(10,10,10,0.92)" : "transparent",
        backdropFilter: scrolled ? "blur(20px)" : "none",
        borderBottom: scrolled ? "1px solid rgba(250,250,248,0.07)" : "none",
        transition: "all 0.5s",
      }}>
        <span className="nav-link" style={{ color: "#FAFAF8" }} onClick={() => setMenuOpen(true)}>MENU</span>
        <div>
          <span style={{
            fontFamily: "'Bebas Neue', sans-serif", fontSize: 26,
            letterSpacing: "0.18em", color: "#FAFAF8",
          }}>CMSN //</span>
        </div>
        <div style={{ display: "flex", gap: 32 }}>
          <span className="nav-link" style={{ color: "#FAFAF8" }}>SEARCH</span>
          <span className="nav-link" style={{ color: "#FAFAF8" }}>BAG (0)</span>
        </div>
      </nav>

      {/* HERO — Full bleed dark gym */}
      <section style={{ height: "100vh", position: "relative", overflow: "hidden" }}>
        <img
          src={heroImages[0]}
          alt="Training"
          style={{
            position: "absolute", inset: 0, width: "100%", height: "100%",
            objectFit: "cover", objectPosition: "center",
            filter: "grayscale(100%) brightness(0.35) contrast(1.1)",
            transform: loaded ? "scale(1.0)" : "scale(1.06)",
            transition: "transform 1.8s cubic-bezier(0.22,1,0.36,1)",
          }}
        />
        {/* Gradient overlay */}
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(to top, rgba(10,10,10,0.95) 0%, rgba(10,10,10,0.4) 50%, rgba(10,10,10,0.2) 100%)",
        }} />

        {/* Vertical right label */}
        <div style={{
          position: "absolute", right: 52, top: "50%",
          transform: "translateY(-50%) rotate(90deg)",
          fontSize: 8, letterSpacing: "0.35em",
          color: "rgba(250,250,248,0.2)", textTransform: "uppercase", whiteSpace: "nowrap",
        }}>CMSN — EARN YOUR COMMISSION — SS 2026</div>

        <div className="hero-in" style={{
          position: "absolute", bottom: 0, left: 0, right: 0,
          padding: "0 64px 80px",
          animationDelay: "0.4s",
        }}>
          <div style={{
            fontFamily: "'Helvetica Neue', sans-serif", fontSize: 9,
            letterSpacing: "0.3em", textTransform: "uppercase",
            color: "rgba(250,250,248,0.4)", marginBottom: 24,
          }}>Spring / Summer 2026</div>

          <h1 style={{
            fontFamily: "'Bebas Neue', sans-serif",
            fontSize: "clamp(88px, 17vw, 220px)",
            fontWeight: 400, lineHeight: 0.86,
            color: "#FAFAF8", letterSpacing: "0.01em",
            marginBottom: 48,
          }}>
            THE BODY<br />
            IS THE<br />
            COMMISSION.
          </h1>

          <div style={{ display: "flex", alignItems: "center", gap: 32 }}>
            <button className="btn-white">Shop Women</button>
            <button className="btn-ghost-white">Shop Men</button>
            <div style={{ marginLeft: 16, display: "flex", gap: 40 }}>
              {[["24", "Collections"], ["SS26", "Season"], ["NYC", "Origin"]].map(([val, label]) => (
                <div key={label}>
                  <div style={{ fontFamily: "'Bebas Neue', sans-serif", fontSize: 22, color: "#FAFAF8", lineHeight: 1 }}>{val}</div>
                  <div style={{ fontSize: 8, letterSpacing: "0.2em", textTransform: "uppercase", color: "rgba(250,250,248,0.3)", marginTop: 4 }}>{label}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* MARQUEE */}
      <div style={{
        background: "#FAFAF8", padding: "12px 0", overflow: "hidden",
        borderTop: "none", borderBottom: "none",
      }}>
        <div className="marquee-track">
          {Array(2).fill(["EARN YOUR COMMISSION", "·", "BUILT FOR THE WORK", "·", "SPRING SUMMER 2026", "·", "CMSN", "·", "NEW YORK CITY", "·", "PERFORMANCE WEAR", "·", "EARN IT", "·"]).flat().map((t, i) => (
            <span key={i} style={{
              fontFamily: "'Helvetica Neue', sans-serif",
              fontSize: 9, letterSpacing: "0.28em", textTransform: "uppercase",
              color: t === "·" ? "rgba(10,10,10,0.2)" : "#0A0A0A",
            }}>{t}</span>
          ))}
        </div>
      </div>

      {/* EDITORIAL GRID — 4 gym images */}
      <section style={{ background: "#0A0A0A", padding: "80px 52px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1.4fr 1fr 1fr 1fr", gap: 4, height: 520 }}>
          {editorialImages.map((img, i) => (
            <div key={i} className="editorial-block" style={{ position: "relative", overflow: "hidden", cursor: "pointer" }}>
              <img src={img} alt="Training" className="editorial-img" />
              {i === 0 && (
                <div style={{
                  position: "absolute", bottom: 24, left: 24,
                  fontFamily: "'Bebas Neue', sans-serif",
                  fontSize: 32, color: "#FAFAF8", letterSpacing: "0.04em",
                  lineHeight: 1, textShadow: "0 2px 20px rgba(0,0,0,0.8)",
                }}>THE<br />WORK</div>
              )}
            </div>
          ))}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 40 }}>
          <p style={{
            fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 200,
            fontStyle: "italic", color: "rgba(250,250,248,0.4)", lineHeight: 1.8, maxWidth: 480,
          }}>
            This is not about how you look leaving the gym. It's about what you're willing to do inside it. CMSN is built for that moment.
          </p>
          <span className="nav-link" style={{ color: "rgba(250,250,248,0.5)" }}>VIEW THE COLLECTION →</span>
        </div>
      </section>

      {/* SHOP SECTION — Clean white with real imagery */}
      <section style={{ background: "#F5F3F0", padding: "100px 52px" }}>
        <div style={{ maxWidth: 1200, margin: "0 auto" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: 56 }}>
            <div>
              <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 9, letterSpacing: "0.25em", textTransform: "uppercase", color: "rgba(10,10,10,0.35)", marginBottom: 14 }}>SS26 Collection</div>
              <h2 style={{ fontFamily: "'Bebas Neue', sans-serif", fontSize: "clamp(44px, 5vw, 68px)", letterSpacing: "0.02em", color: "#0A0A0A", lineHeight: 0.95 }}>NEW ARRIVALS</h2>
            </div>
            <div style={{ display: "flex", gap: 40, borderBottom: "1px solid rgba(10,10,10,0.1)" }}>
              {["women", "men"].map(tab => (
                <button key={tab} className={`tab-btn ${activeTab === tab ? "active" : ""}`}
                  style={{ color: activeTab === tab ? "#0A0A0A" : "rgba(10,10,10,0.3)", borderBottomColor: activeTab === tab ? "#0A0A0A" : "transparent" }}
                  onClick={() => setActiveTab(tab)}>
                  {tab.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 28 }}>
            {products[activeTab].map((p, i) => (
              <div key={p.name} className="product-card">
                <div className="product-img-wrap">
                  <img src={productImages[activeTab][i]} alt={p.name} />
                  {p.tag && (
                    <div style={{
                      position: "absolute", top: 16, left: 16,
                      fontFamily: "'Helvetica Neue', sans-serif", fontSize: 7,
                      letterSpacing: "0.2em", textTransform: "uppercase",
                      background: p.tag === "NEW" ? "#0A0A0A" : "rgba(250,250,248,0.9)",
                      color: p.tag === "NEW" ? "#FAFAF8" : "#0A0A0A",
                      padding: "5px 10px",
                    }}>{p.tag}</div>
                  )}
                </div>
                <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.2em", textTransform: "uppercase", color: "rgba(10,10,10,0.35)", marginBottom: 6 }}>{p.category}</div>
                <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 400, color: "#0A0A0A", marginBottom: 6 }}>{p.name}</div>
                <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, fontWeight: 500, color: "#0A0A0A" }}>{p.price}</div>
              </div>
            ))}
          </div>
          <div style={{ textAlign: "center", marginTop: 72 }}>
            <button className="btn-ghost-black">View All Products</button>
          </div>
        </div>
      </section>

      {/* SPLIT EDITORIAL — Dark luxury */}
      <section style={{ display: "grid", gridTemplateColumns: "1fr 1fr", minHeight: "90vh" }}>
        <div style={{ position: "relative", overflow: "hidden" }}>
          <img
            src={heroImages[1]}
            alt="Performance"
            style={{ width: "100%", height: "100%", objectFit: "cover", filter: "grayscale(100%) brightness(0.4) contrast(1.1)" }}
          />
          <div style={{
            position: "absolute", inset: 0,
            background: "linear-gradient(to top, rgba(10,10,10,0.9) 0%, transparent 60%)",
          }} />
          <div style={{ position: "absolute", bottom: 56, left: 56, right: 56 }}>
            <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.3em", color: "rgba(250,250,248,0.4)", textTransform: "uppercase", marginBottom: 20 }}>Performance Edit</div>
            <h3 style={{
              fontFamily: "'Bebas Neue', sans-serif",
              fontSize: "clamp(44px, 5vw, 68px)",
              color: "#FAFAF8", lineHeight: 0.95, letterSpacing: "0.01em", marginBottom: 28,
            }}>BUILT FOR<br />THE WORK.</h3>
            <button className="btn-white">Shop Training</button>
          </div>
        </div>
        <div style={{ position: "relative", overflow: "hidden" }}>
          <img
            src={heroImages[2]}
            alt="Recovery"
            style={{ width: "100%", height: "100%", objectFit: "cover", filter: "grayscale(100%) brightness(0.45) contrast(1.05)" }}
          />
          <div style={{
            position: "absolute", inset: 0,
            background: "linear-gradient(to top, rgba(10,10,10,0.9) 0%, transparent 60%)",
          }} />
          <div style={{ position: "absolute", bottom: 56, left: 56, right: 56 }}>
            <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.3em", color: "rgba(250,250,248,0.4)", textTransform: "uppercase", marginBottom: 20 }}>Recovery Edit</div>
            <h3 style={{
              fontFamily: "'Bebas Neue', sans-serif",
              fontSize: "clamp(44px, 5vw, 68px)",
              color: "#FAFAF8", lineHeight: 0.95, letterSpacing: "0.01em", marginBottom: 28,
            }}>REST IS<br />EARNED TOO.</h3>
            <button className="btn-ghost-white">Shop Recovery</button>
          </div>
        </div>
      </section>

      {/* SPECS / FABRIC DETAILS */}
      <section style={{ background: "#0A0A0A", padding: "100px 52px" }}>
        <div style={{ maxWidth: 1000, margin: "0 auto" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 80 }}>
            <h2 style={{
              fontFamily: "'Bebas Neue', sans-serif",
              fontSize: "clamp(48px, 6vw, 80px)",
              color: "#FAFAF8", lineHeight: 0.95, letterSpacing: "0.01em",
              maxWidth: 400,
            }}>ENGINEERED.<br />NOT JUST<br />DESIGNED.</h2>
            <p style={{
              fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 200,
              fontStyle: "italic", color: "rgba(250,250,248,0.4)", lineHeight: 1.9,
              maxWidth: 360, paddingTop: 8,
            }}>
              Every CMSN piece goes through 14 wear tests before production. Sweat. Stretch. Sprint. Repeat. If it doesn't perform, it doesn't ship.
            </p>
          </div>
          {[
            { num: "01", label: "FOUR-WAY STRETCH", detail: "Full range of motion in every direction. No restriction. No compromise." },
            { num: "02", label: "MOISTURE CONTROL", detail: "Proprietary wicking technology. Sweat moves. You stay dry. You stay focused." },
            { num: "03", label: "TEMPERATURE REGULATION", detail: "Adaptive fabric responds to body heat. Cools when you push. Warms when you rest." },
            { num: "04", label: "ANTI-ODOR TREATMENT", detail: "72-hour freshness. Because the commission doesn't end at the gym door." },
          ].map((spec, i) => (
            <div key={spec.num} className="stat-line">
              <div style={{ fontFamily: "'Bebas Neue', sans-serif", fontSize: 13, letterSpacing: "0.1em", color: "rgba(250,250,248,0.2)" }}>{spec.num}</div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 10, letterSpacing: "0.2em", textTransform: "uppercase", color: "#FAFAF8" }}>{spec.label}</div>
                <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, fontWeight: 200, fontStyle: "italic", color: "rgba(250,250,248,0.35)", maxWidth: 420, textAlign: "right", lineHeight: 1.7 }}>{spec.detail}</div>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* FULL BLEED STATEMENT */}
      <section style={{ position: "relative", height: "70vh", overflow: "hidden" }}>
        <img
          src="https://images.unsplash.com/photo-1576678927484-cc907957088c?w=1600&q=80&auto=format&fit=crop"
          alt="Commitment"
          style={{ width: "100%", height: "100%", objectFit: "cover", filter: "grayscale(100%) brightness(0.25) contrast(1.15)" }}
        />
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          justifyContent: "center", alignItems: "center", textAlign: "center",
          padding: "0 48px",
        }}>
          <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.35em", textTransform: "uppercase", color: "rgba(250,250,248,0.35)", marginBottom: 28 }}>The CMSN Standard</div>
          <h2 style={{
            fontFamily: "'Bebas Neue', sans-serif",
            fontSize: "clamp(64px, 11vw, 140px)",
            color: "#FAFAF8", lineHeight: 0.9, letterSpacing: "0.01em",
            maxWidth: 900,
          }}>
            THE COMMISSION<br />IS EARNED IN<br />THE DARK.
          </h2>
        </div>
      </section>

      {/* MORIS HILL HOUSE */}
      <section style={{
        background: "#FAFAF8", padding: "60px 52px",
        display: "flex", justifyContent: "space-between", alignItems: "center",
      }}>
        <div>
          <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.25em", textTransform: "uppercase", color: "rgba(10,10,10,0.3)", marginBottom: 10 }}>Part of</div>
          <div style={{ fontFamily: "'Bebas Neue', sans-serif", fontSize: 36, letterSpacing: "0.15em", color: "rgba(10,10,10,0.35)" }}>MORIS HILL HOUSE</div>
        </div>
        <a style={{
          fontFamily: "'Helvetica Neue', sans-serif", fontSize: 9,
          letterSpacing: "0.22em", textTransform: "uppercase",
          color: "#0A0A0A", textDecoration: "none", cursor: "pointer",
          borderBottom: "1px solid #0A0A0A", paddingBottom: 2,
        }}>Visit morishill.com →</a>
      </section>

      {/* NEWSLETTER */}
      <section style={{ background: "#0A0A0A", padding: "100px 52px", textAlign: "center" }}>
        <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.3em", textTransform: "uppercase", color: "rgba(250,250,248,0.2)", marginBottom: 28 }}>Early Access</div>
        <h2 style={{
          fontFamily: "'Bebas Neue', sans-serif",
          fontSize: "clamp(52px, 8vw, 96px)",
          color: "#FAFAF8", lineHeight: 0.9, marginBottom: 20, letterSpacing: "0.01em",
        }}>FIRST TO EARN IT.</h2>
        <p style={{
          fontFamily: "'DM Sans', sans-serif", fontSize: 14, fontWeight: 200,
          fontStyle: "italic", color: "rgba(250,250,248,0.3)", marginBottom: 52, lineHeight: 1.8,
        }}>New drops. Training content. Zero noise.</p>
        <div style={{ display: "flex", justifyContent: "center", gap: 0 }}>
          <input type="email" placeholder="your@email.com" />
          <button className="btn-white" style={{ marginLeft: 2, padding: "12px 28px" }}>Join</button>
        </div>
      </section>

      {/* FOOTER */}
      <footer style={{ background: "#050505", padding: "52px", borderTop: "1px solid rgba(250,250,248,0.05)" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1.2fr 1fr 1fr 1fr", gap: 40, marginBottom: 52 }}>
          <div>
            <div style={{ fontFamily: "'Bebas Neue', sans-serif", fontSize: 24, letterSpacing: "0.15em", color: "#FAFAF8", marginBottom: 12 }}>CMSN //</div>
            <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 200, fontStyle: "italic", lineHeight: 1.9, color: "rgba(250,250,248,0.25)" }}>
              Performance wear.<br />New York City.<br />Earn it.
            </p>
          </div>
          {[
            { title: "SHOP", links: ["Women", "Men", "Training", "Recovery", "New Arrivals"] },
            { title: "BRAND", links: ["About", "Moris Hill", "Community", "Journal", "Press"] },
            { title: "HELP", links: ["Size Guide", "Shipping", "Returns", "Contact", "FAQ"] },
          ].map(col => (
            <div key={col.title}>
              <div style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.25em", textTransform: "uppercase", color: "rgba(250,250,248,0.18)", marginBottom: 24 }}>{col.title}</div>
              {col.links.map(l => (
                <div key={l} style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 300, lineHeight: 2.6, color: "rgba(250,250,248,0.35)", cursor: "pointer", transition: "color 0.2s" }}>{l}</div>
              ))}
            </div>
          ))}
        </div>
        <div style={{ borderTop: "1px solid rgba(250,250,248,0.05)", paddingTop: 24, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.15em", color: "rgba(250,250,248,0.15)" }}>© 2026 CMSN. PART OF MORIS HILL HOUSE.</span>
          <span style={{ fontFamily: "'Helvetica Neue', sans-serif", fontSize: 8, letterSpacing: "0.15em", color: "rgba(250,250,248,0.15)" }}>EARNYOURCMSN.COM</span>
        </div>
      </footer>
    </div>
  );
};

export default CMSN;