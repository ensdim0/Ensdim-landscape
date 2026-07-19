import React, { useEffect, useState } from "react";
import { 
  Users, 
  Search, 
  Plus, 
  Pencil, 
  Trash2,
  X,
  Save,
  Shield,
  UserCheck,
  User2,
  MapPin,
  Calendar,
  Loader2
} from "lucide-react";

import { container } from "@infrastructure/di/container";
import { User } from "@domain/entities/User";
import { GeographicLine } from "@domain/entities/GeographicLine";

import { getUsers } from "@application/use-cases/admin/getUsers";
import { createUser } from "@application/use-cases/admin/createUser";
import { updateUser } from "@application/use-cases/admin/updateUser";
import { deleteUser } from "@application/use-cases/admin/deleteUser";

import { useToast } from "@presentation/components/ToastProvider";
import { useTour } from "@presentation/components/tour/useTour";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { CustomSelect } from "@presentation/components/CustomSelect";

export const AdminUsersPage: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [lines, setLines] = useState<GeographicLine[]>([]);
  
  const [isLoading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState("");
  const [activeTab, setActiveTab] = useState<'all' | 'admin' | 'supervisor' | 'client'>('all');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [createRole, setCreateRole] = useState<string>('admin');
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [deletingUser, setDeletingUser] = useState<User | null>(null);
  const [actionLoading, setActionLoading] = useState(false);

  const { notify } = useToast();

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
        const [usersRes, linesRes] = await Promise.all([
            getUsers(container.adminRepository),
            container.lineRepository.listLines()
        ]);

        if (usersRes.ok) {
            setUsers(usersRes.data);
            setLines(linesRes);
        } else {
            setError(usersRes.error?.message || "فشل تحميل البيانات");
        }
    } catch (e) {
        setError("خطأ غير متوقع");
    } finally {
        setLoading(false);
    }
  };

  const handleCreate = async (data: any) => {
      setActionLoading(true);
      try {
          const result = await createUser(container.adminRepository, data);
          if (result.ok) {
              notify("تم إنشاء المستخدم بنجاح");
              setShowCreateModal(false);
              await loadData();
          } else {
              notify(result.error?.message || "فشل إنشاء المستخدم");
          }
      } finally {
          setActionLoading(false);
      }
  };

  const handleUpdate = async (data: any) => {
      setActionLoading(true);
      try {
          const result = await updateUser(container.adminRepository, {
              ...data,
              id: editingUser!.id
          });

          if (result.ok) {
              notify("تم تحديث المستخدم بنجاح");
              setEditingUser(null);
              loadData();
          } else {
              notify(result.error?.message || "فشل تحديث المستخدم");
          }
      } finally {
          setActionLoading(false);
      }
  };

  const confirmDelete = async () => {
      if (!deletingUser) return;
      setActionLoading(true);
      try {
          const result = await deleteUser(container.adminRepository, deletingUser.id);
          
          if (result.ok) {
              notify("تم حذف المستخدم بنجاح");
              setDeletingUser(null);
              loadData();
          } else {
              notify(result.error?.message || "فشل حذف المستخدم");
          }
      } finally {
          setActionLoading(false);
      }
  };

  const filteredUsers = users.filter(u => {
      const matchesSearch =
          (u.fullName || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
          (u.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
          (u.phone || '').toLowerCase().includes(searchQuery.toLowerCase());
      const matchesTab = activeTab === 'all' || u.role === activeTab;
      return matchesSearch && matchesTab;
  });

  const getLineName = (id?: string) => lines.find(l => l.id === id)?.name || "-";
  const handleOpenCreate = (role?: string) => {
      setCreateRole(role || (activeTab !== 'all' ? activeTab : 'admin'));
      setShowCreateModal(true);
  };

  const getInitials = (name: string) =>
      (name || "")
          .split(" ")
          .filter(Boolean)
          .slice(0, 2)
          .map(part => part[0])
          .join("")
          .toUpperCase();

  useTour(
    "admin-users",
    isLoading || error
      ? []
      : [
          {
            target: ".admin-users-header",
            title: "إدارة المستخدمين",
            content: "من هنا تشوف كل مستخدمي النظام وتضيف مستخدم جديد (مدير، مشرف، أو عميل).",
          },
          {
            target: ".admin-users-toolbar",
            title: "بحث وفلترة",
            content: "دوّر بالاسم أو البريد الإلكتروني، أو فلتر المستخدمين حسب نوعهم.",
          },
          {
            target: ".admin-users-list-card",
            title: "قائمة المستخدمين",
            content: "من هنا تعدّل بيانات أي مستخدم أو تدير صلاحياته.",
          },
        ]
  );

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

    return (
        <div className="admin-users-page" style={{ padding: '24px', display: 'flex', flexDirection: 'column', height: '100vh', gap: '24px', backgroundColor: 'var(--bg-app)', boxSizing: 'border-box', overflowY: 'hidden' }}>
        
        {/* Header Section */}
        <div className="admin-users-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
                <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Users size={28} style={{color: 'var(--color-primary)'}} />
                    إدارة المستخدمين
                </h1>
                <p style={{ color: 'var(--text-tertiary)', fontSize: '0.9rem', margin: 0 }}>
                    عرض وإدارة جميع المستخدمين في النظام ({users.length} مستخدم)
                </p>
            </div>
            <button 
                className="button primary admin-users-create-button" 
                onClick={() => handleOpenCreate()}
                style={{ height: '44px', padding: '0 24px', borderRadius: 'var(--radius-md)', fontSize: '0.95rem' }}
            >
                <Plus size={20} />
                مستخدم جديد
            </button>
        </div>

        {/* Toolbar Section - Filters & Search */}
        <div className="admin-users-toolbar" style={{ 
            backgroundColor: 'var(--bg-card)', 
            padding: '16px', 
            borderRadius: 'var(--radius-lg)', 
            boxShadow: 'var(--shadow-sm)',
            display: 'flex',
            flexWrap: 'wrap',
            gap: '16px',
            alignItems: 'center',
            border: '1px solid var(--color-border)'
        }}>
            <div className="admin-users-search" style={{ flex: 1, minWidth: '240px', position: 'relative' }}>
                <Search size={18} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '12px', color: 'var(--text-tertiary)' }} />
                <input 
                    type="text" 
                    placeholder="بحث بالاسم، البريد الإلكتروني..." 
                    className="input admin-users-search-input"
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    style={{ 
                        width: '100%', 
                        paddingRight: '40px', 
                        borderRadius: 'var(--radius-md)',
                        borderColor: 'var(--color-border)',
                        height: '42px'
                    }} 
                />
            </div>

            <div className="admin-users-tabs-wrap" style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                <div className="admin-users-filters" style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
                     {[
                        { id: 'all' as const, label: 'الكل' },
                        { id: 'admin' as const, label: 'مديرين' },
                        { id: 'supervisor' as const, label: 'مشرفين' },
                        { id: 'client' as const, label: 'عملاء' },
                     ].map(filter => (
                        <button
                            key={filter.id}
                            className="admin-users-filter-button"
                            onClick={() => setActiveTab(filter.id)}
                            style={{
                                padding: '6px 12px',
                                borderRadius: '6px',
                                fontSize: '0.85rem',
                                fontWeight: 500,
                                color: activeTab === filter.id ? 'var(--text-on-primary)' : 'var(--text-secondary)',
                                backgroundColor: activeTab === filter.id ? 'var(--color-primary)' : 'transparent',
                                border: 'none',
                                cursor: 'pointer',
                                transition: 'all 0.2s'
                            }}
                        >
                            {filter.label}
                        </button>
                     ))}
                </div>
            </div>
        </div>

        {/* Data List - Grid Design */}
        <div className="admin-users-list-card" style={{ flex: 1, overflow: 'hidden', paddingBottom: '2px' }}>
            <div className="admin-users-list-scroll" style={{ height: '100%', overflowY: 'auto', padding: '0 16px' }}>
                
                {/* Header for Desktop */}
                <div className="admin-users-table-head" style={{ 
                    display: 'grid', 
                    gridTemplateColumns: '1.5fr 1fr 1fr 1fr 140px', 
                    gap: '16px', 
                    padding: '0 24px 12px', 
                    borderBottom: '1px solid var(--color-border)', 
                    marginBottom: '16px', 
                    fontSize: '0.85rem', 
                    fontWeight: 600, 
                    color: 'var(--text-tertiary)',
                    position: 'sticky',
                    top: 0,
                    zIndex: 10,
                    backgroundColor: 'var(--bg-app)'
                }}>
                    <div style={{ textAlign: 'right' }}>المستخدم</div>
                    <div style={{ textAlign: 'right' }}>البريد الإلكتروني</div>
                    <div style={{ textAlign: 'center' }}>النوع</div>
                    <div style={{ textAlign: 'right' }}>معلومات إضافية</div>
                    <div style={{ textAlign: 'center' }}>إجراءات</div>
                </div>

                <div className="admin-users-table-body" style={{ display: 'flex', flexDirection: 'column', gap: '12px', paddingBottom: '24px' }}>
                    {filteredUsers.length > 0 ? filteredUsers.map(user => (
                        <div 
                            key={user.id} 
                            className="admin-users-row"
                            style={{ 
                                display: 'grid', 
                                gridTemplateColumns: '1.5fr 1fr 1fr 1fr 140px', 
                                gap: '16px',
                                alignItems: 'center',
                                backgroundColor: 'var(--bg-card)', 
                                padding: '16px 24px', 
                                borderRadius: '16px', 
                                border: '1px solid var(--color-border)',
                                boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                                transition: 'all 0.2s ease'
                            }}
                        >
                            {/* Column 1: User Info */}
                            <div className="admin-users-cell admin-users-cell-user" data-label="المستخدم" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                <div style={{
                                    width: '40px',
                                    height: '40px',
                                    borderRadius: '10px',
                                    display: 'grid',
                                    placeItems: 'center',
                                    background: user.role === 'client' ? 'var(--color-warning-bg)' : 'var(--green-50)',
                                    color: user.role === 'client' ? 'var(--color-warning)' : 'var(--color-primary)',
                                    fontWeight: 700,
                                    fontSize: '0.85rem'
                                }}>
                                    {getInitials(user.fullName) || 'U'}
                                </div>
                                <div>
                                    <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{user.fullName}</div>
                                    <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>
                                        انضم: {user.createdAt ? new Date(user.createdAt).toLocaleDateString('ar-EG') : '-'}
                                    </div>
                                </div>
                            </div>
                            
                            {/* Column 2: Email */}
                            <div className="admin-users-cell admin-users-cell-email" data-label="البريد الإلكتروني" style={{ fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                                {user.email}
                            </div>
                            
                            {/* Column 3: Role Badge */}
                            <div className="admin-users-cell admin-users-cell-role" data-label="النوع" style={{ textAlign: 'center' }}>
                                <RoleBadge role={user.role} />
                            </div>

                            {/* Column 4: Additional Info */}
                            <div className="admin-users-cell admin-users-cell-meta" data-label="معلومات إضافية" style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                {user.phone && <div style={{ direction: 'ltr', marginBottom: '4px' }}>{user.phone}</div>}
                                {user.role === 'supervisor' && user.assignedLineId && (
                                    <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                        <MapPin size={14} color="var(--color-primary)" />
                                        {getLineName(user.assignedLineId)}
                                    </div>
                                )}
                                {user.role === 'admin' && (
                                    <span style={{ color: 'var(--text-tertiary)' }}>—</span>
                                )}
                                {!user.assignedLineId && user.role === 'supervisor' && (
                                    <span style={{ color: 'var(--text-tertiary)' }}>غير معين</span>
                                )}
                            </div>
                            
                            {/* Column 5: Actions */}
                            <div className="admin-users-cell admin-users-cell-actions" data-label="إجراءات" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                                <div className="admin-users-actions" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
                                <button
                                    className="button secondary"
                                    onClick={() => setEditingUser(user)}
                                    style={{ height: '36px', width: '36px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--radius-md)' }}
                                    title="تعديل"
                                >
                                    <Pencil size={16} />
                                </button>
                                <button
                                    className="button danger"
                                    onClick={() => setDeletingUser(user)}
                                    style={{ height: '36px', width: '36px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--radius-md)' }}
                                    title="حذف"
                                >
                                    <Trash2 size={16} />
                                </button>
                                </div>
                            </div>
                        </div>
                    )) : (
                        <div className="admin-users-empty" style={{ 
                            backgroundColor: 'var(--bg-card)', 
                            padding: '48px', 
                            textAlign: 'center', 
                            color: 'var(--text-tertiary)',
                            borderRadius: '16px',
                            border: '1px solid var(--color-border)'
                        }}>
                            لا يوجد مستخدمين مطابقين للبحث
                        </div>
                    )}
                </div>
            </div>
        </div>

        {(showCreateModal || editingUser) && (
            <UserFormModal
                title={editingUser ? "تعديل بيانات المستخدم" : "إضافة مستخدم جديد"}
                initialData={editingUser || { role: createRole }}
                lines={lines}
                isEdit={!!editingUser}
                loading={actionLoading}
                onClose={() => { setShowCreateModal(false); setEditingUser(null); }}
                onSubmit={editingUser ? handleUpdate : handleCreate}
            />
        )}

        {deletingUser && (
            <Modal title="تأكيد حذف المستخدم" onClose={() => setDeletingUser(null)}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                    <p style={{ margin: 0, color: '#7c857a', lineHeight: '1.6' }}>
                        هل أنت متأكد من حذف المستخدم
                        <strong style={{ color: '#1a2a10', margin: '0 4px' }}>{deletingUser.fullName}</strong>؟
                        <br />
                        <span style={{ fontSize: '0.85rem', color: '#ef4444' }}>
                            لن يتمكن هذا المستخدم من الدخول للنظام بعد الآن.
                        </span>
                    </p>
                    <div className="admin-users-delete-actions" style={{ display: 'flex', gap: '10px', marginTop: '8px', paddingTop: '14px', borderTop: '1px solid #f5f3ef' }}>
                        <button className="button danger" onClick={confirmDelete} disabled={actionLoading} style={{ flex: 1, justifyContent: 'center', height: '38px' }}>
                            {actionLoading ? <Loader2 size={18} className="spin" /> : null}
                            {actionLoading ? "جار الحذف..." : "تأكيد الحذف"}
                        </button>
                        <button className="button secondary" onClick={() => setDeletingUser(null)} disabled={actionLoading} style={{ height: '38px' }}>
                            إلغاء
                        </button>
                    </div>
                </div>
            </Modal>
        )}
    </div>
  );
};

const RoleBadge = ({ role }: { role: string }) => {
    let bg = '#f5f3ef';
    let color = '#7c857a';
    let icon = null;
    let label = role || 'غير محدد';

    switch (role?.toLowerCase()) {
        case 'admin': 
            bg = '#eef3e8'; color = '#30461F'; label = 'مدير نظام'; 
            icon = <Shield size={12} />;
            break;
        case 'supervisor': 
            bg = '#eef3e8'; color = '#30461F'; label = 'مشرف ميداني';
            icon = <UserCheck size={12} />;
            break;
        case 'client': 
            bg = '#fef6eb'; color = '#EA8E20'; label = 'عميل';
            icon = <User2 size={12} />;
            break;
        default: break;
    }

    return (
        <span style={{ 
            padding: '4px 10px', borderRadius: '20px', fontSize: '0.75rem', fontWeight: '600',
            background: bg, color: color, display: 'inline-flex', alignItems: 'center', gap: '6px'
        }}>
            {icon} {label}
        </span>
    );
};

const Modal = ({ title, onClose, children }: any) => (
    <div className="admin-users-modal-overlay" style={{
        position: 'fixed', inset: 0, background: 'rgba(15, 23, 42, 0.62)', 
        backdropFilter: 'blur(5px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100,
        padding: '40px 20px', overflowY: 'auto'
    }}>
        <div className="card admin-users-modal-card" style={{ width: '100%', maxWidth: '560px', display: 'flex', flexDirection: 'column', padding: '0', boxShadow: '0 20px 40px rgba(15, 23, 42, 0.25)', position: 'relative', borderRadius: 'var(--radius-lg)', overflow: 'hidden', maxHeight: 'calc(100dvh - 80px)' }}>
            <div className="admin-users-modal-head" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 18px', borderBottom: '1px solid #f0ece4', background: '#faf9f7', flexShrink: 0 }}>
                <h3 style={{ margin: 0, fontSize: '1rem', color: '#1a2a10', fontWeight: 700 }}>{title}</h3>
                <button onClick={onClose} className="icon-button" style={{ background: '#f1eee7', width: '30px', height: '30px' }}><X size={17} /></button>
            </div>
            <div className="admin-users-modal-body" style={{ padding: '18px', overflowY: 'auto', maxHeight: 'calc(100dvh - 150px)' }}>{children}</div>
        </div>
    </div>
);

const UserFormModal = ({ title, initialData, lines, isEdit, loading, onClose, onSubmit }: any) => {
    const formatDateForInput = (dateStr: string | null | undefined) => {
        if (!dateStr) return "";
        return dateStr.split('T')[0]; 
    };

    const [formData, setFormData] = useState(() => {
        const initialFullName = initialData?.fullName || "";
        const detectedTitle = initialFullName.startsWith("السيد ")
            ? "السيد"
            : initialFullName.startsWith("السيدة ")
                ? "السيدة"
                : "";
        const nameWithoutTitle = detectedTitle ? initialFullName.replace(`${detectedTitle} `, "") : initialFullName;

        return {
            title: detectedTitle,
            fullName: nameWithoutTitle,
            email: initialData?.email || "",
            password: "",
            role: initialData?.role || "admin",
            assignedLineId: initialData?.assignedLineId || "",
            assignmentStartDate: formatDateForInput(initialData?.assignmentStartDate),
            assignmentEndDate: formatDateForInput(initialData?.assignmentEndDate),
            joinDate: formatDateForInput(initialData?.createdAt),
            phone: initialData?.phone || "",
            address: initialData?.address || "",
        };
    });

    const today = new Date().toISOString().split("T")[0];

    const handleChange = (field: string, value: any) => {
        setFormData(prev => ({ ...prev, [field]: value }));
    };

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
            const asTrimmedString = (value: unknown) => (typeof value === 'string' ? value.trim() : '');

            const cleaned = {
                ...formData,
                fullName: asTrimmedString(formData.fullName),
                email: asTrimmedString(formData.email),
                password: asTrimmedString(formData.password),
                phone: asTrimmedString(formData.phone),
                assignedLineId: asTrimmedString(formData.assignedLineId),
                assignmentStartDate: asTrimmedString(formData.assignmentStartDate),
                assignmentEndDate: asTrimmedString(formData.assignmentEndDate),
                joinDate: asTrimmedString(formData.joinDate),
                address: asTrimmedString(formData.address),
            };

            // Prefix title to fullName if selected and not already present
            const selectedTitle = (formData.title || "").trim();
            if (selectedTitle) {
                const titleWithSpace = `${selectedTitle} `;
                if (cleaned.fullName && !cleaned.fullName.startsWith(titleWithSpace)) {
                    cleaned.fullName = `${selectedTitle} ${cleaned.fullName}`;
                }
            }

            if (!cleaned.password) delete (cleaned as any).password;
            if (!cleaned.email) delete (cleaned as any).email;
            if (!cleaned.assignedLineId) delete (cleaned as any).assignedLineId;
            if (!cleaned.assignmentStartDate) delete (cleaned as any).assignmentStartDate;
            if (!cleaned.assignmentEndDate) delete (cleaned as any).assignmentEndDate;
            if (!cleaned.joinDate) delete (cleaned as any).joinDate;
            if (!cleaned.phone) delete (cleaned as any).phone;
            if (!cleaned.address) delete (cleaned as any).address;
        onSubmit(cleaned);
    };

    const isSupervisor = formData.role === 'supervisor';
    const isClient = formData.role === 'client';

    const ROLE_DESCRIPTIONS: Record<string, { icon: React.ReactNode; desc: string; color: string; bg: string }> = {
        admin: { icon: <Shield size={16} />, desc: "صلاحية كاملة على النظام – إدارة المستخدمين، العقود، الخطوط، التقارير", color: "#30461F", bg: "#eef3e8" },
        supervisor: { icon: <UserCheck size={16} />, desc: "مشرف ميداني – يتم تعيينه على خط ويتابع العقود والمهام الميدانية", color: "#30461F", bg: "#eef3e8" },
        client: { icon: <User2 size={16} />, desc: "عميل – يمكنه رؤية عقوده وفواتيره وإضافة تعليقات", color: "#EA8E20", bg: "#fef6eb" },
    };

    const roleInfo = ROLE_DESCRIPTIONS[formData.role];

    return (
        <Modal title={title} onClose={onClose}>
             <form className="admin-users-form" onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                {/* Role Selection - First */}
                <label className="form-group">
                    <span>نوع المستخدم <span style={{color:'red'}}>*</span></span>
                    <CustomSelect
                        value={formData.role}
                        onChange={(val) => handleChange('role', val)}
                        options={[
                            { id: 'admin', label: 'مدير نظام (Admin)' },
                            { id: 'supervisor', label: 'مشرف ميداني (Supervisor)' },
                            { id: 'client', label: 'عميل (Client)' }
                        ]}
                        width="100%"
                        placeholder="اختر نوع المستخدم"
                    />
                </label>

                {roleInfo && (
                    <div style={{
                        display: 'flex', alignItems: 'flex-start', gap: '10px', padding: '10px 12px',
                        borderRadius: '10px', background: roleInfo.bg, border: `1px solid ${roleInfo.color}22`,
                        fontSize: '0.8rem', color: roleInfo.color, lineHeight: '1.5'
                    }}>
                        <div style={{ marginTop: '2px' }}>{roleInfo.icon}</div>
                        <span>{roleInfo.desc}</span>
                    </div>
                )}

                {/* Common Fields */}
                <label className="form-group">
                    <span>اللقب</span>
                    <CustomSelect
                        value={formData.title || ''}
                        onChange={(val) => handleChange('title', val)}
                        options={[
                            { id: '', label: 'بدون' },
                            { id: 'السيد', label: 'السيد' },
                            { id: 'السيدة', label: 'السيدة' },
                        ]}
                        width="140px"
                    />
                </label>

                <label className="form-group">
                    <span>الاسم الكامل <span style={{color:'red'}}>*</span></span>
                    <input className="input" value={formData.fullName} onChange={e => handleChange('fullName', e.target.value)} required placeholder="الاسم" />
                </label>

                <label className="form-group">
                    <span>البريد الإلكتروني <span style={{fontSize:'0.75em', fontWeight:'normal'}}>(اختياري)</span></span>
                    <input type="email" className="input" value={formData.email} onChange={e => handleChange('email', e.target.value)} placeholder="example@domain.com" dir="ltr" />
                </label>

                <label className="form-group">
                    <span>رقم الهاتف <span style={{color:'red'}}>*</span></span>
                    <input className="input" value={formData.phone} onChange={e => handleChange('phone', e.target.value)} required={!isEdit} placeholder="+96550012345" dir="ltr" />
                </label>

                {isEdit && (
                    <label className="form-group">
                        <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <Calendar size={14} /> تاريخ الانضمام
                        </span>
                        <input
                            type="date"
                            className="input"
                            value={formData.joinDate}
                            onChange={e => handleChange('joinDate', e.target.value)}
                            max={today}
                        />
                    </label>
                )}

                <label className="form-group">
                    <span>كلمة المرور {isEdit && <span style={{fontSize:'0.75em', fontWeight:'normal'}}>(اختياري - اتركه فارغ لعدم التغيير)</span>} {!isEdit && <span style={{color:'red'}}>*</span>}</span>
                    <input type="password" className="input" value={formData.password} onChange={e => handleChange('password', e.target.value)} required={!isEdit} minLength={6} placeholder="6 أحرف على الأقل" />
                </label>

                {/* Supervisor-specific fields */}
                {isSupervisor && (
                    <div className="admin-users-supervisor-box" style={{ background: '#f7fbf3', padding: '14px', borderRadius: '10px', border: '1px solid #dce8d0', display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '2px' }}>
                        <div style={{ fontSize: '0.85rem', fontWeight: '700', color: '#30461F', marginBottom: '-8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <MapPin size={14} /> بيانات التعيين الميداني
                        </div>
                        
                        <label className="form-group">
                            <span>الخط المعين عليه</span>
                            <CustomSelect
                                value={formData.assignedLineId || ''}
                                onChange={(val) => handleChange('assignedLineId', val)}
                                options={[
                                    { id: '', label: 'بدون تعيين خط (يمكن التعيين لاحقاً)' },
                                    ...lines.map((l: any) => ({ id: l.id, label: l.name }))
                                ]}
                                width="100%"
                                placeholder="اختر الخط"
                            />
                        </label>

                        {formData.assignedLineId && formData.assignedLineId !== '' && (
                            <div className="admin-users-date-grid" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                                <label className="form-group">
                                    <span>تاريخ البداية</span>
                                    <input type="date" className="input" value={formData.assignmentStartDate || ''} onChange={e => handleChange('assignmentStartDate', e.target.value)} />
                                </label>
                                <label className="form-group">
                                    <span>تاريخ النهاية</span>
                                    <input type="date" className="input" value={formData.assignmentEndDate || ''} onChange={e => handleChange('assignmentEndDate', e.target.value)} />
                                </label>
                            </div>
                        )}
                    </div>
                )}

                {/* Client-specific fields */}
                {isClient && (
                    <div className="admin-users-client-box" style={{ background: '#fffaf2', padding: '14px', borderRadius: '10px', border: '1px solid #fde8c8', display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '2px' }}>
                        <div style={{ fontSize: '0.85rem', fontWeight: '700', color: '#EA8E20', marginBottom: '-8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <User2 size={14} /> بيانات العميل
                        </div>
                        
                        <label className="form-group">
                            <span>العنوان</span>
                            <input className="input" value={formData.address} onChange={e => handleChange('address', e.target.value)} placeholder="العنوان التفصيلي" />
                        </label>
                    </div>
                )}

                <div className="admin-users-form-actions" style={{ display: 'flex', gap: '10px', marginTop: '6px', paddingTop: '14px', borderTop: '1px solid #f5f3ef' }}>
                    <button className="button" type="submit" disabled={loading} style={{ flex: 1, justifyContent: 'center', height: '38px' }}>
                        {loading ? <Loader2 size={18} className="spin" /> : <Save size={18} />}
                        {loading ? "جار الحفظ..." : "حفظ"}
                    </button>
                    <button className="button secondary" type="button" onClick={onClose} disabled={loading} style={{ height: '38px' }}>إلغاء</button>
                </div>
            </form>
            <style>{`
                .form-group { 
                    display: flex; 
                    flex-direction: column; 
                    gap: 8px; 
                }
                .form-group > span { 
                    font-size: 0.9rem; 
                    font-weight: 600; 
                    color: #1a2a10;
                    margin-bottom: 2px;
                }
                @keyframes spin { to { transform: rotate(360deg); } }
                .spin { animation: spin 1s linear infinite; }
            `}</style>
        </Modal>
    );
};
