const fs = require('fs');

var lines = fs.readFileSync(process.argv[2], 'utf-8').split(/[\n\r]/);

for(var i = 0; i < lines.length; i++) {
    lines[i] = lines[i].replace('"/wd4312"', '"/wd4834"');
}
        
fs.writeFileSync(process.argv[2], lines.join('\n'));
