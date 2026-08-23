import { useState, FormEvent, useContext } from 'react';
import { loginWithEmail } from '../lib/auth';
import { I18nContext } from '../lib/i18n';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const { t } = useContext(I18nContext);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    try {
      await loginWithEmail(email, password);
    } catch (err: unknown) {
      setError((err as { message?: string })?.message || 'Login failed');
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0A0B] flex items-center justify-center p-4">
      <form onSubmit={handleSubmit} className="bg-[#0D0D0E] border border-white/10 rounded-2xl p-8 w-full max-w-sm space-y-6">
        <div className="text-center">
          <div className="w-12 h-12 rounded-xl bg-indigo-600 flex items-center justify-center text-white font-bold text-lg mx-auto mb-3">Z</div>
          <h1 className="text-white text-lg font-semibold">{t('app.name')}</h1>
          <p className="text-slate-500 text-xs mt-1">{t('app.tagline')}</p>
        </div>
        {error && (
          <div className="bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs p-3 rounded-lg">{error}</div>
        )}
        <div>
          <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5 tracking-wider">{t('login.email')}</label>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            className="w-full bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white focus:outline-none focus:border-indigo-500"
            required
          />
        </div>
        <div>
          <label className="block text-[10px] uppercase text-slate-400 font-bold mb-1.5 tracking-wider">{t('login.password')}</label>
          <input
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            className="w-full bg-[#161618] border border-white/10 rounded-lg py-2 px-3 text-xs text-white focus:outline-none focus:border-indigo-500"
            required
          />
        </div>
        <button type="submit" className="w-full py-2 bg-indigo-600 hover:bg-indigo-700 text-xs text-white font-semibold rounded-lg transition-colors">
          {t('login.submit')}
        </button>
      </form>
    </div>
  );
}
