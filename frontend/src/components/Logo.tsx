export function Logo({ size = 36 }: { size?: number }) {
  return (
    <div className="flex items-center gap-3">
      <div
        className="grid place-items-center rounded-xl bg-gradient-to-br from-brand-500 to-brand-700 shadow-lg shadow-brand-900/30"
        style={{ width: size, height: size }}
      >
        <svg
          viewBox="0 0 64 64"
          width={size * 0.62}
          height={size * 0.62}
          fill="none"
        >
          <path
            d="M20 44V20h4l16 17V20h4v24h-4L24 27v17z"
            fill="white"
          />
        </svg>
      </div>
      <div className="leading-tight">
        <div className="text-lg font-extrabold tracking-tight text-white">
          Noesis
        </div>
        <div className="text-[11px] font-medium uppercase tracking-[0.18em] text-brand-200/80">
          Conocimiento Estatal
        </div>
      </div>
    </div>
  );
}
