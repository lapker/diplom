/**
 * Утилиты TileCRM
 */

// ── Авторизация ──────────────────────────────────────────────────────────────

const auth = {
  getUser() {
    try { return JSON.parse(sessionStorage.getItem('crm_user') || 'null'); }
    catch { return null; }
  },
  setUser(u) { sessionStorage.setItem('crm_user', JSON.stringify(u)); },
  clear()    { sessionStorage.removeItem('crm_user'); },
  isLoggedIn() { return !!this.getUser(); },
  isAdmin()    { return this.getUser()?.role === 'admin'; },
  isManager()  { return this.getUser()?.role === 'manager'; },

  /** Редирект на логин если не авторизован (async — проверяет сессию на сервере) */
  requireAuth(redirectTo = 'login.html') {
    if (!this.isLoggedIn()) {
      // Пробуем восстановить сессию с сервера
      fetch('/api/auth/me', { credentials: 'include' })
        .then(r => r.ok ? r.json() : Promise.reject())
        .then(user => {
          this.setUser(user);
          // Перезагружаем страницу — теперь sessionStorage заполнен
          window.location.reload();
        })
        .catch(() => {
          window.location.href = redirectTo;
        });
      return false;
    }
    return true;
  },
  /** Редирект если не администратор */
  requireAdmin() {
    if (!this.requireAuth()) return false;
    if (!this.isAdmin()) {
      window.location.href = 'dashboard.html';
      return false;
    }
    return true;
  },
};

// ── Toast уведомления ────────────────────────────────────────────────────────

const toast = (() => {
  let container;
  function getContainer() {
    if (!container) {
      container = document.createElement('div');
      container.className = 'toast-container';
      document.body.appendChild(container);
    }
    return container;
  }

  const icons = { success: '✅', error: '❌', warning: '⚠️', info: 'ℹ️' };

  return {
    show(msg, type = 'info', duration = 4000) {
      const c = getContainer();
      const el = document.createElement('div');
      el.className = `toast ${type}`;
      el.innerHTML = `
        <span class="toast-icon">${icons[type] || icons.info}</span>
        <span class="toast-msg">${msg}</span>
        <button class="toast-close" onclick="this.parentElement.remove()">✕</button>
      `;
      c.appendChild(el);
      if (duration > 0) {
        setTimeout(() => {
          el.style.animation = 'fadeOut .3s ease forwards';
          setTimeout(() => el.remove(), 300);
        }, duration);
      }
    },
    success: (m, d) => toast.show(m, 'success', d),
    error:   (m, d) => toast.show(m, 'error',   d),
    warning: (m, d) => toast.show(m, 'warning', d),
    info:    (m, d) => toast.show(m, 'info',    d),
  };
})();

// ── Модальные окна ───────────────────────────────────────────────────────────

const modal = {
  open(id)  {
    const el = document.getElementById(id);
    if (el) { el.classList.add('open'); document.body.style.overflow = 'hidden'; }
  },
  close(id) {
    const el = document.getElementById(id);
    if (el) { el.classList.remove('open'); document.body.style.overflow = ''; }
  },
  closeAll() {
    document.querySelectorAll('.modal-overlay.open').forEach(el => {
      el.classList.remove('open');
    });
    document.body.style.overflow = '';
  },
};

// Закрытие по клику на оверлей
document.addEventListener('click', e => {
  if (e.target.classList.contains('modal-overlay')) modal.closeAll();
});
// Закрытие по Escape
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') modal.closeAll();
});

// ── Форматирование ───────────────────────────────────────────────────────────

const fmt = {
  money(v) {
    if (v == null) return '—';
    const num = parseFloat(v);
    if (isNaN(num)) return '—';
    // Белорусские рубли (BYN)
    return new Intl.NumberFormat('ru-BY', { style: 'currency', currency: 'BYN', maximumFractionDigits: 2 }).format(num);
  },
  date(v) {
    if (!v) return '—';
    const d = new Date(v);
    if (isNaN(d)) return v;
    return d.toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric' });
  },
  datetime(v) {
    if (!v) return '—';
    const d = new Date(v);
    if (isNaN(d)) return v;
    return d.toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  },
  initials(name) {
    if (!name) return '?';
    return name.split(' ').slice(0, 2).map(w => w[0]).join('').toUpperCase();
  },
  /**
   * Форматирует белорусский номер телефона для отображения.
   * Принимает: +375291234567 или 80291234567
   * Возвращает: +375 (29) 123-45-67 или 8 (029) 123-45-67
   */
  phone(v) {
    if (!v) return '—';
    return formatByPhone(v) || v;
  },
};

// ── Статусы клиентов ─────────────────────────────────────────────────────────

const STATUS_BADGE = {
  'Новый':      'badge-primary',
  'Активный':   'badge-success',
  'Постоянный': 'badge-warning',
  'Неактивный': 'badge-secondary',
  'Потерянный': 'badge-danger',
};

function statusBadge(name) {
  const cls = STATUS_BADGE[name] || 'badge-secondary';
  return `<span class="badge ${cls}">${name || '—'}</span>`;
}

// ── Sidebar ──────────────────────────────────────────────────────────────────

function initSidebar(activePage) {
  const user = auth.getUser();
  if (!user) return;

  // Заполняем данные пользователя
  const nameEl = document.getElementById('sidebarUserName');
  const roleEl = document.getElementById('sidebarUserRole');
  const avatarEl = document.getElementById('sidebarAvatar');
  if (nameEl) nameEl.textContent = user.fullname;
  if (roleEl) roleEl.textContent = user.role === 'admin' ? 'Администратор' : 'Менеджер';
  if (avatarEl) avatarEl.textContent = fmt.initials(user.fullname);

  // Активный пункт меню
  document.querySelectorAll('.nav-item[data-page]').forEach(el => {
    el.classList.toggle('active', el.dataset.page === activePage);
  });

  // Скрываем/показываем admin-only пункты
  document.querySelectorAll('[data-role="admin"]').forEach(el => {
    el.style.display = user.role === 'admin' ? '' : 'none';
  });
  document.querySelectorAll('[data-role="manager"]').forEach(el => {
    el.style.display = user.role === 'manager' ? '' : 'none';
  });

  // Кнопка выхода
  const logoutBtn = document.getElementById('logoutBtn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async () => {
      try { await api.logout(); } catch {}
      auth.clear();
      window.location.href = 'login.html';
    });
  }

  // Всегда показываем "Мои КП" в сайдбаре для всех пользователей (и менеджеров, и админов)
  // "Мои КП" показывает КП только для клиентов, закреплённых за текущим пользователем
  const navMyOffers = document.getElementById('navMyOffers');
  if (navMyOffers) {
    navMyOffers.style.display = '';
    navMyOffers.removeAttribute('data-role');
    // Убеждаемся что ссылка ведёт на offers.html?my=1
    navMyOffers.setAttribute('onclick', "navigate('offers.html?my=1')");
  }

  // Мобильный toggle
  const toggle = document.getElementById('sidebarToggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebarOverlay');
  if (toggle && sidebar) {
    toggle.addEventListener('click', () => {
      sidebar.classList.toggle('open');
      overlay?.classList.toggle('open');
    });
    overlay?.addEventListener('click', () => {
      sidebar.classList.remove('open');
      overlay.classList.remove('open');
    });
  }

  // Добавляем служебные кнопки в нижнюю часть сайдбара (перед sidebar-footer)
  const sidebarEl = document.getElementById('sidebar');
  const footer = sidebarEl ? sidebarEl.querySelector('.sidebar-footer') : null;

  if (sidebarEl && footer) {
    // ── Кнопка FAQ ──────────────────────────────────────────
    if (!document.getElementById('faqSidebarBtn')) {
      const faqBtn = document.createElement('button');
      faqBtn.id = 'faqSidebarBtn';
      faqBtn.className = 'nav-item' + (activePage === 'faq' ? ' active' : '');
      faqBtn.setAttribute('data-page', 'faq');
      faqBtn.title = 'Часто задаваемые вопросы';
      faqBtn.innerHTML = '<span class="nav-icon">❓</span> Помощь / FAQ';
      faqBtn.onclick = () => navigate('faq.html');
      sidebarEl.insertBefore(faqBtn, footer);
    }

    // ── Кнопка уведомлений (только для залогиненных) ─────────
    if (!document.getElementById('notifBellBtn')) {
      const bellBtn = document.createElement('button');
      bellBtn.id = 'notifBellBtn';
      bellBtn.className = 'nav-item' + (activePage === 'notifications' ? ' active' : '');
      bellBtn.setAttribute('data-page', 'notifications');
      bellBtn.title = 'Уведомления';
      bellBtn.innerHTML = '<span class="nav-icon">🔔</span> Уведомления <span id="notifBellBadge" style="display:none;background:#dc2626;color:#fff;border-radius:10px;padding:1px 6px;font-size:.65rem;font-weight:700;margin-left:4px"></span>';
      bellBtn.onclick = () => navigate('notifications.html');
      sidebarEl.insertBefore(bellBtn, footer);

      // Загружаем счётчик уведомлений
      api.getNotifications().then(notifs => {
        const count = notifs.filter(n => n.type === 'overdue' || n.type === 'today').length;
        const badge = document.getElementById('notifBellBadge');
        if (badge) {
          if (count > 0) {
            badge.textContent = count > 9 ? '9+' : String(count);
            badge.style.display = 'inline-block';
          } else {
            badge.style.display = 'none';
          }
        }
      }).catch(() => {});
    }
  }
}

// ── Навигация ────────────────────────────────────────────────────────────────

function navigate(page) {
  window.location.href = page;
}

// ── Загрузка справочников ────────────────────────────────────────────────────

let _refs = null;
async function loadReferences() {
  if (_refs) return _refs;
  _refs = await api.getReferences();
  return _refs;
}

function fillSelect(selectEl, items, valueKey, labelKey, placeholder = 'Выберите...') {
  selectEl.innerHTML = `<option value="">${placeholder}</option>`;
  items.forEach(item => {
    const opt = document.createElement('option');
    opt.value = item[valueKey];
    opt.textContent = item[labelKey];
    selectEl.appendChild(opt);
  });
}

// ── Телефоны (Беларусь) ──────────────────────────────────────────────────────

/**
 * Форматирует белорусский номер для отображения.
 * +375291234567  → +375 (29) 123-45-67
 * 80291234567    → 8 (029) 123-45-67
 */
function formatByPhone(raw) {
  if (!raw) return '';
  const digits = raw.replace(/\D/g, '');

  // Международный: +375 XX XXXXXXX (12 цифр без +)
  if (digits.startsWith('375') && digits.length === 12) {
    const code = digits.slice(3, 5);
    const num  = digits.slice(5);
    return `+375 (${code}) ${num.slice(0,3)}-${num.slice(3,5)}-${num.slice(5,7)}`;
  }
  // Внутренний: 80XXXXXXXXX (11 цифр)
  if (digits.startsWith('80') && digits.length === 11) {
    const code = digits.slice(1, 4);
    const num  = digits.slice(4);
    return `8 (0${code.slice(1)}) ${num.slice(0,3)}-${num.slice(3,5)}-${num.slice(5,7)}`;
  }
  return raw; // вернуть как есть если не распознан
}

/**
 * Валидирует белорусский номер телефона.
 * Допустимые форматы (без пробелов/скобок):
 *   +375XXXXXXXXX (12 цифр после +)
 *   80XXXXXXXXX   (11 цифр)
 * Код зоны — любые 2 цифры.
 */
function validateByPhone(raw) {
  if (!raw) return false;
  const digits = raw.replace(/\D/g, '');
  if (digits.startsWith('375') && digits.length === 12) return true;
  if (digits.startsWith('80')  && digits.length === 11) return true;
  return false;
}

/**
 * Нормализует номер (убирает лишние символы) для хранения.
 * Возвращает строку вида +375291234567 или 80291234567.
 */
function normalizePhone(raw) {
  if (!raw) return '';
  const digits = raw.replace(/\D/g, '');
  if (digits.startsWith('375') && digits.length === 12) return '+' + digits;
  if (digits.startsWith('80')  && digits.length === 11) return digits;
  return raw.trim();
}

// ── Email валидация ───────────────────────────────────────────────────────────

function validateEmail(email) {
  if (!email || email.trim() === '') return true; // пустой — допустимо
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

// ── Дата: запрет будущих дат ─────────────────────────────────────────────────

/** Устанавливает max=сегодня для date-input */
function setMaxToday(inputEl) {
  if (!inputEl) return;
  inputEl.max = new Date().toISOString().split('T')[0];
}

/** Проверяет, что дата не в будущем */
function validateNotFuture(dateStr) {
  if (!dateStr) return true;
  return new Date(dateStr) <= new Date();
}

// ── Обновление бейджа уведомлений ────────────────────────────────────────────

/**
 * Перезагружает счётчик уведомлений в sidebar.
 * Вызывается из notifications.html после выполнения задачи.
 */
function refreshNotifBadge() {
  const badge = document.getElementById('notifBellBadge');
  if (!badge) return;
  api.getNotifications().then(notifs => {
    const count = notifs.filter(n => n.type === 'overdue' || n.type === 'today').length;
    if (count > 0) {
      badge.textContent = count > 9 ? '9+' : String(count);
      badge.style.display = 'inline-block';
    } else {
      badge.style.display = 'none';
      badge.textContent = '';
    }
  }).catch(() => {});
}

// ── Экспорт ──────────────────────────────────────────────────────────────────

window.auth  = auth;
window.toast = toast;
window.modal = modal;
window.fmt   = fmt;
window.statusBadge    = statusBadge;
window.initSidebar    = initSidebar;
window.navigate       = navigate;
window.loadReferences = loadReferences;
window.fillSelect     = fillSelect;
window.formatByPhone  = formatByPhone;
window.validateByPhone = validateByPhone;
window.normalizePhone = normalizePhone;
window.validateEmail  = validateEmail;
window.setMaxToday    = setMaxToday;
window.validateNotFuture = validateNotFuture;
window.refreshNotifBadge = refreshNotifBadge;
