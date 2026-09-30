import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import AuthLayout from "@/components/AuthLayout";
import { Button, Checkbox, Input, PasswordInput, useToast } from "@/components/ui";
import { homeFor, useAuth } from "@/lib/auth";
import { useMobile } from "@/lib/useMobile";
import LoginApp from "./LoginApp";

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
  const mobile = useMobile();

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (loading) return;
    const id = identifier.trim();
    const errs: typeof errors = {};
    if (!id) errs.id = "Please enter your email or mobile number";
    else if (!/^\d{10}$/.test(id) && !EMAIL_RE.test(id))
      errs.id = "Please enter a valid email or 10-digit mobile number";
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

  // Phone width: the mobile app's login screen.
  if (mobile)
    return (
      <LoginApp
        identifier={identifier}
        setIdentifier={setIdentifier}
        password={password}
        setPassword={setPassword}
        remember={remember}
        setRemember={setRemember}
        errors={errors}
        loading={loading}
        onSubmit={submit}
      />
    );

  return (
    <AuthLayout>
      <form onSubmit={submit}>
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Welcome Back</h2>
          <div className="mt-2 text-sm text-muted">Sign in to access your portal</div>
        </div>
        <div className="mt-8 space-y-4">
          <div>
            <label className="label">Email or mobile number</label>
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
            <label className="label">Password</label>
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
        <div className="mt-4 flex items-center justify-between">
          <Checkbox
            checked={remember}
            onChange={setRemember}
            label={<span className="text-sm text-white/75">Remember me</span>}
          />
          <Link to="/forgot-password" className="text-sm font-semibold text-accent hover:underline">
            Forgot Password?
          </Link>
        </div>
        <Button type="submit" full loading={loading} icon="login" className="mt-6 py-3">
          Login
        </Button>
        <div className="mt-8 border-t border-line pt-5 text-center text-xs text-muted">
          One login for delegates, speakers, event staff and admins.
        </div>
      </form>
    </AuthLayout>
  );
}
