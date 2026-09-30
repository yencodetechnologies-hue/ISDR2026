import { AppBar, Icon } from "../ui";

export { AppBar };

/** App bar icon action (IconButton, white 24px). */
export function AppBarAction({
  icon,
  onClick,
  title,
  badge,
}: {
  icon: string;
  onClick?: () => void;
  title?: string;
  badge?: number;
}) {
  return (
    <button
      onClick={onClick}
      title={title}
      aria-label={title}
      className="relative flex h-12 w-12 items-center justify-center rounded-full active:bg-white/10"
    >
      <Icon name={icon} size={24} outline />
      {!!badge && badge > 0 && (
        <span className="absolute right-2 top-2 min-w-[16px] rounded-full bg-[#EF4444] px-1 text-center text-[9px] font-bold leading-4">
          {badge > 99 ? "99+" : badge}
        </span>
      )}
    </button>
  );
}

/** An app screen: app bar + content column (16px gutters). */
export function AppPage({
  title,
  actions,
  back,
  onBack,
  outfit,
  children,
  pad = true,
}: {
  title?: React.ReactNode;
  actions?: React.ReactNode;
  back?: boolean;
  onBack?: () => void;
  outfit?: boolean;
  children: React.ReactNode;
  pad?: boolean;
}) {
  return (
    <div className="min-h-screen bg-bg pb-8">
      <AppBar title={title} actions={actions} back={back} onBack={onBack} outfit={outfit} />
      <div className={pad ? "px-4 pt-2" : ""}>{children}</div>
    </div>
  );
}
