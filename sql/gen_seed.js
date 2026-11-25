/*
 * frontend-এর data.js আর bd-locations.js থেকে seed SQL বানায়।
 * হাতে ৬৪ জেলা + শত শত উপজেলা + ১২টা রোগের ধাপ লিখতে গেলে ভুল হবেই,
 * তাই আসল ডাটা থেকেই তৈরি করা হচ্ছে।
 *
 * চালানো:  node gen_seed.js <frontend/js ফোল্ডার> <আউটপুট .sql>
 *
 * ফাইলগুলো vm.runInNewContext-এ চালানো হয় — ওই context-এ require,
 * process বা fs নেই, তাই শুধু ডাটা বের হয়, আর কিছু করতে পারে না।
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const [jsDir, outFile] = process.argv.slice(2);
if (!jsDir || !outFile) {
  console.error('ব্যবহার: node gen_seed.js <js ফোল্ডার> <আউটপুট.sql>');
  process.exit(1);
}

const sandbox = { window: {}, console: { log() {}, warn() {}, error() {} } };
const context = vm.createContext(sandbox);

for (const file of ['bd-locations.js', 'data.js']) {
  const code = fs.readFileSync(path.join(jsDir, file), 'utf8');
  vm.runInContext(code, context, { filename: file, timeout: 5000 });
}

// `const X = ...` vm context-এ lexical binding হয়, sandbox object-এর property হয় না।
// তাই একই context-এর ভেতরে একটা expression চালিয়ে মানগুলো বের করতে হয়।
const { BD_LOCATIONS, DISTRICT_CENTERS, SYMPTOMS, DISEASES, FLORA, DEFAULT_FARMERS } =
  vm.runInContext(
    '({ BD_LOCATIONS, DISTRICT_CENTERS, SYMPTOMS, DISEASES, FLORA, DEFAULT_FARMERS })',
    context
  );

// ---- সহায়ক ----
const q = (v) => (v === null || v === undefined ? 'NULL' : `'${String(v).replace(/'/g, "''")}'`);
const n = (v) => (v === null || v === undefined || v === '' ? 'NULL' : Number(v));
const out = [];
const say = (line = '') => out.push(line);

say('-- =====================================================================');
say('-- ১০ — seed ডাটা');
say('-- এই ফাইলটা হাতে লেখা নয় — frontend-এর data.js ও bd-locations.js থেকে');
say('-- scratchpad/gen_seed.js দিয়ে তৈরি। ডাটা বদলালে আবার তৈরি করতে হবে।');
say('--');
say('-- চালান:  .\\db.ps1 -File sql\\10_seed.sql');
say('-- =====================================================================');
say('');
say('SET NAMES utf8mb4;');
say('START TRANSACTION;');
say('');

// ---- মাস ----
const MONTHS_BN = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
say('-- ১. মাস (ফুলের ক্যালেন্ডারের lookup)');
say('INSERT INTO months (month_no, name_bn) VALUES');
say(MONTHS_BN.map((m, i) => `  (${i + 1}, ${q(m)})`).join(',\n'));
say('ON DUPLICATE KEY UPDATE name_bn = VALUES(name_bn);');
say('');

// ---- জেলা ----
const districts = Object.keys(BD_LOCATIONS);
say(`-- ২. জেলা — ${districts.length}টি, স্থানাঙ্ক DISTRICT_CENTERS থেকে`);
say('INSERT INTO districts (name, lat, lng) VALUES');
say(districts.map((d) => {
  const c = (DISTRICT_CENTERS && DISTRICT_CENTERS[d]) || [null, null];
  return `  (${q(d)}, ${n(c[0])}, ${n(c[1])})`;
}).join(',\n'));
say('ON DUPLICATE KEY UPDATE lat = VALUES(lat), lng = VALUES(lng);');
say('');

// ---- উপজেলা ----
const upazilaRows = [];
for (const d of districts) {
  for (const u of BD_LOCATIONS[d]) {
    upazilaRows.push(`  ((SELECT id FROM districts WHERE name = ${q(d)}), ${q(u)})`);
  }
}
say(`-- ৩. উপজেলা — ${upazilaRows.length}টি (জেলার সাথে 1:M)`);
say('INSERT INTO upazilas (district_id, name) VALUES');
say(upazilaRows.join(',\n'));
say('ON DUPLICATE KEY UPDATE name = VALUES(name);');
say('');

// ---- মৌমাছির প্রজাতি ----
say('-- ৪. মৌমাছির প্রকার (bees.html)');
say('INSERT INTO bee_species (name, sci_name, note) VALUES');
say([
  ['Apis mellifera', 'Apis mellifera', 'ইউরোপীয় মধু মৌমাছি — বাংলাদেশে বাণিজ্যিক চাষে সবচেয়ে বেশি ব্যবহৃত'],
  ['Apis cerana', 'Apis cerana indica', 'দেশি মৌমাছি — ছোট বাক্সে পালন করা যায়, রোগ সহনশীল'],
  ['Apis dorsata', 'Apis dorsata', 'বড় মৌমাছি — সুন্দরবনের প্রাকৃতিক চাক, পালন করা যায় না'],
  ['Apis florea', 'Apis florea', 'ক্ষুদে মৌমাছি — ছোট চাক, মধু কম'],
].map((s) => `  (${q(s[0])}, ${q(s[1])}, ${q(s[2])})`).join(',\n'));
say('ON DUPLICATE KEY UPDATE sci_name = VALUES(sci_name), note = VALUES(note);');
say('');

// ---- ফসল ----
say('-- ৫. ফসল (কৃষকের স্প্রে নোটিশে লাগে)');
say('INSERT INTO crops (name) VALUES');
say(['সরিষা', 'ধান', 'গম', 'ভুট্টা', 'আলু', 'লিচু', 'আম', 'সবজি', 'তিল', 'কালোজিরা', 'ধনিয়া']
  .map((c) => `  (${q(c)})`).join(',\n'));
say('ON DUPLICATE KEY UPDATE name = VALUES(name);');
say('');

// ---- লক্ষণ ----
const symptomCodes = Object.keys(SYMPTOMS);
say(`-- ৬. লক্ষণ — ${symptomCodes.length}টি (diseases.html-এ এগুলো বাছা হয়)`);
say('INSERT INTO symptoms (code, name) VALUES');
say(symptomCodes.map((c) => `  (${q(c)}, ${q(SYMPTOMS[c])})`).join(',\n'));
say('ON DUPLICATE KEY UPDATE name = VALUES(name);');
say('');

// ---- রোগ ----
say(`-- ৭. রোগ ও শত্রু — ${DISEASES.length}টি`);
say('INSERT INTO diseases (code, name, kind, risk, cause, spread) VALUES');
say(DISEASES.map((d) =>
  `  (${q(d.id)}, ${q(d.name)}, ${q(d.kind)}, ${q(d.risk)}, '', '')`).join(',\n'));
say('ON DUPLICATE KEY UPDATE name = VALUES(name), kind = VALUES(kind), risk = VALUES(risk);');
say('');

// ---- রোগ ↔ লক্ষণ (M:N) ----
const dsRows = [];
for (const d of DISEASES) {
  for (const s of d.symptoms || []) {
    dsRows.push(`  ((SELECT id FROM diseases WHERE code = ${q(d.id)}),` +
                ` (SELECT id FROM symptoms WHERE code = ${q(s)}))`);
  }
}
say(`-- ৮. রোগ ↔ লক্ষণ junction — ${dsRows.length} জোড়া`);
say('--    লক্ষণ বাছলে রোগ বের হওয়ার পুরো কাজটা এই টেবিলের উপর দাঁড়ানো');
say('INSERT IGNORE INTO disease_symptoms (disease_id, symptom_id) VALUES');
say(dsRows.join(',\n') + ';');
say('');

// ---- রোগের ধাপ ----
const stepRows = [];
for (const d of DISEASES) {
  for (const [kind, key] of [['sign', 'signs'], ['prevent', 'prevent'], ['treat', 'treat']]) {
    (d[key] || []).forEach((text, i) => {
      stepRows.push(`  ((SELECT id FROM diseases WHERE code = ${q(d.id)}),` +
                    ` ${q(kind)}, ${i + 1}, ${q(text)})`);
    });
  }
}
say(`-- ৯. রোগের লক্ষণ-বর্ণনা, প্রতিরোধ ও চিকিৎসার ধাপ — ${stepRows.length}টি`);
say('--    আগে এগুলো diseases টেবিলের তিনটা TEXT কলামে JSON string ছিল (1NF ভাঙত)');
say('INSERT INTO disease_steps (disease_id, kind, step_no, text) VALUES');
say(stepRows.join(',\n'));
say('ON DUPLICATE KEY UPDATE text = VALUES(text);');
say('');

// ---- ফুল ----
say(`-- ১০. ফুল — ${FLORA.length}টি`);
say('INSERT INTO flora (name, where_found, is_dearth) VALUES');
say(FLORA.map((f) => `  (${q(f.name)}, ${q(f.where)}, ${f.dearth ? 1 : 0})`).join(',\n'));
say('ON DUPLICATE KEY UPDATE where_found = VALUES(where_found), is_dearth = VALUES(is_dearth);');
say('');

const bloomRows = [];
for (const f of FLORA) {
  for (const m of f.months || []) {
    bloomRows.push(`  ((SELECT id FROM flora WHERE name = ${q(f.name)}), ${m})`);
  }
}
say(`-- ১১. ফুল ↔ মাস junction — ${bloomRows.length} জোড়া`);
say('--    আগে flora.months কলামে "[12,1,2]" string ছিল');
say('INSERT IGNORE INTO flora_blooms (flora_id, month_id) VALUES');
say(bloomRows.join(',\n') + ';');
say('');

say('COMMIT;');
say('');
say('-- ---- যাচাই ----');
say("SELECT 'districts' AS টেবিল, COUNT(*) AS সারি FROM districts");
say("UNION ALL SELECT 'upazilas', COUNT(*) FROM upazilas");
say("UNION ALL SELECT 'months', COUNT(*) FROM months");
say("UNION ALL SELECT 'crops', COUNT(*) FROM crops");
say("UNION ALL SELECT 'bee_species', COUNT(*) FROM bee_species");
say("UNION ALL SELECT 'symptoms', COUNT(*) FROM symptoms");
say("UNION ALL SELECT 'diseases', COUNT(*) FROM diseases");
say("UNION ALL SELECT 'disease_symptoms', COUNT(*) FROM disease_symptoms");
say("UNION ALL SELECT 'disease_steps', COUNT(*) FROM disease_steps");
say("UNION ALL SELECT 'flora', COUNT(*) FROM flora");
say("UNION ALL SELECT 'flora_blooms', COUNT(*) FROM flora_blooms;");

fs.writeFileSync(outFile, out.join('\n') + '\n', 'utf8');
console.log('districts=%d upazilas=%d symptoms=%d diseases=%d steps=%d flora=%d blooms=%d',
  districts.length, upazilaRows.length, symptomCodes.length,
  DISEASES.length, stepRows.length, FLORA.length, bloomRows.length);
console.log('লেখা হয়েছে: ' + outFile);
