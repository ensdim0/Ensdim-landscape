import { ReactNode, createContext, useCallback, useContext, useState } from "react";

type Toast = { id: string; message: string };

type ToastContextValue = {
  notify: (message: string) => void;
};

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

export const ToastProvider = ({ children }: { children: ReactNode }) => {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const notify = useCallback((message: string) => {
    const toast = { id: crypto.randomUUID(), message };
    setToasts((prev: Toast[]) => [...prev, toast]);
    setTimeout(() => {
      setToasts((prev: Toast[]) => prev.filter((item: Toast) => item.id !== toast.id));
    }, 3000);
  }, []);

  return (
    <ToastContext.Provider value={{ notify }}>
      {children}
      <div style={{ position: "fixed", bottom: 24, insetInlineStart: 24, zIndex: 9999, display: 'flex', flexDirection: 'column', gap: '8px' }}>
        {toasts.map((toast) => (
          <div key={toast.id} style={{ 
            background: '#1a2a10', 
            color: '#ffffff', 
            padding: '12px 20px', 
            borderRadius: '10px', 
            fontSize: '0.88rem',
            fontWeight: '500',
            boxShadow: '0 8px 24px rgba(26,42,16,0.2)',
            animation: 'slideIn 0.3s ease',
            maxWidth: '360px',
          }}>
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
};

export const useToast = () => {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error("ToastProvider is missing");
  }
  return context;
};
