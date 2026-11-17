// Utilidades compartidas por las funciones de pago (Vercel Serverless, Node 18+).
// Variables de entorno:
//   STRIPE_SECRET_KEY        sk_live_... o sk_test_...  (obligatoria para cobrar)
//   STRIPE_CURRENCY          usd (por defecto) | eur | mxn ...
//   ALLOWED_RETURN_ORIGINS   https://tu-dominio.com,https://otro.com (opcional)
export function cors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 'no-store');
}

export async function stripe(path, { method = 'GET', form } = {}) {
  const key = process.env.STRIPE_SECRET_KEY;
  const r = await fetch('https://api.stripe.com/v1/' + path, {
    method,
    headers: {
      Authorization: `Bearer ${key}`,
      ...(form ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
    },
    body: form ? new URLSearchParams(form).toString() : undefined,
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error?.message || 'stripe_error');
  return j;
}

export function readBody(req) {
  if (req.body && typeof req.body === 'object') return Promise.resolve(req.body);
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => { data += c; });
    req.on('end', () => { try { resolve(JSON.parse(data || '{}')); } catch { resolve({}); } });
  });
}
