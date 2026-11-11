// Susun ulang frame hi-fi yang sudah ada di page 03 (tanpa impor ulang): baris mengalir, maksimal 4 layar desktop per baris.
// Data (id label, id frame, lebar, tinggi) diambil dari get_node section pada 2026-11-12; urutan = urutan fitur.
// Jalankan: node relayout-hifi.mjs > relayout.json ; kirim ke FigCraft batch.
const GAP_X = 120, GAP_ROW = 160, PAD = 120, GAP_SEC = 320, LABEL = 56, MAX_W = 4 * 1440 + 3 * GAP_X;
const SEKSI = [
  { id: 1238, layar: [[1239, 1240, 1440, 6381], [2249, 2250, 1440, 900], [2405, 2406, 1440, 900], [2581, 2582, 1440, 900], [2756, 2757, 1440, 934], [2990, 2991, 1440, 1226], [3301, 3302, 1440, 900], [3425, 3426, 1440, 900], [3604, 3605, 1440, 900]] },
  { id: 3702, layar: [[3703, 3704, 1440, 1065], [4772, 4773, 646, 1637], [5618, 5619, 1440, 1255], [6773, 6774, 1440, 1255], [7926, 7927, 1440, 1776], [8633, 8634, 1440, 2120], [9435, 9436, 1440, 1817], [10151, 10152, 1440, 900], [11225, 11226, 1440, 900], [11733, 11734, 1440, 900], [12329, 12330, 1440, 911], [12983, 12984, 1440, 955], [13651, 13652, 1440, 900], [14288, 14289, 1440, 900], [14909, 14910, 1440, 900], [15525, 15526, 1440, 900], [15978, 15979, 1440, 1222], [16721, 16722, 1440, 900], [17273, 17274, 1440, 900], [18053, 18054, 1440, 3808], [19139, 19140, 1440, 984], [19685, 19686, 1440, 944], [20257, 20258, 1440, 966], [20774, 20775, 1440, 900], [20948, 20949, 1440, 900], [21701, 21702, 1440, 3620], [22673, 22674, 1440, 900], [23427, 23428, 1440, 3620]] },
  { id: 24400, layar: [[25338, 25339, 1440, 1186], [26178, 26179, 1440, 900], [26938, 26939, 1440, 900], [27658, 27659, 1440, 1216], [28337, 28338, 1440, 900], [28942, 28943, 1440, 900], [29874, 29875, 1440, 900], [30410, 30411, 1440, 900], [31047, 31048, 1440, 1184], [31563, 31564, 1440, 900], [32040, 32041, 1440, 1032], [32694, 32695, 1440, 900], [33394, 33395, 1440, 900], [34179, 34180, 1440, 900], [24401, 24402, 1440, 900], [24779, 24780, 1440, 900]] },
  { id: 34676, layar: [[34677, 34678, 390, 844], [34779, 34780, 390, 890], [35059, 35060, 390, 890], [35377, 35378, 390, 890], [35781, 35782, 390, 844]] },
];
const steps = [{ command: "page.select", params: { id: 4 } }];
let y = 0;
for (const s of SEKSI) {
  const rows = [];
  for (const m of s.layar) {
    const r = rows[rows.length - 1];
    const lebar = r ? r.reduce((a, x) => a + x[2], 0) + GAP_X * r.length + m[2] : Infinity;
    if (r && lebar <= MAX_W) r.push(m); else rows.push([m]);
  }
  const rowW = rows.map((r) => r.reduce((a, m) => a + m[2], 0) + GAP_X * (r.length - 1));
  const rowH = rows.map((r) => Math.max(...r.map((m) => m[3])));
  const secW = Math.max(...rowW) + PAD * 2;
  const secH = rowH.reduce((a, h) => a + h + LABEL, 0) + GAP_ROW * (rows.length - 1) + PAD * 2;
  steps.push({ command: "node.set", params: { ids: [s.id], x: 0, y, width: secW, height: secH } });
  let ry = PAD;
  rows.forEach((row, i) => {
    let x = PAD;
    for (const [label, frame, w] of row) {
      steps.push({ command: "node.set", params: { ids: [label], x, y: ry } });
      steps.push({ command: "node.set", params: { ids: [frame], x, y: ry + LABEL } });
      x += w + GAP_X;
    }
    ry += rowH[i] + LABEL + GAP_ROW;
  });
  y += secH + GAP_SEC;
}
process.stdout.write(JSON.stringify(steps));
console.error(`${steps.length} langkah, tinggi total ${y}`);
