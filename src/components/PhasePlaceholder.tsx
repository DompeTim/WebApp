interface PhasePlaceholderProps {
  title: string;
  phase: string;
  description: string;
}

export function PhasePlaceholder({
  title,
  phase,
  description,
}: PhasePlaceholderProps) {
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h1 className="text-xl font-bold tracking-tight text-slate-900 sm:text-2xl">
          {title}
        </h1>
        <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-800">
          {phase}
        </span>
      </div>
      <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-6 text-sm leading-relaxed text-slate-600">
        {description}
      </div>
    </div>
  );
}
