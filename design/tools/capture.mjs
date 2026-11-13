// Tangkap setiap halaman web KateringKita sebagai SVG (dom-to-svg) + PNG untuk diimpor ke FigCraft.
// Jalankan: node D:\PBL\design\tools\capture.mjs   (butuh backend :5050 + frontend :3050 + DB kateringkita_design)
import { createRequire } from "node:module";
import fs from "node:fs";
import { randomUUID } from "node:crypto";

const require = createRequire("D:/PBL/frontend/package.json");
const { chromium } = require("playwright");

const WEB = "http://localhost:3050";
const API = "http://localhost:5050/api/v1";
const OUT = "D:/PBL/design/capture";
const BUNDLE = "D:/figcraft/tools/dom2svg/bundle.js";
const PASS = "rahasia123";
const PASS_ADMIN_BARU = "rahasia1234";
const ADMIN = "081200000001";
const CITRA = "081100000003"; // demo terverifikasi
const SARI = "081100000001"; // demo menunggu verifikasi
const DEDI = "081100000004"; // demo ditangguhkan
const manifest = [];
// ONLY=<regex> : tangkap ulang sebagian layar saja; folder dan manifest lama dipertahankan, entri sama diganti.
const ONLY = process.env.ONLY ? new RegExp(process.env.ONLY) : null;

async function api(method, p, token, body, extra = {}) {
  const res = await fetch(`${API}${p}`, {
    method,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}), ...extra },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) throw new Error(`${method} ${p} -> ${res.status} ${JSON.stringify(json)}`);
  return json?.data;
}
const login = async (identifier, password = PASS) => (await api("POST", "/auth/login", undefined, { identifier, password, client: "web" })).token;
const coba = async (label, fn) => { try { return await fn(); } catch (e) { console.warn(`  lewati ${label}: ${String(e.message).slice(0, 160)}`); return null; } };

// ---------- seed ----------
async function seed() {
  console.log("seed...");
  let tokenAdmin = await login(ADMIN).catch(() => null);
  if (tokenAdmin) {
    await coba("ganti sandi admin", () => api("PUT", "/me/password", tokenAdmin, { current_password: PASS, new_password: PASS_ADMIN_BARU }));
  }
  tokenAdmin = await login(ADMIN, PASS_ADMIN_BARU);
  // Admin ops dengan sandi sementara (must_change_password) untuk layar "wajib ganti sandi"; dibuat sekali, lalu reset tiap run.
  const sandiOps = await coba("admin ops", async () => {
    const baru = await api("POST", "/admin/admins", tokenAdmin, { full_name: "Ops Desain", phone: "081200000002", admin_level: "ops" }).catch(() => null);
    if (baru?.temp_password) return baru.temp_password;
    const semua = await api("GET", "/admin/admins", tokenAdmin);
    const ops = (Array.isArray(semua) ? semua : semua.items ?? []).find((a) => a.phone === "081200000002");
    return (await api("POST", `/admin/admins/${ops.id}/reset-password`, tokenAdmin, {})).temp_password;
  });

  const tokenP = await login(CITRA);
  await coba("profil", () => api("PATCH", "/merchant/profile", tokenP, {
    open_time: "00:00", close_time: "23:59", pickup_point_ids: [2, 3], dine_in_enabled: true, // buka 24 jam agar checkout tidak ditolak MERCHANT_CLOSED
    description: "Minuman segar untuk mahasiswa. Pesan sebelum jam 11 untuk ambil siang.", service_mode: "both", wa_number: CITRA,
  }));
  const daftarMenu = async () => { const m = await api("GET", "/merchant/menus", tokenP); return Array.isArray(m) ? m : m.items ?? m.data ?? []; };
  let menus = await daftarMenu();
  if (menus.length < 5) {
    await coba("menu baru 1", () => api("POST", "/merchant/menus", tokenP, { name: "Nasi Ayam Bakar", category_id: 1, unit_label: "porsi", price: 18000, hpp: 11000, daily_quota: 30, prep_minutes: 20, is_preorder: false, preorder_days: 0, min_order_qty: 1, description: "Ayam bakar madu, nasi, lalapan, sambal." }));
    await coba("menu baru 2", () => api("POST", "/merchant/menus", tokenP, { name: "Paket Snack Rapat (pre-order)", category_id: 1, unit_label: "box", price: 25000, hpp: 15000, daily_quota: 50, prep_minutes: 60, is_preorder: true, preorder_days: 1, min_order_qty: 10, description: "Minimal 10 box, pesan H-1." }));
    menus = await daftarMenu();
  }
  const byName = (n) => menus.find((m) => m.name.startsWith(n));
  const esTeh = byName("Es Teh"), kopi = byName("Kopi"), jeruk = byName("Es Jeruk"), ayam = byName("Nasi Ayam");
  if (jeruk) await coba("kuota rendah", () => api("PATCH", `/merchant/menus/${jeruk.id}/quota`, tokenP, { quota_today: 2 }));
  if (kopi) await coba("menu nonaktif", () => api("PATCH", `/merchant/menus/${kopi.id}`, tokenP, { is_active: false }));

  await coba("daftar pembeli", () => api("POST", "/auth/customer/register", undefined, { full_name: "Rina Pembeli", email: "rina@mail.com", phone: "081280000001", password: PASS }));
  const tokenC = await login("081280000001");
  const pesan = (items, extra = {}) => api("POST", "/orders", tokenC, { items, pickup_point_id: 2, payment_method: "cod", ...extra }, { "Idempotency-Key": randomUUID() });
  const aksi = (code, a, body = {}) => api("POST", `/merchant/orders/${code}/${a}`, tokenP, body);
  const orders = {};
  const sudahAda = (await coba("daftar pesanan", () => api("GET", "/merchant/orders", tokenP))) ?? [];
  const adaPesanan = (Array.isArray(sudahAda) ? sudahAda : sudahAda.items ?? []).length > 0;
  if (adaPesanan) {
    // run ulang: pakai pesanan yang sudah ada, satu per status; pesanan "holding" selalu baru karena yang lama kedaluwarsa
    for (const o of Array.isArray(sudahAda) ? sudahAda : sudahAda.items ?? []) if (!orders[o.status] && o.status !== "holding") orders[o.status] = o.code;
    if (ayam && esTeh) orders.holding = await coba("o holding", async () => (await pesan([{ menu_id: ayam.id, qty: 2 }, { menu_id: esTeh.id, qty: 2 }], { note: "Tanpa sambal, ambil jam 12." })).code);
  } else if (ayam && esTeh) {
    orders.holding = await coba("o holding", async () => (await pesan([{ menu_id: ayam.id, qty: 2 }, { menu_id: esTeh.id, qty: 2 }], { note: "Tanpa sambal, ambil jam 12." })).code);
    orders.confirmed = await coba("o confirmed", async () => { const c = (await pesan([{ menu_id: ayam.id, qty: 1 }])).code; await aksi(c, "confirm"); return c; });
    orders.cooking = await coba("o cooking", async () => { const c = (await pesan([{ menu_id: esTeh.id, qty: 3 }])).code; await aksi(c, "confirm"); await aksi(c, "cook"); return c; });
    orders.ready = await coba("o ready", async () => { const c = (await pesan([{ menu_id: ayam.id, qty: 1 }, { menu_id: esTeh.id, qty: 1 }])).code; await aksi(c, "confirm"); await aksi(c, "cook"); await aksi(c, "ready"); return c; });
    orders.completed = await coba("o completed", async () => { const c = (await pesan([{ menu_id: ayam.id, qty: 2 }])).code; await aksi(c, "confirm"); await aksi(c, "cook"); await aksi(c, "ready"); await aksi(c, "complete"); return c; });
    orders.rejected = await coba("o rejected", async () => { const c = (await pesan([{ menu_id: esTeh.id, qty: 1 }])).code; await aksi(c, "reject", { reason: "Bahan habis hari ini." }); return c; });
    if (orders.completed) await coba("ulasan", () => api("POST", `/orders/${orders.completed}/reviews`, tokenC, { items: [{ menu_id: ayam.id, rating: 5, comment: "Ayamnya empuk, bumbunya meresap. Pengambilan tepat waktu." }] }));
  }
  const kini = Date.now(), hari = 86400000;
  await coba("promo", () => api("POST", "/merchant/promos", tokenP, { code: "HEMAT10", description: "Diskon 10% minimal belanja 20rb", type: "percent", value: 10, max_discount: 5000, min_subtotal: 20000, quota: 100, per_user_limit: 1, starts_at: new Date(kini - hari).toISOString(), ends_at: new Date(kini + 30 * hari).toISOString(), is_active: true }));
  let tables = (await coba("daftar meja", () => api("GET", "/merchant/tables", tokenP))) ?? [];
  if (!tables.length) { await coba("meja", () => api("POST", "/merchant/tables", tokenP, { label: "Meja 1" })); await coba("meja2", () => api("POST", "/merchant/tables", tokenP, { label: "Meja 2" })); tables = await api("GET", "/merchant/tables", tokenP); }
  const tokenMeja = tables[0]?.token ?? null;
  // pesanan holding dibuat lagi tepat sebelum layar penjual ditangkap supaya belum kedaluwarsa
  const buatHolding = () => (ayam && esTeh) ? coba("o holding", async () => (await pesan([{ menu_id: ayam.id, qty: 2 }, { menu_id: esTeh.id, qty: 2 }], { note: "Tanpa sambal, ambil jam 12." })).code) : null;
  return { orders, menuId: ayam?.id ?? menus[0]?.id, tokenMeja, sandiOps, buatHolding };
}

// ---------- capture ----------
const hidrasi = (page) => page.waitForFunction(() => { const b = document.querySelector("button[type=submit],button"); return !!b && Object.keys(b).some((k) => k.startsWith("__reactProps$")); }, null, { timeout: 20000 }).catch(() => {});

async function loginUI(page, identifier, password = PASS) {
  await page.goto(`${WEB}/login`, { timeout: 120000 });
  await hidrasi(page);
  await page.getByLabel("Email atau nomor WA").fill(identifier);
  await page.getByLabel(/^Kata sandi/).fill(password);
  await page.getByRole("button", { name: "Masuk" }).click();
  await page.waitForURL((u) => !u.pathname.startsWith("/login"), { timeout: 30000 });
}

const BUNDLE_SRC = fs.readFileSync(BUNDLE, "utf8") + "\nwindow.domToSvg = domToSvg;";

async function capture(page, name, meta = {}, maxHeight = 7000) {
  if (ONLY && !ONLY.test(name)) return;
  await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(400);
  await page.evaluate(() => document.fonts.ready);
  const svg = await page.evaluate(async ({ maxHeight, bundle }) => {
    document.querySelectorAll("nextjs-portal").forEach((e) => e.remove());
    const fix = (s) => s.replace(/\(in [a-z-]+(?: [a-z]+ hue)?, /g, "(").replace(/ in [a-z-]+(?: [a-z]+ hue)?/g, "");
    let pseudo = 0;
    for (const el of document.querySelectorAll("*")) {
      const bg = getComputedStyle(el).backgroundImage;
      if (bg.includes("gradient") && / in [a-z-]+/.test(bg)) el.style.backgroundImage = fix(bg);
      for (const p of ["::before", "::after"]) { const b = getComputedStyle(el, p).backgroundImage; if (b.includes("gradient") && / in [a-z-]+/.test(b)) pseudo++; }
    }
    if (pseudo) { const st = document.createElement("style"); st.textContent = "*::before,*::after{background-image:none !important}"; document.head.appendChild(st); }
    if (!window.domToSvg) { const s = document.createElement("script"); s.textContent = bundle; document.head.appendChild(s); }
    window.scrollTo(0, 0);
    const se = document.scrollingElement;
    const width = Math.max(se.scrollWidth, innerWidth), height = Math.min(Math.max(se.scrollHeight, innerHeight), maxHeight);
    const out = domToSvg.documentToSVG(document, { captureArea: { x: 0, y: 0, width, height } });
    try { await domToSvg.inlineResources(out.documentElement); } catch {}
    return new XMLSerializer().serializeToString(out);
  }, { maxHeight, bundle: BUNDLE_SRC });
  const m = svg.match(/width="(\d+(?:\.\d+)?)" height="(\d+(?:\.\d+)?)"/);
  fs.writeFileSync(`${OUT}/${name}.svg`, svg);
  // Kotak blok untuk lo-fi: landmark, kartu, form, tabel, judul, tombol utama (posisi absolut dalam halaman).
  const boxes = await page.evaluate(() => {
    const sel = "header,nav,aside,main,section,form,table,footer,[role=tablist],[role=dialog],dialog,h1,h2,button,a[class*=bg-accent],input,select,textarea,img,svg[width],div[class*=rounded-lg][class*=border],div[class*=rounded-xl][class*=border],div[class*=rounded-2xl][class*=border]";
    const out = [];
    for (const el of document.querySelectorAll(sel)) {
      const r = el.getBoundingClientRect();
      if (r.width < 24 || r.height < 12) continue;
      if (el.closest("nextjs-portal")) continue;
      const tag = el.tagName.toLowerCase();
      const jenis = tag === "h1" || tag === "h2" ? "judul" : tag === "button" || tag === "a" ? "tombol" : ["input", "select", "textarea"].includes(tag) ? "isian" : tag === "img" || tag === "svg" ? "gambar" : tag === "table" ? "tabel" : ["header", "nav", "aside", "main", "footer"].includes(tag) ? tag : "kartu";
      const teks = (el.getAttribute("aria-label") || el.getAttribute("placeholder") || el.innerText || "").trim().split("\n")[0].slice(0, 40);
      out.push({ jenis, x: Math.round(r.x + scrollX), y: Math.round(r.y + scrollY), w: Math.round(r.width), h: Math.round(r.height), teks });
    }
    return out;
  });
  fs.writeFileSync(`${OUT}/${name}.boxes.json`, JSON.stringify(boxes));
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true }).catch(() => {});
  manifest.push({ name, url: page.url().replace(WEB, ""), width: Number(m?.[1] ?? 0), height: Number(m?.[2] ?? 0), ...meta });
  console.log(`  ${name} ${m?.[1]}x${m?.[2]}`);
}

// next dev mengompilasi route saat pertama dibuka (bisa > 30 detik), jadi timeout navigasi dilonggarkan
async function go(page, path) { await page.goto(`${WEB}${path}`, { waitUntil: "domcontentloaded", timeout: 120000 }); await hidrasi(page); }
const submitKosong = async (page) => { await page.locator("button[type=submit]").first().click({ timeout: 5000 }); await page.waitForTimeout(800); };

async function main() {
  if (!ONLY) fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });
  const data = await seed();
  console.log("data:", JSON.stringify(data));
  const browser = await chromium.launch({ channel: "chrome", headless: true });
  const desktop = { viewport: { width: 1440, height: 900 }, locale: "id-ID", timezoneId: "Asia/Jakarta" };
  const ponsel = { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true, deviceScaleFactor: 1, locale: "id-ID", timezoneId: "Asia/Jakarta" };

  // --- Publik ---
  console.log("publik");
  let ctx = await browser.newContext(desktop); let page = await ctx.newPage();
  await go(page, "/"); await capture(page, "publik__landing", { peran: "publik", fitur: "F00 Landing" });
  await go(page, "/login"); await capture(page, "publik__login", { peran: "publik", fitur: "F02 Masuk" });
  await coba("login salah", async () => { await page.getByLabel("Email atau nomor WA").fill(CITRA); await page.getByLabel(/^Kata sandi/).fill("salah123"); await page.getByRole("button", { name: "Masuk" }).click(); await page.waitForTimeout(2500); await capture(page, "publik__login--galat", { peran: "publik", fitur: "F02 Masuk", state: "error" }); });
  await go(page, "/register"); await capture(page, "publik__register", { peran: "publik", fitur: "F01 Daftar penjual" });
  await coba("register kosong", async () => { await submitKosong(page); await capture(page, "publik__register--galat", { peran: "publik", fitur: "F01 Daftar penjual", state: "error" }); });
  await go(page, "/lupa-sandi"); await capture(page, "publik__lupa-sandi", { peran: "publik", fitur: "F11 Lupa sandi" });
  await coba("lupa sandi kirim", async () => { await page.getByLabel(/Email/).first().fill("citra@mail.com"); await submitKosong(page); await page.waitForTimeout(2000); await capture(page, "publik__lupa-sandi--otp", { peran: "publik", fitur: "F11 Lupa sandi", state: "alternatif" }); });
  await go(page, "/halaman-tidak-ada"); await capture(page, "publik__404", { peran: "publik", fitur: "F00 Galat", state: "error" });
  await go(page, "/dashboard"); await capture(page, "publik__dashboard-tanpa-login", { peran: "publik", fitur: "F02 Masuk", state: "error" });
  await ctx.close();

  // --- Penjual terverifikasi ---
  console.log("penjual");
  ctx = await browser.newContext(desktop); page = await ctx.newPage();
  await loginUI(page, CITRA);
  const P = (f, state) => ({ peran: "penjual", fitur: f, ...(state ? { state } : {}) });
  data.orders.holding = await data.buatHolding();
  await go(page, "/dashboard"); await capture(page, "penjual__dashboard", P("F07 Dashboard pesanan"));
  await go(page, "/menu"); await capture(page, "penjual__menu", P("F04 Menu & kuota"));
  await go(page, "/menu?status=sold_out"); await capture(page, "penjual__menu--filter-kosong", P("F04 Menu & kuota", "alternatif"));
  await go(page, "/menu/baru"); await capture(page, "penjual__menu-baru", P("F04 Menu & kuota"));
  await coba("menu baru kosong", async () => { await submitKosong(page); await capture(page, "penjual__menu-baru--galat", P("F04 Menu & kuota", "error")); });
  if (data.menuId) { await go(page, `/menu/${data.menuId}`); await capture(page, "penjual__menu-detail", P("F04 Menu & kuota")); }
  await go(page, "/pesanan"); await capture(page, "penjual__pesanan", P("F07 Pesanan"));
  await go(page, "/pesanan?q=zzzz"); await capture(page, "penjual__pesanan--kosong", P("F07 Pesanan", "alternatif"));
  for (const [st, code] of Object.entries(data.orders)) { if (!code) continue; await go(page, `/pesanan/${code}`); await capture(page, `penjual__pesanan-detail--${st}`, P("F07 Pesanan", st === "holding" ? undefined : "alternatif")); }
  await go(page, "/pesanan/KK-00000000-XXXX"); await capture(page, "penjual__pesanan-detail--404", P("F07 Pesanan", "error"));
  await go(page, "/laporan"); await capture(page, "penjual__laporan", P("F09 Laporan"));
  await go(page, "/promo"); await capture(page, "penjual__promo", P("F12 Promo toko"));
  await go(page, "/ulasan"); await capture(page, "penjual__ulasan", P("F13 Ulasan"));
  await go(page, "/pengaturan"); await capture(page, "penjual__pengaturan", P("F03 Profil toko"), 9000);
  await go(page, "/template-wa"); await capture(page, "penjual__template-wa", P("F03 Template WA"));
  await go(page, "/copilot"); await capture(page, "penjual__copilot", P("F17 Asisten AI + HPP"));
  await go(page, "/pratinjau"); await capture(page, "penjual__pratinjau", P("F05 Pratinjau katalog"));
  await go(page, "/cetak-qr"); await capture(page, "penjual__cetak-qr", P("F21 Cetak QR meja"));
  await ctx.close();

  // --- Penjual pending & suspended ---
  for (const [who, phone, label] of [["pending", SARI, "menunggu verifikasi"], ["suspended", DEDI, "ditangguhkan"]]) {
    console.log("penjual", who);
    ctx = await browser.newContext(desktop); page = await ctx.newPage();
    await coba(`login ${who}`, async () => { await loginUI(page, phone); await go(page, "/dashboard"); await capture(page, `penjual__dashboard--${who}`, P("F03 Verifikasi toko", "alternatif " + label)); await go(page, "/pengaturan"); await capture(page, `penjual__pengaturan--${who}`, P("F03 Verifikasi toko", "alternatif " + label), 9000); });
    await ctx.close();
  }

  // --- Penjual di ponsel (diblokir) ---
  ctx = await browser.newContext(ponsel); page = await ctx.newPage();
  await coba("blok ponsel", async () => { await loginUI(page, CITRA); await go(page, "/dashboard"); await capture(page, "penjual__dashboard--ponsel", P("F07 Dashboard pesanan", "error layar < 768")); });
  await ctx.close();

  // --- Admin ---
  console.log("admin");
  const A = (f, state) => ({ peran: "admin", fitur: f, ...(state ? { state } : {}) });
  if (data.sandiOps) { ctx = await browser.newContext(desktop); page = await ctx.newPage(); await coba("admin wajib ganti sandi", async () => { await loginUI(page, "081200000002", data.sandiOps); await go(page, "/admin"); await capture(page, "admin__wajib-ganti-sandi", A("F18 Kelola admin", "alternatif sandi sementara")); }); await ctx.close(); }
  ctx = await browser.newContext(desktop); page = await ctx.newPage();
  await loginUI(page, ADMIN, PASS_ADMIN_BARU);
  const adminRoutes = [["/admin", "admin__ringkasan", "F18 Ringkasan"], ["/admin/verifikasi", "admin__verifikasi", "F19 Verifikasi"], ["/admin/penjual", "admin__penjual", "F19 Penjual"], ["/admin/moderasi", "admin__moderasi", "F20 Moderasi"], ["/admin/data-master", "admin__data-master", "F18 Data master"], ["/admin/promo", "admin__promo", "F12 Promo platform & setelan"], ["/admin/keuangan", "admin__keuangan", "F23 Keuangan"], ["/admin/pencairan", "admin__pencairan", "F26 Pencairan & refund"], ["/admin/pengumuman", "admin__pengumuman", "F18 Pengumuman"], ["/admin/ai", "admin__ai", "F22 AI gateway"], ["/admin/admin", "admin__kelola-admin", "F18 Kelola admin"], ["/admin/log", "admin__log", "F18 Log audit"], ["/admin/server", "admin__server", "F18 Server"], ["/admin/akun", "admin__akun", "F18 Akun admin"]];
  for (const [r, n, f] of adminRoutes) { await go(page, r); await capture(page, n, A(f)); }
  await coba("admin penjual detail", async () => { await go(page, "/admin/penjual"); const link = page.locator('a[href^="/admin/penjual/"]').first(); const href = await link.getAttribute("href"); await go(page, href); await capture(page, "admin__penjual-detail", A("F19 Penjual")); });
  await ctx.close();

  // --- Tamu meja (ponsel) ---
  console.log("meja");
  ctx = await browser.newContext(ponsel); page = await ctx.newPage();
  const M = (f, state) => ({ peran: "tamu", fitur: f, ...(state ? { state } : {}) });
  await go(page, "/meja"); await capture(page, "tamu__meja-index", M("F21 Pesan dari meja", "alternatif belum scan"));
  if (data.tokenMeja) {
    await go(page, `/meja/${data.tokenMeja}`); await capture(page, "tamu__meja-menu", M("F21 Pesan dari meja"));
    await coba("meja keranjang", async () => { await page.getByRole("button", { name: /Tambah|\+/ }).first().click({ timeout: 5000 }); await page.waitForTimeout(600); await capture(page, "tamu__meja-keranjang", M("F21 Pesan dari meja", "alternatif keranjang")); });
    await coba("meja pesan", async () => { await page.getByRole("button", { name: /Pesan|Checkout|Lanjut/ }).first().click({ timeout: 5000 }); await page.waitForTimeout(600); await capture(page, "tamu__meja-checkout", M("F21 Pesan dari meja")); await page.getByLabel(/Nama/).first().fill("Rina");
      // Tombol "Pesan & bayar" langsung memanggil Snap (409 tanpa Midtrans), jadi pesanan tamu dibuat lewat API lalu halaman status dibuka dengan token tamu di localStorage.
      const pm = await api("POST", `/tables/${data.tokenMeja}/orders`, undefined, { items: [{ menu_id: data.menuId, qty: 1 }], customer_name: "Rina", note: "Tanpa es." });
      const kodeMeja = pm.code ?? pm.data?.code, tokenTamu = pm.guest_token ?? pm.data?.guest_token;
      await page.evaluate(([c, t, m]) => localStorage.setItem(`kk-tamu:${c}`, JSON.stringify({ tamu: t, meja: m })), [kodeMeja, tokenTamu, data.tokenMeja]);
      await go(page, `/meja/pesanan/${kodeMeja}`); await capture(page, "tamu__meja-pesanan", M("F21 Pesan dari meja", "status + bayar")); });
  }
  await go(page, "/meja/token-tidak-valid-000000000000000000"); await capture(page, "tamu__meja--404", M("F21 Pesan dari meja", "error"));
  await ctx.close();

  await browser.close();
  let akhir = manifest;
  if (ONLY) {
    try {
      const lama = JSON.parse(fs.readFileSync(`${OUT}/manifest.json`, "utf8"));
      const baru = new Map(manifest.map((m) => [m.name, m]));
      akhir = lama.map((m) => baru.get(m.name) ?? m);
      for (const m of manifest) if (!lama.some((l) => l.name === m.name)) akhir.push(m);
    } catch {}
  }
  fs.writeFileSync(`${OUT}/manifest.json`, JSON.stringify(akhir, null, 2));
  console.log(`selesai: ${manifest.length} layar -> ${OUT}/manifest.json`);
}
main().catch((e) => { console.error(e); process.exit(1); });
