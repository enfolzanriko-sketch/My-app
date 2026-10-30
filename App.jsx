import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Plus, Check, Trash2, Flame, Pencil, ListChecks, StickyNote, Loader2,
  Sparkles, Trophy, CalendarCheck, Target, X,
} from 'lucide-react';

const FONT_DISPLAY = "'Unbounded', sans-serif";
const FONT_BODY = "'Manrope', sans-serif";
const FONT_MONO = "'JetBrains Mono', monospace";

const WEEKDAYS_SHORT = ['ВС', 'ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ'];
const WEEKDAYS_LONG = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
const MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

function pad(n) {
  return String(n).padStart(2, '0');
}

function todayStr(d = new Date()) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function longDate(d = new Date()) {
  return `${d.getDate()} ${MONTHS[d.getMonth()]}`;
}

function greeting(d = new Date()) {
  const h = d.getHours();
  if (h < 5) return 'Доброй ночи';
  if (h < 12) return 'Доброе утро';
  if (h < 18) return 'Добрый день';
  return 'Добрый вечер';
}

function calcStreak(completedDates) {
  const set = new Set(completedDates);
  let streak = 0;
  const cursor = new Date();
  if (!set.has(todayStr(cursor))) cursor.setDate(cursor.getDate() - 1);
  while (set.has(todayStr(cursor))) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
}

function last7Days() {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    days.push({ key: todayStr(d), label: WEEKDAYS_SHORT[d.getDay()], date: d.getDate() });
  }
  return days;
}

function motivation(pct, total) {
  if (total === 0) return 'Добавь первую привычку — и начнём.';
  if (pct === 100) return 'Идеальный день. Так держать!';
  if (pct >= 50) return 'Больше половины позади — дожимай.';
  if (pct > 0) return 'Хорошее начало. Следующая галочка ближе, чем кажется.';
  return 'Новый день — чистый лист. Начни с малого.';
}

function defaultHabits() {
  const now = todayStr();
  return [
    { id: 'h_pushups', name: 'Отжимания 10 раз', completedDates: [], createdAt: now },
    { id: 'h_teeth', name: 'Почистить зубы', completedDates: [], createdAt: now },
    { id: 'h_study', name: 'Уроки / учёба', completedDates: [], createdAt: now },
  ];
}

function defaultNotes() {
  return [
    {
      id: 'n_pushup_tech',
      title: 'Техника отжиманий',
      content: 'Спина прямая, локти примерно под 45° к корпусу, опускайся плавно, не задерживай дыхание.',
    },
    {
      id: 'n_study_rules',
      title: 'Во время учёбы нельзя',
      content: 'Брать телефон в руки во время занятия. Ставь таймер на 25 минут, потом перерыв 5 минут.',
    },
  ];
}

/* ---------- UI primitives ---------- */

function AuroraBackground() {
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-0 overflow-hidden">
      <div className="aurora-blob absolute -top-32 -left-24 w-[28rem] h-[28rem] rounded-full bg-amber-500/20 blur-3xl" />
      <div className="aurora-blob absolute top-40 -right-32 w-[24rem] h-[24rem] rounded-full bg-orange-600/10 blur-3xl" style={{ animationDelay: '-6s' }} />
      <div className="aurora-blob absolute bottom-0 left-1/4 w-[22rem] h-[22rem] rounded-full bg-indigo-500/10 blur-3xl" style={{ animationDelay: '-12s' }} />
      <div className="grain absolute inset-0 opacity-[0.035] mix-blend-overlay" />
    </div>
  );
}

function SpotlightCard({ className = '', children, as: Tag = 'div', ...rest }) {
  const ref = useRef(null);
  function onMove(e) {
    const el = ref.current;
    if (!el) return;
    const r = el.getBoundingClientRect();
    el.style.setProperty('--x', `${e.clientX - r.left}px`);
    el.style.setProperty('--y', `${e.clientY - r.top}px`);
  }
  return (
    <Tag
      ref={ref}
      onMouseMove={onMove}
      className={`group relative overflow-hidden rounded-2xl border border-white/[0.08] bg-slate-900/60 backdrop-blur-xl ${className}`}
      {...rest}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 opacity-0 transition-opacity duration-300 group-hover:opacity-100"
        style={{ background: 'radial-gradient(320px circle at var(--x) var(--y), rgba(251,191,36,0.10), transparent 60%)' }}
      />
      <div className="relative">{children}</div>
    </Tag>
  );
}

function ProgressRing({ value, size = 128, stroke = 10 }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c - (value / 100) * c;
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90" role="img" aria-label={`Выполнено ${value}%`}>
        <defs>
          <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#fde68a" />
            <stop offset="100%" stopColor="#f59e0b" />
          </linearGradient>
        </defs>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(148,163,184,0.12)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="url(#ring)"
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={offset}
          style={{ transition: 'stroke-dashoffset 700ms cubic-bezier(.2,.8,.2,1)', filter: 'drop-shadow(0 0 6px rgba(245,158,11,.45))' }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span style={{ fontFamily: FONT_DISPLAY }} className="text-3xl font-bold text-slate-50 tabular-nums">
          {value}
          <span className="text-base text-slate-400">%</span>
        </span>
        <span className="text-[11px] uppercase tracking-widest text-slate-400 mt-0.5">сегодня</span>
      </div>
    </div>
  );
}

function StatTile({ icon: Icon, label, value, delay }) {
  return (
    <SpotlightCard className="p-3.5 rise" style={{ animationDelay: delay }}>
      <Icon className="w-4 h-4 text-amber-400" aria-hidden="true" />
      <p style={{ fontFamily: FONT_DISPLAY }} className="text-xl font-bold text-slate-50 mt-2.5 tabular-nums">
        {value}
      </p>
      <p className="text-[11px] text-slate-400 mt-0.5 leading-tight">{label}</p>
    </SpotlightCard>
  );
}

function SegmentedTabs({ value, onChange, items }) {
  const idx = items.findIndex(i => i.value === value);
  return (
    <div role="tablist" className="relative grid grid-cols-2 p-1 rounded-xl bg-slate-900/70 border border-white/[0.08] backdrop-blur-xl">
      <div
        aria-hidden="true"
        className="absolute top-1 bottom-1 left-1 rounded-lg bg-gradient-to-b from-amber-400 to-amber-500 shadow-[0_4px_20px_-4px_rgba(245,158,11,.6)] transition-transform duration-300 ease-out"
        style={{ width: 'calc(50% - 4px)', transform: `translateX(${idx * 100}%)` }}
      />
      {items.map(({ value: v, label, icon: Icon, count }) => {
        const active = v === value;
        return (
          <button
            key={v}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(v)}
            className={`relative z-10 min-h-[44px] flex items-center justify-center gap-2 text-sm font-semibold rounded-lg cursor-pointer transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 ${
              active ? 'text-slate-950' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <Icon className="w-4 h-4" aria-hidden="true" />
            {label}
            <span
              style={{ fontFamily: FONT_MONO }}
              className={`text-[11px] px-1.5 rounded-md ${active ? 'bg-slate-950/15' : 'bg-white/5'}`}
            >
              {count}
            </span>
          </button>
        );
      })}
    </div>
  );
}

const inputCls =
  'w-full bg-slate-950/60 border border-white/[0.08] rounded-xl px-3.5 py-3 text-sm text-slate-100 placeholder-slate-500 outline-none transition focus:border-amber-400/60 focus:ring-4 focus:ring-amber-400/10';
const primaryBtn =
  'flex-1 min-h-[44px] bg-gradient-to-b from-amber-400 to-amber-500 text-slate-950 text-sm font-bold rounded-xl cursor-pointer transition hover:brightness-110 active:scale-[.98] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-200 shadow-[0_8px_24px_-8px_rgba(245,158,11,.7)]';
const ghostBtn =
  'min-h-[44px] px-4 text-slate-400 text-sm font-medium rounded-xl cursor-pointer transition hover:text-slate-200 hover:bg-white/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-500';
const iconBtn =
  'shrink-0 w-10 h-10 flex items-center justify-center rounded-xl text-slate-500 cursor-pointer transition hover:text-slate-200 hover:bg-white/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-slate-500';
const addBtn =
  'w-full min-h-[52px] flex items-center justify-center gap-2 rounded-2xl border border-dashed border-white/15 text-slate-400 text-sm font-medium cursor-pointer transition hover:border-amber-400/50 hover:text-amber-300 hover:bg-amber-400/[0.04] active:scale-[.99] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-400';

/* ---------- App ---------- */

export default function App() {
  const [tab, setTab] = useState('habits');
  const [habits, setHabits] = useState([]);
  const [notes, setNotes] = useState([]);
  const [ready, setReady] = useState(false);
  const [today, setToday] = useState(todayStr());
  const [saveError, setSaveError] = useState(false);

  const [addingHabit, setAddingHabit] = useState(false);
  const [habitInput, setHabitInput] = useState('');

  const [addingNote, setAddingNote] = useState(false);
  const [noteTitleInput, setNoteTitleInput] = useState('');
  const [noteContentInput, setNoteContentInput] = useState('');
  const [editingNoteId, setEditingNoteId] = useState(null);

  useEffect(() => {
    try {
      const savedHabits = localStorage.getItem('routine-tracker-habits');
      const savedNotes = localStorage.getItem('routine-tracker-notes');
      setHabits(savedHabits ? JSON.parse(savedHabits) : defaultHabits());
      setNotes(savedNotes ? JSON.parse(savedNotes) : defaultNotes());
    } catch (e) {
      setHabits(defaultHabits());
      setNotes(defaultNotes());
      setSaveError(true);
    }
    setReady(true);
  }, []);

  useEffect(() => {
    const id = setInterval(() => {
      const t = todayStr();
      setToday(prev => (prev !== t ? t : prev));
    }, 30000);
    return () => clearInterval(id);
  }, []);

  const saveHabits = useCallback(next => {
    setHabits(next);
    try {
      localStorage.setItem('routine-tracker-habits', JSON.stringify(next));
      setSaveError(false);
    } catch (e) {
      setSaveError(true);
    }
  }, []);

  const saveNotes = useCallback(next => {
    setNotes(next);
    try {
      localStorage.setItem('routine-tracker-notes', JSON.stringify(next));
      setSaveError(false);
    } catch (e) {
      setSaveError(true);
    }
  }, []);

  function toggleHabit(id) {
    const next = habits.map(h => {
      if (h.id !== id) return h;
      const done = h.completedDates.includes(today);
      return {
        ...h,
        completedDates: done ? h.completedDates.filter(d => d !== today) : [...h.completedDates, today],
      };
    });
    saveHabits(next);
  }

  function addHabit() {
    const name = habitInput.trim();
    if (!name) return;
    const next = [...habits, { id: 'h_' + Date.now(), name, completedDates: [], createdAt: today }];
    saveHabits(next);
    setHabitInput('');
    setAddingHabit(false);
  }

  function deleteHabit(id) {
    saveHabits(habits.filter(h => h.id !== id));
  }

  function startAddNote() {
    setEditingNoteId(null);
    setNoteTitleInput('');
    setNoteContentInput('');
    setAddingNote(true);
  }

  function startEditNote(note) {
    setEditingNoteId(note.id);
    setNoteTitleInput(note.title);
    setNoteContentInput(note.content);
    setAddingNote(true);
  }

  function cancelNote() {
    setAddingNote(false);
    setEditingNoteId(null);
    setNoteTitleInput('');
    setNoteContentInput('');
  }

  function saveNote() {
    const title = noteTitleInput.trim();
    const content = noteContentInput.trim();
    if (!title && !content) return;
    let next;
    if (editingNoteId) {
      next = notes.map(n => (n.id === editingNoteId ? { ...n, title, content } : n));
    } else {
      next = [...notes, { id: 'n_' + Date.now(), title, content }];
    }
    saveNotes(next);
    cancelNote();
  }

  function deleteNote(id) {
    saveNotes(notes.filter(n => n.id !== id));
    if (editingNoteId === id) cancelNote();
  }

  const doneCount = habits.filter(h => h.completedDates.includes(today)).length;
  const pct = habits.length ? Math.round((doneCount / habits.length) * 100) : 0;
  const weekDays = last7Days();
  const weekStats = weekDays.map(d => ({
    ...d,
    ratio: habits.length ? habits.filter(h => h.completedDates.includes(d.key)).length / habits.length : 0,
  }));
  const weekPct = Math.round((weekStats.reduce((s, d) => s + d.ratio, 0) / 7) * 100);
  const bestStreak = habits.reduce((m, h) => Math.max(m, calcStreak(h.completedDates)), 0);
  const totalChecks = habits.reduce((s, h) => s + h.completedDates.length, 0);

  if (!ready) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <Loader2 className="w-6 h-6 text-slate-500 animate-spin" aria-label="Загрузка" />
      </div>
    );
  }

  return (
    <div className="relative min-h-screen bg-slate-950 text-slate-100 antialiased" style={{ fontFamily: FONT_BODY }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Unbounded:wght@600;700&family=Manrope:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap');`}</style>
      <AuroraBackground />

      <main className="relative max-w-md mx-auto px-4 pt-8 pb-16" style={{ paddingTop: 'max(2rem, env(safe-area-inset-top))' }}>
        {/* Header */}
        <header className="flex items-center justify-between mb-6 rise">
          <div>
            <p className="text-sm text-slate-400">
              {WEEKDAYS_LONG[new Date().getDay()]}, {longDate()}
            </p>
            <h1 style={{ fontFamily: FONT_DISPLAY }} className="text-[26px] leading-tight font-bold tracking-tight mt-1">
              {greeting()}
              <span className="shimmer-text">.</span>
            </h1>
          </div>
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-amber-300 to-orange-500 flex items-center justify-center shadow-[0_8px_30px_-6px_rgba(245,158,11,.6)]">
            <Sparkles className="w-5 h-5 text-slate-950" aria-hidden="true" />
          </div>
        </header>

        {saveError && (
          <div role="alert" className="bg-red-950/70 border border-red-800/60 text-red-300 text-sm rounded-xl px-3.5 py-2.5 mb-4">
            Не удалось сохранить изменения. Проверь хранилище браузера и попробуй ещё раз.
          </div>
        )}

        {/* Hero: today's progress */}
        <SpotlightCard className="p-5 rise" style={{ animationDelay: '60ms' }}>
          <div
            aria-hidden="true"
            className="absolute -top-16 -right-16 w-48 h-48 rounded-full bg-amber-400/10 blur-2xl"
          />
          <div className="flex items-center gap-5">
            <ProgressRing value={pct} />
            <div className="min-w-0">
              <p className="text-xs uppercase tracking-widest text-amber-300/90 font-semibold">Прогресс дня</p>
              <p style={{ fontFamily: FONT_DISPLAY }} className="text-2xl font-bold mt-1.5 tabular-nums">
                {doneCount}
                <span className="text-slate-500"> / {habits.length}</span>
              </p>
              <p className="text-sm text-slate-300 mt-1.5 leading-snug">{motivation(pct, habits.length)}</p>
            </div>
          </div>

          {/* Week heat strip */}
          <div className="mt-5 pt-4 border-t border-white/[0.06]">
            <div className="flex items-end justify-between gap-1.5" aria-label="Выполнение за последние 7 дней">
              {weekStats.map(d => {
                const isToday = d.key === today;
                return (
                  <div key={d.key} className="flex-1 flex flex-col items-center gap-1.5">
                    <div className="relative w-full h-14 rounded-lg bg-white/[0.04] overflow-hidden">
                      <div
                        className={`absolute inset-x-0 bottom-0 rounded-lg transition-all duration-700 ${
                          isToday ? 'bg-gradient-to-t from-amber-500 to-amber-300' : 'bg-gradient-to-t from-amber-600/70 to-amber-400/60'
                        }`}
                        style={{ height: `${Math.max(d.ratio * 100, d.ratio > 0 ? 8 : 0)}%` }}
                      />
                    </div>
                    <span
                      style={{ fontFamily: FONT_MONO }}
                      className={`text-[10px] ${isToday ? 'text-amber-300 font-medium' : 'text-slate-500'}`}
                    >
                      {d.label}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </SpotlightCard>

        {/* Bento stats */}
        <div className="grid grid-cols-3 gap-2.5 mt-2.5">
          <StatTile icon={Flame} label="лучшая серия, дней" value={bestStreak} delay="120ms" />
          <StatTile icon={Target} label="за неделю" value={`${weekPct}%`} delay="160ms" />
          <StatTile icon={Trophy} label="всего отметок" value={totalChecks} delay="200ms" />
        </div>

        {/* Tabs */}
        <div className="mt-6 mb-4 rise" style={{ animationDelay: '240ms' }}>
          <SegmentedTabs
            value={tab}
            onChange={setTab}
            items={[
              { value: 'habits', label: 'Привычки', icon: ListChecks, count: habits.length },
              { value: 'notes', label: 'Заметки', icon: StickyNote, count: notes.length },
            ]}
          />
        </div>

        {tab === 'habits' && (
          <section className="space-y-2.5" aria-label="Привычки">
            {habits.map((h, i) => {
              const done = h.completedDates.includes(today);
              const streak = calcStreak(h.completedDates);
              const dateSet = new Set(h.completedDates);
              return (
                <SpotlightCard
                  key={h.id}
                  className={`p-3 rise transition-colors ${done ? 'border-amber-400/25 bg-amber-400/[0.04]' : ''}`}
                  style={{ animationDelay: `${280 + i * 40}ms` }}
                >
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => toggleHabit(h.id)}
                      aria-pressed={done}
                      aria-label={done ? `Снять отметку: ${h.name}` : `Отметить: ${h.name}`}
                      className={`shrink-0 w-12 h-12 rounded-xl flex items-center justify-center cursor-pointer transition-all duration-200 active:scale-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-amber-300 ${
                        done
                          ? 'bg-gradient-to-br from-amber-300 to-amber-500 shadow-[0_6px_20px_-6px_rgba(245,158,11,.8)]'
                          : 'bg-slate-950/50 border-2 border-slate-700 hover:border-amber-400/60'
                      }`}
                    >
                      {done && <Check key={today} className="pop w-6 h-6 text-slate-950" strokeWidth={3} />}
                    </button>
                    <div className="flex-1 min-w-0">
                      <p className={`text-[15px] font-semibold truncate transition-colors ${done ? 'text-slate-400 line-through decoration-amber-400/60' : 'text-slate-50'}`}>
                        {h.name}
                      </p>
                      <div className="flex items-center gap-3 mt-2">
                        <div className="flex gap-1" aria-label="Последние 7 дней">
                          {weekDays.map(wd => (
                            <div
                              key={wd.key}
                              title={wd.label}
                              className={`w-2.5 h-2.5 rounded-[4px] transition-colors ${
                                dateSet.has(wd.key) ? 'bg-amber-400' : 'bg-white/[0.07]'
                              } ${wd.key === today ? 'ring-1 ring-amber-300/50 ring-offset-1 ring-offset-slate-900' : ''}`}
                            />
                          ))}
                        </div>
                        {streak > 0 && (
                          <span className="flex items-center gap-1 text-xs text-amber-300 bg-amber-400/10 rounded-full px-2 py-0.5">
                            <Flame className="w-3 h-3" aria-hidden="true" />
                            <span style={{ fontFamily: FONT_MONO }}>{streak}</span>
                          </span>
                        )}
                      </div>
                    </div>
                    <button onClick={() => deleteHabit(h.id)} aria-label={`Удалить привычку: ${h.name}`} className={`${iconBtn} hover:!text-red-400`}>
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </SpotlightCard>
              );
            })}

            {habits.length === 0 && !addingHabit && (
              <div className="text-center py-8">
                <CalendarCheck className="w-8 h-8 text-slate-600 mx-auto" aria-hidden="true" />
                <p className="text-sm text-slate-400 mt-3">Добавь то, что хочешь делать каждый день</p>
              </div>
            )}

            {addingHabit ? (
              <SpotlightCard className="p-3.5 rise">
                <label htmlFor="habit-input" className="sr-only">Название привычки</label>
                <input
                  id="habit-input"
                  autoFocus
                  value={habitInput}
                  onChange={e => setHabitInput(e.target.value)}
                  onKeyDown={e => {
                    if (e.key === 'Enter') addHabit();
                    if (e.key === 'Escape') setAddingHabit(false);
                  }}
                  placeholder="Например: 10 отжиманий"
                  className={inputCls}
                />
                <div className="flex gap-2 mt-2.5">
                  <button onClick={addHabit} disabled={!habitInput.trim()} className={`${primaryBtn} disabled:opacity-40 disabled:cursor-not-allowed`}>
                    Добавить
                  </button>
                  <button
                    onClick={() => {
                      setAddingHabit(false);
                      setHabitInput('');
                    }}
                    className={ghostBtn}
                  >
                    Отмена
                  </button>
                </div>
              </SpotlightCard>
            ) : (
              <button onClick={() => setAddingHabit(true)} className={addBtn}>
                <Plus className="w-4 h-4" aria-hidden="true" />
                Новая привычка
              </button>
            )}
          </section>
        )}

        {tab === 'notes' && (
          <section className="space-y-2.5" aria-label="Заметки">
            {notes.map((n, i) => (
              <SpotlightCard key={n.id} className="p-4 rise" style={{ animationDelay: `${i * 40}ms` }}>
                <div aria-hidden="true" className="absolute left-0 top-4 bottom-4 w-[3px] rounded-r-full bg-gradient-to-b from-amber-300 to-orange-500" />
                <div className="flex items-start justify-between gap-2 pl-2">
                  <div className="min-w-0 pt-1">
                    <h3 className="text-[15px] font-bold text-slate-50">{n.title}</h3>
                    {n.content && <p className="text-sm text-slate-300 mt-1.5 leading-relaxed whitespace-pre-wrap">{n.content}</p>}
                  </div>
                  <div className="flex -mr-1.5 -mt-1.5 shrink-0">
                    <button onClick={() => startEditNote(n)} aria-label={`Редактировать: ${n.title}`} className={iconBtn}>
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button onClick={() => deleteNote(n.id)} aria-label={`Удалить: ${n.title}`} className={`${iconBtn} hover:!text-red-400`}>
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </SpotlightCard>
            ))}

            {notes.length === 0 && !addingNote && (
              <div className="text-center py-8">
                <StickyNote className="w-8 h-8 text-slate-600 mx-auto" aria-hidden="true" />
                <p className="text-sm text-slate-400 mt-3">
                  Здесь храни то, что просто нужно помнить — без ежедневных галочек
                </p>
              </div>
            )}

            {addingNote ? (
              <SpotlightCard className="p-3.5 rise">
                <div className="flex items-center justify-between mb-2.5">
                  <p className="text-xs uppercase tracking-widest text-amber-300/90 font-semibold">
                    {editingNoteId ? 'Редактирование' : 'Новая заметка'}
                  </p>
                  <button onClick={cancelNote} aria-label="Закрыть" className={`${iconBtn} w-8 h-8`}>
                    <X className="w-4 h-4" />
                  </button>
                </div>
                <label htmlFor="note-title" className="sr-only">Заголовок</label>
                <input
                  id="note-title"
                  autoFocus
                  value={noteTitleInput}
                  onChange={e => setNoteTitleInput(e.target.value)}
                  placeholder="Заголовок"
                  className={`${inputCls} mb-2`}
                />
                <label htmlFor="note-content" className="sr-only">Текст заметки</label>
                <textarea
                  id="note-content"
                  value={noteContentInput}
                  onChange={e => setNoteContentInput(e.target.value)}
                  placeholder="Что нужно запомнить..."
                  rows={3}
                  className={`${inputCls} resize-none`}
                />
                <div className="flex gap-2 mt-2.5">
                  <button onClick={saveNote} className={primaryBtn}>
                    Сохранить
                  </button>
                  <button onClick={cancelNote} className={ghostBtn}>
                    Отмена
                  </button>
                </div>
              </SpotlightCard>
            ) : (
              <button onClick={startAddNote} className={addBtn}>
                <Plus className="w-4 h-4" aria-hidden="true" />
                Новая заметка
              </button>
            )}
          </section>
        )}
      </main>
    </div>
  );
}
