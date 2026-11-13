// Alat lokal: kirim notifikasi "settlement" Midtrans palsu ber-signature ke backend
// lokal, karena webhook sandbox tidak bisa mencapai localhost. Jangan dipakai
// ke production — di sana webhook asli yang mengubah status.
//
// pakai: node tools/midtrans-settle.mjs <KODE_PESANAN> <TOTAL> [baseUrl]
// contoh: node tools/midtrans-settle.mjs KK-7F3A2B 30000
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

const [code, total, base = "http://localhost:5000/api/v1"] = process.argv.slice(2);
if (!code || !total) {
  console.error("pakai: node tools/midtrans-settle.mjs <KODE_PESANAN> <TOTAL> [baseUrl]");
  process.exit(1);
}
if (!/^https?:\/\/(localhost|127\.0\.0\.1|10\.0\.2\.2)[:/]/.test(base)) {
  console.error("Hanya untuk backend lokal. baseUrl ditolak.");
  process.exit(1);
}

const dotenv = readFileSync(new URL("../backend/.env", import.meta.url), "utf8");
const key = dotenv.match(/^MIDTRANS_SERVER_KEY=\s*["']?([^"'\r\n]+)/m)?.[1]?.trim();
if (!key) {
  console.error("MIDTRANS_SERVER_KEY kosong di backend/.env");
  process.exit(1);
}

// signature sama dengan Midtrans: SHA512(order_id + status_code + gross_amount + server key)
const n = {
  order_id: code,
  status_code: "200",
  gross_amount: Number(total).toFixed(2),
  transaction_status: "settlement",
  payment_type: "bank_transfer",
  transaction_id: `lokal-${Date.now()}`,
};
n.signature_key = createHash("sha512")
  .update(`${n.order_id}${n.status_code}${n.gross_amount}${key}`)
  .digest("hex");

const r = await fetch(`${base}/payments/midtrans`, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify(n),
});
console.log(r.status, await r.text());
