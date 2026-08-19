// Validates JSONC files (JSON + comments + trailing commas) — the format
// VSCode and Zed settings use. Usage: node jsonc-check.js <file> [<file> ...]
'use strict';
const fs = require('fs');

function stripJsonc(src) {
  let out = '', inStr = false;
  for (let i = 0; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (inStr) {
      out += c;
      if (c === '\\') { out += n; i++; continue; }
      if (c === '"') inStr = false;
      continue;
    }
    if (c === '"') { inStr = true; out += c; continue; }
    if (c === '/' && n === '/') { while (i < src.length && src[i] !== '\n') i++; continue; }
    if (c === '/' && n === '*') { i += 2; while (i < src.length && !(src[i] === '*' && src[i + 1] === '/')) i++; i++; continue; }
    out += c;
  }
  return out.replace(/,(\s*[}\]])/g, '$1'); // drop trailing commas
}

let failed = false;
for (const file of process.argv.slice(2)) {
  try {
    JSON.parse(stripJsonc(fs.readFileSync(file, 'utf8')));
    console.log('valid JSONC:', file);
  } catch (err) {
    console.error('INVALID JSONC:', file, '—', err.message);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
