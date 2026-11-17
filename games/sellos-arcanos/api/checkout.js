// POST /api/checkout {sku, lang, returnUrl} -> {url} de Stripe Checkout
// GET  /api/checkout -> {enabled} (el juego muestra la tienda de pago solo si hay clave)
import { PRODUCTS } from '../src/data/shop.js';
import { cors, stripe, readBody } from './_stripe.js';

export default async function handler(req, res) {
  cors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  const enabled = !!process.env.STRIPE_SECRET_KEY;
  if (req.method === 'GET') return res.status(200).json({ enabled });
  if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
  if (!enabled) return res.status(503).json({ error: 'payments_disabled' });

  const { sku, lang, returnUrl } = await readBody(req);
  const product = PRODUCTS.find((p) => p.sku === sku);
  if (!product) return res.status(400).json({ error: 'unknown_sku' });

  // evita redirecciones abiertas: solo se vuelve a orígenes permitidos
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  const fallback = `https://${host}/`;
  const allowed = (process.env.ALLOWED_RETURN_ORIGINS || '').split(',').map((s) => s.trim()).filter(Boolean);
  let base = fallback;
  try {
    const u = new URL(returnUrl);
    if (u.host === host || allowed.includes(u.origin)) base = u.origin + u.pathname;
  } catch { /* usa el origen propio */ }

  const l = lang === 'en' ? 'en' : 'es';
  try {
    const session = await stripe('checkout/sessions', {
      method: 'POST',
      form: {
        mode: 'payment',
        'line_items[0][quantity]': '1',
        'line_items[0][price_data][currency]': (process.env.STRIPE_CURRENCY || 'usd').toLowerCase(),
        'line_items[0][price_data][unit_amount]': String(Math.round(product.usd * 100)),
        'line_items[0][price_data][product_data][name]': `Sellos Arcanos · ${product.name[l]}`,
        ...(product.desc ? { 'line_items[0][price_data][product_data][description]': product.desc[l] } : {}),
        'metadata[sku]': sku,
        'payment_intent_data[metadata][sku]': sku,
        success_url: `${base}?purchase=ok&session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: `${base}?purchase=cancel`,
        locale: l,
        allow_promotion_codes: 'true',
      },
    });
    return res.status(200).json({ url: session.url });
  } catch (e) {
    return res.status(502).json({ error: e.message });
  }
}
