import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";
import { container } from "@infrastructure/di/container";
import { Vehicle } from "@domain/entities/Vehicle";
import { VehicleExpense } from "@domain/entities/VehicleExpense";
import { ExpenseLineItem } from "@domain/entities/ExpenseLineItem";
import type { PaymentMethod } from "@domain/entities/ContractPayment";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { CustomSelect } from "@presentation/components/CustomSelect";
import {
  Car,
  Plus,
  X,
  Save,
  Pencil,
  Trash2,
  Power,
  FileText,
  Calendar,
  DollarSign,
  AlertTriangle,
  Loader2,
  Receipt,
  Search,
  Tag,
} from "lucide-react";

const formatDate = (d: string) => {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("ar-KW", { year: "numeric", month: "short", day: "numeric" });
};

const daysUntil = (d: string) => {
  const diff = Math.ceil((new Date(d).getTime() - Date.now()) / 86400000);
  return diff;
};

const formatAmount = (n: number) => n.toLocaleString("ar-KW", { minimumFractionDigits: 3, maximumFractionDigits: 3 });

const PAYMENT_METHOD_OPTIONS: { id: PaymentMethod; label: string }[] = [
  { id: "cash", label: "نقدي" },
  { id: "transfer", label: "رابط" },
  { id: "cheque", label: "شيك" },
  { id: "card", label: "ومض" },
  { id: "gateway", label: "UPayments" },
];

export const FleetPage = () => {
  const [params] = useSearchParams();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "inactive">("all");
  const [licenseFilter, setLicenseFilter] = useState<"all" | "valid" | "expiring" | "expired">("all");

  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingVehicle, setEditingVehicle] = useState<Vehicle | null>(null);
  const [selectedVehicle, setSelectedVehicle] = useState<Vehicle | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{ vehicle: Vehicle } | null>(null);
  const [deleting, setDeleting] = useState(false);

  const [expenses, setExpenses] = useState<VehicleExpense[]>([]);
  const [loadingExpenses, setLoadingExpenses] = useState(false);
  const [vehicleLineItems, setVehicleLineItems] = useState<ExpenseLineItem[]>([]);

  const { notify } = useToast();
  const repo = container.fleetRepository;

  const loadData = async () => {
    try {
      setLoading(true);
      const [data, allSections, allLineItems] = await Promise.all([
        repo.listVehicles(),
        container.adminRepository.listExpenseSections(),
        container.adminRepository.listExpenseLineItems(),
      ]);
      setVehicles(data);
      const vehiclesSection = allSections.find((s) => s.type === "vehicles");
      if (vehiclesSection) {
        setVehicleLineItems(allLineItems.filter((li) => li.sectionId === vehiclesSection.id));
      }
    } catch {
      setError("تعذر تحميل بيانات الأسطول");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  useEffect(() => {
    const vehicleId = params.get("vehicleId");
    if (!vehicleId || vehicles.length === 0) return;
    const target = vehicles.find((v) => v.id === vehicleId);
    if (target) {
      void handleSelectVehicle(target);
    }
  }, [params, vehicles]);

  const handleSelectVehicle = async (v: Vehicle) => {
    setSelectedVehicle(v);
    setLoadingExpenses(true);
    try {
      const exps = await repo.listExpenses(v.id);
      setExpenses(exps);
    } catch {
      notify("فشل تحميل المصاريف");
    } finally {
      setLoadingExpenses(false);
    }
  };

  const handleCreate = async (data: any) => {
    try {
      await repo.createVehicle(data);
      notify("تم إضافة السيارة بنجاح");
      setIsCreateOpen(false);
      loadData();
    } catch {
      notify("فشل إضافة السيارة");
    }
  };

  const handleUpdate = async (data: any) => {
    try {
      await repo.updateVehicle(data);
      notify("تم تحديث بيانات السيارة");
      setEditingVehicle(null);
      loadData();
    } catch {
      notify("فشل تحديث السيارة");
    }
  };

  const handleToggleStatus = async (v: Vehicle) => {
    try {
      await repo.updateVehicle({
        id: v.id, plateNumber: v.plateNumber, licenseNumber: v.licenseNumber,
        licenseExpiry: v.licenseExpiry, notes: v.notes, isActive: v.status !== "active"
      });
      loadData();
    } catch {
      notify("فشل تحديث الحالة");
    }
  };

  const handleDeleteVehicle = async () => {
    if (!confirmDelete) return;
    setDeleting(true);
    try {
      await repo.deleteVehicle(confirmDelete.vehicle.id);
      notify("تم حذف السيارة");
      setConfirmDelete(null);
      if (selectedVehicle?.id === confirmDelete.vehicle.id) setSelectedVehicle(null);
      loadData();
    } catch {
      notify("فشل حذف السيارة");
    } finally {
      setDeleting(false);
    }
  };

  const handleAddExpense = async (data: { description: string; amount: number; expenseDate: string; lineItemId?: string | null; paymentMethod?: PaymentMethod | null }) => {
    if (!selectedVehicle) return;
    try {
      await repo.createExpense({ vehicleId: selectedVehicle.id, ...data });
      notify("تم إضافة المصروف");
      const exps = await repo.listExpenses(selectedVehicle.id);
      setExpenses(exps);
      loadData();
    } catch {
      notify("فشل إضافة المصروف");
    }
  };

  const handleDeleteExpense = async (expenseId: string) => {
    try {
      await repo.deleteExpense(expenseId);
      notify("تم حذف المصروف");
      if (selectedVehicle) {
        const exps = await repo.listExpenses(selectedVehicle.id);
        setExpenses(exps);
        loadData();
      }
    } catch {
      notify("فشل حذف المصروف");
    }
  };

  const filtered = vehicles.filter((v) => {
    const matchesSearch = v.plateNumber.includes(search) || v.licenseNumber.includes(search);
    if (!matchesSearch) return false;

    if (statusFilter === "active" && v.status !== "active") return false;
    if (statusFilter === "inactive" && v.status === "active") return false;

    const days = daysUntil(v.licenseExpiry);
    const licenseStatus = days < 0 ? "expired" : days <= 30 ? "expiring" : "valid";
    if (licenseFilter === "valid" && licenseStatus !== "valid") return false;
    if (licenseFilter === "expiring" && licenseStatus !== "expiring") return false;
    if (licenseFilter === "expired" && licenseStatus !== "expired") return false;

    return true;
  });

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div className="fleet-page" style={{ padding: '24px', display: 'flex', flexDirection: 'column', height: '100vh', gap: '24px', backgroundColor: 'var(--bg-app)', boxSizing: 'border-box', overflowY: 'hidden' }}>
        
        {/* Header Section */}
        <div className="fleet-page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="fleet-page-header-copy">
                <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Car size={28} style={{color: 'var(--color-primary)'}} />
                    إدارة أسطول السيارات
                </h1>
                <p style={{ color: 'var(--text-tertiary)', fontSize: '0.9rem', margin: 0 }}>
                    عرض وإدارة جميع السيارات في الأسطول ({vehicles.length} سيارة)
                </p>
            </div>
            <button 
              className="button primary fleet-page-create-button" 
                onClick={() => setIsCreateOpen(true)}
                style={{ height: '44px', padding: '0 24px', borderRadius: 'var(--radius-md)', fontSize: '0.95rem' }}
            >
                <Plus size={20} />
                سيارة جديدة
            </button>
        </div>

        {/* Toolbar Section - Filters & Search */}
        <div className="fleet-page-toolbar" style={{ 
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
            <div className="fleet-page-search" style={{ flex: 1, minWidth: '240px', position: 'relative' }}>
                <Search size={18} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '12px', color: 'var(--text-tertiary)' }} />
                <input 
                    type="text" 
                    placeholder="بحث برقم السيارة، الرخصة..." 
                    className="input"
                    value={search}
                    onChange={e => setSearch(e.target.value)}
                    style={{ 
                        width: '100%', 
                        paddingRight: '40px', 
                        borderRadius: 'var(--radius-md)',
                        borderColor: 'var(--color-border)',
                        height: '42px'
                    }} 
                />
            </div>

            <div className="fleet-page-filters" style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
              <div className="fleet-page-filter-group fleet-page-filter-group--status" style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
                     {[
                        { id: 'all', label: 'الكل' },
                        { id: 'active', label: 'نشط' },
                        { id: 'inactive', label: 'متوقف' },
                     ].map(filter => (
                        <button
                            key={filter.id}
                            onClick={() => setStatusFilter(filter.id as any)}
                            style={{
                                padding: '6px 12px',
                                borderRadius: '6px',
                                fontSize: '0.85rem',
                                fontWeight: 500,
                                color: statusFilter === filter.id ? 'var(--text-on-primary)' : 'var(--text-secondary)',
                                backgroundColor: statusFilter === filter.id ? 'var(--color-primary)' : 'transparent',
                                border: 'none',
                                cursor: 'pointer',
                                transition: 'all 0.2s'
                            }}
                        >
                            {filter.label}
                        </button>
                     ))}
                </div>
                
                <div className="fleet-page-filter-divider" style={{ width: '1px', height: '24px', backgroundColor: 'var(--color-border)', margin: '0 4px' }}></div>

                <div className="fleet-page-filter-group fleet-page-filter-group--license" style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
                     {[
                        { id: 'all', label: 'الكل', color: 'var(--color-primary)' },
                        { id: 'valid', label: 'صحيحة', color: '#16a34a' },
                        { id: 'expiring', label: 'قريبة', color: '#d97706' },
                        { id: 'expired', label: 'منتهية', color: '#dc2626' },
                     ].map(filter => (
                        <button
                            key={filter.id}
                            onClick={() => setLicenseFilter(filter.id as any)}
                            style={{
                                padding: '6px 12px',
                                borderRadius: '6px',
                                fontSize: '0.85rem',
                                fontWeight: 500,
                                color: licenseFilter === filter.id ? 'var(--text-on-primary)' : 'var(--text-secondary)',
                                backgroundColor: licenseFilter === filter.id ? filter.color : 'transparent',
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
        <div className="fleet-page-content" style={{ flex: 1, overflow: 'hidden', paddingBottom: '2px' }}>
          <div className="fleet-page-scroll" style={{ height: '100%', overflowY: 'auto', padding: '0 16px' }}>
                
                {/* Header for Desktop */}
            <div className="fleet-vehicles-table-header" style={{ 
                    display: 'grid', 
                    gridTemplateColumns: '1.2fr 1fr 1fr 0.8fr 0.8fr 160px', 
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
                    <div style={{ textAlign: 'right' }}>السيارة</div>
                    <div style={{ textAlign: 'right' }}>الرخصة</div>
                    <div style={{ textAlign: 'center' }}>الحالة</div>
                    <div style={{ textAlign: 'right' }}>صلاحية الرخصة</div>
                    <div style={{ textAlign: 'right' }}>مصاريف الشهر</div>
                    <div style={{ textAlign: 'center' }}>إجراءات</div>
                </div>

                <div className="fleet-vehicles-list" style={{ display: 'flex', flexDirection: 'column', gap: '12px', paddingBottom: '24px' }}>
                    {filtered.length > 0 ? filtered.map(vehicle => {
                        const days = daysUntil(vehicle.licenseExpiry);
                        const isExpired = days < 0;
                        const isExpiring = days >= 0 && days <= 30;
                        
                        return (
                        <div 
                            key={vehicle.id} 
                          className="fleet-vehicle-row"
                            style={{ 
                                display: 'grid', 
                                gridTemplateColumns: '1.2fr 1fr 1fr 0.8fr 0.8fr 160px', 
                                gap: '16px',
                                alignItems: 'center',
                                backgroundColor: selectedVehicle?.id === vehicle.id ? 'var(--bg-subtle)' : 'var(--bg-card)', 
                                padding: '16px 24px', 
                                borderRadius: '16px', 
                                border: selectedVehicle?.id === vehicle.id ? '1px solid var(--color-primary)' : '1px solid var(--color-border)',
                                boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                                transition: 'all 0.2s ease',
                                cursor: 'pointer'
                            }}
                            onClick={() => handleSelectVehicle(vehicle)}
                        >
                            {/* Column 1: Vehicle Info */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--vehicle" data-label="السيارة" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                <div style={{
                                    width: '40px',
                                    height: '40px',
                                    borderRadius: '10px',
                                    display: 'grid',
                                    placeItems: 'center',
                                    background: 'var(--green-50)',
                                    color: 'var(--color-primary)',
                                }}>
                                    <Car size={20} />
                                </div>
                                <div>
                                    <div style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>{vehicle.plateNumber}</div>
                                    <div style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)' }}>
                                        {vehicle.notes || 'لا توجد ملاحظات'}
                                    </div>
                                </div>
                            </div>
                            
                            {/* Column 2: License Number */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--license" data-label="الرخصة" style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', fontFamily: 'monospace' }}>
                                {vehicle.licenseNumber}
                            </div>
                            
                            {/* Column 3: Status Badge */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--status" data-label="الحالة" style={{ textAlign: 'center' }}>
                                <span style={{
                                    display: 'inline-flex',
                                    alignItems: 'center',
                                    gap: '6px',
                                    padding: '4px 10px',
                                    borderRadius: '12px',
                                    fontSize: '0.75rem',
                                    fontWeight: 600,
                                    backgroundColor: vehicle.status === 'active' ? 'var(--color-success-bg)' : 'var(--neutral-100)',
                                    color: vehicle.status === 'active' ? 'var(--color-success)' : 'var(--text-secondary)'
                                }}>
                                    <div style={{
                                        width: '6px',
                                        height: '6px',
                                        borderRadius: '50%',
                                        backgroundColor: vehicle.status === 'active' ? 'var(--color-success)' : 'var(--text-tertiary)'
                                    }} />
                                    {vehicle.status === 'active' ? 'نشط' : 'متوقف'}
                                </span>
                            </div>

                            {/* Column 4: License Expiry */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--expiry" data-label="صلاحية الرخصة" style={{ fontSize: '0.85rem' }}>
                                <div style={{ 
                                    fontWeight: 600, 
                                    color: isExpired ? '#dc2626' : isExpiring ? '#d97706' : '#16a34a',
                                    marginBottom: '2px'
                                }}>
                                    {formatDate(vehicle.licenseExpiry)}
                                </div>
                                <div style={{ fontSize: '0.75rem', color: isExpired ? '#dc2626' : isExpiring ? '#d97706' : 'var(--text-tertiary)' }}>
                                    {isExpired ? 'منتهية' : isExpiring ? `${days} أيام` : 'صالحة'}
                                </div>
                            </div>
                            
                            {/* Column 5: Monthly Expenses */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--expenses" data-label="مصاريف الشهر" style={{ fontWeight: 700, color: 'var(--color-warning)', fontSize: '0.9rem' }}>
                                {formatAmount(vehicle.currentMonthExpenses || 0)} د.ك
                            </div>
                            
                            {/* Column 6: Actions */}
                            <div className="fleet-vehicle-cell fleet-vehicle-cell--actions" data-label="إجراءات" style={{ display: 'flex', gap: '8px', justifyContent: 'center' }} onClick={(e) => e.stopPropagation()}>
                                <button
                                    className="button secondary"
                                    onClick={() => setEditingVehicle(vehicle)}
                                    style={{ height: '36px', width: '36px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--radius-md)' }}
                                    title="تعديل"
                                >
                                    <Pencil size={16} />
                                </button>
                                <button
                                    className="button"
                                    onClick={() => handleToggleStatus(vehicle)}
                                    style={{ 
                                        height: '36px', 
                                        width: '36px', 
                                        padding: 0, 
                                        display: 'flex', 
                                        alignItems: 'center', 
                                        justifyContent: 'center', 
                                        borderRadius: 'var(--radius-md)',
                                        backgroundColor: vehicle.status === 'active' ? 'var(--color-error-bg)' : 'var(--color-success-bg)',
                                        color: vehicle.status === 'active' ? 'var(--color-error)' : 'var(--color-success)',
                                        border: 'none'
                                    }}
                                    title={vehicle.status === 'active' ? 'إيقاف' : 'تفعيل'}
                                >
                                    <Power size={16} />
                                </button>
                                <button
                                    className="button danger"
                                    onClick={() => setConfirmDelete({ vehicle })}
                                    style={{ height: '36px', width: '36px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--radius-md)' }}
                                    title="حذف"
                                >
                                    <Trash2 size={16} />
                                </button>
                            </div>
                        </div>
                    )}) : (
                        <div style={{ 
                            backgroundColor: 'var(--bg-card)', 
                            padding: '48px', 
                            textAlign: 'center', 
                            color: 'var(--text-tertiary)',
                            borderRadius: '16px',
                            border: '1px solid var(--color-border)'
                        }}>
                            لا توجد سيارات مطابقة للبحث
                        </div>
                    )}
                </div>
            </div>
        </div>

        {/* Expenses Backdrop */}
        {selectedVehicle && (
            <div
                style={{
                    position: "fixed",
                    inset: 0,
                    background: "rgba(0,0,0,0.3)",
                    zIndex: 40,
                    backdropFilter: "blur(2px)",
                }}
                onClick={() => setSelectedVehicle(null)}
            />
        )}

        {/* Expenses Side Panel */}
        <div
          className="fleet-expenses-panel"
            style={{
                position: "fixed",
                top: 0,
                bottom: 0,
                left: 0,
                width: "480px",
                maxWidth: "90vw",
                background: "white",
                boxShadow: "-2px 0 12px rgba(0,0,0,0.15)",
                transform: selectedVehicle ? "translateX(0)" : "translateX(-100%)",
                transition: "transform 0.3s ease",
                zIndex: 50,
                display: "flex",
                flexDirection: "column",
                borderRight: "1px solid var(--color-border)",
            }}
        >
            {selectedVehicle && (
                <>
                    <div className="fleet-expenses-panel-header" style={{ padding: "20px 24px", borderBottom: "1px solid var(--color-border)", display: "flex", justifyContent: "space-between", alignItems: "start" }}>
                        <div>
                            <h3 style={{ margin: "0 0 4px", fontSize: "1.2rem", color: "#1a2a10", fontWeight: 700 }}>
                                {selectedVehicle.plateNumber}
                            </h3>
                            <p style={{ margin: 0, fontSize: "0.85rem", color: "#7c857a" }}>
                                ترخيص: {selectedVehicle.licenseNumber}
                            </p>
                        </div>
                        <button
                            onClick={() => setSelectedVehicle(null)}
                            style={{
                                background: "transparent",
                                border: "none",
                                borderRadius: "8px",
                                width: "32px",
                                height: "32px",
                                display: "flex",
                                alignItems: "center",
                                justifyContent: "center",
                                cursor: "pointer",
                                color: "#b0b8ae",
                            }}
                        >
                            <X size={20} />
                        </button>
                    </div>

                    {/* Total Summary */}
                    <div className="fleet-expenses-summary" style={{ padding: "16px 24px", background: "var(--bg-subtle)", borderBottom: "1px solid var(--color-border)" }}>
                        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: "12px" }}>
                            <span style={{ fontSize: "0.85rem", color: "#7c857a", fontWeight: 600 }}>مصاريف الشهر الحالي</span>
                            <div style={{ textAlign: "left" }}>
                                <div style={{ fontSize: "1.25rem", fontWeight: 800, color: "#EA8E20" }}>
                                    {formatAmount(
                                        expenses
                                            .filter((e) => {
                                                const d = new Date(e.expenseDate);
                                                const now = new Date();
                                                return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
                                            })
                                            .reduce((s, e) => s + e.amount, 0)
                                    )}{" "}
                                    د.ك
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Expenses List */}
                    <div className="fleet-expenses-list" style={{ flex: 1, overflowY: "auto", padding: "16px 24px" }}>
                        {loadingExpenses ? (
                            <div style={{ padding: "40px", textAlign: "center", color: "#b0b8ae" }}>
                                <Loader2 className="spin" style={{ marginBottom: "8px" }} />
                                جاري التحميل...
                            </div>
                        ) : expenses.length === 0 ? (
                            <div style={{ textAlign: "center", padding: "40px 20px", color: "#b0b8ae" }}>
                                <Receipt size={32} style={{ marginBottom: "8px", opacity: 0.5 }} />
                                <p style={{ margin: 0, fontWeight: 500 }}>لا توجد مصاريف</p>
                            </div>
                        ) : (
                            <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                                {(() => {
                                    const groups: Record<string, VehicleExpense[]> = {};
                                    expenses.forEach((exp) => {
                                        const d = new Date(exp.expenseDate);
                                        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
                                        (groups[key] ??= []).push(exp);
                                    });
                                    const sortedKeys = Object.keys(groups).sort((a, b) => b.localeCompare(a));

                                    return sortedKeys.map((key) => {
                                        const monthExpenses = groups[key] ?? [];
                                        const total = monthExpenses.reduce((s, e) => s + e.amount, 0);
                                        const [year, month] = key.split("-");
                                        const monthName = new Date(Number(year), Number(month) - 1).toLocaleDateString("ar-KW", { month: "long", year: "numeric" });

                                        return (
                                            <div key={key} style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                                                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 12px", background: "var(--bg-subtle)", borderRadius: "8px" }}>
                                                    <span style={{ fontSize: "0.85rem", fontWeight: 700, color: "#4a5349" }}>{monthName}</span>
                                                    <span style={{ fontSize: "0.9rem", fontWeight: 700, color: "#EA8E20" }}>{formatAmount(total)} د.ك</span>
                                                </div>
                                                <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                                                    {monthExpenses.map((exp) => (
                                                        <div
                                                            key={exp.id}
                                                          className="fleet-expense-item"
                                                            style={{
                                                                display: "flex",
                                                                alignItems: "center",
                                                                gap: "10px",
                                                                padding: "12px",
                                                                background: "white",
                                                                borderRadius: "10px",
                                                                border: "1px solid var(--color-border)",
                                                                transition: "all 0.2s",
                                                            }}
                                                        >
                                                            <div
                                                                style={{
                                                                    width: "36px",
                                                                    height: "36px",
                                                                    borderRadius: "8px",
                                                                    background: "#fef6eb",
                                                                    border: "1px solid #fde68a",
                                                                    display: "flex",
                                                                    alignItems: "center",
                                                                    justifyContent: "center",
                                                                    flexShrink: 0,
                                                                }}
                                                            >
                                                                <DollarSign size={16} color="#EA8E20" />
                                                            </div>
                                                            <div style={{ flex: 1 }}>
                                                                <div style={{ fontWeight: 600, fontSize: "0.9rem", color: "#1a2a10" }}>
                                                                    {exp.description}
                                                                </div>
                                                                <div style={{ fontSize: "0.75rem", color: "#b0b8ae", marginTop: "2px", display: "flex", gap: "8px", alignItems: "center" }}>
                                                                    {exp.lineItemId && vehicleLineItems.find(li => li.id === exp.lineItemId) && (
                                                                      <span style={{ display: "inline-flex", alignItems: "center", gap: "3px", background: "#f0ede8", padding: "1px 6px", borderRadius: "10px", fontSize: "0.7rem", fontWeight: 600, color: "#6b7a68" }}>
                                                                        <Tag size={10} />{vehicleLineItems.find(li => li.id === exp.lineItemId)?.name}
                                                                      </span>
                                                                    )}
                                                                    {formatDate(exp.expenseDate)}
                                                                </div>
                                                            </div>
                                                            <div style={{ fontWeight: 700, color: "#EA8E20", fontSize: "0.9rem", whiteSpace: "nowrap" }}>
                                                                {formatAmount(exp.amount)} د.ك
                                                            </div>
                                                            <button
                                                                type="button"
                                                                className="icon-button danger"
                                                                onClick={() => handleDeleteExpense(exp.id)}
                                                                style={{ width: "28px", height: "28px", flexShrink: 0 }}
                                                            >
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>
                                                    ))}
                                                </div>
                                            </div>
                                        );
                                    });
                                })()}
                            </div>
                        )}
                    </div>

                    {/* Add Expense Form */}
                    <div className="fleet-expenses-form" style={{ padding: "16px 24px", borderTop: "1px solid var(--color-border)", background: "var(--bg-subtle)" }}>
                        <AddExpenseForm lineItems={vehicleLineItems} onSubmit={handleAddExpense} />
                    </div>
                </>
            )}
        </div>

        {/* Modals */}
        {isCreateOpen && <VehicleFormModal title="إضافة سيارة جديدة" onClose={() => setIsCreateOpen(false)} onSubmit={handleCreate} />}
        {editingVehicle && <VehicleFormModal title="تعديل بيانات السيارة" vehicle={editingVehicle} onClose={() => setEditingVehicle(null)} onSubmit={handleUpdate} />}

        {confirmDelete && (
            <ConfirmDeleteModal
                name={confirmDelete.vehicle.plateNumber}
                loading={deleting}
                onConfirm={handleDeleteVehicle}
                onClose={() => !deleting && setConfirmDelete(null)}
            />
        )}
    </div>
  );
};


const StatCard = ({ icon: Icon, label, value, subtitle, color, bg }: any) => (
  <div className="card" style={{ padding: "16px 20px", display: "flex", alignItems: "center", gap: "14px" }}>
    <div style={{ width: "42px", height: "42px", borderRadius: "10px", background: bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <Icon size={22} color={color} />
    </div>
    <div>
      <div style={{ fontSize: "0.8rem", color: "#7c857a", fontWeight: "500" }}>{label}</div>
      <div style={{ fontSize: "1.15rem", fontWeight: "800", color: "#1a2a10", marginTop: "2px" }}>{value}</div>
      {subtitle && <div style={{ fontSize: "0.75rem", color: "#b0b8ae", marginTop: "2px" }}>{subtitle}</div>}
    </div>
  </div>
);

const AddExpenseForm = ({ lineItems, onSubmit }: {
  lineItems: ExpenseLineItem[];
  onSubmit: (data: { description: string; amount: number; expenseDate: string; lineItemId?: string | null; paymentMethod?: PaymentMethod | null }) => void;
}) => {
  const [desc, setDesc] = useState("");
  const [amount, setAmount] = useState("");
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [lineItemId, setLineItemId] = useState("");
  const [paymentMethod, setPaymentMethod] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!desc.trim() || !amount || !date || !paymentMethod) return;
    setSubmitting(true);
    await onSubmit({
      description: desc.trim(), amount: Number(amount), expenseDate: date,
      lineItemId: lineItemId || null, paymentMethod: paymentMethod as PaymentMethod,
    });
    setSubmitting(false);
    setDesc("");
    setAmount("");
    setLineItemId("");
    setPaymentMethod("");
  };

  return (
    <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
      <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "4px" }}>
        <Plus size={16} color="#EA8E20" />
        <span style={{ fontSize: "0.9rem", fontWeight: "600", color: "#4a5349" }}>إضافة مصروف جديد</span>
      </div>
      {lineItems.length > 0 && (
        <select
          className="input"
          value={lineItemId}
          onChange={(e) => setLineItemId(e.target.value)}
          style={{ borderColor: "#e4e0d8", height: "40px" }}
        >
          <option value="">— البند (اختياري) —</option>
          {lineItems.map((li) => <option key={li.id} value={li.id}>{li.name}</option>)}
        </select>
      )}
      <input className="input" placeholder="وصف المصروف..." value={desc} onChange={e => setDesc(e.target.value)} style={{ borderColor: "#e4e0d8" }} />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
        <input className="input" type="number" step="0.001" min="0" placeholder="المبلغ (د.ك)" value={amount} onChange={e => setAmount(e.target.value)} style={{ borderColor: "#e4e0d8" }} />
        <input className="input" type="date" value={date} onChange={e => setDate(e.target.value)} style={{ borderColor: "#e4e0d8" }} />
      </div>
      <CustomSelect
        value={paymentMethod}
        onChange={setPaymentMethod}
        options={PAYMENT_METHOD_OPTIONS}
        placeholder="طريقة الدفع"
        width="100%"
      />
      <button className="button" type="submit" disabled={submitting || !desc.trim() || !amount || !paymentMethod} style={{ justifyContent: "center" }}>
        {submitting ? <Loader2 size={18} className="spin" /> : <Plus size={18} />}
        {submitting ? "جار الإضافة..." : "إضافة المصروف"}
      </button>
    </form>
  );
};

const VehicleFormModal = ({ title, vehicle, onClose, onSubmit }: {
  title: string; vehicle?: Vehicle; onClose: () => void;
  onSubmit: (data: any) => void;
}) => {
  const [plateNumber, setPlateNumber] = useState(vehicle?.plateNumber || "");
  const [licenseNumber, setLicenseNumber] = useState(vehicle?.licenseNumber || "");
  const [licenseExpiry, setLicenseExpiry] = useState(vehicle?.licenseExpiry?.split("T")[0] || "");
  const [notes, setNotes] = useState(vehicle?.notes || "");
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!plateNumber.trim() || !licenseNumber.trim() || !licenseExpiry) return;
    setSubmitting(true);
    await onSubmit({
      ...(vehicle ? { id: vehicle.id, isActive: vehicle.status === "active" } : {}),
      plateNumber: plateNumber.trim(),
      licenseNumber: licenseNumber.trim(),
      licenseExpiry,
      notes: notes.trim() || null,
    });
    setSubmitting(false);
  };

  return (
    <Modal title={title} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          <FormField label="رقم السيارة (لوحة كويتية)" icon={Car} required>
            <input className="input" placeholder="مثال: 12345 / ك و ت" value={plateNumber} onChange={e => setPlateNumber(e.target.value)}
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="رقم الرخصة" icon={FileText} required>
            <input className="input" placeholder="رقم رخصة السيارة..." value={licenseNumber} onChange={e => setLicenseNumber(e.target.value)}
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="تاريخ انتهاء الرخصة" icon={Calendar} required>
            <input className="input" type="date" value={licenseExpiry} onChange={e => setLicenseExpiry(e.target.value)}
              lang="en-GB" dir="ltr"
              style={{ paddingRight: "40px", borderColor: "#e4e0d8" }} />
          </FormField>
          <FormField label="ملاحظات" icon={FileText}>
            <textarea className="input" placeholder="ملاحظات إضافية (اختياري)..." value={notes} onChange={e => setNotes(e.target.value)}
              rows={2} style={{ paddingRight: "40px", borderColor: "#e4e0d8", resize: "vertical" }} />
          </FormField>
        </div>
        <div style={{ display: "flex", gap: "12px", marginTop: "8px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
          <button className="button" style={{ flex: 1, justifyContent: "center" }} type="submit" disabled={submitting}>
            {submitting ? <Loader2 size={18} className="spin" /> : vehicle ? <Save size={18} /> : <Plus size={18} />}
            {submitting ? "جار الحفظ..." : vehicle ? "حفظ التغييرات" : "إضافة السيارة"}
          </button>
          <button className="button secondary" type="button" onClick={onClose} disabled={submitting}>إلغاء</button>
        </div>
      </form>
    </Modal>
  );
};

const FormField = ({ label, icon: Icon, required, children }: { label: string; icon: any; required?: boolean; children: React.ReactNode }) => (
  <label style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
    <span style={{ fontSize: "0.9rem", fontWeight: "600", color: "#2d3a2a" }}>
      {label} {required && <span style={{ color: "red" }}>*</span>}
    </span>
    <div style={{ position: "relative" }}>
      <Icon size={18} style={{ position: "absolute", top: "10px", right: "12px", color: "#b0b8ae" }} />
      {children}
    </div>
  </label>
);

const Modal = ({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) => (
  <div className="fleet-modal-overlay" style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.5)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100 }}>
    <div className="card fleet-modal-card" style={{ width: "100%", maxWidth: "450px", maxHeight: "90vh", overflowY: "auto", padding: "24px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "20px", alignItems: "center" }}>
        <h3 style={{ margin: 0, fontSize: "1.15rem", color: "#1a2a10" }}>{title}</h3>
        <button onClick={onClose} style={{ background: "#f5f3ef", border: "none", borderRadius: "8px", width: "32px", height: "32px", display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
          <X size={20} />
        </button>
      </div>
      {children}
    </div>
  </div>
);

const ConfirmDeleteModal = ({ name, loading, onConfirm, onClose }: { name: string; loading: boolean; onConfirm: () => void; onClose: () => void }) => (
  <div className="fleet-confirm-overlay" style={{ position: "fixed", inset: 0, background: "rgba(15, 23, 42, 0.6)", backdropFilter: "blur(4px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 110 }}>
    <div className="card fleet-confirm-card" style={{ width: "100%", maxWidth: "420px", padding: "32px", textAlign: "center" }}>
      <div style={{ width: "64px", height: "64px", borderRadius: "50%", background: "#fef2f2", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px", border: "2px solid #fecaca" }}>
        <AlertTriangle size={32} color="#ef4444" />
      </div>
      <h3 style={{ margin: "0 0 8px", fontSize: "1.2rem", color: "#1a2a10" }}>تأكيد الحذف</h3>
      <p style={{ margin: "0 0 8px", color: "#7c857a", fontSize: "0.95rem" }}>هل أنت متأكد من حذف السيارة</p>
      <p style={{ margin: "0 0 16px", fontWeight: "700", fontSize: "1.05rem", color: "#1a2a10", background: "#FBF9F5", padding: "10px 16px", borderRadius: "8px", border: "1px solid #e4e0d8", display: "inline-block" }}>"{name}"</p>
      <p style={{ margin: "0 0 24px", color: "#dc2626", fontSize: "0.85rem", background: "#fef2f2", padding: "10px 14px", borderRadius: "8px", border: "1px solid #fecaca", display: "flex", alignItems: "center", gap: "8px", justifyContent: "center" }}>
        <AlertTriangle size={16} /> سيتم حذف جميع المصاريف المرتبطة بالسيارة
      </p>
      <div style={{ display: "flex", gap: "12px", justifyContent: "center" }}>
        <button onClick={onConfirm} disabled={loading} style={{ flex: 1, padding: "12px 20px", borderRadius: "10px", border: "none", background: loading ? "#fca5a5" : "#ef4444", color: "white", fontWeight: "600", fontSize: "0.95rem", cursor: loading ? "not-allowed" : "pointer", display: "flex", alignItems: "center", justifyContent: "center", gap: "8px" }}>
          {loading ? <Loader2 size={18} className="spin" /> : <Trash2 size={18} />}
          {loading ? "جار الحذف..." : "نعم، احذف"}
        </button>
        <button onClick={onClose} disabled={loading} style={{ flex: 1, padding: "12px 20px", borderRadius: "10px", border: "1px solid #e4e0d8", background: "white", color: "#4a5349", fontWeight: "600", fontSize: "0.95rem", cursor: loading ? "not-allowed" : "pointer" }}>
          إلغاء
        </button>
      </div>
    </div>
  </div>
);
