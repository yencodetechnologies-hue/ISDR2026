import { Navigate, Outlet, useLocation } from "react-router-dom";
import { homeFor, useAuth } from "@/lib/auth";
import { Loading } from "./ui";

/** Only lets signed-in users of the given roles through; others go to login / their own home. */
export default function Guard({ roles }: { roles?: string[] }) {
  const { user, ready } = useAuth();
  const location = useLocation();
  if (!user) {
    if (!ready) return <Loading />;
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }
  const type = String(user.userType ?? "").toLowerCase();
  if (roles && !roles.includes(type === "tenant" ? "user" : type)) return <Navigate to={homeFor(user)} replace />;
  return <Outlet />;
}
