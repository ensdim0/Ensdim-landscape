import { useEffect, useState } from "react";
import { container } from "@infrastructure/di/container";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { ContractType } from "@domain/entities/ContractType";
import { Vehicle } from "@domain/entities/Vehicle";
import { CompanyPhone } from "@domain/entities/CompanyPhone";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { useToast } from "@presentation/components/ToastProvider";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { createLine } from "@application/use-cases/admin/createLine";
import { updateLine } from "@application/use-cases/admin/updateLine";
import { createZone } from "@application/use-cases/admin/createZone";
import { deleteZone } from "@application/use-cases/admin/deleteZone";
import { deleteLine } from "@application/use-cases/admin/deleteLine";
import { 
  MapPin, Pencil, Trash2, Plus, X, Search, Car, Phone, 
  GripVertical, ArrowRight, ChevronDown, Check, Filter,
  MoreVertical, Calendar, LayoutGrid, List, Map
} from "lucide-react";

const toClientErrorMessage = (rawError: unknown, fallback: string): string => {
    const raw = typeof rawError === "string"
        ? rawError
        : (rawError as any)?.message || "";

    if (!raw) return fallback;
    if (/[\u0600-\u06FF]/.test(raw)) return raw;

    const lower = raw.toLowerCase();

    if (lower.includes("duplicate") || lower.includes("already exists") || lower.includes("unique")) {
        return "البيانات التي أدخلتها مستخدمة بالفعل. فضلاً استخدم بيانات مختلفة.";
    }
    if (lower.includes("forbidden") || lower.includes("unauthorized") || lower.includes("permission")) {
        return "ليس لديك صلاحية لتنفيذ هذا الإجراء. يرجى التواصل مع مدير النظام.";
    }
    if (lower.includes("network") || lower.includes("failed to fetch") || lower.includes("fetch")) {
        return "تعذر الاتصال بالخادم. يرجى التحقق من الإنترنت ثم المحاولة مرة أخرى.";
    }
    if (lower.includes("timeout")) {
        return "استغرق الطلب وقتاً أطول من المتوقع. حاول مرة أخرى.";
    }
    if (lower.includes("foreign key") || lower.includes("violates")) {
        return "لا يمكن تنفيذ العملية بسبب ارتباط هذا الخط ببيانات أخرى في النظام.";
    }

    return fallback;
};

export const LinesPage = () => {
  const [lines, setLines] = useState<GeographicLine[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
    const [isCompactLayout, setIsCompactLayout] = useState(() => {
        return typeof window !== "undefined" && window.matchMedia("(max-width: 767px)").matches;
    });
  const [contractTypes, setContractTypes] = useState<ContractType[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [companyPhones, setCompanyPhones] = useState<CompanyPhone[]>([]);
  
  const [searchQuery, setSearchQuery] = useState("");
  const [filterType, setFilterType] = useState('all'); 
  const [selectedContractTypeId, setSelectedContractTypeId] = useState('all');
  
  const [selectedLineId, setSelectedLineId] = useState<string | null>(null);
  const [zonesMap, setZonesMap] = useState<Record<string, Zone[]>>({});
  const [loadingZones, setLoadingZones] = useState<Set<string>>(new Set());
  
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingLine, setEditingLine] = useState<GeographicLine | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{ type: 'line' | 'zone'; name: string; onConfirm: () => Promise<void> } | null>(null);

  const { notify } = useToast();

    useEffect(() => {
        const mediaQuery = window.matchMedia("(max-width: 767px)");

        const updateLayout = () => setIsCompactLayout(mediaQuery.matches);

        updateLayout();

        if (typeof mediaQuery.addEventListener === "function") {
            mediaQuery.addEventListener("change", updateLayout);
            return () => mediaQuery.removeEventListener("change", updateLayout);
        }

        mediaQuery.addListener(updateLayout);
        return () => mediaQuery.removeListener(updateLayout);
    }, []);

  const loadData = async () => {
    try {
            setError(null);
      setLoading(true);
      const [linesData, typesData, vehiclesData, phonesData] = await Promise.all([
        container.lineRepository.listLines(),
        container.adminRepository.listContractTypes(),
        container.fleetRepository.listVehicles(),
        container.phoneRepository.listPhones()
      ]);
      setLines(linesData);
      setContractTypes(typesData);
      setVehicles(vehiclesData.filter(v => v.status === "active"));
      setCompanyPhones(phonesData.filter(p => p.status === "active"));
        } catch (err: any) {
            setError(toClientErrorMessage(err, "تعذر تحميل بيانات خطوط السير حالياً. يرجى المحاولة بعد قليل."));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadData(); }, []);

  const openDrawer = async (line: GeographicLine) => {
    setSelectedLineId(line.id);
    if (!zonesMap[line.id]) {
      setLoadingZones(prev => new Set(prev).add(line.id));
      try {
        const fetched = await container.lineRepository.listZones(line.id);
        setZonesMap(prev => ({ ...prev, [line.id]: fetched }));
            } catch (err: any) {
                notify(toClientErrorMessage(err, "تعذر تحميل مناطق هذا الخط حالياً. حاول مرة أخرى."));
      } finally {
        setLoadingZones(prev => { const n = new Set(prev); n.delete(line.id); return n; });
      }
    }
  };

  const handleToggleStatus = async (line: GeographicLine) => {
    try {
        const newStatus = line.status === 'active' ? 'inactive' : 'active';
        await updateLine(container.lineRepository, {
            id: line.id,
            name: line.name,
            lineType: line.lineType,
            contractTypeId: line.contractTypeId || null,
            phoneNumber: line.phoneNumber || null,
            carNumber: line.carNumber || null,
            vehicleId: line.vehicleId || null,
            phoneId: line.phoneId || null,
            isActive: newStatus === 'active'
        });
        
        setLines(prev => prev.map(l => l.id === line.id ? { ...l, status: newStatus } : l));
        notify(newStatus === 'active' ? "تم تنشيط الخط" : "تم ايقاف الخط");
        } catch (err: any) {
                notify(toClientErrorMessage(err, "تعذر تحديث حالة الخط حالياً. حاول مرة أخرى."));
    }
  };

  const fetchZones = async (lineId: string, setZonesMap: any, notify: any) => {
      try {
          const fetched = await container.lineRepository.listZones(lineId);
          setZonesMap((prev: any) => ({ ...prev, [lineId]: fetched }));
            } catch (err: any) {
                notify(toClientErrorMessage(err, "تعذر تحديث قائمة المناطق حالياً. حاول مرة أخرى."));
            }
  };

    const handleDeleteLine = async (line: GeographicLine) => {
        const result = await deleteLine(container.lineRepository, line.id);

        if (result.ok) {
            setLines(prev => prev.filter(l => l.id !== line.id));
            setZonesMap(prev => {
                const next = { ...prev };
                delete next[line.id];
                return next;
            });

            if (selectedLineId === line.id) {
                setSelectedLineId(null);
            }

            notify("تم حذف خط السير بنجاح.");
            setConfirmDelete(null);
            return;
        }

        notify(toClientErrorMessage(
            result.error?.message,
            "تعذر حذف خط السير حالياً. تأكد أنه غير مرتبط بعقود نشطة ثم حاول مرة أخرى."
        ));
        setConfirmDelete(null);
    };

  const filteredLines = lines.filter(l => {
    const searchLower = searchQuery.toLowerCase();
    const matchesSearch = 
      l.name.toLowerCase().includes(searchLower) || 
      (l.vehiclePlate && l.vehiclePlate.toLowerCase().includes(searchLower)) ||
      (l.status === 'active' ? 'نشط' : 'متوقف').includes(searchLower);
      
    const matchesStatus = filterType === 'all' || l.status === filterType;
    const matchesContract = selectedContractTypeId === 'all' || l.contractTypeId === selectedContractTypeId;
    
    return matchesSearch && matchesStatus && matchesContract;
  });
  
  const selectedLine = lines.find(l => l.id === selectedLineId);

  if (loading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div style={{ padding: isCompactLayout ? '16px 12px 20px' : '24px', display: 'flex', flexDirection: 'column', height: isCompactLayout ? 'auto' : '100vh', minHeight: isCompactLayout ? '100%' : '100vh', gap: isCompactLayout ? '16px' : '24px', backgroundColor: 'var(--bg-app)', boxSizing: 'border-box', overflowY: isCompactLayout ? 'visible' : 'hidden' }}>
        
         {/* Header Section */}
         <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: isCompactLayout ? 'stretch' : 'center', gap: isCompactLayout ? '12px' : '16px', flexDirection: isCompactLayout ? 'column' : 'row' }}>
            <div style={{ minWidth: 0 }}>
                <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Map size={28} style={{color: 'var(--color-primary)'}} />
                    إدارة خطوط السير
                </h1>
                <p style={{ color: 'var(--text-tertiary)', fontSize: '0.9rem', margin: 0 }}>
                    إدارة المسارات، توزيع المركبات، وترتيب محطات التوزيع ({lines.length} خط)
                </p>
            </div>
            
            <button 
                onClick={() => setIsCreateModalOpen(true)}
                className="button primary"
                style={{ 
                    height: '44px', padding: '0 24px', borderRadius: 'var(--radius-md)', fontSize: '0.95rem',
                    display: 'flex', alignItems: 'center', gap: '8px', width: isCompactLayout ? '100%' : 'auto', justifyContent: 'center'
                }}
            >
                <Plus size={20} /> إضافة خط جديد
            </button>
        </div>

        {/* Filters Toolbar */}
        <div style={{ 
            backgroundColor: 'var(--bg-card)', 
            padding: isCompactLayout ? '12px' : '16px', 
            borderRadius: 'var(--radius-lg)', 
            boxShadow: 'var(--shadow-sm)',
            display: 'flex',
            flexDirection: isCompactLayout ? 'column' : 'row',
            flexWrap: 'wrap',
            gap: isCompactLayout ? '12px' : '16px',
            alignItems: isCompactLayout ? 'stretch' : 'center',
            border: '1px solid var(--color-border)'
        }}>
            {/* Search */}
             <div style={{ flex: 1, minWidth: isCompactLayout ? 0 : '240px', position: 'relative', width: isCompactLayout ? '100%' : 'auto' }}>
                <Search size={18} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '12px', color: 'var(--text-tertiary)' }} />
                <input 
                    type="text" 
                    placeholder="بحث سريع (مثال: خط حولي، 123كويت، +96550012345)..." 
                    className="input"
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

            <div style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                {/* Contract Filter */}
                <CustomSelect 
                    value={selectedContractTypeId} 
                    onChange={setSelectedContractTypeId}
                    options={[{id: 'all', label: 'كل أنواع العقود'}, ...contractTypes.map(ct => ({id: ct.id, label: ct.name}))]}
                    width={isCompactLayout ? '100%' : '220px'}
                    placeholder="كل أنواع العقود"
                />

                {!isCompactLayout && <div style={{ width: '1px', height: '24px', backgroundColor: 'var(--color-border)', margin: '0 4px' }}></div>}

                {/* Status Toggles */}
                 <div style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)', width: isCompactLayout ? '100%' : 'auto' }}>
                    {[{ id: 'all', label: 'الكل' }, { id: 'active', label: 'نشط' }, { id: 'inactive', label: 'متوقف' }].map(tab => (
                        <button
                            key={tab.id}
                            onClick={() => setFilterType(tab.id)}
                            style={{
                                padding: '6px 12px',
                                flex: isCompactLayout ? 1 : '0 0 auto',
                                borderRadius: '6px',
                                fontSize: '0.85rem',
                                fontWeight: 500,
                                color: filterType === tab.id ? 'var(--text-on-primary)' : 'var(--text-secondary)',
                                backgroundColor: filterType === tab.id ? 'var(--color-primary)' : 'transparent',
                                border: 'none',
                                cursor: 'pointer',
                                transition: 'all 0.2s'
                            }}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>
            </div>
        </div>

        {/* Content Table */}
         <div style={{ flex: 1, overflow: isCompactLayout ? 'visible' : 'hidden', paddingBottom: '2px' }}>
            <div className="card" style={{ height: isCompactLayout ? 'auto' : '100%', padding: 0, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
                <div style={{ flex: 1, overflowY: isCompactLayout ? 'visible' : 'auto' }}>
                    {!isCompactLayout ? (
                    <table className="table" style={{ width: '100%', borderCollapse: 'separate', borderSpacing: 0 }}>
                        <thead style={{ position: 'sticky', top: 0, zIndex: 10, backgroundColor: 'var(--bg-subtle)' }}>
                            <tr>
                                <th style={thStyle}>اسم الخط</th>
                                <th style={thStyle}>نوع العقد</th>
                                <th style={thStyle}>السيارة المرتبطة</th>
                                <th style={thStyle}>رقم الهاتف</th>
                                <th style={thStyle}>المناطق</th>
                                <th style={thStyle}>الحالة</th>
                                <th style={{ ...thStyle, textAlign: 'center' }}>إجراءات</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filteredLines.map(line => (
                                <tr key={line.id} style={{ transition: 'background 0.2s', cursor: 'default' }} className="hover:bg-neutral-50">
                                    <td style={tdStyle}>
                                        <div style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{line.name}</div>
                                    </td>
                                    <td style={tdStyle}>
                                         <span style={{ 
                                            display: 'inline-flex', alignItems: 'center', gap: '6px',
                                            padding: '4px 8px', borderRadius: '6px', background: 'var(--neutral-100)', 
                                            color: 'var(--text-secondary)', fontSize: '0.8rem', fontWeight: 500
                                        }}>
                                            <Calendar size={12} /> {line.lineType || 'عقد مسار'}
                                        </span>
                                    </td>
                                    <td style={tdStyle}>
                                        {line.vehiclePlate ? (
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)' }}>
                                                <Car size={16} className="text-tertiary" /> <span>{line.vehiclePlate}</span>
                                            </div>
                                        ) : <span style={{ color: 'var(--text-placeholder)' }}>--</span>}
                                    </td>
                                    <td style={tdStyle}>
                                        {line.phoneDisplay ? (
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)' }}>
                                                <Phone size={16} className="text-tertiary" /> <span>{line.phoneDisplay}</span>
                                            </div>
                                        ) : <span style={{ color: 'var(--text-placeholder)' }}>--</span>}
                                    </td>
                                    <td style={tdStyle}>
                                        <button 
                                            onClick={() => openDrawer(line)}
                                            style={{ 
                                                border: '1px solid var(--color-border)', background: 'white', 
                                                borderRadius: '8px', padding: '4px 8px', cursor: 'pointer',
                                                display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem',
                                                color: 'var(--color-primary)', fontWeight: 600
                                            }}
                                        >
                                            {line.zoneCount} منطقة
                                            <ArrowRight size={14} />
                                        </button>
                                    </td>
                                    <td style={tdStyle}>
                                        <div 
                                            onClick={() => handleToggleStatus(line)}
                                            style={{ 
                                                cursor: 'pointer',
                                                display: 'inline-flex', alignItems: 'center', gap: '6px',
                                                padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 600,
                                                backgroundColor: line.status === 'active' ? 'var(--color-success-bg)' : 'var(--color-error-bg)',
                                                color: line.status === 'active' ? 'var(--color-success)' : 'var(--color-error)'
                                            }}
                                        >
                                            <div style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: 'currentColor' }} />
                                            {line.status === 'active' ? 'نشط' : 'متوقف'}
                                        </div>
                                    </td>
                                    <td style={{ ...tdStyle, textAlign: 'center' }}>
                                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                                            <button 
                                                title="تعديل"
                                                onClick={() => setEditingLine(line)}
                                                style={{ 
                                                    padding: '6px', borderRadius: '6px', border: 'none', background: 'transparent', 
                                                    cursor: 'pointer', color: 'var(--text-secondary)' 
                                                }}
                                                className="hover:bg-neutral-100"
                                            >
                                                <Pencil size={18} />
                                            </button>
                                            <button 
                                                title="حذف"
                                                onClick={() => setConfirmDelete({
                                                    type: 'line', name: line.name, 
                                                    onConfirm: async () => handleDeleteLine(line)
                                                })}
                                                style={{ 
                                                    padding: '6px', borderRadius: '6px', border: 'none', background: 'transparent', 
                                                    cursor: 'pointer', color: 'var(--color-error)' 
                                                }}
                                                className="hover:bg-error-bg"
                                            >
                                                <Trash2 size={18} />
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                    ) : (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', padding: '12px' }}>
                            {filteredLines.length === 0 ? (
                                <div style={{ background: 'var(--bg-subtle)', border: '1px dashed var(--color-border)', borderRadius: '16px', padding: '24px', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '0.95rem' }}>
                                    لا توجد خطوط مطابقة لخيارات البحث أو الفلترة الحالية.
                                </div>
                            ) : (
                                filteredLines.map((line) => (
                                    <MobileLineCard
                                        key={line.id}
                                        line={line}
                                        onOpenDrawer={openDrawer}
                                        onToggleStatus={handleToggleStatus}
                                        onEdit={() => setEditingLine(line)}
                                        onDelete={() => setConfirmDelete({
                                          type: 'line',
                                          name: line.name,
                                          onConfirm: async () => handleDeleteLine(line)
                                        })}
                                    />
                                ))
                            )}
                        </div>
                    )}
                </div>
            </div>
        </div>

        {/* --- Drawers & Modals --- */}
        <ZonesDrawer 
            isOpen={!!selectedLineId}
            isCompactLayout={isCompactLayout}
            line={selectedLine}
            zones={selectedLine ? zonesMap[selectedLine.id] : []}
            loading={selectedLineId ? loadingZones.has(selectedLineId) : false}
            onClose={() => setSelectedLineId(null)}
            onUpdate={() => selectedLineId && fetchZones(selectedLineId, setZonesMap, notify)}
            onDeleteZone={(z: { name: any; id: string; }) => setConfirmDelete({ 
                type: 'zone', name: z.name, 
                onConfirm: async () => {
                    await deleteZone(container.lineRepository, z.id);
                    if(selectedLineId) fetchZones(selectedLineId, setZonesMap, notify);
                    setConfirmDelete(null);
                } 
            })}
        />

        {isCreateModalOpen && (
            <CreateLineModal 
                isCompactLayout={isCompactLayout}
                contractTypes={contractTypes} vehicles={vehicles} companyPhones={companyPhones}
                onClose={() => setIsCreateModalOpen(false)} onSuccess={() => { setIsCreateModalOpen(false); loadData(); }}
            />
        )}
        
        {editingLine && (
            <EditLineModal 
                isCompactLayout={isCompactLayout}
                line={editingLine} contractTypes={contractTypes} vehicles={vehicles} companyPhones={companyPhones}
                onClose={() => setEditingLine(null)} onSuccess={() => { setEditingLine(null); loadData(); }}
            />
        )}

        {/* Delete Confirmation */}
        {confirmDelete && (
             <div className="app-modal-overlay" style={{ zIndex: 1400 }}>
                <div className="app-modal" style={{ width: isCompactLayout ? '100%' : '400px', textAlign: 'center', boxShadow: 'var(--shadow-xl)' }}>
                    <div style={{ width: '64px', height: '64px', borderRadius: '20px', background: 'var(--color-error-bg)', color: 'var(--color-error)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
                        <Trash2 size={32} />
                    </div>
                    <h3 style={{ margin: '0 0 8px', fontSize: '1.25rem', color: 'var(--text-primary)' }}>تأكيد الحذف</h3>
                    <p style={{ margin: '0 0 24px', color: 'var(--text-secondary)' }}>هل أنت متأكد من حذف <strong>"{confirmDelete.name}"</strong>؟</p>
                    <div style={{ display: 'flex', gap: '12px', flexDirection: isCompactLayout ? 'column' : 'row' }}>
                        <button className="button secondary" style={{ flex: 1 }} onClick={() => setConfirmDelete(null)}>إلغاء</button>
                        <button className="button" style={{ flex: 1, backgroundColor: 'var(--color-error)', color: 'white', border: 'none' }} onClick={confirmDelete.onConfirm}>حذف نهائي</button>
                    </div>
                </div>
            </div>
        )}
    </div>
  );
};

const thStyle = { padding: '16px 20px', textAlign: 'right' as const, fontWeight: 600, color: 'var(--text-secondary)', borderBottom: '1px solid var(--color-border)', fontSize: '0.9rem' };
const tdStyle = { padding: '16px 20px', borderBottom: '1px solid var(--color-border)', verticalAlign: 'middle', fontSize: '0.95rem' };

const MobileLineCard = ({ line, onOpenDrawer, onToggleStatus, onEdit, onDelete }: any) => {
    const isActive = line.status === 'active';

    return (
        <div style={{
            background: 'var(--bg-card)',
            border: '1px solid var(--color-border)',
            borderRadius: '16px',
            padding: '14px',
            boxShadow: 'var(--shadow-sm)',
            display: 'flex',
            flexDirection: 'column',
            gap: '12px'
        }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: '12px', alignItems: 'flex-start' }}>
                <div style={{ minWidth: 0, flex: 1 }}>
                    <div style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '4px' }}>{line.name}</div>
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', padding: '4px 8px', borderRadius: '999px', background: 'var(--neutral-100)', color: 'var(--text-secondary)', fontSize: '0.78rem', fontWeight: 600 }}>
                        <Calendar size={12} /> {line.lineType || 'عقد مسار'}
                    </div>
                </div>

                <button
                    type="button"
                    onClick={() => onToggleStatus(line)}
                    style={{
                        cursor: 'pointer',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                        padding: '6px 10px',
                        borderRadius: '999px',
                        border: 'none',
                        fontSize: '0.75rem',
                        fontWeight: 700,
                        backgroundColor: isActive ? 'var(--color-success-bg)' : 'var(--color-error-bg)',
                        color: isActive ? 'var(--color-success)' : 'var(--color-error)',
                        whiteSpace: 'nowrap',
                        flexShrink: 0
                    }}
                >
                    <div style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: 'currentColor' }} />
                    {isActive ? 'نشط' : 'متوقف'}
                </button>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '10px' }}>
                <div style={{ padding: '10px 12px', borderRadius: '12px', background: 'var(--bg-subtle)' }}>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)', marginBottom: '4px' }}>السيارة</div>
                    <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-primary)' }}>{line.vehiclePlate || '--'}</div>
                </div>
                <div style={{ padding: '10px 12px', borderRadius: '12px', background: 'var(--bg-subtle)' }}>
                    <div style={{ fontSize: '0.72rem', color: 'var(--text-tertiary)', marginBottom: '4px' }}>الهاتف</div>
                    <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-primary)' }}>{line.phoneDisplay || '--'}</div>
                </div>
            </div>

            <button
                type="button"
                onClick={() => onOpenDrawer(line)}
                style={{
                    width: '100%',
                    border: '1px solid var(--color-border)',
                    background: 'white',
                    borderRadius: '12px',
                    padding: '10px 12px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    gap: '8px',
                    fontSize: '0.9rem',
                    color: 'var(--color-primary)',
                    fontWeight: 700
                }}
            >
                <span>{line.zoneCount} منطقة</span>
                <ArrowRight size={14} />
            </button>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                <button
                    type="button"
                    title="تعديل"
                    onClick={onEdit}
                    className="button secondary"
                    style={{ justifyContent: 'center', width: '100%' }}
                >
                    <Pencil size={16} /> تعديل
                </button>
                <button
                    type="button"
                    title="حذف"
                    onClick={onDelete}
                    className="button"
                    style={{ justifyContent: 'center', width: '100%', backgroundColor: 'var(--color-error)', color: 'white', border: 'none' }}
                >
                    <Trash2 size={16} /> حذف
                </button>
            </div>
        </div>
    );
};


const ZonesDrawer = ({ isOpen, line, zones, loading, onClose, onUpdate, onDeleteZone, isCompactLayout }: any) => {
    const [dragIndex, setDragIndex] = useState<number | null>(null);
    const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
    const [localZones, setLocalZones] = useState<Zone[]>([]);
    const { notify } = useToast();

    useEffect(() => { if (zones) setLocalZones(zones); }, [zones]);

    const handleDrop = async () => {
        if (dragIndex === null || dragOverIndex === null || dragIndex === dragOverIndex) {
            setDragIndex(null); setDragOverIndex(null); return;
        }
        const newZones = [...localZones];
        const [moved] = newZones.splice(dragIndex, 1);
        if (moved) {
            newZones.splice(dragOverIndex, 0, moved);
        }
        
        const reordered = newZones.map((z, i) => ({ ...z, sortOrder: i + 1 }));
        setLocalZones(reordered);
        setDragIndex(null); setDragOverIndex(null);

        try {
            await container.lineRepository.reorderZones(reordered.map((z, i) => ({ id: z.id, sortOrder: i + 1 })));
            notify("تم حفظ الترتيب الجديد");
            onUpdate(); 
        } catch (err: any) {
            notify(toClientErrorMessage(err, "تعذر حفظ ترتيب المناطق حالياً. حاول مرة أخرى."));
            onUpdate();
        }
    };

    return (
        <>
            <div 
                onClick={onClose}
                style={{
                    position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(2px)',
                    opacity: isOpen ? 1 : 0, pointerEvents: isOpen ? 'auto' : 'none', transition: 'all 0.4s', zIndex: 1100
                }}
            />
            <div style={{
                position: 'fixed', top: 0, left: 0, bottom: 0, width: isCompactLayout ? '100vw' : '500px', maxWidth: isCompactLayout ? '100vw' : '90vw',
                background: 'var(--bg-card)', boxShadow: 'var(--shadow-xl)',
                transform: isOpen ? 'translateX(0)' : 'translateX(-100%)',
                transition: 'transform 0.4s cubic-bezier(0.16, 1, 0.3, 1)', zIndex: 1110,
                display: 'flex', flexDirection: 'column'
            }}>
                {line && (
                    <>
                        <div style={{ padding: isCompactLayout ? '16px' : '24px', background: 'var(--bg-card)', borderBottom: '1px solid var(--color-border)', flexShrink: 0 }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '16px' }}>
                                <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', background: 'var(--green-50)', padding: '6px 12px', borderRadius: '20px', color: 'var(--color-primary)', fontSize: '0.85rem', fontWeight: 'bold' }}>
                                    <MapPin size={14} /> خط سير
                                </div>
                                <button onClick={onClose} className="button secondary icon-only" style={{ borderRadius: '8px' }}><X size={20} /></button>
                            </div>
                            <h2 style={{ margin: '0 0 6px', fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)' }}>{line.name}</h2>
                            <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.9rem' }}>يمكنك ترتيب المناطق بالسحب والإفلات.</p>
                        </div>
                        
                        <div style={{ flex: 1, overflowY: 'auto', padding: isCompactLayout ? '16px' : '24px' }}>
                            {loading ? (
                                <div style={{ display: 'flex', justifyContent: 'center', padding: '40px' }}><div className="spinner" /></div>
                            ) : (
                                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                    {localZones.length === 0 && <div style={{ textAlign: 'center', padding: '40px', color: 'var(--text-tertiary)', border: '2px dashed var(--color-border)', borderRadius: '16px' }}>لا توجد مناطق</div>}
                                    {localZones.map((zone, idx) => (
                                        <div 
                                            key={zone.id} draggable data-allow-drag
                                            onDragStart={() => setDragIndex(idx)}
                                            onDragOver={(e) => { e.preventDefault(); setDragOverIndex(idx); }}
                                            onDragEnd={handleDrop}
                                            style={{ 
                                                display: 'flex', alignItems: 'center', gap: isCompactLayout ? '12px' : '16px', padding: '12px 16px', 
                                                flexWrap: isCompactLayout ? 'wrap' : 'nowrap',
                                                borderRadius: '12px', background: dragIndex === idx ? 'var(--green-50)' : 'var(--bg-subtle)',
                                                border: dragOverIndex === idx && dragIndex !== null && dragIndex !== idx ? '2px solid var(--color-primary)' : '1px solid transparent',
                                                cursor: 'grab', color: 'var(--text-primary)'
                                            }}
                                        >
                                            <div style={{ color: 'var(--text-tertiary)', cursor: 'grab' }}><GripVertical size={20} /></div>
                                            <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: 'var(--neutral-200)', color: 'var(--text-secondary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, flexShrink: 0, fontSize: '0.85rem' }}>{idx + 1}</div>
                                            <div style={{ flex: 1, fontWeight: 600, minWidth: 0 }}>{zone.name}</div>
                                            <button onClick={() => onDeleteZone(zone)} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--color-error)', opacity: 0.7 }} className="hover:opacity-100"><Trash2 size={18} /></button>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                        
                        <div style={{ padding: isCompactLayout ? '16px' : '24px', background: 'var(--bg-card)', borderTop: '1px solid var(--color-border)' }}>
                             <AddZoneForm lineId={line.id} nextOrder={localZones.length + 1} onSuccess={onUpdate} isCompactLayout={isCompactLayout} />
                        </div>
                    </>
                )}
            </div>
        </>
    );
};

const AddZoneForm = ({ lineId, nextOrder, onSuccess, isCompactLayout }: any) => {
    const [name, setName] = useState("");
    const [loading, setLoading] = useState(false);
    const { notify } = useToast();
    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if(!name.trim()) {
            notify("يرجى إدخال اسم المنطقة قبل الحفظ.");
            return;
        }
        setLoading(true);
        const res = await createZone(container.lineRepository, { lineId, name, sortOrder: nextOrder });
        setLoading(false);
        if(res.ok) {
            notify("تمت إضافة المنطقة بنجاح");
            setName("");
            onSuccess();
        } else {
            notify(toClientErrorMessage(res.error?.message, "تعذر إضافة المنطقة حالياً. حاول مرة أخرى."));
        }
    };
    return (
        <form onSubmit={handleSubmit} style={{ display: 'flex', gap: '12px', flexDirection: isCompactLayout ? 'column' : 'row' }}>
            <input 
                placeholder="مثال: السالمية" 
                value={name} onChange={e => setName(e.target.value)}
                className="input"
                style={{ flex: 1, width: isCompactLayout ? '100%' : 'auto' }}
            />
            <button type="submit" disabled={loading || !name} className="button primary" style={{ opacity: name ? 1 : 0.6, width: isCompactLayout ? '100%' : 'auto', justifyContent: 'center' }}>
                {loading ? '...' : 'إضافة'}
            </button>
        </form>
    )
};

const Modal = ({ title, onClose, children, isCompactLayout }: any) => (
    <div className="app-modal-overlay" style={{ zIndex: 1200 }}>
        <div className="app-modal" style={{ width: isCompactLayout ? '100%' : '500px', maxWidth: isCompactLayout ? '100%' : '500px', padding: 0, overflow: 'hidden' }}>
            <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--color-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'var(--bg-subtle)' }}>
                <h3 style={{ margin: 0, fontWeight: 700, fontSize: '1.1rem', color: 'var(--text-primary)' }}>{title}</h3>
                <button onClick={onClose} style={{ border: 'none', background: 'transparent', cursor: 'pointer', color: 'var(--text-secondary)' }}><X size={20} /></button>
            </div>
            <div style={{ padding: '24px' }}>{children}</div>
        </div>
    </div>
);

const CreateLineModal = ({ contractTypes, vehicles, companyPhones, onClose, onSuccess, isCompactLayout }: any) => {
    const [name, setName] = useState("");
    const [typeId, setTypeId] = useState("");
    const [vehicleId, setVehicleId] = useState("");
    const [phoneId, setPhoneId] = useState("");
    const { notify } = useToast();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!name.trim()) {
            notify("يرجى إدخال اسم خط السير قبل الحفظ.");
            return;
        }
        const res = await createLine(container.lineRepository, {
            name, contractTypeId: typeId || null, lineType: contractTypes.find((t: any) => t.id === typeId)?.name || "",
            phoneNumber: companyPhones.find((p: any) => p.id === phoneId)?.phoneNumber || null,
            carNumber: vehicles.find((v: any) => v.id === vehicleId)?.plateNumber || null,
            vehicleId: vehicleId || null, phoneId: phoneId || null
        });
        if(res.ok) {
            notify("تم إنشاء خط السير بنجاح");
            onSuccess();
        } else {
            notify(toClientErrorMessage(res.error?.message, "تعذر إنشاء خط السير حالياً. حاول مرة أخرى."));
        }
    };

    return (
        <Modal title="إضافة خط جديد" onClose={onClose} isCompactLayout={isCompactLayout}>
            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>اسم الخط</label>
                    <input className="input" placeholder="مثال: خط حولي" value={name} onChange={e => setName(e.target.value)} required />
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>نوع العقد</label>
                    <CustomSelect
                        value={typeId}
                        onChange={setTypeId}
                        options={[{ id: "", label: "اختر نوع العقد..." }, ...contractTypes.map((t: any) => ({ id: t.id, label: t.name }))]}
                        width="100%"
                        placeholder="اختر نوع العقد..."
                    />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: isCompactLayout ? '1fr' : '1fr 1fr', gap: '16px' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                         <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>السيارة</label>
                        <CustomSelect
                            value={vehicleId}
                            onChange={setVehicleId}
                            options={[{ id: "", label: "بدون سيارة" }, ...vehicles.map((v: any) => ({ id: v.id, label: v.plateNumber }))]}
                            width="100%"
                            placeholder="بدون سيارة"
                        />
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>الهاتف</label>
                        <CustomSelect
                            value={phoneId}
                            onChange={setPhoneId}
                            options={[{ id: "", label: "بدون هاتف" }, ...companyPhones.map((p: any) => ({ id: p.id, label: p.phoneNumber }))]}
                            width="100%"
                            placeholder="بدون هاتف"
                        />
                    </div>
                </div>
                <div style={{ marginTop: '8px' }}>
                    <button type="submit" className="button primary" style={{ width: '100%', justifyContent: 'center' }}>
                         <Plus size={18} /> حفظ الخط
                    </button>
                </div>
            </form>
        </Modal>
    );
};

const EditLineModal = ({ line, contractTypes, vehicles, companyPhones, onClose, onSuccess, isCompactLayout }: any) => {
    const [name, setName] = useState(line.name);
    const [typeId, setTypeId] = useState(line.contractTypeId || "");
    const [vehicleId, setVehicleId] = useState(line.vehicleId || "");
    const [phoneId, setPhoneId] = useState(line.phoneId || "");
    const { notify } = useToast();
    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!name.trim()) {
            notify("يرجى إدخال اسم خط السير قبل حفظ التعديلات.");
            return;
        }
        const res = await updateLine(container.lineRepository, {
            id: line.id, name, contractTypeId: typeId || null, lineType: contractTypes.find((t: any) => t.id === typeId)?.name || "",
            phoneNumber: companyPhones.find((p: any) => p.id === phoneId)?.phoneNumber || null, carNumber: vehicles.find((v: any) => v.id === vehicleId)?.plateNumber || null,
            vehicleId: vehicleId || null, phoneId: phoneId || null, isActive: line.status === 'active'
        });
        if(res.ok) {
            notify("تم تحديث بيانات خط السير بنجاح");
            onSuccess();
        } else {
            notify(toClientErrorMessage(res.error?.message, "تعذر تحديث بيانات خط السير حالياً. حاول مرة أخرى."));
        }
    };
    return (
        <Modal title="تعديل الخط" onClose={onClose} isCompactLayout={isCompactLayout}>
           <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>اسم الخط</label>
                    <input className="input" placeholder="مثال: خط حولي" value={name} onChange={e => setName(e.target.value)} required />
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                    <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>نوع العقد</label>
                    <CustomSelect
                        value={typeId}
                        onChange={setTypeId}
                        options={[{ id: "", label: "اختر نوع العقد..." }, ...contractTypes.map((t: any) => ({ id: t.id, label: t.name }))]}
                        width="100%"
                        placeholder="اختر نوع العقد..."
                    />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: isCompactLayout ? '1fr' : '1fr 1fr', gap: '16px' }}>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                         <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>السيارة</label>
                        <CustomSelect
                            value={vehicleId}
                            onChange={setVehicleId}
                            options={[{ id: "", label: "بدون سيارة" }, ...vehicles.map((v: any) => ({ id: v.id, label: v.plateNumber }))]}
                            width="100%"
                            placeholder="بدون سيارة"
                        />
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                        <label style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>الهاتف</label>
                        <CustomSelect
                            value={phoneId}
                            onChange={setPhoneId}
                            options={[{ id: "", label: "بدون هاتف" }, ...companyPhones.map((p: any) => ({ id: p.id, label: p.phoneNumber }))]}
                            width="100%"
                            placeholder="بدون هاتف"
                        />
                    </div>
                </div>
                <div style={{ marginTop: '8px' }}>
                    <button type="submit" className="button primary" style={{ width: '100%', justifyContent: 'center' }}>
                         <Pencil size={18} /> حفظ التغييرات
                    </button>
                </div>
            </form>
        </Modal>
    );
};
