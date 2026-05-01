const fs = require('fs');
const path = require('path');

const datasetDir = path.join(__dirname, '..', 'sdataset');
const outputDir = path.join(__dirname, 'src', 'data');

if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });

const csvFiles = fs.readdirSync(datasetDir).filter(f => f.endsWith('.csv'));

for (const file of csvFiles) {
  const raw = fs.readFileSync(path.join(datasetDir, file), 'utf-8');
  const lines = raw.split(/\r?\n/).filter(l => l.trim());
  const headers = parseCSVLine(lines[0]);
  const rows = [];

  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVLine(lines[i]);
    const obj = {};
    headers.forEach((h, idx) => {
      let val = values[idx] || '';
      // Auto-convert numeric fields
      if (/^-?\d+(\.\d+)?$/.test(val) && !h.includes('aadhaar') && !h.includes('phone')) {
        val = Number(val);
      }
      obj[h] = val;
    });
    rows.push(obj);
  }

  const jsonName = file.replace('.csv', '.json');
  fs.writeFileSync(path.join(outputDir, jsonName), JSON.stringify(rows, null, 2));
  console.log(`✓ ${file} → ${jsonName} (${rows.length} rows)`);
}

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += ch;
    }
  }
  result.push(current.trim());
  return result;
}

console.log('\nDone! All CSV files converted to JSON in src/data/');
