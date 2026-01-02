# Testing Checklist for Parent Dashboard & Security Rules

## Changes Made
1. Added Firestore security rules for `invoices`, `payments`, and `payment_methods` collections
2. Connected `ParentDashboard` widget to `ParentDashboardScreen`
3. Added Scaffold wrapper to `ParentDashboardScreen` for proper navigation context

## Testing Checklist

### 1. Firestore Security Rules Validation

#### Syntax Validation
- [ ] Deploy rules to Firebase and verify no syntax errors
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] Verify rules compile successfully
- [ ] Check Firebase Console for rule validation warnings

#### Invoices Collection Rules
- [ ] Parent can read their own invoices (parent_id matches auth.uid)
- [ ] Parent CANNOT read other parents' invoices
- [ ] Admin can read all invoices
- [ ] Only admins can create invoices
- [ ] Parent can update only `payment_method_id` field of their own invoices
- [ ] Parent CANNOT update other fields of their invoices
- [ ] Parent CANNOT update other parents' invoices
- [ ] Only admins can delete invoices

#### Payments Collection Rules
- [ ] Parent can read their own payments (parent_id matches auth.uid)
- [ ] Parent CANNOT read other parents' payments
- [ ] Admin can read all payments
- [ ] Client-side create is BLOCKED (returns permission denied)
- [ ] Client-side update is BLOCKED (returns permission denied)
- [ ] Only Cloud Functions can create/update payments (server-side)
- [ ] Only admins can delete payments

#### Payment Methods Subcollection Rules
- [ ] User can read their own payment methods (`users/{userId}/payment_methods/{methodId}`)
- [ ] User can write (create/update/delete) their own payment methods
- [ ] User CANNOT access other users' payment methods
- [ ] Admin CANNOT access user payment methods (handled by user ownership check)

### 2. Parent Dashboard Connection

#### Routing & Navigation
- [ ] Login as parent user with role='parent'
- [ ] Verify `RoleBasedDashboard` routes to `ParentDashboard`
- [ ] Verify `ParentDashboard` displays `ParentDashboardScreen`
- [ ] Verify `ParentDashboardScreen` is wrapped with `_DashboardVersionOverlay`
- [ ] Verify version pill appears in bottom-right corner

#### UI Rendering
- [ ] Dashboard loads without errors
- [ ] Welcome message displays (shows parent's first name if available)
- [ ] Financial summary card displays
- [ ] Children list displays
- [ ] Recent invoices section displays
- [ ] Recent payments section displays
- [ ] All navigation buttons work (Invoices, Payments)
- [ ] Scaffold provides proper context for Navigator.push()

#### Data Loading
- [ ] Dashboard initializes with parentId from UserRoleService
- [ ] Children data loads correctly via `ParentService.getParentChildren()`
- [ ] Financial summary loads via `ParentService.getFinancialSummary()`
- [ ] Invoices stream loads via `InvoiceService.getParentInvoices()`
- [ ] Payments stream loads via `PaymentService.getPaymentHistory()`
- [ ] Error states display correctly if data fails to load
- [ ] Loading indicators show during data fetch

### 3. Navigation & Screen Transitions

#### From Parent Dashboard
- [ ] "Invoices" quick action navigates to `ParentInvoicesScreen`
- [ ] "Payments" quick action navigates to `PaymentHistoryScreen`
- [ ] "Pay Now" button navigates to invoices with pending filter
- [ ] "See all" for invoices navigates to `ParentInvoicesScreen`
- [ ] "See all" for payments navigates to `PaymentHistoryScreen`
- [ ] Invoice card tap navigates to `InvoiceDetailScreen`
- [ ] Payment item tap navigates to `InvoiceDetailScreen`
- [ ] All navigations use MaterialPageRoute properly
- [ ] Back button works correctly on all screens

### 4. Error Handling & Edge Cases

#### Authentication
- [ ] Dashboard handles null parentId gracefully
- [ ] Shows error message when parentId cannot be determined
- [ ] Handles authentication errors appropriately

#### Data Edge Cases
- [ ] Dashboard handles empty children list
- [ ] Dashboard handles empty invoices list
- [ ] Dashboard handles empty payments list
- [ ] Dashboard handles API errors gracefully
- [ ] RefreshIndicator works correctly (pull-to-refresh)

### 5. Security & Permissions

#### Firestore Read Access
- [ ] Parent user CAN read invoices where parent_id = their uid
- [ ] Parent user CANNOT read invoices where parent_id != their uid
- [ ] Parent user CAN read payments where parent_id = their uid
- [ ] Parent user CANNOT read payments where parent_id != their uid
- [ ] Admin user CAN read all invoices
- [ ] Admin user CAN read all payments

#### Firestore Write Access
- [ ] Parent user CANNOT create invoices (admin only)
- [ ] Parent user CAN update payment_method_id on their own invoices
- [ ] Parent user CANNOT update other fields on invoices
- [ ] Parent user CANNOT create payments (Cloud Functions only)
- [ ] Parent user CANNOT update payments (Cloud Functions only)
- [ ] Parent user CAN manage their own payment methods

### 6. Integration Testing

#### End-to-End Flow
- [ ] Parent logs in → sees dashboard → views invoices → pays invoice → sees updated balance
- [ ] Parent views payment history → sees payment details
- [ ] Admin creates invoice for parent → parent sees invoice on dashboard
- [ ] Cloud Function processes payment → parent sees updated payment status

#### Multi-User Isolation
- [ ] Parent A cannot see Parent B's invoices
- [ ] Parent A cannot see Parent B's payments
- [ ] Parent A cannot access Parent B's payment methods

## Deployment Checklist

### Before Deployment
- [ ] All tests pass
- [ ] Firestore rules validated and deployed
- [ ] Code compiles without errors
- [ ] Linter passes (ignore pre-existing warnings)
- [ ] No console errors in browser/device

### After Deployment
- [ ] Verify rules are active in Firebase Console
- [ ] Test with real parent user account
- [ ] Test with admin account
- [ ] Monitor Firebase Console for permission denied errors
- [ ] Check application logs for any errors

## Rollback Plan

If issues occur:
1. Revert `firestore.rules` to previous version
2. Revert `lib/role_based_dashboard.dart` changes
3. Redeploy rules: `firebase deploy --only firestore:rules`
4. Verify parent dashboard still accessible (may show old DashboardPage)

## Notes

- The lint warning about `_onRoleChanged` in `role_based_dashboard.dart` is pre-existing and can be ignored
- Payment creation/updates are intentionally blocked on client-side (only Cloud Functions can modify)
- Parent can only update `payment_method_id` field on invoices to prevent unauthorized changes
