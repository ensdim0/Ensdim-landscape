import { useState, useRef, useEffect, useLayoutEffect, type CSSProperties } from 'react';
import { createPortal } from 'react-dom';
import { ChevronDown, Check } from 'lucide-react';

interface Option {
  id: string | number;
  label: string;
}

interface CustomSelectProps {
  value: string | number;
  onChange: (value: string) => void;
  options: Option[];
  placeholder?: string;
  width?: string;
  className?: string;
  disabled?: boolean;
  searchable?: boolean;
}

export const CustomSelect = ({ 
  value, 
  onChange, 
  options, 
  placeholder = "Select...", 
  width = "200px",
  className = "",
  disabled = false,
  searchable = false
}: CustomSelectProps) => {
  const [isOpen, setIsOpen] = useState(false);
  const [menuStyle, setMenuStyle] = useState<CSSProperties>({});
  const containerRef = useRef<HTMLDivElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [searchQuery, setSearchQuery] = useState("");

  const selectedOption = options.find(opt => String(opt.id) === String(value));

  const updateMenuPosition = () => {
    if (!containerRef.current || typeof window === "undefined") return;

    const rect = containerRef.current.getBoundingClientRect();
    const viewportPadding = 12;
    const menuGap = 8;
    const maxMenuHeight = 240;
    const spaceBelow = window.innerHeight - rect.bottom - viewportPadding;
    const spaceAbove = rect.top - viewportPadding;
    const openAbove = spaceBelow < 180 && spaceAbove > spaceBelow;
    const availableSpace = Math.max(0, openAbove ? spaceAbove - menuGap : spaceBelow - menuGap);
    const menuWidth = Math.min(rect.width, Math.max(0, window.innerWidth - viewportPadding * 2));
    const left = Math.min(
      Math.max(rect.left, viewportPadding),
      Math.max(viewportPadding, window.innerWidth - menuWidth - viewportPadding)
    );

    setMenuStyle({
      position: "fixed",
      left,
      width: menuWidth,
      maxHeight: Math.min(maxMenuHeight, Math.max(availableSpace, 120)),
      zIndex: 3000,
      top: openAbove ? undefined : rect.bottom + menuGap,
      bottom: openAbove ? window.innerHeight - rect.top + menuGap : undefined,
      overflowY: "auto",
      overscrollBehavior: "contain",
      WebkitOverflowScrolling: "touch",
    });
  };

  useEffect(() => {
    if (!isOpen) return;

    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as Node;
      if (
        containerRef.current &&
        !containerRef.current.contains(target) &&
        menuRef.current &&
        !menuRef.current.contains(target)
      ) {
        setIsOpen(false);
      }
    };

    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    };

    const handleLayoutChange = () => updateMenuPosition();

    document.addEventListener('mousedown', handleClickOutside);
    document.addEventListener('keydown', handleEscape);
    window.addEventListener('resize', handleLayoutChange);
    window.addEventListener('scroll', handleLayoutChange, true);

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleEscape);
      window.removeEventListener('resize', handleLayoutChange);
      window.removeEventListener('scroll', handleLayoutChange, true);
    };
  }, [isOpen]);

  useLayoutEffect(() => {
    if (isOpen) {
      updateMenuPosition();
    }
  }, [isOpen, options.length]);

  useLayoutEffect(() => {
    if (isOpen) updateMenuPosition();
  }, [isOpen, searchQuery]);

  const menu = isOpen && typeof document !== 'undefined' ? createPortal(
    <div
      ref={menuRef}
      style={{
        ...menuStyle,
        background: 'var(--bg-card)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-md)',
        boxShadow: 'var(--shadow-lg)',
        padding: '4px',
        animation: 'fadeIn 0.15s ease',
      }}
      role="listbox"
    >
      {searchable && (
        <div style={{ padding: '6px 8px 0 8px' }}>
          <input
            autoFocus
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="بحث..."
            style={{
              width: '100%',
              padding: '8px 10px',
              borderRadius: '8px',
              border: '1px solid var(--color-border)',
              outline: 'none',
              fontSize: '0.9rem',
              boxSizing: 'border-box'
            }}
          />
        </div>
      )}

      {
        (() => {
          const visible = searchQuery && searchable
            ? options.filter(o => String(o.label).toLowerCase().includes(searchQuery.toLowerCase()))
            : options;

          return visible.length > 0 ? (
            visible.map((option) => {
              const isSelected = String(option.id) === String(value);
              return (
                <div
                  key={option.id}
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => {
                    onChange(String(option.id));
                    setIsOpen(false);
                    setSearchQuery("");
                  }}
                  style={{
                    padding: '8px 12px',
                    fontSize: '0.9rem',
                    color: isSelected ? 'var(--color-primary)' : 'var(--text-primary)',
                    background: isSelected ? 'var(--bg-primary-light)' : 'transparent',
                    borderRadius: 'var(--radius-sm)',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    transition: 'background 0.15s'
                  }}
                  onMouseEnter={e => {
                    if (!isSelected) e.currentTarget.style.background = 'var(--bg-subtle)';
                  }}
                  onMouseLeave={e => {
                    if (!isSelected) e.currentTarget.style.background = 'transparent';
                  }}
                >
                  <span style={{ flex: 1 }}>{option.label}</span>
                  {isSelected && <Check size={14} />}
                </div>
              );
            })
          ) : (
            <div style={{ padding: '12px', textAlign: 'center', color: 'var(--text-tertiary)', fontSize: '0.85rem' }}>
              لا توجد خيارات
            </div>
          );
        })()
      }
    </div>,
    document.body
  ) : null;

  return (
    <div 
      ref={containerRef} 
      className={`custom-select-container ${className} ${disabled ? 'disabled' : ''}`} 
      style={{ width, position: 'relative', userSelect: 'none', opacity: disabled ? 0.6 : 1, pointerEvents: disabled ? 'none' : 'auto' }}
    >
      <div 
        onClick={() => !disabled && setIsOpen(!isOpen)}
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 12px',
          height: '42px',
          background: disabled ? 'var(--neutral-100)' : 'var(--bg-card)',
          border: isOpen ? '1px solid var(--color-primary)' : '1px solid var(--color-border)',
          borderRadius: 'var(--radius-md)',
          cursor: disabled ? 'not-allowed' : 'pointer',
          color: selectedOption ? 'var(--text-primary)' : 'var(--text-tertiary)',
          fontSize: '0.9rem',
          transition: 'all 0.2s ease',
          boxShadow: isOpen ? '0 0 0 2px var(--color-primary-faded)' : 'none'
        }}
      >
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {selectedOption ? selectedOption.label : placeholder}
        </span>
        <ChevronDown 
          size={16} 
          style={{ 
            color: 'var(--text-tertiary)', 
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
            transition: 'transform 0.2s ease'
          }} 
        />
      </div>
      {menu}
    </div>
  );
};
