import { AppRouter } from "@presentation/routing/AppRouter";
import { ToastProvider } from "@presentation/components/ToastProvider";
import { TourProvider } from "@presentation/components/tour/TourContext";

export const App = () => {
  return (
    <ToastProvider>
      <TourProvider>
        <AppRouter />
      </TourProvider>
    </ToastProvider>
  );
};
