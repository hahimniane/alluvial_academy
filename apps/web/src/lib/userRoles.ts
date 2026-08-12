import type { User } from "firebase/auth";
import { collection, doc, getDoc, getDocs, limit, query, where } from "firebase/firestore";
import { db } from "@/lib/firebase";

type UserRecord = Record<string, unknown>;

export async function isCurrentUserAdmin(user: User) {
  const data = await getUserRecord(user);
  if (!data) return false;
  const roles = availableRoles(data);
  return roles.has("admin") || roles.has("super_admin");
}

export async function isCurrentUserTeacher(user: User) {
  const data = await getUserRecord(user);
  if (!data) return false;
  return availableRoles(data).has("teacher");
}

export async function isCurrentUserStudent(user: User) {
  const data = await getUserRecord(user);
  if (!data) return false;
  return availableRoles(data).has("student");
}

/**
 * Adult students pay their own tuition, so they get the Finance section a
 * parent would. Minors never see it — their parent handles billing.
 */
export function isAdultStudentRecord(data: UserRecord | null) {
  return data?.is_adult_student === true;
}

export async function dashboardPathForUser(user: User) {
  const data = await getUserRecord(user);
  // Roles without a ported dashboard (parents, circle members) still land in the
  // Flutter app, but at /app/ rather than its login screen — they are already
  // authenticated by the time this runs, so the login route would just bounce.
  if (!data) return "/app/";
  const roles = availableRoles(data);
  if (roles.has("admin") || roles.has("super_admin")) return "/admin/";
  if (roles.has("teacher")) return "/teacher/";
  if (roles.has("student")) return "/student/";
  return "/app/";
}

export async function getCurrentUserRecord(user: User): Promise<UserRecord | null> {
  return getUserRecord(user);
}

export function rolesForUserRecord(data: UserRecord) {
  return availableRoles(data);
}

async function getUserRecord(user: User): Promise<UserRecord | null> {
  const byUid = await getDoc(doc(db, "users", user.uid));
  if (byUid.exists()) return byUid.data() as UserRecord;

  const email = user.email?.trim().toLowerCase();
  if (email) {
    const byEmailId = await getDoc(doc(db, "users", email));
    if (byEmailId.exists()) return byEmailId.data() as UserRecord;

    for (const field of ["email", "e-mail"]) {
      const snap = await getDocs(query(collection(db, "users"), where(field, "==", email), limit(1)));
      if (!snap.empty) return snap.docs[0].data() as UserRecord;
    }
  }

  if (user.phoneNumber) {
    const snap = await getDocs(query(collection(db, "users"), where("phone_number", "==", user.phoneNumber), limit(1)));
    if (!snap.empty) return snap.docs[0].data() as UserRecord;
  }

  return null;
}

function availableRoles(data: UserRecord) {
  const roles = new Set<string>();
  const primaryRole = stringValue(data.user_type).toLowerCase();
  if (primaryRole) roles.add(primaryRole);
  if (primaryRole === "admin" || primaryRole === "super_admin") roles.add("teacher");
  if (primaryRole === "teacher" && data.is_admin_teacher === true) roles.add("admin");
  if (Array.isArray(data.secondary_roles)) {
    data.secondary_roles.forEach((role) => {
      const normalized = stringValue(role).toLowerCase();
      if (normalized) roles.add(normalized);
    });
  }
  return roles;
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}
