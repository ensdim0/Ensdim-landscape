import { supabase } from "@infrastructure/supabase/client";

export const syncWorkerVisaNotifications = async (): Promise<boolean> => {
  try {
    const { error } = await supabase.rpc("sync_worker_visa_expiry_notifications");
    if (error) {
      console.warn("Worker visa notification sync error:", error.message || error);
      return false;
    }

    return true;
  } catch (error) {
    console.warn("Worker visa notification sync exception:", error);
    return false;
  }
};
