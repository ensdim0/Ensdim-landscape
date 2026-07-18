import React, { useEffect, useState, useCallback, useRef } from "react";
import { useLocation } from "react-router-dom";
import {
  UserCheck,
  Search,
  MapPin,
  Calendar,
  FileText,
  ClipboardList,
  ChevronDown,
  ChevronLeft,
  Plus,
  CheckCircle2,
  Clock,
  XCircle,
  ShieldCheck,
  X,
  Save,
  LinkIcon,
  Unlink,
  Eye,
  AlertTriangle,
  BarChart3,
  Loader2,
  ImageIcon,
  MessageSquare,
  Navigation,
  Camera,
  User as UserIcon
} from "lucide-react";
import { CustomSelect } from "@presentation/components/CustomSelect";
import { formatDate, formatDateTime } from "@shared/utils/date";

import { container } from "@infrastructure/di/container";
import { User } from "@domain/entities/User";
import { GeographicLine } from "@domain/entities/GeographicLine";
import { Contract } from "@domain/entities/Contract";
import { ContractTask, TaskStatus } from "@domain/entities/ContractTask";
import { Visit } from "@domain/entities/Visit";
import { SupervisorNote, CreateSupervisorNoteDTO, UpdateSupervisorNoteDTO } from "@domain/entities/SupervisorNote";

import { getSupervisors } from "@application/use-cases/admin/getSupervisors";
import { assignLineToSupervisor } from "@application/use-cases/admin/assignLineToSupervisor";
import { removeLineAssignment } from "@application/use-cases/admin/removeLineAssignment";
import { getLineContracts } from "@application/use-cases/admin/getLineContracts";
import { getAllVisitTasks } from "@application/use-cases/admin/getContractTasks";
import { createUser } from "@application/use-cases/admin/createUser";

import { useToast } from "@presentation/components/ToastProvider";
import { LoadingState, ErrorState } from "@presentation/components/States";
import { SupervisorNotesEditor } from "@presentation/components/SupervisorNotesEditor";
import { getVisitStatusStyle } from "@shared/visitStatus";

const MONTH_NAMES = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
];

const STATUS_CONFIG: Record<TaskStatus, { label: string; color: string; bg: string; icon: React.ReactNode }> = {
  pending: { label: "قيد الانتظار", color: "#aa4d13", bg: "#fdecdb", icon: <Clock size={14} /> },
  completed: { label: "مكتملة", color: "#30461F", bg: "#e3ebe0", icon: <CheckCircle2 size={14} /> },
  verified: { label: "تم التحقق", color: "#30461F", bg: "#e3ebe0", icon: <ShieldCheck size={14} /> },
  rejected: { label: "مرفوضة", color: "#dc2626", bg: "#fee2e2", icon: <XCircle size={14} /> }
};

export const SupervisorsPage: React.FC = () => {
  const location = useLocation();
  const [supervisors, setSupervisors] = useState<User[]>([]);
  const [lines, setLines] = useState<GeographicLine[]>([]);
  const [isLoading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [mobileShowList, setMobileShowList] = useState(true);

  const [selectedSupervisor, setSelectedSupervisor] = useState<User | null>(null);
  const [lineContracts, setLineContracts] = useState<Contract[]>([]);
  const [contractVisits, setContractVisits] = useState<Record<string, Visit[]>>({});
  const [visitTasks, setVisitTasks] = useState<Record<string, ContractTask[]>>({});
  const [expandedContract, setExpandedContract] = useState<string | null>(null);
  const [expandedVisit, setExpandedVisit] = useState<string | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [taskExecutions, setTaskExecutions] = useState<Record<string, any[]>>({});
  const [executionPhotos, setExecutionPhotos] = useState<Record<string, any[]>>({});
  const [visitLevelPhotos, setVisitLevelPhotos] = useState<Record<string, any[]>>({});
  const [contractComments, setContractComments] = useState<Record<string, any[]>>({});
  const [supervisorNotes, setSupervisorNotes] = useState<Record<string, SupervisorNote[]>>({});
  const [loadingExecutions, setLoadingExecutions] = useState<Record<string, boolean>>({});
  const [highlightedCommentId, setHighlightedCommentId] = useState<string | null>(null);
  const [deepLinkHandled, setDeepLinkHandled] = useState(false);
  const deepLinkInFlightRef = useRef(false);

  const [showAssignModal, setShowAssignModal] = useState(false);
  const [assignTarget, setAssignTarget] = useState<User | null>(null);
  const [confirmUnassign, setConfirmUnassign] = useState<User | null>(null);
  const [showCreateSupervisorModal, setShowCreateSupervisorModal] = useState(false);
  const [actionLoading, setActionLoading] = useState(false);
  const [updatingTaskId, setUpdatingTaskId] = useState<string | null>(null);

  const { notify } = useToast();

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      const [supRes, linesRes] = await Promise.all([
        getSupervisors(container.adminRepository),
        container.lineRepository.listLines().catch(e => { console.error("Failed to load lines:", e); return [] as GeographicLine[]; })
      ]);
      console.log("Lines loaded:", linesRes.length, linesRes);
      if (supRes.ok) {
        setSupervisors(supRes.data);
        setLines(linesRes);
      } else {
        setError(supRes.error?.message || "فشل تحميل البيانات");
      }
    } catch (e) {
      console.error("Load data error:", e);
      setError("خطأ غير متوقع");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  const loadSupervisorDetail = useCallback(async (sup: User) => {
    setSelectedSupervisor(sup);
    // إخفاء القائمة على الهاتف عند اختيار مشرف
    if (window.innerWidth <= 600) {
      setMobileShowList(false);
    }
    setExpandedContract(null);
    setExpandedVisit(null);
    setContractVisits({});
    setVisitTasks({});
    setVisitLevelPhotos({});

    if (!sup.assignedLineId) {
      setLineContracts([]);
      return;
    }

    setLoadingDetail(true);
    try {
      const res = await getLineContracts(container.adminRepository, sup.assignedLineId);
      if (res.ok) {
        setLineContracts(res.data);
        if (res.data.length > 0) {
          const contractIds = res.data.map(c => c.id);
          const allVisits = await container.adminRepository.listAllVisits(contractIds);
          const groupedVisits: Record<string, Visit[]> = {};
          for (const v of allVisits) {
            const arr = groupedVisits[v.contractId] ?? [];
            arr.push(v);
            groupedVisits[v.contractId] = arr;
          }
          setContractVisits(groupedVisits);

          if (allVisits.length > 0) {
            const visitIds = allVisits.map(v => v.id);
            const tasksRes = await getAllVisitTasks(container.adminRepository, visitIds);
            if (tasksRes.ok) {
              const groupedTasks: Record<string, ContractTask[]> = {};
              for (const t of tasksRes.data) {
                const arr = groupedTasks[t.visitId] ?? [];
                arr.push(t);
                groupedTasks[t.visitId] = arr;
              }
              setVisitTasks(groupedTasks);
            }
          }
        }
      } else {
        notify(res.error?.message || "فشل تحميل العقود");
      }
    } catch {
      notify("خطأ في تحميل تفاصيل المشرف");
    } finally {
      setLoadingDetail(false);
    }
  }, [notify]);

  const handleToggleTaskStatus = useCallback(async (task: ContractTask) => {
    const nextStatus: TaskStatus =
      task.status === "completed" || task.status === "verified" ? "pending" : "completed";

    setUpdatingTaskId(task.id);
    try {
      await container.adminRepository.updateContractTaskStatus(task.id, nextStatus);
      setVisitTasks(prev => ({
        ...prev,
        [task.visitId]: (prev[task.visitId] || []).map(t =>
          t.id === task.id ? { ...t, status: nextStatus } : t
        ),
      }));
    } catch {
      notify("تعذر تحديث حالة المهمة");
    } finally {
      setUpdatingTaskId(null);
    }
  }, [notify]);

  const loadVisitExecutions = useCallback(async (visitId: string) => {
    const tasks = visitTasks[visitId] || [];
    setLoadingExecutions(prev => ({ ...prev, [visitId]: true }));
    try {
      const directPhotos = await container.adminRepository.listVisitPhotos(visitId);
      setVisitLevelPhotos(prev => ({ ...prev, [visitId]: directPhotos }));

      if (tasks.length > 0) {
        const taskIds = tasks.map(t => t.id);
        const execs = await container.adminRepository.listTaskExecutions(taskIds);
        const grouped: Record<string, any[]> = {};
        for (const ex of execs) {
          const arr = grouped[ex.taskId] ?? [];
          arr.push(ex);
          grouped[ex.taskId] = arr;
        }
        setTaskExecutions(prev => ({ ...prev, ...grouped }));

        if (execs.length > 0) {
          const execIds = execs.map(e => e.id);
          const photos = await container.adminRepository.listExecutionPhotos(execIds);
          const photoGrouped: Record<string, any[]> = {};
          for (const p of photos) {
            const arr = photoGrouped[p.executionId] ?? [];
            arr.push(p);
            photoGrouped[p.executionId] = arr;
          }
          setExecutionPhotos(prev => ({ ...prev, ...photoGrouped }));
        }
      }
    } catch (e) {
      console.error("Error loading visit details:", e);
    } finally {
      setLoadingExecutions(prev => ({ ...prev, [visitId]: false }));
    }
  }, [visitTasks]);

  const loadContractComments = useCallback(async (contractId: string) => {
    if (contractComments[contractId]) return;
    try {
      const comments = await container.adminRepository.listContractComments(contractId);
      setContractComments(prev => ({ ...prev, [contractId]: comments }));
    } catch (e) {
      console.error("Error loading comments:", e);
    }
  }, [contractComments]);

  const findSupervisorForContract = useCallback(async (targetContractId: string) => {
    const candidates = supervisors.filter((sup) => !!sup.assignedLineId);

    for (const sup of candidates) {
      if (!sup.assignedLineId) continue;
      try {
        const res = await getLineContracts(container.adminRepository, sup.assignedLineId);
        if (res.ok && res.data.some((contract) => contract.id === targetContractId)) {
          return sup;
        }
      } catch {
      }
    }

    return null;
  }, [supervisors]);

  useEffect(() => {
    setDeepLinkHandled(false);
    setHighlightedCommentId(null);
    deepLinkInFlightRef.current = false;
  }, [location.search]);

  useEffect(() => {
    if (deepLinkHandled || isLoading || supervisors.length === 0) return;
    if (deepLinkInFlightRef.current) return;

    const params = new URLSearchParams(location.search);
    const contractId = params.get("contractId") || "";
    const visitId = params.get("visitId") || "";
    const commentId = params.get("commentId") || "";

    if (!contractId || !visitId) return;

    let cancelled = false;

    const openFromNotification = async () => {
      deepLinkInFlightRef.current = true;
      // Mark as handled immediately to avoid re-running on intermediate state updates.
      setDeepLinkHandled(true);
      try {
        const targetSupervisor = await findSupervisorForContract(contractId);
        if (cancelled) return;

        if (!targetSupervisor) {
          notify("تعذر فتح الزيارة من الإشعار: لا يوجد مشرف مرتبط بهذا العقد حالياً");
          return;
        }

        await loadSupervisorDetail(targetSupervisor);
        if (cancelled) return;

        setExpandedContract(contractId);
        setExpandedVisit(visitId);
        await loadVisitExecutions(visitId);

        try {
          const notes = await container.supervisorRepository.listSupervisorNotes(visitId);
          if (!cancelled) {
            setSupervisorNotes((prev) => ({ ...prev, [visitId]: notes }));
          }
        } catch {
        }

        try {
          const comments = await container.adminRepository.listContractComments(contractId);
          if (!cancelled) {
            setContractComments((prev) => ({ ...prev, [contractId]: comments }));
          }
        } catch {
        }

        if (commentId) {
          setHighlightedCommentId(commentId);
          window.setTimeout(() => {
            const element = document.getElementById(`client-comment-${commentId}`);
            if (element) {
              element.scrollIntoView({ behavior: "smooth", block: "center" });
            }
          }, 250);
        }

        if (window.innerWidth <= 600) {
          setMobileShowList(false);
        }
      } catch {
        notify("تعذر فتح تفاصيل الإشعار حالياً");
      } finally {
        deepLinkInFlightRef.current = false;
      }
    };

    void openFromNotification();

    return () => {
      cancelled = true;
    };
  }, [
    deepLinkHandled,
    isLoading,
    supervisors,
    location.search,
    notify,
    findSupervisorForContract,
    loadSupervisorDetail,
    loadVisitExecutions,
  ]);

  const handleAssignLine = async (data: { lineId: string; startDate?: string; endDate?: string }) => {
    if (!assignTarget) return;
    setActionLoading(true);
    try {
      const res = await assignLineToSupervisor(container.adminRepository, {
        supervisorId: assignTarget.id,
        lineId: data.lineId,
        startDate: data.startDate,
        endDate: data.endDate
      });
      if (res.ok) {
        notify("تم تعيين الخط بنجاح");
        setShowAssignModal(false);
        setAssignTarget(null);
        await loadData();
        if (selectedSupervisor?.id === assignTarget.id) {
          const updated = {
            ...assignTarget,
            assignedLineId: data.lineId,
            assignmentStartDate: data.startDate || undefined,
            assignmentEndDate: data.endDate || undefined
          };
          loadSupervisorDetail(updated);
        }
      } else {
        notify(res.error?.message || "فشل التعيين");
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleUnassign = async () => {
    if (!confirmUnassign) return;
    setActionLoading(true);
    try {
      const res = await removeLineAssignment(container.adminRepository, confirmUnassign.id);
      if (res.ok) {
        notify("تم إزالة تعيين الخط");
        setConfirmUnassign(null);
        await loadData();
        if (selectedSupervisor?.id === confirmUnassign.id) {
          setSelectedSupervisor(null);
          setLineContracts([]);
          setContractVisits({});
          setVisitTasks({});
        }
      } else {
        notify(res.error?.message || "فشل إزالة التعيين");
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleCreateSupervisor = async (data: any) => {
    setActionLoading(true);
    try {
      const result = await createUser(container.adminRepository, {
        ...data,
        role: 'supervisor'
      });
      if (result.ok) {
        notify("تم إنشاء المشرف بنجاح");
        setShowCreateSupervisorModal(false);
        await loadData();
      } else {
        notify(result.error?.message || "فشل إنشاء المشرف");
      }
    } finally {
      setActionLoading(false);
    }
  };

  // Supervisor Notes handlers
  const loadSupervisorNotes = useCallback(async (visitId: string) => {
    try {
      const notes = await container.supervisorRepository.listSupervisorNotes(visitId);
      setSupervisorNotes(prev => ({ ...prev, [visitId]: notes }));
    } catch (e) {
      console.error("Failed to load supervisor notes:", e);
    }
  }, []);

  const handleAddNote = useCallback(async (visitId: string, contractId: string, content: string, visibility: "supervisors_only" | "all") => {
    try {
      const note = await container.supervisorRepository.createSupervisorNote({ visitId, contractId, content, visibility });
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: [note, ...(prev[visitId] || [])]
      }));
      notify("تم إضافة الملاحظة بنجاح");
    } catch (e) {
      notify("فشل إضافة الملاحظة");
      throw e;
    }
  }, [notify]);

  const handleUpdateNote = useCallback(async (visitId: string, noteId: string, content: string, visibility: "supervisors_only" | "all") => {
    try {
      const note = await container.supervisorRepository.updateSupervisorNote({ noteId, content, visibility });
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: prev[visitId]?.map(n => n.id === noteId ? note : n) || []
      }));
      notify("تم تحديث الملاحظة بنجاح");
    } catch (e) {
      notify("فشل تحديث الملاحظة");
      throw e;
    }
  }, [notify]);

  const handleDeleteNote = useCallback(async (visitId: string, noteId: string) => {
    try {
      await container.supervisorRepository.deleteSupervisorNote(noteId);
      setSupervisorNotes(prev => ({
        ...prev,
        [visitId]: prev[visitId]?.filter(n => n.id !== noteId) || []
      }));
      notify("تم حذف الملاحظة بنجاح");
    } catch (e) {
      notify("فشل حذف الملاحظة");
      throw e;
    }
  }, [notify]);

  const filteredSupervisors = supervisors.filter(s =>
    s.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
    s.email.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getLineName = (id?: string) => lines.find(l => l.id === id)?.name || "غير معين";

  const assignedCount = supervisors.filter(s => s.assignedLineId).length;
  const unassignedCount = supervisors.length - assignedCount;

  if (isLoading) return <LoadingState />;
  if (error) return <ErrorState text={error} />;

  return (
    <div className="supervisors-page" style={{ height: "calc(100vh - 80px)", display: "flex", background: "#f8fafc", overflow: "hidden" }}>
      {/* Sidebar List - Show/Hide on Mobile */}
      <div className={`supervisors-sidebar ${!mobileShowList ? "supervisors-sidebar-hidden" : "supervisors-sidebar-visible"}`} style={{ width: "360px", background: "white", borderLeft: "1px solid #e2e8f0", display: "flex", flexDirection: "column", zIndex: 10 }}>
        {/* Sidebar Header */}
        <div style={{ padding: "20px", borderBottom: "1px solid #e2e8f0" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
            <h2 style={{ margin: 0, fontSize: "1.25rem", fontWeight: "700", color: "#0f172a", display: "flex", alignItems: "center", gap: "10px" }}>
              <UserCheck size={24} className="text-primary" />
              المشرفين
            </h2>
            <button
              onClick={() => setShowCreateSupervisorModal(true)}
              style={{ padding: "8px", borderRadius: "8px", background: "#f1f5f9", border: "none", cursor: "pointer", color: "#0f172a" }}
              title="إضافة مشرف"
            >
              <Plus size={20} />
            </button>
          </div>

          <div style={{ position: "relative" }}>
            <Search size={18} style={{ position: "absolute", top: "10px", right: "12px", color: "#94a3b8" }} />
            <input
              type="text"
              placeholder="بحث..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{
                width: "100%", padding: "8px 40px 8px 12px", borderRadius: "8px", border: "1px solid #e2e8f0",
                fontSize: "0.9rem", outline: "none", background: "#f8fafc", color: "#334155"
              }}
            />
          </div>

          <div style={{ display: "flex", gap: "12px", marginTop: "12px", fontSize: "0.75rem", fontWeight: "600" }}>
             <span style={{ color: "#16a34a" }}>● {assignedCount} معين</span>
             <span style={{ color: "#f59e0b" }}>● {unassignedCount} متاح</span>
          </div>
        </div>

        {/* List Content */}
        <div style={{ overflowY: "auto", flex: 1, padding: "8px" }}>
          {filteredSupervisors.length === 0 ? (
            <div style={{ padding: "40px 20px", textAlign: "center", color: "#94a3b8" }}>
              لا يوجد نتائج
            </div>
          ) : (
            filteredSupervisors.map(sup => (
              <SupervisorCard
                key={sup.id}
                supervisor={sup}
                lineName={getLineName(sup.assignedLineId)}
                isSelected={selectedSupervisor?.id === sup.id}
                onSelect={() => loadSupervisorDetail(sup)}
                onAssign={() => { setAssignTarget(sup); setShowAssignModal(true); }}
                onUnassign={() => setConfirmUnassign(sup)}
              />
            ))
          )}
        </div>
      </div>

      {/* Main Detail Area */}
      <div className="supervisors-main" style={{ flex: 1, overflowY: "auto", padding: "24px", display: "flex", flexDirection: "column" }}>
        {selectedSupervisor ? (
          <div className="supervisors-content" style={{ maxWidth: "1000px", margin: "0 auto", width: "100%", display: "flex", flexDirection: "column", gap: "24px" }}>
            {/* Header Card */}
            <div className="supervisors-header-card" style={{ 
              background: "white", borderRadius: "16px", padding: "24px", 
              boxShadow: "0 1px 3px rgba(0,0,0,0.05), 0 1px 2px rgba(0,0,0,0.1)",
              border: "1px solid #e2e8f0",
              display: "flex", justifyContent: "space-between", alignItems: "flex-start"
            }}>
              <div style={{ display: "flex", gap: "20px" }}>
                <div style={{ width: "64px", height: "64px", borderRadius: "50%", background: "#f1f5f9", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "1.5rem", fontWeight: "700", color: "#64748b" }}>
                  {selectedSupervisor.fullName.charAt(0)}
                </div>
                <div>
                  <h1 style={{ margin: "0 0 4px", fontSize: "1.5rem", color: "#0f172a" }}>{selectedSupervisor.fullName}</h1>
                  <div style={{ display: "flex", alignItems: "center", gap: "6px", color: "#64748b", fontSize: "0.9rem", marginBottom: "8px" }}>
                    <UserIcon size={14} /> {selectedSupervisor.email}
                  </div>
                  {selectedSupervisor.assignedLineId ? (
                     <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
                        <div style={{ padding: "4px 10px", background: "#dcfce7", color: "#166534", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600", display: "flex", alignItems: "center", gap: "6px" }}>
                          <MapPin size={14} /> {getLineName(selectedSupervisor.assignedLineId)}
                        </div>
                        <div style={{ color: "#64748b", fontSize: "0.8rem", display: "flex", alignItems: "center", gap: "4px" }}>
                          <Calendar size={14} /> {selectedSupervisor.assignmentStartDate}
                        </div>
                     </div>
                  ) : (
                    <div style={{ padding: "4px 10px", background: "#fef3c7", color: "#b45309", borderRadius: "20px", fontSize: "0.8rem", fontWeight: "600", display: "inline-flex", alignItems: "center", gap: "6px" }}>
                      <AlertTriangle size={14} /> غير معين
                      <button 
                        onClick={() => { setAssignTarget(selectedSupervisor); setShowAssignModal(true); }}
                        style={{ border: "none", background: "none", textDecoration: "underline", cursor: "pointer", color: "inherit", fontWeight: "700", marginRight: "4px" }}
                      >
                         تعيين الآن
                      </button>
                    </div>
                  )}
                </div>
              </div>
              <button 
                onClick={() => { 
                  setSelectedSupervisor(null); 
                  setLineContracts([]); 
                  setContractVisits({}); 
                  setVisitTasks({}); 
                  setVisitLevelPhotos({});
                  // رجوع للقائمة على الهاتف
                  if (window.innerWidth <= 600) {
                    setMobileShowList(true);
                  }
                }}
                className="supervisors-header-close"
                style={{ padding: "8px", borderRadius: "50%", border: "1px solid #e2e8f0", background: "white", cursor: "pointer", color: "#64748b" }}
              >
                <X size={20} />
              </button>
            </div>

            {/* Content Area */}
            {loadingDetail ? (
               <div style={{ display: "flex", justifyContent: "center", padding: "60px" }}>
                 <div style={{ textAlign: "center", color: "#64748b" }}>
                   <Loader2 size={32} className="spin mb-2" />
                   <p>جار تحميل البيانات...</p>
                 </div>
               </div>
            ) : lineContracts.length > 0 ? (
               <>
                 <StatsGrid contracts={lineContracts} visits={contractVisits} tasks={visitTasks} />
                 
                 <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                    {lineContracts.map(contract => (
                      <ContractCard
                        key={contract.id}
                        contract={contract}
                        visits={contractVisits[contract.id] || []}
                        visitTasks={visitTasks}
                        isExpanded={expandedContract === contract.id}
                        expandedVisit={expandedVisit}
                        onToggle={() => setExpandedContract(prev => prev === contract.id ? null : contract.id)}
                        onToggleVisit={(visitId) => setExpandedVisit(prev => prev === visitId ? null : visitId)}
                        taskExecutions={taskExecutions}
                        executionPhotos={executionPhotos}
                        visitLevelPhotos={visitLevelPhotos}
                        loadingExecutions={loadingExecutions}
                        onExpandVisit={(visitId) => { loadVisitExecutions(visitId); loadSupervisorNotes(visitId); }}
                        comments={contractComments[contract.id] || []}
                        onLoadComments={() => loadContractComments(contract.id)}
                        highlightedCommentId={highlightedCommentId}
                        supervisorNotes={supervisorNotes}
                        handleAddNote={handleAddNote}
                        handleUpdateNote={handleUpdateNote}
                        handleDeleteNote={handleDeleteNote}
                        actionLoading={actionLoading}
                        onToggleTaskStatus={handleToggleTaskStatus}
                        updatingTaskId={updatingTaskId}
                      />
                    ))}
                 </div>
               </>
            ) : (
              selectedSupervisor.assignedLineId ? (
                <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", color: "#94a3b8", padding: "40px" }}>
                  <FileText size={48} style={{ opacity: 0.2, marginBottom: "16px" }} />  
                  <p style={{ margin: 0, fontSize: "1.1rem" }}>لا توجد عقود نشطة في هذا الخط</p>
                </div>
              ) : null
            )}

          </div>
        ) : (
          <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", flexDirection: "column", color: "#cbd5e1" }}>
            <div style={{ width: "80px", height: "80px", borderRadius: "50%", background: "#f1f5f9", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: "20px" }}>
               <UserCheck size={40} className="text-primary" style={{ opacity: 0.5 }} />
            </div>
            <h2 style={{ color: "#64748b", margin: "0 0 8px" }}>اختر مشرفاً للمتابعة</h2>
            <p style={{ margin: 0, color: "#94a3b8" }}>يمكنك البحث عن المشرفين وعرض تفاصيل أدائهم</p>
          </div>
        )}
      </div>


      {showCreateSupervisorModal && (
        <CreateSupervisorModal
          lines={lines}
          loading={actionLoading}
          onClose={() => setShowCreateSupervisorModal(false)}
          onSubmit={handleCreateSupervisor}
        />
      )}

      {showAssignModal && assignTarget && (
        <AssignLineModal
          supervisor={assignTarget}
          lines={lines}
          loading={actionLoading}
          initialLineId={assignTarget.assignedLineId}
          initialStart={assignTarget.assignmentStartDate}
          initialEnd={assignTarget.assignmentEndDate}
          onClose={() => { setShowAssignModal(false); setAssignTarget(null); }}
          onSubmit={handleAssignLine}
        />
      )}

      {confirmUnassign && (
        <Modal title="إزالة تعيين الخط" onClose={() => setConfirmUnassign(null)}>
          <div style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
            <p style={{ margin: 0, color: "#7c857a", lineHeight: "1.6" }}>
              هل أنت متأكد من إزالة تعيين الخط من المشرف
              <strong style={{ color: "#1a2a10", margin: "0 4px" }}>{confirmUnassign.fullName}</strong>؟
              <br />
              <span style={{ fontSize: "0.85rem", color: "#d97706" }}>
                <AlertTriangle size={14} style={{ verticalAlign: "middle" }} /> لن يتمكن من رؤية العقود والمهام.
              </span>
            </p>
            <div style={{ display: "flex", gap: "12px", borderTop: "1px solid #f5f3ef", paddingTop: "16px" }}>
              <button className="button danger" onClick={handleUnassign} disabled={actionLoading} style={{ flex: 1, justifyContent: "center" }}>
                {actionLoading ? <Loader2 size={16} className="spin" /> : null}
                {actionLoading ? "جار الإزالة..." : "تأكيد الإزالة"}
              </button>
              <button className="button secondary" onClick={() => setConfirmUnassign(null)} disabled={actionLoading}>إلغاء</button>
            </div>
          </div>
        </Modal>
      )}

    </div>
  );
};


const SupervisorCard = ({
  supervisor,
  lineName,
  isSelected,
  onSelect,
  onAssign,
  onUnassign
}: {
  supervisor: User;
  lineName: string;
  isSelected: boolean;
  onSelect: () => void;
  onAssign: () => void;
  onUnassign: () => void;
}) => {
  const hasLine = !!supervisor.assignedLineId;

  return (
    <div
      onClick={onSelect}
      style={{
        padding: "16px",
        borderRadius: "12px",
        marginBottom: "8px",
        cursor: "pointer",
        background: isSelected ? "#e3ebe0" : "white",
        border: isSelected ? "1px solid #528042" : "1px solid transparent",
        borderBottom: isSelected ? "1px solid #528042" : "1px solid #eae7e0",
        transition: "all 0.15s ease",
        display: "flex",
        gap: "12px",
        alignItems: "center"
      }}
    >
      <div style={{
        width: "40px", height: "40px", borderRadius: "50%",
        background: isSelected ? "#30461F" : "#f5f3ef",
        color: isSelected ? "white" : "#5c574f",
        display: "flex", alignItems: "center", justifyContent: "center",
        fontWeight: "700", fontSize: "1rem"
      }}>
        {supervisor.fullName.charAt(0)}
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontWeight: "600", color: "#1a1917", fontSize: "0.95rem", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
          {supervisor.fullName}
        </div>
        <div style={{ fontSize: "0.75rem", color: "#5c574f" }}>{supervisor.email}</div>
        
        {hasLine ? (
          <div style={{ marginTop: "6px", display: "flex", alignItems: "center", gap: "6px" }}>
            <span style={{
              padding: "2px 8px", borderRadius: "10px", fontSize: "0.7rem", fontWeight: "600",
              background: "#e3ebe0", color: "#30461F", display: "inline-flex", alignItems: "center", gap: "4px"
            }}>
              <MapPin size={10} /> {lineName}
            </span>
          </div>
        ) : (
          <div style={{ marginTop: "6px" }}>
            <span style={{
              padding: "2px 8px", borderRadius: "10px", fontSize: "0.7rem", fontWeight: "600",
              background: "#fdecdb", color: "#aa4d13"
            }}>
              غير معين
            </span>
          </div>
        )}
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: "4px" }}>
        <button
          className="icon-button"
          title={hasLine ? "إعادة تعيين" : "تعيين خط"}
          onClick={(e) => { e.stopPropagation(); onAssign(); }}
          style={{ width: "28px", height: "28px", borderRadius: "6px", background: "#f5f3ef", color: "#5c574f" }}
        >
          <LinkIcon size={14} />
        </button>
        {hasLine && (
          <button
            className="icon-button danger"
            title="إزالة التعيين"
            onClick={(e) => { e.stopPropagation(); onUnassign(); }}
            style={{ width: "28px", height: "28px", borderRadius: "6px", background: "#fee2e2", color: "#ef4444" }}
          >
            <Unlink size={14} />
          </button>
        )}
      </div>
     
    </div>
  );
};

const StatsGrid = ({ contracts, visits, tasks }: { contracts: Contract[]; visits: Record<string, Visit[]>; tasks: Record<string, ContractTask[]> }) => {
  const allVisits = Object.values(visits).flat();
  const allTasks = Object.values(tasks).flat();
  const pending = allTasks.filter(t => t.status === "pending").length;
  const completed = allTasks.filter(t => t.status === "completed").length;
  // const verified = allTasks.filter(t => t.status === "verified").length;
  const rejected = allTasks.filter(t => t.status === "rejected").length;

  return (
    <div className="supervisors-stats-grid" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: "16px" }}>
      <StatCard icon={<FileText size={20} />} label="إجمالي العقود" value={contracts.length} color="#30461F" bg="#e3ebe0" />
      <StatCard icon={<Calendar size={20} />} label="الزيارات" value={allVisits.length} color="#ea8e20" bg="#fdecdb" />
      <StatCard icon={<ClipboardList size={20} />} label="المهام" value={allTasks.length} color="#2e2b27" bg="#f5f3ef" />
      <StatCard icon={<Clock size={20} />} label="قيد الانتظار" value={pending} color="#aa4d13" bg="#fff7ed" />
      <StatCard icon={<CheckCircle2 size={20} />} label="مكتملة" value={completed} color="#3e6530" bg="#e3ebe0" />
      {/* <StatCard icon={<ShieldCheck size={20} />} label="محققة" value={verified} color="#15803d" bg="#dcfce7" /> */}
      {rejected > 0 && <StatCard icon={<XCircle size={20} />} label="مرفوضة" value={rejected} color="#b91c1c" bg="#fee2e2" />}
    </div>
  );
};

const StatCard = ({ icon, label, value, color, bg }: { icon: React.ReactNode; label: string; value: number; color: string; bg: string }) => (
  <div className="stat-card" style={{ background: "white", padding: "16px", borderRadius: "12px", border: "1px solid #eae7e0", boxShadow: "0 1px 2px rgba(0,0,0,0.05)", display: "flex", flexDirection: "column", gap: "8px" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
       <div className="stat-card-label" style={{ color: "#5c574f", fontSize: "0.85rem", fontWeight: "600" }}>{label}</div>
       <div style={{ padding: "6px", borderRadius: "8px", background: bg, color: color }}>{icon}</div>
    </div>
    <div className="stat-card-value" style={{ fontSize: "1.5rem", fontWeight: "700", color: "#1a1917" }}>{value}</div>
  </div>
);

const ContractCard = ({
  contract,
  visits,
  visitTasks,
  isExpanded,
  expandedVisit,
  onToggle,
  onToggleVisit,
  taskExecutions,
  executionPhotos,
  visitLevelPhotos,
  loadingExecutions,
  onExpandVisit,
  comments,
  onLoadComments,
  highlightedCommentId,
  supervisorNotes,
  handleAddNote,
  handleUpdateNote,
  handleDeleteNote,
  actionLoading,
  onToggleTaskStatus,
  updatingTaskId
}: {
  contract: Contract;
  visits: Visit[];
  visitTasks: Record<string, ContractTask[]>;
  isExpanded: boolean;
  expandedVisit: string | null;
  onToggle: () => void;
  onToggleVisit: (visitId: string) => void;
  taskExecutions: Record<string, any[]>;
  executionPhotos: Record<string, any[]>;
  visitLevelPhotos: Record<string, any[]>;
  loadingExecutions: Record<string, boolean>;
  onExpandVisit: (visitId: string) => void;
  comments: any[];
  onLoadComments: () => void;
  highlightedCommentId?: string | null;
  supervisorNotes: Record<string, SupervisorNote[]>;
  handleAddNote: (visitId: string, contractId: string, content: string, visibility: "supervisors_only" | "all") => Promise<void>;
  handleUpdateNote: (visitId: string, noteId: string, content: string, visibility: "supervisors_only" | "all") => Promise<void>;
  handleDeleteNote: (visitId: string, noteId: string) => Promise<void>;
  actionLoading: boolean;
  onToggleTaskStatus: (task: ContractTask) => void;
  updatingTaskId: string | null;
}) => {
  const allTasks = visits.flatMap(v => visitTasks[v.id] || []);
  const completedCount = allTasks.filter(t => t.status === "completed" || t.status === "verified").length;

  // Group visits by Contract Items (Terms) — mirrors getTermVisitGroups in ContractDetailsModal
  const termGroups = React.useMemo(() => {
    if (!contract.terms || contract.terms.length === 0) return null;

    const seen = new Set<string>();
    const termLabels: string[] = [];
    for (const term of contract.terms) {
      const label = (term.content || "").trim();
      if (!label || seen.has(label)) continue;
      seen.add(label);
      termLabels.push(label);
    }

    const usedVisitIds = new Set<string>();
    const groups: { term: any; visits: { visit: Visit; tasks: ContractTask[] }[] }[] = [];

    termLabels.forEach(label => {
      const matched = visits.filter(v => {
        if (usedVisitIds.has(v.id)) return false;
        return (v.title || "").trim() === label;
      });
      matched.forEach(v => usedVisitIds.add(v.id));
      if (matched.length > 0) {
        groups.push({
          term: { content: label },
          visits: matched.map(visit => ({ visit, tasks: visitTasks[visit.id] || [] })),
        });
      }
    });

    const unmatched = visits.filter(v => !usedVisitIds.has(v.id));
    if (unmatched.length > 0) {
      groups.push({
        term: { content: "زيارات بدون بند" },
        visits: unmatched.map(visit => ({ visit, tasks: visitTasks[visit.id] || [] })),
      });
    }

    return groups;
  }, [contract.terms, visits, visitTasks]);

  return (
    <div style={{
      background: "white",
      borderRadius: "16px",
      border: "1px solid #eae7e0",
      overflow: "hidden",
      boxShadow: "0 1px 2px rgba(0,0,0,0.05)"
    }}>
      {/* Header */}
      <div
        onClick={onToggle}
        className="contract-card-header"
        style={{
          padding: "20px",
          display: "flex",
          flexDirection: "column",
          gap: "12px",
          cursor: "pointer",
          background: isExpanded ? "#fbfaf9" : "white",
          transition: "background 0.2s"
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
           <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
              <div style={{ padding: "10px", borderRadius: "10px", background: "#e3ebe0", color: "#30461F" }}>
                 <FileText size={20} />
              </div>
              <div>
                <div style={{ fontSize: "1rem", fontWeight: "700", color: "#1a1917" }}>عقد {contract.code}</div>
                <div style={{ fontSize: "0.8rem", color: "#5c574f", marginTop: "2px" }}>
                   {contract.startDate} → {contract.endDate}
                </div>
              </div>
           </div>
           {isExpanded ? <ChevronDown size={20} className="text-gray-400" /> : <ChevronLeft size={20} className="text-gray-400" />}
        </div>
        
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingTop: "8px", borderTop: "1px solid #f5f3ef" }}>
           <div style={{ display: "flex", gap: "8px" }}>
            <ContractStatusBadge status={contract.status} />
            <span style={{ padding: "4px 10px", borderRadius: "20px", background: "#f5f3ef", fontSize: "0.75rem", fontWeight: "600", color: "#5c574f" }}>{visits.length} زيارة</span>
          </div>
          {contract.addressDetails && (
            <div style={{ fontSize: "0.8rem", color: "#5c574f", display: "flex", alignItems: "center", gap: "6px" }}>
               <MapPin size={14} /> {contract.addressDetails}
            </div>
          )}
        </div>
      </div>

      {isExpanded && (
        <div style={{ borderTop: "1px solid #eae7e0" }}>
           {/* Progress Bar */}
           {allTasks.length > 0 && (
            <div style={{ padding: "12px 20px", background: "#fbfaf9", borderBottom: "1px solid #eae7e0" }}>
               <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.75rem", fontWeight: "600", color: "#5c574f", marginBottom: "6px" }}>
                  <span style={{ display: "flex", alignItems: "center", gap: "6px" }}><BarChart3 size={14} /> نسبة الإنجاز الكلية</span>
                  <span style={{ color: "#30461F" }}>{Math.round((completedCount/allTasks.length)*100)}%</span>
               </div>
               <div style={{ height: "6px", width: "100%", background: "#eae7e0", borderRadius: "3px", overflow: "hidden" }}>
                  <div style={{ height: "100%", width: `${(completedCount/allTasks.length)*100}%`, background: "#30461F", transition: "width 0.5s ease" }} />
               </div>
            </div>
           )}

           <div style={{ padding: "16px", background: "#fbfaf9" }}>
             {visits.length === 0 ? (
               <div style={{ textAlign: "center", padding: "30px", color: "#a8a298" }}>لا توجد زيارات مسجلة</div>
             ) : (termGroups && termGroups.length > 0) ? (
                <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
                   {termGroups.map((group, idx) => (
                      <div key={idx} style={{ background: "white", borderRadius: "12px", border: "1px solid #eae7e0", overflow: "hidden" }}>
                         <div style={{ padding: "12px 16px", background: "#f5f3ef", display: "flex", alignItems: "center", gap: "8px", fontWeight: "700", color: "#2e2b27", fontSize: "0.9rem" }}>
                            <ClipboardList size={16} /> {group.term.content}
                         </div>
                         <div style={{ display: "flex", flexDirection: "column" }}>
                            {group.visits.map(({ visit, tasks }) => {
                               const isVisitExpanded = expandedVisit === visit.id;
                               const vsc = getVisitStatusStyle(visit.status);
                               const directVisitPhotos = visitLevelPhotos[visit.id] || [];
                               // Only verify tasks for THIS term
                               const termCompleted = tasks.filter(t => t.status === "completed" || t.status === "verified").length;
                               
                               return (
                                  <div key={visit.id} style={{ borderBottom: "1px solid #f5f3ef" }}>
                                    <div 
                                       onClick={() => { onToggleVisit(visit.id); if (!isVisitExpanded) { onExpandVisit(visit.id); onLoadComments(); } }}
                                       style={{ padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer", background: isVisitExpanded ? "#fbfaf9" : "white" }}
                                    >
                                       <div style={{ display: "flex", flexDirection: "column", gap: "8px", flex: 1 }}>
                                          <div style={{ display: "flex", gap: "10px", alignItems: "center", flexWrap: "wrap" }}>
                                             <div style={{ fontSize: "0.85rem", fontWeight: "600", color: "#1a1917" }}>{visit.notes || "زيارة"}</div>
                                             <span style={{ fontSize: "0.75rem", padding: "2px 8px", borderRadius: "10px", background: vsc.bg, color: vsc.color }}>{vsc.label}</span>
                                             <span style={{ fontSize: "0.75rem", color: "#5c574f" }}>• {termCompleted}/{tasks.length} منجز</span>
                                          </div>
                                          <div style={{ fontSize: "0.75rem", color: "#5c574f" }}>
                                             {formatDate(visit.visitDate)} • {new Date(visit.visitDate).toLocaleDateString("ar-EG", { weekday: "long" })}
                                          </div>
                                       </div>
                                       {isVisitExpanded ? <ChevronDown size={16} className="text-gray-400" /> : <ChevronLeft size={16} className="text-gray-400" />}
                                    </div>

                                    {isVisitExpanded && (
                                       <div style={{ padding: "12px", background: "#fbfaf9", borderTop: "1px solid #f5f3ef" }}>
                                         {loadingExecutions[visit.id] ? (
                                           <div className="flex justify-center p-4"><Loader2 size={16} className="spin text-gray-400" /></div>
                                         ) : (
                                           <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                                              {visit.summary && (
                                                <div style={{
                                                  padding: "10px 12px",
                                                  borderRadius: "8px",
                                                  border: "1px solid #bbf7d0",
                                                  background: "#f0fdf4",
                                                }}>
                                                  <div style={{ fontSize: "0.8rem", fontWeight: 700, color: "#166534", marginBottom: "4px", display: "flex", alignItems: "center", gap: "6px" }}>
                                                    <FileText size={14} /> ملخص الزيارة
                                                  </div>
                                                  <div style={{ fontSize: "0.85rem", color: "#2e2b27", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>
                                                    {visit.summary}
                                                  </div>
                                                </div>
                                              )}

                                              {directVisitPhotos.length > 0 && (
                                                <div>
                                                  <div style={{ fontSize: "0.8rem", fontWeight: 700, color: "#2e2b27", marginBottom: "8px", display: "flex", alignItems: "center", gap: "6px" }}>
                                                    <Camera size={14} /> صور الزيارة ({directVisitPhotos.length})
                                                  </div>
                                                  <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                                                    {directVisitPhotos.map((p: any) => (
                                                      <a key={p.id} href={p.photoUrl || p.photoPath} target="_blank" rel="noopener noreferrer" style={{ position: "relative" }}>
                                                        <img src={p.photoUrl || p.photoPath} style={{ width: "80px", height: "80px", borderRadius: "8px", objectFit: "cover", border: "1px solid #eae7e0" }} />
                                                      </a>
                                                    ))}
                                                  </div>
                                                </div>
                                              )}

                                              {/* Only show relevant tasks */}
                                              {tasks.map(task => (
                                                <TaskRow
                                                  key={task.id}
                                                  task={task}
                                                  executions={taskExecutions[task.id] || []}
                                                  executionPhotos={executionPhotos}
                                                  onToggleStatus={onToggleTaskStatus}
                                                  isUpdating={updatingTaskId === task.id}
                                                />
                                              ))}

                                              {(() => {
                                                const visitComments = comments.filter((c: any) => !c.visitId || c.visitId === visit.id);
                                                if (visitComments.length === 0) return null;
                                                return <CommentsSection comments={visitComments} highlightedCommentId={highlightedCommentId} />;
                                              })()}
                                           </div>
                                         )}
                                       </div>
                                    )}
                                  </div>
                               );
                            })}
                         </div>
                      </div>
                   ))}
                </div>
             ) : (
                /* Fallback to original pure visit list if no terms */
                <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
                  {visits.map(visit => {
                    const tasks = visitTasks[visit.id] || [];
                    const vCompleted = tasks.filter(t => t.status === "completed" || t.status === "verified").length;
                    const isVisitExpanded = expandedVisit === visit.id;
                    const vsc = getVisitStatusStyle(visit.status);
                    const directVisitPhotos = visitLevelPhotos[visit.id] || [];
                    
                    return (
                      <div key={visit.id} style={{
                        background: "white", borderRadius: "12px", border: "1px solid #eae7e0", overflow: "hidden",
                        boxShadow: "0 1px 2px rgba(0,0,0,0.02)"
                      }}>
                        {/* Visit Header */}
                        <div 
                           onClick={() => { onToggleVisit(visit.id); if (!isVisitExpanded) { onExpandVisit(visit.id); onLoadComments(); } }}
                           style={{ padding: "16px", display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer" }}
                        >
                           <div style={{ display: "flex", gap: "12px", alignItems: "center" }}>
                              <div style={{ padding: "8px", borderRadius: "8px", background: vsc.bg, color: vsc.color }}>
                                 <Calendar size={16} />
                              </div>
                              <div>
                                 <div style={{ fontWeight: "600", color: "#1a1917", fontSize: "0.9rem" }}>{visit.notes || "زيارة"}</div>
                                 <div style={{ fontSize: "0.75rem", color: "#a8a298", display: "flex", gap: "8px", marginTop: "2px" }}>
                                    <span style={{ color: vsc.color, fontWeight: "600" }}>{vsc.label}</span>
                                    <span>• {formatDate(visit.visitDate)}</span>
                                    <span>• {tasks.length} مهمة</span>
                                 </div>
                                  {visit.completedAt ? (
                                    <div style={{ fontSize: "0.75rem", color: "#5c574f", marginTop: "4px", display: "flex", alignItems: "center", gap: "6px" }}>
                                     <Clock size={12} />
                                     <span>{formatDateTime(visit.completedAt)}</span>
                                    </div>
                                  ) : null}
                              </div>
                           </div>
                           {isVisitExpanded ? <ChevronDown size={18} className="text-gray-400" /> : <ChevronLeft size={18} className="text-gray-400" />}
                        </div>

                         {/* Expanded Visit Content */}
                         {isVisitExpanded && (
                            <div style={{ borderTop: "1px solid #f5f3ef", background: "#fbfaf9" }}>
                               {loadingExecutions[visit.id] ? (
                                  <div style={{ padding: "40px", textAlign: "center", color: "#5c574f" }}>
                                     <Loader2 size={24} className="spin mb-2 mx-auto" />
                                     <p>جار التحميل...</p>
                                  </div>
                               ) : (
                                  <div>
                                     {visit.summary && (
                                       <div style={{ padding: "16px", borderBottom: "1px solid #f5f3ef" }}>
                                         <div style={{
                                           padding: "10px 12px",
                                           borderRadius: "8px",
                                           border: "1px solid #bbf7d0",
                                           background: "#f0fdf4",
                                         }}>
                                           <div style={{ fontSize: "0.8rem", fontWeight: 700, color: "#166534", marginBottom: "4px", display: "flex", alignItems: "center", gap: "6px" }}>
                                             <FileText size={14} /> ملخص الزيارة
                                           </div>
                                           <div style={{ fontSize: "0.85rem", color: "#2e2b27", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>
                                             {visit.summary}
                                           </div>
                                         </div>
                                       </div>
                                     )}

                                     {/* Supervisor Notes */}
                                     <div style={{ padding: "16px", borderBottom: "1px solid #f5f3ef" }}>
                                       <SupervisorNotesEditor
                                         visitId={visit.id}
                                         notes={supervisorNotes[visit.id] || []}
                                         onAddNote={(content, visibility) => handleAddNote(visit.id, contract.id, content, visibility)}
                                         onUpdateNote={(noteId, content, visibility) => handleUpdateNote(visit.id, noteId, content, visibility)}
                                         onDeleteNote={(noteId) => handleDeleteNote(visit.id, noteId)}
                                         isLoading={actionLoading}
                                       />
                                     </div>

                                     {directVisitPhotos.length > 0 && (
                                       <div style={{ padding: "16px", borderBottom: "1px solid #f5f3ef" }}>
                                         <h4 style={{ margin: "0 0 12px", fontSize: "0.85rem", color: "#2e2b27", display: "flex", alignItems: "center", gap: "8px" }}>
                                           <Camera size={16} /> صور الزيارة ({directVisitPhotos.length})
                                         </h4>
                                         <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                                           {directVisitPhotos.map((p: any) => (
                                             <a key={p.id} href={p.photoUrl || p.photoPath} target="_blank" rel="noopener noreferrer" style={{ position: "relative" }}>
                                               <img src={p.photoUrl || p.photoPath} style={{ width: "80px", height: "80px", borderRadius: "8px", objectFit: "cover", border: "1px solid #eae7e0" }} />
                                             </a>
                                           ))}
                                         </div>
                                       </div>
                                     )}

                                     {/* Photos Band (showing ALL task execution photos for visit) */}
                                     {(() => {
                                        const allPhotos = tasks.flatMap(t => (taskExecutions[t.id] || []).flatMap((ex: any) => executionPhotos[ex.id] || []));
                                        if (allPhotos.length > 0) {
                                          const before = allPhotos.filter((p: any) => p.photoType === "before");
                                          const after = allPhotos.filter((p: any) => p.photoType === "after");
                                          return (
                                            <div style={{ padding: "16px", borderBottom: "1px solid #f5f3ef" }}>
                                               <h4 style={{ margin: "0 0 12px", fontSize: "0.85rem", color: "#2e2b27", display: "flex", alignItems: "center", gap: "8px" }}>
                                                  <ImageIcon size={16} /> صور تنفيذ المهام
                                               </h4>
                                               <div style={{ display: "flex", gap: "16px", overflowX: "auto", paddingBottom: "8px" }}>
                                                  {before.length > 0 && (
                                                     <div style={{ display: "flex", gap: "8px" }}>
                                                        {before.map((p: any) => (
                                                           <a key={p.id} href={p.photoUrl || p.photoPath} target="_blank" rel="noopener noreferrer" style={{ position: "relative" }}>
                                                              <img src={p.photoUrl || p.photoPath} style={{ width: "80px", height: "80px", borderRadius: "8px", objectFit: "cover", border: "1px solid #eae7e0" }} />
                                                              <div style={{ position: "absolute", bottom: "4px", right: "4px", background: "rgba(0,0,0,0.6)", color: "white", fontSize: "0.6rem", padding: "2px 4px", borderRadius: "4px" }}>قبل</div>
                                                           </a>
                                                        ))}
                                                     </div>
                                                  )}
                                                  {after.length > 0 && (
                                                     <div style={{ display: "flex", gap: "8px" }}>
                                                        {after.map((p: any) => (
                                                           <a key={p.id} href={p.photoUrl || p.photoPath} target="_blank" rel="noopener noreferrer" style={{ position: "relative" }}>
                                                              <img src={p.photoUrl || p.photoPath} style={{ width: "80px", height: "80px", borderRadius: "8px", objectFit: "cover", border: "1px solid #eae7e0" }} />
                                                              <div style={{ position: "absolute", bottom: "4px", right: "4px", background: "rgba(0,0,0,0.6)", color: "white", fontSize: "0.6rem", padding: "2px 4px", borderRadius: "4px" }}>بعد</div>
                                                           </a>
                                                        ))}
                                                     </div>
                                                  )}
                                               </div>
                                            </div>
                                          );
                                        }
                                        return null;
                                     })()}

                                     {/* Tasks List */}
                                     <div style={{ padding: "12px" }}>
                                        {tasks.length === 0 ? <div style={{ padding: "20px", textAlign: "center", color: "#a8a298" }}>لا توجد مهام</div> : (
                                           <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                                              {tasks.map(task => (
                                                <TaskRow
                                                  key={task.id}
                                                  task={task}
                                                  executions={taskExecutions[task.id] || []}
                                                  executionPhotos={executionPhotos}
                                                  onToggleStatus={onToggleTaskStatus}
                                                  isUpdating={updatingTaskId === task.id}
                                                />
                                              ))}
                                           </div>
                                        )}
                                     </div>
                                     
                                     {/* Comments */}
                                     {(() => {
                                      const visitComments = comments.filter((c: any) => !c.visitId || c.visitId === visit.id);
                                      if (visitComments.length === 0) return null;
                                      return <CommentsSection comments={visitComments} highlightedCommentId={highlightedCommentId} />;
                                     })()}
                                  </div>
                               )}
                            </div>
                         )}
                      </div>
                    );
                  })}
                </div>
             )}
           </div>
        </div>
      )}
    </div>
  );
};

const ContractStatusBadge = ({ status }: { status: string }) => {
  const map: Record<string, { label: string; color: string; bg: string }> = {
    active: { label: "نشط", color: "#30461F", bg: "#e3ebe0" },
    pending: { label: "انتظار", color: "#aa4d13", bg: "#fdecdb" },
    cancelled: { label: "ملغي", color: "#5c574f", bg: "#f5f3ef" },
    terminated: { label: "ملغي", color: "#5c574f", bg: "#f5f3ef" },
    expired: { label: "منتهي", color: "#b91c1c", bg: "#fee2e2" }
  };
  const cfg = map[status] ?? map.pending!;
  return (
    <span style={{
      padding: "4px 10px", borderRadius: "20px", fontSize: "0.75rem", fontWeight: "600",
      background: cfg.bg, color: cfg.color
    }}>
      {cfg.label}
    </span>
  );
};

const TaskRow = ({
  task,
  executions,
  executionPhotos,
  onToggleStatus,
  isUpdating
}: {
  task: ContractTask;
  executions: any[];
  executionPhotos: Record<string, any[]>;
  onToggleStatus: (task: ContractTask) => void;
  isUpdating: boolean;
}) => {
  const cfg = STATUS_CONFIG[task.status];
  const [expanded, setExpanded] = useState(false);
  const hasExecutionData = executions.length > 0;
  const isDone = task.status === "completed" || task.status === "verified";

  return (
    <div style={{
      borderRadius: "10px",
      background: expanded ? "#fbfaf9" : "white",
      border: "1px solid #eae7e0",
      transition: "all 0.15s"
    }}>
      <div
        onClick={() => hasExecutionData && setExpanded(!expanded)}
        style={{ padding: "12px", display: "flex", alignItems: "center", justifyContent: "space-between", cursor: hasExecutionData ? "pointer" : "default" }}
      >
         <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            <button
              type="button"
              onClick={(e) => { e.stopPropagation(); if (!isUpdating) onToggleStatus(task); }}
              disabled={isUpdating}
              title={isDone ? "إلغاء تحديد المهمة كمكتملة" : "تحديد المهمة كمكتملة"}
              style={{ border: "none", background: "transparent", padding: 0, cursor: isUpdating ? "not-allowed" : "pointer", display: "flex" }}
            >
              <div style={{ color: cfg.color, background: cfg.bg, padding: "6px", borderRadius: "8px", opacity: isUpdating ? 0.5 : 1 }}>
                {isUpdating ? <Loader2 size={14} className="spin" /> : cfg.icon}
              </div>
            </button>
            <div>
               <div style={{ fontSize: "0.9rem", fontWeight: "600", color: "#2e2b27" }}>{task.title}</div>
               <div style={{ fontSize: "0.75rem", color: "#a8a298" }}>شهر {MONTH_NAMES[task.month - 1] || task.month}</div>
            </div>
         </div>
         <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
             {hasExecutionData && <span style={{ fontSize: "0.75rem", fontWeight: "700", color: "#30461F", background: "#e3ebe0", padding: "2px 8px", borderRadius: "10px" }}>{executions.length} تنفيذ</span>}
             {hasExecutionData && (expanded ? <ChevronDown size={14} className="text-gray-400" /> : <ChevronLeft size={14} className="text-gray-400" />)}
         </div>
      </div>

      {expanded && hasExecutionData && (
         <div style={{ borderTop: "1px solid #eae7e0", padding: "12px" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
               {executions.map((exec: any) => (
                  <div key={exec.id} style={{ background: "white", border: "1px solid #eae7e0", borderRadius: "8px", padding: "12px" }}>
                     <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "8px" }}>
                         <span style={{ fontSize: "0.75rem", fontWeight: "600", color: "#30461F" }}>
                            {exec.status === "completed" ? "مكتمل" : exec.status === "verified" ? "محقق" : "مرفوض"}
                         </span>
                         <span style={{ fontSize: "0.7rem", color: "#a8a298" }}>
                           {formatDateTime(exec.createdAt)}
                         </span>
                     </div>
                     {exec.notes && <div style={{ fontSize: "0.85rem", color: "#2e2b27", background: "#f5f3ef", padding: "8px", borderRadius: "6px" }}>{exec.notes}</div>}
                     {exec.gpsLat && (
                        <a href={`https://www.google.com/maps?q=${exec.gpsLat},${exec.gpsLng}`} target="_blank" style={{ color: "#aa4d13", fontSize: "0.75rem", marginTop: "8px", display: "inline-flex", alignItems: "center", gap: "4px" }}>
                           <Navigation size={12} /> الموقع
                        </a>
                     )}
                  </div>
               ))}
            </div>
         </div>
      )}
    </div>
  );
};

const CommentsSection = ({ comments, highlightedCommentId }: { comments: any[]; highlightedCommentId?: string | null }) => {
  return (
    <div style={{ borderTop: "1px solid #f5f3ef", padding: "16px", background: "#fbfaf9" }}>
       <h4 style={{ margin: "0 0 12px", fontSize: "0.85rem", color: "#2e2b27", display: "flex", alignItems: "center", gap: "8px" }}>
       <MessageSquare size={16} /> تعليقات الزيارة
       </h4>
       <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
           {comments.map((c: any) => {
             const isHighlighted = highlightedCommentId === c.id;
             return (
             <div key={c.id} id={`client-comment-${c.id}`} style={{ display: "flex", gap: "10px", scrollMarginTop: "120px" }}>
                <div style={{ width: "32px", height: "32px", borderRadius: "50%", background: "#e3ebe0", display: "flex", alignItems: "center", justifyContent: "center" }}>
                   <UserIcon size={16} color="#5c574f" />
                </div>
               <div style={{
                flex: 1,
                background: isHighlighted ? "#fff7ed" : "white",
                padding: "10px 14px",
                borderRadius: "0 12px 12px 12px",
                border: isHighlighted ? "1px solid #fb923c" : "1px solid #eae7e0",
                boxShadow: isHighlighted ? "0 0 0 2px rgba(251, 146, 60, 0.2)" : "0 1px 2px rgba(0,0,0,0.02)"
               }}>
                   <div style={{ fontSize: "0.75rem", color: "#5c574f", marginBottom: "4px", fontWeight: 600 }}>
                     {c.authorName || "العميل"}
                   </div>
                   <div style={{ fontSize: "0.75rem", color: "#a8a298", marginBottom: "4px" }}>
                      {formatDateTime(c.createdAt)}
                   </div>
                   <div style={{ fontSize: "0.9rem", color: "#1a1917", lineHeight: "1.5" }}>{c.comment}</div>
                   {c.attachmentPath && (
                     <a href={c.attachmentPath} target="_blank" rel="noreferrer" style={{ marginTop: "8px", display: "inline-block", width: "80px", height: "80px", borderRadius: "8px", overflow: "hidden", border: "2px solid #eae7e0" }}>
                       <img src={c.attachmentPath} alt="مرفق" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                     </a>
                   )}
                </div>
             </div>
             )})}
       </div>
    </div>
  );
};

const Modal = ({ title, onClose, children, width = "450px" }: any) => (
  <div style={{
    position: "fixed", inset: 0, background: "rgba(15, 23, 42, 0.4)",
    backdropFilter: "blur(8px)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 100
  }}>
    <div className="bg-white rounded-2xl shadow-2xl" style={{ width: "100%", maxWidth: width, maxHeight: "90vh", overflowY: "auto", padding: "32px", background: "white", borderRadius: "16px", boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.25)" }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "24px", alignItems: "center" }}>
        <h3 style={{ margin: 0, fontSize: "1.25rem", fontWeight: "700", color: "#0f172a" }}>{title}</h3>
        <button onClick={onClose} style={{ padding: "8px", borderRadius: "50%", background: "#f1f5f9", border: "none", cursor: "pointer", color: "#64748b" }}><X size={20} /></button>
      </div>
      {children}
    </div>
  </div>
);

const AssignLineModal = ({
  supervisor,
  lines,
  loading,
  initialLineId,
  initialStart,
  initialEnd,
  onClose,
  onSubmit
}: {
  supervisor: User;
  lines: GeographicLine[];
  loading?: boolean;
  initialLineId?: string;
  initialStart?: string;
  initialEnd?: string;
  onClose: () => void;
  onSubmit: (data: { lineId: string; startDate?: string; endDate?: string }) => void;
}) => {
  const [lineId, setLineId] = useState(initialLineId || "");
  const [startDate, setStartDate] = useState(initialStart || "");
  const [endDate, setEndDate] = useState(initialEnd || "");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!lineId) return;
    onSubmit({ lineId, startDate: startDate || undefined, endDate: endDate || undefined });
  };

  return (
    <Modal title={`تعيين خط سير`} onClose={onClose}>
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "20px" }}>
        <div style={{ background: "#f8fafc", padding: "12px", borderRadius: "8px", display: "flex", alignItems: "center", gap: "10px", color: "#334155" }}>
           <UserIcon size={18} /> 
           <span style={{ fontWeight: "600" }}>{supervisor.fullName}</span>
        </div>

        <label style={{ display: "flex", flexDirection: "column", gap: "8px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
          <span>اختر خط السير <span style={{ color: "#ef4444" }}>*</span></span>
          <CustomSelect 
            value={lineId}
            onChange={(val) => setLineId(val)}
            options={lines.map(l => ({ id: l.id, label: `${l.name} (${l.zoneCount || 0} مناطق)` }))}
            placeholder="اختر خط السير"
            width="100%"
          />
        </label>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
          <label style={{ display: "flex", flexDirection: "column", gap: "8px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>من تاريخ</span>
            <input type="date" style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} className="input" value={startDate} onChange={e => setStartDate(e.target.value)} />
          </label>
          <label style={{ display: "flex", flexDirection: "column", gap: "8px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>إلى تاريخ</span>
            <input type="date" style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} className="input" value={endDate} onChange={e => setEndDate(e.target.value)} />
          </label>
        </div>

        <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
          <button className="button" type="submit" disabled={loading} style={{ flex: 1, justifyContent: "center", padding: "12px", borderRadius: "8px", background: "var(--green-600)", color: "white", fontWeight: "600", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: "8px" }}>
            {loading ? <Loader2 size={18} className="spin" /> : <Save size={18} />}
            {loading ? "جار الحفظ..." : "حفظ التعيين"}
          </button>
          <button type="button" onClick={onClose} disabled={loading} style={{ padding: "12px 24px", borderRadius: "8px", background: "white", border: "1px solid #e2e8f0", cursor: "pointer", fontWeight: "600", color: "#64748b" }}>إلغاء</button>
        </div>
      </form>
    </Modal>
  );
};

const CreateSupervisorModal = ({
  lines,
  loading,
  onClose,
  onSubmit
}: {
  lines: GeographicLine[];
  loading: boolean;
  onClose: () => void;
  onSubmit: (data: any) => void;
}) => {
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit({ fullName, email, password, phone });
  };

  return (
    <Modal title="إضافة مشرف جديد" onClose={onClose} width="500px">
      <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr", gap: "16px" }}>
          <label style={{ display: "flex", flexDirection: "column", gap: "6px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>الاسم الكامل <span style={{ color: "#ef4444" }}>*</span></span>
            <input style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} value={fullName} onChange={e => setFullName(e.target.value)} required placeholder="أدخل اسم المشرف..." />
          </label>

          <label style={{ display: "flex", flexDirection: "column", gap: "6px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>البريد الإلكتروني أو رقم الهاتف <span style={{ color: "#ef4444" }}>*</span></span>
            <input style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} type="text" value={email} onChange={e => setEmail(e.target.value)} required placeholder="example@email.com أو +96550012345" dir="ltr" />
          </label>
          
           <label style={{ display: "flex", flexDirection: "column", gap: "6px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>كلمة المرور <span style={{ color: "#ef4444" }}>*</span></span>
            <input style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} type="password" value={password} onChange={e => setPassword(e.target.value)} required placeholder="******" dir="ltr" minLength={6} />
          </label>

          <label style={{ display: "flex", flexDirection: "column", gap: "6px", fontSize: "0.9rem", fontWeight: "500", color: "#334155" }}>
            <span>رقم الهاتف</span>
            <input style={{ padding: "10px", borderRadius: "8px", border: "1px solid #e2e8f0" }} value={phone} onChange={e => setPhone(e.target.value)} placeholder="+96550012345" dir="ltr" />
          </label>
        </div>

        <div style={{ display: "flex", gap: "12px", marginTop: "12px" }}>
          <button className="button" type="submit" disabled={loading} style={{ flex: 1, justifyContent: "center", padding: "12px", borderRadius: "8px", background: "#16a34a", color: "white", fontWeight: "600", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: "8px" }}>
            {loading ? <Loader2 size={18} className="spin" /> : <Plus size={18} />}
            {loading ? "جار الإنشاء..." : "إنشاء المشرف"}
          </button>
          <button type="button" onClick={onClose} disabled={loading} style={{ padding: "12px 24px", borderRadius: "8px", background: "white", border: "1px solid #e2e8f0", cursor: "pointer", fontWeight: "600", color: "#64748b" }}>إلغاء</button>
        </div>
      </form>
    </Modal>
  );
};
