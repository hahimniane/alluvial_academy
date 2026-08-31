"use client";

import { Eraser, Redo2, Undo2, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";

export type TutorStroke = {
  id: string;
  points: Array<{ x: number; y: number }>;
  color: number;
  strokeWidth: number;
  normalized: boolean;
};
export type TutorWhiteboardProject = {
  strokes: TutorStroke[];
  texts: Array<Record<string, unknown>>;
  version: number;
};

export function TeacherTutorWhiteboard({
  project,
  drawingEnabled,
  onChange,
  onClose,
}: {
  project: TutorWhiteboardProject;
  drawingEnabled: boolean;
  onChange: (project: TutorWhiteboardProject) => void;
  onClose: () => void;
}) {
  const [strokes, setStrokes] = useState<TutorStroke[]>(project.strokes);
  const [redo, setRedo] = useState<TutorStroke[]>([]);
  const [active, setActive] = useState<TutorStroke | null>(null);
  const svgRef = useRef<SVGSVGElement | null>(null);
  useEffect(() => {
    setStrokes(project.strokes);
    setRedo([]);
  }, [project]);
  function point(event: React.PointerEvent<SVGSVGElement>) {
    const box = svgRef.current?.getBoundingClientRect();
    if (!box) return { x: 0, y: 0 };
    return {
      x: Math.max(0, Math.min(1, (event.clientX - box.left) / box.width)),
      y: Math.max(0, Math.min(1, (event.clientY - box.top) / box.height)),
    };
  }
  function publish(next: TutorStroke[], texts = project.texts) {
    setStrokes(next);
    onChange({ strokes: next, texts, version: 2 });
  }
  return (
    <section
      className="fixed inset-0 z-[85] flex flex-col bg-[#F8FAFC]"
      role="dialog"
      aria-modal="true"
      aria-label="AI Tutor whiteboard"
    >
      <header className="flex min-h-14 items-center gap-2 border-b border-[#E2E8F0] bg-white px-3">
        <h2 className="min-w-0 flex-1 truncate font-extrabold">
          AI Tutor Whiteboard
        </h2>
        <button
          type="button"
          aria-label="Undo whiteboard stroke"
          disabled={!strokes.length || !drawingEnabled}
          onClick={() => {
            const removed = strokes.at(-1);
            if (!removed) return;
            setRedo((current) => [...current, removed]);
            publish(strokes.slice(0, -1));
          }}
          className="grid h-10 w-10 place-items-center rounded-xl disabled:opacity-40"
        >
          <Undo2 size={19} />
        </button>
        <button
          type="button"
          aria-label="Redo whiteboard stroke"
          disabled={!redo.length || !drawingEnabled}
          onClick={() => {
            const restored = redo.at(-1);
            if (!restored) return;
            setRedo((current) => current.slice(0, -1));
            publish([...strokes, restored]);
          }}
          className="grid h-10 w-10 place-items-center rounded-xl disabled:opacity-40"
        >
          <Redo2 size={19} />
        </button>
        <button
          type="button"
          aria-label="Clear whiteboard"
          disabled={!strokes.length || !drawingEnabled}
          onClick={() => {
            setRedo(strokes);
            publish([], []);
          }}
          className="inline-flex min-h-10 items-center gap-2 rounded-xl px-3 text-sm font-bold text-red-600 disabled:opacity-40"
        >
          <Eraser size={18} />
          Clear
        </button>
        <button
          type="button"
          aria-label="Close whiteboard"
          onClick={onClose}
          className="grid h-10 w-10 place-items-center rounded-xl"
        >
          <X size={20} />
        </button>
      </header>
      {!drawingEnabled ? (
        <p className="bg-amber-50 px-4 py-2 text-center text-sm font-semibold text-amber-900">
          The tutor has temporarily disabled drawing.
        </p>
      ) : null}
      <svg
        ref={svgRef}
        className={`min-h-0 flex-1 touch-none bg-white ${drawingEnabled ? "cursor-crosshair" : "cursor-not-allowed"}`}
        viewBox="0 0 1000 700"
        preserveAspectRatio="none"
        onPointerDown={(event) => {
          if (!drawingEnabled) return;
          event.currentTarget.setPointerCapture(event.pointerId);
          const next: TutorStroke = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2)}`,
            points: [point(event)],
            color: 0xff111827,
            strokeWidth: 3,
            normalized: true,
          };
          setActive(next);
          setRedo([]);
        }}
        onPointerMove={(event) => {
          if (!active || !drawingEnabled) return;
          setActive({ ...active, points: [...active.points, point(event)] });
        }}
        onPointerUp={() => {
          if (!active) return;
          const next = [...strokes, active];
          setActive(null);
          publish(next);
        }}
        onPointerCancel={() => setActive(null)}
      >
        {[...strokes, ...(active ? [active] : [])].map((stroke) => (
          <polyline
            key={stroke.id}
            fill="none"
            stroke={argbToCss(stroke.color)}
            strokeWidth={stroke.strokeWidth}
            strokeLinecap="round"
            strokeLinejoin="round"
            vectorEffect="non-scaling-stroke"
            points={stroke.points
              .map((item) => `${item.x * 1000},${item.y * 700}`)
              .join(" ")}
          />
        ))}
      </svg>
    </section>
  );
}

function argbToCss(value: number) {
  const unsigned = value >>> 0;
  const a = ((unsigned >> 24) & 255) / 255;
  const r = (unsigned >> 16) & 255;
  const g = (unsigned >> 8) & 255;
  const b = unsigned & 255;
  return `rgba(${r},${g},${b},${a})`;
}
