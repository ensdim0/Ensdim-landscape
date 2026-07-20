import { Loader2, AlertCircle, Inbox } from "lucide-react";

export const LoadingState = ({ text = "جار التحميل..." }: { text?: string }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 20px', color: '#7c857a' }}>
    <Loader2 size={28} className="spin" style={{ marginBottom: '12px', color: '#30461F' }} />
    <span style={{ fontSize: '0.9rem' }}>{text}</span>
  </div>
);

export const EmptyState = ({ text = "لا توجد بيانات" }: { text?: string }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 20px', color: '#b0b8ae' }}>
    <Inbox size={36} style={{ marginBottom: '12px', opacity: 0.5 }} />
    <span style={{ fontSize: '0.9rem' }}>{text}</span>
  </div>
);

export const ErrorState = ({ text = "حدث خطأ" }: { text?: string }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 20px', color: '#C23030' }}>
    <AlertCircle size={32} style={{ marginBottom: '12px' }} />
    <span style={{ fontSize: '0.9rem' }}>{text}</span>
  </div>
);
