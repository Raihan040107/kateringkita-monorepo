# PRD KateringKita

Dokumen kebutuhan produk ini direkonstruksi dari kode di monorepo `D:\PBL` (`backend/`, `frontend/`, `mobile/`) pada 2026-11-11. Yang ditulis di sini adalah perilaku yang benar-benar diimplementasikan, bukan rencana. Bagian 9 mencatat kesenjangan antar-platform.

## 1. Ringkasan produk

KateringKita adalah marketplace pre-order katering, snack, dan danusan untuk lingkungan kampus (seed data: Vokasi UB dan FILKOM UB, Malang). Pembeli (mahasiswa) memesan porsi dari penjual katering, porsi dikunci sementara, penjual memproses, pembeli mengambil di titik temu kampus atau memesan langsung dari meja lewat QR.

Tiga aplikasi:

| Aplikasi | Teknologi | Pengguna | Status |
|---|---|---|---|
| `backend/` REST API `/api/v1` | Express 5, TypeScript, MySQL/TiDB, Zod | semua klien | F00–F26 selesai, 80+ berkas uji Vitest, deploy Heroku |
| `frontend/` web dashboard | Next.js 16 App Router, React 19, Tailwind v4 | penjual, admin, tamu meja (PWA) | selesai, 804 uji Vitest + 14 skenario Playwright, deploy Vercel (`ketringkita.edufin.app`) |
| `mobile/` aplikasi pembeli | Flutter 3.47, Drift SQLite, Provider | pembeli | **prototipe UI, belum terhubung ke API** (data lokal dan contoh statis) |

## 2. Masalah yang diselesaikan

1. Penjual katering kampus menerima pesanan lewat chat WhatsApp secara manual, sehingga porsi sering kelebihan pesan dan tidak ada rekap penjualan.
2. Pembeli tidak tahu menu mana yang masih tersedia hari ini dan di mana mengambilnya.
3. Pembayaran non-tunai tersebar di QRIS pribadi tiap penjual tanpa bukti yang bisa diverifikasi platform.
4. Pengelola platform perlu memverifikasi penjual, memoderasi konten, dan merekap keuangan.

## 3. Pengguna dan peran

| Peran | Nilai `users.role` | Klien | Hak utama |
|---|---|---|---|
| Pembeli | `customer` | mobile (direncanakan) | katalog, favorit, checkout, bayar, pantau pesanan, ulasan, rekomendasi AI |
| Penjual | `merchant` | web ≥ 768 px | profil toko, menu & kuota, proses pesanan, laporan, promo, meja QR, rekening pencairan, asisten AI |
| Admin super | `admin` + `admin_level = super` | web | semua fitur admin |
| Admin operasional | `admin_level = ops` | web | verifikasi, penjual, moderasi, data master, promo, pengumuman; tanpa kelola admin, AI, keuangan, pencairan, server, tulis setelan |
| Admin support | `admin_level = support` | web | hanya baca (GET) di luar area super |
| Tamu meja | tanpa akun | web PWA `/meja/[token]` | lihat menu toko, pesan, bayar Snap, pantau status dengan token tamu |
| Sistem | — | job internal, webhook | kedaluwarsa pesanan (tiap 30 detik), notifikasi Midtrans, pembersihan log |

Toko hanya tampil di katalog dan bisa menerima pesanan setelah `verification_status = verified`. Admin dengan `must_change_password` wajib ganti sandi (`PUT /me/password`) sebelum memakai rute admin lain (403 `PASSWORD_CHANGE_REQUIRED`).

## 4. Lingkup fitur

Kolom status: **BE** backend, **Web** dashboard Next.js, **Mob** aplikasi Flutter. ✅ selesai, 🟡 UI ada tapi data lokal/statis, ❌ tidak ada.

### 4.1 Akun (F01, F02, F11)

| Fitur | Aturan | Endpoint | BE | Web | Mob |
|---|---|---|---|---|---|
| Daftar pembeli | nama ≤150, email valid, HP `08` + 8–11 digit, sandi 8–72 karakter berisi huruf dan angka | `POST /auth/customer/register` | ✅ | — | 🟡 simpan ke SQLite lokal |
| Daftar penjual | + nama usaha, `merchant_type_id`, alamat; email opsional; toko lahir `pending` | `POST /auth/merchant/register` | ✅ | ✅ `/register` | — |
| Masuk | identifier email atau HP + `client` (`web` TTL 1 hari, `mobile` 30 hari); sesi dicatat di `auth_sessions` | `POST /auth/login` | ✅ | ✅ `/login`, JWT di cookie httpOnly `kk_session` | 🟡 token simulasi lokal |
| Keluar | `revoked_at` diisi | `POST /auth/logout` | ✅ | ✅ | 🟡 |
| Profil, ganti sandi, avatar | `PATCH /me` butuh `current_password` untuk ubah email/HP; avatar lewat URL unggah R2 | `GET/PATCH /me`, `PUT /me/password`, `POST /me/avatar` | ✅ | ✅ | 🟡 profil lokal |
| Lupa sandi OTP email | OTP 6 digit, berlaku 10 menit, maks 5 percobaan, sekali pakai; respons permintaan selalu sama agar email tidak bocor | `POST /auth/password/{forgot,verify,reset}` | ✅ | ✅ `/lupa-sandi` | 🟡 layar ada, OTP tidak dikirim |

### 4.2 Toko penjual (F03)

| Fitur | Aturan | Endpoint | BE | Web |
|---|---|---|---|---|
| Profil toko | nama, deskripsi ≤500, alamat, nomor WA, `service_mode` daily/event/both, jam buka–tutup `JJ:MM`, `hold_minutes` 1–30, target omzet harian, logo, minimal 1 titik temu (maks 50) | `GET/PATCH /merchant/profile` | ✅ | ✅ `/pengaturan` |
| Status dapur buka/tutup | `is_open` | `PATCH /merchant/status` | ✅ | ✅ sakelar di shell |
| Templat WhatsApp | ≤1.000 karakter; placeholder `{kode} {nama} {menu} {total} {titik_temu} {waktu_ambil} {metode_bayar}` saja | bagian `PATCH /merchant/profile` | ✅ | ✅ `/template-wa` |
| Rekening pencairan | bank/e-wallet dari daftar `BANK_PENCAIRAN` (15 pilihan), nomor 6–20 digit, nama 3–100, wajib kata sandi | `PUT /merchant/payout-account`, `GET /merchant/payouts` | ✅ | ✅ `/pengaturan` |
| Unggah foto | URL PUT bertanda tangan R2, berlaku 300 detik; browser memperkecil ke WebP ≤1600 px | `POST /merchant/uploads` | ✅ (503 bila R2 kosong) | ✅ |

### 4.3 Menu dan kuota (F04)

| Fitur | Aturan | Endpoint | BE | Web |
|---|---|---|---|---|
| CRUD menu | nama ≤80, kategori, harga 1.000–100 jt dan > HPP, HPP ≥ 0, kuota harian 0–10.000, estimasi siap 1–1440 menit, pre-order + hari, minimum pesan 1–1000, maks 20 opsi (nama unik, tambahan 0–1 jt); hapus = soft delete | `GET/POST /merchant/menus`, `GET/PATCH/DELETE /merchant/menus/:id` | ✅ | ✅ `/menu`, `/menu/baru`, `/menu/[id]` |
| Kuota hari ini | tepat satu dari `delta` (±1–10.000, bukan 0) atau `quota_today` absolut; `quota_today ≥ sold_today + held_today`; penghitung harian direset saat tanggal WIB berganti | `PATCH /merchant/menus/:id/quota` | ✅ | ✅ hook `useKuota` (antrean request, debounce 600 ms, rollback) |
| Filter daftar menu | `status` active/low/sold_out/inactive, `q`, `category` | `GET /merchant/menus` | ✅ | ✅ |
| Menu diturunkan admin | `moderated_at` terisi: nonaktif dan tidak bisa diaktifkan penjual sampai dipulihkan | — | ✅ | ✅ tampil alasan |

### 4.4 Katalog publik dan favorit (F05)

| Fitur | Aturan | Endpoint | BE | Mob |
|---|---|---|---|---|
| Daftar menu | hanya toko `verified`, menu aktif tidak dihapus/diturunkan; filter `q` ≤100, `category` slug, `merchant` slug, `pickup_point_id`; `sort` popular/rating/price_asc/price_desc/newest; `limit` ≤100; **tanpa `hpp`** | `GET /menus` | ✅ | 🟡 `home_screen`, `search_screen` dari `mockProducts` |
| Detail menu + ulasan | ulasan tersembunyi tidak ikut | `GET /menus/:id`, `GET /menus/:id/reviews` | ✅ | 🟡 `product_detail_screen` |
| Profil toko | | `GET /merchants/:slug` | ✅ | 🟡 `store_profile_screen` |
| Favorit | pembeli saja | `GET /me/favorites`, `PUT/DELETE /me/favorites/:menuId` | ✅ | 🟡 `liked_screen`, SharedPreferences |
| Data referensi | jenis usaha, kategori, titik temu, setelan publik (`service_fee`, kontak CS) | `GET /meta/*` | ✅ | ❌ |

### 4.5 Checkout dan pesanan pembeli (F06, F07, F12, F14)

| Fitur | Aturan | Endpoint | BE | Mob |
|---|---|---|---|---|
| Hitung harga | 1–20 item, qty 1–1000, maks 10 opsi per item, `pickup_point_id` wajib, catatan ≤255, kode promo ≤30, `pickup_at` ISO untuk pre-order; harga, diskon, biaya layanan, total dihitung server | `POST /orders/quote` | ✅ | 🟡 `checkout_screen` hitung lokal |
| Buat pesanan | + `payment_method` cod/va/online; header `Idempotency-Key` UUID wajib (request sama → pesanan sama); porsi dikunci di `held_today`; status `holding`, `hold_until` = sekarang + `hold_minutes` toko; dua checkout bersamaan untuk sisa 1 porsi hanya menghasilkan satu pesanan; kode `KK-YYYYMMDD-XXXX` | `POST /orders` | ✅ | 🟡 simpan ke SQLite lokal |
| Daftar & detail pesanan | tab active/completed/cancelled, `q` ≤50, `updated_since`, halaman ≤100; detail berisi `seconds_left`, `payment` | `GET /me/orders`, `GET /orders/:code` | ✅ | 🟡 `orders_screen`, `active_orders_screen`, `completed_orders_screen` dari `mockOrders` |
| Pesan WhatsApp ke penjual | teks dari templat toko | `GET /orders/:code/whatsapp` | ✅ | 🟡 `whatsapp_generator_screen` lokal |
| Batalkan | `holding` apa pun; `confirmed` hanya tunai; alasan ≤255 | `POST /orders/:code/cancel` | ✅ | ❌ |
| Selesaikan | dari `ready` | `POST /orders/:code/complete` | ✅ | ❌ |
| Pesan lagi | isi ulang keranjang dari pesanan lama | `POST /orders/:code/reorder` | ✅ | ❌ |
| Promo | promo platform (semua toko) atau promo toko; dicek aktif, periode, kuota (atomik), minimal belanja, batas per pembeli; kuota kembali saat batal/kedaluwarsa | bagian quote/order | ✅ | ❌ |

### 4.6 Pembayaran (F10, F26)

| Metode | Alur | Siapa yang menerima pesanan |
|---|---|---|
| `cod` | bayar tunai saat ambil; `payment_status` jadi `paid` saat `completed` | penjual menekan Konfirmasi |
| `va` | `POST /orders/:code/va` `{bank: bca|bni|bri}` → nomor VA; satu VA per pesanan; masa berlaku ≤ `hold_until` | otomatis saat Midtrans `settlement` |
| `online` | `POST /orders/:code/online` → `payment.payment_url` halaman Snap (QRIS, GoPay, ShopeePay, VA); idempoten; `kembali` opsional harus berasal dari `CORS_ORIGIN` | otomatis saat `settlement` |

- Webhook `POST /payments/midtrans` memverifikasi signature SHA512, menandai `paid`, lalu `pay` → `confirmed`. Pembeli mendapat notifikasi.
- Tanpa `MIDTRANS_SERVER_KEY` checkout VA/online ditolak 409; hanya tunai jalan.
- Sisa waktu tahan < 1 menit → VA/Snap ditolak 409 `Batas waktu pesanan sudah habis.`
- Pembayaran lunas pada pesanan `cancelled`/`expired` tetap `paid`, masuk daftar refund admin; setelah admin menandai, `payment_status = refunded`.
- QRIS statis toko dengan verifikasi manual **dihapus** (F26). `qris` hanya data lama.
- Mobile: `payment_screen` menampilkan QRIS, GoPay/OVO/ShopeePay, VA, COD sebagai pilihan statis; belum memanggil endpoint mana pun. Kontrak lengkap: `backend/docs/pembayaran.md`.

### 4.7 Proses pesanan penjual (F07, F08)

| Fitur | Aturan | Endpoint | BE | Web |
|---|---|---|---|---|
| Antrean pesanan | filter status/`q`/`updated_since`; dashboard polling tiap 5 detik (30 detik bila tab tidak aktif) lewat `/api/dashboard/sinkron` | `GET /merchant/orders`, `GET /merchant/orders/:code` | ✅ | ✅ `/dashboard`, `/pesanan`, `/pesanan/[code]` |
| Aksi status | confirm (holding→confirmed; VA/online harus lunas), cook, ready, complete, reject (holding/confirmed, wajib alasan); transisi tak sah 409; setiap perubahan ke `order_status_logs` + notifikasi pembeli | `POST /merchant/orders/:code/{confirm,cook,ready,complete,reject}` | ✅ | ✅ dengan jendela undo 5 detik |
| Pesan WhatsApp ke pembeli | | `GET /merchant/orders/:code/whatsapp` | ✅ | ✅ `/api/pesanan/[code]/wa` |
| Kedaluwarsa otomatis | job dalam proses tiap 30 detik: `holding` lewat `hold_until` → `expired`, porsi dan kuota promo kembali, pembeli diberi notifikasi | — | ✅ | — |

### 4.8 Laporan, promo, ulasan toko (F09, F12, F13)

| Fitur | Endpoint | BE | Web |
|---|---|---|---|
| Ringkasan omzet, pesanan selesai, menu terlaris; sebaran per jam; daftar transaksi; ekspor CSV UTF-8 BOM | `GET /merchant/reports/{summary,hourly,transactions}` | ✅ | ✅ `/laporan`, `/api/laporan/csv` |
| Promo toko (kode, tipe percent/fixed/free_service_fee, nilai, maks diskon, min belanja, kuota, batas per pembeli, periode); saat diaktifkan, pembeli yang memfavoritkan menu toko diberi notifikasi `promo` | `GET/POST /merchant/promos`, `PATCH/DELETE /merchant/promos/:id` | ✅ | ✅ `/promo` |
| Ulasan masuk | `GET /merchant/reviews` | ✅ | ✅ `/ulasan` |
| Ulasan pembeli: satu per menu per pesanan `completed`, rating 1–5, komentar ≤500; rating menu dan toko dihitung ulang | `POST /orders/:code/reviews` | ✅ | — (mobile ❌) |

### 4.9 Pesan dari meja (F21)

| Fitur | Aturan | Endpoint | BE | Web |
|---|---|---|---|---|
| Kelola meja | `dine_in_enabled` di profil; label 1–30 unik per toko; token QR 32 karakter bisa diganti (`ganti_token: true`) | `GET/POST /merchant/tables`, `PATCH /merchant/tables/:id` | ✅ | ✅ `/pengaturan`, cetak `/cetak-qr` (A4) |
| Menu meja tanpa login | hanya menu non-pre-order; maks 5 pesanan menunggu per meja; nama 1–60, HP opsional | `GET /tables/:token`, `POST /tables/:token/orders` | ✅ | ✅ PWA `/meja/[token]` (dirancang untuk HP) |
| Bayar & status | selalu `online` (Snap); header `X-Guest-Token`; `kembali` wajib dan harus origin web | `POST /guest/orders/:code/pay`, `GET /guest/orders/:code` | ✅ | ✅ `/meja/pesanan/[code]` |

### 4.10 Notifikasi dan pengumuman

| Fitur | Endpoint | BE | Web | Mob |
|---|---|---|---|---|
| Notifikasi in-app: `order_status` (perubahan status oleh penjual/sistem), `promo`, `info` (pengumuman admin); tandai dibaca | `GET /me/notifications`, `POST /me/notifications/read` | ✅ | ✅ hook `useNotifikasi` | 🟡 `notification_screen` statis |
| Broadcast admin ke pembeli/penjual/semua | `POST /admin/broadcasts` | ✅ | ✅ `/admin/pengumuman` | — |
| Kontak CS (nomor WA) | `PUT /admin/settings/cs-contact`, tampil di `GET /meta/settings` | ✅ | ✅ | ❌ |

### 4.11 AI (F17, F22, F24, F25)

| Fitur | Aturan | Endpoint | BE | Web | Mob |
|---|---|---|---|---|---|
| AI gateway | penyedia gemini/groq/openrouter/nvidia diatur admin; dicoba urut `priority`; 429/kunci ditolak/timeout → `cooldown_until`, lanjut ke berikutnya; `GEMINI_API_KEY` env cadangan terakhir; key terenkripsi AES-256-GCM, hanya `key_hint` keluar | `GET/POST /admin/ai-providers`, `PATCH/DELETE /admin/ai-providers/:id`, `POST /admin/ai-providers/:id/test` | ✅ | ✅ `/admin/ai` | — |
| Asisten AI toko | pertanyaan penjual dengan konteks data toko; 10 permintaan / 10 menit per pengguna | `POST /merchant/assistant` | ✅ | ✅ `/copilot` (+ kalkulator HPP) | — |
| Rekomendasi AI pembeli (RAG) | `question` 3–500 karakter, `budget` 1.000–100 jt, `portions` 1–1000, filter kategori/toko/titik temu; kandidat ≤40 menu tersedia saat itu; jawaban AI divalidasi ulang (id, qty, stok, anggaran, harga dari DB); tanpa AI → `source: "fallback"` tetap 200 | `POST /assistant/recommendations` | ✅ | — | 🟡 `ai_assistant_screen` memanggil Gemini langsung dari HP dengan basis pengetahuan statis |
| Pemakaian AI | token, panggilan, gagal, latensi per penyedia/fitur/hari; simpan 90 hari | `GET /admin/ai-usage?days=1..90` | ✅ | ✅ `/admin/ai` | — |

Kontrak rekomendasi: `backend/docs/rekomendasi-ai.md`.

### 4.12 Admin (F18, F19, F20, F23, F26, kelola admin)

| Fitur | Level | Endpoint | Web |
|---|---|---|---|
| Ringkasan platform | semua | `GET /admin/summary` | `/admin` |
| Antrean verifikasi + checklist (WA valid, alamat, titik temu aktif, menu aktif, menu berfoto, jam buka < tutup); aksi verify, request-fix (alasan), suspend (alasan), reactivate, close-today | ops+ | `GET /admin/verification-queue`, `GET /admin/merchants[/:id]`, `POST /admin/merchants/:id/{verify,request-fix,suspend,reactivate,close-today}` | `/admin/verifikasi`, `/admin/penjual`, `/admin/penjual/[id]` |
| Data master: `merchant_types`, `categories`, `pickup_points` (buat, ubah, aktif/nonaktif) | ops+ | `GET/POST /admin/master/:kind`, `PATCH /admin/master/:kind/:id`, `POST .../{activate,deactivate}` | `/admin/data-master` |
| Promo platform | ops+ | `GET/POST /admin/promos`, `PATCH /admin/promos/:id`, `POST .../{activate,deactivate}` | `/admin/promo` |
| Setelan: biaya layanan, kontak CS | baca semua, tulis super | `GET /admin/settings`, `PUT /admin/settings/{service-fee,cs-contact}` | `/admin/promo` |
| Moderasi: sembunyikan/tampilkan ulasan (alasan), turunkan/pulihkan menu (alasan) | ops+ | `GET /admin/reviews`, `POST /admin/reviews/:id/{hide,unhide}`, `GET /admin/menus`, `POST /admin/menus/:id/{takedown,restore}` | `/admin/moderasi` |
| Rekap keuangan per toko: omzet, diskon toko/platform, biaya layanan; CSV | super | `GET /admin/finance` | `/admin/keuangan`, `/api/admin/keuangan/csv` |
| Pencairan: saldo per toko (`as_of`), catat transfer (`amount` harus sama dengan saldo sampai `until`, catatan ganda/saldo berubah → 409), riwayat; daftar refund dan tandai dengan referensi | super | `GET /admin/payouts/balances`, `GET/POST /admin/payouts`, `GET /admin/refunds`, `POST /admin/refunds/:code` | `/admin/pencairan` |
| Log audit admin | semua | `GET /admin/audit-logs` | `/admin/log` |
| Status server, log error 5xx dan request lambat > 2 detik (30 hari) | super | `GET /admin/server-status`, `GET /admin/server-logs?level=&q=&page=&limit=` | `/admin/server` |
| Kelola akun admin: buat (sandi sementara → `must_change_password`), ubah level, aktif/nonaktif, reset sandi | super | `GET/POST /admin/admins`, `PATCH /admin/admins/:id/level`, `POST /admin/admins/:id/{activate,deactivate,reset-password}` | `/admin/admin` |
| Akun admin sendiri (ganti sandi) | semua | `PUT /me/password` | `/admin/akun` |

Rute admin tak dikenal: tanpa token 401, bukan admin 403, admin 404.

## 5. Alur utama

### 5.1 Onboarding penjual
1. Daftar di `/register` → akun `merchant` + toko `pending`.
2. Lengkapi profil, titik temu, minimal satu menu aktif berfoto.
3. Admin memeriksa checklist di `/admin/verifikasi`; `verify` atau `request-fix` dengan catatan.
4. Setelah `verified`, toko tampil di `GET /menus` dan bisa menerima pesanan. Admin dapat `suspend` kapan saja; `reactivate` mengembalikan ke `verified`.

### 5.2 Checkout pembeli
1. `POST /orders/quote` menampilkan rincian harga, diskon promo, biaya layanan.
2. `POST /orders` dengan `Idempotency-Key`: porsi dikunci, status `holding`, `hold_until` berjalan.
3. Tunai: penjual Konfirmasi sebelum `hold_until`. VA/online: pembeli membayar, webhook Midtrans mengonfirmasi otomatis. Tidak dibayar/dikonfirmasi tepat waktu → `expired`.
4. Penjual: `cook` → `ready`. Pembeli atau penjual: `complete`.
5. Pembeli memberi ulasan per menu dari pesanan `completed`.

### 5.3 Pesan dari meja
1. Penjual menyalakan `dine_in_enabled`, membuat meja, mencetak QR dari `/cetak-qr`.
2. Tamu memindai → `/meja/[token]`: menu non-pre-order toko, keranjang lokal, nama + catatan.
3. `POST /tables/:token/orders` → token tamu disimpan peramban → `POST /guest/orders/:code/pay` membuka Snap.
4. Webhook `settlement` mengonfirmasi; tamu memantau `/meja/pesanan/[code]`.

### 5.4 Uang ke penjual (non-tunai)
1. Dana VA/online masuk akun Midtrans platform.
2. Bagian penjual per pesanan `completed` = `subtotal` − diskon promo toko. Biaya layanan, promo platform, dan fee Midtrans ditanggung platform. Tunai tidak ikut.
3. Penjual mengisi rekening di `/pengaturan` (wajib kata sandi).
4. Admin super melihat saldo (`as_of`) di `/admin/pencairan`, mentransfer lewat bank, lalu mencatat dengan `amount` + `until` + referensi. Pesanan yang tercatat diberi `payout_id`.
5. Pembayaran lunas pada pesanan batal masuk daftar refund; admin mengembalikan di luar aplikasi lalu menandainya.

## 6. Kebutuhan non-fungsional

| Area | Ketentuan yang diimplementasikan |
|---|---|
| Autentikasi | JWT dengan `jti` di `auth_sessions` (bisa dicabut); web menyimpan token di cookie httpOnly `kk_session`, JavaScript peramban tidak pernah melihat JWT; `proxy.ts` mengarahkan ke `/login?next=` bila cookie tidak ada |
| Kata sandi | bcrypt; aturan 8–72 karakter, huruf + angka |
| Pembatas laju (in-memory, per proses) | login: 5/menit per IP+identifier dan 10/15 menit per akun, hanya percobaan gagal dihitung; ganti sandi/profil: 5/menit per pengguna; unggah: 20/10 menit; OTP: 5/15 menit per email dan 30/15 menit per IP; AI: 10/10 menit per pengguna; pesan meja: 15/10 menit |
| Integritas transaksi | kuota, promo, idempotensi, dan transisi status dalam transaksi DB dengan urutan kunci tetap (users → orders → promos → menus); checkout paralel diuji (`test/checkout-paralel.test.ts`) |
| Kerahasiaan data | `hpp` tidak pernah keluar ke katalog publik; API key AI terenkripsi, hanya 4 karakter terakhir tampil; `server_logs` tanpa body/header/token |
| Validasi | semua body/query lewat Zod; field asing dibuang (anti mass-assignment); pesan galat bahasa Indonesia, format `{ error: { code, message, fields? } }` |
| Observabilitas | `X-Request-Id` dari Next diteruskan ke backend; `server_logs` 30 hari; `ai_usage` 90 hari; `admin_audit_logs` permanen; health check `GET /health` berisi status DB |
| Kinerja | polling pesanan hanya `updated_since`; request > 2 detik dicatat sebagai `slow`; paginasi maks 100 |
| Ketersediaan fitur opsional | R2 kosong → unggah 503; SMTP kosong → OTP ke log (dev) / 503 (production); Midtrans kosong → VA/online 409; tanpa penyedia AI → asisten 503, rekomendasi fallback 200 |
| Perangkat | dashboard penjual/admin hanya ≥ 768 px (layar "Buka di tablet atau komputer"); `/meja` untuk HP; mobile Flutter Android (Java 17, AGP 9.1, Kotlin 2.4) |
| Deploy | backend Heroku app `ketring`, migrasi otomatis di fase `release`; DB TiDB Cloud cluster `pbl-ketring`; web Vercel + domain `ketringkita.edufin.app`; `CORS_ORIGIN` wajib di production |
| Uji | backend Vitest + Supertest terhadap MySQL nyata (`TEST_DATABASE_URL` berakhiran `_test`); frontend Vitest 804 uji + Playwright 14 skenario; mobile tidak ada uji |

## 7. Integrasi eksternal

| Layanan | Dipakai untuk | Konfigurasi |
|---|---|---|
| Midtrans (Core API VA + Snap) | VA BCA/BNI/BRI, halaman Snap, webhook `POST /payments/midtrans` | `MIDTRANS_SERVER_KEY`, `MIDTRANS_IS_PRODUCTION` (bawaan sandbox) |
| Cloudflare R2 | foto menu, logo, avatar lewat URL PUT bertanda tangan (AWS SigV4 tanpa SDK) | `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_PUBLIC_URL`, CORS bucket untuk origin web |
| SMTP | OTP lupa sandi | `SMTP_HOST/PORT/USER/PASS/FROM` |
| Gemini, Groq, OpenRouter, NVIDIA NIM | AI gateway | tabel `ai_providers` (admin) + `GEMINI_API_KEY` cadangan |
| WhatsApp (`wa.me`) | tautan pesan dari templat, bukan API resmi | `merchants.wa_number`, `app_settings.cs_whatsapp` |
| OpenStreetMap + Nominatim | pemilih lokasi di mobile (`map_service.dart`) | tanpa kunci; belum ada padanan di backend |

## 8. Metrik yang sudah diukur sistem

- Penjual: omzet kotor, pesanan selesai, menu terlaris, sebaran per jam, target omzet harian (`/laporan`, `/dashboard`).
- Admin: ringkasan platform (`/admin/summary`: toko buka, antrean verifikasi, dsb.), rekap keuangan per toko, saldo pencairan, pemakaian AI (token, gagal, latensi), error 5xx dan request lambat.
- Belum ada metrik produk lintas-platform (konversi katalog → checkout, tingkat `expired`, retensi pembeli). Ini kandidat untuk ditambah setelah mobile terhubung.

## 9. Kesenjangan dan risiko

### 9.1 Mobile belum terintegrasi (kesenjangan terbesar)
- `auth_repository.dart` menyimpan akun dan sandi di SQLite + secure storage dan membuat token palsu `dev-token-…`. Tidak ada panggilan ke `/auth/*`.
- Produk, vendor, ulasan, pesanan berasal dari `mockProducts`, `mockOrders`, `VendorProfile` statis. Harga `double` (mis. `129.99`) dengan konversi "× 1000 bila < 500" di `app_currency.dart`; backend memakai `INT` Rupiah.
- Status pesanan mobile `active/completed/cancelled` versus 7 status backend; kode pesanan mobile `#KK-2026-089` versus `KK-YYYYMMDD-XXXX`.
- Metode bayar mobile (QRIS, GoPay, OVO, ShopeePay, Dana, VA Mandiri, COD) tidak sama dengan backend (`cod`, `va` BCA/BNI/BRI, `online` Snap). Halaman Snap-lah yang menyediakan e-wallet, bukan aplikasi.
- Pemilih lokasi peta (koordinat, riwayat per akun) tidak punya padanan: backend hanya mengenal `pickup_point_id` dari daftar tetap tanpa koordinat. Basis pengetahuan AI mobile menyebut titik yang tidak ada di DB (Perpustakaan Pusat UB, Samantha Krida, Dinoyo) dan "gratis ongkir".
- AI mobile memanggil Gemini langsung dari perangkat dengan kunci `--dart-define`/secure storage dan basis pengetahuan hard-coded berisi HPP vendor. Backend sudah menyediakan `POST /assistant/recommendations` yang menyembunyikan HPP dan memakai stok nyata. Kunci API di aplikasi klien bisa diekstrak.
- Tidak ada layar untuk: batalkan/selesaikan pesanan, pesan lagi, ulasan, kode promo, pilih bank VA, buka Snap, notifikasi dari server.
- Rekomendasi: ganti lapisan data mobile dengan klien HTTP ke `/api/v1` (`client: "mobile"`, TTL 30 hari), pakai kontrak di `backend/docs/pembayaran.md` dan `rekomendasi-ai.md`, hapus Drift `Users` dan `GeminiService`; simpan hanya token di secure storage.

### 9.2 Backend dan web
- Pembatas laju disimpan di memori proses (komentar `shortcut:` di `rateLimiter.ts`). Bila API dijalankan > 1 instance, batas menjadi per instance. Pindah ke tabel/Redis sebelum scale-out.
- Job kedaluwarsa berjalan di dalam proses web (`server.ts`). Dua instance = dua job; transaksi mencegah dobel, tetapi beban DB ganda.
- `docs/API.md` yang dirujuk README backend tidak ada di monorepo ini. Kontrak respons hanya terdokumentasi di `docs/pembayaran.md`, `docs/rekomendasi-ai.md`, kode handler, dan uji.
- Notifikasi promo dikirim setiap kali promo diaktifkan (komentar `shortcut:` di `admin-pengumuman.service.ts`); mati-hidup berulang = notifikasi berulang.
- Checklist verifikasi `opening_hours` hanya mengecek `open_time < close_time`, jadi toko yang buka melewati tengah malam dianggap gagal.
- Produksi TiDB: README menyatakan migrasi 001–004 sudah diterapkan; 005–010 bergantung pada fase `release` Heroku. Perlu dicek `schema_migrations` di production.
- Vercel deploy frontend tercatat gagal sebelum push terakhir (lihat memori sesi); penyebab belum diketahui.
- `orders.payout_id` tanpa FK; konsistensi pencairan bergantung aplikasi (lihat `docs/erd.md` §4).

### 9.3 Repositori
- `frontend/README.md` menyatakan `services/merchantService.ts` dan `adminService.ts`; berkas nyata adalah `menuService.ts`, `orderService.ts`, `adminMerchantService.ts`, dll. Dokumentasi tertinggal dari kode.
- `D:\PBL\CLAUDE.md` di root monorepo belum dilacak git dan bukan bagian repo asal mana pun.

## 10. Di luar lingkup saat ini

Tidak ada di kode: pengantaran/ongkir, chat dalam aplikasi, push notification (FCM), multi-toko per akun, pembayaran langsung ke rekening penjual (split payment Midtrans), refund otomatis lewat API Midtrans, iOS build yang diuji, aplikasi penjual di mobile.
