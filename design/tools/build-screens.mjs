// Buat skrip FigCraft untuk page "03 Hi-fi" (impor SVG hasil capture) atau "02 Lo-fi" (kotak abu-abu dari boxes.json).
// Jalankan: node build-screens.mjs hifi > hifi.json ; node build-screens.mjs lofi > lofi.json ; lalu figcraft-cli run <file> --in ... --out ...
import fs from "node:fs";
const MODE = process.argv[2] ?? "hifi";
const CAP = "D:/PBL/design/capture";
const manifest = JSON.parse(fs.readFileSync(`${CAP}/manifest.json`, "utf8"));
const PAGE = MODE === "hifi" ? 4 : 3;
const GAP_X = 120, GAP_ROW = 160, PAD = 120, GAP_SEC = 320, LABEL = 56, MAX_W = 4 * 1440 + 3 * GAP_X;
const PERAN = ["publik", "penjual", "admin", "tamu"];
const JUDUL = { publik: "Publik & Auth", penjual: "Penjual (web \u2265 768 px)", admin: "Admin", tamu: "Tamu meja (PWA ponsel)" };

const steps = [];
const FRAME = {}; // nama layar -> ref frame hi-fi (untuk prototype)
let n = 0;
const add = (command, params, as) => { const s = { command, params }; if (as) s.as = as; steps.push(s); return as; };
const ref = (as) => ({ $ref: as });
const id = (p) => `${p}${++n}`;
add("page.select", { id: PAGE });

// --- tata letak: section per peran, satu baris per fitur ---
let y = 0;
const abu = { bg: "#F4F2EB", line: "#CFC6BD", strong: "#9B9187", text: "#665D55" };
for (const peran of PERAN) {
  const layar = manifest.filter((m) => m.peran === peran);
  if (!layar.length) continue;
  // Urut per fitur, lalu alirkan ke baris selebar maksimal MAX_W (4 layar desktop) supaya section tidak memanjang.
  const fiturs = [...new Set(layar.map((m) => m.fitur))];
  const urut = fiturs.flatMap((f) => layar.filter((m) => m.fitur === f));
  const rows = [];
  for (const m of urut) {
    const r = rows[rows.length - 1];
    const lebar = r ? r.reduce((a, x) => a + x.width, 0) + GAP_X * r.length + m.width : Infinity;
    if (r && lebar <= MAX_W) r.push(m); else rows.push([m]);
  }
  const rowW = rows.map((r) => r.reduce((a, m) => a + m.width, 0) + GAP_X * (r.length - 1));
  const rowH = rows.map((r) => Math.max(...r.map((m) => m.height)));
  const secW = Math.max(...rowW) + PAD * 2;
  const secH = rowH.reduce((a, h) => a + h + LABEL, 0) + GAP_ROW * (rows.length - 1) + PAD * 2;
  const sec = add("node.create", { type: "section", name: `${MODE === "hifi" ? "Hi-fi" : "Lo-fi"} \u00b7 ${JUDUL[peran]}`, x: 0, y, width: secW, height: secH }, id("sec"));
  let ry = y + PAD;
  rows.forEach((row, i) => {
    let x = PAD;
    for (const m of row) {
      const label = `${m.name}\n${m.url}${m.state ? ` \u00b7 ${m.state}` : ""}`;
      add("node.create", { type: "text", name: `label ${m.name}`, parent: ref(sec), x, y: ry - y, text: label, props: { fontFamily: "Inter", fontStyle: "SemiBold", fontSize: 14, lineHeight: 20, fill: "#262017" } });
      const fy = ry + LABEL;
      if (MODE === "hifi") {
        const im = add("file.import", { path: `${CAP}/${m.name}.svg`, x, y: fy }, id("im"));
        FRAME[m.name] = im;
        add("node.set", { ids: [ref(im)], name: m.name });
        add("node.reparent", { ids: [ref(im)], parent: ref(sec) });
      } else {
        const fr = add("node.create", { type: "frame", name: m.name, parent: ref(sec), x, y: fy - y, width: m.width, height: m.height, props: { fill: "#FFFFFF", stroke: abu.strong, strokeWeight: 1, clip: true } }, id("fr"));
        let boxes = [];
        try { boxes = JSON.parse(fs.readFileSync(`${CAP}/${m.name}.boxes.json`, "utf8")); } catch {}
        const seen = new Set();
        let k = 0;
        for (const b of boxes) {
          if (b.w * b.h > m.width * m.height * 0.9 || b.jenis === "main") continue;
          const key = `${b.jenis}:${b.x}:${b.y}:${b.w}:${b.h}`;
          if (seen.has(key) || b.y > m.height) continue;
          seen.add(key);
          if (++k > 400) break;
          const nm = b.teks ? `${b.jenis}: ${b.teks}` : b.jenis;
          if (b.jenis === "judul") {
            add("node.create", { type: "text", name: nm, parent: ref(fr), x: b.x, y: b.y, width: b.w, text: b.teks || "Judul", props: { fontFamily: "Inter", fontStyle: "Bold", fontSize: Math.max(12, Math.min(32, Math.round(b.h * 0.7))), fill: abu.text, textAutoResize: "height" } });
            continue;
          }
          const style = { header: { fill: "#E8E5DF" }, nav: { fill: "#E8E5DF" }, aside: { fill: "#E8E5DF" }, footer: { fill: "#E8E5DF" }, kartu: { fill: abu.bg, stroke: abu.line, strokeWeight: 1 }, tabel: { fill: abu.bg, stroke: abu.line, strokeWeight: 1 }, tombol: { fill: abu.line, cornerRadius: 8 }, isian: { fill: "#FFFFFF", stroke: abu.strong, strokeWeight: 1, cornerRadius: 8 }, gambar: { fill: "#E8E5DF", stroke: abu.line, strokeWeight: 1 } }[b.jenis] ?? { fill: abu.bg };
          add("node.create", { type: "rectangle", name: nm, parent: ref(fr), x: b.x, y: b.y, width: b.w, height: b.h, props: style });
          if ((b.jenis === "tombol" || b.jenis === "isian") && b.teks && b.w > 60) {
            add("node.create", { type: "text", name: `teks ${b.teks}`, parent: ref(fr), x: b.x + 12, y: b.y + Math.max(0, (b.h - 16) / 2), width: Math.max(20, b.w - 24), text: b.teks, props: { fontFamily: "Inter", fontStyle: b.jenis === "tombol" ? "SemiBold" : "Regular", fontSize: 12, lineHeight: 16, fill: abu.text, textAutoResize: "truncate", maxLines: 1 } });
          }
          if (b.jenis === "gambar") {
            add("node.create", { type: "vector", name: "silang", parent: ref(fr), x: b.x, y: b.y, path: `M0 0L${b.w} ${b.h}M${b.w} 0L0 ${b.h}`, props: { stroke: abu.line, strokeWeight: 1, fill: "none" } });
          }
        }
      }
      x += m.width + GAP_X;
    }
    ry += rowH[i] + LABEL + GAP_ROW;
  });
  y += secH + GAP_SEC;
}
// --- Prototype (hanya mode hifi): hotspot transparan di atas tombol/tautan yang dikenal, navigasi ke frame tujuan ---
if (MODE === "hifi") {
  const ada = (n) => (n in FRAME ? n : null);
  // teks tombol/tautan (huruf kecil) -> nama layar tujuan; dicari per peran dulu, lalu umum
  const TUJUAN = {
    publik: { "masuk": "publik__login", "daftar sebagai penjual": "publik__register", "daftar": "publik__register", "lupa kata sandi?": "publik__lupa-sandi", "kembali ke beranda": "publik__landing", "beranda": "publik__landing", "sudah punya akun? masuk": "publik__login", "lanjut": "publik__register", "kirim kode": "publik__lupa-sandi--terkirim" },
    penjual: { "dashboard": "penjual__dashboard", "menu": "penjual__menu", "pesanan": "penjual__pesanan", "laporan": "penjual__laporan", "promo": "penjual__promo", "ulasan": "penjual__ulasan", "pengaturan": "penjual__pengaturan", "template wa": "penjual__template-wa", "templat wa": "penjual__template-wa", "copilot": "penjual__copilot", "asisten ai": "penjual__copilot", "tambah menu": "penjual__menu-baru", "menu baru": "penjual__menu-baru", "cetak qr": "penjual__cetak-qr", "pratinjau": "penjual__pratinjau", "pratinjau toko": "penjual__pratinjau", "lihat semua pesanan": "penjual__pesanan", "lihat semua": "penjual__pesanan", "kembali": "penjual__pesanan", "simpan": "penjual__menu", "keluar": "publik__login" },
    admin: { "ringkasan": "admin__dashboard", "dashboard": "admin__dashboard", "verifikasi": "admin__verifikasi", "penjual": "admin__penjual", "data master": "admin__data-master", "promo": "admin__promo", "moderasi": "admin__moderasi", "keuangan": "admin__keuangan", "pencairan": "admin__pencairan", "log audit": "admin__log", "log": "admin__log", "server": "admin__server", "admin": "admin__admin", "akun": "admin__akun", "akun saya": "admin__akun", "ai": "admin__ai", "penyedia ai": "admin__ai", "pengumuman": "admin__pengumuman", "keluar": "publik__login" },
    tamu: { "lihat pesanan": "tamu__meja-keranjang", "pesan & bayar": "tamu__meja-checkout", "kembali": "tamu__meja-menu", "tutup": "tamu__meja-menu" },
  };
  // layar yang dijadikan titik mulai flow prototype, per peran
  const MULAI = { publik: "publik__landing", penjual: "penjual__dashboard", admin: "admin__dashboard", tamu: "tamu__meja-menu" };
  const PERAN_NAV = { publik: "publik", penjual: "penjual", admin: "admin", tamu: "tamu" };
  let hot = 0;
  for (const m of manifest) {
    if (!FRAME[m.name]) continue;
    let boxes = [];
    try { boxes = JSON.parse(fs.readFileSync(`${CAP}/${m.name}.boxes.json`, "utf8")); } catch { continue; }
    const seen = new Set();
    for (const b of boxes) {
      if (b.jenis !== "tombol" || !b.teks || b.y + b.h > m.height) continue;
      const t = b.teks.toLowerCase().replace(/\s+/g, " ").trim();
      const peta = TUJUAN[PERAN_NAV[m.peran]] ?? {};
      let tujuan = ada(peta[t]);
      if (!tujuan && m.peran === "penjual" && t === "masuk") tujuan = ada("penjual__dashboard");
      if (!tujuan && m.name.startsWith("publik__login") && t === "masuk") tujuan = ada("penjual__dashboard");
      if (!tujuan || tujuan === m.name) continue;
      const key = `${b.x}:${b.y}:${tujuan}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const hs = add("node.create", { type: "frame", name: `→ ${tujuan}`, parent: ref(FRAME[m.name]), x: b.x, y: b.y, width: b.w, height: b.h, props: { fill: "none", opacity: 1 } }, id("hs"));
      add("proto.interaction.add", { id: ref(hs), dest: ref(FRAME[tujuan]) });
      hot++;
    }
  }
  for (const [peran, nama] of Object.entries(MULAI)) if (FRAME[nama]) add("proto.flow.add", { start: ref(FRAME[nama]), name: JUDUL[peran] });
  console.error(`prototype: ${hot} hotspot`);
}

process.stdout.write(JSON.stringify(steps));
console.error(`${MODE}: ${steps.length} langkah, ${manifest.length} layar`);
