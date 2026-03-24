const fs = require('fs');
const path = require('path');

const htmlContent = fs.readFileSync('wiki_colors_raw.html', 'utf8');

// Regex to find color spans and text content
// Matches: <span style="color: #RRGGBB;">CONTENT</span>
// Also handles <br /> which signifies new line
const regex = /<span style="color: (#[0-9A-Fa-f]{6});">([^<]*)<\/span>|<br \/>/g;

let match;
let gridColors = [];
let currentRow = [];
let currentColor = '#800000'; // Default start color based on first line logic if missing

// Manual fix: The first line "琴清..." is inside a span #800000 but starts with a <br /> inside the span?
// The snippet shows: <span style="color: #800000;"><br />琴清...</span>
// So the first characters are Maroon.

// We will simulate a parser that walks the string.
// However, the HTML provided in snippet is:
// <p ...><span color="#800000"><br />CHARS...<br />CHAR</span><span color="#000000">...</span></p>

// Let's create a cleaner string to parse by removing non-essential tags first
let cleanHtml = htmlContent.replace(/<p[^>]*>/g, '').replace(/<\/p>/g, '');

// The structure is roughly:
// <span style="color: COLOR;">TEXT_MAYBE_WITH_BR</span>
// We need to capture the COLOR and the TEXT (including breaks).

const colorSpans = [];
const spanRegex = /<span style="color: (#[0-9A-Fa-f]{6});">([\s\S]*?)<\/span>/g;

while ((match = spanRegex.exec(cleanHtml)) !== null) {
    colorSpans.push({
        color: match[1],
        content: match[2]
    });
}

// Now process the content of spans.
// Content might contain <br />.
// We treat the grid as a stream of characters. <br /> forces a row jump (or we can just count 29 chars).
// Since it's a 29x29 grid, we can just filter out whitespace/br and push to a flat array, then map to grid.

let flatColorMap = [];

for (const span of colorSpans) {
    // Remove <br /> tags and newlines
    const text = span.content.replace(/<br\s*\/?>/gi, '').replace(/\s/g, '');
    
    for (const char of text) {
        flatColorMap.push(span.color);
    }
}

// Validation
console.log(`Total characters found: ${flatColorMap.length}`);
if (flatColorMap.length !== 841) {
    console.warn("WARNING: Count mismatch! Expected 841 (29*29).");
    // If mismatch, we might need to be more careful with the first <span ...><br />...</span> case
    // In the raw HTML: <span style="color: #800000;"><br />琴...</span>
    // My logic handles stripping <br />.
    // Let's check if "Full text" header or other junk got in.
}

// Construct the 29x29 grid
const GRID_SIZE = 29;
const colorGrid = [];

for (let r = 0; r < GRID_SIZE; r++) {
    const row = [];
    for (let c = 0; c < GRID_SIZE; c++) {
        const idx = r * GRID_SIZE + c;
        if (idx < flatColorMap.length) {
            row.push(flatColorMap[idx]);
        } else {
            row.push('#000000'); // Fallback
        }
    }
    colorGrid.push(row);
}

// Write to file
const outputPath = path.join('star-guage/src/data/color-map.json');
fs.writeFileSync(outputPath, JSON.stringify(colorGrid, null, 2));
console.log(`Written color map to ${outputPath}`);
