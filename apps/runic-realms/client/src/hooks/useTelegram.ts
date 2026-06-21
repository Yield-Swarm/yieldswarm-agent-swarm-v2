export type TelegramUser = {
  id: number;
  first_name?: string;
  username?: string;
};

declare global {
  interface Window {
    Telegram?: {
      WebApp: {
        ready: () => void;
        expand: () => void;
        initData: string;
        initDataUnsafe: { user?: TelegramUser };
        themeParams: Record<string, string>;
        MainButton: {
          text: string;
          show: () => void;
          hide: () => void;
          onClick: (cb: () => void) => void;
          offClick: (cb: () => void) => void;
        };
        HapticFeedback?: { impactOccurred: (style: string) => void };
      };
    };
  }
}

export function useTelegram() {
  const tg = typeof window !== 'undefined' ? window.Telegram?.WebApp : undefined;
  const user = tg?.initDataUnsafe?.user;
  const isTelegram = Boolean(tg?.initData);

  const ready = () => {
    tg?.ready();
    tg?.expand();
    document.documentElement.style.setProperty('--tg-bg', tg?.themeParams.bg_color || '#0a0810');
  };

  const haptic = () => tg?.HapticFeedback?.impactOccurred('medium');

  return {
    tg,
    user,
    isTelegram,
    displayName: user?.first_name || user?.username || 'Wanderer',
    telegramId: user?.id?.toString() || 'dev_baris',
    initData: tg?.initData || '',
    ready,
    haptic,
  };
}
