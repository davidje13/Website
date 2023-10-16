const ext = process.argv[2];
const zipped = process.argv[3] === '--zipped';
const rep = 10000;

function o(t, n = 1) {
  if (n >= rep) for (const tr = t.repeat(rep); n >= rep; n -= rep) process.stdout.write(tr);
  process.stdout.write(t.repeat(n));
}

switch (ext) {
  case 'html':
    o('<!DOCTYPE html><html><head><title>Loading...</title></head><body>');
    o('<i>', zipped ? 1000000 : 10000);
    o('<a a');
    o(' ', zipped ? 10000000 : 100000);
    o('href="https://a.b');
    o('/', zipped ? 1000000 : 10000);
    o('?', zipped ? 1000000 : 10000);
    o(' a');
    o('>', zipped ? 10000000 : 10000);
    o('<form ');
    o('action=', zipped ? 100000 : 1000);
    o('<a ');
    o('href=', zipped ? 100000 : 1000);
    o(' ', zipped ? 200000000 : 0);
    break;
  case 'xml': {
    // extended "billion laughs"
    o('<?xml version="1.0" encoding="UTF-8" ?>\n<!DOCTYPE r [\n<!ENTITY l0 "data"><!ELEMENT r (#PCDATA)>');
    const levels = 50;
    for (let i = 0; i < levels; ++i) {
      o(`<!ENTITY l${i + 1} "`);
      o(`&l${i};`, 50);
      o(`">`);
    }
    o(`]><r>`);
    if (zipped) {
      o('.', 200000000);
    }
    o(`</r>`);
    break;
  }
  case 'json':
    o('{"data":');
    o('{"v":', zipped ? 1000000 : 10000);
    o('[', zipped ? 200000000 : 50000);
    o('0');
    o(',1', zipped ? 1000000 : 50000);
    o(']');
    break;
  case 'yaml': {
    const levels = 50;
    o(`v0: &v0 ["data"]\n`);
    for (let i = 0; i < levels; ++i) {
      o(`v${i + 1}: &v${i + 1} [*v${i}`);
      o(`,*v${i}`, zipped ? 9999 : 99);
      o(']\n');
    }
    o('n: ');
    o('[', zipped ? 200000000 : 100000);
    o('0');
    o(',1', zipped ? 1000000 : 50000);
    o(']');
    break;
  }
  default:
    throw new Error(`Unknown file type: ${ext}`);
}
