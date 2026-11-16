const menuToggle = document.querySelector('.menu-toggle');
const primaryNav = document.querySelector('.primary-nav');
const settingsDialog = document.querySelector('#settings-dialog');
const signInDialog = document.querySelector('#sign-in-dialog');
const signInButton = document.querySelector('.sign-in-open');
const signInForm = document.querySelector('#email-signin-form');
const signInEmail = document.querySelector('#signin-email');
const signInCode = document.querySelector('#signin-code');
const signInCodeLabel = document.querySelector('#signin-code-label');
const signInStatus = document.querySelector('#signin-status');
const signInSession = document.querySelector('#signin-session');
const signInSubmit = signInForm.querySelector('.signin-submit');
const signOutButton = document.querySelector('#signin-signout');
const currentYear = document.querySelector('#current-year');

if (currentYear) currentYear.textContent = new Date().getFullYear();

menuToggle.addEventListener('click', () => {
  const isOpen = menuToggle.getAttribute('aria-expanded') === 'true';
  menuToggle.setAttribute('aria-expanded', String(!isOpen));
  primaryNav.classList.toggle('is-open', !isOpen);
});

function closeMenu() {
  menuToggle.setAttribute('aria-expanded', 'false');
  primaryNav.classList.remove('is-open');
}

primaryNav.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));

const defaults = { darkMode: true, reduceMotion: false, cursorGlow: true };
let preferences = { ...defaults };
try {
  const saved = JSON.parse(localStorage.getItem('tracknest-site-settings') || 'null');
  if (saved && typeof saved === 'object') preferences = { ...defaults, ...saved };
} catch (_) {
  // The page remains usable if browser storage is unavailable.
}

function persistPreferences() {
  try {
    localStorage.setItem('tracknest-site-settings', JSON.stringify(preferences));
  } catch (_) {
    // Keep the controls working for this visit when storage is disabled.
  }
}

function syncSettingsControls() {
  document.querySelectorAll('.setting-switch').forEach((toggle) => {
    const value = Boolean(preferences[toggle.dataset.setting]);
    toggle.setAttribute('aria-checked', String(value));
  });
}

function applyPreferences() {
  document.documentElement.dataset.theme = preferences.darkMode ? 'dark' : 'light';
  document.documentElement.dataset.reduceMotion = preferences.reduceMotion ? 'on' : 'off';
  document.body.dataset.cursorGlow = preferences.cursorGlow ? 'on' : 'off';
  syncSettingsControls();
}

function updatePreference(name, value) {
  preferences = { ...preferences, [name]: value };
  applyPreferences();
  persistPreferences();
}

applyPreferences();

document.querySelectorAll('.setting-switch').forEach((toggle) => {
  toggle.addEventListener('click', () => {
    const name = toggle.dataset.setting;
    updatePreference(name, !preferences[name]);
  });
});

document.querySelector('.settings-toggle').addEventListener('click', () => settingsDialog.showModal());
document.querySelectorAll('.dialog-close').forEach((button) => {
  button.addEventListener('click', () => button.closest('dialog').close());
});
document.querySelector('#reset-settings').addEventListener('click', () => {
  preferences = { ...defaults };
  applyPreferences();
  persistPreferences();
});

settingsDialog.addEventListener('click', (event) => {
  if (event.target === settingsDialog) settingsDialog.close();
});

signInButton.addEventListener('click', async () => {
  closeMenu();
  signInDialog.showModal();
  await showExistingSession();
});
signInDialog.addEventListener('click', (event) => {
  if (event.target === signInDialog) signInDialog.close();
});

let authClient = null;
let authStage = 'email';

async function getAuthClient() {
  if (authClient) return authClient;
  const config = window.TRACKNEST_AUTH_CONFIG || {};
  if (!config.supabaseUrl || !config.supabaseAnonKey) return null;
  const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
  authClient = createClient(config.supabaseUrl, config.supabaseAnonKey);
  return authClient;
}

async function showExistingSession() {
  try {
    const client = await getAuthClient();
    if (!client) return;
    const { data } = await client.auth.getSession();
    if (!data.session) return;
    signInForm.hidden = true;
    signInSession.hidden = false;
    signInSession.textContent = `Signed in as ${data.session.user.email}. Your library stays on each device.`;
    signOutButton.hidden = false;
  } catch (_) {
    signInStatus.textContent = 'Could not check your sign-in status. Try again in a moment.';
  }
}

signInForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  const config = window.TRACKNEST_AUTH_CONFIG || {};
  if (!config.supabaseUrl || !config.supabaseAnonKey) {
    signInStatus.textContent = 'Email sign-in needs the TrackNest account service to be connected. Your address was not sent.';
    return;
  }

  const email = signInEmail.value.trim();
  signInSubmit.disabled = true;
  try {
    const client = await getAuthClient();
    if (authStage === 'email') {
      const { error } = await client.auth.signInWithOtp({ email, options: { shouldCreateUser: true } });
      if (error) throw error;
      authStage = 'code';
      signInCode.hidden = false;
      signInCodeLabel.hidden = false;
      signInCode.required = true;
      signInStatus.textContent = 'Check your email for a one-time code, then enter it here.';
      signInSubmit.innerHTML = 'Verify code <span aria-hidden="true">→</span>';
      signInCode.focus();
    } else {
      const { data, error } = await client.auth.verifyOtp({ email, token: signInCode.value.trim(), type: 'email' });
      if (error) throw error;
      signInForm.hidden = true;
      signInSession.hidden = false;
      signInSession.textContent = `Signed in as ${data.user.email}. Your library stays on each device.`;
      signOutButton.hidden = false;
    }
  } catch (_) {
    signInStatus.textContent = authStage === 'email'
      ? 'Could not send a code. Check the email address and account setup.'
      : 'That code did not work. Check it and try again.';
  } finally {
    signInSubmit.disabled = false;
  }
});

signOutButton.addEventListener('click', async () => {
  try {
    const client = await getAuthClient();
    await client.auth.signOut();
    authStage = 'email';
    signInForm.hidden = false;
    signInSession.hidden = true;
    signInCode.hidden = true;
    signInCodeLabel.hidden = true;
    signInCode.required = false;
    signInCode.value = '';
    signInStatus.textContent = 'You are signed out.';
    signOutButton.hidden = true;
    signInSubmit.innerHTML = 'Continue with email <span aria-hidden="true">→</span>';
  } catch (_) {
    signInStatus.textContent = 'Could not sign out. Please try again.';
  }
});

if ('IntersectionObserver' in window) {
  document.documentElement.classList.add('js-ready');
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add('is-visible');
      observer.unobserve(entry.target);
    });
  }, { threshold: 0.12 });
  document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));
} else {
  document.querySelectorAll('.reveal').forEach((element) => element.classList.add('is-visible'));
}
