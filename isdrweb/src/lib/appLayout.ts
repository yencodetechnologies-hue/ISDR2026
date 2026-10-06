import { createContext, useContext } from "react";
import type { Role } from "./nav";

/**
 * Roles whose phone-width pages copy the mobile app's screens (app headers,
 * app bars, module grids…). Other roles keep the website's own phone layout
 * until they are converted. Desktop is never affected.
 */
export const APP_LAYOUT_ROLES: Role[] = ["apartment", "participant", "user"];

/** True inside the Shell when the current page should render the app's phone layout. */
export const AppLayoutContext = createContext(false);

export const useAppLayout = () => useContext(AppLayoutContext);

/**
 * The same flag for things rendered outside the Shell (the confirm dialog lives at the
 * app root): the Shell sets it while an app-layout page is on screen.
 */
let appLayoutActive = false;
export const setAppLayoutActive = (v: boolean) => {
  appLayoutActive = v;
};
export const isAppLayoutActive = () => appLayoutActive;
