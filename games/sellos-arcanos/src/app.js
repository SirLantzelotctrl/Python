// Controlador del juego: navegación entre pantallas, expediciones,
// recompensas, compras y anuncios.
import { state, save, saveNow, spendInk, today } from './core/save.js';
import { t, L, fmt } from './core/i18n.js';
import { platform } from './core/platform.js';
import { sfx, playMusic, initAudio } from './core/audio.js';
import { CREATURE } from './data/creatures.js';
import { ISLANDS } from './data/islands.js';
import { TINT, SEAL, EFFECT, PRODUCT } from './data/shop.js';
import { Combat } from './game/combat.js';
import { openSealing } from './game/sealing.js';
import { addCreature, giveXp, rankInfo, progressContract, addPassXp, grant, bestiaryMilestones, addBondCheck, teamSize, checkTitles } from './game/progression.js';
import { titleScreen, starterScreen, menuScreen, mapScreen, loadingScreen, settingsModal, adInkOffer, watchAdForInk } from './ui/menus.js';
import { bestiaryScreen, fichaScreen } from './ui/collection.js';
import { shopScreen, passScreen } from './ui/shop.js';
import { hudScreen, updateHud, showBanner, hideHud, resultsScreen } from './ui/hud.js';
import { modal, toast, confirmBuy, ICON } from './ui/ui.js';
import { clearPressed, input } from './engine/input.js';

export const app = {
  renderer: null,
  showcase: null,
  combat: null,
  current: null,
  params: null,
  onLeave: null,

  go(name, params = {}) {
    // el equipo solo puede tener criaturas propias
    state.team = state.team.filter((id) => state.creatures[id]);
    if (!state.team.length && Object.keys(state.creatures).length) state.team = [Object.keys(state.creatures)[0]];
    this.onLeave?.();
    this.onLeave = null;
    if (this.combat && name !== 'hud') this.endCombat();
    this.current = name;
    this.params = params;
    document.body.classList.toggle('in-combat', name === 'hud');
    if (name !== 'hud') {
      this.showcase.activate();
      playMusic('menu');
    }
    const screens = {
      title: titleScreen, starter: starterScreen, menu: menuScreen, map: mapScreen,
      bestiary: bestiaryScreen, ficha: fichaScreen, shop: shopScreen, pass: passScreen,
    };
    screens[name]?.(params);
  },

  refresh() {
    if (this.current && this.current !== 'hud') this.go(this.current, this.params);
  },

  sealFor(id) {
    const s = state.cosmetics.seal;
    return s && s !== 'propio' ? s : CREATURE[id].circle;
  },

  // --- expediciones ---------------------------------------------------
  startExpedition(islandIdx, opts = {}) {
    initAudio();
    this.showcase.setTeam([]);
    const begin = () => {
      platform.gameplayStart();
      this.current = 'hud';
      document.body.classList.add('in-combat');
      const team = state.team.filter((id) => state.creatures[id]).slice(0, teamSize());
      this.combat = new Combat(this.renderer, document.getElementById('dmg'), this.combatEvents());
      this.combat.start({ islandIdx, team, tutorial: !!opts.tutorial, waves: opts.tutorial ? 3 : 4 });
      hudScreen(this.combat);
      if (opts.tutorial) this.tutorialHints();
      clearPressed();
    };
    if (opts.tutorial) begin();
    else loadingScreen(islandIdx, begin);
  },

  tutorialHints() {
    const touch = input.touch || matchMedia('(pointer: coarse)').matches;
    const steps = touch ? ['tut1t', 'tut2t', 'tut3', 'tut4'] : ['tut1', 'tut2', 'tut3', 'tut4'];
    steps.forEach((k, i) => setTimeout(() => {
      if (this.combat && !this.combat.over) toast(t(k));
    }, 1500 + i * 5200));
  },

  combatEvents() {
    return {
      hud: (c) => updateHud(c),
      banner: (text, cls, dur, sub) => showBanner(text, cls, dur, sub),
      sealStart: (enemy) => this.startSeal(enemy),
      choice: () => this.bossChoice(),
      defeat: () => this.defeatModal(),
      end: (victory, rewards, fought) => this.finishExpedition(victory, rewards, fought),
    };
  },

  async startSeal(enemy) {
    const c = this.combat;
    if (!c || enemy.sealing) return;
    if (!enemy.boss) {
      if (state.ink <= 0) {
        sfx.error();
        if (adInkOffer()) {
          c.paused = true;
          const go = await modal(t('noInkTitle'), `<p>${t('noInkBody')}</p>`, [{ label: t('cancel'), value: false }, { label: `${t('watchAd')} · +3`, cls: 'primary', value: true }]);
          if (go) await watchAdForInk();
          c.paused = false;
        } else toast(t('noInk'));
        if (state.ink <= 0) return;
      }
      spendInk();
    }
    enemy.sealing = true;
    c.paused = true;
    platform.gameplayStop();
    const def = CREATURE[enemy.id];
    const nodes = enemy.boss ? 9 : Math.min(7, Math.max(4, def.nodes - 2 + Math.floor(c.islandIdx / 4)));
    openSealing({
      root: document.getElementById('modal-root'),
      color: enemy.visual.glowColor.getStyle(),
      name: L(def.name),
      nodes,
      moving: enemy.boss || enemy.form >= 1,
      time: enemy.boss ? 7 : 5,
      boss: enemy.boss,
      ink: state.ink + 1,
      onDone: (result) => {
        c.paused = false;
        platform.gameplayStart();
        c.sealResult(enemy, result);
        if (result !== 'fail') platform.happytime();
        clearPressed();
      },
    });
  },

  async bossChoice() {
    const c = this.combat;
    c.paused = true;
    const isl = ISLANDS[c.islandIdx];
    const cleared = state.islands.cleared.includes(c.islandIdx);
    const v = await modal(t('pathEnds'), `<p>${cleared ? t('bossAgain', { name: L(CREATURE[isl.boss].name) }) : t('bossFirst')}</p>`, [
      { label: t('returnCitadel'), value: 'leave' },
      { label: t('facePrimordial'), cls: 'primary', value: 'boss' },
    ], { dismiss: false });
    c.paused = false;
    if (v === 'boss') {
      for (const tm of c.team) if (!tm.fainted) { tm.hp = tm.maxHp; tm.energy = 100; }
      c.startBoss();
    } else c.finish(true);
  },

  async defeatModal() {
    const c = this.combat;
    if (!c) return;
    c.paused = true;
    platform.gameplayStop();
    const cost = 150 + c.islandIdx * 80;
    const actions = [{ label: t('retreat'), value: 'retreat' }];
    if (c.revivesUsed < 2) {
      if (state.essence >= cost) actions.push({ label: `${t('revive')} · ${fmt(cost)} ${t('essenceShort')}`, value: 'essence' });
      if (platform.hasRewarded()) actions.push({ label: `${t('revive')} · ${t('ad')}`, cls: 'primary', value: 'ad' });
    }
    const v = await modal(t('teamFell'), `<p>${t('teamFellBody')}</p>`, actions, { dismiss: false });
    if (v === 'ad') {
      const ok = await platform.rewarded();
      if (ok) { c.paused = false; c.revive(); platform.gameplayStart(); return; }
      toast(t('adUnavailable'));
      return this.defeatModal();
    }
    if (v === 'essence') {
      state.essence -= cost;
      save();
      c.paused = false;
      c.revive();
      platform.gameplayStart();
      return;
    }
    c.paused = false;
    c.rewards.essence = Math.floor(c.rewards.essence * 0.5);
    c.rewards.xp = Math.floor(c.rewards.xp * 0.5);
    c.finish(false);
  },

  pause() {
    const c = this.combat;
    if (!c || c.paused) return;
    c.paused = true;
    platform.gameplayStop();
    modal(t('pause'), `<p class="muted">${L(ISLANDS[c.islandIdx].name)} · ${t('wave', { a: Math.min(c.waveIdx + 1, c.waveCount), b: c.waveCount })}</p>`, [
      { label: t('settings'), value: 'settings' },
      { label: t('abandon'), value: 'abandon' },
      { label: t('resume'), cls: 'primary', value: 'resume' },
    ]).then(async (v) => {
      if (v === 'settings') { await settingsModal(); c.paused = false; this.pause(); return; }
      if (v === 'abandon') {
        const ok = await modal(t('abandon'), `<p>${t('abandonBody')}</p>`, [{ label: t('cancel'), value: false }, { label: t('abandon'), cls: 'primary', value: true }]);
        if (ok) {
          c.paused = false;
          c.rewards.essence = Math.floor(c.rewards.essence * 0.5);
          c.rewards.xp = Math.floor(c.rewards.xp * 0.5);
          c.finish(false);
          return;
        }
        c.paused = false;
        this.pause();
        return;
      }
      c.paused = false;
      platform.gameplayStart();
      clearPressed();
    });
  },

  // Aplica las recompensas al estado y muestra los resultados.
  finishExpedition(victory, r, fought) {
    platform.gameplayStop();
    const c = this.combat;
    const idx = c.islandIdx;
    const res = { victory, rewards: r, xp: [], essence: r.essence, fragments: 0, crystals: 0, passXp: 0, contractsDone: [], newEntries: 0, unlocked: '' };
    // criaturas selladas
    for (const s of r.sealed) {
      const before = !!state.creatures[s.id];
      const out = addCreature(s.id, s.level, s.perfect);
      s.isNew = out.isNew;
      res.fragments += out.fragments;
      if (!before) res.newEntries++;
    }
    // jefe vencido: isla completada
    if (r.bossSealed) {
      const isl = ISLANDS[idx];
      const el = CREATURE[isl.boss].el;
      const first = !state.islands.cleared.includes(idx);
      const frags = first ? 12 : 6;
      state.fragments[el] = (state.fragments[el] || 0) + frags;
      res.fragments += frags;
      if (first) {
        state.islands.cleared.push(idx);
        state.stats.bosses++;
        res.crystals = 25;
        state.crystals += 25;
        if (idx + 1 < ISLANDS.length && state.islands.unlocked < idx + 1) {
          state.islands.unlocked = idx + 1;
          res.unlocked = L(ISLANDS[idx + 1].name);
        }
      }
    }
    // primer recorrido del tutorial: desbloquea la isla 1 completa
    state.essence += r.essence;
    // experiencia del equipo
    for (const id of c.team.map((f) => f.id)) {
      const own = state.creatures[id];
      const share = fought.includes(id) ? 1 : 0.5;
      const xp = Math.round(r.xp * share);
      const ups = giveXp(id, xp);
      own.bondXp += fought.includes(id) ? 12 : 4;
      addBondCheck(own);
      res.xp.push({ id, xp, ups, level: own.level });
    }
    const rankBefore = rankInfo().rank;
    state.rankXp += Math.round(r.xp * 0.6 + r.sealed.length * 25 + (r.bossSealed ? 150 : 0));
    const rankAfter = rankInfo().rank;
    if (rankAfter >= 10 && rankBefore < 10) setTimeout(() => toast(t('thirdSlot'), 'gold'), 1200);
    res.passXp = 30 + r.sealed.length * 10 + (r.bossSealed ? 40 : 0);
    addPassXp(res.passXp);
    state.stats.runs++;
    if (victory) res.contractsDone = progressContract('runs');
    res.contractsDone = [...res.contractsDone, ...state.contracts.list.filter((x) => x.progress >= x.goal && !x.claimed && !res.contractsDone.includes(x))];
    checkTitles();
    bestiaryMilestones();
    res.canDouble = victory && platform.hasRewarded() && r.essence > 0;
    saveNow();
    this.endCombat();
    this.current = 'results';
    document.body.classList.remove('in-combat');
    this.showcase.activate();
    playMusic('menu');
    resultsScreen(res);
    if (r.bossSealed || res.newEntries) sfx.sealPerfect(); else sfx.levelUp();
  },

  endCombat() {
    if (!this.combat) return;
    this.combat.dispose();
    this.combat = null;
    hideHud();
    document.body.classList.remove('in-combat');
  },

  // --- compras ----------------------------------------------------------
  async buyCosmetic(kind, id, after) {
    const item = kind === 'tint' ? TINT[id] : kind === 'seal' ? SEAL[id] : EFFECT[id];
    if (!item) return;
    const list = kind === 'tint' ? state.cosmetics.tints : kind === 'seal' ? state.cosmetics.seals : state.cosmetics.effects;
    if (list.includes(id)) return;
    const price = `${ICON.crystal.replace('<svg', '<svg style="width:1.1em;height:1.1em;vertical-align:-.15em"')} ${fmt(item.price)}`;
    if (state.crystals < item.price) {
      const go = await modal(t('notEnoughCrystals'), `<p>${t('needCrystals', { n: fmt(item.price - state.crystals) })}</p>`, [{ label: t('close'), value: false }, { label: t('getCrystals'), cls: 'primary', value: true }]);
      if (go) this.go('shop', { tab: platform.canBuy() ? 'crystals' : 'free' });
      return;
    }
    if (!(await confirmBuy(L(item.name), price))) return;
    state.crystals -= item.price;
    list.push(id);
    if (kind === 'tint' && state.creatures[item.creature]) state.creatures[item.creature].tint = id;
    if (kind === 'seal') state.cosmetics.seal = id;
    if (kind === 'effect') state.cosmetics.effect = id;
    saveNow();
    sfx.sealPerfect();
    toast(t('purchased', { name: L(item.name) }), 'gold');
    after?.();
  },

  async buyProduct(sku) {
    const p = PRODUCT[sku];
    if (!p) return;
    if (!platform.canBuy()) { toast(t('paymentsOff')); return; }
    const ok = await confirmBuy(L(p.name), `US$ ${p.usd.toFixed(2)}`);
    if (!ok) return;
    try {
      saveNow();
      await platform.buy(sku, document.documentElement.lang);
    } catch (e) {
      toast(t('paymentError'));
    }
  },

  // Tras volver de Stripe: concede el producto una sola vez por sesión de pago.
  grantProduct(sku, session) {
    const p = PRODUCT[sku];
    if (!p || state.purchases.sessions.includes(session)) return false;
    state.purchases.sessions.push(session);
    const g = p.grant;
    if (g.crystals) state.crystals += g.crystals;
    if (g.passPremium) state.pass.premium = true;
    if (g.noAds) { state.purchases.noAds = true; platform.noAds = true; }
    if (sku === 'fundador') state.purchases.founder = true;
    if (g.starterPrism) {
      const starter = Object.keys(state.creatures)[0] || 'fenix';
      const tid = `${starter}_prisma`;
      if (!state.cosmetics.tints.includes(tid)) state.cosmetics.tints.push(tid);
      if (state.creatures[starter]) state.creatures[starter].tint = tid;
    }
    for (const s of g.seals || []) if (!state.cosmetics.seals.includes(s)) state.cosmetics.seals.push(s);
    for (const e of g.effects || []) if (!state.cosmetics.effects.includes(e)) state.cosmetics.effects.push(e);
    saveNow();
    return true;
  },
};

export { grant, today };
