import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { Button, Checkbox, Icon, Input, PasswordInput, useToast } from "@/components/ui";
import { asset } from "@/lib/api";
import { homeFor, useAuth } from "@/lib/auth";

const EMAIL_RE = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

/** One login for every role — the backend works out the account type. */
export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [errors, setErrors] = useState<{ id?: string; pw?: string }>({});
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (loading) return;
    const id = identifier.trim();
    const errs: typeof errors = {};
    if (!id) errs.id = "Please enter your email or mobile number";
    else if (!/^\d{10}$/.test(id) && !EMAIL_RE.test(id)) errs.id = "Please enter a valid email or 10-digit mobile number";
    if (!password) errs.pw = "Please enter your password";
    else if (password.length < 6) errs.pw = "Password must be at least 6 characters";
    setErrors(errs);
    if (errs.id || errs.pw) return;
    setLoading(true);
    const res = await login(id, password);
    setLoading(false);
    if (res.error || !res.user) {
      toast(res.error || "Login failed", "error");
      return;
    }
    if (res.user.status === "rejected") {
      toast("Your account has been rejected. Please contact administrator.", "error");
      return;
    }
    navigate(homeFor(res.user), { replace: true });
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-bg px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 flex flex-col items-center">
          <img src={asset("ISDR 2026 Logo.png")} alt="ISDR 2026" className="h-20 object-contain" />
        </div>
        <form onSubmit={submit} className="card p-6">
          <div className="flex flex-col items-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-accent/15">
              <Icon name="person" size={26} color="#3B82F6" />
            </div>
            <div className="mt-3 text-xl font-extrabold">Welcome Back</div>
            <div className="mt-1 text-xs text-muted">Sign in to access your portal</div>
          </div>
          <div className="mt-6 space-y-3">
            <div>
              <Input
                icon="mail"
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                placeholder="Email or mobile number"
                autoComplete="username"
                disabled={loading}
              />
              {errors.id && <div className="mt-1 text-xs text-danger">{errors.id}</div>}
            </div>
            <div>
              <PasswordInput
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Password"
                autoComplete="current-password"
                disabled={loading}
              />
              {errors.pw && <div className="mt-1 text-xs text-danger">{errors.pw}</div>}
            </div>
          </div>
          <div className="mt-3 flex items-center justify-between">
            <Checkbox checked={remember} onChange={setRemember} label={<span className="text-xs">Remember me</span>} />
            <Link to="/forgot-password" className="text-xs font-semibold text-accent">
              Forgot Password?
            </Link>
          </div>
          <Button type="submit" full loading={loading} className="mt-5 py-3">
            Login
          </Button>
        </form>
      </div>
    </div>
  );
}
