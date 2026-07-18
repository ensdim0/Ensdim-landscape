import React, { useEffect, useState, useRef, useCallback, useMemo } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { 
  FileText, 
  Search, 
  Plus, 
  Pencil, 
  Trash2,
  X,
  Save,
  Filter,
  Calendar,
  DollarSign,
  User as UserIcon,
  MapPin,
  CheckCircle,
  AlertCircle,
  ClipboardList,
  Check,
  Eye,
  Clock,
  CheckSquare,
  XCircle,
  ShieldCheck,
  Loader2,
  Receipt,
  ChevronDown,
  ChevronLeft,
  BarChart3,
  ExternalLink,
  Mail,
  Shield,
  Home,
  Link2,
  Hash,
  GripVertical,
  ImageIcon,
  Upload,
  Phone,
  Download,
  MoreVertical,
  ArrowRight,
  Copy,
  CreditCard,
  LayoutList,
  Truck
} from "lucide-react";

import { ContractTask, TaskStatus } from "@domain/entities/ContractTask";
import { Invoice } from "@domain/entities/Invoice";
import { Visit, VisitStatus } from "@domain/entities/Visit";

import { container } from "@infrastructure/di/container";
import { Contract, ContractPalmInfo } from "@domain/entities/Contract";
import { User } from "@domain/entities/User";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Zone } from "@domain/entities/Zone";
import { ContractType } from "@domain/entities/ContractType";
import { ContractTerm } from "@domain/entities/ContractTerm";
import { ContractPayment, PaymentMethod } from "@domain/entities/ContractPayment";

import { ContractDetailsModal, StatusPicker } from "@presentation/components/ContractDetailsModal";
import { ContractVisitsManagerModal } from "@presentation/components/ContractVisitsManagerModal";

import { createContract } from "@application/use-cases/admin/createContract";
import { updateContract } from "@application/use-cases/admin/updateContract";
import { deleteContract } from "@application/use-cases/admin/deleteContract";
import { getContracts } from "@application/use-cases/admin/getContracts";
import { UpdateContractDTO } from "@application/dtos/UpdateContractDTO";
import { useToast } from "@presentation/components/ToastProvider";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { formatDate } from "@shared/utils/date";
import { sha256 } from "@shared/utils/crypto";
import { compressImage } from "@shared/utils/imageCompression";
import { CONTRACT_STATUS_FILTERS, CONTRACT_STATUS_LABELS, CONTRACT_STATUS_OPTIONS, normalizeContractStatus } from "@shared/contractStatus";

const Badge = ({ children, variant = 'default', className = '', style = {} }: any) => {
    const styles: any = {
        default: { bg: 'var(--neutral-100)', color: 'var(--text-secondary)' },
        success: { bg: 'var(--color-success-bg)', color: 'var(--color-success)' },
        warning: { bg: 'var(--color-warning-bg)', color: 'var(--color-warning)' },
        error: { bg: 'var(--color-error-bg)', color: 'var(--color-error)' },
        info: { bg: 'var(--color-info-bg)', color: 'var(--color-info)' },
        primary: { bg: 'var(--green-50)', color: 'var(--color-primary)' }
    };
    const s = styles[variant] || styles.default;
    
    return (
        <span style={{ 
            backgroundColor: s.bg, 
            color: s.color,
            padding: '4px 10px',
            borderRadius: '12px',
            fontSize: '0.75rem',
            fontWeight: 600,
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            lineHeight: 1,
            whiteSpace: 'nowrap',
            ...style,
            ...className
        }}>
            {children}
        </span>
    );
};

type DraftContractPayment = {
    id: string;
    amount: number;
    paymentMethod: PaymentMethod;
    paymentDate: string;
    notes?: string;
    imageFile?: File | null;
};

type ContractFormSubmitData = Record<string, any> & {
    initialPayments?: DraftContractPayment[];
    palmInfo?: ContractPalmInfo | null;
};

const PAYMENT_METHOD_OPTIONS: { value: PaymentMethod; label: string }[] = [
    { value: 'cash', label: 'نقدي' },
    { value: 'transfer', label: 'رابط' },
    { value: 'cheque', label: 'شيك' },
    { value: 'card', label: 'ومض' },
];

const getPaymentMethodLabel = (method: string) => PAYMENT_METHOD_OPTIONS.find((item) => item.value === method)?.label || method;

export const ContractsPage: React.FC = () => {
  const navigate = useNavigate();
    const [params] = useSearchParams();
  const [contracts, setContracts] = useState<Contract[]>([]);
  const [clientUsers, setClientUsers] = useState<User[]>([]);
  const [lines, setLines] = useState<GeographicLine[]>([]);
  const [zones, setZones] = useState<Zone[]>([]);
  const [types, setTypes] = useState<ContractType[]>([]);
  
  const [isLoading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [lineFilter, setLineFilter] = useState("ALL");
  const [zoneFilter, setZoneFilter] = useState("ALL");
  const [typeFilter, setTypeFilter] = useState("ALL");
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [editingContract, setEditingContract] = useState<Contract | null>(null);
    const [managingVisitsContract, setManagingVisitsContract] = useState<Contract | null>(null);
  const [deletingContract, setDeletingContract] = useState<Contract | null>(null);
  const [viewingContract, setViewingContract] = useState<Contract | null>(null);
  const [initialVisitId, setInitialVisitId] = useState<string | null>(null);
  const [initialTab, setInitialTab] = useState<"summary" | "visits" | "payments" | "tasks" | null>(null);
  const [uploadingContractId, setUploadingContractId] = useState<string | null>(null);
  const [contractPayments, setContractPayments] = useState<Record<string, number>>({});
  const [lateContractIds, setLateContractIds] = useState<Set<string>>(new Set());
  const [lateOnly, setLateOnly] = useState(false);
    const [selectedContractIds, setSelectedContractIds] = useState<string[]>([]);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const uploadTargetId = useRef<string | null>(null);

  const { notify } = useToast();

  useEffect(() => {
    loadData();
  }, []);

    // If opened via a notification link containing ?contractId=..., open the contract details modal
    useEffect(() => {
        const contractId = params.get("contractId");
        const visitId = params.get("visitId");
        const notificationType = params.get("type");
        if (!contractId) return;
        const open = (contract: Contract) => {
            setInitialVisitId(visitId || null);
            setInitialTab(
                notificationType === "payment_received_admin" || notificationType === "payment_late_admin"
                    ? "payments"
                    : null
            );
            setViewingContract(contract);
        };
        const found = contracts.find((c) => c.id === contractId);
        if (found) {
            open(found);
            return;
        }

        // If contracts haven't loaded yet, attempt to reload data and then open
        if (!isLoading) {
            loadData().then(() => {
                const after = contracts.find((c) => c.id === contractId);
                if (after) open(after);
            }).catch(() => {});
        }
    }, [params, contracts, isLoading]);

  const loadData = async () => {
    setLoading(true);
    try {
        const [contractsRes, clientUsersRes, linesRes, typesRes, overduePayments] = await Promise.all([
            getContracts(container.adminRepository),
            container.adminRepository.listClientUsers(),
            container.lineRepository.listLines(),
            container.adminRepository.listContractTypes(),
            container.adminRepository.listOverdueContractPayments().catch(() => [] as ContractPayment[])
        ]);

        if (contractsRes.ok) {
            setContracts(contractsRes.data);
            setClientUsers(clientUsersRes);
            setLines(linesRes);
            setTypes(typesRes);
            const allZones = (await Promise.all(linesRes.map(l => container.lineRepository.listZones(l.id)))).flat();
            setZones(allZones);

            // عقود فيها دفعة تجاوز تاريخ استحقاقها ولم تُدفع بعد
            const lateIds = new Set(overduePayments.map((p: ContractPayment) => p.contractId));
            setLateContractIds(lateIds);
            
            // تحميل الدفعات بشكل متوازي مع timeout
            const paymentsMap: Record<string, number> = {};
            
            // دالة مساعدة مع timeout
            const loadPaymentWithTimeout = async (contractId: string, timeoutMs = 5000): Promise<number> => {
                return Promise.race([
                    container.adminRepository.listContractPayments(contractId).then(payments => 
                        payments.reduce((sum: number, p: any) => sum + p.amount, 0)
                    ),
                    new Promise<number>((_, reject) => 
                        setTimeout(() => reject(new Error('timeout')), timeoutMs)
                    )
                ]).catch(() => 0);
            };
            
            // تحميل الدفعات مع معالجة الأخطاء
            await Promise.allSettled(
                contractsRes.data.map(async (c: Contract) => {
                    try {
                        paymentsMap[c.id] = await loadPaymentWithTimeout(c.id);
                    } catch (e) {
                        paymentsMap[c.id] = 0;
                    }
                })
            );
            setContractPayments(paymentsMap);
        } else {
            setError(contractsRes.error?.message || "فشل تحميل البيانات");
        }
    } catch (e) {
        console.error('loadData error:', e);
        setError("خطأ غير متوقع");
    } finally {
        setLoading(false);
    }
  };

    const handleCreate = async (data: ContractFormSubmitData) => {
        const { initialPayments = [], ...contractData } = data;

        const cleanedTerms = (contractData.terms || [])
        .filter((t: any) => !t.isExcluded)
        .map((t: any) => ({
            ...t,
            visits: (t.visits || []).filter((v: any) => !v.isExcluded)
        }));

    const result = await createContract(container.adminRepository, {
            userId: contractData.clientId,
            zoneId: contractData.zoneId as string,
            code: contractData.code,
            contractTypeId: contractData.contractTypeId || undefined,
            durationMonths: Number(contractData.durationMonths) || undefined,
            addressDetails: contractData.addressDetails || undefined,
            notes: contractData.notes || undefined,
            palmInfo: contractData.palmInfo || undefined,
            blockNumber: contractData.blockNumber || undefined,
            street: contractData.street || undefined,
            avenue: contractData.avenue || undefined,
            house: contractData.house || undefined,
            kuwaitFinderUrl: contractData.kuwaitFinderUrl || undefined,
            contractUserName: contractData.contractUserName || "",
            contractUserPhone: contractData.contractUserPhone || "",
            contractUserPasswordHash: contractData.contractUserPasswordHash || "",
            startDate: contractData.startDate,
            endDate: contractData.endDate,
            totalValue: Number(contractData.totalValue) || 0,
            status: contractData.status,
            terms: cleanedTerms,
            firstVisitDate: contractData.firstVisitDate || undefined,
      });

      if (result.ok) {
          const contract = result.data;

          // إنشاء الزيارات والمهام بدون تاريخ (يتم تحديده لاحقاً يدوياً)
          // كل زيارة مستقلة عن الأخرى، فنُنشئها بالتوازي لتقليل زمن الحفظ بدلاً من الانتظار تتابعيًا
          const visitJobs: { termContent?: string; description?: string; tasks: any[]; month: number }[] = [];
          for (const term of cleanedTerms) {
              if (!term.visits || term.visits.length === 0) continue;
              for (const vt of term.visits) {
                  const visitCount = vt.count || 1;
                  for (let i = 0; i < visitCount; i++) {
                      visitJobs.push({ termContent: term.content, description: vt.description, tasks: vt.tasks || [], month: i + 1 });
                  }
              }
          }

          let visitCreationErrors = 0;
          await Promise.all(visitJobs.map(async (job) => {
              try {
                  const createdVisit = await container.adminRepository.createVisit({
                      contractId: contract.id,
                      notes: job.description || undefined,
                      title: job.termContent || undefined,
                  });

                  const taskResults = await Promise.allSettled(job.tasks.map((task) =>
                      container.adminRepository.createContractTask({
                          visitId: createdVisit.id,
                          contractId: contract.id,
                          title: task.title,
                          month: job.month,
                      })
                  ));
                  taskResults.forEach((r) => {
                      if (r.status === "rejected") {
                          console.error("Error creating task:", r.reason);
                          visitCreationErrors++;
                      }
                  });
              } catch (visitError) {
                  console.error("Error creating visit:", visitError);
                  visitCreationErrors++;
              }
          }));

          if (visitCreationErrors > 0) {
              console.warn(`تحذير: فشل إنشاء ${visitCreationErrors} من الزيارات/المهام`);
          }

          // إنشاء الدفعات (بالتوازي أيضًا لأنها مستقلة عن بعضها)
          if (initialPayments.length > 0) {
              const paymentResults = await Promise.allSettled(initialPayments.map(async (payment) => {
                  const createdPayment = await container.adminRepository.createContractPayment({
                      contractId: contract.id,
                      amount: payment.amount,
                      paymentMethod: payment.paymentMethod,
                      notes: payment.notes,
                      paymentDate: payment.paymentDate,
                  });

                  if (payment.imageFile) {
                      try {
                          const compressed = await compressImage(payment.imageFile);
                          await container.adminRepository.uploadPaymentImage(
                              createdPayment.id,
                              compressed,
                              payment.imageFile.name.replace(/\.[^.]+$/, '.jpg')
                          );
                      } catch (uploadError) {
                          console.error('Error uploading payment image:', uploadError);
                          // لا نعتبرها فشل كامل للدفعة
                      }
                  }
              }));

              const failedPayments = paymentResults.filter((r) => r.status === "rejected").length;
              paymentResults.forEach((r) => {
                  if (r.status === "rejected") console.error('Error creating payment:', r.reason);
              });

              if (failedPayments > 0) {
                  notify(`تم إنشاء العقد، ولكن تعذر حفظ ${failedPayments} دفعة`);
              }
          }

          notify("تم إنشاء العقد بنجاح");
          setShowCreateModal(false);
          
          // تحديث محلي للبيانات بدلاً من إعادة تحميل كل شيء (الأحدث أولاً)
          setContracts(prev => [contract, ...prev]);
          
          // محاولة تحميل البيانات مع timeout (بدون انتظار)
          loadData().catch(e => {
              console.warn('loadData failed but form was saved:', e);
          });
      } else {
          notify(result.error?.message || "فشل إنشاء العقد");
      }
  };

  const handleUpdate = async (data: ContractFormSubmitData) => {
      const { initialPayments: _initialPayments, ...updateData } = data;

      const result = await updateContract(container.adminRepository, {
          id: editingContract!.id,
          userId: updateData.clientId,
          zoneId: updateData.zoneId || editingContract!.zoneId || "",
          code: updateData.code,
          contractTypeId: updateData.contractTypeId || undefined,
          durationMonths: Number(updateData.durationMonths) || undefined,
          addressDetails: updateData.addressDetails || undefined,
          notes: updateData.notes || undefined,
          palmInfo: updateData.palmInfo || undefined,
          blockNumber: updateData.blockNumber || undefined,
          street: updateData.street || undefined,
          avenue: updateData.avenue || undefined,
          house: updateData.house || undefined,
          kuwaitFinderUrl: updateData.kuwaitFinderUrl || undefined,
          contractUserName: updateData.contractUserName,
          contractUserPhone: updateData.contractUserPhone,
          startDate: updateData.startDate,
          firstVisitDate: updateData.firstVisitDate || undefined,
          endDate: updateData.endDate,
          totalValue: Number(updateData.totalValue) || 0,
          status: updateData.status,
          terms: editingContract?.terms || [],
      } as UpdateContractDTO);

      if (result.ok) {
          notify("تم تحديث العقد بنجاح مع الحفاظ على الزيارات الحالية");
          setEditingContract(null);
          loadData();
      } else {
          notify(result.error?.message || "فشل تحديث العقد");
      }
  };

  const confirmDelete = async () => {
      if (!deletingContract) return;
      const result = await deleteContract(container.adminRepository, deletingContract.id);
      
      if (result.ok) {
          notify("تم حذف العقد بنجاح");
          setDeletingContract(null);
          loadData();
      } else {
          notify(result.error?.message || "فشل حذف العقد");
      }
  };

  const triggerImageUpload = (contractId: string) => {
      uploadTargetId.current = contractId;
      fileInputRef.current?.click();
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      const contractId = uploadTargetId.current;
      if (!file || !contractId) return;
      e.target.value = '';
      if (!file.type.startsWith('image/')) {
          notify('يرجى اختيار ملف صورة');
          return;
      }
      setUploadingContractId(contractId);
      try {
          const compressed = await compressImage(file);
          await container.adminRepository.uploadContractImage(contractId, compressed, file.name.replace(/\.[^.]+$/, '.jpg'));
          notify('تم رفع صورة العقد بنجاح');
          loadData();
      } catch (err: any) {
          notify(err?.message || 'فشل رفع الصورة');
      } finally {
          setUploadingContractId(null);
      }
  };

  const handleStatusChange = async (contract: Contract, newStatus: string) => {
      if (contract.status === newStatus) return;
      try {
          await container.adminRepository.updateContractStatus(contract.id, newStatus);
          notify("تم تغيير حالة العقد");
          loadData();
      } catch {
          notify("فشل تغيير الحالة");
      }
  };

    const filteredContracts = useMemo(() => contracts.filter(c => {
            const normalizedSearchQuery = searchQuery.trim().toLowerCase();
            const searchDigits = normalizedSearchQuery.replace(/\D/g, "");
            const client = clientUsers.find(u => u.id === c.clientId);
            const clientName = client?.fullName?.toLowerCase() || "";
            const clientPhoneDigits = (client?.phone || "").replace(/\D/g, "");
            const contractPhoneDigits = (c.contractUserPhone || "").replace(/\D/g, "");
            const matchesSearch = 
                c.code.toLowerCase().includes(normalizedSearchQuery) ||
                clientName.includes(normalizedSearchQuery) ||
                (searchDigits && clientPhoneDigits.includes(searchDigits)) ||
                (searchDigits && contractPhoneDigits.includes(searchDigits));
      
    const matchesStatus = statusFilter === "ALL" || normalizeContractStatus(c.status) === statusFilter;
      const matchesLine = lineFilter === "ALL" || c.lineId === lineFilter;
      const matchesZone = zoneFilter === "ALL" || c.zoneId === zoneFilter;
      const matchesType = typeFilter === "ALL" || c.contractTypeId === typeFilter;
      const matchesLate = !lateOnly || lateContractIds.has(c.id);
      return matchesSearch && matchesStatus && matchesLine && matchesZone && matchesType && matchesLate;
  }), [contracts, searchQuery, statusFilter, lineFilter, zoneFilter, typeFilter, lateOnly, lateContractIds, clientUsers]);

  const selectedFilteredContracts = useMemo(() => {
      const selectedSet = new Set(selectedContractIds);
      return filteredContracts.filter(contract => selectedSet.has(contract.id));
  }, [filteredContracts, selectedContractIds]);

  const isAllFilteredSelected = filteredContracts.length > 0 && selectedFilteredContracts.length === filteredContracts.length;

  const toggleContractSelection = (contractId: string) => {
      setSelectedContractIds(prev => prev.includes(contractId)
          ? prev.filter(id => id !== contractId)
          : [...prev, contractId]
      );
  };

  const toggleSelectAllFiltered = () => {
      const filteredIds = filteredContracts.map(contract => contract.id);
      setSelectedContractIds(prev => {
          const allSelected = filteredIds.length > 0 && filteredIds.every(id => prev.includes(id));
          if (allSelected) {
              return prev.filter(id => !filteredIds.includes(id));
          }
          return Array.from(new Set([...prev, ...filteredIds]));
      });
  };

  useEffect(() => {
      const availableIds = new Set(filteredContracts.map(contract => contract.id));
      setSelectedContractIds(prev => {
          const next = prev.filter(id => availableIds.has(id));
          return next.length === prev.length ? prev : next;
      });
  }, [filteredContracts]);

  const getClientName = (id: string) => clientUsers.find(u => u.id === id)?.fullName || "غير معروف";
  const getClientPhone = (id: string) => clientUsers.find(u => u.id === id)?.phone || '';
  const getTypeName = (id?: string | null) => types.find(t => t.id === id)?.name || "غير محدد";
  const getLineName = (id?: string | null) => lines.find(l => l.id === id)?.name || "—";
  const getZoneName = (id?: string | null) => zones.find(z => z.id === id)?.name || null;

  const handleEditPaymentSummaryChange = useCallback((totalPaid: number) => {
      if (!editingContract) return;
      setContractPayments(prev => {
          if (prev[editingContract.id] === totalPaid) return prev;
          return { ...prev, [editingContract.id]: totalPaid };
      });
  }, [editingContract]);

  const normalizeAddressValue = (value?: string | null) => {
      const normalized = value?.trim();
      return normalized ? normalized : null;
  };

  const stripAddressPrefix = (value: string, prefixes: string[]) => {
      const escaped = prefixes.map(prefix => prefix.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
      const cleaned = value.replace(new RegExp(`^(?:${escaped})\\s*[:\\-]?\\s*`, 'i'), '').trim();
      return cleaned || value;
  };

  const getCompactAddress = (contract: Contract) => {
      const block = normalizeAddressValue(contract.blockNumber);
      const street = normalizeAddressValue(contract.street);
      const avenue = normalizeAddressValue(contract.avenue);
      const house = normalizeAddressValue(contract.house);

      const parts = [
          {
              shortLabel: 'ق',
              value: block ? stripAddressPrefix(block, ['ق', 'قطعة', 'block']) : null
          },
          {
              shortLabel: 'ش',
              value: street ? stripAddressPrefix(street, ['ش', 'شارع', 'street', 'st']) : null
          },
          {
              shortLabel: 'ج',
              value: avenue ? stripAddressPrefix(avenue, ['ج', 'جادة', 'avenue', 'ave']) : null
          },
          {
              shortLabel: 'م',
              value: house ? stripAddressPrefix(house, ['م', 'منزل', 'بيت', 'house', 'home']) : null
          }
      ]
          .filter(part => part.value)
          .map(part => `${part.shortLabel} ${part.value}`)
          .join(' - ');

      return parts || normalizeAddressValue(contract.addressDetails);
  };

  const getLocationDisplay = (contract: Contract) => {
      const zoneName = getZoneName(contract.zoneId);
      const compactAddress = getCompactAddress(contract);

      if (zoneName && compactAddress) return `${zoneName} • ${compactAddress}`;
      return zoneName || compactAddress || '—';
  };

  const getClientContracts = (clientId: string) => contracts.filter(c => c.clientId === clientId);

  const exportToExcel = () => {
      const exportSource = selectedFilteredContracts.length > 0 ? selectedFilteredContracts : filteredContracts;
      const headers = [
          'كود العقد', 'العميل', 'هاتف العميل', 'اسم مستخدم العقد',
          'الخط', 'المنطقة', 'نوع العقد', 'مدة العقد (شهر)',
          'الحالة', 'تاريخ البداية', 'تاريخ النهاية', 'القيمة الإجمالية',
          'تفاصيل العنوان', 'القطعة', 'الشارع', 'الجادة', 'المنزل',
          'رابط كويت فايندر', 'بنود العقد', 'تاريخ الإنشاء'
      ];
      const rows = exportSource.map(c => [
          c.code,
          getClientName(c.clientId),
          getClientPhone(c.clientId),
          getClientName(c.clientId),
          getLineName(c.lineId),
          getZoneName(c.zoneId) || '',
          getTypeName(c.contractTypeId),
          c.durationMonths?.toString() || '',
          CONTRACT_STATUS_LABELS[normalizeContractStatus(c.status)] || c.status,
          c.startDate || '',
          c.endDate || '',
          c.totalValue?.toString() || '0',
          c.addressDetails || '',
          c.blockNumber || '',
          c.street || '',
          c.avenue || '',
          c.house || '',
          c.kuwaitFinderUrl || '',
          (c.terms || []).map(t => t.content).join(' | '),
          c.createdAt ? formatDate(c.createdAt) : ''
      ]);
      const BOM = '\uFEFF';
      const csv = BOM + [headers, ...rows].map(r => r.map(v => `"${(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\n');
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `contracts_${new Date().toISOString().split('T')[0]}.csv`;
      a.click();
      URL.revokeObjectURL(url);
      notify(`تم تصدير ${exportSource.length} عقد${selectedFilteredContracts.length > 0 ? ' (العقود المحددة)' : ''}`);
  };

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

    return (
        <div className="contracts-page" style={{ padding: '24px', display: 'flex', flexDirection: 'column', height: '100vh', gap: '24px', backgroundColor: 'var(--bg-app)', boxSizing: 'border-box', overflowY: 'hidden' }}>
        
        <div className="contracts-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="contracts-title-wrap">
                <h1 className="contracts-title" style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '4px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <FileText size={28} style={{color: 'var(--color-primary)'}} />
                     إدارة العقود
                </h1>
                <p className="contracts-subtitle" style={{ color: 'var(--text-tertiary)', fontSize: '0.9rem', margin: 0 }}>
                    عرض وإدارة جميع العقود في النظام ({contracts.length} عقد)
                </p>
            </div>
            <button 
                className="button primary contracts-add-btn" 
                onClick={() => setShowCreateModal(true)}
                style={{ height: '44px', padding: '0 24px', borderRadius: 'var(--radius-md)', fontSize: '0.95rem' }}
            >
                <Plus size={20} />
                عقد جديد
            </button>
        </div>

        <div className="contracts-filters" style={{ 
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
            <div className="contracts-search-wrap" style={{ flex: 1, minWidth: '240px', position: 'relative' }}>
                <Search size={18} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', right: '12px', color: 'var(--text-tertiary)' }} />
                <input 
                    type="text" 
                    placeholder="بحث برقم العقد، اسم العميل، أو رقم الهاتف..." 
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


            <div className="contracts-filters-controls" style={{ display: 'flex', gap: '10px', alignItems: 'center', flexWrap: 'wrap' }}>
                <CustomSelect
                    className="contracts-filter-select"
                    value={lineFilter}
                    onChange={(val) => { setLineFilter(val); setZoneFilter("ALL"); }}
                    options={[{ id: 'ALL', label: 'كل الخطوط' }, ...lines.map(l => ({ id: l.id, label: l.name }))]}
                    width="180px"
                    placeholder="كل الخطوط"
                />

                <CustomSelect
                    className="contracts-filter-select"
                    value={zoneFilter}
                    onChange={setZoneFilter}
                    options={[
                        { id: 'ALL', label: 'كل المناطق' },
                        ...(lineFilter !== 'ALL' ? zones.filter(z => z.lineId === lineFilter) : zones).map(z => ({ id: z.id, label: z.name }))
                    ]}
                    width="180px"
                    placeholder="كل المناطق"
                />

                <CustomSelect
                    className="contracts-filter-select"
                    value={typeFilter}
                    onChange={setTypeFilter}
                    options={[{ id: 'ALL', label: 'كل الأنواع' }, ...types.map(t => ({ id: t.id, label: t.name }))]}
                    width="180px"
                    placeholder="كل الأنواع"
                />
                
                     <div className="contracts-filters-divider" style={{ width: '1px', height: '24px', backgroundColor: 'var(--color-border)', margin: '0 4px' }}></div>

                     <button
                        className="contracts-late-toggle"
                        onClick={() => setLateOnly(prev => !prev)}
                        title="عرض العقود التي عليها دفعات متأخرة فقط"
                        style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: '6px',
                            padding: '6px 12px',
                            borderRadius: 'var(--radius-md)',
                            fontSize: '0.85rem',
                            fontWeight: 600,
                            cursor: 'pointer',
                            border: lateOnly ? '1px solid var(--color-error)' : '1px solid var(--color-border)',
                            backgroundColor: lateOnly ? 'var(--color-error-bg)' : 'transparent',
                            color: lateOnly ? 'var(--color-error)' : 'var(--text-secondary)'
                        }}
                     >
                        <AlertCircle size={15} />
                        دفعات متأخرة{lateContractIds.size > 0 ? ` (${lateContractIds.size})` : ''}
                     </button>

                     <div className="contracts-filters-divider" style={{ width: '1px', height: '24px', backgroundColor: 'var(--color-border)', margin: '0 4px' }}></div>

                     <div className="contracts-status-tabs" style={{ display: 'flex', background: 'var(--neutral-50)', padding: '4px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
                            {[
                                { id: 'ALL', label: 'الكل' },
                                ...CONTRACT_STATUS_FILTERS.map(filter => ({ id: filter.value, label: filter.label })),
                            ].map(filter => (
                        <button
                            className="contracts-status-tab"
                            key={filter.id}
                            onClick={() => setStatusFilter(filter.id)}
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

                <div className="contracts-selection-tools" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <button
                        className="button secondary"
                        onClick={toggleSelectAllFiltered}
                        disabled={filteredContracts.length === 0}
                        style={{ height: '38px', padding: '0 12px', fontSize: '0.85rem', whiteSpace: 'nowrap' }}
                    >
                        {isAllFilteredSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل'}
                    </button>
                    <span className="contracts-selection-count" style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', fontWeight: 600 }}>
                        {selectedFilteredContracts.length} محدد
                    </span>
                </div>

                 <button
                          className="button secondary contracts-export-btn"
                    onClick={exportToExcel}
                    disabled={filteredContracts.length === 0}
                    style={{ height: '42px', width: '42px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRadius: 'var(--radius-md)' }}
                    title="تصدير Excel"
                >
                    <Download size={18} />
                </button>
            </div>
        </div>

        <div className="contracts-list-shell" style={{ flex: 1, overflow: 'hidden', paddingBottom: '2px' }}>
            <div className="contracts-list-scroll" style={{ height: '100%', overflowY: 'auto', padding: '0 16px' }}>
                <div className="dashboard-panel" style={{ marginBottom: 0 }}>
                    <div className="dashboard-table-wrap">
                        <table className="dashboard-table contracts-page-table" style={{ minWidth: '1000px' }}>
                            <thead>
                                <tr>
                                    <th style={{ textAlign: 'center' }}>
                                        <input
                                            type="checkbox"
                                            className="contract-select-checkbox"
                                            checked={isAllFilteredSelected}
                                            onChange={toggleSelectAllFiltered}
                                            disabled={filteredContracts.length === 0}
                                            aria-label="تحديد كل العقود"
                                        />
                                    </th>
                                    <th>العقد</th>
                                    <th>العميل</th>
                                    <th>الموقع</th>
                                    <th style={{ textAlign: 'center' }}>السداد</th>
                                    <th style={{ textAlign: 'center' }}>الحالة</th>
                                    <th style={{ textAlign: 'center' }}>التواريخ</th>
                                    <th style={{ textAlign: 'center' }}>إجراءات</th>
                                </tr>
                            </thead>
                            <tbody>
                                {filteredContracts.length > 0 ? filteredContracts.map(contract => {
                                    const client = clientUsers.find(u => u.id === contract.clientId);
                                    const locationDisplay = getLocationDisplay(contract);
                                    const isSelected = selectedContractIds.includes(contract.id);
                                    const paid = contractPayments[contract.id] || 0;
                                    const total = contract.totalValue || 0;
                                    const rem = Math.max(total - paid, 0);

                                    return (
                                        <tr
                                            key={contract.id}
                                            onClick={() => setViewingContract(contract)}
                                            style={{ cursor: 'pointer', backgroundColor: isSelected ? 'var(--primary-light)' : undefined }}
                                        >
                                            <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                                                <input
                                                    type="checkbox"
                                                    className="contract-select-checkbox"
                                                    checked={isSelected}
                                                    onChange={() => toggleContractSelection(contract.id)}
                                                    aria-label={`تحديد العقد ${contract.code}`}
                                                />
                                            </td>

                                            <td style={{ whiteSpace: 'normal' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                                    <Badge variant="default" style={{ fontSize: '0.72rem', fontWeight: 600, padding: '3px 8px', background: 'var(--primary-light)', border: '1px solid var(--color-primary)', color: 'var(--color-primary)', width: 'fit-content', borderRadius: '6px' }}>
                                                        {getTypeName(contract.contractTypeId)}
                                                    </Badge>
                                                    <span className="muted" style={{ fontSize: '0.75rem', fontFamily: 'monospace', letterSpacing: '0.3px' }}>
                                                        رقم العقد: {contract.code}
                                                    </span>
                                                </div>
                                            </td>

                                            <td style={{ whiteSpace: 'normal' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
                                                    <span
                                                        style={{ fontWeight: 600, color: 'var(--text-primary)', fontSize: '0.9rem', lineHeight: 1.2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                                                        className="hover:text-primary hover:underline"
                                                        onClick={(e) => { e.stopPropagation(); navigate(`/admin/clients/${contract.clientId}`); }}
                                                    >
                                                        {client?.fullName || 'غير معروف'}
                                                    </span>
                                                    <span className="muted" style={{ fontSize: '0.75rem', display: 'flex', alignItems: 'center', gap: '3px' }}>
                                                        <Phone size={11} /> {client?.phone || '—'}
                                                    </span>
                                                </div>
                                            </td>

                                            <td style={{ whiteSpace: 'normal' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '5px' }}>
                                                    <div style={{ fontSize: '0.85rem', color: 'var(--text-primary)', fontWeight: 700 }}>
                                                        {getLineName(contract.lineId)}
                                                    </div>
                                                    <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', display: 'flex', alignItems: 'flex-start', gap: '3px' }}>
                                                        <MapPin size={13} color="var(--text-tertiary)" style={{ marginTop: '1px', flexShrink: 0 }} />
                                                        <span
                                                            title={locationDisplay}
                                                            style={{
                                                                display: '-webkit-box',
                                                                WebkitLineClamp: 2,
                                                                WebkitBoxOrient: 'vertical',
                                                                overflow: 'hidden',
                                                                wordBreak: 'break-word',
                                                                lineHeight: 1.3
                                                            }}
                                                        >
                                                            {locationDisplay}
                                                        </span>
                                                    </div>
                                                </div>
                                            </td>

                                            <td style={{ textAlign: 'center', whiteSpace: 'normal' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', alignItems: 'center', justifyContent: 'center' }}>
                                                    <div style={{ fontSize: '0.9rem', fontWeight: 800, color: 'var(--text-primary)' }} title={`القيمة الإجمالية: ${total}`}>
                                                        {total.toLocaleString()}
                                                    </div>
                                                    <div style={{ display: 'flex', gap: '10px', fontSize: '0.82rem', color: 'var(--text-secondary)', alignItems: 'center', flexWrap: 'wrap', justifyContent: 'center' }}>
                                                        <div style={{ color: 'var(--color-success)', fontWeight: 700 }}>مدفوع: {paid.toLocaleString()}</div>
                                                        <div style={{ color: rem > 0 ? 'var(--color-warning)' : 'var(--color-success)', fontWeight: 700 }}>متبقي: {rem.toLocaleString()}</div>
                                                    </div>
                                                    {lateContractIds.has(contract.id) && (
                                                        <Badge variant="error" style={{ fontSize: '0.68rem', padding: '2px 8px' }}>
                                                            <AlertCircle size={11} /> دفعة متأخرة
                                                        </Badge>
                                                    )}
                                                </div>
                                            </td>

                                            <td style={{ textAlign: 'center' }} onClick={(e) => e.stopPropagation()}>
                                                <StatusPicker status={contract.status} onChange={(s) => handleStatusChange(contract, s)} />
                                            </td>

                                            <td style={{ textAlign: 'center', whiteSpace: 'normal' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', fontSize: '0.75rem' }}>
                                                    <span className="contract-date-chip contract-date-end" style={{ padding: '2px 6px', borderRadius: '4px', background: 'var(--neutral-100)', whiteSpace: 'nowrap' }}>انتهاء: {formatDate(contract.endDate)}</span>
                                                </div>
                                            </td>

                                            <td style={{ textAlign: 'center' }}>
                                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }} onClick={(e) => e.stopPropagation()}>
                                                    {uploadingContractId === contract.id ? (
                                                        <Loader2 size={18} style={{ animation: 'spin 1s linear infinite', color: 'var(--color-primary)' }} />
                                                    ) : contract.contractImageUrl ? (
                                                        <button
                                                            onClick={(e) => { e.stopPropagation(); window.open(contract.contractImageUrl!, '_blank'); }}
                                                            style={{ border: 'none', background: 'var(--primary-light)', width: '34px', height: '34px', borderRadius: '8px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--color-primary)' }}
                                                            title="عرض الصورة"
                                                            className="hover:bg-primary hover:text-white"
                                                        >
                                                            <ImageIcon size={16} />
                                                        </button>
                                                    ) : (
                                                        <button
                                                            onClick={(e) => { e.stopPropagation(); triggerImageUpload(contract.id); }}
                                                            style={{ border: '1px dashed var(--neutral-300)', background: 'transparent', width: '34px', height: '34px', borderRadius: '8px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-tertiary)' }}
                                                            className="hover:border-primary hover:text-primary"
                                                            title="رفع صورة"
                                                        >
                                                            <Upload size={16} />
                                                        </button>
                                                    )}

                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); setEditingContract(contract); }}
                                                        style={{ border: 'none', background: 'transparent', padding: '6px', cursor: 'pointer', color: 'var(--text-secondary)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                                                        className="hover:bg-neutral-100 hover:text-warning"
                                                        title="تعديل"
                                                    >
                                                        <Pencil size={16} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); setManagingVisitsContract(contract); }}
                                                        style={{ border: 'none', background: 'transparent', padding: '6px', cursor: 'pointer', color: 'var(--text-secondary)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                                                        className="hover:bg-primary-light hover:text-primary"
                                                        title="إدارة الزيارات"
                                                    >
                                                        <Calendar size={16} />
                                                    </button>
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); setDeletingContract(contract); }}
                                                        style={{ border: 'none', background: 'transparent', padding: '6px', cursor: 'pointer', color: 'var(--text-secondary)', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                                                        className="hover:bg-error-bg hover:text-error"
                                                        title="حذف"
                                                    >
                                                        <Trash2 size={16} />
                                                    </button>
                                                </div>
                                            </td>
                                        </tr>
                                    );
                                }) : (
                                    <tr>
                                        <td colSpan={8} className="dashboard-empty contracts-empty">
                                            <div style={{ padding: '28px 14px', textAlign: 'center', color: 'var(--text-tertiary)' }}>
                                                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
                                                    <div style={{ width: '64px', height: '64px', borderRadius: '50%', background: 'var(--neutral-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                                        <Search size={32} style={{ opacity: 0.5 }} />
                                                    </div>
                                                    <div>
                                                        <p style={{ margin: 0, fontWeight: 600, fontSize: '1rem' }}>لا توجد عقود مطابقة للبحث</p>
                                                        <p style={{ margin: '4px 0 0', fontSize: '0.9rem' }}>جرب تغيير معايير البحث أو تصنيفات الفلتر</p>
                                                    </div>
                                                </div>
                                            </div>
                                        </td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        {/* Hidden file input for contract image upload */}
        <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            style={{ display: 'none' }}
            onChange={handleImageUpload}
        />

        {/* Modals */}
        {showCreateModal && (
            <ContractFormModal 
                title="إضافة عقد جديد"
                clients={clientUsers}
                lines={lines}
                types={types}
                contracts={contracts}
                onClose={() => setShowCreateModal(false)}
                onSubmit={handleCreate}
                zones={zones}
            />
        )}

        {editingContract && (
            <ContractFormModal 
                title="تعديل العقد"
                initialData={editingContract}
                clients={clientUsers}
                lines={lines}
                types={types}
                contracts={contracts}
                isEdit
                onClose={() => setEditingContract(null)}
                onSubmit={handleUpdate}
                onPaymentSummaryChange={handleEditPaymentSummaryChange}
                zones={zones}
            />
        )}

        {managingVisitsContract && (
            <ContractVisitsManagerModal
                contract={managingVisitsContract}
                clientName={clientUsers.find(u => u.id === managingVisitsContract.clientId)?.fullName}
                onClose={() => setManagingVisitsContract(null)}
                onSaved={async () => {
                    await loadData();
                    if (viewingContract?.id === managingVisitsContract.id) {
                        const contractsRes = await getContracts(container.adminRepository);
                        if (contractsRes.ok) {
                            const updated = contractsRes.data.find(c => c.id === managingVisitsContract.id);
                            if (updated) setViewingContract(updated);
                        }
                    }
                }}
            />
        )}

        {viewingContract && (
            <ContractDetailsModal
                contract={viewingContract}
                client={clientUsers.find(u => u.id === viewingContract.clientId)}
                typeName={getTypeName(viewingContract.contractTypeId)}
                lineName={lines.find(l => l.id === viewingContract.lineId)?.name}
                zoneName={zones.find(z => z.id === viewingContract.zoneId)?.name}
                initialVisitId={initialVisitId}
                initialTab={initialTab}
                onClose={() => {
                    setViewingContract(null);
                    setInitialVisitId(null);
                    setInitialTab(null);
                    if (params.get("contractId")) {
                        navigate("/admin/contracts", { replace: true });
                    }
                }}
                onStatusChange={async (newStatus: string) => {
                    await handleStatusChange(viewingContract, newStatus);
                    setViewingContract({ ...viewingContract, status: newStatus as any });
                }}
                refreshContractDetails={async () => {
                    const contractsRes = await getContracts(container.adminRepository);
                    if (contractsRes.ok) {
                        const updated = contractsRes.data.find(c => c.id === viewingContract.id);
                        if (updated) setViewingContract(updated);
                    }
                }}
                onPaymentsChange={async () => {
                    try {
                        const payments = await container.adminRepository.listContractPayments(viewingContract.id);
                        const total = payments.reduce((sum: number, p: any) => sum + p.amount, 0);
                        setContractPayments(prev => ({ ...prev, [viewingContract.id]: total }));
                    } catch {}
                }}
            />
        )}

         {deletingContract && (
            <Modal title="تأكيد حذف العقد" onClose={() => setDeletingContract(null)}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                    <div style={{ background: 'var(--color-error-bg)', padding: '16px', borderRadius: 'var(--radius-md)', display: 'flex', gap: '12px' }}>
                        <AlertCircle className="text-error" style={{ flexShrink: 0, color: 'var(--color-error)' }} />
                        <p style={{ margin: 0, color: 'var(--color-error)', lineHeight: '1.6', fontSize: '0.9rem' }}>
                            أنت على وشك حذف العقد رقم <strong style={{ fontWeight: 700 }}>{deletingContract!.code}</strong>.
                            <br />
                            هذا الإجراء لا يمكن التراجع عنه وسيتم حذف جميع الزيارات والبيانات المرتبطة.
                        </p>
                    </div>
                    <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
                        <button className="button secondary" onClick={() => setDeletingContract(null)}>
                            إلغاء
                        </button>
                        <button className="button danger" onClick={confirmDelete}>
                            تأكيد الحذف
                        </button>
                    </div>
                </div>
            </Modal>
        )}
    </div>
  );
};


const Modal = ({ title, onClose, children }: any) => (
    <div style={{
        position: 'fixed', inset: 0, background: 'rgba(0, 0, 0, 0.4)', 
        backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100
    }}>
        <div className="card" style={{ width: '100%', maxWidth: '500px', maxHeight: '90vh', overflowY: 'auto', padding: '24px', boxShadow: 'var(--shadow-lg)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '24px', alignItems: 'center' }}>
                <h3 style={{ margin: 0, fontSize: '1.25rem', color: 'var(--text-primary)', fontWeight: 700 }}>{title}</h3>
                <button onClick={onClose} className="icon-button"><X size={20} /></button>
            </div>
            {children}
        </div>
    </div>
);

const InputGroup = ({ label, required, children, style }: any) => (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', ...style }}>
        <label style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-secondary)', display: 'flex', justifyContent: 'space-between' }}>
            <span>{label} {required && <span style={{ color: 'var(--color-error)' }}>*</span>}</span>
        </label>
        {children}
    </div>
);

const ContractFormModal = ({ title, initialData, clients, lines, types, contracts, isEdit, onClose, onSubmit, onPaymentSummaryChange }: any) => {
    const steps = [
        { id: 1, title: 'البيانات الأساسية', icon: FileText, desc: 'العميل ونوع العقد' },
        { id: 2, title: 'الموقع والعنوان', icon: MapPin, desc: 'تفاصيل العنوان الدقيق' },
        { id: 3, title: 'النخيل', icon: LayoutList, desc: 'اختيار النوع والعدادات' },
        { id: 4, title: 'المدة والقيمة', icon: Calendar, desc: 'الفترة المالية' },
        { id: 5, title: 'المراجعة والحفظ', icon: CheckCircle, desc: 'تأكيد البيانات' }
    ];

    const generateNextCode = () => {
        const PREFIX = 'NO-';
        const START = 1;
        if (!contracts || contracts.length === 0) return `${PREFIX}${String(START).padStart(4, '0')}`;
        
        let maxSeq = START - 1;
        for (const c of contracts) {
            const match = c.code?.match(/^NO-(\d{4,})$/);
            if (match) {
                const seq = parseInt(match[1], 10);
                if (seq > maxSeq) maxSeq = seq;
            }
        }
        return `${PREFIX}${String(maxSeq + 1).padStart(4, '0')}`;
    };

    const [currentStep, setCurrentStep] = useState(1);
    const [stepError, setStepError] = useState<string | null>(null);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [clientMode, setClientMode] = useState<'existing' | 'new'>('new');
    const [newClient, setNewClient] = useState({ title: '', fullName: '', email: '', phone: '', password: '' });
    const [localClients, setLocalClients] = useState(clients);
    const paymentFileRef = useRef<HTMLInputElement>(null);

    const [formData, setFormData] = useState({
        code: initialData?.code || generateNextCode(),
        clientId: initialData?.clientId || "",
        contractTypeId: initialData?.contractTypeId || "",
        lineId: initialData?.lineId || "",
        zoneId: initialData?.zoneId || "",
        durationMonths: initialData?.durationMonths || 12,
        startDate: initialData?.startDate || new Date().toISOString().split('T')[0],
        firstVisitDate: initialData?.firstVisitDate || "",
        endDate: initialData?.endDate || "",
        totalValue: initialData?.totalValue || 0,
        status: normalizeContractStatus(initialData?.status) || "active",
        addressDetails: initialData?.addressDetails || "",
        notes: initialData?.notes || "",
        blockNumber: initialData?.blockNumber || "",
        street: initialData?.street || "",
        avenue: initialData?.avenue || "",
        house: initialData?.house || "",
        kuwaitFinderUrl: initialData?.kuwaitFinderUrl || "",
        contractUserName: initialData?.contractUserName || "",
        contractUserPhone: initialData?.contractUserPhone || "",
        terms: initialData?.terms || [],
        palm: {
            isPalm: false,
            species: 'baladi',
            baladi: { largeProductive: 0, largeNonProductive: 0, smallProductive: 0, smallNonProductive: 0 },
            washingtonia: { largeProductive: 0, largeNonProductive: 0, smallProductive: 0, smallNonProductive: 0 }
        }
    });

    const [zones, setZones] = useState<Zone[]>([]);
    const [savedPayments, setSavedPayments] = useState<ContractPayment[]>([]);
    const [draftPayments, setDraftPayments] = useState<DraftContractPayment[]>([]);
    const [loadingPayments, setLoadingPayments] = useState(false);
    
    // تهيئة معرّفات البنود عند تحميل العقد
    useEffect(() => {
        setFormData(prev => ({
            ...prev,
            terms: prev.terms.map((t: any) => ({
                ...t,
                id: t.id || crypto.randomUUID()
            }))
        }));
    }, []);
    
    // عند فتح نموذج التعديل: تهيئة بيانات النخيل من العمود المخصص، مع دعم البيانات القديمة في notes
    useEffect(() => {
        const sourcePalmInfo = initialData?.palmInfo || null;
        if (sourcePalmInfo) {
            let species = sourcePalmInfo?.species;
            if (!species) {
                const baladi = sourcePalmInfo?.baladi || {};
                const wash = sourcePalmInfo?.washingtonia || {};
                const baladiSum = (Number(baladi.largeProductive || 0) + Number(baladi.largeNonProductive || 0) + Number(baladi.smallProductive || 0) + Number(baladi.smallNonProductive || 0));
                const washSum = (Number(wash.largeProductive || 0) + Number(wash.largeNonProductive || 0) + Number(wash.smallProductive || 0) + Number(wash.smallNonProductive || 0));
                species = baladiSum >= washSum ? 'baladi' : 'washingtonia';
            }

            setFormData(prev => ({
                ...prev,
                notes: (initialData?.notes || '').toString().trim(),
                palm: {
                    isPalm: !!sourcePalmInfo?.isPalm,
                    species,
                    baladi: sourcePalmInfo?.baladi || prev.palm.baladi,
                    washingtonia: sourcePalmInfo?.washingtonia || prev.palm.washingtonia
                }
            }));
            return;
        }

        if (!initialData?.notes) return;
        const PALM_PREFIX = '[[PALM_INFO]]';
        const notesStr = (initialData.notes || '').toString();
        if (notesStr.startsWith(PALM_PREFIX)) {
            try {
                const rest = notesStr.substring(PALM_PREFIX.length);
                const jsonEnd = rest.indexOf('\n');
                const jsonStr = jsonEnd === -1 ? rest : rest.substring(0, jsonEnd);
                const palmObj = JSON.parse(jsonStr);
                const cleanedNotes = jsonEnd === -1 ? '' : rest.substring(jsonEnd + 1);
                // infer species if not provided
                let species = palmObj?.species;
                if (!species) {
                    const baladi = palmObj?.baladi || {};
                    const wash = palmObj?.washingtonia || {};
                    const baladiSum = (Number(baladi.largeProductive || 0) + Number(baladi.largeNonProductive || 0) + Number(baladi.smallProductive || 0) + Number(baladi.smallNonProductive || 0));
                    const washSum = (Number(wash.largeProductive || 0) + Number(wash.largeNonProductive || 0) + Number(wash.smallProductive || 0) + Number(wash.smallNonProductive || 0));
                    species = baladiSum >= washSum ? 'baladi' : 'washingtonia';
                }

                setFormData(prev => ({
                    ...prev,
                    notes: (cleanedNotes || '').trim(),
                    palm: {
                        isPalm: !!palmObj?.isPalm,
                        species,
                        baladi: palmObj?.baladi || prev.palm.baladi,
                        washingtonia: palmObj?.washingtonia || prev.palm.washingtonia
                    }
                }));
            } catch (e) {
                // ignore parse errors and keep defaults
            }
        }
    }, [initialData]);
    const [showAddPayment, setShowAddPayment] = useState(false);
    const [paymentAmount, setPaymentAmount] = useState('');
    const [paymentMethod, setPaymentMethod] = useState<PaymentMethod | ''>('');
    const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0]);
    const [paymentNotes, setPaymentNotes] = useState('');
    const [paymentImageFile, setPaymentImageFile] = useState<File | null>(null);
    const [savingPayment, setSavingPayment] = useState(false);
    const [viewingImage, setViewingImage] = useState<string | null>(null);

    const activePayments = isEdit ? savedPayments : draftPayments;
    const totalContractValue = Number(formData.totalValue) || 0;
    const totalPaid = activePayments.reduce((sum, payment) => sum + Number(payment.amount || 0), 0);
    const remaining = totalContractValue - totalPaid;
    const paidPercent = totalContractValue > 0 ? Math.min((totalPaid / totalContractValue) * 100, 100) : 0;

    const resetPaymentInputs = () => {
        setPaymentAmount('');
        setPaymentMethod('');
        setPaymentDate(new Date().toISOString().split('T')[0]);
        setPaymentNotes('');
        setPaymentImageFile(null);
    };

    const loadPayments = useCallback(async () => {
        if (!isEdit || !initialData?.id) {
            setSavedPayments([]);
            onPaymentSummaryChange?.(0);
            return;
        }

        setLoadingPayments(true);
        try {
            const data = await container.adminRepository.listContractPayments(initialData.id);
            setSavedPayments(data);
            const total = data.reduce((sum, payment) => sum + payment.amount, 0);
            onPaymentSummaryChange?.(total);
        } catch (e) {
            console.error('Error loading contract payments:', e);
        } finally {
            setLoadingPayments(false);
        }
    }, [isEdit, initialData?.id, onPaymentSummaryChange]);

    useEffect(() => {
        loadPayments();
    }, [loadPayments]);

    useEffect(() => {
        if (isEdit && formData.contractTypeId && types.length > 0) {
            const selectedType = types.find((t: any) => t.id === formData.contractTypeId);
            if (selectedType && selectedType.terms) {
                setFormData(prev => {
                    const currentContents = new Set(prev.terms.map((t: any) => t.content));
                    const missingTerms = selectedType.terms
                        .filter((t: any) => !currentContents.has(t.content))
                        .map((t: any) => ({ ...JSON.parse(JSON.stringify(t)), isExcluded: true }));
                    
                    if (missingTerms.length > 0) {
                        return { ...prev, terms: [...prev.terms, ...missingTerms] };
                    }
                    return prev;
                });
            }
        }
    }, [isEdit, formData.contractTypeId, types]);

    // تحميل البنود الافتراضية مستبعدة عند إنشاء عقد جديد
    useEffect(() => {
        if (!isEdit && formData.contractTypeId && types.length > 0) {
            const selectedType = types.find((t: any) => t.id === formData.contractTypeId);
            if (selectedType && selectedType.terms) {
                const defaultTerms = selectedType.terms.map((t: any) => ({
                    ...JSON.parse(JSON.stringify(t)),
                    isExcluded: true, // مستبعدة بشكل افتراضي
                    id: t.id || crypto.randomUUID()
                }));
                setFormData(prev => ({ ...prev, terms: defaultTerms }));
            }
        }
    }, [isEdit, formData.contractTypeId, types]);

    useEffect(() => {
        if (formData.lineId) {
            container.lineRepository.listZones(formData.lineId).then(setZones);
        } else {
            setZones([]);
        }
    }, [formData.lineId]);

    useEffect(() => {
        if (formData.startDate && formData.durationMonths) {
            const start = new Date(formData.startDate);
            start.setMonth(start.getMonth() + parseInt(formData.durationMonths));
            setFormData(prev => ({ ...prev, endDate: start.toISOString().split('T')[0] }));
        }
    }, [formData.startDate, formData.durationMonths]);

    const handleChange = (field: string, value: any) => {
        setFormData(prev => {
            const next = { ...prev, [field]: value };
            if (field === 'clientId' && value) {
                const selectedClient = clients.find((c: any) => c.id === value);
                if (selectedClient) {
                    next.contractUserName = selectedClient.fullName || '';
                    next.contractUserPhone = selectedClient.phone || '';
                }
            }
            return next;
        });
        if (stepError) setStepError(null);
    };

    const handleAddPayment = async () => {
        const amount = Number(paymentAmount);
        if (!amount || amount <= 0 || !paymentDate) return;
        if (!paymentMethod) {
            setStepError('من فضلك اختر طريقة الدفع');
            return;
        }

        setSavingPayment(true);
        try {
            if (isEdit && initialData?.id) {
                const createdPayment = await container.adminRepository.createContractPayment({
                    contractId: initialData.id,
                    amount,
                    paymentMethod,
                    notes: paymentNotes || undefined,
                    paymentDate,
                });

                if (paymentImageFile) {
                    const compressed = await compressImage(paymentImageFile);
                    await container.adminRepository.uploadPaymentImage(
                        createdPayment.id,
                        compressed,
                        paymentImageFile.name.replace(/\.[^.]+$/, '.jpg')
                    );
                }

                await loadPayments();
            } else {
                setDraftPayments(prev => [
                    {
                        id: crypto.randomUUID(),
                        amount,
                        paymentMethod,
                        paymentDate,
                        notes: paymentNotes || undefined,
                        imageFile: paymentImageFile,
                    },
                    ...prev,
                ]);
            }

            setShowAddPayment(false);
            resetPaymentInputs();
        } catch (e: any) {
            console.error('Error saving payment:', e);
            setStepError(e?.message || 'فشل حفظ الدفعة');
        } finally {
            setSavingPayment(false);
        }
    };

    const handleDeletePayment = async (paymentId: string) => {
        try {
            if (isEdit) {
                await container.adminRepository.deleteContractPayment(paymentId);
                await loadPayments();
                return;
            }

            setDraftPayments(prev => prev.filter((payment) => payment.id !== paymentId));
        } catch (e: any) {
            console.error('Error deleting payment:', e);
            setStepError(e?.message || 'فشل حذف الدفعة');
        }
    };

    const validateStep = (step: number) => {
        switch (step) {
            case 1:
                if (!formData.code || !formData.contractTypeId) return false;
                if (clientMode === 'existing') return !!formData.clientId;
                if (isEdit && formData.clientId) return true;
                return !!(
                    newClient.fullName?.trim() &&
                    newClient.phone?.trim() &&
                    newClient.password?.trim() &&
                    newClient.password.trim().length >= 6
                );
            case 2:
                return !!formData.lineId && !!formData.zoneId;
            case 3:
                return true;
            case 4:
                return formData.startDate && formData.durationMonths > 0;
            default:
                return true;
        }
    };

    const handleNext = () => {
        if (validateStep(currentStep)) {
            setStepError(null);
            setCurrentStep(prev => Math.min(prev + 1, steps.length));
        } else {
             setStepError('يرجى ملء الحقول الإلزامية (*) للمتابعة');
        }
    };

    const handleBack = () => {
        setStepError(null);
        setCurrentStep(prev => Math.max(prev - 1, 1));
    };

    const handleSubmit = async () => {
        if (isSubmitting) return;

        if (validateStep(5)) {
            if (!formData.zoneId) {
                setStepError('يرجى اختيار المنطقة قبل حفظ العقد');
                setCurrentStep(2);
                return;
            }
            const palmInfo = formData.palm && formData.palm.isPalm
                ? {
                    isPalm: true,
                    species: formData.palm?.species || 'baladi',
                    baladi: formData.palm.baladi,
                    washingtonia: formData.palm.washingtonia
                }
                : null;

            // Exclude `palm` from payload and send the structured palm object separately.
            const { palm, ...restForm } = formData as any;
            const cleanData: ContractFormSubmitData = {
                ...restForm,
                notes: (formData.notes || '').trim(),
                palmInfo,
                terms: getSortedTerms(formData.terms).filter((t: any) => !t.isExcluded)
            };
            if (!isEdit && draftPayments.length > 0) {
                cleanData.initialPayments = draftPayments;
            }
            
            setIsSubmitting(true);
            try {
                if (clientMode === 'new' && !formData.clientId) {
                    const cleanedNewClient = {
                        fullName: `${newClient.title ? (newClient.title + ' ') : ''}${newClient.fullName.trim()}`,
                        email: newClient.email.trim(),
                        phone: newClient.phone.trim(),
                        password: newClient.password.trim(),
                    };

                    if (!cleanedNewClient.fullName || !cleanedNewClient.phone || !cleanedNewClient.password) {
                        throw new Error('يرجى إدخال الاسم الكامل ورقم الهاتف وكلمة المرور للعميل الجديد');
                    }

                    if (cleanedNewClient.password.length < 6) {
                        throw new Error('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                    }

                    const createdUser = await container.adminRepository.createUser({
                        email: cleanedNewClient.email || undefined,
                        fullName: cleanedNewClient.fullName,
                        phone: cleanedNewClient.phone,
                        password: cleanedNewClient.password,
                        role: 'client',
                    });
                    cleanData.clientId = createdUser.id;
                    if (!cleanData.contractUserName) cleanData.contractUserName = createdUser.fullName;
                    if (!cleanData.contractUserPhone) cleanData.contractUserPhone = createdUser.phone || '';
                }
                await onSubmit(cleanData);
            } catch (err: any) {
                console.error(err);
                setStepError(err?.message || 'فشل إنشاء العميل');
                setIsSubmitting(false);
            }
        } else {
             setStepError('يرجى ملء الحقول الإلزامية (*)');
        }
    };

    const [expandedTerm, setExpandedTerm] = useState<number | null>(null);
    const [draggedTermIndex, setDraggedTermIndex] = useState<number | null>(null);
    const [activationCounter, setActivationCounter] = useState(0);

    const onDragStart = (e: React.DragEvent, index: number) => {
        setDraggedTermIndex(index);
        e.dataTransfer.effectAllowed = "move";
    };

    /**
     * ترتيب البنود بناءً على ترتيب التفعيل
     * - البنود المفعّلة (بترتيب التفعيل) أولاً
     * - ثم البنود المستبعدة في الأسفل
     */
    const getSortedTerms = (terms: any[]) => {
        const enabled = terms.filter((t: any) => t.isExcluded !== true);
        const disabled = terms.filter((t: any) => t.isExcluded === true);
        
        // ترتيب المفعّلة بناءً على activationOrder
        enabled.sort((a: any, b: any) => (a.activationOrder || 0) - (b.activationOrder || 0));
        
        return [...enabled, ...disabled];
    };

    /**
     * البحث عن فهرس البند باستخدام معرّف فريد
     */
    const findTermIndexById = (termId: string) => {
        return formData.terms.findIndex((t: any) => t.id === termId);
    };

    const onDragOver = (e: React.DragEvent, index: number) => {
        e.preventDefault(); 
        if (draggedTermIndex === null || draggedTermIndex === index) return;
        
        const newTerms = [...formData.terms];
        const [draggedItem] = newTerms.splice(draggedTermIndex, 1);
        newTerms.splice(index, 0, draggedItem);
        
        setFormData(prev => ({ ...prev, terms: newTerms }));
        setDraggedTermIndex(index);
    };

    const onDragEnd = () => {
        setDraggedTermIndex(null);
    };

    const handleTermAction = {
         toggle: (termId: string) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const updatedTerms = prev.terms.map((t: any, i: number) => {
                    if (i !== termIndex) return t;
                    
                    const isCurrentlyExcluded = t.isExcluded !== false;
                    
                    if (isCurrentlyExcluded) {
                        // التفعيل - إضافة activationOrder
                        return {
                            ...t,
                            isExcluded: false,
                            activationOrder: activationCounter + 1
                        };
                    } else {
                        // الاستبعاد - إزالة activationOrder
                        return {
                            ...t,
                            isExcluded: true,
                            activationOrder: undefined
                        };
                    }
                });
                
                return { ...prev, terms: updatedTerms };
            });
            
            // زيادة عداد التفعيل عند تفعيل بند جديد
            if (formData.terms[termIndex]?.isExcluded !== false) {
                setActivationCounter(prev => prev + 1);
            }
            
            if (expandedTerm === termIndex) setExpandedTerm(null);
        },
        addVisit: (termId: string) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newTerm = { ...term, visits: [...(term.visits || [])] };
                    newTerm.visits.push({
                        id: crypto.randomUUID(),
                        description: '',
                        visitDate: '',
                        count: 1,
                        intervalMonths: 1,
                        tasks: []
                    });
                    return newTerm;
                });
                return { ...prev, terms: newTerms };
            });
        },
        removeVisit: (termId: string, visitIndex: number) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    return {
                        ...term,
                        visits: term.visits.filter((_: any, vi: number) => vi !== visitIndex)
                    };
                });
                return { ...prev, terms: newTerms };
            });
        },
        updateVisit: (termId: string, visitIndex: number, field: string, value: any) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
             setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newVisits = [...term.visits];
                    newVisits[visitIndex] = { ...newVisits[visitIndex], [field]: value };
                    return { ...term, visits: newVisits };
                });
                return { ...prev, terms: newTerms };
            });
        },
        toggleVisit: (termId: string, visitIndex: number) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newVisits = term.visits.map((v: any, vi: number) => 
                        vi === visitIndex ? { ...v, isExcluded: !v.isExcluded } : v
                    );
                    return { ...term, visits: newVisits };
                });
                return { ...prev, terms: newTerms };
            });
        },
        addTask: (termId: string, visitIndex: number) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newVisits = term.visits.map((visit: any, vi: number) => {
                        if (vi !== visitIndex) return visit;
                        const newVisit = { ...visit, tasks: [...(visit.tasks || [])] };
                        newVisit.tasks.push({ id: crypto.randomUUID(), title: '' });
                        return newVisit;
                    });
                    return { ...term, visits: newVisits };
                });
                return { ...prev, terms: newTerms };
            });
        },
        removeTask: (termId: string, visitIndex: number, taskIndex: number) => {
            const termIndex = formData.terms.findIndex((t: any) => t.id === termId);
            if (termIndex === -1) return;
            
            setFormData(prev => {
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newVisits = term.visits.map((visit: any, vi: number) => {
                        if (vi !== visitIndex) return visit;
                        return { 
                            ...visit, 
                            tasks: visit.tasks.filter((_: any, ti: number) => ti !== taskIndex) 
                        };
                    });
                     return { ...term, visits: newVisits };
                });
                return { ...prev, terms: newTerms };
            });
        },
        updateTask: (termId: string, visitIndex: number, taskIndex: number, title: string) => {
             setFormData(prev => {
                const termIndex = prev.terms.findIndex((t: any) => t.id === termId);
                if (termIndex === -1) return prev;
                
                const newTerms = prev.terms.map((term: any, i: number) => {
                    if (i !== termIndex) return term;
                    const newVisits = term.visits.map((visit: any, vi: number) => {
                        if (vi !== visitIndex) return visit;
                        const newTasks = [...visit.tasks];
                        newTasks[taskIndex] = { ...newTasks[taskIndex], title };
                        return { ...visit, tasks: newTasks };
                    });
                     return { ...term, visits: newVisits };
                });
                return { ...prev, terms: newTerms };
            });
        }
    };

    const renderStepContent = () => {
        switch (currentStep) {
            case 1:
                return (
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
                        {/* Right Column: Contract Info */}
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                            <div style={{ paddingBottom: '8px', borderBottom: '1px solid var(--color-border)', marginBottom: '8px', fontSize: '1rem', fontWeight: 700, color: 'var(--color-primary)' }}>
                                معلومات العقد
                            </div>
                            
                            <InputGroup label="كود العقد" required>
                                <input 
                                    className="input" 
                                    value={formData.code} 
                                    onChange={e => handleChange('code', e.target.value)} 
                                    placeholder="NO-0001" 
                                    dir="ltr" 
                                    style={{ textAlign: 'left', fontFamily: 'monospace', fontWeight: 700, letterSpacing: '1px' }} 
                                />
                            </InputGroup>

                            <InputGroup label="نوع العقد" required>
                                <CustomSelect 
                                    value={formData.contractTypeId} 
                                    onChange={val => handleChange('contractTypeId', val)}
                                    options={types.map((t: any) => ({ id: t.id, label: t.name }))}
                                    placeholder="اختر النوع"
                                    width="100%"
                                />
                            </InputGroup>

                             <InputGroup label="حالة العقد">
                                <div style={{ display: 'flex', gap: '8px', background: 'var(--bg-subtle)', padding: '4px', borderRadius: '8px' }}>
                                    {CONTRACT_STATUS_OPTIONS.map(opt => ({
                                        ...opt,
                                        c: opt.value === 'active' ? 'var(--green-600)' : opt.value === 'pending' ? 'var(--orange-600)' : opt.value === 'expired' ? 'var(--red-600)' : 'var(--neutral-600)',
                                        b: opt.value === 'active' ? 'var(--green-100)' : opt.value === 'pending' ? 'var(--orange-100)' : opt.value === 'expired' ? 'var(--red-100)' : 'var(--neutral-100)'
                                    })).map(opt => (
                                        <button
                                            key={opt.value}
                                            onClick={() => handleChange('status', opt.value)}
                                            style={{
                                                flex: 1,
                                                padding: '8px',
                                                borderRadius: '6px',
                                                border: 'none',
                                                background: formData.status === opt.value ? 'var(--bg-card)' : 'transparent',
                                                color: formData.status === opt.value ? opt.c : 'var(--text-tertiary)',
                                                fontWeight: formData.status === opt.value ? 700 : 500,
                                                boxShadow: formData.status === opt.value ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                                                cursor: 'pointer',
                                                transition: 'all 0.2s'
                                            }}
                                        >
                                            {opt.label}
                                        </button>
                                    ))}
                                </div>
                            </InputGroup>
                        </div>

                        {/* Left Column: Client Info */}
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                            <div style={{ paddingBottom: '8px', borderBottom: '1px solid var(--color-border)', marginBottom: '8px', fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
                                بيانات العميل
                            </div>

                            {/* Toggle: existing vs new client */}
                            <div style={{ display: 'flex', gap: '8px', background: 'var(--bg-subtle)', padding: '4px', borderRadius: '8px' }}>
                                {[
                                    { v: 'new' as const, l: 'عميل جديد', icon: Plus },
                                    { v: 'existing' as const, l: 'عميل موجود', icon: UserIcon },
                                ].map(opt => (
                                    <button
                                        key={opt.v}
                                        type="button"
                                        onClick={() => {
                                            setClientMode(opt.v);
                                            if (opt.v === 'new') {
                                                handleChange('clientId', '');
                                            }
                                        }}
                                        style={{
                                            flex: 1,
                                            padding: '8px 12px',
                                            borderRadius: '6px',
                                            border: 'none',
                                            background: clientMode === opt.v ? 'var(--bg-card)' : 'transparent',
                                            color: clientMode === opt.v ? 'var(--color-primary)' : 'var(--text-tertiary)',
                                            fontWeight: clientMode === opt.v ? 700 : 500,
                                            boxShadow: clientMode === opt.v ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                                            cursor: 'pointer',
                                            transition: 'all 0.2s',
                                            display: 'flex',
                                            alignItems: 'center',
                                            justifyContent: 'center',
                                            gap: '6px',
                                            fontSize: '0.9rem',
                                        }}
                                    >
                                        <opt.icon size={16} />
                                        {opt.l}
                                    </button>
                                ))}
                            </div>

                            {clientMode === 'existing' ? (
                                <InputGroup label="اختر العميل" required>
                                    <CustomSelect
                                        value={formData.clientId}
                                        onChange={val => handleChange('clientId', val)}
                                        options={localClients.map((c: any) => ({ id: c.id, label: `${c.fullName} (${c.phone})` }))}
                                        placeholder="بحث عن عميل..."
                                        width="100%"
                                        searchable
                                    />
                                </InputGroup>
                            ) : (
                                <div style={{ background: 'var(--neutral-50)', padding: '16px', borderRadius: '12px', border: '1px solid var(--color-primary)', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                    <InputGroup label="الاسم الكامل" required>
                                        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                            <CustomSelect
                                                value={newClient.title || ''}
                                                onChange={(val) => setNewClient(p => ({ ...p, title: val }))}
                                                options={[
                                                    { id: '', label: 'بدون' },
                                                    { id: 'السيد', label: 'السيد' },
                                                    { id: 'السيدة', label: 'السيدة' },
                                                ]}
                                                width="140px"
                                            />
                                            <div style={{ position: 'relative', flex: 1 }}>
                                                <UserIcon size={16} style={{ position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }} />
                                                <input className="input" placeholder="الاسم الكامل" value={newClient.fullName} onChange={e => setNewClient(p => ({ ...p, fullName: e.target.value }))} style={{ background: '#fff', paddingRight: '36px' }} />
                                            </div>
                                        </div>
                                    </InputGroup>
                                    <InputGroup label="البريد الإلكتروني (اختياري)">
                                        <div style={{ position: 'relative' }}>
                                            <Mail size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }} />
                                            <input className="input" type="email" placeholder="example@domain.com" value={newClient.email} onChange={e => setNewClient(p => ({ ...p, email: e.target.value }))} dir="ltr" style={{ textAlign: 'left', background: '#fff', paddingLeft: '36px' }} />
                                        </div>
                                    </InputGroup>
                                    <InputGroup label="رقم الهاتف" required>
                                        <div style={{ position: 'relative' }}>
                                            <Phone size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }} />
                                            <input className="input" name="newClientPhone" autoComplete="off" placeholder="+96550012345" value={newClient.phone} onChange={e => setNewClient(p => ({ ...p, phone: e.target.value }))} dir="ltr" style={{ textAlign: 'left', background: '#fff', paddingLeft: '36px' }} />
                                        </div>
                                    </InputGroup>
                                    <InputGroup label="كلمة المرور" required>
                                        <input className="input" name="newClientPassword" autoComplete="new-password" type="password" minLength={6} placeholder="6 أحرف على الأقل" value={newClient.password} onChange={e => setNewClient(p => ({ ...p, password: e.target.value }))} dir="ltr" style={{ textAlign: 'left', background: '#fff' }} />
                                    </InputGroup>
                                </div>
                            )}

                            <div style={{ background: 'var(--neutral-50)', padding: '16px', borderRadius: '12px', border: '1px dashed var(--neutral-300)', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                <InputGroup label="اسم الحارس">
                                    <input className="input" placeholder="نفس العميل" value={formData.contractUserName} onChange={e => handleChange('contractUserName', e.target.value)} style={{ background: '#fff' }} />
                                </InputGroup>

                                <InputGroup label="هاتف الحارس">
                                    <input className="input" placeholder="نفس الهاتف" value={formData.contractUserPhone} onChange={e => handleChange('contractUserPhone', e.target.value)} dir="ltr" style={{ textAlign: 'left', background: '#fff' }} />
                                </InputGroup>
                            </div>
                        </div>
                    </div>
                );
            case 2: 
                return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                            <InputGroup label="الخط" required>
                                <CustomSelect 
                                    value={formData.lineId} 
                                    onChange={val => {
                                        handleChange('lineId', val);
                                        handleChange('zoneId', ''); 
                                    }}
                                    options={lines.map((l: any) => ({ id: l.id, label: l.name }))}
                                    placeholder="اختر الخط"
                                    width="100%"
                                />
                            </InputGroup>

                            <InputGroup label="المنطقة" required>
                                <CustomSelect 
                                    value={formData.zoneId} 
                                    onChange={val => handleChange('zoneId', val)}
                                    options={zones.map((z: any) => ({ id: z.id, label: z.name }))}
                                    placeholder={formData.lineId ? "اختر المنطقة" : "اختر الخط أولاً"}
                                    disabled={!formData.lineId}
                                    width="100%"
                                />
                            </InputGroup>
                        </div>

                        <div style={{ padding: '20px', background: 'var(--neutral-50)', borderRadius: '16px', border: '1px solid var(--neutral-200)' }}>
                            <h4 style={{ margin: '0 0 16px 0', fontSize: '0.95rem', color: 'var(--text-primary)' }}>تفاصيل العنوان</h4>
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: '12px', marginBottom: '16px' }}>
                                <InputGroup label="القطعة">
                                    <input className="input" style={{background:'#fff'}} placeholder="-" value={formData.blockNumber} onChange={e => handleChange('blockNumber', e.target.value)} />
                                </InputGroup>
                                <InputGroup label="الشارع">
                                    <input className="input" style={{background:'#fff'}} placeholder="-" value={formData.street} onChange={e => handleChange('street', e.target.value)} />
                                </InputGroup>
                                <InputGroup label="جادة">
                                    <input className="input" style={{background:'#fff'}} placeholder="-" value={formData.avenue} onChange={e => handleChange('avenue', e.target.value)} />
                                </InputGroup>
                                <InputGroup label="المنزل">
                                    <input className="input" style={{background:'#fff'}} placeholder="-" value={formData.house} onChange={e => handleChange('house', e.target.value)} />
                                </InputGroup>
                            </div>
                            <InputGroup label="رابط كويت فايندر (Kuwait Finder)">
                                <div style={{ position: 'relative' }}>
                                    <MapPin size={16} style={{ position: 'absolute', top: '50%', transform: 'translateY(-50%)', left: '12px', color: 'var(--text-tertiary)' }} />
                                    <input 
                                        className="input" 
                                        style={{background:'#fff', paddingLeft: '36px'}} 
                                        placeholder="https://kuwaitfinder.com/..." 
                                        value={formData.kuwaitFinderUrl} 
                                        onChange={e => handleChange('kuwaitFinderUrl', e.target.value)} 
                                        dir="ltr" 
                                    />
                                </div>
                            </InputGroup>
                        </div>

                        <InputGroup label="تفاصيل إضافية للعنوان">
                            <textarea 
                                className="input" 
                                rows={2} 
                                placeholder="علامات مميزة، مدخل خلفي، إلخ..." 
                                value={formData.addressDetails} 
                                onChange={e => handleChange('addressDetails', e.target.value)} 
                            />
                        </InputGroup>

                        <InputGroup label="ملاحظات داخلية على العقد">
                            <textarea
                                className="input"
                                rows={2}
                                placeholder="ملاحظة داخلية لفريق المتابعة (لا تظهر للعميل)..."
                                value={formData.notes}
                                onChange={e => handleChange('notes', e.target.value)}
                            />
                        </InputGroup>
                    </div>
                );
            case 3:
                return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                        <div style={{ padding: '12px', background: 'var(--neutral-50)', borderRadius: '12px', border: '1px solid var(--neutral-200)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                                <div style={{ fontSize: '0.95rem', fontWeight: 700, color: 'var(--text-primary)' }}>نخيل (اختياري)</div>
                                <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                                    <input type="checkbox" checked={formData.palm?.isPalm} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, isPalm: e.target.checked } }))} />
                                    <span>يوجد نخيل</span>
                                </label>
                            </div>

                            {formData.palm?.isPalm ? (
                                <div>
                                    <div style={{ display: 'flex', gap: '8px', marginBottom: '12px', alignItems: 'center' }}>
                                        <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-secondary)' }}>اختر نوع النخيل:</div>
                                        <div style={{ display: 'flex', gap: '8px' }}>
                                            <button type="button" onClick={() => setFormData(prev => ({ ...prev, palm: { ...prev.palm, species: 'baladi' } }))} style={{ padding: '8px 12px', borderRadius: '8px', border: formData.palm.species === 'baladi' ? '1px solid var(--color-primary)' : '1px solid var(--color-border)', background: formData.palm.species === 'baladi' ? 'var(--bg-card)' : 'transparent', cursor: 'pointer' }}>بلدي</button>
                                            <button type="button" onClick={() => setFormData(prev => ({ ...prev, palm: { ...prev.palm, species: 'washingtonia' } }))} style={{ padding: '8px 12px', borderRadius: '8px', border: formData.palm.species === 'washingtonia' ? '1px solid var(--color-primary)' : '1px solid var(--color-border)', background: formData.palm.species === 'washingtonia' ? 'var(--bg-card)' : 'transparent', cursor: 'pointer' }}>واشنطونيا</button>
                                        </div>
                                    </div>

                                    {formData.palm.species === 'baladi' && (
                                        <div style={{ padding: '10px', borderRadius: '8px', border: '1px solid var(--color-border)', background: '#fff' }}>
                                            <div style={{ fontWeight: 700, marginBottom: '8px' }}>بلدي</div>
                                            <InputGroup label="كبير ومثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.baladi.largeProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, baladi: { ...prev.palm.baladi, largeProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="كبير وغير مثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.baladi.largeNonProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, baladi: { ...prev.palm.baladi, largeNonProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="صغير ومثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.baladi.smallProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, baladi: { ...prev.palm.baladi, smallProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="صغير وغير مثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.baladi.smallNonProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, baladi: { ...prev.palm.baladi, smallNonProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                        </div>
                                    )}

                                    {formData.palm.species === 'washingtonia' && (
                                        <div style={{ padding: '10px', borderRadius: '8px', border: '1px solid var(--color-border)', background: '#fff' }}>
                                            <div style={{ fontWeight: 700, marginBottom: '8px' }}>واشنطونيا</div>
                                            <InputGroup label="كبير ومثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.washingtonia.largeProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, washingtonia: { ...prev.palm.washingtonia, largeProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="كبير وغير مثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.washingtonia.largeNonProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, washingtonia: { ...prev.palm.washingtonia, largeNonProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="صغير ومثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.washingtonia.smallProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, washingtonia: { ...prev.palm.washingtonia, smallProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                            <InputGroup label="صغير وغير مثمر">
                                                <input type="number" min={0} className="input" value={formData.palm.washingtonia.smallNonProductive} onChange={e => setFormData(prev => ({ ...prev, palm: { ...prev.palm, washingtonia: { ...prev.palm.washingtonia, smallNonProductive: Number(e.target.value || 0) } } }))} />
                                            </InputGroup>
                                        </div>
                                    )}
                                </div>
                            ) : (
                                <div style={{ padding: '16px', borderRadius: '10px', background: '#fff', border: '1px dashed var(--neutral-300)', color: 'var(--text-secondary)', fontSize: '0.9rem' }}>
                                    فعّل "يوجد نخيل" لإدخال النوع والعدادات.
                                </div>
                            )}
                        </div>
                    </div>
                );
            case 4: 
                return (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                        <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: '24px' }}>
                            <div style={{ background: 'var(--neutral-50)', padding: '20px', borderRadius: '16px', border: '1px solid var(--neutral-200)' }}>
                                <h4 style={{ margin: '0 0 16px 0', fontSize: '0.95rem', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                    <Calendar size={18} /> الفترة الزمنية
                                </h4>
                                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                                        <InputGroup label="تاريخ البداية" required>
                                            <input type="date" className="input" style={{background:'#fff'}} value={formData.startDate} onChange={e => handleChange('startDate', e.target.value)} />
                                        </InputGroup>
                                        <InputGroup label="المدة (أشهر)" required>
                                            <input type="number" min="1" className="input" style={{background:'#fff'}} value={formData.durationMonths} onChange={e => handleChange('durationMonths', e.target.value)} />
                                        </InputGroup>
                                    </div>
                                    <InputGroup label="تاريخ أول زيارة (اختياري)">
                                        <input type="month" className="input" style={{background:'#fff'}} value={formData.firstVisitDate} onChange={e => handleChange('firstVisitDate', e.target.value)} />
                                    </InputGroup>
                                    <div style={{ padding: '12px', background: '#eef2ff', borderRadius: '8px', border: '1px solid #c7d2fe', color: '#3730a3', fontSize: '0.9rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                        <span>ينتهي العقد بتاريخ:</span>
                                        <span style={{ fontWeight: 700, fontSize: '1rem' }}>{formData.endDate || '-'}</span>
                                    </div>
                                </div>
                            </div>
                            
                            <div style={{ background: 'var(--neutral-50)', padding: '20px', borderRadius: '16px', border: '1px solid var(--neutral-200)', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                                <h4 style={{ margin: '0 0 16px 0', fontSize: '0.95rem', color: 'var(--text-primary)', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                    <CreditCard size={18} /> القيمة المالية
                                </h4>
                                <InputGroup label="القيمة الإجمالية">
                                    <div style={{ position: 'relative' }}>
                                        <input 
                                            type="number" 
                                            min="0" 
                                            className="input" 
                                            value={formData.totalValue} 
                                            onChange={e => handleChange('totalValue', e.target.value)} 
                                            style={{ 
                                                fontSize: '1.5rem', 
                                                fontWeight: 800, 
                                                color: 'var(--color-primary)', 
                                                height: '60px', 
                                                textAlign: 'center',
                                                background: '#fff',
                                                boxShadow: 'inset 0 2px 4px rgba(0,0,0,0.05)'
                                            }} 
                                        />
                                        <span style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)', fontWeight: 600 }}>د.ك</span>
                                    </div>
                                </InputGroup>
                            </div>
                        </div>

                        <div className="contract-details-payments" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                            <div className="contract-details-payments-kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
                                <div style={{ padding: '16px', background: 'var(--bg-subtle)', borderRadius: '12px', border: '1px solid var(--color-border)' }}>
                                    <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', marginBottom: '8px' }}>إجمالي العقد</div>
                                    <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--text-primary)' }}>
                                        {totalContractValue.toLocaleString()} <span style={{ fontSize: '0.8rem' }}>د.ك</span>
                                    </div>
                                </div>
                                <div style={{ padding: '16px', background: 'var(--color-success-bg)', borderRadius: '12px', border: '1px solid var(--green-200)' }}>
                                    <div style={{ fontSize: '0.85rem', color: 'var(--color-success)', marginBottom: '8px' }}>المدفوع</div>
                                    <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--color-success)' }}>
                                        {totalPaid.toLocaleString()} <span style={{ fontSize: '0.8rem' }}>د.ك</span>
                                    </div>
                                </div>
                                <div style={{ padding: '16px', background: remaining > 0 ? 'var(--color-warning-bg)' : 'var(--color-success-bg)', borderRadius: '12px', border: `1px solid ${remaining > 0 ? 'var(--orange-200)' : 'var(--green-200)'}` }}>
                                    <div style={{ fontSize: '0.85rem', color: remaining > 0 ? 'var(--color-warning)' : 'var(--color-success)', marginBottom: '8px' }}>المتبقي</div>
                                    <div style={{ fontSize: '1.25rem', fontWeight: 800, color: remaining > 0 ? 'var(--color-warning)' : 'var(--color-success)' }}>
                                        {remaining.toLocaleString()} <span style={{ fontSize: '0.8rem' }}>د.ك</span>
                                    </div>
                                </div>
                            </div>

                            <div style={{ background: 'var(--neutral-100)', borderRadius: '8px', height: '10px', overflow: 'hidden' }}>
                                <div style={{ height: '100%', width: `${paidPercent}%`, background: paidPercent >= 100 ? 'var(--color-success)' : 'var(--color-primary)', borderRadius: '8px', transition: 'width 0.5s ease' }} />
                            </div>
                            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>
                                <span>نسبة السداد: {paidPercent.toFixed(1)}%</span>
                                <span>{activePayments.length} دفعة</span>
                            </div>

                            {!showAddPayment && (
                                <button
                                    type="button"
                                    onClick={() => setShowAddPayment(true)}
                                    style={{
                                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px',
                                        padding: '12px', borderRadius: '10px', border: '2px dashed var(--color-border)',
                                        background: 'var(--bg-subtle)', color: 'var(--color-primary)', fontWeight: 600,
                                        fontSize: '0.9rem', cursor: 'pointer', transition: 'all 0.2s',
                                    }}
                                >
                                    <Plus size={18} /> إضافة دفعة جديدة
                                </button>
                            )}

                            {showAddPayment && (
                                <div className="contract-details-add-payment" style={{ border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', background: 'var(--bg-card)', boxShadow: 'var(--shadow-sm)' }}>
                                    <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-primary)', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                                        <CreditCard size={18} style={{ color: 'var(--color-primary)' }} />
                                        تسجيل دفعة جديدة
                                    </div>

                                    <div className="contract-details-payment-fields" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: 500, color: 'var(--text-secondary)' }}>
                                                المبلغ <span style={{ color: 'var(--color-error)' }}>*</span>
                                            </label>
                                            <input
                                                type="number"
                                                step="0.01"
                                                min="0.01"
                                                placeholder="0.000"
                                                value={paymentAmount}
                                                onChange={(e) => setPaymentAmount(e.target.value)}
                                                style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '0.95rem', outline: 'none', direction: 'ltr' }}
                                            />
                                        </div>

                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: 500, color: 'var(--text-secondary)' }}>طريقة الدفع</label>
                                            <select
                                                value={paymentMethod}
                                                onChange={(e) => setPaymentMethod(e.target.value as PaymentMethod)}
                                                style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '0.9rem', outline: 'none', background: '#fff' }}
                                            >
                                                <option value="" disabled>اختر طريقة الدفع</option>
                                                {PAYMENT_METHOD_OPTIONS.map((method) => (
                                                    <option key={method.value} value={method.value}>{method.label}</option>
                                                ))}
                                            </select>
                                        </div>

                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: 500, color: 'var(--text-secondary)' }}>
                                                تاريخ الدفع <span style={{ color: 'var(--color-error)' }}>*</span>
                                            </label>
                                            <input
                                                type="date"
                                                value={paymentDate}
                                                onChange={(e) => setPaymentDate(e.target.value)}
                                                style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '0.9rem', outline: 'none' }}
                                            />
                                        </div>

                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: 500, color: 'var(--text-secondary)' }}>صورة التحويل</label>
                                            <input
                                                ref={paymentFileRef}
                                                type="file"
                                                accept="image/*"
                                                style={{ display: 'none' }}
                                                onChange={(e) => {
                                                    const selectedFile = e.target.files?.[0];
                                                    if (selectedFile && selectedFile.type.startsWith('image/')) {
                                                        setPaymentImageFile(selectedFile);
                                                    }
                                                    e.target.value = '';
                                                }}
                                            />
                                            <button
                                                type="button"
                                                onClick={() => paymentFileRef.current?.click()}
                                                style={{
                                                    padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--color-border)',
                                                    fontSize: '0.85rem', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '8px',
                                                    background: paymentImageFile ? 'var(--green-50)' : '#fff',
                                                    color: paymentImageFile ? 'var(--color-success)' : 'var(--text-secondary)',
                                                }}
                                            >
                                                <Upload size={16} />
                                                {paymentImageFile ? paymentImageFile.name : 'اختر صورة...'}
                                            </button>
                                        </div>

                                        <div className="contract-details-payment-notes" style={{ gridColumn: 'span 2', display: 'flex', flexDirection: 'column', gap: '6px' }}>
                                            <label style={{ fontSize: '0.85rem', fontWeight: 500, color: 'var(--text-secondary)' }}>ملاحظات</label>
                                            <input
                                                type="text"
                                                placeholder="ملاحظات اختيارية..."
                                                value={paymentNotes}
                                                onChange={(e) => setPaymentNotes(e.target.value)}
                                                style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid var(--color-border)', fontSize: '0.9rem', outline: 'none' }}
                                            />
                                        </div>
                                    </div>

                                    <div className="contract-details-add-payment-actions" style={{ display: 'flex', gap: '10px', marginTop: '16px', justifyContent: 'flex-end' }}>
                                        <button
                                            type="button"
                                            onClick={() => {
                                                setShowAddPayment(false);
                                                resetPaymentInputs();
                                            }}
                                            style={{ padding: '10px 20px', borderRadius: '8px', border: '1px solid var(--color-border)', background: '#fff', cursor: 'pointer', fontWeight: 600, color: 'var(--text-secondary)' }}
                                        >
                                            إلغاء
                                        </button>
                                        <button
                                            type="button"
                                            onClick={handleAddPayment}
                                            disabled={savingPayment || !paymentAmount || !paymentDate}
                                            style={{
                                                padding: '10px 24px', borderRadius: '8px', border: 'none',
                                                background: savingPayment ? 'var(--neutral-400)' : 'var(--green-600)',
                                                color: '#fff', cursor: savingPayment ? 'wait' : 'pointer', fontWeight: 600,
                                                display: 'flex', alignItems: 'center', gap: '8px',
                                            }}
                                        >
                                            {savingPayment ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                                            {savingPayment ? 'جار الحفظ...' : 'حفظ الدفعة'}
                                        </button>
                                    </div>
                                </div>
                            )}

                            {loadingPayments ? (
                                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '40px', color: 'var(--text-tertiary)' }}>
                                    <Loader2 size={28} className="animate-spin" style={{ marginBottom: '12px', color: 'var(--color-primary)' }} />
                                    <span>جاري تحميل الدفعات...</span>
                                </div>
                            ) : activePayments.length > 0 ? (
                                <div className="contract-details-payments-list" style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                                    {activePayments.map((payment: any) => (
                                        <div className="contract-details-payment-item" key={payment.id} style={{
                                            padding: '16px', borderRadius: '12px', border: '1px solid var(--color-border)',
                                            background: 'var(--bg-card)', display: 'flex', alignItems: 'center', gap: '16px',
                                        }}>
                                            <div style={{
                                                width: '40px', height: '40px', borderRadius: '10px',
                                                background: 'var(--color-success-bg)', color: 'var(--color-success)',
                                                display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                                            }}>
                                                <DollarSign size={20} />
                                            </div>

                                            <div className="contract-details-payment-main" style={{ flex: 1, minWidth: 0 }}>
                                                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '4px' }}>
                                                    <span style={{ fontWeight: 700, fontSize: '1.05rem', color: 'var(--color-success)' }}>
                                                        {Number(payment.amount || 0).toLocaleString()} د.ك
                                                    </span>
                                                    <span style={{ padding: '2px 10px', borderRadius: '20px', fontSize: '0.75rem', fontWeight: 600, background: 'var(--neutral-100)', color: 'var(--text-secondary)' }}>
                                                        {getPaymentMethodLabel(payment.paymentMethod)}
                                                    </span>
                                                    {!isEdit && payment.imageFile && (
                                                        <span style={{ padding: '2px 8px', borderRadius: '20px', fontSize: '0.72rem', fontWeight: 600, background: 'var(--green-50)', color: 'var(--green-700)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                                                            <ImageIcon size={12} />
                                                            صورة مرفقة
                                                        </span>
                                                    )}
                                                </div>
                                                <div className="contract-details-payment-meta" style={{ display: 'flex', gap: '16px', fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>
                                                    <span>{formatDate(payment.paymentDate)}</span>
                                                    {payment.notes && <span>• {payment.notes}</span>}
                                                </div>
                                            </div>

                                            <div className="contract-details-payment-actions" style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                                {isEdit && payment.transferImageUrl && (
                                                    <button
                                                        type="button"
                                                        onClick={() => setViewingImage(payment.transferImageUrl)}
                                                        title="عرض صورة التحويل"
                                                        style={{
                                                            width: '36px', height: '36px', borderRadius: '8px',
                                                            border: '1px solid var(--color-border)', background: 'var(--bg-subtle)',
                                                            cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                            color: 'var(--text-secondary)',
                                                        }}
                                                    >
                                                        <ImageIcon size={16} />
                                                    </button>
                                                )}
                                                <button
                                                    type="button"
                                                    onClick={() => handleDeletePayment(payment.id)}
                                                    title="حذف الدفعة"
                                                    style={{
                                                        width: '36px', height: '36px', borderRadius: '8px',
                                                        border: '1px solid var(--color-border)', background: 'var(--bg-subtle)',
                                                        cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                        color: 'var(--color-error)',
                                                    }}
                                                >
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            ) : (
                                <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-tertiary)', background: 'var(--bg-card)', borderRadius: '12px', border: '1px dashed var(--color-border)' }}>
                                    <div style={{ width: '56px', height: '56px', borderRadius: '50%', background: 'var(--neutral-100)', margin: '0 auto 12px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                        <DollarSign size={28} style={{ opacity: 0.4 }} />
                                    </div>
                                    <p style={{ fontWeight: 600, color: 'var(--text-secondary)', margin: '0 0 4px' }}>لا توجد دفعات</p>
                                    <p style={{ margin: 0, fontSize: '0.85rem' }}>يمكنك إضافة الدفعات الآن أو لاحقًا من تفاصيل العقد.</p>
                                </div>
                            )}
                        </div>

                        {viewingImage && (
                            <div
                                onClick={() => setViewingImage(null)}
                                style={{
                                    position: 'fixed',
                                    inset: 0,
                                    background: 'rgba(0,0,0,0.7)',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                    zIndex: 200,
                                    cursor: 'pointer',
                                    backdropFilter: 'blur(4px)',
                                }}
                            >
                                <img
                                    src={viewingImage}
                                    alt="صورة التحويل"
                                    style={{ maxWidth: '90%', maxHeight: '90%', borderRadius: '12px', objectFit: 'contain' }}
                                    onClick={(e) => e.stopPropagation()}
                                />
                            </div>
                        )}
                    </div>
                );
            case 5: 
                if (isEdit) {
                    return (
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                            <div style={{ background: 'var(--bg-card)', border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', display: 'flex', alignItems: 'start', gap: '16px' }}>
                                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'var(--green-100)', color: 'var(--green-600)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                                    <CheckCircle size={24} />
                                </div>
                                <div>
                                    <h4 style={{ margin: '0 0 8px 0' }}>جاهز لتحديث العقد</h4>
                                    <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: '1.5' }}>
                                        سيتم حفظ البيانات الأساسية فقط، بينما إدارة الزيارات والمهام أصبحت من زر مستقل في عمود الإجراءات.
                                    </p>
                                </div>
                            </div>

                            <div style={{ padding: '20px', border: '1px solid var(--neutral-200)', borderRadius: '12px', background: '#fff' }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px', fontWeight: 700, color: 'var(--text-primary)' }}>
                                    <ClipboardList size={18} /> ملخص العقد
                                </div>
                                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: '12px', fontSize: '0.9rem', color: 'var(--text-secondary)' }}>
                                    <div>العميل: <strong style={{ color: 'var(--text-primary)' }}>{localClients.find((c: any) => c.id === formData.clientId)?.fullName || '—'}</strong></div>
                                    <div>النوع: <strong style={{ color: 'var(--text-primary)' }}>{types.find((t: any) => t.id === formData.contractTypeId)?.name || '—'}</strong></div>
                                    <div>الموقع: <strong style={{ color: 'var(--text-primary)' }}>{lines.find((l: any) => l.id === formData.lineId)?.name || '—'}</strong></div>
                                    <div>المنطقة: <strong style={{ color: 'var(--text-primary)' }}>{zones.find((z: any) => z.id === formData.zoneId)?.name || '—'}</strong></div>
                                </div>
                            </div>
                        </div>
                    );
                }
                return (
                    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', gap: '16px' }}>
                         <div style={{ background: 'var(--bg-card)', border: '1px solid var(--color-border)', borderRadius: '12px', padding: '20px', display: 'flex', alignItems: 'start', gap: '16px' }}>
                            <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: 'var(--green-100)', color: 'var(--green-600)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                                <CheckCircle size={24} />
                            </div>
                            <div>
                                <h4 style={{ margin: '0 0 8px 0' }}>جاهز للحفظ!</h4>
                                <p style={{ margin: 0, color: 'var(--text-secondary)', fontSize: '0.95rem', lineHeight: '1.5' }}>
                                    أنت على وشك إنشاء عقد جديد للعميل <strong>{clientMode === 'new' ? (newClient.fullName || localClients.find((c: any) => c.id === formData.clientId)?.fullName) : localClients.find((c: any) => c.id === formData.clientId)?.fullName}</strong>{' '}
                                    بقيمة <strong style={{ color: 'var(--color-primary)' }}>{formData.totalValue} د.ك</strong>.
                                    <br />
                                    سيتم توليد الزيارات تلقائيًا بناءً على نوع العقد المختار.
                                </p>
                            </div>
                         </div>

                        {formData.contractTypeId ? (
                            <div style={{ flex: 1, overflowY: 'auto', border: '1px solid var(--neutral-200)', borderRadius: '12px', padding: '0', background: '#fff' }}>
                                {/* Header */}
                                <div style={{ background: 'var(--neutral-50)', padding: '12px 16px', borderBottom: '1px solid var(--neutral-200)', fontWeight: 600, fontSize: '0.9rem', color: 'var(--text-secondary)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                                    <span>البنود والخدمات ({formData.terms?.filter((t: any) => !t.isExcluded).length || 0} مفعّل)</span>
                                </div>
                                <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                                    {formData.terms && formData.terms.length > 0 ? (
                                        getSortedTerms(formData.terms).map((term: any, sortedIndex: number) => {
                                            const termIndex = formData.terms.findIndex((t: any) => t.id === term.id);
                                            const isExpanded = expandedTerm === termIndex;
                                            const isExcluded = term.isExcluded;
                                            const isDragging = termIndex === draggedTermIndex;

                                            return (
                                            <div 
                                                key={term.id || sortedIndex} 
                                                draggable={!isExcluded}
                                                data-allow-drag={!isExcluded ? true : undefined}
                                                onDragStart={(e) => !isExcluded && onDragStart(e, termIndex)}
                                                onDragOver={(e) => onDragOver(e, termIndex)}
                                                onDragEnd={onDragEnd}
                                                style={{ 
                                                    borderRadius: '8px', border: '1px solid var(--neutral-200)',
                                                    background: isExcluded ? 'var(--neutral-50)' : '#fff', 
                                                    opacity: isDragging ? 0.3 : (isExcluded ? 0.7 : 1),
                                                    boxShadow: isDragging ? '0 10px 20px rgba(0,0,0,0.1)' : '0 1px 2px rgba(0,0,0,0.02)', 
                                                    overflow: 'hidden',
                                                    marginBottom: '12px',
                                                    transform: isDragging ? 'scale(1.02)' : 'none',
                                                    transition: 'transform 0.1s, opacity 0.1s'
                                                }}>
                                                {/* Term Header */}
                                                <div style={{ 
                                                    display: 'flex', gap: '12px', padding: '12px', alignItems: 'center', cursor: !isExcluded ? 'grab' : 'default', background: isExpanded ? 'var(--neutral-50)' : 'transparent' 
                                                }} onClick={() => !isExcluded && setExpandedTerm(isExpanded ? null : termIndex)}>
                                                    
                                                    {!isExcluded && (
                                                        <div 
                                                            style={{ cursor: 'grab', color: 'var(--text-tertiary)', padding: '4px', display: 'flex', alignItems: 'center' }}
                                                            onMouseDown={(e) => e.stopPropagation()} // Prevent expanding when clicking grip
                                                        >
                                                            <GripVertical size={16} />
                                                        </div>
                                                    )}

                                                    <div 
                                                        onClick={(e) => { e.stopPropagation(); handleTermAction.toggle(term.id); }}
                                                        style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '4px', cursor: 'pointer' }}
                                                        title={isExcluded ? "تفعيل البند" : "استبعاد البند"}
                                                    >
                                                        <div style={{ 
                                                            width: '20px', height: '20px', borderRadius: '6px', 
                                                            border: `2px solid ${isExcluded ? 'var(--neutral-400)' : 'var(--color-primary)'}`,
                                                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                            background: isExcluded ? 'transparent' : 'var(--color-primary)',
                                                            color: '#fff', transition: 'all 0.2s'
                                                        }}>
                                                            {!isExcluded && <Check size={14} strokeWidth={3} />}
                                                        </div>
                                                    </div>
                                                    
                                                    <div style={{ flex: 1, fontWeight: 600, fontSize: '0.9rem', color: isExcluded ? 'var(--text-tertiary)' : 'var(--text-primary)', textDecoration: isExcluded ? 'line-through' : 'none' }}>{term.content}</div>
                                                    
                                                    {!isExcluded && (
                                                        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                                            <span style={{ fontSize: '0.75rem', color: 'var(--text-tertiary)', background: '#fff', padding: '2px 6px', borderRadius: '4px', border: '1px solid var(--neutral-200)' }}>
                                                                {term.visits?.filter((v: any) => !v.isExcluded).length || 0}/{term.visits?.length || 0} أنواع زيارات
                                                            </span>
                                                            <ChevronDown size={16} style={{ transform: isExpanded ? 'rotate(180deg)' : 'rotate(0)', transition: 'transform 0.2s', color: 'var(--text-tertiary)' }} />
                                                        </div>
                                                    )}
                                                </div>

                                                {/* Term Body (Visits) */}
                                                {isExpanded && (
                                                    <div style={{ borderTop: '1px solid var(--neutral-200)', padding: '16px', background: '#fafafa' }}>
                                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                                                            {term.visits && term.visits.map((visit: any, visitIndex: number) => (
                                                                <div key={visitIndex} style={{ background: visit.isExcluded ? 'var(--neutral-50)' : '#fff', border: `1px solid ${visit.isExcluded ? 'var(--neutral-200)' : 'var(--neutral-200)'}`, borderRadius: '8px', padding: '12px', opacity: visit.isExcluded ? 0.6 : 1, transition: 'opacity 0.2s' }}>
                                                                    {/* Visit Header with Toggle */}
                                                                    <div style={{ display: 'flex', gap: '12px', alignItems: 'center', marginBottom: visit.isExcluded ? '0' : '12px' }}>
                                                                        <div 
                                                                            onClick={() => handleTermAction.toggleVisit(term.id, visitIndex)}
                                                                            style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', flexShrink: 0 }}
                                                                            title={visit.isExcluded ? "تفعيل الزيارة" : "استبعاد الزيارة"}
                                                                        >
                                                                            <div style={{ 
                                                                                width: '18px', height: '18px', borderRadius: '5px', 
                                                                                border: `2px solid ${visit.isExcluded ? 'var(--neutral-400)' : 'var(--color-primary)'}`,
                                                                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                                                background: visit.isExcluded ? 'transparent' : 'var(--color-primary)',
                                                                                color: '#fff', transition: 'all 0.2s'
                                                                            }}>
                                                                                {!visit.isExcluded && <Check size={12} strokeWidth={3} />}
                                                                            </div>
                                                                        </div>
                                                                        <div style={{ flex: 1, display: visit.isExcluded ? 'flex' : 'grid', gridTemplateColumns: '1fr auto', gap: '12px', alignItems: visit.isExcluded ? 'center' : 'end' }}>
                                                                            {visit.isExcluded ? (
                                                                                <span style={{ fontSize: '0.85rem', color: 'var(--text-tertiary)', textDecoration: 'line-through' }}>
                                                                                    {visit.description || 'زيارة بدون وصف'}
                                                                                </span>
                                                                            ) : (
                                                                                <>
                                                                                    <InputGroup label="وصف الزيارة (اختياري)">
                                                                                        <input 
                                                                                            className="input small" 
                                                                                            value={visit.description || ''} 
                                                                                            onChange={(e) => handleTermAction.updateVisit(term.id, visitIndex, 'description', e.target.value)}
                                                                                            placeholder="مثال: زيارة صيانة، زيارة طوارئ..."
                                                                                        />
                                                                                    </InputGroup>
                                                                                    <InputGroup label="تاريخ الزيارة (اختياري)">
                                                                                        <input 
                                                                                            type="date"
                                                                                            className="input small" 
                                                                                            value={visit.visitDate || ''} 
                                                                                            onChange={(e) => handleTermAction.updateVisit(term.id, visitIndex, 'visitDate', e.target.value)}
                                                                                        />
                                                                                    </InputGroup>
                                                                                    <button 
                                                                                        onClick={() => handleTermAction.removeVisit(term.id, visitIndex)}
                                                                                        style={{ padding: '8px', color: 'var(--color-error)', border: '1px solid var(--red-200)', background: 'var(--red-50)', borderRadius: '6px', cursor: 'pointer' }}
                                                                                        title="حذف نوع الزيارة"
                                                                                    >
                                                                                        <Trash2 size={16} />
                                                                                    </button>
                                                                                </>
                                                                            )}
                                                                        </div>
                                                                    </div>

                                                                    {/* Tasks */}
                                                                    {!visit.isExcluded && <div style={{ background: 'var(--neutral-50)', padding: '12px', borderRadius: '6px' }}>
                                                                        <div style={{ fontSize: '0.8rem', fontWeight: 600, marginBottom: '8px', color: 'var(--text-secondary)' }}>المهام المطلوبة في الزيارة:</div>
                                                                        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                                                                            {visit.tasks && visit.tasks.map((task: any, taskIndex: number) => (
                                                                                <div key={taskIndex} style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                                                                                    <CheckSquare size={14} style={{ color: 'var(--text-tertiary)' }} />
                                                                                    <input 
                                                                                        className="input small" 
                                                                                        style={{ flex: 1, height: '32px', fontSize: '0.85rem' }} 
                                                                                        value={task.title} 
                                                                                        placeholder="اكتب المهمة..."
                                                                                        onChange={(e) => handleTermAction.updateTask(term.id, visitIndex, taskIndex, e.target.value)}
                                                                                    />
                                                                                    <button 
                                                                                        onClick={() => handleTermAction.removeTask(term.id, visitIndex, taskIndex)}
                                                                                        style={{ border: 'none', background: 'transparent', color: 'var(--text-tertiary)', cursor: 'pointer' }}
                                                                                        className="hover:text-error"
                                                                                    >
                                                                                        <X size={14} />
                                                                                    </button>
                                                                                </div>
                                                                            ))}
                                                                            <button 
                                                                                onClick={() => handleTermAction.addTask(term.id, visitIndex)}
                                                                                style={{ alignSelf: 'start', fontSize: '0.8rem', color: 'var(--color-primary)', background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 0' }}
                                                                            >
                                                                                <Plus size={14} /> إضافة مهمة
                                                                            </button>
                                                                        </div>
                                                                    </div>}
                                                                </div>
                                                            ))}
                                                            
                                                            <button 
                                                                onClick={() => handleTermAction.addVisit(term.id)}
                                                                className="button secondary small"
                                                                style={{ width: '100%', justifyContent: 'center', borderStyle: 'dashed' }}
                                                            >
                                                                <Plus size={16} /> إضافة نوع زيارة جديد لهذا البند
                                                            </button>
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        )})
                                    ) : (
                                        <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-tertiary)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
                                            <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: 'var(--neutral-100)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                                                <AlertCircle size={24} style={{ opacity: 0.4 }} />
                                            </div>
                                            <p style={{ margin: 0 }}>تم إزالة جميع البنود. لن يتم جدولة أي زيارات.</p>
                                            <button 
                                                onClick={() => {
                                                    const selectedType = types.find((t: any) => t.id === formData.contractTypeId);
                                                    if (selectedType && selectedType.terms) {
                                                        setFormData(prev => ({ ...prev, terms: JSON.parse(JSON.stringify(selectedType.terms)) }));
                                                    }
                                                }}
                                                className="button secondary"
                                                style={{ fontSize: '0.85rem', padding: '6px 16px', marginTop: '8px' }}
                                            >
                                                استعادة البنود الافتراضية
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>
                        ) : (
                             <div style={{ padding: '40px', textAlign: 'center', color: 'var(--color-error)', background: 'var(--color-error-bg)', borderRadius: '12px' }}>
                                يرجى اختيار نوع العقد في الخطوة الأولى
                            </div>
                        )}
                    </div>
                );
        }
    };

    return (
        <div className="contract-form-overlay" style={{ 
            position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', zIndex: 100,
            display: 'flex', alignItems: 'center', justifyContent: 'center', backdropFilter: 'blur(8px)'
        }}>
            <div className="card contract-form-modal" style={{ width: '90%', maxWidth: '850px', height: '85vh', maxHeight: '800px', display: 'flex', flexDirection: 'column', padding: 0, overflow: 'hidden', boxShadow: '0 20px 50px rgba(0,0,0,0.2)' }}>
                {/* Header */}
                <div className="contract-form-header" style={{ padding: '16px 24px', borderBottom: '1px solid var(--color-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: '#fff' }}>
                    <div className="contract-form-header-main" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ width: '40px', height: '40px', borderRadius: '10px', background: 'var(--primary-light)', color: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                            {isEdit ? <Pencil size={20} /> : <Plus size={24} />}
                        </div>
                        <div>
                            <h3 style={{ margin: 0, fontSize: '1.1rem', color: 'var(--text-primary)', fontWeight: 700 }}>{title}</h3>
                            <p style={{ margin: '2px 0 0', fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>{isEdit ? 'تعديل بيانات العقد الحالي' : 'إدخال بيانات عقد جديد للنظام'}</p>
                        </div>
                    </div>
                    <button onClick={onClose} className="icon-button contract-form-close" style={{ width: '32px', height: '32px' }}><X size={20} /></button>
                </div>

                {/* Steps Horizontal */}
                <div className="contract-form-steps" style={{ padding: '20px 40px', background: 'var(--neutral-50)', borderBottom: '1px solid var(--color-border)', display: 'flex', justifyContent: 'space-between', position: 'relative' }}>
                    {/* Line Background */}
                    <div className="contract-form-steps-line-bg" style={{ position: 'absolute', top: '34px', left: '60px', right: '60px', height: '3px', background: 'var(--neutral-200)', zIndex: 0 }}></div>
                    <div className="contract-form-steps-line-progress" style={{ position: 'absolute', top: '34px', right: '60px', width: `${((currentStep - 1) / (steps.length - 1)) * 100}%`, height: '3px', background: 'var(--color-primary)', transition: 'width 0.3s ease', zIndex: 0, left: 'auto', transformOrigin: 'right' }}></div>

                    {steps.map((s, idx) => {
                        const active = s.id === currentStep;
                        const completed = s.id < currentStep;
                        const canNavigate = isEdit || completed;
                        
                        return (
                            <div className="contract-form-step" key={s.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', position: 'relative', zIndex: 1, cursor: canNavigate ? 'pointer' : 'default' }}
                                 onClick={() => canNavigate && setCurrentStep(s.id)}>
                                <div className="contract-form-step-badge" style={{ 
                                    width: '32px', height: '32px', borderRadius: '50%', 
                                    background: active ? 'var(--color-primary)' : (completed ? 'var(--color-success)' : 'var(--neutral-100)'),
                                    border: `2px solid ${active ? 'var(--color-primary)' : (completed ? 'var(--color-success)' : 'var(--neutral-300)')}`,
                                    color: active || completed ? '#fff' : 'var(--text-tertiary)', 
                                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                                    transition: 'all 0.3s'
                                }}>
                                    {completed ? <Check size={16} /> : <s.icon size={16} />}
                                </div>
                                <div style={{ textAlign: 'center' }}>
                                    <span className="contract-form-step-title" style={{ display: 'block', fontSize: '0.8rem', fontWeight: active ? 700 : 500, color: active ? 'var(--text-primary)' : 'var(--text-secondary)' }}>
                                        {s.title}
                                    </span>
                                </div>
                            </div>
                        );
                    })}
                </div>

                {/* Body */}
                <div className="contract-form-body" style={{ flex: 1, overflowY: 'auto', padding: '32px 40px', background: '#fff' }}>
                    {stepError && (
                        <div style={{ background: 'var(--color-error-bg)', color: 'var(--color-error)', padding: '12px 16px', borderRadius: '8px', marginBottom: '24px', fontSize: '0.9rem', display: 'flex', gap: '12px', alignItems: 'center', border: '1px solid var(--red-200)' }}>
                            <AlertCircle size={20} />
                            <span style={{ fontWeight: 600 }}>{stepError}</span>
                        </div>
                    )}
                    <div className="animate-fade-in">
                        {renderStepContent()}
                    </div>
                </div>

                {/* Footer */}
                <div className="contract-form-footer" style={{ padding: '20px 40px', borderTop: '1px solid var(--color-border)', display: 'flex', justifyContent: 'space-between', background: 'var(--neutral-50)', alignItems: 'center' }}>
                    <button 
                        className="button secondary" 
                        onClick={handleBack}
                        disabled={currentStep === 1}
                        style={{ padding: '0 24px', visibility: currentStep === 1 ? 'hidden' : 'visible' }}
                    >
                        السابق
                    </button>
                    
                    <div style={{ display: 'flex', gap: '12px' }}>
                        <button className="button ghost" onClick={onClose} style={{ color: 'var(--text-secondary)' }}>
                            إلغاء
                        </button>
                        {currentStep < steps.length ? (
                            <button className="button primary" onClick={handleNext} style={{ padding: '0 32px' }}>
                                التالي <ChevronLeft size={18} style={{ marginRight: '8px' }} />
                            </button>
                        ) : (
                            <button 
                                className="button primary" 
                                onClick={handleSubmit} 
                                disabled={isSubmitting}
                                style={{ 
                                    padding: '0 32px', 
                                    background: isSubmitting ? 'var(--neutral-400)' : 'var(--green-600)', 
                                    borderColor: isSubmitting ? 'var(--neutral-400)' : 'var(--green-600)',
                                    cursor: isSubmitting ? 'wait' : 'pointer'
                                }}
                            >
                                {isSubmitting ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} style={{ marginLeft: '8px' }} />}
                                {isSubmitting ? ' جاري الحفظ...' : ' تأكيد وحفظ'}
                            </button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

const styles = document.createElement('style');
styles.innerHTML = `
 .grid { display: grid; gap: 1rem; }
 .form-group { display: flex; flexDirection: column; gap: 6px; }
 .form-group span { font-size: 0.85rem; font-weight: 500; color: var(--text-secondary); }
 .detail-item label { display: block; font-size: 0.75rem; color: var(--text-tertiary); margin-bottom: 4px; font-weight: 500; }
 .detail-item div { font-size: 0.95rem; color: var(--text-primary); }
 .hover-trigger:hover { opacity: 1 !important; }
 .icon-button { border: none; background: transparent; padding: 6px; cursor: pointer; color: var(--text-secondary); border-radius: 6px; display: flex; align-items: center; justify-content: center; }
 .icon-button:hover { background: var(--bg-subtle); color: var(--text-primary); }
 .contract-mobile-label { display: none; }
 .contract-select-checkbox {
     width: 18px;
     height: 18px;
     accent-color: var(--color-primary);
     cursor: pointer;
 }
 .contracts-selection-count {
     min-width: 66px;
 }

 @media (max-width: 768px) {
    .contracts-page {
        padding: 12px !important;
        gap: 14px !important;
        height: auto !important;
        min-height: 100vh;
        overflow-y: auto !important;
    }

    .contracts-header {
        flex-direction: column !important;
        align-items: stretch !important;
        gap: 12px !important;
    }

    .contracts-title {
        font-size: 1.2rem !important;
    }

    .contracts-subtitle {
        font-size: 0.82rem !important;
        line-height: 1.45;
    }

    .contracts-add-btn {
        width: 100%;
        justify-content: center;
    }

    .contract-form-overlay {
        align-items: center !important;
        justify-content: center !important;
        padding: 8px !important;
    }

    .contract-form-modal {
        width: min(96vw, 760px) !important;
        max-width: 760px !important;
        height: min(92dvh, 860px) !important;
        max-height: 92dvh !important;
        border-radius: 14px !important;
    }

    .contract-form-header {
        padding: 12px 14px !important;
        gap: 10px !important;
    }

    .contract-form-header-main {
        min-width: 0;
    }

    .contract-form-steps {
        padding: 12px 14px !important;
        justify-content: flex-start !important;
        gap: 10px;
        overflow-x: auto;
        scrollbar-width: none;
    }

    .contract-form-steps::-webkit-scrollbar {
        display: none;
    }

    .contract-form-steps-line-bg,
    .contract-form-steps-line-progress {
        display: none;
    }

    .contract-form-step {
        min-width: 92px;
    }

    .contract-form-step-title {
        font-size: 0.72rem !important;
        line-height: 1.3;
    }

    .contract-form-body {
        padding: 16px 14px !important;
    }

    .contract-form-footer {
        padding: 12px 14px !important;
        flex-wrap: wrap;
        gap: 10px;
    }

    .contract-form-footer > div {
        width: 100%;
        justify-content: space-between;
    }

    .contracts-filters {
        padding: 12px !important;
        gap: 10px !important;
    }

    .contracts-search-wrap {
        min-width: 100% !important;
        flex-basis: 100% !important;
    }

    .contracts-filters-controls {
        width: 100% !important;
        gap: 8px !important;
    }

    .contracts-filter-select {
        width: 100% !important;
        min-width: 100% !important;
        flex: 1 1 100% !important;
    }

    .contracts-selection-tools {
        width: 100% !important;
        justify-content: space-between;
    }

    .contracts-filters-divider {
        display: none !important;
    }

    .contracts-status-tabs {
        width: auto;
        min-width: 0;
        flex: 1 1 auto;
        overflow-x: auto;
        scrollbar-width: none;
    }

    .contracts-status-tabs::-webkit-scrollbar {
        display: none;
    }

    .contracts-status-tab {
        flex: 1 0 auto;
        white-space: nowrap;
    }

    .contracts-export-btn {
        margin-inline-start: 0;
        flex: 0 0 42px;
    }

    .contracts-list-shell,
    .contracts-list-scroll {
        overflow: visible !important;
        height: auto !important;
        padding: 0 !important;
    }

    .contracts-table-head {
        display: none !important;
    }

    .contracts-rows {
        gap: 10px !important;
        padding-bottom: 14px !important;
    }

    .contract-row {
        display: grid !important;
        grid-template-columns: repeat(2, minmax(0, 1fr)) !important;
        gap: 12px !important;
        align-items: stretch !important;
        padding: 14px !important;
        border-radius: 12px !important;
        background: linear-gradient(180deg, #ffffff 0%, #fbfcff 100%) !important;
        box-shadow: 0 6px 20px rgba(18, 36, 72, 0.06) !important;
    }

    .contract-row::before {
        content: "";
        position: absolute;
        top: 0;
        right: 0;
        width: 4px;
        height: 100%;
        border-radius: 0 12px 12px 0;
        background: linear-gradient(180deg, var(--color-primary), #50b97a);
    }

    .contracts-page-table.dashboard-table {
        min-width: 0 !important;
    }

    .contracts-page-table.dashboard-table td:nth-child(1)::before {
        content: "تحديد";
    }

    .contracts-page-table.dashboard-table td:nth-child(2)::before {
        content: "العقد";
    }

    .contracts-page-table.dashboard-table td:nth-child(3)::before {
        content: "العميل";
    }

    .contracts-page-table.dashboard-table td:nth-child(4)::before {
        content: "الموقع";
    }

    .contracts-page-table.dashboard-table td:nth-child(5)::before {
        content: "السداد";
    }

    .contracts-page-table.dashboard-table td:nth-child(6)::before {
        content: "الحالة";
    }

    .contracts-page-table.dashboard-table td:nth-child(7)::before {
        content: "التواريخ";
    }

    .contracts-page-table.dashboard-table td:nth-child(8)::before {
        content: "إجراءات";
    }

    .contract-actions-divider,
 }
`;
document.head.appendChild(styles);
