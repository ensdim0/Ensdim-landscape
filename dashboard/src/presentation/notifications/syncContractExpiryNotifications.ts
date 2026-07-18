import { supabase } from "@infrastructure/supabase/client";

export const syncContractExpiryNotifications = async (): Promise<boolean> => {
  try {
    const { error } = await supabase.rpc("sync_contract_expiry_notifications");
    if (error) {
      console.warn("Contract expiry notification sync error:", error.message || error);
      return false;
    }

    return true;
  } catch (error) {
    console.warn("Contract expiry notification sync exception:", error);
    return false;
  }
};

export default syncContractExpiryNotifications;
