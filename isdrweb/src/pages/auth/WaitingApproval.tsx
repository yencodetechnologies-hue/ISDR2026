import { useNavigate } from "react-router-dom";
import AuthLayout from "@/components/AuthLayout";
import { Button, Icon } from "@/components/ui";
import { useAuth } from "@/lib/auth";

export default function WaitingApproval() {
  const navigate = useNavigate();
  const { logout } = useAuth();
  return (
    <AuthLayout>
      <div>
        <div className="flex h-14 w-14 items-center justify-center rounded-xl bg-amber-500/15">
          <Icon name="hourglass_top" size={30} color="#F59E0B" />
        </div>
        <h2 className="mt-6 text-3xl font-bold tracking-tight">Waiting for Approval</h2>
        <div className="mt-2 text-sm text-muted">Your account is under review</div>
        <div className="mt-6 rounded-lg border border-line bg-white/[0.03] p-4 text-left">
          <div className="text-sm font-bold">What happens next?</div>
          <div className="mt-1 text-sm text-white/70">
            Your registration has been submitted successfully. Our administrator is reviewing your account details. You
            will be notified once your account is approved.
          </div>
        </div>
        <div className="mt-3 rounded-lg border border-line bg-white/[0.03] p-4 text-left">
          <div className="text-sm font-bold">Need Help?</div>
          <div className="mt-1 text-sm text-white/70">Contact your administrator</div>
        </div>
        <Button
          full
          className="mt-6"
          onClick={() => {
            logout();
            navigate("/login", { replace: true });
          }}
        >
          Back to Login
        </Button>
      </div>
    </AuthLayout>
  );
}
