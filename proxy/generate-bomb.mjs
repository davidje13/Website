const zipped = process.argv[2] === '--zipped';
const rep = 10000;

function o(t, n = 1) {
  if (n >= rep) for (const tr = t.repeat(rep); n >= rep; n -= rep) process.stdout.write(tr);
  process.stdout.write(t.repeat(n));
}

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
