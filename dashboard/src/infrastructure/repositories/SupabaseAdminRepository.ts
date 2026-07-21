import { AdminRepository } from "@domain/repositories/AdminRepository";
import { supabase } from "@infrastructure/supabase/client";
import { env } from "@core/config/env";
import { Contract, ContractPalmInfo, ContractStatus } from "@domain/entities/Contract";
import { ContractTask } from "@domain/entities/ContractTask";
import { Invoice, InvoiceStatus } from "@domain/entities/Invoice";
import { User } from "@domain/entities/User";
import { ContractType } from "@domain/entities/ContractType";
import { ContractTerm } from "@domain/entities/ContractTerm";
import { Visit } from "@domain/entities/Visit";
import { ContractPayment, PaymentMethod } from "@domain/entities/ContractPayment";
import { StandaloneTask } from "@domain/entities/StandaloneTask";
import { StandaloneTaskPayment } from "@domain/entities/StandaloneTaskPayment";
import { CompanyExpense, CompanyExpenseCategory } from "@domain/entities/CompanyExpense";
import { ExpenseSection } from "@domain/entities/ExpenseSection";
import { ExpenseLineItem } from "@domain/entities/ExpenseLineItem";

const BUCKET = 'contract-images';
const PAYMENT_BUCKET = 'payment-images';

export class SupabaseAdminRepository implements AdminRepository {
  // Manually-recorded "gateway" payments (added/edited by an admin, not created
  // via the UPayments checkout flow) don't go through create-upayment-charge or
  // verify-upayment, so gateway_fee_amount would otherwise stay null — making
  // them count toward gateway revenue but not toward the commission total.
  // Mirrors the fee calc used in the verify-upayment/webhook edge functions.
  private async computeGatewayFeeAmount(): Promise<number> {
    return this.getUpaymentsFeeAmount();
  }

  private async resolveTaskPhotoUrl(photoPath: string | null | undefined): Promise<string> {
    if (!photoPath) return "";

    if (photoPath.startsWith("http://") || photoPath.startsWith("https://")) {
      return photoPath;
    }

    const { data, error } = await supabase.storage
      .from("task-photos")
      .createSignedUrl(photoPath, 60 * 60);

    if (!error && data?.signedUrl) {
      return data.signedUrl;
    }

    // Fallback for older environments that still use public buckets.
    return supabase.storage.from("task-photos").getPublicUrl(photoPath).data.publicUrl;
  }

  private toInputDate(value: any): string | null {
    if (value === null || value === undefined) return null;
    const s = String(value);
    // If value already contains a date part (ISO or timestamp), extract the date portion
    if (s.includes('T')) return s.split('T')[0] ?? null;
    if (s.includes(' ')) return s.split(' ')[0] ?? null;
    return s || null;
  }

  private async getValidAccessToken(forceRefresh = false): Promise<string> {
    if (forceRefresh) {
      const { data, error } = await supabase.auth.refreshSession();
      if (error || !data.session?.access_token) {
        throw new Error("انتهت جلسة تسجيل الدخول. برجاء تسجيل الدخول مرة أخرى.");
      }
      return data.session.access_token;
    }

    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (!session?.access_token) {
      throw new Error("انتهت جلسة تسجيل الدخول. برجاء تسجيل الدخول مرة أخرى.");
    }

    const expiresAt = session.expires_at ?? 0;
    const nowInSeconds = Math.floor(Date.now() / 1000);

    // Refresh token proactively if it is close to expiry.
    if (expiresAt > 0 && expiresAt - nowInSeconds < 60) {
      const { data, error } = await supabase.auth.refreshSession();
      if (error || !data.session?.access_token) {
        throw new Error("انتهت جلسة تسجيل الدخول. برجاء تسجيل الدخول مرة أخرى.");
      }
      return data.session.access_token;
    }

    const currentToken = session.access_token;
    const { data: userData, error: userError } = await supabase.auth.getUser(currentToken);
    if (!userError && userData.user) {
      return currentToken;
    }

    // Token may be stale even when local session exists; refresh once before invoking admin functions.
    const { data: refreshedData, error: refreshedError } = await supabase.auth.refreshSession();
    if (refreshedError || !refreshedData.session?.access_token) {
      throw new Error("انتهت جلسة تسجيل الدخول. برجاء تسجيل الدخول مرة أخرى.");
    }

    return refreshedData.session.access_token;
  }

  private async invokeAdminFunctionWithToken<T>(name: string, body: unknown, accessToken: string): Promise<T> {
    const response = await fetch(`${env.supabaseUrl}/functions/v1/${name}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.supabaseAnonKey,
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(body ?? {}),
    });

    let payload: any = null;
    try {
      payload = await response.json();
    } catch {
      payload = null;
    }

    if (!response.ok) {
      const message = payload?.message || payload?.error || `Edge Function returned ${response.status}`;
      const err: any = new Error(message);
      err.status = response.status;
      err.context = { status: response.status, body: payload };
      throw err;
    }

    return payload as T;
  }

  private async invokeAdminFunction<T>(name: string, body: unknown): Promise<T> {
    const accessToken = await this.getValidAccessToken();

    try {
      return await this.invokeAdminFunctionWithToken<T>(name, body, accessToken);
    } catch (error: any) {
      const status = error?.context?.status ?? error?.status;
      const isUnauthorized = status === 401 || /401|Unauthorized/i.test(String(error?.message ?? ""));

      if (!isUnauthorized) {
        throw error;
      }

      try {
        const refreshedToken = await this.getValidAccessToken(true);
        return await this.invokeAdminFunctionWithToken<T>(name, body, refreshedToken);
      } catch (retryError: any) {
        const retryStatus = retryError?.context?.status ?? retryError?.status;
        if (retryStatus === 401 || /401|Unauthorized/i.test(String(retryError?.message ?? ""))) {
          const details = retryError?.context?.body?.details || retryError?.context?.body?.message || retryError?.message;
          try {
            // Clear any stale local session state to avoid repeated 401 loops.
            await supabase.auth.signOut({ scope: "local" });
          } catch {
          }

          throw new Error(`انتهت صلاحية جلسة تسجيل الدخول. الرجاء تسجيل الدخول مرة أخرى. تفاصيل: ${details ?? "Unauthorized"}`);
        }
        throw retryError;
      }
    }
  }

  private mapUser(row: any): User {
    return {
      id: row.id,
      email: row.email,
      fullName: row.fullName ?? '',
      phone: row.phone ?? '',
      role: row.role,
      assignedLineId: row.assignedLineId,
      assignmentStartDate: row.assignmentStartDate,
      assignmentEndDate: row.assignmentEndDate,
      createdAt: row.createdAt
    };
  }

  async listUsers(): Promise<User[]> {
    const { data, error } = await supabase.from("users_view").select("*");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapUser(row));
  }

  async createUser(payload: { 
    email?: string; 
    fullName: string; 
    role: string; 
    password?: string;
    phone: string;
    assignedLineId?: string;
    assignmentStartDate?: string;
    assignmentEndDate?: string;
  }): Promise<User> {
    const data = await this.invokeAdminFunction<any>("admin-create-user", payload);
    
    // Check if response contains an error field
    if (data?.error) {
      throw new Error(data.error);
    }
    
    if (!data?.success) {
      throw new Error('User creation failed');
    }
    
    return data as User;
  }

  async updateUser(payload: { 
    id: string; 
    email?: string; 
    fullName?: string; 
    role?: string; 
    password?: string;
    phone?: string;
    assignedLineId?: string;
    assignmentStartDate?: string;
    assignmentEndDate?: string;
    joinDate?: string | null;
  }): Promise<User> {
    const data = await this.invokeAdminFunction<User>("admin-update-user", payload);

    if (payload.joinDate) {
      const parsedJoinDate = new Date(payload.joinDate);
      if (!Number.isNaN(parsedJoinDate.getTime())) {
        const { error: joinDateErr } = await supabase
          .from("users")
          .update({ created_at: parsedJoinDate.toISOString() })
          .eq("id", payload.id);

        if (joinDateErr) {
          throw joinDateErr;
        }
      }
    }

    return data as User;
  }

  async deleteUser(id: string): Promise<void> {
    await this.invokeAdminFunction("admin-delete-user", { id });
  }

  async listClientUsers(): Promise<User[]> {
    const { data, error } = await supabase
      .from("users_view")
      .select("*")
      .eq("role", "client");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapUser(row));
  }

  async createContract(payload: {
    userId: string;
    zoneId: string;
    code: string;
    contractTypeId?: string;
    durationMonths?: number;
    addressDetails?: string;
    notes?: string;
    palmInfo?: ContractPalmInfo | null;
    blockNumber?: string;
    street?: string;
    avenue?: string;
    house?: string;
    kuwaitFinderUrl?: string;
    contractUserName?: string;
    contractUserPhone?: string;
    startDate: string;
    endDate: string;
    totalValue: number;
    status?: ContractStatus;
    terms?: ContractTerm[];
  }): Promise<Contract> {
    const { data, error } = await supabase
      .from("contracts")
      .insert({
        user_id: payload.userId,
        block_id: null,
        zone_id: payload.zoneId,
        code: payload.code,
        contract_type_id: payload.contractTypeId ?? null,
        status: payload.status ?? 'active',
        duration_months: payload.durationMonths ?? 12,
        address_details: payload.addressDetails ?? null,
        notes: payload.notes ?? null,
        palm_info: payload.palmInfo ?? null,
        block_number: payload.blockNumber ?? null,
        street: payload.street ?? null,
        avenue: payload.avenue ?? null,
        house: payload.house ?? null,
        kuwait_finder_url: payload.kuwaitFinderUrl ?? null,
        contract_user_name: payload.contractUserName ?? null,
        contract_user_phone: payload.contractUserPhone ?? null,
        start_date: payload.startDate,
        end_date: payload.endDate,
        total_value: payload.totalValue,
        terms: payload.terms ?? []
      })
      .select("*")
      .single();
    
    if (error) throw error;

    return {
      id: data.id,
      code: data.code,
      clientId: data.user_id,
      blockId: data.block_id,
      zoneId: data.zone_id,
      contractTypeId: data.contract_type_id,
      durationMonths: data.duration_months,
      addressDetails: data.address_details,
      notes: data.notes,
      palmInfo: data.palm_info,
      blockNumber: data.block_number,
      street: data.street,
      avenue: data.avenue,
      house: data.house,
      kuwaitFinderUrl: data.kuwait_finder_url,
      contractUserName: data.contract_user_name,
      contractUserPhone: data.contract_user_phone,
      startDate: this.toInputDate(data.start_date),
      endDate: this.toInputDate(data.end_date),
      status: data.status,
      totalValue: data.total_value,
      terms: data.terms,
      contractImageUrl: data.contract_image_url,
      createdAt: data.created_at
    } as Contract;
  }

  async updateContract(payload: {
    id: string;
    userId: string;
    zoneId: string;
    code: string;
    contractTypeId?: string;
    durationMonths?: number;
    addressDetails?: string;
    notes?: string;
    palmInfo?: ContractPalmInfo | null;
    blockNumber?: string;
    street?: string;
    avenue?: string;
    house?: string;
    kuwaitFinderUrl?: string;
    contractUserName?: string;
    contractUserPhone?: string;
    startDate: string;
    endDate: string;
    totalValue: number;
    status: string;
    terms?: ContractTerm[];
  }): Promise<Contract> {
    const { data, error } = await supabase
      .from("contracts")
      .update({
        user_id: payload.userId,
        zone_id: payload.zoneId,
        code: payload.code,
        contract_type_id: payload.contractTypeId ?? null,
        duration_months: payload.durationMonths ?? 12,
        address_details: payload.addressDetails ?? null,
        notes: payload.notes ?? null,
        palm_info: payload.palmInfo ?? null,
        block_number: payload.blockNumber ?? null,
        street: payload.street ?? null,
        avenue: payload.avenue ?? null,
        house: payload.house ?? null,
        kuwait_finder_url: payload.kuwaitFinderUrl ?? null,
        contract_user_name: payload.contractUserName ?? null,
        contract_user_phone: payload.contractUserPhone ?? null,
        start_date: payload.startDate,
        end_date: payload.endDate,
        total_value: payload.totalValue,
        status: payload.status,
        terms: payload.terms
      })
      .eq("id", payload.id)
      .select("*")
      .single();

    if (error) throw error;
    
    return {
      id: data.id,
      code: data.code,
      clientId: data.user_id,
      blockId: data.block_id,
      zoneId: data.zone_id,
      contractTypeId: data.contract_type_id,
      durationMonths: data.duration_months,
      addressDetails: data.address_details,
      notes: data.notes,
      palmInfo: data.palm_info,
      blockNumber: data.block_number,
      street: data.street,
      avenue: data.avenue,
      house: data.house,
      kuwaitFinderUrl: data.kuwait_finder_url,
      contractUserName: data.contract_user_name,
      contractUserPhone: data.contract_user_phone,
      startDate: this.toInputDate(data.start_date),
      endDate: this.toInputDate(data.end_date),
      status: data.status,
      totalValue: data.total_value,
      terms: data.terms,
      contractImageUrl: data.contract_image_url,
      createdAt: data.created_at
    } as Contract;
  }

  async deleteContract(id: string): Promise<void> {
    const { error } = await supabase.from("contracts").delete().eq("id", id);
    if (error) throw error;
  }

  async updateContractStatus(id: string, status: string): Promise<void> {
    const { error } = await supabase.from("contracts").update({ status }).eq("id", id);
    if (error) throw error;
  }

  async listContracts(): Promise<Contract[]> {
    const { data, error } = await supabase.from("contracts_view").select("*").order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => ({
      id: row.id,
      code: row.code,
      clientId: row.user_id,
      blockId: row.block_id,
      zoneId: row.zone_id,
      lineId: row.line_id,
      contractTypeId: row.contract_type_id,
      durationMonths: row.duration_months,
      addressDetails: row.address_details,
      notes: row.notes,
      palmInfo: row.palm_info,
      blockNumber: row.block_number,
      street: row.street,
      avenue: row.avenue,
      house: row.house,
      kuwaitFinderUrl: row.kuwait_finder_url,
      contractUserName: row.contract_user_name,
      contractUserPhone: row.contract_user_phone,
      startDate: this.toInputDate(row.start_date),
      endDate: this.toInputDate(row.end_date),
      status: row.status,
      totalValue: row.total_value,
      terms: row.terms,
      contractImageUrl: row.contract_image_url,
      createdAt: row.created_at
    })) as Contract[];
  }

  async listContractTypes(): Promise<ContractType[]> {
    const { data, error } = await supabase
      .from("contract_types")
      .select("id, name, description, terms, created_at, contracts(count)");
      
    if (error) throw error;
    
    return (data ?? []).map((row: any) => ({
      id: row.id,
      name: row.name,
      description: row.description,
      terms: row.terms || [],
      createdAt: row.created_at,
      contractCount: row.contracts ? row.contracts[0]?.count : 0
    }));
  }

  async createContractType(payload: {
    name: string;
    description?: string | undefined;
    terms?: ContractTerm[];
  }): Promise<ContractType> {
    const { data, error } = await supabase
      .from("contract_types")
      .insert({ name: payload.name, description: payload.description ?? null, terms: payload.terms ?? [] })
      .select("id, name, description, terms, created_at")
      .single();
    if (error) throw error;
    
    return {
      id: data.id,
      name: data.name,
      description: data.description,
      terms: data.terms || [],
      createdAt: data.created_at,
      contractCount: 0
    };
  }

  async updateContractType(payload: {
    id: string;
    name: string;
    description?: string | undefined;
    terms?: ContractTerm[];
  }): Promise<ContractType> {
    const { data, error } = await supabase
      .from("contract_types")
      .update({ name: payload.name, description: payload.description ?? null, terms: payload.terms })
      .eq("id", payload.id)
      .select("id, name, description, terms, created_at")
      .single();
    if (error) throw error;
    
    return {
      id: data.id,
      name: data.name,
      description: data.description,
      terms: data.terms || [],
      createdAt: data.created_at
    };
  }

  async deleteContractType(id: string): Promise<void> {
    const { error } = await supabase.from("contract_types").delete().eq("id", id);
    if (error) throw error;
  }

  async listInvoices(contractId?: string): Promise<Invoice[]> {
    const query = supabase.from("invoices").select("*");
    const { data, error } = contractId ? await query.eq("contract_id", contractId) : await query;
    if (error) throw error;
    return data as Invoice[];
  }

  async updateInvoiceStatus(id: string, status: InvoiceStatus): Promise<Invoice> {
    const { data, error } = await supabase
      .from("invoices")
      .update({ status })
      .eq("id", id)
      .select()
      .single();
    if (error) throw error;
    return data as Invoice;
  }

  async listSupervisors(): Promise<User[]> {
    const { data, error } = await supabase
      .from("users_view")
      .select("*")
      .eq("role", "supervisor");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapUser(row));
  }

  async assignLineToSupervisor(payload: {
    supervisorId: string;
    lineId: string;
    startDate?: string | null;
    endDate?: string | null;
  }): Promise<void> {
    const { error } = await supabase
      .from("users")
      .update({
        assigned_line_id: payload.lineId,
        assignment_start_date: payload.startDate ?? null,
        assignment_end_date: payload.endDate ?? null
      })
      .eq("id", payload.supervisorId);
    if (error) throw error;
  }

  async removeLineAssignment(supervisorId: string): Promise<void> {
    const { error } = await supabase
      .from("users")
      .update({
        assigned_line_id: null,
        assignment_start_date: null,
        assignment_end_date: null
      })
      .eq("id", supervisorId);
    if (error) throw error;
  }

  async getContractsByLineId(lineId: string): Promise<Contract[]> {
    const { data, error } = await supabase
      .from("contracts_view")
      .select("*")
      .eq("line_id", lineId);
    if (error) throw error;
    return (data ?? []).map((row: any) => ({
      id: row.id,
      code: row.code,
      clientId: row.user_id,
      blockId: row.block_id,
      zoneId: row.zone_id,
      lineId: row.line_id,
      contractTypeId: row.contract_type_id,
      durationMonths: row.duration_months,
      addressDetails: row.address_details,
      notes: row.notes,
      palmInfo: row.palm_info,
      startDate: this.toInputDate(row.start_date),
      endDate: this.toInputDate(row.end_date),
      status: row.status,
      totalValue: row.total_value,
      terms: row.terms,
      contractImageUrl: row.contract_image_url,
      createdAt: row.created_at
    })) as Contract[];
  }

  async deleteContractImage(contractId: string, imageUrl: string): Promise<void> {
    const filePath = imageUrl.split(`/${BUCKET}/`)[1];
    if (filePath) {
      await supabase.storage.from(BUCKET).remove([filePath]);
    }
    const { error } = await supabase
      .from('contracts')
      .update({ contract_image_url: null })
      .eq('id', contractId);
    if (error) throw error;
  }

  async uploadContractImage(contractId: string, file: Blob, fileName: string): Promise<string> {
    const filePath = `${contractId}/${Date.now()}_${fileName}`;
    const contentType = file.type || 'image/jpeg';

    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(filePath, file, {
        contentType,
        upsert: true
      });
    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from(BUCKET)
      .getPublicUrl(filePath);

    const publicUrl = urlData.publicUrl;

    const { error: updateError } = await supabase
      .from('contracts')
      .update({ contract_image_url: publicUrl })
      .eq('id', contractId);
    if (updateError) throw updateError;

    return publicUrl;
  }


  private mapVisit(row: any): Visit {
    return {
      id: row.id,
      contractId: row.contract_id,
      title: row.title,
      visitDate: this.toInputDate(row.visit_date) ?? "",
      notes: row.notes,
      status: row.status,
      summary: row.summary,
      gpsLat: row.gps_lat,
      gpsLng: row.gps_lng,
      completedAt: row.completed_at,
      createdAt: row.created_at
    };
  }

  async listVisits(contractId: string): Promise<Visit[]> {
    const { data, error } = await supabase
      .from("visits")
      .select("*")
      .eq("contract_id", contractId)
      .order("visit_date", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapVisit(row));
  }

  async listAllVisits(contractIds: string[]): Promise<Visit[]> {
    if (contractIds.length === 0) return [];
    const { data, error } = await supabase
      .from("visits")
      .select("*")
      .in("contract_id", contractIds)
      .order("visit_date", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapVisit(row));
  }

  async createVisit(payload: {
    contractId: string;
    visitDate?: string;
    notes?: string;
    title?: string;
  }): Promise<Visit> {
    const visitDateValue = payload.visitDate?.trim() ? payload.visitDate : null;
    const { data, error } = await supabase
      .from("visits")
      .insert({
        contract_id: payload.contractId,
        visit_date: visitDateValue,
        notes: payload.notes ?? null,
        title: payload.title ?? null,
        status: "planned"
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapVisit(data);
  }

  async updateVisit(payload: {
    id: string;
    title?: string | null;
    visitDate?: string;
    notes?: string | null;
    status?: string;
  }): Promise<Visit> {
    const updates: Record<string, any> = {};
    if (payload.title !== undefined) updates.title = payload.title;
    if (payload.visitDate !== undefined) {
      updates.visit_date = payload.visitDate.trim() ? payload.visitDate : null;
    }
    if (payload.notes !== undefined) updates.notes = payload.notes;
    if ((payload as any).supervisorReport !== undefined) updates.supervisor_report = (payload as any).supervisorReport;
    if (payload.status !== undefined) updates.status = payload.status;

    const { data, error } = await supabase
      .from("visits")
      .update(updates)
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapVisit(data);
  }

  async updateVisitStatus(visitId: string, status: string): Promise<Visit> {
    const { data, error } = await supabase
      .from("visits")
      .update({ status })
      .eq("id", visitId)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapVisit(data);
  }

  async deleteVisit(visitId: string): Promise<void> {
    const { error } = await supabase
      .from("visits")
      .delete()
      .eq("id", visitId);
    if (error) throw error;
  }


  private mapTask(row: any): ContractTask {
    return {
      id: row.id,
      contractId: row.contract_id,
      visitId: row.visit_id,
      title: row.title,
      month: row.month,
      status: row.status,
      createdAt: row.created_at
    };
  }

  async listVisitTasks(visitId: string): Promise<ContractTask[]> {
    const { data, error } = await supabase
      .from("contract_tasks")
      .select("*")
      .eq("visit_id", visitId)
      .order("month", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapTask(row));
  }

  async listAllVisitTasks(visitIds: string[]): Promise<ContractTask[]> {
    if (visitIds.length === 0) return [];
    const { data, error } = await supabase
      .from("contract_tasks")
      .select("*")
      .in("visit_id", visitIds)
      .order("month", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapTask(row));
  }

  async createContractTask(payload: {
    visitId: string;
    contractId: string;
    title: string;
    month: number;
  }): Promise<ContractTask> {
    const { data, error } = await supabase
      .from("contract_tasks")
      .insert({
        visit_id: payload.visitId,
        contract_id: payload.contractId,
        title: payload.title,
        month: payload.month,
        status: "pending"
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapTask(data);
  }

  async updateContractTaskStatus(taskId: string, status: string): Promise<ContractTask> {
    const { data, error } = await supabase
      .from("contract_tasks")
      .update({ status })
      .eq("id", taskId)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapTask(data);
  }

  async deleteContractTask(taskId: string): Promise<void> {
    const { error } = await supabase
      .from("contract_tasks")
      .delete()
      .eq("id", taskId);
    if (error) throw error;
  }

  async listTaskExecutions(taskIds: string[]): Promise<any[]> {
    if (taskIds.length === 0) return [];
    const { data, error } = await supabase
      .from("task_executions")
      .select("*")
      .in("task_id", taskIds)
      .order("created_at", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => ({
      id: row.id,
      taskId: row.task_id,
      supervisorId: row.supervisor_id,
      visitId: row.visit_id,
      notes: row.notes,
      status: row.status,
      gpsLat: row.gps_lat,
      gpsLng: row.gps_lng,
      createdAt: row.created_at,
    }));
  }

  async listExecutionPhotos(executionIds: string[]): Promise<any[]> {
    if (executionIds.length === 0) return [];
    const { data, error } = await supabase
      .from("task_photos")
      .select("*")
      .in("execution_id", executionIds)
      .order("created_at", { ascending: true });
    if (error) throw error;

    return await Promise.all(
      (data ?? []).map(async (row: any) => {
        const photoUrl = await this.resolveTaskPhotoUrl(row.photo_path);
        return {
          id: row.id,
          executionId: row.execution_id,
          photoPath: row.photo_path,
          photoUrl,
          photoType: row.photo_type,
          createdAt: row.created_at,
        };
      })
    );
  }

  async listVisitPhotos(visitId: string): Promise<any[]> {
    const { data, error } = await supabase
      .from("visit_photos")
      .select("*")
      .eq("visit_id", visitId)
      .order("created_at", { ascending: true });
    if (error) throw error;

    return await Promise.all(
      (data ?? []).map(async (row: any) => {
        const photoUrl = await this.resolveTaskPhotoUrl(row.photo_path);
        return {
          id: row.id,
          visitId: row.visit_id,
          photoPath: row.photo_path,
          photoUrl,
          createdAt: row.created_at,
        };
      })
    );
  }

  async listContractComments(contractId: string, visitId?: string): Promise<any[]> {
    let query = supabase
      .from("client_comments")
      .select("id, contract_id, visit_id, client_id, comment, attachment_path, created_at, author_name, author_user_id")
      .eq("contract_id", contractId)
      .order("created_at", { ascending: false });

    if (visitId) {
      query = query.eq("visit_id", visitId);
    }

    const { data, error } = await query;
    if (error) throw error;
    return await Promise.all(
      (data ?? []).map(async (row: any) => {
        const attachmentUrl = await this.resolveTaskPhotoUrl(row.attachment_path);
        return {
          id: row.id,
          contractId: row.contract_id,
          visitId: row.visit_id,
          clientId: row.client_id,
          comment: row.comment,
          attachmentPath: attachmentUrl,
          authorName: row.author_name,
          authorUserId: row.author_user_id,
          createdAt: row.created_at,
        };
      })
    );
  }

  private mapPayment(row: any): ContractPayment {
    return {
      id: row.id,
      contractId: row.contract_id,
      amount: Number(row.amount),
      paymentMethod: row.payment_method as PaymentMethod,
      transferImageUrl: row.transfer_image_url,
      notes: row.notes,
      paymentDate: row.payment_date,
      createdAt: row.created_at,
      dueDate: row.due_date ?? null,
      paymentGatewayUrl: row.payment_gateway_url ?? null,
      paymentGatewayOrderId: row.payment_gateway_order_id ?? null,
      gatewayStatus: row.gateway_status ?? null,
      gatewayFeeAmount: row.gateway_fee_amount != null ? Number(row.gateway_fee_amount) : null,
      receiptUrl: row.receipt_url ?? null,
    };
  }

  async listContractPayments(contractId: string): Promise<ContractPayment[]> {
    const { data, error } = await supabase
      .from("contract_payments")
      .select("*")
      .eq("contract_id", contractId)
      .order("payment_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapPayment(row));
  }

  async listAllContractPayments(): Promise<ContractPayment[]> {
    const { data, error } = await supabase
      .from("contract_payments")
      .select("*")
      // Include: manual payments (gateway_status IS NULL, no due_date = old completed)
      //          + gateway-confirmed payments
      // Exclude: pending/failed/cancelled gateway payments (not yet received)
      .or("gateway_status.is.null,gateway_status.eq.paid")
      .order("payment_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapPayment(row));
  }

  async listOverdueContractPayments(): Promise<ContractPayment[]> {
    const todayStr = new Date().toISOString().slice(0, 10);
    const { data, error } = await supabase
      .from("contract_payments")
      .select("*")
      .not("due_date", "is", null)
      .lt("due_date", todayStr)
      // Not yet paid: covers manual scheduled entries (gateway_status is null)
      // and gateway payments still pending/failed/cancelled.
      .or("gateway_status.is.null,gateway_status.neq.paid");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapPayment(row));
  }

  async listScheduledContractPayments(contractId: string): Promise<ContractPayment[]> {
    const { data, error } = await supabase
      .from("contract_payments")
      .select("*")
      .eq("contract_id", contractId)
      .order("due_date", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapPayment(row));
  }

  async createScheduledContractPayment(payload: {
    contractId: string;
    amount: number;
    dueDate: string;
    paymentMethod: PaymentMethod;
    notes?: string | null;
  }): Promise<ContractPayment> {
    const { data, error } = await supabase
      .from("contract_payments")
      .insert({
        contract_id:  payload.contractId,
        amount:       payload.amount,
        due_date:     payload.dueDate,
        notes:        payload.notes ?? null,
        payment_method: payload.paymentMethod,
        payment_date: payload.dueDate,
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapPayment(data);
  }

  async updateScheduledPaymentMethod(id: string, paymentMethod: PaymentMethod): Promise<ContractPayment> {
    const { data, error } = await supabase
      .from("contract_payments")
      .update({ payment_method: paymentMethod })
      .eq("id", id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapPayment(data);
  }

  async createContractPayment(payload: {
    contractId: string;
    amount: number;
    paymentMethod: PaymentMethod;
    notes?: string;
    paymentDate: string;
  }): Promise<ContractPayment> {
    const gatewayFeeAmount = payload.paymentMethod === "gateway"
      ? await this.computeGatewayFeeAmount()
      : null;
    const { data, error } = await supabase
      .from("contract_payments")
      .insert({
        contract_id: payload.contractId,
        amount: payload.amount,
        payment_method: payload.paymentMethod,
        notes: payload.notes ?? null,
        payment_date: payload.paymentDate,
        gateway_fee_amount: gatewayFeeAmount,
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapPayment(data);
  }

  async updateContractPayment(payload: {
    id: string;
    amount: number;
    paymentMethod: PaymentMethod;
    notes?: string | null;
    paymentDate: string;
  }): Promise<ContractPayment> {
    const gatewayFeeAmount = payload.paymentMethod === "gateway"
      ? await this.computeGatewayFeeAmount()
      : null;
    const { data, error } = await supabase
      .from("contract_payments")
      .update({
        amount: payload.amount,
        payment_method: payload.paymentMethod,
        notes: payload.notes ?? null,
        payment_date: payload.paymentDate,
        gateway_fee_amount: gatewayFeeAmount,
      })
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapPayment(data);
  }

  async markContractPaymentPaid(payload: {
    id: string;
    paymentMethod: PaymentMethod;
    paymentDate: string;
    notes?: string | null;
  }): Promise<ContractPayment> {
    const { data, error } = await supabase
      .from("contract_payments")
      .update({
        payment_method: payload.paymentMethod,
        payment_date: payload.paymentDate,
        notes: payload.notes ?? null,
        due_date: null,
        gateway_status: null,
        payment_gateway_url: null,
        payment_gateway_order_id: null,
      })
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapPayment(data);
  }

  async uploadPaymentImage(paymentId: string, file: Blob, fileName: string): Promise<string> {
    const filePath = `${paymentId}/${Date.now()}_${fileName}`;
    const contentType = file.type || 'image/jpeg';

    const { error: uploadError } = await supabase.storage
      .from(PAYMENT_BUCKET)
      .upload(filePath, file, { contentType, upsert: true });
    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage
      .from(PAYMENT_BUCKET)
      .getPublicUrl(filePath);
    const publicUrl = urlData.publicUrl;

    const { error: updateError } = await supabase
      .from('contract_payments')
      .update({ transfer_image_url: publicUrl })
      .eq('id', paymentId);
    if (updateError) throw updateError;

    return publicUrl;
  }

  async deleteContractPayment(id: string): Promise<void> {
    const { error } = await supabase
      .from("contract_payments")
      .delete()
      .eq("id", id);
    if (error) throw error;
  }

  private mapStandaloneTask(row: any): StandaloneTask {
    return {
      id: row.id,
      title: row.title,
      description: row.description ?? null,
      address: row.address ?? null,
      clientId: row.client_id ?? null,
      clientName: row.client_name ?? null,
      clientPhone: row.client_phone ?? null,
      supervisorId: row.supervisor_id ?? null,
      taskDate: row.task_date,
      contractId: row.contract_id ?? null,
      lineId: row.line_id ?? null,
      zoneId: row.zone_id ?? null,
      cost: row.cost != null ? Number(row.cost) : null,
      notes: row.notes ?? null,
      supervisorReport: row.supervisor_report ?? null,
      status: row.status,
      paymentStatus: row.payment_status ?? 'unpaid',
      paymentMethod: row.payment_method ?? null,
      createdAt: row.created_at,
      updatedAt: row.updated_at ?? null,
      deletedAt: row.deleted_at ?? null,
    } as StandaloneTask;
  }

  async listStandaloneTasks(): Promise<StandaloneTask[]> {
    const { data, error } = await supabase
      .from("standalone_tasks")
      .select("*")
      .order("task_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapStandaloneTask(row));
  }

  async listStandaloneTasksByContract(contractId: string): Promise<StandaloneTask[]> {
    const { data, error } = await supabase
      .from("standalone_tasks")
      .select("*")
      .eq("contract_id", contractId)
      .order("task_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapStandaloneTask(row));
  }

  async createStandaloneTask(payload: {
    title: string;
    description?: string | null;
    address?: string | null;
    clientId?: string | null;
    clientName?: string | null;
    clientPhone?: string | null;
    supervisorId?: string | null;
    taskDate: string;
    notes?: string | null;
    status?: string;
    contractId?: string | null;
    lineId?: string | null;
    zoneId?: string | null;
    cost?: number | null;
    paymentStatus?: string;
    paymentMethod?: string | null;
  }): Promise<StandaloneTask> {
    const { data, error } = await supabase
      .from("standalone_tasks")
      .insert({
        title: payload.title,
        description: payload.description ?? null,
        address: payload.address ?? null,
        client_id: payload.clientId ?? null,
        client_name: payload.clientName ?? null,
        client_phone: payload.clientPhone ?? null,
        supervisor_id: payload.supervisorId ?? null,
        task_date: payload.taskDate,
        notes: payload.notes ?? null,
        status: payload.status ?? 'pending',
        contract_id: payload.contractId ?? null,
        line_id: payload.lineId ?? null,
        zone_id: payload.zoneId ?? null,
        cost: payload.cost ?? null,
        payment_status: payload.paymentStatus ?? 'unpaid',
        payment_method: payload.paymentMethod ?? null,
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapStandaloneTask(data);
  }

  async updateStandaloneTask(id: string, payload: { title?: string; description?: string | null; address?: string | null; clientId?: string | null; clientName?: string | null; clientPhone?: string | null; supervisorId?: string | null; taskDate?: string; notes?: string | null; status?: string; contractId?: string | null; lineId?: string | null; zoneId?: string | null; cost?: number | null; paymentStatus?: string; paymentMethod?: string | null }): Promise<StandaloneTask> {
    if (!id || id.trim() === '') {
      throw new Error('Invalid standalone task id');
    }
    const updates: any = {};
    if (payload.title !== undefined) updates.title = payload.title;
    if (payload.description !== undefined) updates.description = payload.description;
    if (payload.address !== undefined) updates.address = payload.address;
    if (payload.clientId !== undefined) updates.client_id = payload.clientId;
    if (payload.clientName !== undefined) updates.client_name = payload.clientName;
    if (payload.clientPhone !== undefined) updates.client_phone = payload.clientPhone;
    if (payload.supervisorId !== undefined) updates.supervisor_id = payload.supervisorId;
    if (payload.taskDate !== undefined) updates.task_date = payload.taskDate;
    if (payload.notes !== undefined) updates.notes = payload.notes;
    if ((payload as any).supervisorReport !== undefined) updates.supervisor_report = (payload as any).supervisorReport;
    if (payload.status !== undefined) updates.status = payload.status;
    if (payload.contractId !== undefined) updates.contract_id = payload.contractId;
    if ((payload as any).lineId !== undefined) updates.line_id = (payload as any).lineId;
    if ((payload as any).zoneId !== undefined) updates.zone_id = (payload as any).zoneId;
    if (payload.cost !== undefined) updates.cost = payload.cost;
    if (payload.paymentStatus !== undefined) updates.payment_status = payload.paymentStatus;
    if (payload.paymentMethod !== undefined) updates.payment_method = payload.paymentMethod;

    const { data, error } = await supabase
      .from("standalone_tasks")
      .update(updates)
      .eq("id", id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapStandaloneTask(data);
  }

  async updateStandaloneTaskStatus(id: string, status: string): Promise<StandaloneTask> {
    if (!id || id.trim() === '') {
      throw new Error('Invalid standalone task id');
    }
    const { data, error } = await supabase
      .from("standalone_tasks")
      .update({ status })
      .eq("id", id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapStandaloneTask(data);
  }

  async deleteStandaloneTask(id: string): Promise<void> {
    if (!id || id.trim() === '') {
      throw new Error('Invalid standalone task id');
    }
    const { error } = await supabase
      .from("standalone_tasks")
      .delete()
      .eq("id", id);
    if (error) throw error;
  }

  private mapStandaloneTaskPayment(row: any): StandaloneTaskPayment {
    return {
      id: row.id,
      taskId: row.task_id,
      amount: Number(row.amount),
      paymentMethod: row.payment_method as PaymentMethod,
      notes: row.notes,
      paymentDate: row.payment_date,
      createdAt: row.created_at,
      dueDate: row.due_date ?? null,
      paymentGatewayUrl: row.payment_gateway_url ?? null,
      paymentGatewayOrderId: row.payment_gateway_order_id ?? null,
      gatewayStatus: row.gateway_status ?? null,
      gatewayFeeAmount: row.gateway_fee_amount != null ? Number(row.gateway_fee_amount) : null,
      receiptUrl: row.receipt_url ?? null,
    };
  }

  async listAllStandaloneTaskPayments(): Promise<StandaloneTaskPayment[]> {
    const { data, error } = await supabase
      .from("standalone_task_payments")
      .select("*")
      .or("gateway_status.is.null,gateway_status.eq.paid")
      .order("payment_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapStandaloneTaskPayment(row));
  }

  async listOverdueStandaloneTaskPayments(): Promise<StandaloneTaskPayment[]> {
    const todayStr = new Date().toISOString().slice(0, 10);
    const { data, error } = await supabase
      .from("standalone_task_payments")
      .select("*")
      .not("due_date", "is", null)
      .lt("due_date", todayStr)
      .or("gateway_status.is.null,gateway_status.neq.paid");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapStandaloneTaskPayment(row));
  }

  async createStandaloneTaskPayment(payload: {
    taskId: string;
    amount: number;
    paymentMethod: PaymentMethod;
    notes?: string | null;
    paymentDate: string;
  }): Promise<StandaloneTaskPayment> {
    const gatewayFeeAmount = payload.paymentMethod === "gateway"
      ? await this.computeGatewayFeeAmount()
      : null;
    const { data, error } = await supabase
      .from("standalone_task_payments")
      .insert({
        task_id: payload.taskId,
        amount: payload.amount,
        payment_method: payload.paymentMethod,
        notes: payload.notes ?? null,
        payment_date: payload.paymentDate,
        gateway_fee_amount: gatewayFeeAmount,
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapStandaloneTaskPayment(data);
  }

  async updateStandaloneTaskPayment(payload: {
    id: string;
    amount: number;
    paymentMethod: PaymentMethod;
    notes?: string | null;
    paymentDate: string;
  }): Promise<StandaloneTaskPayment> {
    const gatewayFeeAmount = payload.paymentMethod === "gateway"
      ? await this.computeGatewayFeeAmount()
      : null;
    const { data, error } = await supabase
      .from("standalone_task_payments")
      .update({
        amount: payload.amount,
        payment_method: payload.paymentMethod,
        notes: payload.notes ?? null,
        payment_date: payload.paymentDate,
        gateway_fee_amount: gatewayFeeAmount,
      })
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapStandaloneTaskPayment(data);
  }

  async deleteStandaloneTaskPayment(id: string): Promise<void> {
    const { error } = await supabase
      .from("standalone_task_payments")
      .delete()
      .eq("id", id);
    if (error) throw error;
  }

  private mapExpenseSection(row: any): ExpenseSection {
    return {
      id: row.id,
      name: row.name,
      type: row.type,
      kind: row.kind ?? 'expense',
      sortOrder: row.sort_order,
      isSystem: row.is_system,
      createdAt: row.created_at,
    };
  }

  private mapExpenseLineItem(row: any): ExpenseLineItem {
    return {
      id: row.id,
      sectionId: row.section_id,
      name: row.name,
      sortOrder: row.sort_order,
      createdAt: row.created_at,
    };
  }

  async listExpenseSections(): Promise<ExpenseSection[]> {
    const { data, error } = await supabase
      .from("expense_sections")
      .select("*")
      .order("sort_order", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapExpenseSection(row));
  }

  async createExpenseSection(payload: { name: string; kind?: 'expense' | 'cost' }): Promise<ExpenseSection> {
    const { data: existing } = await supabase
      .from("expense_sections")
      .select("sort_order")
      .order("sort_order", { ascending: false })
      .limit(1)
      .single();
    const nextOrder = ((existing as any)?.sort_order ?? 0) + 1;
    const { data, error } = await supabase
      .from("expense_sections")
      .insert({ name: payload.name, type: "general", sort_order: nextOrder, is_system: false, kind: payload.kind ?? 'expense' })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapExpenseSection(data);
  }

  async updateExpenseSection(payload: { id: string; name: string; sortOrder?: number }): Promise<ExpenseSection> {
    const updates: any = { name: payload.name };
    if (payload.sortOrder !== undefined) updates.sort_order = payload.sortOrder;
    const { data, error } = await supabase
      .from("expense_sections")
      .update(updates)
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapExpenseSection(data);
  }

  async deleteExpenseSection(id: string): Promise<void> {
    const { error } = await supabase.from("expense_sections").delete().eq("id", id);
    if (error) throw error;
  }

  async listExpenseLineItems(): Promise<ExpenseLineItem[]> {
    const { data, error } = await supabase
      .from("expense_line_items")
      .select("*")
      .order("sort_order", { ascending: true });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapExpenseLineItem(row));
  }

  async createExpenseLineItem(payload: { sectionId: string; name: string }): Promise<ExpenseLineItem> {
    const { data: existing } = await supabase
      .from("expense_line_items")
      .select("sort_order")
      .eq("section_id", payload.sectionId)
      .order("sort_order", { ascending: false })
      .limit(1)
      .single();
    const nextOrder = ((existing as any)?.sort_order ?? 0) + 1;
    const { data, error } = await supabase
      .from("expense_line_items")
      .insert({ section_id: payload.sectionId, name: payload.name, sort_order: nextOrder })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapExpenseLineItem(data);
  }

  async updateExpenseLineItem(payload: { id: string; name: string; sortOrder?: number }): Promise<ExpenseLineItem> {
    const updates: any = { name: payload.name };
    if (payload.sortOrder !== undefined) updates.sort_order = payload.sortOrder;
    const { data, error } = await supabase
      .from("expense_line_items")
      .update(updates)
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapExpenseLineItem(data);
  }

  async deleteExpenseLineItem(id: string): Promise<void> {
    const { error } = await supabase.from("expense_line_items").delete().eq("id", id);
    if (error) throw error;
  }

  private mapCompanyExpense(row: any): CompanyExpense {
    return {
      id: row.id,
      category: (row.category ?? null) as CompanyExpenseCategory | null,
      sectionId: row.section_id ?? null,
      lineItemId: row.line_item_id ?? null,
      name: row.name,
      description: row.description ?? null,
      amount: Number(row.amount),
      expenseDate: row.expense_date,
      note: row.note ?? null,
      workerId: row.worker_id ?? null,
      paymentMethod: (row.payment_method ?? null) as PaymentMethod | null,
      createdAt: row.created_at,
    };
  }

  async listCompanyExpenses(): Promise<CompanyExpense[]> {
    const { data, error } = await supabase
      .from("company_expenses")
      .select("*")
      .order("expense_date", { ascending: false });
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapCompanyExpense(row));
  }

  async createCompanyExpense(payload: {
    sectionId: string;
    category?: CompanyExpenseCategory | null;
    lineItemId?: string | null;
    name: string;
    description?: string | null;
    amount: number;
    expenseDate: string;
    note?: string | null;
    workerId?: string | null;
    paymentMethod?: PaymentMethod | null;
  }): Promise<CompanyExpense> {
    const { data, error } = await supabase
      .from("company_expenses")
      .insert({
        section_id: payload.sectionId,
        category: payload.category ?? null,
        line_item_id: payload.lineItemId ?? null,
        name: payload.name,
        description: payload.description ?? null,
        amount: payload.amount,
        expense_date: payload.expenseDate,
        note: payload.note ?? null,
        worker_id: payload.workerId ?? null,
        payment_method: payload.paymentMethod ?? null,
      })
      .select("*")
      .single();
    if (error) throw error;
    return this.mapCompanyExpense(data);
  }

  async updateCompanyExpense(payload: {
    id: string;
    lineItemId?: string | null;
    name: string;
    description?: string | null;
    amount: number;
    expenseDate: string;
    note?: string | null;
    workerId?: string | null;
    paymentMethod?: PaymentMethod | null;
  }): Promise<CompanyExpense> {
    const { data, error } = await supabase
      .from("company_expenses")
      .update({
        line_item_id: payload.lineItemId ?? null,
        name: payload.name,
        description: payload.description ?? null,
        amount: payload.amount,
        expense_date: payload.expenseDate,
        note: payload.note ?? null,
        worker_id: payload.workerId ?? null,
        payment_method: payload.paymentMethod ?? null,
      })
      .eq("id", payload.id)
      .select("*")
      .single();
    if (error) throw error;
    return this.mapCompanyExpense(data);
  }

  async deleteCompanyExpense(id: string): Promise<void> {
    const { error } = await supabase.from("company_expenses").delete().eq("id", id);
    if (error) throw error;
  }

  async bulkPaySalaries(month: string, paymentMethod: PaymentMethod): Promise<CompanyExpense[]> {
    const { data: workers, error: workersError } = await supabase.from("workers").select("*");
    if (workersError) throw workersError;

    const { data: sectionRow } = await supabase
      .from("expense_sections")
      .select("id")
      .eq("type", "salary")
      .single();
    const salarySectionId: string | null = (sectionRow as any)?.id ?? null;

    const monthStart = `${month}-01`;
    const { data: existing, error: existingError } = await supabase
      .from("company_expenses")
      .select("worker_id")
      .eq("category", "salary")
      .gte("expense_date", monthStart)
      .lt("expense_date", this.nextMonthStart(month));
    if (existingError) throw existingError;

    const paidWorkerIds = new Set((existing ?? []).map((row: any) => row.worker_id).filter(Boolean));
    const toInsert = (workers ?? [])
      .filter((worker: any) => !paidWorkerIds.has(worker.id))
      .map((worker: any) => ({
        section_id: salarySectionId,
        category: "salary" as CompanyExpenseCategory,
        name: worker.name,
        description: null,
        amount: worker.salary,
        expense_date: monthStart,
        note: null,
        worker_id: worker.id,
        payment_method: paymentMethod,
      }));

    if (toInsert.length === 0) return [];

    const { data, error } = await supabase.from("company_expenses").insert(toInsert).select("*");
    if (error) throw error;
    return (data ?? []).map((row: any) => this.mapCompanyExpense(row));
  }

  async getUpaymentsFeeAmount(): Promise<number> {
    const { data, error } = await supabase.rpc("get_upayments_fee_amount");
    if (error) throw error;
    return Number(data);
  }

  async updateUpaymentsFeeAmount(amount: number): Promise<void> {
    const { error } = await supabase.rpc("set_upayments_fee_amount", { p_amount: amount });
    if (error) throw error;
  }

  async getUpaymentsSandboxMode(): Promise<boolean> {
    const { data, error } = await supabase.rpc("get_upayments_sandbox_mode");
    if (error) throw error;
    return Boolean(data);
  }

  async updateUpaymentsSandboxMode(sandbox: boolean): Promise<void> {
    const { error } = await supabase.rpc("set_upayments_sandbox_mode", { p_sandbox: sandbox });
    if (error) throw error;
  }

  async hasTenantPaymentCredentials(): Promise<boolean> {
    const { data, error } = await supabase.rpc("has_tenant_payment_credentials");
    if (error) throw error;
    return Boolean(data);
  }

  async setTenantPaymentCredentials(input: {
    apiToken: string;
    nwlToken: string;
    gatewaySrc: string;
    webhookSecret: string;
    returnUrl: string;
    cancelUrl: string;
  }): Promise<void> {
    const { error } = await supabase.rpc("set_tenant_payment_credentials", {
      p_api_token: input.apiToken,
      p_nwl_token: input.nwlToken,
      p_gateway_src: input.gatewaySrc,
      p_webhook_secret: input.webhookSecret,
      p_return_url: input.returnUrl,
      p_cancel_url: input.cancelUrl,
    });
    if (error) throw error;
  }

  private nextMonthStart(month: string): string {
    const parts = month.split("-").map(Number);
    const year = parts[0] ?? 0;
    const monthNum = parts[1] ?? 1;
    const next = monthNum === 12 ? `${year + 1}-01-01` : `${year}-${String(monthNum + 1).padStart(2, "0")}-01`;
    return next;
  }
}
