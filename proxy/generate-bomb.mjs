const ext = process.argv[2];
const zipped = process.argv[3] === '--zipped';
const rep = 10000;

function o(t, n = 1) {
  if (n >= rep) for (const tr = t.repeat(rep); n >= rep; n -= rep) process.stdout.write(tr);
  process.stdout.write(t.repeat(n));
}

function shell() {
  o('\n', zipped ? 1000000 : 10000);
  o('\u001B]0;');
  o('?', zipped ? 10000000 : 10000);
  o('\u0007\u001B[?1049h');
  o('\u001B[41m \u001B[42m%', zipped ? 1000000 : 5000);
  o('\u001B[2m\u001B[5m\u001B[8m\u001B[30m\u001B[40m\u001B[38:2:0:0:0m\u001B[48:2:0:0:0m\u001B[?25l\u001B[?2004l\u001B[=1h\u001B[97;8p\u001B[101;8p\u001B[105;8p\u001B[111;8p\u001B[117;8p\u001B[13;8p');
  o('\u0007', zipped ? 100000000 : 10000);
  o('\u001BX\u001B[');
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
    o('>', zipped ? 70000000 : 10000);
    o('<form ');
    o('action=', zipped ? 100000 : 1000);
    o('<a ');
    o('href=', zipped ? 100000 : 1000);
    shell();
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
    o(`]><r>&l${levels};`);
    o('\n', zipped ? 1000000 : 10000);
    o('.', zipped ? 200000000 : 10000);
    o(`</r>`);
    break;
  }
  case 'json':
    o('{"data":');
    o('{"v":', zipped ? 1000000 : 10000);
    o('[', zipped ? 100000000 : 50000);
    o('0');
    o(',1', zipped ? 1000000 : 50000);
    o('],"');
    shell();
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
    o('[', zipped ? 100000000 : 100000);
    o('0');
    o(',1', zipped ? 1000000 : 50000);
    o('],"');
    shell();
    break;
  }
  default:
    throw new Error(`Unknown file type: ${ext}`);
}
