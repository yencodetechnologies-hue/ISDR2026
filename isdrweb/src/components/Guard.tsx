import { Navigate, Outlet, useLocation } from "react-router-dom";
import { homeFor, useAuth } from "@/lib/auth";
import Shell from "./Shell";
import { Loading } from "./ui";

/**
 * Only lets signed-in users of the given roles through; others go to login / their own home.
 * With `shell`, the pages inside render in the website layout (sidebar + top bar).
 */
export default function Guard({ roles, shell }: { roles?: string[]; shell?: boolean }) {
  const { user, ready } = useAuth();
  const location = useLocation();
  if (!user) {
    if (!ready) return <Loading />;
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  const type = String(user.userType ?? "").toLowerCase();
  if (roles && !roles.includes(type === "tenant" ? "user" : type)) return <Navigate to={homeFor(user)} replace />;
  if (!shell) return <Outlet />;
  return (
    <Shell>
      <Outlet />
    </Shell>
  );
}
