// Buat skrip FigCraft untuk page "04 Flow": satu section per fitur, berisi alur utama (baris atas),
// alur alternatif dan alur error (baris di bawahnya) dari docs/prd.md §4–5.
// Dibangun dari frame + vector biasa (perintah board.* hanya ada di file board, bukan file desain).
// Jalankan: node build-flows.mjs > flows.json ; figcraft-cli run flows.json --in ... --out ...
//
// Notasi simpul (string): awalan menentukan bentuk/warna, "label|teks" memberi label pada panah masuk.
//   "@/rute"  layar (biru)      "?teks" keputusan (ungu, belah ketupat)   "!teks" error (merah)
//   "✓teks"   akhir sukses (hijau, pil)   "○teks" mulai (abu, pil)   "teks" langkah/sistem (abu)
// Cabang: { dari: indeks simpul utama, jenis: "alt"|"err", simpul: [...], ke?: indeks utama tujuan panah balik }
const PAGE = 5;
const W = 220, H = 96, PX = 320, PY = 176, PAD = 80, JUDUL_H = 72, GAP_SEC = 160, MAX_W = 6600;
const WARNA = {
  blue: { fill: "#DBEAFE", stroke: "#3B82F6", text: "#1E3A8A" },
  gray: { fill: "#F4F2EB", stroke: "#9B9187", text: "#262017" },
  violet: { fill: "#EDE9FE", stroke: "#7C3AED", text: "#4C1D95" },
  orange: { fill: "#FFEDD5", stroke: "#F97316", text: "#7C2D12" },
  red: { fill: "#FEE2E2", stroke: "#DC2626", text: "#7F1D1D" },
  green: { fill: "#DCFCE7", stroke: "#16A34A", text: "#14532D" },
};
const GARIS = { utama: "#665D55", alt: "#F97316", err: "#DC2626" };

const FLOWS = [
  { kode: "F01", nama: "Daftar penjual", utama: ["○Calon penjual", "@/register", "Isi data pemilik (langkah 1)", "?Isian valid?", "ya|Isi data usaha (langkah 2)", "POST /auth/merchant/register", "?Berhasil?", "ya|Akun merchant + toko pending", "@/login", "✓Masuk ke dashboard pending"],
    cabang: [
      { dari: 3, jenis: "err", simpul: ["tidak|!Banner “Periksa isian berikut” + pesan per isian"], ke: 2 },
      { dari: 6, jenis: "err", simpul: ["409|!WA/email sudah terdaftar"], ke: 2 },
      { dari: 1, jenis: "alt", simpul: ["sudah punya akun|@/login"] },
    ] },
  { kode: "F02", nama: "Masuk", utama: ["○Pengguna", "@/login", "Isi email/WA + kata sandi", "POST /auth/login", "?Kredensial benar?", "ya|Cookie kk_session (TTL 1 hari)", "?Peran?", "merchant|@/dashboard", "✓Dashboard penjual"],
    cabang: [
      { dari: 4, jenis: "err", simpul: ["tidak|!Banner “Email/WA atau kata sandi salah”"], ke: 2 },
      { dari: 4, jenis: "err", simpul: ["terlalu sering|!429 terlalu banyak percobaan, tunggu"], ke: 2 },
      { dari: 6, jenis: "alt", simpul: ["admin|@/admin", "?must_change_password?", "ya|@/admin/akun ganti sandi", "✓Dashboard admin"] },
      { dari: 7, jenis: "alt", simpul: ["toko pending|@/dashboard (pending): banner menunggu verifikasi"] },
      { dari: 7, jenis: "alt", simpul: ["toko suspended|@/dashboard (suspended): alasan + kontak CS"] },
      { dari: 2, jenis: "alt", simpul: ["lupa kata sandi|@/lupa-sandi (F11)"] },
    ] },
  { kode: "F11", nama: "Lupa kata sandi (OTP email)", utama: ["○Pengguna", "@/lupa-sandi", "Masukkan email", "POST /auth/password/forgot (respons selalu sama)", "Masukkan OTP 6 digit", "POST /auth/password/verify", "?OTP valid?", "ya|Kata sandi baru + konfirmasi", "POST /auth/password/reset", "✓Kembali ke /login"],
    cabang: [
      { dari: 6, jenis: "err", simpul: ["salah|!OTP salah (maks 5 percobaan)"], ke: 4 },
      { dari: 6, jenis: "err", simpul: ["kedaluwarsa|!OTP lewat 10 menit / percobaan habis", "Minta OTP baru"], ke: 2 },
      { dari: 7, jenis: "err", simpul: ["tidak valid|!Sandi < 8 karakter / tidak sama"], ke: 7 },
    ] },
  { kode: "F03", nama: "Profil toko & pengaturan", utama: ["○Penjual", "@/pengaturan", "Ubah nama, deskripsi, alamat, WA, jam buka–tutup, hold_minutes", "Tambah titik temu (min 1, maks 50)", "Unggah logo (WebP ≤ 1600 px)", "PATCH /merchant/profile", "?Valid?", "ya|✓Toast “Profil tersimpan”"],
    cabang: [
      { dari: 6, jenis: "err", simpul: ["tidak|!Pesan validasi per isian (jam buka ≥ tutup, titik temu kosong)"], ke: 2 },
      { dari: 4, jenis: "err", simpul: ["R2 kosong|!503 unggah tidak tersedia"] },
      { dari: 1, jenis: "alt", simpul: ["rekening pencairan|Isi bank, nomor, nama + kata sandi", "PUT /merchant/payout-account", "?Sandi benar?", "ya|✓Rekening tersimpan"] },
      { dari: 1, jenis: "alt", simpul: ["sakelar buka/tutup di shell|PATCH /merchant/status", "✓Status dapur berubah"] },
      { dari: 1, jenis: "alt", simpul: ["@/template-wa", "Ubah templat (≤ 1.000 karakter, placeholder {kode} {nama} …)", "✓Tersimpan"] },
    ] },
  { kode: "F04", nama: "Menu & kuota", utama: ["○Penjual", "@/menu (filter status, q, kategori)", "@/menu/baru", "Isi nama, kategori, harga > HPP, kuota, estimasi, opsi ≤ 20", "POST /merchant/menus", "?Valid?", "ya|✓Kembali ke /menu, menu aktif"],
    cabang: [
      { dari: 5, jenis: "err", simpul: ["tidak|!Pesan validasi (harga ≤ HPP, nama > 80, opsi ganda)"], ke: 3 },
      { dari: 1, jenis: "alt", simpul: ["klik menu|@/menu/[id]", "Ubah lalu PATCH /merchant/menus/:id", "✓Tersimpan"] },
      { dari: 1, jenis: "alt", simpul: ["hapus|Dialog konfirmasi hapus", "DELETE (soft delete)", "✓Menu hilang dari daftar"] },
      { dari: 1, jenis: "alt", simpul: ["stepper kuota ±|Debounce 600 ms, antrean request", "PATCH /merchant/menus/:id/quota", "?quota ≥ sold + held?", "ya|✓Kuota hari ini berubah"] },
      { dari: 1, jenis: "err", simpul: ["kuota ditolak|!409, nilai di-rollback + toast"] },
      { dari: 1, jenis: "err", simpul: ["diturunkan admin|!Badge “Diturunkan” + alasan, tidak bisa diaktifkan"] },
    ] },
  { kode: "F07/F08", nama: "Proses pesanan penjual", utama: ["○Pesanan masuk (holding)", "@/dashboard polling 5 detik", "@/pesanan/[code]", "Konfirmasi", "?Metode bayar?", "tunai / sudah lunas|confirmed", "Masak → cooking", "Siap → ready", "Selesai → completed", "✓Pembeli diberi notifikasi, log status tercatat"],
    cabang: [
      { dari: 4, jenis: "err", simpul: ["VA/online belum lunas|!409 “Pembayaran belum lunas”"], ke: 2 },
      { dari: 2, jenis: "alt", simpul: ["tolak (holding/confirmed)|Dialog alasan wajib", "POST /merchant/orders/:code/reject", "cancelled"] },
      { dari: 3, jenis: "alt", simpul: ["dalam 5 detik|Toast dengan tombol Urungkan", "Aksi dibatalkan"], ke: 2 },
      { dari: 0, jenis: "err", simpul: ["hold_until lewat|!Job 30 detik → expired, porsi & kuota promo kembali"] },
      { dari: 3, jenis: "err", simpul: ["status sudah berubah|!409 transisi tak sah, muat ulang detail"], ke: 2 },
      { dari: 2, jenis: "alt", simpul: ["WhatsApp pembeli|GET /merchant/orders/:code/whatsapp", "Buka wa.me dengan templat"] },
    ] },
  { kode: "F09", nama: "Laporan", utama: ["○Penjual", "@/laporan", "Pilih periode", "GET /merchant/reports/summary + hourly + transactions", "Kartu KPI, grafik per jam, tabel transaksi", "Ekspor CSV (/api/laporan/csv, UTF-8 BOM)", "✓File terunduh"],
    cabang: [
      { dari: 3, jenis: "alt", simpul: ["tanpa data|EmptyState “Belum ada transaksi”"] },
      { dari: 3, jenis: "err", simpul: ["gagal|!Banner error + tombol coba lagi"], ke: 2 },
    ] },
  { kode: "F12", nama: "Promo toko", utama: ["○Penjual", "@/promo", "Buat promo: kode ≤ 30, tipe percent/fixed/free_service_fee, nilai, min belanja, kuota, periode", "POST /merchant/promos", "?Valid?", "ya|Promo aktif", "✓Pembeli yang memfavoritkan menu toko diberi notifikasi promo"],
    cabang: [
      { dari: 4, jenis: "err", simpul: ["tidak|!Validasi: kode ganda, periode terbalik, nilai di luar batas"], ke: 2 },
      { dari: 1, jenis: "alt", simpul: ["ubah / nonaktifkan|PATCH /merchant/promos/:id", "✓Status berubah"] },
      { dari: 1, jenis: "alt", simpul: ["hapus|Dialog konfirmasi", "DELETE /merchant/promos/:id"] },
      { dari: 5, jenis: "alt", simpul: ["dipakai pembeli|Cek aktif, periode, kuota atomik, min belanja, batas per pembeli", "Kuota kembali bila pesanan batal/kedaluwarsa"] },
    ] },
  { kode: "F13", nama: "Ulasan toko", utama: ["○Penjual", "@/ulasan", "GET /merchant/reviews", "Daftar ulasan per menu: rating, komentar, kode pesanan", "✓Rating toko & menu terlihat"],
    cabang: [
      { dari: 2, jenis: "alt", simpul: ["belum ada|EmptyState “Belum ada ulasan”"] },
      { dari: 3, jenis: "alt", simpul: ["disembunyikan admin|Ulasan tidak tampil di publik (F23)"] },
    ] },
  { kode: "F17", nama: "Asisten AI toko", utama: ["○Penjual", "@/copilot", "Tulis pertanyaan", "POST /merchant/assistant (konteks data toko)", "?Penyedia AI tersedia?", "ya|Jawaban AI", "✓Tampil di percakapan"],
    cabang: [
      { dari: 4, jenis: "err", simpul: ["tidak|!503 “Asisten belum tersedia”"] },
      { dari: 3, jenis: "err", simpul: ["> 10 permintaan / 10 menit|!429 batas pemakaian, tunggu"] },
      { dari: 1, jenis: "alt", simpul: ["kalkulator HPP|Isi bahan + porsi", "Hitung HPP dan saran harga lokal"] },
    ] },
  { kode: "F21", nama: "Pesan dari meja (QR)", utama: ["○Penjual: dine_in_enabled + buat meja", "@/cetak-qr (A4)", "Tamu memindai QR", "@/meja/[token]", "Pilih menu non-pre-order, keranjang lokal", "Checkout: nama 1–60, WA opsional, catatan", "POST /tables/:token/orders (X-Guest-Token)", "POST /guest/orders/:code/pay → Snap", "?Bayar berhasil?", "settlement|confirmed", "@/meja/pesanan/[code] pantau status", "✓Pesanan selesai di meja"],
    cabang: [
      { dari: 3, jenis: "err", simpul: ["token tidak valid|!404 “QR meja tidak aktif”"] },
      { dari: 3, jenis: "err", simpul: ["toko tutup|!409 MERCHANT_CLOSED, menu tidak bisa dipesan"] },
      { dari: 6, jenis: "err", simpul: ["> 5 pesanan menunggu|!409 meja penuh, tanyakan ke kasir"], ke: 4 },
      { dari: 7, jenis: "err", simpul: ["Midtrans tidak diatur|!409 pembayaran tidak tersedia"] },
      { dari: 8, jenis: "err", simpul: ["tidak / lewat hold_until|!expired, porsi kembali"] },
      { dari: 3, jenis: "alt", simpul: ["belum memindai|@/meja (index): instruksi scan"] },
    ] },
  { kode: "F18", nama: "Verifikasi penjual (admin)", utama: ["○Admin ops+", "@/admin/verifikasi antrean", "@/admin/penjual/[id]", "Checklist: WA, alamat, titik temu, menu aktif berfoto, jam buka < tutup", "?Lengkap?", "ya|verify", "✓Toko verified, tampil di katalog"],
    cabang: [
      { dari: 4, jenis: "alt", simpul: ["belum|request-fix + catatan", "Toko pending dengan catatan perbaikan"] },
      { dari: 6, jenis: "alt", simpul: ["melanggar|suspend + alasan", "suspended (dashboard penjual terkunci)", "reactivate", "verified"] },
      { dari: 6, jenis: "alt", simpul: ["close-today|Toko ditutup hari ini"] },
      { dari: 1, jenis: "alt", simpul: ["@/admin/penjual daftar semua toko + filter status"] },
      { dari: 5, jenis: "err", simpul: ["status sudah berubah|!409 aksi ditolak, muat ulang"], ke: 2 },
    ] },
  { kode: "F19", nama: "Data master (admin)", utama: ["○Admin ops+", "@/admin/data-master", "Tab jenis usaha / kategori / titik temu", "Buat atau ubah (nama, slug, urutan)", "POST/PATCH /admin/master/:kind", "?Valid?", "ya|✓Tersimpan"],
    cabang: [
      { dari: 5, jenis: "err", simpul: ["tidak|!409 nama/slug ganda"], ke: 3 },
      { dari: 2, jenis: "alt", simpul: ["aktif / nonaktif|POST .../activate | deactivate", "✓Tidak tampil di pilihan publik"] },
    ] },
  { kode: "F20", nama: "Promo platform & setelan (admin)", utama: ["○Admin ops+", "@/admin/promo", "Buat promo platform (berlaku semua toko)", "POST /admin/promos", "?Valid?", "ya|aktif / nonaktif", "✓Promo dipakai saat quote pesanan"],
    cabang: [
      { dari: 4, jenis: "err", simpul: ["tidak|!Validasi kode ganda / periode"], ke: 2 },
      { dari: 1, jenis: "alt", simpul: ["setelan|Biaya layanan + kontak CS", "PUT /admin/settings/service-fee | cs-contact", "?Level super?", "ya|✓Tersimpan"] },
      { dari: 1, jenis: "err", simpul: ["ops ubah setelan|!403 hanya super admin"] },
    ] },
  { kode: "F23", nama: "Moderasi (admin)", utama: ["○Admin ops+", "@/admin/moderasi", "Tab ulasan / menu", "Pilih item + alasan", "POST reviews/:id/hide | menus/:id/takedown", "✓Ulasan tersembunyi / menu diturunkan, penjual melihat alasan"],
    cabang: [
      { dari: 2, jenis: "alt", simpul: ["pulihkan|POST reviews/:id/unhide | menus/:id/restore", "✓Kembali tampil"] },
      { dari: 3, jenis: "err", simpul: ["alasan kosong|!Validasi alasan wajib"], ke: 3 },
    ] },
  { kode: "F26", nama: "Keuangan & pencairan (admin super)", utama: ["○Admin super", "@/admin/pencairan", "Saldo per toko (as_of) dari pesanan completed non-tunai", "Transfer lewat bank di luar aplikasi", "Catat: amount + until + referensi", "POST /admin/payouts", "?amount = saldo s.d. until?", "ya|✓Pesanan diberi payout_id, riwayat tercatat"],
    cabang: [
      { dari: 6, jenis: "err", simpul: ["tidak / saldo berubah / ganda|!409 catatan ditolak, muat ulang saldo"], ke: 2 },
      { dari: 1, jenis: "alt", simpul: ["refund|Daftar pembayaran lunas pada pesanan batal/expired", "Kembalikan di luar aplikasi", "POST /admin/refunds/:code + referensi", "✓payment_status refunded"] },
      { dari: 0, jenis: "alt", simpul: ["@/admin/keuangan rekap omzet, diskon, biaya layanan", "Ekspor CSV"] },
      { dari: 1, jenis: "err", simpul: ["ops membuka|!403 hanya super admin"] },
    ] },
  { kode: "F22", nama: "Penyedia AI & pemakaian (admin)", utama: ["○Admin", "@/admin/ai", "Tambah penyedia: gemini/groq/openrouter/nvidia, key, priority", "POST /admin/ai-providers (key dienkripsi, hanya key_hint)", "POST .../:id/test", "?Tes berhasil?", "ya|✓Aktif, dicoba urut priority"],
    cabang: [
      { dari: 5, jenis: "err", simpul: ["tidak|!Kunci ditolak / timeout, perbaiki key"], ke: 2 },
      { dari: 6, jenis: "err", simpul: ["429 saat dipakai|!cooldown_until, lanjut ke penyedia berikutnya"] },
      { dari: 1, jenis: "alt", simpul: ["pemakaian|GET /admin/ai-usage?days=1..90", "Token, panggilan, gagal, latensi per penyedia"] },
    ] },
  { kode: "Admin", nama: "Kelola akun admin & pengumuman", utama: ["○Admin super", "@/admin/admin", "Buat admin: nama, email, level, sandi sementara", "POST /admin/admins (must_change_password)", "Admin baru masuk", "@/admin/akun", "PUT /me/password", "✓Sandi diganti, masuk dashboard"],
    cabang: [
      { dari: 6, jenis: "err", simpul: ["sandi lama salah|!401, ulangi"], ke: 5 },
      { dari: 1, jenis: "alt", simpul: ["ubah level / nonaktif / reset sandi|PATCH level, POST activate|deactivate|reset-password"] },
      { dari: 0, jenis: "alt", simpul: ["@/admin/pengumuman", "POST /admin/broadcasts ke pembeli/penjual/semua", "✓Notifikasi info terkirim"] },
      { dari: 0, jenis: "alt", simpul: ["@/admin/log audit", "@/admin/server status + log 5xx"] },
    ] },
  { kode: "F06/F10", nama: "Checkout pembeli (mobile, belum terintegrasi)", utama: ["○Pembeli", "Pilih menu + titik temu + promo", "POST /orders/quote", "POST /orders + Idempotency-Key", "holding, porsi dikunci, hold_until berjalan", "?Metode bayar?", "va / online|Bayar Midtrans", "Webhook settlement → paid → confirmed", "cooking → ready → completed", "✓Ulasan per menu"],
    cabang: [
      { dari: 5, jenis: "alt", simpul: ["tunai|Penjual Konfirmasi sebelum hold_until", "confirmed"], ke: 8 },
      { dari: 4, jenis: "err", simpul: ["tidak dibayar/dikonfirmasi|!expired, porsi & promo kembali"] },
      { dari: 6, jenis: "err", simpul: ["sisa tahan < 1 menit|!409 “Batas waktu pesanan sudah habis.”"] },
      { dari: 4, jenis: "alt", simpul: ["batalkan (holding; confirmed hanya tunai)|POST /orders/:code/cancel", "cancelled; bila sudah lunas masuk daftar refund"] },
      { dari: 3, jenis: "err", simpul: ["porsi habis (dua checkout bersamaan)|!409 hanya satu pesanan yang jadi"] },
    ] },
];

const steps = [];
const add = (command, params, as) => { const s = { command, params }; if (as) s.as = as; steps.push(s); return as; };
const ref = (as) => ({ $ref: as });
let n = 0;
add("page.select", { id: PAGE });

const parse = (s) => {
  let label; const i = s.indexOf("|"); if (i > 0) { label = s.slice(0, i); s = s.slice(i + 1); }
  const p = s[0];
  const m = { "@": ["layar", "blue"], "?": ["putus", "violet"], "!": ["error", "red"], "✓": ["akhir", "green"], "○": ["mulai", "gray"] }[p];
  return { label, bentuk: m?.[0] ?? "langkah", color: m?.[1], text: m ? s.slice(1).trim() : s };
};

const teks = (parent, text, props, extra = {}) => add("node.create", { type: "text", name: text.slice(0, 40), parent: ref(parent), text, ...extra, props: { fontFamily: "Inter", fontStyle: "Medium", fontSize: 13, lineHeight: 18, textAlign: "center", textAutoResize: "height", sizingH: "fill", ...props } });

const simpul = (sec, x, y, spec) => {
  const w = WARNA[spec.color ?? "gray"];
  const putus = spec.bentuk === "putus", pil = spec.bentuk === "mulai" || spec.bentuk === "akhir";
  const fw = putus ? W + 20 : W, fh = putus ? H + 24 : H;
  const fr = add("node.create", { type: "frame", name: `${spec.bentuk}: ${spec.text.slice(0, 40)}`, parent: ref(sec), x: putus ? x - 10 : x, y: putus ? y - 12 : y, width: fw, height: fh, props: putus ? { fill: "none", layout: "vertical", mainAlign: "center", crossAlign: "center", padding: [12, 28, 12, 28] } : { fill: w.fill, stroke: w.stroke, strokeWeight: 1.5, cornerRadius: pil ? H / 2 : 12, layout: "vertical", mainAlign: "center", crossAlign: "center", padding: 12 } }, `n${++n}`);
  if (putus) add("node.create", { type: "polygon", name: "belah ketupat", parent: ref(fr), x: 0, y: 0, width: fw, height: fh, props: { pointCount: 4, fill: w.fill, stroke: w.stroke, strokeWeight: 1.5, absolute: true } });
  teks(fr, spec.text, { fill: w.text, fontStyle: spec.bentuk === "layar" ? "SemiBold" : "Medium", fontSize: putus ? 12 : 13 });
  return fr;
};

// panah siku: dari sisi kanan/bawah simpul A ke sisi kiri/bawah simpul B (koordinat relatif section)
const panah = (sec, a, b, jenis, label, mode) => {
  const warna = GARIS[jenis];
  const c = (nd) => { const d = nd.spec.bentuk === 'putus' ? 10 : 0, e = nd.spec.bentuk === 'putus' ? 12 : 0; return { l: nd.x - d, r: nd.x + W + d, t: nd.y - e, b: nd.y + H + e, cx: nd.x + W / 2, cy: nd.y + H / 2 }; };
  const A = c(a), B = c(b);
  let x0, y0, path;
  if (mode === "kanan") { x0 = A.r; y0 = A.cy; path = `M0 0 L${B.l - A.r} ${B.cy - A.cy}`; if (Math.abs(B.cy - A.cy) > 1) path = `M0 0 L${(B.l - A.r) / 2} 0 L${(B.l - A.r) / 2} ${B.cy - A.cy} L${B.l - A.r} ${B.cy - A.cy}`; }
  else if (mode === "turun") { x0 = A.cx; y0 = A.b; path = `M0 0 L0 ${B.cy - A.b} L${B.l - A.cx} ${B.cy - A.b}`; }
  else { // balik: dari bawah A, lewat bawah baris, naik ke bawah B
    const dy = PY - H - 30, gx = B.l - 28 - A.cx, gy = B.cy + 24 - A.b; x0 = A.cx; y0 = A.b; path = `M0 0 L0 ${dy} L${gx} ${dy} L${gx} ${gy} L${B.l - A.cx} ${gy}`; }
  add("node.create", { type: "vector", name: `panah ${jenis}`, parent: ref(sec), x: x0, y: y0, path, props: { stroke: warna, strokeWeight: 1.5, endCap: "triangleArrow", fill: "none", strokeJoin: "round", ...(mode === "balik" ? { dashes: [6, 4] } : {}) } });
  if (label) {
    const lx = mode === "kanan" ? x0 + 6 : x0 + 8, ly = mode === "kanan" ? y0 - 20 : y0 + (mode === "turun" ? (B.cy - A.b) - 20 : 6);
    add("node.create", { type: "text", name: `label ${label}`, parent: ref(sec), x: lx, y: ly, text: label, props: { fontFamily: "Inter", fontStyle: "Regular", fontSize: 11, lineHeight: 16, fill: warna, textAutoResize: "widthAndHeight" } });
  }
};

// Legenda
add("node.create", { type: "text", name: "Legenda", x: 0, y: -56, text: "04 Flow · biru = layar, abu = langkah/sistem, ungu = keputusan, oranye = alur alternatif, merah = alur error, hijau = akhir, putus-putus = kembali ke langkah. Sumber: docs/prd.md §4–5.", props: { fontFamily: "Inter", fontStyle: "Regular", fontSize: 16, lineHeight: 24, fill: "#665D55" } });

let rowX = 0, rowY = 0, rowH = 0;
for (const f of FLOWS) {
  const nodes = {}; const edges = [];
  f.utama.forEach((s, i) => { nodes[`u${i}`] = { col: i, row: 0, spec: parse(s) }; if (i) edges.push({ a: `u${i - 1}`, b: `u${i}`, label: nodes[`u${i}`].spec.label, jenis: "utama", mode: "kanan" }); });
  let row = 1;
  for (const c of f.cabang) {
    const r = row++;
    c.simpul.forEach((s, j) => {
      const spec = parse(s); if (!spec.color) spec.color = c.jenis === "err" ? "red" : "orange";
      nodes[`c${r}_${j}`] = { col: c.dari + 1 + j, row: r, spec };
      edges.push({ a: j ? `c${r}_${j - 1}` : `u${c.dari}`, b: `c${r}_${j}`, label: spec.label, jenis: c.jenis, mode: j ? "kanan" : "turun" });
    });
    if (c.ke != null) edges.push({ a: `c${r}_${c.simpul.length - 1}`, b: `u${c.ke}`, jenis: c.jenis, mode: "balik", label: "kembali" });
  }
  const list = Object.values(nodes);
  const cols = Math.max(...list.map((x) => x.col)) + 1;
  const secW = PAD * 2 + cols * PX - (PX - W);
  const secH = PAD + JUDUL_H + row * PY - (PY - H) + PAD;
  if (rowX > 0 && rowX + secW > MAX_W) { rowX = 0; rowY += rowH + GAP_SEC; rowH = 0; }
  const sec = add("node.create", { type: "section", name: `${f.kode} · ${f.nama}`, x: rowX, y: rowY, width: secW, height: secH }, `sec${++n}`);
  add("node.create", { type: "text", name: "judul", parent: ref(sec), x: PAD, y: PAD - 24, text: `${f.kode} · ${f.nama}`, props: { fontFamily: "Plus Jakarta Sans", fontStyle: "Bold", fontSize: 28, lineHeight: 36, fill: "#262017" } });
  for (const nd of list) { nd.x = PAD + nd.col * PX; nd.y = PAD + JUDUL_H + nd.row * PY; }
  // panah dulu (di bawah), lalu simpul di atasnya
  for (const e of edges) panah(sec, nodes[e.a], nodes[e.b], e.jenis, e.label, e.mode);
  for (const nd of list) simpul(sec, nd.x, nd.y, nd.spec);
  rowX += secW + GAP_SEC; rowH = Math.max(rowH, secH);
}
process.stdout.write(JSON.stringify(steps));
console.error(`flow: ${FLOWS.length} fitur, ${steps.length} langkah`);
