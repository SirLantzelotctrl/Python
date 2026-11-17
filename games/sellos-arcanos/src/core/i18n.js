import { STRINGS } from './strings.js';

let lang = 'es';

export function detectLang(saved) {
  if (saved === 'es' || saved === 'en') return saved;
  const nav = (navigator.language || 'en').toLowerCase();
  return nav.startsWith('es') ? 'es' : 'en';
}

export function setLang(l) {
  lang = l === 'en' ? 'en' : 'es';
  document.documentElement.lang = lang;
}

export function getLang() {
  return lang;
}

// t('clave', {n: 3}) -> texto con {n} sustituido
export function t(key, vars) {
  const entry = STRINGS[key];
  let s = entry ? entry[lang] ?? entry.es : key;
  if (vars) for (const k in vars) s = s.split(`{${k}}`).join(vars[k]);
  return s;
}

// L({es, en}) -> texto en el idioma activo
export function L(obj) {
  if (!obj) return '';
  return obj[lang] ?? obj.es ?? '';
}

export function fmt(n) {
  return Math.round(n).toLocaleString(lang === 'es' ? 'es-ES' : 'en-US');
}
