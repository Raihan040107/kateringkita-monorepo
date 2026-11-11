// Lo-fi + prototype tanpa server: dibaca dari pohon frame hi-fi yang sudah diimpor (dom-to-svg menamai group dengan class pertama,
// text dengan isinya). Tiga tahap, semuanya lewat figcraft-cli:
//   node build-offline.mjs find > find.json   ; figcraft-cli run find.json --in F > find.out
//   node build-offline.mjs get  > get.json    ; figcraft-cli run get.json  --in F > get.out
//   node build-offline.mjs build > offline.json ; figcraft-cli run offline.json --in F --out F
import fs from "node:fs";
const MODE = process.argv[2] ?? "find";
const GAP_X = 120, GAP_ROW = 160, PAD = 120, GAP_SEC = 320, LABEL = 56, MAX_W = 4 * 1440 + 3 * GAP_X;
const JUDUL = { publik: "Publik & Auth", penjual: "Penjual (web ≥ 768 px)", admin: "Admin", tamu: "Tamu meja (PWA ponsel)" };
// [nama, id frame hi-fi, lebar, tinggi, url · state] urut fitur (dari get_node page 03 pada 2026-11-12)
const LAYAR = [
  ["publik__landing", 1240, 1440, 6381, "/"], ["publik__login", 2250, 1440, 900, "/login"], ["publik__login--galat", 2406, 1440, 900, "/login · error"], ["publik__dashboard-tanpa-login", 2582, 1440, 900, "/login?next=%2Fdashboard · error"], ["publik__register", 2757, 1440, 934, "/register"], ["publik__register--galat", 2991, 1440, 1226, "/register · error"], ["publik__lupa-sandi", 3302, 1440, 900, "/lupa-sandi"], ["publik__lupa-sandi--otp", 3426, 1440, 900, "/lupa-sandi · alternatif"], ["publik__404", 3605, 1440, 900, "/halaman-tidak-ada · error"],
  ["penjual__dashboard", 3704, 1440, 1065, "/dashboard"], ["penjual__dashboard--ponsel", 4773, 646, 1637, "/dashboard · error layar < 768"], ["penjual__menu", 5619, 1440, 1255, "/menu"], ["penjual__menu--filter-kosong", 6774, 1440, 1255, "/menu?status=sold_out · alternatif"], ["penjual__menu-baru", 7927, 1440, 1776, "/menu/baru"], ["penjual__menu-baru--galat", 8634, 1440, 2120, "/menu/baru · error"], ["penjual__menu-detail", 9436, 1440, 1817, "/menu/6"], ["penjual__pesanan", 10152, 1440, 900, "/pesanan"], ["penjual__pesanan--kosong", 11226, 1440, 900, "/pesanan?q=zzzz · alternatif"], ["penjual__pesanan-detail--cancelled", 11734, 1440, 900, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--completed", 12330, 1440, 911, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--ready", 12984, 1440, 955, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--cooking", 13652, 1440, 900, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--confirmed", 14289, 1440, 900, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--expired", 14910, 1440, 900, "/pesanan/[code] · alternatif"], ["penjual__pesanan-detail--404", 15526, 1440, 900, "/pesanan/KK-00000000-XXXX · error"], ["penjual__laporan", 15979, 1440, 1222, "/laporan"], ["penjual__promo", 16722, 1440, 900, "/promo"], ["penjual__ulasan", 17274, 1440, 900, "/ulasan"], ["penjual__pengaturan", 18054, 1440, 3808, "/pengaturan"], ["penjual__template-wa", 19140, 1440, 984, "/template-wa"], ["penjual__copilot", 19686, 1440, 944, "/copilot"], ["penjual__pratinjau", 20258, 1440, 966, "/pratinjau"], ["penjual__cetak-qr", 20775, 1440, 900, "/cetak-qr"], ["penjual__dashboard--pending", 20949, 1440, 900, "/dashboard · alternatif menunggu verifikasi"], ["penjual__pengaturan--pending", 21702, 1440, 3620, "/pengaturan · alternatif menunggu verifikasi"], ["penjual__dashboard--suspended", 22674, 1440, 900, "/dashboard · alternatif ditangguhkan"], ["penjual__pengaturan--suspended", 23428, 1440, 3620, "/pengaturan · alternatif ditangguhkan"],
  ["admin__ringkasan", 25339, 1440, 1186, "/admin"], ["admin__verifikasi", 26179, 1440, 900, "/admin/verifikasi"], ["admin__penjual", 26939, 1440, 900, "/admin/penjual"], ["admin__penjual-detail", 27659, 1440, 1216, "/admin/penjual/4"], ["admin__moderasi", 28338, 1440, 900, "/admin/moderasi"], ["admin__data-master", 28943, 1440, 900, "/admin/data-master"], ["admin__promo", 29875, 1440, 900, "/admin/promo"], ["admin__keuangan", 30411, 1440, 900, "/admin/keuangan"], ["admin__pencairan", 31048, 1440, 1184, "/admin/pencairan"], ["admin__pengumuman", 31564, 1440, 900, "/admin/pengumuman"], ["admin__ai", 32041, 1440, 1032, "/admin/ai"], ["admin__log", 32695, 1440, 900, "/admin/log"], ["admin__server", 33395, 1440, 900, "/admin/server"], ["admin__akun", 34180, 1440, 900, "/admin/akun"], ["admin__wajib-ganti-sandi", 24402, 1440, 900, "/admin · alternatif sandi sementara"], ["admin__kelola-admin", 24780, 1440, 900, "/admin/admin"],
  ["tamu__meja-index", 34678, 390, 844, "/meja · alternatif belum scan"], ["tamu__meja-menu", 34780, 390, 890, "/meja/[token]"], ["tamu__meja-keranjang", 35060, 390, 890, "/meja/[token] · alternatif keranjang"], ["tamu__meja-checkout", 35378, 390, 890, "/meja/[token]"], ["tamu__meja--404", 35782, 390, 844, "/meja/token-tidak-valid · error"],
  // ditambah 2026-11-12 setelah capture ulang; elemen ke-6 = posisi tempel di section lo-fi yang sudah ada (mode TAMBAH=1)
  ["penjual__pesanan-detail--holding", 46716, 1440, 900, "/pesanan/[code] · holding (utama)", { sec: 41863, x: 120, y: 15656 }],
  ["tamu__meja-pesanan", 47333, 390, 844, "/meja/pesanan/[code] · status + bayar", { sec: 45627, x: 2670, y: 120 }],
];
const peranDari = (n) => n.split("__")[0];
// HANYA=<regex>: batasi ke sebagian layar. TAMBAH=1: tempel layar itu ke section lo-fi yang sudah ada, tanpa membuat section/flow baru.
const HANYA = process.env.HANYA ? new RegExp(process.env.HANYA) : null;
const DIPAKAI = HANYA ? LAYAR.filter((m) => HANYA.test(m[0])) : LAYAR;
const TAMBAH = !!process.env.TAMBAH;
// teks tombol/tautan -> layar tujuan (prototype)
const TUJUAN = {
  publik: { "masuk": "penjual__dashboard", "daftar sebagai penjual": "publik__register", "lupa kata sandi?": "publik__lupa-sandi", "kembali ke beranda": "publik__landing", "lanjut": "publik__register", "kirim kode": "publik__lupa-sandi--otp", "masuk ke dashboard": "publik__login", "daftar jadi penjual": "publik__register" },
  penjual: { "dashboard": "penjual__dashboard", "menu": "penjual__menu", "pesanan": "penjual__pesanan", "laporan": "penjual__laporan", "promo": "penjual__promo", "ulasan": "penjual__ulasan", "pengaturan": "penjual__pengaturan", "template wa": "penjual__template-wa", "templat wa": "penjual__template-wa", "copilot": "penjual__copilot", "asisten ai": "penjual__copilot", "tambah menu": "penjual__menu-baru", "cetak qr": "penjual__cetak-qr", "pratinjau": "penjual__pratinjau", "lihat semua": "penjual__pesanan", "keluar": "publik__login" },
  admin: { "ringkasan": "admin__ringkasan", "verifikasi": "admin__verifikasi", "penjual": "admin__penjual", "data master": "admin__data-master", "promo": "admin__promo", "moderasi": "admin__moderasi", "keuangan": "admin__keuangan", "pencairan": "admin__pencairan", "log audit": "admin__log", "server": "admin__server", "admin": "admin__kelola-admin", "kelola admin": "admin__kelola-admin", "akun": "admin__akun", "ai": "admin__ai", "pengumuman": "admin__pengumuman", "keluar": "publik__login" },
  tamu: { "lihat pesanan": "tamu__meja-keranjang", "pesan & bayar": "tamu__meja-checkout", "kembali": "tamu__meja-menu" },
};
const POLA = ["rounded", "inline-flex", "sticky", "hidden", "border"]; // nama group yang jadi kotak lo-fi
const out = (steps, info) => { process.stdout.write(JSON.stringify(steps)); console.error(info); };
const bacaJsonl = (f) => fs.readFileSync(f, "utf8").split("\n").filter((l) => l.startsWith("{")).map((l) => JSON.parse(l));

if (MODE === "find") {
  const steps = [{ command: "page.select", params: { id: 4 } }];
  for (const [nama, id] of DIPAKAI) {
    for (const p of POLA) steps.push({ command: "node.find", params: { root: id, type: "GROUP", name: p, limit: 400 }, as: `${nama}|grup|${p}` });
    steps.push({ command: "node.find", params: { root: id, type: "TEXT", limit: 400 }, as: `${nama}|teks|` });
    for (const t of Object.keys(TUJUAN[peranDari(nama)])) steps.push({ command: "node.find", params: { root: id, type: "TEXT", name: t, limit: 20 }, as: `${nama}|hot|${t}` });
  }
  out(steps, `find: ${steps.length} langkah`);
} else if (MODE === "get") {
  const hasil = bacaJsonl("find.out");
  const find = JSON.parse(fs.readFileSync("find.json", "utf8"));
  const ids = new Set();
  hasil.forEach((h, i) => { if (h.ok && find[i]?.as) for (const id of h.result.ids) ids.add(id); });
  const steps = [{ command: "page.select", params: { id: 4 } }];
  for (const [, id] of DIPAKAI) steps.push({ command: "node.get", params: { id, fields: ["absoluteBounds"] } });
  for (const id of ids) steps.push({ command: "node.get", params: { id, fields: ["name", "characters", "fontSize", "fontStyle", "absoluteBounds"] } });
  out(steps, `get: ${steps.length} langkah`);
} else {
  const find = JSON.parse(fs.readFileSync("find.json", "utf8"));
  const findOut = bacaJsonl("find.out");
  const getOut = bacaJsonl("get.out");
  const node = {}; // id -> {name, characters, fontSize, fontStyle, b}
  for (const g of getOut) if (g.ok && g.result?.id != null) node[g.result.id] = { ...g.result, b: g.result.absoluteBounds };
  const per = {}; // nama layar -> {grup:Set, teks:Set, hot:{teks:[ids]}}
  findOut.forEach((h, i) => {
    const as = find[i]?.as; if (!as || !h.ok) return;
    const [nama, jenis, kunci] = as.split("|");
    per[nama] ??= { grup: new Set(), teks: new Set(), hot: {} };
    if (jenis === "grup") h.result.ids.forEach((id) => per[nama].grup.add(id));
    else if (jenis === "teks") h.result.ids.forEach((id) => per[nama].teks.add(id));
    else per[nama].hot[kunci] = h.result.ids;
  });
  const steps = [];
  const add = (command, params, as) => { const s = { command, params }; if (as) s.as = as; steps.push(s); return as; };
  const ref = (as) => ({ $ref: as });
  let n = 0;
  // --- Lo-fi: page 3, tata letak sama dengan hi-fi ---
  add("page.select", { id: 3 });
  if (process.env.HAPUS_LOFI) add("edit.delete", { ids: process.env.HAPUS_LOFI.split(",").map(Number) });
  const abu = { bg: "#F4F2EB", line: "#CFC6BD", strong: "#9B9187", text: "#665D55", blok: "#E8E5DF" };
  let y = 0, kotak = 0, hot = 0;
  const FRAME_LOFI = {};
  if (TAMBAH) { // section lo-fi mengikuti ukuran section hi-fi setelah 2 layar ditambah (id section lo-fi per 2026-11-12)
    add("node.set", { ids: [41863], height: 16732 }); add("node.set", { ids: [44502], y: 26607 }); add("node.set", { ids: [45627], y: 32071, width: 3180 });
  }
  for (const peran of ["publik", "penjual", "admin", "tamu"]) {
    const layar = DIPAKAI.filter((m) => peranDari(m[0]) === peran);
    if (!layar.length) continue;
    const rows = [];
    for (const m of layar) {
      const r = rows[rows.length - 1];
      const lebar = r ? r.reduce((a, x) => a + x[2], 0) + GAP_X * r.length + m[2] : Infinity;
      if (r && lebar <= MAX_W) r.push(m); else rows.push([m]);
    }
    const rowW = rows.map((r) => r.reduce((a, m) => a + m[2], 0) + GAP_X * (r.length - 1));
    const rowH = rows.map((r) => Math.max(...r.map((m) => m[3])));
    const secW = Math.max(...rowW) + PAD * 2;
    const secH = rowH.reduce((a, h) => a + h + LABEL, 0) + GAP_ROW * (rows.length - 1) + PAD * 2;
    const sec = TAMBAH ? null : add("node.create", { type: "section", name: `Lo-fi · ${JUDUL[peran]}`, x: 0, y, width: secW, height: secH }, `sec${++n}`);
    let ry = PAD;
    rows.forEach((row, i) => {
      let x = PAD;
      for (const [nama, idHifi, w, h, url, tb] of row) {
        const induk = TAMBAH ? tb.sec : ref(sec), px = TAMBAH ? tb.x : x, py = TAMBAH ? tb.y : ry;
        add("node.create", { type: "text", name: `label ${nama}`, parent: induk, x: px, y: py, text: `${nama}\n${url}`, props: { fontFamily: "Inter", fontStyle: "SemiBold", fontSize: 14, lineHeight: 20, fill: "#262017" } });
        const fr = add("node.create", { type: "frame", name: nama, parent: induk, x: px, y: py + LABEL, width: w, height: h, props: { fill: "#FFFFFF", stroke: abu.strong, strokeWeight: 1, clip: true } }, `fr${++n}`);
        FRAME_LOFI[nama] = fr;
        const asal = node[idHifi]?.b; const d = per[nama];
        if (asal && d) {
          const rel = (b) => ({ x: Math.round(b.x - asal.x), y: Math.round(b.y - asal.y), w: Math.round(b.width), h: Math.round(b.height) });
          const seen = new Set(); let k = 0;
          const grup = [...d.grup].map((id) => node[id]).filter(Boolean).map((g) => ({ ...rel(g.b), name: g.name })).filter((g) => g.w >= 24 && g.h >= 12 && g.w * g.h < w * h * 0.9 && g.y < h).sort((a, b) => b.w * b.h - a.w * a.h);
          for (const g of grup) {
            const key = `${g.x}:${g.y}:${g.w}:${g.h}`; if (seen.has(key)) continue; seen.add(key); if (++k > 300) break;
            const tombol = g.name.startsWith("inline-flex") || (g.h <= 48 && g.w <= 220);
            const isian = !tombol && g.h <= 56 && g.w > 220 && g.name.startsWith("rounded");
            const blok = g.name.startsWith("sticky") || g.name.startsWith("hidden");
            const style = tombol ? { fill: abu.line, cornerRadius: 8 } : isian ? { fill: "#FFFFFF", stroke: abu.strong, strokeWeight: 1, cornerRadius: 8 } : blok ? { fill: abu.blok } : { fill: abu.bg, stroke: abu.line, strokeWeight: 1, cornerRadius: 12 };
            add("node.create", { type: "rectangle", name: tombol ? "tombol" : isian ? "isian" : blok ? "blok" : "kartu", parent: ref(fr), x: g.x, y: g.y, width: g.w, height: g.h, props: style });
            kotak++;
          }
          let t = 0;
          for (const id of d.teks) {
            const tx = node[id]; if (!tx?.characters || !tx.b) continue;
            const r = rel(tx.b); if (r.y > h || r.w < 8) continue; if (++t > 200) break;
            const fs = Math.max(10, Math.round(tx.fontSize ?? 14));
            add("node.create", { type: "text", name: tx.characters.slice(0, 40), parent: ref(fr), x: r.x, y: r.y, width: Math.max(r.w, 8) + 12, text: tx.characters, props: { fontFamily: "Inter", fontStyle: fs >= 18 ? "Bold" : "Regular", fontSize: fs, lineHeight: Math.round(fs * 1.3), fill: fs >= 18 ? abu.text : abu.strong, textAutoResize: "height" } });
          }
        }
        x += w + GAP_X;
      }
      ry += rowH[i] + LABEL + GAP_ROW;
    });
    y += secH + GAP_SEC;
  }
  // --- Prototype: hotspot di frame hi-fi (page 4) --- (lewati bila HANYA_LOFI=1: hotspot sudah ada)
  if (!process.env.HANYA_LOFI) {
  add("page.select", { id: 4 });
  const idHifi = Object.fromEntries(LAYAR.map((m) => [m[0], m[1]]));
  for (const [nama, id, w, h] of DIPAKAI) {
    const d = per[nama]; const asal = node[id]?.b; if (!d || !asal) continue;
    const peta = TUJUAN[peranDari(nama)];
    const seen = new Set();
    for (const [teks, ids] of Object.entries(d.hot)) {
      const tujuan = peta[teks]; if (!tujuan || tujuan === nama || !idHifi[tujuan]) continue;
      for (const tid of ids) {
        const tx = node[tid]; if (!tx?.characters || tx.characters.trim().toLowerCase() !== teks) continue;
        const x = Math.round(tx.b.x - asal.x) - 8, yy = Math.round(tx.b.y - asal.y) - 8;
        if (yy > h) continue;
        const key = `${x}:${yy}`; if (seen.has(key)) continue; seen.add(key);
        const hs = add("node.create", { type: "frame", name: `→ ${tujuan}`, parent: id, x, y: yy, width: Math.round(tx.b.width) + 16, height: Math.round(tx.b.height) + 16, props: { fill: "none" } }, `hs${++n}`);
        add("proto.interaction.add", { id: ref(hs), dest: idHifi[tujuan] });
        hot++;
      }
    }
  }
  if (!TAMBAH) for (const [peran, nama] of Object.entries({ publik: "publik__landing", penjual: "penjual__dashboard", admin: "admin__ringkasan", tamu: "tamu__meja-menu" })) add("proto.flow.add", { start: idHifi[nama], name: JUDUL[peran] });
  }
  out(steps, `build: ${steps.length} langkah, ${kotak} kotak lo-fi, ${hot} hotspot`);
}
