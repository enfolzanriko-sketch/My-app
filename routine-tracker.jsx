import React, { useState, useEffect, useCallback } from 'react';
import { Plus, Check, Trash2, Flame, Pencil, ListChecks, StickyNote, Loader2 } from 'lucide-react';

const FONT_DISPLAY = "'Unbounded', sans-serif";
const FONT_BODY = "'Manrope', sans-serif";
const FONT_MONO = "'JetBrains Mono', monospace";

function pad(n) {
  return String(n).padStart(2, '0');
}

function todayStr(d = new Date()) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function logDate(d = new Date()) {
  const days = ['ВС', 'ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ'];
  return `${days[d.getDay()]} ${pad(d.getDate())}.${pad(d.getMonth() + 1)}`;
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
    days.push(todayStr(d));
  }
  return days;
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
    (async () => {
      let h = defaultHabits();
      let n = defaultNotes();
      try {
        const r = await window.storage.get('habits');
        if (r && r.value) h = JSON.parse(r.value);
      } catch (e) {
        // no saved habits yet, use defaults
      }
      try {
        const r = await window.storage.get('notes');
        if (r && r.value) n = JSON.parse(r.value);
      } catch (e) {
        // no saved notes yet, use defaults
      }
      setHabits(h);
      setNotes(n);
      setReady(true);
    })();
  }, []);

  useEffect(() => {
    const id = setInterval(() => {
      const t = todayStr();
      setToday(prev => (prev !== t ? t : prev));
    }, 30000);
    return () => clearInterval(id);
  }, []);

  const saveHabits = useCallback(async next => {
    setHabits(next);
    try {
      const res = await window.storage.set('habits', JSON.stringify(next));
      setSaveError(!res);
    } catch (e) {
      setSaveError(true);
    }
  }, []);

  const saveNotes = useCallback(async next => {
    setNotes(next);
    try {
      const res = await window.storage.set('notes', JSON.stringify(next));
      setSaveError(!res);
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
    setAddingNote(false);
    setEditingNoteId(null);
    setNoteTitleInput('');
    setNoteContentInput('');
  }

  function deleteNote(id) {
    saveNotes(notes.filter(n => n.id !== id));
    if (editingNoteId === id) {
      setAddingNote(false);
      setEditingNoteId(null);
    }
  }

  const doneCount = habits.filter(h => h.completedDates.includes(today)).length;
  const weekDays = last7Days();

  if (!ready) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <Loader2 className="w-6 h-6 text-slate-600 animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-slate-950" style={{ fontFamily: FONT_BODY }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Unbounded:wght@700&family=Manrope:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');`}</style>

      <div className="max-w-md mx-auto px-4 pt-6 pb-10">
        <header className="flex items-start justify-between mb-6">
          <div>
            <h1 style={{ fontFamily: FONT_DISPLAY }} className="text-2xl font-bold tracking-tight text-slate-100">
              Рутина
            </h1>
            <p className="text-sm text-slate-400 mt-1.5">
              {habits.length > 0 ? `Сегодня: ${doneCount} из ${habits.length}` : 'Начни с первой привычки'}
            </p>
          </div>
          <div style={{ fontFamily: FONT_MONO }} className="text-xs text-slate-600 pt-1.5 tracking-wide">
            {logDate()}
          </div>
        </header>

        {saveError && (
          <div className="bg-red-950 border border-red-900 text-red-400 text-xs rounded-lg px-3 py-2 mb-4">
            Не удалось сохранить изменения. Проверь соединение и попробуй ещё раз.
          </div>
        )}

        <div className="flex border-b border-slate-800 mb-5">
          <button
            onClick={() => setTab('habits')}
            className={`flex-1 pb-3 -mb-px flex items-center justify-center gap-1.5 text-xs font-semibold uppercase tracking-wide border-b-2 transition ${
              tab === 'habits' ? 'text-amber-400 border-amber-400' : 'text-slate-500 border-transparent'
            }`}
          >
            <ListChecks className="w-4 h-4" />
            Журнал
          </button>
          <button
            onClick={() => setTab('notes')}
            className={`flex-1 pb-3 -mb-px flex items-center justify-center gap-1.5 text-xs font-semibold uppercase tracking-wide border-b-2 transition ${
              tab === 'notes' ? 'text-amber-400 border-amber-400' : 'text-slate-500 border-transparent'
            }`}
          >
            <StickyNote className="w-4 h-4" />
            Заметки
          </button>
        </div>

        {tab === 'habits' && (
          <div className="space-y-2.5">
            {habits.map(h => {
              const done = h.completedDates.includes(today);
              const streak = calcStreak(h.completedDates);
              const dateSet = new Set(h.completedDates);
              return (
                <div key={h.id} className="bg-slate-900 border border-slate-800 rounded-lg p-3.5 flex items-center gap-3">
                  <button
                    onClick={() => toggleHabit(h.id)}
                    className={`shrink-0 w-10 h-10 rounded-full flex items-center justify-center transition active:scale-95 ${
                      done ? 'bg-amber-500 rotate-2' : 'bg-slate-900 border-2 border-slate-700'
                    }`}
                  >
                    {done && <Check className="w-5 h-5 text-slate-950" />}
                  </button>
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-medium truncate ${done ? 'text-slate-500 line-through' : 'text-slate-100'}`}>
                      {h.name}
                    </p>
                    <div className="flex items-center gap-2.5 mt-2">
                      <div className="flex gap-1">
                        {weekDays.map(wd => (
                          <div key={wd} className={`w-1 h-3 rounded-sm ${dateSet.has(wd) ? 'bg-amber-400' : 'bg-slate-800'}`} />
                        ))}
                      </div>
                      {streak > 0 && (
                        <span className="flex items-center gap-1 text-xs text-amber-400">
                          <Flame className="w-3 h-3" />
                          <span style={{ fontFamily: FONT_MONO }}>{streak}</span>
                        </span>
                      )}
                    </div>
                  </div>
                  <button onClick={() => deleteHabit(h.id)} className="shrink-0 text-slate-600 p-1.5">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              );
            })}

            {habits.length === 0 && !addingHabit && (
              <p className="text-sm text-slate-600 text-center py-4">Добавь то, что хочешь делать каждый день</p>
            )}

            {addingHabit ? (
              <div className="bg-slate-900 border border-slate-800 rounded-lg p-3.5">
                <input
                  autoFocus
                  value={habitInput}
                  onChange={e => setHabitInput(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && addHabit()}
                  placeholder="Например: 10 отжиманий"
                  className="w-full bg-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 placeholder-slate-500 outline-none focus:ring-2 focus:ring-amber-500"
                />
                <div className="flex gap-2 mt-2.5">
                  <button
                    onClick={addHabit}
                    className="flex-1 bg-amber-500 text-slate-950 text-sm font-semibold py-2 rounded-md transition active:scale-95"
                  >
                    Добавить
                  </button>
                  <button
                    onClick={() => {
                      setAddingHabit(false);
                      setHabitInput('');
                    }}
                    className="px-3 py-2 text-slate-500 text-sm"
                  >
                    Отмена
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={() => setAddingHabit(true)}
                className="w-full flex items-center justify-center gap-1.5 py-3 rounded-lg border border-dashed border-slate-700 text-slate-500 text-sm transition active:scale-95"
              >
                <Plus className="w-4 h-4" />
                Добавить привычку
              </button>
            )}
          </div>
        )}

        {tab === 'notes' && (
          <div className="space-y-2.5">
            {notes.map(n => (
              <div key={n.id} className="bg-slate-900 border-l-2 border-slate-600 rounded-r-lg p-3.5">
                <div className="flex items-start justify-between gap-2">
                  <h3 className="text-sm font-semibold text-slate-100">{n.title}</h3>
                  <div className="flex gap-1 shrink-0">
                    <button onClick={() => startEditNote(n)} className="text-slate-600 p-1.5">
                      <Pencil className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={() => deleteNote(n.id)} className="text-slate-600 p-1.5">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
                {n.content && <p className="text-sm text-slate-400 mt-1.5 whitespace-pre-wrap">{n.content}</p>}
              </div>
            ))}

            {notes.length === 0 && !addingNote && (
              <p className="text-sm text-slate-600 text-center py-4">
                Здесь храни то, что просто нужно помнить — без ежедневных галочек
              </p>
            )}

            {addingNote ? (
              <div className="bg-slate-900 border border-slate-800 rounded-lg p-3.5">
                <input
                  autoFocus
                  value={noteTitleInput}
                  onChange={e => setNoteTitleInput(e.target.value)}
                  placeholder="Заголовок"
                  className="w-full bg-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 placeholder-slate-500 outline-none focus:ring-2 focus:ring-amber-500 mb-2"
                />
                <textarea
                  value={noteContentInput}
                  onChange={e => setNoteContentInput(e.target.value)}
                  placeholder="Что нужно запомнить..."
                  rows={3}
                  className="w-full bg-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 placeholder-slate-500 outline-none focus:ring-2 focus:ring-amber-500 resize-none"
                />
                <div className="flex gap-2 mt-2.5">
                  <button
                    onClick={saveNote}
                    className="flex-1 bg-amber-500 text-slate-950 text-sm font-semibold py-2 rounded-md transition active:scale-95"
                  >
                    Сохранить
                  </button>
                  <button
                    onClick={() => {
                      setAddingNote(false);
                      setEditingNoteId(null);
                      setNoteTitleInput('');
                      setNoteContentInput('');
                    }}
                    className="px-3 py-2 text-slate-500 text-sm"
                  >
                    Отмена
                  </button>
                </div>
              </div>
            ) : (
              <button
                onClick={startAddNote}
                className="w-full flex items-center justify-center gap-1.5 py-3 rounded-lg border border-dashed border-slate-700 text-slate-500 text-sm transition active:scale-95"
              >
                <Plus className="w-4 h-4" />
                Добавить заметку
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
