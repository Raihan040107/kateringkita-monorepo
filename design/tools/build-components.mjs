// Buat skrip FigCraft (figcraft-cli run) untuk page "01 Components": komponen dari app/components/ui/*.tsx.
// Jalankan: node build-components.mjs > components.json ; lalu figcraft-cli run components.json --in kateringkita.figcraft --out kateringkita.figcraft
import fs from "node:fs";
const ICON = JSON.parse(fs.readFileSync(new URL("./lucide-paths.json", import.meta.url)));

const V = (n) => ({ $var: `color/${n}` });
const steps = [];
let n = 0;
const add = (command, params, as) => { const s = { command, params }; if (as) s.as = as; steps.push(s); return as; };
const ref = (as) => ({ $ref: as });
const id = (p) => `${p}${++n}`;

// --- primitif ---
const frame = (name, props, parent, as = id("f")) => { add("node.create", { type: "frame", name, ...(parent ? { parent: ref(parent) } : {}), props }, as); return as; };
const text = (parent, chars, props, name) => add("node.create", { type: "text", name: name ?? chars.slice(0, 24), parent: ref(parent), text: chars, props: { fontFamily: "Inter", fontStyle: "Regular", fontSize: 16, lineHeight: 24, fill: V("ink"), ...props } }, id("t"));
const icon = (parent, nama, size = 16, color = V("ink")) => add("node.create", { type: "vector", name: `icon/${nama}`, parent: ref(parent), path: ICON[nama], width: size, props: { fill: "none", stroke: color, strokeWeight: 2 * size / 24, strokeCap: "round", strokeJoin: "round" } }, id("i"));
const rect = (parent, name, props) => add("node.create", { type: "rectangle", name, parent: ref(parent), width: props.width ?? 100, height: props.height ?? 100, props }, id("r"));
const row = (name, props, parent) => frame(name, { layout: "horizontal", crossAlign: "center", sizingH: "hug", sizingV: "hug", fill: "none", ...props }, parent);
const col = (name, props, parent) => frame(name, { layout: "vertical", sizingH: "hug", sizingV: "hug", fill: "none", ...props }, parent);

// Seksi: judul + baris varian; frame varian dibuat di dalam seksi agar rapi, lalu dijadikan komponen.

const section = (judul, sumber, isi) => {
  const s = frame(judul, { layout: "vertical", gap: 24, padding: 40, fill: "#FFFFFF", cornerRadius: 16, sizingH: "fill", sizingV: "hug" }, "root");
  text(s, `${judul} — ${sumber}`, { fontFamily: "Plus Jakarta Sans", fontStyle: "Bold", fontSize: 20, lineHeight: 28 });
  const r = frame("Varian", { layout: "horizontal", wrap: true, gap: 24, crossGap: 24, crossAlign: "min", fill: "none", sizingH: "fixed", width: 1200, sizingV: "hug" }, s);
  const made = isi(r);
  return { s, made };
};
const SM = { fontSize: 14, lineHeight: 20 };
const XS = { fontSize: 12, lineHeight: 16 };
const TONE = {
  warning: { fg: V("warning"), bg: V("warning-bg"), icon: "triangle-alert" },
  info: { fg: V("info"), bg: V("info-bg"), icon: "info" },
  success: { fg: V("success"), bg: V("success-bg"), icon: "circle-check" },
  danger: { fg: V("danger"), bg: V("danger-bg"), icon: "circle-alert" },
  neutral: { fg: V("ink-muted"), bg: V("subtle"), icon: "info" },
};

const komponen = []; // {ids, set} → component.createMultiple + combineVariants
add("page.select", { id: 2 });
// Satu bingkai induk auto-layout: seksi tersusun vertikal tanpa menghitung tinggi.
frame("Components", { layout: "vertical", gap: 48, fill: "none", sizingH: "fixed", width: 1280, sizingV: "hug" }, undefined, "root");

// --- Button (Button.tsx + LinkButton.tsx) ---
section("Button", "ui/Button.tsx", (r) => {
  const ids = [];
  const varian = { Primary: { fill: V("accent") }, Secondary: { fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, Ghost: {}, Danger: { fill: V("danger") } };
  for (const size of ["md", "lg"]) for (const [v, p] of Object.entries(varian)) {
    const b = row(`Variant=${v}, Size=${size}, State=Default`, { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: size === "lg" ? 48 : 44, padding: size === "lg" ? [0, 24] : [0, 16], ...p }, r);
    text(b, v === "Danger" ? "Tolak pesanan" : "Simpan menu", { fontStyle: "SemiBold", fontSize: size === "lg" ? 18 : 16, lineHeight: size === "lg" ? 28 : 24, fill: v === "Danger" ? V("surface") : V("ink") });
    ids.push(b);
  }
  const d = row("Variant=Primary, Size=md, State=Disabled", { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: 44, padding: [0, 16], fill: V("accent"), opacity: 0.5 }, r);
  text(d, "Simpan menu", { fontStyle: "SemiBold" }); ids.push(d);
  const l = row("Variant=Primary, Size=md, State=Loading", { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: 44, padding: [0, 16], fill: V("accent"), opacity: 0.5 }, r);
  icon(l, "loader-circle", 16); text(l, "Menyimpan…", { fontStyle: "SemiBold" }); ids.push(l);
  komponen.push({ ids, set: "Button" });
});

// --- IconButton ---
section("IconButton", "ui/IconButton.tsx", (r) => {
  const b = row("IconButton", { mainAlign: "center", cornerRadius: 12, minHeight: 44, minWidth: 44, sizingH: "fixed", width: 44, sizingV: "fixed", height: 44 }, r);
  icon(b, "x", 20);
  komponen.push({ ids: [b] });
});

// --- Badge (Badge.tsx, StatusBadge.tsx, PaymentBadge.tsx) ---
section("Badge", "ui/Badge.tsx + StatusBadge.tsx + PaymentBadge.tsx", (r) => {
  const ids = [];
  const contoh = { warning: "Menunggu konfirmasi", info: "Dikonfirmasi", success: "Siap diambil", danger: "Dibatalkan", neutral: "Selesai" };
  for (const [t, c] of Object.entries(TONE)) {
    const b = row(`Tone=${t}`, { gap: 6, cornerRadius: 12, padding: [4, 8], fill: c.bg }, r);
    icon(b, c.icon, 16, c.fg); text(b, contoh[t], { fontStyle: "Medium", ...SM, fill: c.fg }); ids.push(b);
  }
  komponen.push({ ids, set: "Badge" });
  const p = row("PaymentBadge", { gap: 8 }, r);
  const m = row("Metode", { gap: 6 }, p); icon(m, "banknote", 16, V("ink-muted")); text(m, "Tunai", { ...SM, fill: V("ink-muted") });
  const s = row("Status", { gap: 6, cornerRadius: 12, padding: [4, 8], fill: V("warning-bg") }, p); icon(s, "clock", 16, V("warning")); text(s, "Belum bayar", { fontStyle: "Medium", ...SM, fill: V("warning") });
  komponen.push({ ids: [p] });
});

// --- Input / Textarea / Select / Field ---
const inputBox = (parent, name, { state = "Default", teks = "Contoh: Nasi Ayam Bakar", width = 320, extra = {} } = {}) => {
  const invalid = state === "Invalid", disabled = state === "Disabled";
  const b = row(name, { cornerRadius: 12, minHeight: 44, padding: [0, 12], sizingH: "fixed", width, fill: disabled ? V("subtle") : V("surface"), stroke: invalid ? V("danger") : V("line-strong"), strokeWeight: 1, mainAlign: "spaceBetween", ...extra }, parent);
  text(b, teks, { fill: state === "Filled" ? V("ink") : V("ink-muted") });
  return b;
};
section("Input", "ui/Input.tsx (Input, Textarea, Select)", (r) => {
  const ids = [];
  for (const st of ["Default", "Filled", "Invalid", "Disabled"]) ids.push(inputBox(r, `Type=Input, State=${st}`, { state: st, teks: st === "Default" ? "Contoh: Nasi Ayam Bakar" : "Nasi Ayam Bakar" }));
  const ta = col("Type=Textarea, State=Default", { cornerRadius: 12, minHeight: 96, padding: [8, 12], sizingH: "fixed", width: 320, fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, r);
  text(ta, "Deskripsi menu…", { fill: V("ink-muted") }); ids.push(ta);
  const se = inputBox(r, "Type=Select, State=Default", { teks: "Pilih kategori" }); icon(se, "chevron-down", 16, V("ink-muted")); ids.push(se);
  komponen.push({ ids, set: "Input" });
});
section("Field", "ui/Field.tsx", (r) => {
  const ids = [];
  for (const st of ["Default", "Help", "Error"]) {
    const f = col(`State=${st}`, { gap: 6, sizingH: "fixed", width: 320 }, r);
    const lab = row("Label", { gap: 0 }, f); text(lab, "Nama menu", { fontStyle: "Medium", ...SM }); text(lab, " *", { fontStyle: "Medium", ...SM, fill: V("danger") });
    inputBox(f, "Input", { state: st === "Error" ? "Invalid" : "Default", width: 320, extra: { sizingH: "fill" } });
    if (st === "Help") text(f, "Maksimal 80 karakter.", { ...SM, fill: V("ink-muted") });
    if (st === "Error") { const e = row("Error", { gap: 6, crossAlign: "min" }, f); icon(e, "circle-alert", 16, V("danger")); text(e, "Nama menu wajib diisi.", { ...SM, fill: V("danger") }); }
    ids.push(f);
  }
  komponen.push({ ids, set: "Field" });
});

// --- Card & KpiCard ---
section("Card", "ui/Card.tsx + KpiCard.tsx", (r) => {
  const c = col("Card", { gap: 8, padding: 16, cornerRadius: 16, fill: V("surface"), stroke: V("line"), strokeWeight: 1, sizingH: "fixed", width: 320 }, r);
  text(c, "Judul kartu", { fontStyle: "SemiBold", fontSize: 18, lineHeight: 28 }); text(c, "Isi kartu memakai Body/base, warna ink.", { sizingH: "fill" });
  const k = col("KpiCard", { gap: 4, padding: 16, cornerRadius: 16, fill: V("surface"), stroke: V("line"), strokeWeight: 1, sizingH: "fixed", width: 272 }, r);
  const lab = row("Label", { gap: 8 }, k); icon(lab, "banknote", 16, V("ink-muted")); text(lab, "Omzet hari ini", { ...SM, fill: V("ink-muted") });
  text(k, "Rp 1.250.000", { fontFamily: "JetBrains Mono", fontStyle: "SemiBold", fontSize: 24, lineHeight: 32 });
  text(k, "dari pesanan selesai hari ini", { ...SM, fill: V("ink-muted") });
  komponen.push({ ids: [c] }); komponen.push({ ids: [k] });
});

// --- Tabs ---
section("Tabs", "ui/Tabs.tsx", (r) => {
  const t = row("Tabs", { gap: 4, crossAlign: "max", strokeBottomWeight: 1, stroke: V("line") }, r);
  const items = [["Perlu tindakan", 3, true], ["Dimasak", 1, false], ["Siap diambil", 0, false]];
  const ids = [];
  for (const [l, c, aktif] of items) {
    const b = row(`State=${aktif ? "Active" : "Inactive"}`, { gap: 8, minHeight: 44, padding: [0, 16], strokeBottomWeight: 2, stroke: aktif ? V("primary") : "#00000000" }, t);
    text(b, l, { fontStyle: "Medium", fill: aktif ? V("primary") : V("ink-muted") });
    const chip = row("Count", { cornerRadius: 12, padding: [0, 6], fill: V("subtle") }, b); text(chip, String(c), { fontFamily: "JetBrains Mono", ...SM });
    ids.push(b);
  }
  komponen.push({ ids: ids.slice(0, 2), set: "Tab" });
});

// --- Switch, Checkbox, Stepper ---
section("Switch, Checkbox, Stepper", "ui/Switch.tsx + Checkbox.tsx + Stepper.tsx", (r) => {
  const sw = [];
  for (const on of [true, false]) {
    const s = row(`Checked=${on}`, { sizingH: "fixed", width: 48, sizingV: "fixed", height: 28, cornerRadius: 9999, padding: 2, mainAlign: on ? "max" : "min", fill: on ? V("primary") : V("line-strong") }, r);
    add("node.create", { type: "ellipse", name: "Knob", parent: ref(s), width: 24, height: 24, props: { fill: V("surface") } }, id("e"));
    sw.push(s);
  }
  komponen.push({ ids: sw, set: "Switch" });
  const cb = [];
  for (const on of [true, false]) {
    const c = row(`Checked=${on}`, { gap: 12, minHeight: 44 }, r);
    const box = row("Box", { sizingH: "fixed", width: 20, sizingV: "fixed", height: 20, cornerRadius: 4, mainAlign: "center", fill: on ? V("primary") : V("surface"), stroke: on ? V("primary") : V("line-strong"), strokeWeight: 1 }, c);
    if (on) icon(box, "check", 14, V("surface"));
    text(c, "Pesan dari meja aktif"); cb.push(c);
  }
  komponen.push({ ids: cb, set: "Checkbox" });
  const st = row("Stepper", { gap: 8 }, r);
  const btn = (nm, ic) => { const b = row(nm, { sizingH: "fixed", width: 44, sizingV: "fixed", height: 44, cornerRadius: 12, mainAlign: "center", fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, st); icon(b, ic, 16); };
  btn("Kurangi", "minus");
  const inp = row("Nilai", { sizingH: "fixed", width: 80, sizingV: "fixed", height: 44, cornerRadius: 12, mainAlign: "center", fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, st); text(inp, "20", { fontFamily: "JetBrains Mono" });
  btn("Tambah", "plus");
  komponen.push({ ids: [st] });
});

// --- Toast & Banner ---
section("Toast & Banner", "ui/Toast.tsx + Banner.tsx", (r) => {
  const ids = [], ids2 = [];
  const pesan = { success: "Kuota disimpan.", danger: "Gagal menyimpan. Coba lagi.", info: "Pesanan baru masuk.", warning: "Sisa waktu tahan 2 menit.", neutral: "Tersalin." };
  for (const [t, c] of Object.entries(TONE)) {
    const b = row(`Tone=${t}`, { gap: 12, padding: [4, 0, 4, 16], cornerRadius: 12, sizingH: "fixed", width: 384, fill: c.bg, stroke: V("line"), strokeWeight: 1, effects: [{ type: "dropShadow", color: "#0000001A", offset: [0, 10], radius: 15, spread: -3 }, { type: "dropShadow", color: "#0000001A", offset: [0, 4], radius: 6, spread: -4 }] }, r);
    icon(b, c.icon, 20, c.fg); text(b, pesan[t], { fontStyle: "Medium", ...SM, fill: c.fg, sizingH: "fill" });
    const x = row("Tutup", { sizingH: "fixed", width: 44, sizingV: "fixed", height: 44, mainAlign: "center", cornerRadius: 12 }, b); icon(x, "x", 20, c.fg);
    ids.push(b);
  }
  komponen.push({ ids, set: "Toast" });
  const banner = { info: "Di luar jam buka (06.00–21.00)", warning: "Toko belum terverifikasi. Lengkapi profil dan menu.", danger: "Toko ditangguhkan: laporan makanan tidak sesuai pesanan.", success: "Toko terverifikasi dan tampil di katalog.", neutral: "Tidak ada pengumuman." };
  for (const [t, c] of Object.entries(TONE)) {
    const b = row(`Tone=${t}`, { gap: 12, padding: [12, 16], cornerRadius: 12, sizingH: "fixed", width: 560, fill: c.bg, stroke: V("line"), strokeWeight: 1 }, r);
    icon(b, c.icon, 20, c.fg); text(b, banner[t], { fontStyle: "Medium", ...SM, fill: c.fg, sizingH: "fill" });
    if (t === "info") text(b, "Ubah jam buka", { fontStyle: "Medium", ...SM, fill: c.fg, textDecoration: "underline" });
    ids2.push(b);
  }
  komponen.push({ ids: ids2, set: "Banner" });
});

// --- Dialog, EmptyState, Pagination, Skeleton ---
section("Dialog & EmptyState", "ui/Dialog.tsx + ConfirmDialog.tsx + EmptyState.tsx", (r) => {
  const d = col("ConfirmDialog", { gap: 16, padding: 24, cornerRadius: 16, sizingH: "fixed", width: 512, fill: V("surface"), stroke: V("line"), strokeWeight: 1 }, r);
  const h = row("Header", { gap: 16, mainAlign: "spaceBetween", crossAlign: "min", sizingH: "fill" }, d); text(h, "Tolak pesanan KK-20261112-9V56?", { fontStyle: "SemiBold", fontSize: 18, lineHeight: 28, sizingH: "fill" });
  const x = row("Tutup", { sizingH: "fixed", width: 44, sizingV: "fixed", height: 44, mainAlign: "center", cornerRadius: 12 }, h); icon(x, "x", 20);
  text(d, "Porsi yang ditahan dikembalikan ke kuota dan pembeli diberi tahu.", { fill: V("ink-muted"), sizingH: "fill" });
  const f = col("Alasan", { gap: 6, sizingH: "fill" }, d); text(f, "Tulis alasan *", { fontStyle: "Medium", ...SM });
  const ta = col("Textarea", { cornerRadius: 12, minHeight: 96, padding: [8, 12], sizingH: "fill", fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, f); text(ta, "Bahan habis hari ini.", {});
  const foot = row("Footer", { gap: 12, mainAlign: "max", sizingH: "fill", padding: [8, 0, 0, 0] }, d);
  const b1 = row("Batal", { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: 44, padding: [0, 16], fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, foot); text(b1, "Batal", { fontStyle: "SemiBold" });
  const b2 = row("Tolak", { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: 44, padding: [0, 16], fill: V("danger") }, foot); text(b2, "Tolak pesanan", { fontStyle: "SemiBold", fill: V("surface") });
  komponen.push({ ids: [d] });
  const e = col("EmptyState", { gap: 12, padding: [48, 24], cornerRadius: 16, crossAlign: "center", sizingH: "fixed", width: 560, stroke: V("line-strong"), strokeWeight: 1, dashes: [4, 4] }, r);
  icon(e, "inbox", 40, V("ink-muted")); text(e, "Belum ada pesanan", { fontStyle: "SemiBold", fontSize: 18, lineHeight: 28 });
  text(e, "Pastikan status dapur Buka dan menu punya kuota.", { fill: V("ink-muted"), textAlign: "center", sizingH: "fixed", width: 384 });
  const b3 = row("Aksi", { gap: 8, mainAlign: "center", cornerRadius: 12, minHeight: 44, padding: [0, 16], fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, e); text(b3, "Atur kuota", { fontStyle: "SemiBold" });
  komponen.push({ ids: [e] });
});
section("Pagination & Skeleton", "ui/Pagination.tsx + Skeleton.tsx", (r) => {
  const p = row("Pagination", { gap: 12, mainAlign: "spaceBetween", sizingH: "fixed", width: 560 }, r);
  const prev = row("Sebelumnya", { gap: 4, minHeight: 44, padding: [0, 12], cornerRadius: 12, fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1, opacity: 0.5 }, p); icon(prev, "chevron-left", 16); text(prev, "Sebelumnya", SM);
  text(p, "Halaman 1 dari 3", { ...SM, fill: V("ink-muted") });
  const next = row("Berikutnya", { gap: 4, minHeight: 44, padding: [0, 12], cornerRadius: 12, fill: V("surface"), stroke: V("line-strong"), strokeWeight: 1 }, p); text(next, "Berikutnya", SM); icon(next, "chevron-right", 16);
  komponen.push({ ids: [p] });
  const sk = col("SkeletonKpi", { gap: 8, padding: 16, cornerRadius: 16, fill: V("surface"), stroke: V("line"), strokeWeight: 1, sizingH: "fixed", width: 272 }, r);
  rect(sk, "Teks sm", { width: 112, height: 11, cornerRadius: 12, fill: V("line") }); rect(sk, "Teks 2xl", { width: 128, height: 18, cornerRadius: 12, fill: V("line") }); rect(sk, "Teks sm", { width: 160, height: 11, cornerRadius: 12, fill: V("line") });
  komponen.push({ ids: [sk] });
});

// --- DataTable ---
section("DataTable", "ui/DataTable.tsx", (r) => {
  const t = col("DataTable", { cornerRadius: 16, clip: true, stroke: V("line"), strokeWeight: 1, sizingH: "fixed", width: 760 }, r);
  const kolom = [["Kode", 180, false], ["Pemesan", 220, false], ["Status", 200, false], ["Total", 160, true]];
  const baris = (data, header, i) => {
    const b = row(header ? "Header" : `Baris ${i}`, { sizingH: "fill", fill: header ? V("subtle") : V("surface"), ...(header ? {} : { strokeTopWeight: 1, stroke: V("line") }) }, t);
    kolom.forEach(([k, w, kanan], j) => {
      const c = row(k, { sizingH: "fixed", width: w, padding: [12, 16], mainAlign: kanan ? "max" : "min" }, b);
      text(c, data[j], header ? { fontStyle: "Medium", ...SM, fill: V("ink-muted") } : { ...SM, ...(kanan ? { fontFamily: "JetBrains Mono" } : {}) });
    });
  };
  baris(kolom.map((k) => k[0]), true);
  [["KK-20261112-9V56", "Rina Pembeli", "Menunggu konfirmasi", "Rp 52.000"], ["KK-20261112-7RQP", "Rina Pembeli", "Dikonfirmasi", "Rp 18.000"], ["KK-20261112-50ZJ", "Rina Pembeli", "Selesai", "Rp 36.000"]].forEach((d, i) => baris(d, false, i + 1));
  komponen.push({ ids: [t] });
});

// --- Shell: Nav item, Sidebar, Header ---
section("Shell", "shell/NavList.tsx + Sidebar.tsx + Header.tsx", (r) => {
  const nav = [];
  for (const aktif of [true, false]) {
    const i = row(`State=${aktif ? "Active" : "Inactive"}`, { gap: 12, minHeight: 44, padding: [0, 12], cornerRadius: 12, sizingH: "fixed", width: 232, strokeLeftWeight: 4, stroke: aktif ? V("accent") : "#00000000", fill: aktif ? V("primary-soft") : "none" }, r);
    icon(i, "layout-grid", 20, aktif ? V("primary") : V("ink")); text(i, "Dashboard", { ...SM, fontStyle: aktif ? "SemiBold" : "Regular", fill: aktif ? V("primary") : V("ink"), sizingH: "fill" });
    if (aktif) { const badge = row("Badge", { cornerRadius: 9999, padding: [0, 6], minWidth: 20, mainAlign: "center", fill: V("warning-bg") }, i); text(badge, "3", { fontStyle: "Bold", ...XS, fill: V("warning") }); }
    nav.push(i);
  }
  komponen.push({ ids: nav, set: "NavItem" });
  const grup = text(r, "OPERASIONAL", { fontStyle: "SemiBold", ...XS, letterSpacing: "5%", fill: V("ink-muted") }, "NavGroupTitle");
  komponen.push({ ids: [grup] });
  const h = row("Header", { gap: 12, minHeight: 64, padding: [0, 16], sizingH: "fixed", width: 1184, fill: V("surface"), strokeBottomWeight: 1, stroke: V("line") }, r);
  const s = row("Search", { gap: 8, minHeight: 44, padding: [0, 12], cornerRadius: 12, sizingH: "fixed", width: 448, fill: V("canvas"), stroke: V("line-strong"), strokeWeight: 1 }, h);
  icon(s, "search", 16, V("ink-muted")); text(s, "Cari kode atau nama pemesan", { ...SM, fill: V("ink-muted") });
  frame("Spacer", { sizingH: "fill", sizingV: "fixed", height: 1, fill: "none" }, h);
  text(h, "Kam, 12 Nov · 00.13 WIB", { ...SM, fill: V("ink-muted") }, "Clock");
  const acc = row("AccountMenu", { gap: 8 }, h);
  const av = row("Avatar", { sizingH: "fixed", width: 32, sizingV: "fixed", height: 32, cornerRadius: 9999, mainAlign: "center", fill: V("primary-soft") }, acc); text(av, "CD", { fontStyle: "Bold", ...XS, fill: V("primary") });
  const nm = col("Nama", { gap: 0 }, acc); text(nm, "Citra Demo", { fontStyle: "SemiBold", ...SM }); text(nm, "Es Citra (demo terverifikasi)", { ...XS, fill: V("ink-muted") });
  icon(acc, "chevron-down", 16, V("ink-muted"));
  komponen.push({ ids: [h] });
});

// --- jadikan komponen & gabungkan varian ---
for (const k of komponen) {
  if (k.ids.length === 1) { add("component.create", { ids: [ref(k.ids[0])] }); continue; }
  add("component.createMultiple", { ids: k.ids.map(ref) });
  add("component.combineVariants", { ids: k.ids.map(ref) }, `set_${k.set}`);
  add("node.set", { ids: [ref(`set_${k.set}`)], name: k.set });
}

process.stdout.write(JSON.stringify(steps));
console.error(`${steps.length} langkah, ${komponen.length} komponen/set`);
