import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import { ConfirmProvider, ToastProvider } from "./components/ui";
import { AuthProvider } from "./lib/auth";
import { NotificationProvider } from "./lib/notifications";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <ToastProvider>
          <NotificationProvider>
            <ConfirmProvider>
              <App />
            </ConfirmProvider>
          </NotificationProvider>
        </ToastProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
);
