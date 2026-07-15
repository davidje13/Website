#!/usr/bin/env node

// This file generates static/ascii/index.htm

const COLUMNS = 4;
const ROWS = Math.ceil(128 / COLUMNS);

const CHAR_INFO = new Map([
	[0x00, { short: 'NUL', long: 'Null', esc: '\\0' }],
	[0x01, { short: 'SOH', long: 'Start of Heading' }],
	[0x02, { short: 'STX', long: 'Start of Text' }],
	[0x03, { short: 'ETX', long: 'End of Text' }],
	[0x04, { short: 'EOT', long: 'End of Transmission' }],
	[0x05, { short: 'ENQ', long: 'Enquiry' }],
	[0x06, { short: 'ACK', long: 'Acknowledge' }],
	[0x07, { short: 'BEL', long: 'Bell', esc: '\\a' }],
	[0x08, { short: 'BS', long: 'Backspace', esc: '\\b' }],
	[0x09, { short: 'HT', long: 'Horizontal Tabulation', esc: '\\t' }],
	[0x0A, { short: 'LF', long: 'Line Feed', esc: '\\n' }],
	[0x0B, { short: 'VT', long: 'Vertical Tabulation', esc: '\\v' }],
	[0x0C, { short: 'FF', long: 'Form Feed', esc: '\\f' }],
	[0x0D, { short: 'CR', long: 'Carriage Return', esc: '\\r' }],
	[0x0E, { short: 'SO', long: 'Shift Out' }],
	[0x0F, { short: 'SI', long: 'Shift In' }],
	[0x10, { short: 'DLE', long: 'Data Link Escape' }],
	[0x11, { short: 'DC1', long: 'Device Control 1' }],
	[0x12, { short: 'DC2', long: 'Device Control 2' }],
	[0x13, { short: 'DC3', long: 'Device Control 3' }],
	[0x14, { short: 'DC4', long: 'Device Control 4' }],
	[0x15, { short: 'NAK', long: 'Negative Acknowledge' }],
	[0x16, { short: 'SYN', long: 'Synchronous Idle' }],
	[0x17, { short: 'ETB', long: 'End of Transmission Block' }],
	[0x18, { short: 'CAN', long: 'Cancel' }],
	[0x19, { short: 'EM', long: 'End of Medium' }],
	[0x1A, { short: 'SUB', long: 'Substitute' }],
	[0x1B, { short: 'ESC', long: 'Escape', esc: '\\e' }],
	[0x1C, { short: 'FS', long: 'File Separator' }],
	[0x1D, { short: 'GS', long: 'Group Separator' }],
	[0x1E, { short: 'RS', long: 'Record Separator' }],
	[0x1F, { short: 'US', long: 'Unit Separator' }],
	[0x20, { short: 'SP', long: 'Space' }],
	[0x7F, { short: 'DEL', long: 'Delete' }],
]);

const colInfos = [];
for (let x = 0; x < COLUMNS; ++x) {
	const colInfo = { esc: false, caret: false };
	for (let y = 0; y < ROWS; ++y) {
		const char = getCharInfo(x * ROWS + y);
		if (char.short) {
			colInfo.esc = true;
		}
		if (char.caret) {
			colInfo.caret = true;
		}
	}
	colInfos.push(colInfo);
}

out(
	'<!DOCTYPE html>',
	'<html lang="en">',
	'<head>',
	'<meta charset="utf-8">',
	'<link rel="stylesheet" href="./style.css" />',
	'<title>ASCII - ((DOMAIN))</title>',
	'<link rel="icon" href="../favicon.ico">',
	'</head>',
	'<body>',
	'<h1>ASCII</h1>',
	'<table>',
	'<thead>',
	'<tr>',
);
for (let x = 0; x < COLUMNS; ++x) {
	const colInfo = colInfos[x];
	out(
		'<th class="b"><abbr title="Binary">Bin</abbr></th>',
		'<th class="d"><abbr title="Decimal">Dec</abbr></th>',
		'<th class="h"><abbr title="Hexadecimal">Hex</abbr></th>',
		'<th class="c"><abbr title="Character">Char</abbr></th>',
		colInfo.esc ? '<th class="e" aria-label="C Escape Sequence"></th>' : '',
		colInfo.caret ? '<th class="t" aria-label="Caret Notation"></th>' : '',
		x < COLUMNS - 1 ? '<th class="l"></th>' : '',
	);
}
out(
	'</tr>',
	'</thead>',
	'<tbody>\n',
);
for (let y = 0; y < ROWS; ++y) {
	out('<tr>\n');
	for (let x = 0; x < COLUMNS; ++x) {
		const char = getCharInfo(x * ROWS + y);
		const colInfo = colInfos[x];
		out(
			`<td class="b">${escapeHTML(char.b)}</td>`,
			`<td class="d">${escapeHTML(char.d)}</td>`,
			`<td class="h">${escapeHTML(char.h)}</td>`,
			`<td class="c">`,
		);
		if (char.short) {
			out(`<abbr title="${escapeHTML(char.long)}">${escapeHTML(char.short)}</abbr>`);
		} else {
			out(escapeHTML(char.c));
		}
		out('</td>');
		if (colInfo.esc) {
			out(`<td class="e">${escapeHTML(char.esc ?? '')}</td>`);
		}
		if (colInfo.caret) {
			out(`<td class="t">${char.caret ? escapeHTML('^' + char.caret) : ''}</td>`);
		}
		out(
			x < COLUMNS - 1 ? '<td class="l"></td>' : '',
			'\n',
		);
	}
	out('</tr>\n');
}
out(
	'</tbody>',
	'</table>',
	'</body>',
	'</html>',
);

function out(...lines) {
	for (const ln of lines) {
		process.stdout.write(ln);
	}
}

function escapeHTML(v) {
	return v
		.replaceAll('&', '&amp;')
		.replaceAll('<', '&lt;')
		.replaceAll('>', '&gt;')
		.replaceAll('"', '&quot;');
}

function getCharInfo(v) {
	return {
		...CHAR_INFO.get(v),
		caret: v < 0x20 ? String.fromCharCode(v + 0x40) : v === 0x7F ? '?' : null,
		c: String.fromCharCode(v),
		b: v.toString(2).padStart(8, '0'),
		d: v.toString(10),
		h: v.toString(16).toUpperCase().padStart(2, '0'),
	};
}
