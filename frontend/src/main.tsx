import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import App from "./app/App.tsx";

// Service-worker registration + the "Update available" prompt are handled by
// <UpdatePrompt/> (via useRegisterSW) inside <App/>.

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>
);
