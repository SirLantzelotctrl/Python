// Comprueba la sintaxis de todos los .lua del proyecto (subconjunto compatible
// con Lua 5.1/5.2, que Luau acepta) y algunos errores comunes.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import luaparse from 'luaparse';

const root = new URL('../src', import.meta.url).pathname;
let errors = 0;
let files = 0;

function walk(dir) {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) walk(p);
    else if (p.endsWith('.lua')) check(p);
  }
}

function check(p) {
  files++;
  const src = readFileSync(p, 'utf8');
  try {
    const ast = luaparse.parse(src, { luaVersion: '5.2', locations: true, scope: true });
    // globales sospechosas (posibles errores de escritura)
    const allowed = new Set(['game', 'workspace', 'script', 'Instance', 'Vector3', 'Vector2', 'CFrame', 'Color3', 'UDim', 'UDim2',
      'Enum', 'TweenInfo', 'NumberSequence', 'NumberSequenceKeypoint', 'ColorSequence', 'ColorSequenceKeypoint', 'NumberRange',
      'Ray', 'RaycastParams', 'OverlapParams', 'Rect', 'BrickColor', 'PhysicalProperties', 'Font', 'Random', 'DateTime',
      'task', 'tick', 'time', 'os', 'math', 'string', 'table', 'coroutine', 'pcall', 'xpcall', 'error', 'assert', 'warn', 'print',
      'require', 'pairs', 'ipairs', 'next', 'select', 'type', 'typeof', 'tostring', 'tonumber', 'setmetatable', 'getmetatable',
      'rawget', 'rawset', 'rawequal', 'unpack', 'utf8', 'bit32', 'buffer', 'debug', 'shared', '_G', 'Axes', 'Faces', 'SharedTable']);
    for (const g of ast.globals || []) {
      if (!allowed.has(g.name)) {
        console.log(`${p}:${g.loc ? g.loc.start.line : '?'}: global sospechosa «${g.name}»`);
        errors++;
      }
    }
  } catch (e) {
    console.log(`${p}: ${e.message}`);
    errors++;
  }
  if (src.includes(']]>')) {
    console.log(`${p}: contiene «]]>» (rompe el CDATA del .rbxlx)`);
    errors++;
  }
}

walk(root);
console.log(`${files} archivos, ${errors} problemas`);
process.exit(errors ? 1 : 0);
