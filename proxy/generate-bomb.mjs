const ext = process.argv[2];
const zipped = process.argv[3] === '--zipped';
const rep = 10000;

function o(t, n = 1) {
  if (n >= rep) for (const tr = t.repeat(rep); n >= rep; n -= rep) process.stdout.write(tr);
  process.stdout.write(t.repeat(n));
}

function shell() {
  // play with a lot of (non-permanent) terminal settings if somebody decides
  // to display the file raw in the terminal (e.g. curl or cat)

  o('\n', zipped ? 1000000 : 10000); // clear scrollback
  // set window title
  o('\u001B]0;');
  o('?' + '\u0347\u0363'.repeat(30), zipped ? 100000 : 100);
  o('\u0007');
  o('\u001B[?1049h'); // switch to "alternate screen"
  o('\u001B[?5h'); // reverse video mode
  // alternating colour pattern (poor performance in terminal emulators)
  o('\u001B[41m \u0347\u0363\u0347\u0363\u001B[42m%\u0347\u0363\u0347\u0363', zipped ? 400000 : 2000);
  o('\u001B[3q'); // caps lock LED
  o('\u001B[4h'); // insert mode
  o('\u001B[?1h'); // cursor keys send ESC-O
  // hide text (likely to be automatically reset by terminal)
  o('\u001B[2m\u001B[5m\u001B[8m\u001B[30m\u001B[40m\u001B[38:2:0:0:0m\u001B[48:2:0:0:0m\u001B[8]');
  o('\u001B[?25l'); // hide cursor
  o('\u001B[1h\u001B[=1h'); // 40x25 colour screen
  // redefine palette colours
  for (let i = 0; i < 16; ++i) {
    o(`\u001B]P${i.toString(16)}000000`);
  }
  // redefine keys AEIOU and return as backspace
  o('\u001B[97;8p\u001B[101;8p\u001B[105;8p\u001B[111;8p\u001B[117;8p\u001B[13;8p');
  // lots of bell characters
  o('\u0007', zipped ? 100000000 : 10000);
  // start string, begin unterminated escape sequence
  o('\u001BX\u001B[');
}

switch (ext) {
  case 'html':
    o('<!DOCTYPE html><html><head><title>Loading...</title></head><body>');
    // DOM parsing: heavily nested tags (stack overflow or large memory usage)
    o('<i>', zipped ? 1000000 : 10000);
    // Regex parsing: O(n^2) backtracking for badly written regexes (links - spaces)
    o('<a a');
    o(' ', zipped ? 10000000 : 100000);
    o('href="https://a.b'); // no " after this
    // (URLs - slashes)
    o('/', zipped ? 1000000 : 10000);
    o('?', zipped ? 1000000 : 10000);
    o(' a');
    // (link + text - end of tag)
    o('>', zipped ? 70000000 : 10000); // no </a> after this
    // (forms - attributes)
    o('<form ');
    o('action=', zipped ? 100000 : 1000);
    // (links - attributes)
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
    // no shell codes as it would not be valid XML, potentially breaking the "billion laughs"
    break;
  }
  case 'json':
    o('{"data":');
    // heavily nested objects
    o('{"v":', zipped ? 1000000 : 10000);
    // heavily nested arrays
    o('[', zipped ? 100000000 : 50000);
    o('0');
    // large array
    o(',1', zipped ? 1000000 : 50000);
    o('],"');
    shell();
    break;
  case 'yaml': {
    // adaptation of "billion laughs"
    const levels = 50;
    o(`v0: &v0 ["data"]\n`);
    for (let i = 0; i < levels; ++i) {
      o(`v${i + 1}: &v${i + 1} [*v${i}`);
      o(`,*v${i}`, zipped ? 9999 : 99);
      o(']\n');
    }
    o('n: ');
    // heavily nested arrays
    o('[', zipped ? 100000000 : 100000);
    o('0');
    // large array
    o(',1', zipped ? 1000000 : 50000);
    o('],"');
    shell();
    break;
  }
  default:
    throw new Error(`Unknown file type: ${ext}`);
}

// https://en.wikipedia.org/wiki/ANSI_escape_code
// https://gist.github.com/fnky/458719343aabd01cfb17a3a4f7296797
// https://man7.org/linux/man-pages/man4/console_codes.4.html
