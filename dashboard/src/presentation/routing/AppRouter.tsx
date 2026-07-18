import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "@presentation/components/Layout";
import { LoginPage } from "@presentation/screens/LoginPage";
import { AdminDashboard } from "@presentation/screens/admin/AdminDashboard";
import { ClientsPage } from "@presentation/screens/admin/ClientsPage";
import { LinesPage } from "@presentation/screens/admin/LinesPage";
import { ContractsPage } from "@presentation/screens/admin/ContractsPage";
import { AdminUsersPage } from "@presentation/screens/admin/AdminUsersPage";
import { FleetPage } from "@presentation/screens/admin/FleetPage";
import { PhonesPage } from "@presentation/screens/admin/PhonesPage";
import { WorkersPage } from "@presentation/screens/admin/WorkersPage";
import { ClientDetailsPage } from "@presentation/screens/admin/ClientDetailsPage";
import { RequireAuth } from "@presentation/routing/RequireAuth";
import { ContractTypesPage } from "@presentation/screens/admin/ContractTypesPage";
import { SupervisorsPage } from "@presentation/screens/admin/SupervisorsPage";
import { CompanyAccountsPage } from "@presentation/screens/admin/CompanyAccountsPage";
import { ContactRequestsPage } from "@presentation/screens/admin/ContactRequestsPage";
import { ContractStatusRequestsPage } from "@presentation/screens/admin/ContractStatusRequestsPage";
import { StandaloneTasksPage } from "@presentation/screens/admin/StandaloneTasksPage";
import { StandaloneTaskDetailsPage } from "@presentation/screens/admin/StandaloneTaskDetailsPage";
import { VisitNotificationPage } from "@presentation/screens/admin/VisitNotificationPage";

export const AppRouter = () => {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/admin"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <AdminDashboard />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/lines-only"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <LinesPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/contract-types"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ContractTypesPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/contracts"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ContractsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/users"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <AdminUsersPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/supervisors"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <SupervisorsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/fleet"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <FleetPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/phones"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <PhonesPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/workers"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <WorkersPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/company-accounts"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <CompanyAccountsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/contact-requests"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ContactRequestsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/contract-status-requests"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ContractStatusRequestsPage />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/admin/visit-notification"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <VisitNotificationPage />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/admin/tasks"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <StandaloneTasksPage />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/admin/tasks/:taskId"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <StandaloneTaskDetailsPage viewOnly={true} />
            </Layout>
          </RequireAuth>
        }
      />

      <Route
        path="/admin/tasks/:taskId/edit"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <StandaloneTaskDetailsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/clients"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ClientsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route
        path="/admin/clients/:clientId"
        element={
          <RequireAuth allowedRoles={["admin"]}>
            <Layout>
              <ClientDetailsPage />
            </Layout>
          </RequireAuth>
        }
      />
      <Route path="*" element={<Navigate to="/login" replace />} />
    </Routes>
  );
};
