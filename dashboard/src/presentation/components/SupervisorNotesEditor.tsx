import { useEffect, useState } from "react";
import { SupervisorNote } from "@domain/entities/SupervisorNote";
import { Edit2, Trash2, X, Save } from "lucide-react";

interface SupervisorNotesEditorProps {
  visitId: string;
  notes: SupervisorNote[];
  onAddNote: (content: string, visibility: "supervisors_only" | "all") => Promise<void>;
  onUpdateNote: (noteId: string, content: string, visibility: "supervisors_only" | "all") => Promise<void>;
  onDeleteNote: (noteId: string) => Promise<void>;
  isLoading?: boolean;
}

export const SupervisorNotesEditor: React.FC<SupervisorNotesEditorProps> = ({
  visitId,
  notes,
  onAddNote,
  onUpdateNote,
  onDeleteNote,
  isLoading = false,
}) => {
  const [newContent, setNewContent] = useState("");
  const [newVisibility, setNewVisibility] = useState<"supervisors_only" | "all">("supervisors_only");
  const [editingNoteId, setEditingNoteId] = useState<string | null>(null);
  const [editContent, setEditContent] = useState("");
  const [editVisibility, setEditVisibility] = useState<"supervisors_only" | "all">("supervisors_only");
  const [isAdding, setIsAdding] = useState(false);

  const handleAddNote = async () => {
    if (!newContent.trim()) return;
    try {
      await onAddNote(newContent, newVisibility);
      setNewContent("");
      setNewVisibility("supervisors_only");
    } catch (error) {
      console.error("Error adding note:", error);
    }
  };

  const handleUpdateNote = async (noteId: string) => {
    if (!editContent.trim()) return;
    try {
      await onUpdateNote(noteId, editContent, editVisibility);
      setEditingNoteId(null);
      setEditContent("");
      setEditVisibility("supervisors_only");
    } catch (error) {
      console.error("Error updating note:", error);
    }
  };

  const handleDeleteNote = async (noteId: string) => {
    if (confirm("هل تريد حذف هذه الملاحظة؟")) {
      try {
        await onDeleteNote(noteId);
      } catch (error) {
        console.error("Error deleting note:", error);
      }
    }
  };

  const startEdit = (note: SupervisorNote) => {
    setEditingNoteId(note.id);
    setEditContent(note.content);
    setEditVisibility(note.visibility);
  };

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
      {/* Add new note */}
      <div style={{ padding: "12px", background: "#fbfaf9", borderRadius: "8px", border: "1px solid #eae7e0" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <div style={{ fontSize: "0.75rem", fontWeight: 700, color: "#2e2b27" }}>
            ملاحظة جديدة
          </div>
          <textarea
            value={newContent}
            onChange={(e) => setNewContent(e.target.value)}
            placeholder="أضف ملاحظتك هنا..."
            style={{
              width: "100%",
              padding: "8px",
              borderRadius: "6px",
              border: "1px solid #d8d3cc",
              fontFamily: "inherit",
              fontSize: "0.85rem",
              resize: "vertical",
              minHeight: "60px",
            }}
            disabled={isLoading}
          />
          <div style={{ display: "flex", gap: "8px", alignItems: "center" }}>
            <select
              value={newVisibility}
              onChange={(e) => setNewVisibility(e.target.value as "supervisors_only" | "all")}
              style={{
                padding: "6px 8px",
                borderRadius: "6px",
                border: "1px solid #d8d3cc",
                fontSize: "0.75rem",
                fontFamily: "inherit",
              }}
              disabled={isLoading}
            >
              <option value="supervisors_only">للمشرفين فقط 🔒</option>
              <option value="all">للمشرفين والعملاء 👥</option>
            </select>
            <button
              onClick={handleAddNote}
              disabled={!newContent.trim() || isLoading}
              style={{
                padding: "6px 12px",
                borderRadius: "6px",
                background: newContent.trim() ? "#aa4d13" : "#d8d3cc",
                color: "white",
                border: "none",
                fontSize: "0.75rem",
                fontWeight: 600,
                cursor: newContent.trim() ? "pointer" : "default",
                transition: "background 0.2s",
              }}
            >
              {isLoading ? "جاري الحفظ..." : "حفظ"}
            </button>
          </div>
        </div>
      </div>

      {/* Existing notes */}
      {notes.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <div style={{ fontSize: "0.75rem", fontWeight: 700, color: "#2e2b27" }}>
            ({notes.length}) الملاحظات
          </div>
          {notes.map((note) => (
            <div
              key={note.id}
              style={{
                padding: "12px",
                background: note.visibility === "all" ? "#f0fdf4" : "#fbfaf9",
                borderRadius: "8px",
                border: `1px solid ${note.visibility === "all" ? "#bbf7d0" : "#eae7e0"}`,
              }}
            >
              {editingNoteId === note.id ? (
                // Edit mode
                <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                  <textarea
                    value={editContent}
                    onChange={(e) => setEditContent(e.target.value)}
                    style={{
                      width: "100%",
                      padding: "8px",
                      borderRadius: "6px",
                      border: "1px solid #d8d3cc",
                      fontFamily: "inherit",
                      fontSize: "0.85rem",
                      resize: "vertical",
                      minHeight: "60px",
                    }}
                    disabled={isLoading}
                  />
                  <div style={{ display: "flex", gap: "8px" }}>
                    <select
                      value={editVisibility}
                      onChange={(e) => setEditVisibility(e.target.value as "supervisors_only" | "all")}
                      style={{
                        padding: "6px 8px",
                        borderRadius: "6px",
                        border: "1px solid #d8d3cc",
                        fontSize: "0.75rem",
                        fontFamily: "inherit",
                      }}
                      disabled={isLoading}
                    >
                      <option value="supervisors_only">للمشرفين فقط 🔒</option>
                      <option value="all">للمشرفين والعملاء 👥</option>
                    </select>
                    <button
                      onClick={() => handleUpdateNote(note.id)}
                      disabled={!editContent.trim() || isLoading}
                      style={{
                        padding: "6px 12px",
                        borderRadius: "6px",
                        background: "#166534",
                        color: "white",
                        border: "none",
                        fontSize: "0.75rem",
                        fontWeight: 600,
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "4px",
                      }}
                    >
                      <Save size={12} /> حفظ
                    </button>
                    <button
                      onClick={() => setEditingNoteId(null)}
                      style={{
                        padding: "6px 12px",
                        borderRadius: "6px",
                        background: "#e5e0d8",
                        color: "#5c574f",
                        border: "none",
                        fontSize: "0.75rem",
                        fontWeight: 600,
                        cursor: "pointer",
                        display: "flex",
                        alignItems: "center",
                        gap: "4px",
                      }}
                    >
                      <X size={12} /> إلغاء
                    </button>
                  </div>
                </div>
              ) : (
                // View mode
                <div style={{ display: "flex", justifyContent: "space-between", gap: "12px" }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: "flex", alignItems: "center", gap: "6px", marginBottom: "4px" }}>
                      <span
                        style={{
                          fontSize: "0.65rem",
                          fontWeight: 700,
                          padding: "2px 6px",
                          borderRadius: "4px",
                          background: note.visibility === "all" ? "#dcfce7" : "#f3f3f1",
                          color: note.visibility === "all" ? "#166534" : "#5c574f",
                        }}
                      >
                        {note.visibility === "all" ? "👥 العملاء" : "🔒 المشرفين"}
                      </span>
                      <span style={{ fontSize: "0.7rem", color: "#a8a298" }}>
                        {new Date(note.createdAt).toLocaleDateString("ar-EG")}
                      </span>
                    </div>
                    <div
                      style={{
                        fontSize: "0.85rem",
                        color: "#2e2b27",
                        lineHeight: 1.6,
                        whiteSpace: "pre-wrap",
                      }}
                    >
                      {note.content}
                    </div>
                  </div>
                  <div style={{ display: "flex", gap: "4px" }}>
                    <button
                      onClick={() => startEdit(note)}
                      style={{
                        padding: "4px 6px",
                        borderRadius: "4px",
                        background: "transparent",
                        border: "none",
                        cursor: "pointer",
                        color: "#aa4d13",
                        display: "flex",
                        alignItems: "center",
                      }}
                      title="تعديل"
                    >
                      <Edit2 size={14} />
                    </button>
                    <button
                      onClick={() => handleDeleteNote(note.id)}
                      style={{
                        padding: "4px 6px",
                        borderRadius: "4px",
                        background: "transparent",
                        border: "none",
                        cursor: "pointer",
                        color: "#dc2626",
                        display: "flex",
                        alignItems: "center",
                      }}
                      title="حذف"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
