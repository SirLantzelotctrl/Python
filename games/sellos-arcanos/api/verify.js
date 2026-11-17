// GET /api/verify?session_id=cs_... -> {paid, sku}
// El juego concede el producto una sola vez por session_id.
import { cors, stripe } from './_stripe.js';

export default async function handler(req, res) {
  cors(req, res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  const id = new URL(req.url, 'http://x').searchParams.get('session_id') || '';
  if (!/^cs_(test|live)_[A-Za-z0-9]+$/.test(id)) return res.status(400).json({ paid: false, error: 'bad_session' });
  if (!process.env.STRIPE_SECRET_KEY) return res.status(503).json({ paid: false, error: 'payments_disabled' });
  try {
    const s = await stripe('checkout/sessions/' + encodeURIComponent(id));
    const paid = s.payment_status === 'paid' || s.payment_status === 'no_payment_required';
    return res.status(200).json({ paid, sku: s.metadata?.sku || null });
  } catch (e) {
    return res.status(502).json({ paid: false, error: e.message });
  }
}
