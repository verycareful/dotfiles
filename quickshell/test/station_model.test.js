// Tests for station/model.js: branch classification, station keys, arm layout and launch routing.
// Run from the repo root: node --test quickshell/test
const test = require("node:test");
const assert = require("node:assert/strict");
const m = require("../.config/quickshell/station/model.js");

const win = (cls, name, address) => ({ cls, name: name || cls, address: address || cls + Math.random() });
const ws = (id, name, ...windows) => ({ id, name, windows });

test("branchOfWorkspace: kitty only is a terminal workspace", () => {
    assert.equal(m.branchOfWorkspace({ name: "1", classes: ["kitty", "kitty"] }), "terminal");
});

test("branchOfWorkspace: kitty with firefox is a mix", () => {
    assert.equal(m.branchOfWorkspace({ name: "2", classes: ["kitty", "firefox"] }), "mix");
});

test("branchOfWorkspace: a pad holding only its own app is a pad", () => {
    assert.equal(m.branchOfWorkspace({ name: "special:spotify", classes: ["Spotify"] }), "pad");
});

test("branchOfWorkspace: a pad that gains a terminal becomes a mix", () => {
    assert.equal(m.branchOfWorkspace({ name: "special:spotify", classes: ["Spotify", "kitty"] }), "mix");
});

test("branchOfWorkspace: the General pad stays a pad whatever it holds", () => {
    assert.equal(m.branchOfWorkspace({ name: "special:general", classes: ["kitty", "firefox"] }), "pad");
});

test("branchOfWorkspace: the tray is hidden, the shots workspace is shots", () => {
    assert.equal(m.branchOfWorkspace({ name: "special:tray", classes: ["firefox"] }), "hidden");
    assert.equal(m.branchOfWorkspace({ name: "special:shots", classes: ["org.satty.shot"] }), "shot");
});

test("branchOfWorkspace: a normal workspace with no windows is empty", () => {
    assert.equal(m.branchOfWorkspace({ name: "3", classes: [] }), "empty");
});

test("nameKey: Steam skips the fixed S and the terminal prefix T", () => {
    assert.equal(m.nameKey("Steam", new Set(["S"])), "E");
});

test("nameKey: VS Code takes its second word's initial when V is taken", () => {
    assert.equal(m.nameKey("VS Code", new Set(["V"])), "C");
});

test("nameKey: no free letter in the name gives no key", () => {
    assert.equal(m.nameKey("Steam", new Set(["S", "E", "M"])), null);
});

test("KeyBook: terminals take the lowest free T number and keep it", () => {
    const b = new m.KeyBook();
    assert.deepEqual(["a", "b", "c"].map(id => b.assign(id, "terminal", "kitty")), ["T1", "T2", "T3"]);
    b.release("b");
    assert.equal(b.assign("d", "terminal", "kitty"), "T2");
    assert.equal(b.assign("c", "terminal", "kitty"), "T3");
});

test("KeyBook: a pad that turns into a mix frees its letter and takes a number", () => {
    const b = new m.KeyBook();
    assert.equal(b.assign("sp", "pad", "Spotify", "S"), "S");
    assert.equal(b.assign("sp", "mix", "Spotify"), "1");
    assert.equal(b.assign("sp2", "pad", "Spotify", "S"), "S");
});

test("KeyBook: mixes take 1 to 9 then 0, an eleventh gets no key", () => {
    const b = new m.KeyBook();
    const keys = Array.from({ length: 11 }, (_, i) => b.assign("m" + i, "mix", "mix"));
    assert.deepEqual(keys, ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", null]);
});

test("KeyBook: fixed letters are never given to other apps, even when their app is closed", () => {
    const b = new m.KeyBook();
    assert.equal(b.assign("s", "app", "Steam"), "E");
    assert.equal(b.assign("d", "app", "Dolphin"), "O");
});

test("KeyBook: many apps never share a key, and the leftovers get none", () => {
    const b = new m.KeyBook();
    const keys = Array.from({ length: 40 }, (_, i) => b.assign("w" + i, "app", "Abcdefghijklmnopqrstuvwxyz"));
    const given = keys.filter(k => k !== null);
    assert.equal(new Set(given).size, given.length);
    assert.ok(keys.includes(null));
    assert.ok(!given.includes("Q") && !given.includes("T") && !given.includes("A"));
});

test("buildModel: no windows anywhere gives one empty tile on key 1", () => {
    const model = m.buildModel([], new m.KeyBook());
    assert.equal(model.tiles.length, 1);
    assert.equal(model.tiles[0].branch, "empty");
    assert.equal(model.tiles[0].key, "1");
});

test("buildModel: Firefox gets its fixed B, hidden and shot windows are one tile each", () => {
    const model = m.buildModel([
        ws(1, "1", win("firefox", "Firefox")),
        ws(-98, "special:tray", win("io.missioncenter.MissionCenter", "Mission Center", "h1"), win("obsidian", "Obsidian", "h2")),
        ws(-97, "special:shots", win("org.satty.shot", "satty", "s1"), win("org.satty.shot", "satty", "s2")),
    ], new m.KeyBook());
    const byBranch = b => model.tiles.filter(t => t.branch === b).map(t => t.key);
    assert.deepEqual(byBranch("app"), ["B"]);
    assert.deepEqual(byBranch("hidden"), ["M", "O"]);
    assert.deepEqual(byBranch("shot"), ["A1", "A2"]);
});

test("layoutArms: the first terminal sits right of the hub, the fifth on a side arm", () => {
    const tiles = [1, 2, 3, 4, 5].map(n => ({ id: "t" + n, branch: "terminal", key: "T" + n }));
    const pos = Object.fromEntries(m.layoutArms(tiles).map(p => [p.id, [p.col, p.row]]));
    assert.deepEqual(pos.t1, [1, 0]);
    assert.deepEqual(pos.t4, [4, 0]);
    assert.deepEqual(pos.t5, [2, -1]);
});

test("layoutArms: no two tiles share a cell and none sits on the hub", () => {
    const branches = ["terminal", "pad", "app", "mix", "hidden", "shot"];
    const tiles = [];
    branches.forEach(b => { for (let i = 0; i < 9; i++) tiles.push({ id: b + i, branch: b, key: null }); });
    const cells = m.layoutArms(tiles).map(p => p.col + "," + p.row);
    assert.equal(new Set(cells).size, cells.length);
    assert.ok(!cells.includes("0,0"));
});

test("resolveLaunch: a launch recorded for an ancestor pid wins", () => {
    const launches = [{ pid: 500, ws: "3" }];
    assert.equal(m.resolveLaunch([900, 700, 500, 1], launches, new Map(), "steam"), "3");
});

test("resolveLaunch: with no recorded ancestor, the app's class decides", () => {
    const classWs = new Map([["steam", "4"]]);
    assert.equal(m.resolveLaunch([901, 1], [{ pid: 500, ws: "3" }], classWs, "steam"), "4");
    assert.equal(m.resolveLaunch([902, 1], [], classWs, "firefox"), null);
});
