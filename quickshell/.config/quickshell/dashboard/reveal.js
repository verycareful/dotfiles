// The dashboard's entrance: `reveal` runs 0 -> 1 over TOTAL_MS (and back, faster, on close). Block i starts
// STAGGER_MS after block i - 1, rises RISE px and fades in over EACH_MS, eased out (cubic).
.pragma library

var EACH_MS = 320
var STAGGER_MS = 40
var BLOCKS = 5
var TOTAL_MS = EACH_MS + (BLOCKS - 1) * STAGGER_MS
var RISE = 24

// 0..1 progress of block i at overall progress `reveal`
function stage(reveal, i) {
    var t = Math.max(0, Math.min(1, (reveal * TOTAL_MS - i * STAGGER_MS) / EACH_MS))
    return 1 - Math.pow(1 - t, 3)
}
function offset(reveal, i) { return (1 - stage(reveal, i)) * RISE }
