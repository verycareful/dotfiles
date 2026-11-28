// Station model: which branch a workspace belongs to, which key it gets, where its tile sits, and where a newly
// opened window belongs. Plain functions over plain data, so QML imports this file and node unit-tests it
// (quickshell/test/station_model.test.js). KeyBook is the only state; the Station service owns one instance.

// Window classes per branch. Pads live in their own special workspaces, named by the keys of PADS.
const TERMINALS = ["kitty"];
const SHOTS = ["org.satty.shot"];
const SHOT_NAME = "Screenshot";      // satty has no desktop entry to name its tiles
const PADS = {
    kern:    { cls: "io.github.verycareful.kern", key: "K" },
    spotify: { cls: "Spotify", key: "S" },
    discord: { cls: "discord", key: "D" },
    signal:  { cls: "signal", key: "Z" },
    general: { cls: null, key: "G" },
};
// Apps with a fixed key outside the pads; the key launches the app when it is not open.
const FIXED_APPS = { firefox: "B" };
const FIXED_LETTERS = Object.values(PADS).map(p => p.key).concat(Object.values(FIXED_APPS));
// Q closes windows; T and A start the terminal and shot keys (T1, A1). None of them is ever a name key.
const NEVER = ["Q", "T", "A"];
const MIX_KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"];

function padOfClass(cls) {
    for (const name in PADS) if (PADS[name].cls === cls) return name;
    return null;
}

function branchOfClass(cls) {
    if (TERMINALS.includes(cls)) return "terminal";
    if (SHOTS.includes(cls)) return "shot";
    if (padOfClass(cls)) return "pad";
    return "app";
}

// ws: { name: Hyprland workspace name, classes: class of every window in it }
function branchOfWorkspace(ws) {
    const name = ws.name || "";
    if (name === "special:tray") return "hidden";
    if (name === "special:shots") return "shot";
    if (name.startsWith("special:")) {
        const pad = PADS[name.slice("special:".length)];
        if (pad) {
            if (pad.cls === null) return "pad";
            return ws.classes.every(c => c === pad.cls) ? "pad" : "mix";
        }
    }
    if (ws.classes.length === 0) return "empty";
    // A pad or a shot brought onto a normal workspace stays a pad or a shot; only alongside other windows does the
    // workspace become a mix.
    const kinds = new Set(ws.classes.map(c => (branchOfClass(c) === "terminal" ? "terminal" : "app:" + c)));
    if (kinds.size > 1) return "mix";
    const only = ws.classes[0];
    if (kinds.has("terminal")) return "terminal";
    if (SHOTS.includes(only)) return "shot";
    return padOfClass(only) ? "pad" : "app";
}

// First letters of the words, then the name's remaining letters in order; the first one not taken wins.
function nameKey(name, taken) {
    const words = String(name).toUpperCase().split(/[^A-Z]+/).filter(w => w.length > 0);
    const candidates = words.map(w => w[0]).concat(words.join("").split(""));
    for (const c of candidates) if (!taken.has(c) && !NEVER.includes(c)) return c;
    return null;
}

function lowestFree(prefix, used) {
    for (let n = 1; ; n++) if (!used.has(prefix + n)) return prefix + n;
}

// Keys stay with a workspace while its branch is unchanged; a branch change frees the key and assigns afresh.
class KeyBook {
    constructor() { this.entries = new Map(); }        // id -> { branch, key }

    used() { return new Set([...this.entries.values()].map(e => e.key).filter(k => k !== null)); }

    keyOf(id) { const e = this.entries.get(id); return e ? e.key : null; }

    release(id) { this.entries.delete(id); }

    assign(id, branch, name, fixedKey) {
        const kept = this.entries.get(id);
        if (kept && kept.branch === branch) return kept.key;
        this.entries.delete(id);
        const used = this.used();
        let key = null;
        if (fixedKey) key = fixedKey;
        else if (branch === "terminal") key = lowestFree("T", used);
        else if (branch === "shot") key = lowestFree("A", used);
        else if (branch === "mix" || branch === "empty") key = MIX_KEYS.find(k => !used.has(k)) || null;
        else key = nameKey(name, new Set([...used, ...FIXED_LETTERS]));
        this.entries.set(id, { branch, key });
        return key;
    }
}

// Arm directions as (col, row) steps from the hub at (0, 0).
const ARMS = {
    terminal: [1, 0], pad: [0, -1], app: [-1, -1], mix: [0, 1], empty: [0, 1], hidden: [-1, 1], shot: [1, 1],
};
const BRANCH_ORDER = ["terminal", "pad", "app", "mix", "empty", "hidden", "shot"];
const TERMINAL_TRUNK = 4;     // terminals beyond this grow side arms
const TERMINAL_UP_ARM = 3;    // tiles on the side arm above trunk tile 2; the rest go below trunk tile 3

function layoutArms(tiles) {
    const taken = new Set(["0,0"]);
    const out = [];
    const place = (id, col, row, from) => { taken.add(col + "," + row); out.push({ id, col, row, from }); };
    const free = (col, row) => !taken.has(col + "," + row);

    // Walks from (col,row) along dir; a blocked cell turns the arm a quarter, else it keeps going straight.
    function walker(col, row, dir) {
        return () => {
            let [dc, dr] = dir;
            if (!free(col + dc, row + dr)) {
                const turns = [[-dr, dc], [dr, -dc]].filter(([a, b]) => free(col + a, row + b));
                if (turns.length > 0) dir = turns[0];
            }
            [dc, dr] = dir;
            while (!free(col + dc, row + dr)) { col += dc; row += dr; }
            col += dc; row += dr;
            return [col, row];
        };
    }

    for (const branch of BRANCH_ORDER) {
        const arm = tiles.filter(t => t.branch === branch);
        if (branch === "terminal") {
            let fallback = null;
            arm.forEach((t, i) => {
                let cell, from;
                const up = i - TERMINAL_TRUNK, down = i - TERMINAL_TRUNK - TERMINAL_UP_ARM;
                if (i < TERMINAL_TRUNK) { cell = [i + 1, 0]; from = i === 0 ? "hub" : arm[i - 1].id; }
                else if (up < TERMINAL_UP_ARM) { cell = [2, -(up + 1)]; from = up === 0 ? arm[1].id : arm[i - 1].id; }
                else { cell = [3, down + 1]; from = down === 0 ? arm[2].id : arm[i - 1].id; }
                if (!free(cell[0], cell[1])) cell = (fallback || (fallback = walker(cell[0], cell[1], [1, 0])))();
                place(t.id, cell[0], cell[1], from);
            });
            continue;
        }
        const step = walker(0, 0, ARMS[branch]);
        arm.forEach((t, i) => { const [c, r] = step(); place(t.id, c, r, i === 0 ? "hub" : arm[i - 1].id); });
    }
    return out;
}

const DIRECTIONS = { right: [1, 0], left: [-1, 0], up: [0, -1], down: [0, 1] };
// Off-axis distance costs this much more than distance along the arrow, so the arrow follows the arm it is on.
const OFF_AXIS_WEIGHT = 2;

// The tile an arrow key moves to from fromId ("hub" is the hub at 0,0), or null when nothing lies that way.
function neighbour(positions, fromId, dir) {
    const all = [{ id: "hub", col: 0, row: 0 }].concat(positions);
    const here = all.find(p => p.id === fromId);
    if (!here) return null;
    const [dx, dy] = DIRECTIONS[dir];
    let best = null, bestScore = Infinity;
    for (const p of all) {
        if (p.id === fromId) continue;
        const ax = p.col - here.col, ay = p.row - here.row;
        const along = ax * dx + ay * dy;
        if (along <= 0) continue;
        const score = along + OFF_AXIS_WEIGHT * Math.abs(ax * dy - ay * dx);
        if (score < bestScore) { best = p.id; bestScore = score; }
    }
    return best;
}

// chain: the new window's pid and its ancestors; launches: pids recorded by station-launch with their workspace;
// classWs: the workspace each app class was last routed to (covers windows an app spawns later, like Steam's).
function resolveLaunch(chain, launches, classWs, cls) {
    for (const pid of chain) {
        const hit = launches.find(l => l.pid === pid);
        if (hit) return hit.ws;
    }
    return classWs.has(cls) ? classWs.get(cls) : null;
}

// The tile holding a station key, or null.
function tileByKey(model, key) {
    return model.tiles.find(t => t.key === key) || null;
}

// routes: class -> { ws, at } recorded when a launch is routed; only those younger than ttlMs still route the
// app's later windows. Returns class -> ws, the shape resolveLaunch takes.
function freshClassWs(routes, now, ttlMs) {
    const out = new Map();
    for (const [cls, r] of routes) if (now - r.at <= ttlMs) out.set(cls, r.ws);
    return out;
}

// workspaces: [{ id, name, windows: [{ address, cls, name }] }]. Hidden and shot windows are one tile each;
// every other workspace is one tile. With no workspace at all, the login workspace shows as an empty Mix 1.
function buildModel(workspaces, book) {
    const tiles = [];
    const seen = new Set();
    for (const ws of workspaces) {
        const classes = ws.windows.map(w => w.cls);
        const branch = branchOfWorkspace({ name: ws.name, classes });
        if (branch === "hidden" || branch === "shot") {
            for (const w of ws.windows) {
                const id = "win:" + w.address;
                seen.add(id);
                const name = branch === "shot" ? SHOT_NAME : w.name;
                tiles.push({ id, branch, wsName: ws.name, name, key: book.assign(id, branch, name), windows: [w] });
            }
            continue;
        }
        const id = "ws:" + ws.id;
        seen.add(id);
        const name = ws.windows.length > 0 ? ws.windows[0].name : "";
        let fixed = null;
        if (branch === "pad") fixed = PADS[padOfClass(classes[0]) || ws.name.slice("special:".length)].key;
        else if (branch === "app" && FIXED_APPS[classes[0]]) fixed = FIXED_APPS[classes[0]];
        tiles.push({ id, branch, wsName: ws.name, name, key: book.assign(id, branch, name, fixed), windows: ws.windows });
    }
    if (tiles.length === 0) {
        const id = "ws:1";
        seen.add(id);
        tiles.push({ id, branch: "empty", wsName: "1", name: "", key: book.assign(id, "empty", ""), windows: [] });
    }
    for (const id of [...book.entries.keys()]) if (!seen.has(id)) book.release(id);
    return { tiles, positions: layoutArms(tiles) };
}

if (typeof module !== "undefined") {
    module.exports = {
        TERMINALS, SHOTS, PADS, FIXED_APPS, padOfClass, branchOfClass, branchOfWorkspace, nameKey, KeyBook, layoutArms,
        resolveLaunch, buildModel, tileByKey, freshClassWs, neighbour,
    };
}
