import { useNavigate } from "react-router-dom";
import { Button, Icon } from "@/components/ui";
import { useAuth } from "@/lib/auth";

export default function WaitingApproval() {
  const navigate = useNavigate();
  const { logout } = useAuth();
  return (
    <div className="flex min-h-screen items-center justify-center bg-bg px-4">
      <div className="card w-full max-w-md p-6 text-center">
        <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-amber-500/15">
          <Icon name="hourglass_top" size={32} color="#F59E0B" />
        </div>
        <div className="mt-4 text-xl font-extrabold">Waiting for Approval</div>
        <div className="mt-1 text-sm text-muted">Your account is under review</div>
        <div className="mt-5 rounded-xl bg-field p-4 text-left">
          <div className="text-sm font-bold">What happens next?</div>
          <div className="mt-1 text-sm text-white/70">
            Your registration has been submitted successfully. Our administrator is reviewing your account details. You will be notified
            once your account is approved.
          </div>
        </div>
        <div className="mt-3 rounded-xl bg-field p-4 text-left">
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
    </div>
  );
}
