import { AppRouter } from "@presentation/routing/AppRouter";
import { ToastProvider } from "@presentation/components/ToastProvider";

export const App = () => {
  return (
    <ToastProvider>
      <AppRouter />
    </ToastProvider>
  );
};
