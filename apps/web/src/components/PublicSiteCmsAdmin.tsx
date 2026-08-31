"use client";

import { useEffect, useMemo, useState } from "react";
import { collection, deleteDoc, doc, getDocs, serverTimestamp, setDoc, writeBatch } from "firebase/firestore";
import { onAuthStateChanged, type User } from "firebase/auth";
import { deleteObject, getDownloadURL, ref, uploadBytes } from "firebase/storage";
import {
  ArrowLeft,
  Check,
  ChevronDown,
  DollarSign,
  Globe2,
  Image as ImageIcon,
  Lock,
  Menu,
  Pencil,
  Plus,
  RefreshCw,
  Save,
  Share2,
  Trash2,
  UploadCloud,
  Users,
} from "lucide-react";
import { auth, db, storage } from "@/lib/firebase";
import {
  fallbackPricing,
  loadPublicMarketingBundle,
  photoAssetToPath,
  searchPublicSiteDirectoryUsers,
  type PublicSiteDirectoryUser,
  type PublicSiteLandingDoc,
  type PublicSiteMarketingBundle,
  type PublicSitePlanPricing,
  type PublicSitePricingDoc,
  type PublicSiteSocialDoc,
  type PublicSiteTeamMember,
} from "@/lib/publicSiteCms";
import { isCurrentUserAdmin } from "@/lib/userRoles";

type CmsTab = "pricing" | "team" | "social" | "landing";
type AccessState = "checking" | "signedOut" | "allowed" | "denied";
type TeamDraft = {
  id: string;
  name: string;
  role: string;
  city: string;
  education: string;
  bio: string;
  whyAlluwal: string;
  languages: string;
  imageUrl: string;
  photoAsset: string;
  linkedUserUid: string;
  linkedUserDisplay: string;
  category: "teacher" | "leadership";
  sortOrder: string;
  active: boolean;
};

const tabs: Array<{ id: CmsTab; label: string; icon: typeof DollarSign }> = [
  { id: "pricing", label: "Pricing", icon: DollarSign },
  { id: "team", label: "Team on website", icon: Users },
  { id: "social", label: "Social links", icon: Share2 },
  { id: "landing", label: "Home hero", icon: ImageIcon },
];

const tabCopy: Record<CmsTab, { title: string; subtitle: string }> = {
  pricing: {
    title: "Pricing",
    subtitle: "Set the hourly rates and bullets that feed the public landing page and new enrollment quotes.",
  },
  team: {
    title: "Team on website",
    subtitle: "Profiles shown on the public team page. Only active, named profiles appear publicly.",
  },
  social: {
    title: "Social links",
    subtitle:
      "Choose which icons appear in the blue header bar. Each network stays hidden until it is enabled and has a link.",
  },
  landing: {
    title: "Home hero",
    subtitle:
      "Customize the landing page hero strip: background color and optional image URLs. Empty image URLs use the built-in photos.",
  },
};

const mobileTabSubtitle: Partial<Record<CmsTab, string>> = {
  team:
    "Copies the default team list into Firestore with stable IDs. Imported rows start inactive until you link a real user and activate them for the public site.",
  social:
    "Choose which icons appear in the blue header bar. Each network stays hidden until you turn it on and add a valid https link.",
  landing:
    "Customize the landing page hero strip: background color (hex) and optional image URLs (https). Leave URLs empty to use the built-in photos. Prefer dark hero colors so headline text stays readable. On the web, some stock sites block hotlinking or CORS; use Upload to host images reliably on Firebase Storage.",
};

function mobileSubtitleFor(tab: CmsTab, access: AccessState) {
  if (access !== "allowed") return null;
  return mobileTabSubtitle[tab] ?? null;
}

const trackMeta: Record<string, { title: string; subtitle: string }> = {
  islamic: {
    title: "Islamic & AdLam",
    subtitle: "1-on-1 Islamic and AdLam classes",
  },
  tutoring: {
    title: "Tutoring & Literacy",
    subtitle: "1-on-1 tutoring and literacy support",
  },
  group: {
    title: "Group Classes",
    subtitle: "Weekend group learning sessions",
  },
};

const orderedTrackIds = ["islamic", "tutoring", "group"] as const;

export function PublicSiteCmsAdmin() {
  const [activeTab, setActiveTab] = useState<CmsTab>("pricing");
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<AccessState>("checking");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [bundle, setBundle] = useState<PublicSiteMarketingBundle | null>(null);
  const [teamMembers, setTeamMembers] = useState<PublicSiteTeamMember[]>([]);
  const [editingTeamMember, setEditingTeamMember] = useState<PublicSiteTeamMember | null>(null);
  const [teamEditorOpen, setTeamEditorOpen] = useState(false);
  const [deleteConfirmMember, setDeleteConfirmMember] = useState<PublicSiteTeamMember | null>(null);
  const [deletingTeamId, setDeletingTeamId] = useState("");
  const [importingTeam, setImportingTeam] = useState(false);
  const [pricing, setPricing] = useState<PublicSitePricingDoc>(fallbackPricing);
  const [social, setSocial] = useState<PublicSiteSocialDoc>(emptySocialDoc());
  const [landing, setLanding] = useState<PublicSiteLandingDoc>({
    heroBackgroundColorHex: "#00484E",
    heroMainImageUrl: "",
    heroLeftImageUrl: "",
    heroRightImageUrl: "",
  });

  useEffect(() => {
    return onAuthStateChanged(auth, async (nextUser) => {
      setUser(nextUser);
      setMessage("");
      if (!nextUser) {
        setAccess("signedOut");
        setLoading(false);
        return;
      }

      setAccess("checking");
      setLoading(true);
      try {
        const allowed = await isCurrentUserAdmin(nextUser);
        if (!allowed) {
          setAccess("denied");
          setLoading(false);
          return;
        }
        setAccess("allowed");
        await refresh();
      } catch (error) {
        setAccess("denied");
        setLoading(false);
        setMessage(error instanceof Error ? error.message : "Could not verify admin access.");
      }
    });
  }, []);

  const current =
    access === "allowed"
      ? tabCopy[activeTab]
      : {
          title: "Public website CMS",
          subtitle: "Administrator access is required to manage public website content.",
        };
  const userInitials = initials(user?.displayName || user?.email || "");
  const mobileSubtitle = mobileSubtitleFor(activeTab, access);

  async function refresh() {
    setLoading(true);
    setMessage("");
    try {
      const next = await loadPublicMarketingBundle();
      setBundle(next);
      setTeamMembers(await loadTeamMembersForCms(next.teamMembers));
      setPricing(next.pricing);
      setSocial(next.social);
      setLanding(next.landing);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not load public site CMS data.");
    } finally {
      setLoading(false);
    }
  }

  function requireSignedIn() {
    if (!auth.currentUser || access !== "allowed") {
      setMessage("Sign in with an admin account to save CMS changes.");
      return false;
    }
    return true;
  }

  async function savePricing(planIdForMessage?: string) {
    if (!requireSignedIn()) return;
    setSaving(true);
    setMessage("");
    try {
      await setDoc(
        doc(db, "public_site_cms_pricing", "main"),
        {
          plans: cleanPricingPlans(pricing.plans),
          updatedAt: serverTimestamp(),
          updatedBy: auth.currentUser?.uid ?? null,
        },
        { merge: true },
      );
      setMessage(
        planIdForMessage
          ? `Pricing saved including ${trackMeta[planIdForMessage]?.title ?? planIdForMessage}. All tracks are kept in sync.`
          : "Pricing saved. The landing page and new enrollment quotes will use these values.",
      );
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save pricing.");
    } finally {
      setSaving(false);
    }
  }

  async function saveSocial() {
    if (!requireSignedIn()) return;
    setSaving(true);
    setMessage("");
    try {
      await setDoc(
        doc(db, "public_site_cms_social", "main"),
        {
          ...social,
          updatedAt: serverTimestamp(),
          updatedBy: auth.currentUser?.uid ?? null,
        },
        { merge: true },
      );
      setMessage("Social links saved. The public header updates for all visitors.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save social links.");
    } finally {
      setSaving(false);
    }
  }

  async function saveLanding() {
    if (!requireSignedIn()) return;
    setSaving(true);
    setMessage("");
    try {
      await setDoc(
        doc(db, "public_site_cms_landing", "main"),
        {
          ...landing,
          updatedAt: serverTimestamp(),
          updatedBy: auth.currentUser?.uid ?? null,
        },
        { merge: true },
      );
      setMessage("Landing hero saved. Refresh the public site to see changes.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save landing hero.");
    } finally {
      setSaving(false);
    }
  }

  async function uploadLandingImage(slotId: string, file: File) {
    if (!requireSignedIn()) return "";
    return uploadLandingHeroImage(slotId, file);
  }

  function openTeamEditor(member?: PublicSiteTeamMember) {
    setEditingTeamMember(member ?? null);
    setTeamEditorOpen(true);
  }

  async function saveTeamMember(draft: TeamDraft, imageFile?: File | null) {
    if (!requireSignedIn()) return;
    const name = draft.name.trim();
    const city = draft.city.trim();
    const linkedUserUid = draft.linkedUserUid.trim();
    if (!name) {
      setMessage("Name is required.");
      return;
    }
    if (!linkedUserUid) {
      setMessage("Link this profile to a user before saving.");
      return;
    }
    if (!city) {
      setMessage("City is required.");
      return;
    }
    if (
      linkedUserUid &&
      teamMembers.some((member) => member.id !== draft.id && member.linkedUserUid?.trim() === linkedUserUid)
    ) {
      setMessage("That linked user is already used by another public profile.");
      return;
    }

    setSaving(true);
    setMessage("");
    try {
      let imageUrl = draft.imageUrl.trim();
      if (imageFile) {
        imageUrl = await uploadTeamImage(draft.id, imageFile);
      }
      const member = normalizeTeamDraft({ ...draft, imageUrl, active: true });
      await setDoc(doc(db, "public_site_cms_team", member.id), {
        ...member,
        updatedAt: serverTimestamp(),
        updatedBy: auth.currentUser?.uid ?? null,
      }, { merge: true });
      setTeamEditorOpen(false);
      setEditingTeamMember(null);
      setTeamMembers((current) => upsertTeamMember(current, member));
      setMessage("Profile saved");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not save team profile.");
    } finally {
      setSaving(false);
    }
  }

  async function deleteTeamMember(member: PublicSiteTeamMember) {
    if (!requireSignedIn()) return;
    setDeletingTeamId(member.id);
    setMessage("");
    try {
      await deleteDoc(doc(db, "public_site_cms_team", member.id));
      if (member.imageUrl) {
        try {
          await deleteObject(ref(storage, member.imageUrl));
        } catch {
          // Best effort cleanup: do not fail deletion if the Storage object is already gone.
        }
      }
      setTeamMembers((current) => current.filter((item) => item.id !== member.id));
      setMessage("Profile deleted.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not delete team profile.");
    } finally {
      setDeletingTeamId("");
    }
  }

  async function importBundledStaff() {
    if (!requireSignedIn()) return;
    setImportingTeam(true);
    setMessage("");
    try {
      const response = await fetch("/assets/data/staff.json", { cache: "no-store" });
      if (!response.ok) throw new Error("Could not load bundled staff list.");
      const raw = (await response.json()) as PublicSiteTeamMember[];
      const existingIds = new Set(teamMembers.map((member) => member.id));
      const rows = raw
        .filter((member) => member.id && !existingIds.has(member.id))
        .map((member) => ({
          id: member.id,
          name: member.name ?? "",
          role: member.role ?? "",
          city: member.city ?? "",
          education: member.education ?? "",
          bio: member.bio ?? "",
          languages: Array.isArray(member.languages) ? member.languages : [],
          whyAlluwal: member.whyAlluwal ?? "",
          imageUrl: member.imageUrl ?? null,
          photoAsset: member.photoAsset ?? null,
          linkedUserUid: "",
          category: member.category === "leadership" ? "leadership" : "teacher",
          sortOrder: Number(member.sortOrder ?? 0),
          active: false,
        }));
      const batch = writeBatch(db);
      rows.forEach((member) => {
        batch.set(doc(db, "public_site_cms_team", member.id), {
          ...member,
          updatedAt: serverTimestamp(),
          updatedBy: auth.currentUser?.uid ?? null,
      }, { merge: true });
      });
      if (rows.length > 0) await batch.commit();
      setTeamMembers((current) => [...current, ...rows].sort((a, b) => a.sortOrder - b.sortOrder));
      setMessage(`Imported ${rows.length} profile(s). Skipped ${raw.length - rows.length} that already existed.`);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not import bundled staff.");
    } finally {
      setImportingTeam(false);
    }
  }

  return (
    <main className="min-h-screen bg-[#F1F4F8] text-[#0F172A]">
      <div className="lg:flex lg:min-h-screen">
        {access === "allowed" ? (
        <aside className="hidden w-[92px] shrink-0 border-r border-black/10 bg-white lg:block">
          <div className="flex h-full flex-col items-center gap-3 py-5">
            <Globe2 className="mb-1 text-[#001E4E]" size={24} />
            {tabs.map((tab) => (
              <RailButton key={tab.id} tab={tab} active={activeTab === tab.id} onClick={() => setActiveTab(tab.id)} />
            ))}
          </div>
        </aside>
        ) : null}

        <section className="flex min-h-screen flex-1 flex-col">
          <header className="lg:hidden">
            <div className="grid min-h-14 grid-cols-[48px_1fr_96px] items-center bg-white px-3 text-[#0F172A]">
              <button type="button" aria-label="Menu" className="grid h-11 w-11 place-items-center rounded-xl text-[#0F172A]">
                <Menu size={27} />
              </button>
              <div className="min-w-0 text-center text-[21px] font-bold">Alluwal Education Hub</div>
              <div className="flex items-center justify-end gap-2">
                <span aria-hidden="true" className="text-[26px] font-bold leading-none">
                  ↔
                </span>
                <span className="grid h-11 w-11 place-items-center rounded-full bg-[#009688] text-sm font-semibold text-white">
                  {userInitials || "AD"}
                </span>
              </div>
            </div>
            <div className="flex min-h-[76px] items-center gap-5 border-t border-black/5 bg-[#F1F4F8] px-5 py-4">
              <a href="/admin/" aria-label="Back" className="grid h-11 w-11 shrink-0 place-items-center rounded-xl text-[#0F172A]">
                <ArrowLeft size={32} />
              </a>
              <div className="min-w-0 whitespace-nowrap text-[clamp(18px,5vw,22px)] font-bold leading-tight text-[#0F172A]">
                Public website — pricing & team
              </div>
            </div>
          </header>

          <div className="mx-auto flex w-full max-w-[1200px] flex-1 flex-col px-5 pb-24 pt-3 lg:pb-6 lg:pt-3">
            <section className="mb-3">
              <p className="hidden text-xs font-semibold tracking-[0.04em] text-[#94A3B8] lg:block">
                Public website — pricing & team
              </p>
              <div className="mt-1 flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h1 className="text-[28px] font-bold leading-tight tracking-[-0.02em] text-[#0F172A]">
                    {current.title}
                  </h1>
                  <p className="mt-1 hidden max-w-3xl text-sm leading-6 text-[#64748B] lg:block">{current.subtitle}</p>
                  {mobileSubtitle ? <p className="mt-3 text-sm leading-6 text-[#64748B] lg:hidden">{mobileSubtitle}</p> : null}
                </div>
                <button
                  type="button"
                  onClick={refresh}
                  className="hidden h-10 items-center gap-2 rounded-xl border border-black/10 bg-white px-3 text-sm font-semibold text-[#334155] shadow-sm lg:inline-flex"
                >
                  <RefreshCw size={16} />
                  Refresh
                </button>
              </div>
            </section>

            {access === "signedOut" ? (
              <div className="mb-3 flex items-center gap-2 rounded-2xl border border-[#F59E0B]/30 bg-[#FFFBEB] px-4 py-3 text-sm font-medium text-[#92400E]">
                <Lock size={17} />
                Sign in with an admin account to manage public website content.
              </div>
            ) : null}

            {access === "denied" ? (
              <div className="mb-3 flex items-center gap-2 rounded-2xl border border-[#DC2626]/20 bg-[#FEF2F2] px-4 py-3 text-sm font-medium text-[#991B1B]">
                <Lock size={17} />
                This page is restricted to administrators.
              </div>
            ) : null}

            {message ? (
              <div className="mb-3 flex items-center gap-2 rounded-2xl border border-black/10 bg-white px-4 py-3 text-sm font-semibold text-[#334155] shadow-sm">
                <Check size={17} className="text-[#059669]" />
                {message}
              </div>
            ) : null}

            <div className="relative min-h-[560px] flex-1 overflow-hidden rounded-[20px]">
              {access === "checking" || loading ? (
                <LoadingCards />
              ) : access !== "allowed" ? (
                <AccessPrompt access={access} />
              ) : (
                <>
                  {activeTab === "pricing" ? (
                    <PricingTab pricing={pricing} setPricing={setPricing} saving={saving} onSave={savePricing} />
                  ) : null}
                  {activeTab === "team" ? (
                    <TeamTab
                      members={teamMembers}
                      onAdd={() => openTeamEditor()}
                      onEdit={openTeamEditor}
                      onDelete={setDeleteConfirmMember}
                      onImport={importBundledStaff}
                      deletingId={deletingTeamId}
                      importing={importingTeam}
                    />
                  ) : null}
                  {activeTab === "social" ? (
                    <SocialTab social={social} setSocial={setSocial} saving={saving} onSave={saveSocial} />
                  ) : null}
                  {activeTab === "landing" ? (
                    <LandingTab
                      landing={landing}
                      setLanding={setLanding}
                      saving={saving}
                      onSave={saveLanding}
                      onUpload={uploadLandingImage}
                      setMessage={setMessage}
                    />
                  ) : null}
                </>
              )}
            </div>
          </div>

          {access === "allowed" ? (
          <nav className="fixed inset-x-0 bottom-0 z-20 grid grid-cols-4 border-t border-black/10 bg-white px-1 pb-[env(safe-area-inset-bottom)] pt-1 shadow-[0_-8px_20px_rgba(15,23,42,0.08)] lg:hidden">
            {tabs.map((tab) => (
              <BottomTab key={tab.id} tab={tab} active={activeTab === tab.id} onClick={() => setActiveTab(tab.id)} />
            ))}
          </nav>
          ) : null}
        </section>
      </div>
      {teamEditorOpen ? (
        <TeamEditorSheet
          member={editingTeamMember}
          saving={saving}
          onClose={() => {
            if (saving) return;
            setTeamEditorOpen(false);
            setEditingTeamMember(null);
          }}
          onSave={saveTeamMember}
        />
      ) : null}
      {deleteConfirmMember ? (
        <DeleteTeamMemberDialog
          member={deleteConfirmMember}
          deleting={deletingTeamId === deleteConfirmMember.id}
          onCancel={() => {
            if (deletingTeamId) return;
            setDeleteConfirmMember(null);
          }}
          onConfirm={async () => {
            await deleteTeamMember(deleteConfirmMember);
            setDeleteConfirmMember(null);
          }}
        />
      ) : null}
    </main>
  );
}

function DeleteTeamMemberDialog({
  member,
  deleting,
  onCancel,
  onConfirm,
}: {
  member: PublicSiteTeamMember;
  deleting: boolean;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/30 px-4" role="dialog" aria-modal="true" aria-labelledby="delete-team-member-title">
      <div className="w-full max-w-md rounded-[20px] bg-white p-5 shadow-2xl">
        <h2 id="delete-team-member-title" className="text-lg font-bold text-[#0F172A]">
          Delete this profile from the website?
        </h2>
        <p className="mt-3 text-sm leading-6 text-[#334155]">{member.name}</p>
        <div className="mt-6 flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={deleting}
            className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B] hover:bg-[#F1F4F8] disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={deleting}
            className="inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#001E4E] px-4 text-sm font-semibold text-white disabled:opacity-60"
          >
            {deleting ? <RefreshCw size={16} className="animate-spin" /> : <Trash2 size={16} />}
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}

function RailButton({
  tab,
  active,
  onClick,
}: {
  tab: { id: CmsTab; label: string; icon: typeof DollarSign };
  active: boolean;
  onClick: () => void;
}) {
  const Icon = tab.icon;
  return (
    <button
      type="button"
      onClick={onClick}
      className={`grid w-full justify-items-center gap-1 px-1 py-2 text-center text-[11px] font-semibold ${
        active ? "text-[#001E4E]" : "text-[#64748B]"
      }`}
      aria-pressed={active}
    >
      <span className={`grid h-10 w-10 place-items-center rounded-2xl ${active ? "bg-[#E6EEF8]" : "bg-transparent"}`}>
        <Icon size={20} />
      </span>
      <span className="leading-tight">{tab.label}</span>
    </button>
  );
}

function BottomTab({
  tab,
  active,
  onClick,
}: {
  tab: { id: CmsTab; label: string; icon: typeof DollarSign };
  active: boolean;
  onClick: () => void;
}) {
  const Icon = tab.icon;
  return (
    <button
      type="button"
      onClick={onClick}
      className={`grid min-h-[58px] justify-items-center gap-1 rounded-2xl px-1 py-2 text-[11px] font-semibold ${
        active ? "text-[#001E4E]" : "text-[#64748B]"
      }`}
      aria-pressed={active}
    >
      <Icon size={21} />
      <span className="leading-tight">{tab.label}</span>
    </button>
  );
}

function AccessPrompt({ access }: { access: AccessState }) {
  return (
    <div className="grid h-full min-h-[520px] place-items-center rounded-[20px] border border-black/10 bg-white px-6 text-center shadow-sm">
      <div className="max-w-md">
        <div className="mx-auto grid h-14 w-14 place-items-center rounded-2xl bg-[#E6EEF8] text-[#001E4E]">
          <Lock size={24} />
        </div>
        <h2 className="mt-4 text-xl font-bold text-[#0F172A]">
          {access === "signedOut" ? "Admin sign-in required" : "Administrator access required"}
        </h2>
        <p className="mt-2 text-sm leading-6 text-[#64748B]">
          {access === "signedOut"
            ? "Sign in with an administrator account before managing public website pricing, team profiles, social links, or homepage media."
            : "Your signed-in account does not have administrator permissions for this CMS module."}
        </p>
        {access === "signedOut" ? (
          <a href="/login/" className="mt-5 inline-flex min-h-11 items-center justify-center rounded-xl bg-[#001E4E] px-5 text-sm font-semibold text-white">
            Go to login
          </a>
        ) : null}
      </div>
    </div>
  );
}

function PricingTab({
  pricing,
  setPricing,
  saving,
  onSave,
}: {
  pricing: PublicSitePricingDoc;
  setPricing: (pricing: PublicSitePricingDoc) => void;
  saving: boolean;
  onSave: (planIdForMessage?: string) => void;
}) {
  function updatePlan(planId: string, patch: Partial<PublicSitePlanPricing>) {
    const current = pricing.plans[planId] ?? { bullets: [] };
    setPricing({
      plans: {
        ...pricing.plans,
        [planId]: {
          ...current,
          ...patch,
          bullets: patch.bullets ?? current.bullets ?? [],
        },
      },
    });
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex-1 overflow-y-auto pr-1">
        <p className="mb-4 text-sm leading-6 text-[#64748B]">
          Three public tracks: Islamic &amp; AdLam, Tutoring &amp; Literacy, and Group Classes. Amounts here power
          the home page pricing cards and new enrollment estimates (4 weeks per month for individual tracks; 4.33 for
          group).
        </p>
        {orderedTrackIds.map((planId) => (
          <PricingCard
            key={planId}
            planId={planId}
            plan={pricing.plans[planId] ?? { bullets: [] }}
            updatePlan={updatePlan}
            saving={saving}
            onSave={() => onSave(planId)}
          />
        ))}
      </div>
      <ActionBar>
        <button type="button" disabled={saving} onClick={() => onSave()} className="cms-primary-button">
          <Save size={19} />
          {saving ? "Saving..." : "Save pricing to website"}
        </button>
      </ActionBar>
    </div>
  );
}

function PricingCard({
  planId,
  plan,
  updatePlan,
  saving,
  onSave,
}: {
  planId: string;
  plan: PublicSitePlanPricing;
  updatePlan: (planId: string, patch: Partial<PublicSitePlanPricing>) => void;
  saving: boolean;
  onSave: () => void;
}) {
  const meta = trackMeta[planId];
  return (
    <details className="group mb-3 overflow-hidden rounded-[20px] border border-black/10 bg-white shadow-[0_4px_16px_rgba(15,23,42,0.05)]">
      <summary className="flex cursor-pointer list-none items-center justify-between gap-4 px-5 py-4 marker:hidden">
        <div>
          <h2 className="text-base font-semibold text-[#0F172A]">{meta.title}</h2>
          <p className="mt-1 text-[13px] leading-5 text-[#64748B]">{meta.subtitle}</p>
        </div>
        <ChevronDown size={20} className="shrink-0 text-[#64748B] transition group-open:rotate-180" />
      </summary>

      <div className="px-5 pb-5">
        <div className="grid gap-3">
          {planId === "islamic" ? (
            <>
              <CmsInput
                label="Base hourly rate (USD)"
                value={plan.islamicBaseUsd}
                onChange={(value) => updatePlan(planId, { islamicBaseUsd: value })}
              />
              <CmsInput
                label="Discount hourly rate (USD)"
                value={plan.islamicDiscountUsd}
                onChange={(value) => updatePlan(planId, { islamicDiscountUsd: value })}
              />
              <CmsInput
                label="Volume discount threshold (weekly hours)"
                value={plan.islamicDiscountThreshold}
                helper="Discounted rate applies when weekly hours are greater than this number (default 4)."
                integer
                onChange={(value) => updatePlan(planId, { islamicDiscountThreshold: value })}
              />
            </>
          ) : null}
          {planId === "tutoring" ? (
            <>
              <CmsInput
                label="Base hourly rate (USD)"
                value={plan.tutoringBaseUsd}
                onChange={(value) => updatePlan(planId, { tutoringBaseUsd: value })}
              />
              <CmsInput
                label="Discount hourly rate (USD)"
                value={plan.tutoringDiscountUsd}
                onChange={(value) => updatePlan(planId, { tutoringDiscountUsd: value })}
              />
              <CmsInput
                label="Volume discount threshold (weekly hours)"
                value={plan.tutoringDiscountThreshold}
                helper="Discounted rate applies when weekly hours are greater than this number (default 4)."
                integer
                onChange={(value) => updatePlan(planId, { tutoringDiscountThreshold: value })}
              />
            </>
          ) : null}
          {planId === "group" ? (
            <CmsInput label="Hourly rate (USD)" value={plan.groupHourlyUsd} onChange={(value) => updatePlan(planId, { groupHourlyUsd: value })} />
          ) : null}
        </div>

        <div className="my-5 h-px bg-black/10" />

        <label className="block text-sm font-semibold text-[#334155]">
          <span className="text-xs font-medium leading-5 text-[#64748B]">
            Feature bullets (optional): each line shows as a checkmarked highlight on the home page pricing card for
            this track.
          </span>
          <textarea
            value={(plan.bullets ?? []).join("\n")}
            onChange={(event) =>
              updatePlan(planId, {
                bullets: event.target.value
                  .split("\n")
                  .map((line) => line.trim())
                  .filter(Boolean),
              })
            }
            placeholder="One line per bullet, shown with checkmarks on the card"
            className="mt-2 min-h-[124px] w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 py-3 text-sm leading-6 text-[#0F172A] outline-none focus:border-[#001E4E]"
          />
        </label>
        <button
          type="button"
          onClick={onSave}
          disabled={saving}
          className="mt-3 inline-flex min-h-10 items-center gap-2 rounded-xl bg-[#E6EEF8] px-4 text-sm font-semibold text-[#001E4E] disabled:opacity-60"
        >
          {saving ? <RefreshCw size={16} className="animate-spin" /> : <Save size={16} />}
          Save this track
        </button>
      </div>
    </details>
  );
}

function TeamTab({
  members,
  onAdd,
  onEdit,
  onDelete,
  onImport,
  deletingId,
  importing,
}: {
  members: PublicSiteTeamMember[];
  onAdd: () => void;
  onEdit: (member: PublicSiteTeamMember) => void;
  onDelete: (member: PublicSiteTeamMember) => void;
  onImport: () => void;
  deletingId: string;
  importing: boolean;
}) {
  const sorted = useMemo(() => [...members].sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0)), [members]);
  return (
    <div className="relative h-full">
      {sorted.length === 0 ? (
        <div className="grid h-full place-items-center px-6 pb-24 text-center">
          <div>
            <p className="text-sm text-[#64748B]">
              No profiles yet. Add people to show on the public Team page instead of the default list.
            </p>
            <p className="mt-3 text-xs leading-5 text-[#94A3B8]">
              Copies the default team list into Firestore with stable IDs. Imported rows start inactive until you link a real user and activate them for the public site.
            </p>
          </div>
        </div>
      ) : (
        <div className="h-full overflow-y-auto px-1 pb-32 pt-3">
          {sorted.map((member) => (
            <TeamRow
              key={member.id}
              member={member}
              onEdit={() => onEdit(member)}
              onDelete={() => onDelete(member)}
              deleting={deletingId === member.id}
            />
          ))}
        </div>
      )}
      <div className="absolute inset-x-0 bottom-0 grid gap-2 bg-gradient-to-t from-[#F1F4F8] via-[#F1F4F8] to-transparent px-4 pb-4 pt-12">
        <button type="button" className="cms-secondary-button" onClick={onImport} disabled={importing}>
          <UploadCloud size={18} />
          {importing ? "Importing..." : "Import profiles from website defaults"}
        </button>
        <button type="button" className="cms-primary-button" onClick={onAdd}>
          <Plus size={18} />
          Add profile
        </button>
      </div>
    </div>
  );
}

function TeamRow({
  member,
  onEdit,
  onDelete,
  deleting,
}: {
  member: PublicSiteTeamMember;
  onEdit: () => void;
  onDelete: () => void;
  deleting: boolean;
}) {
  const imageUrl = member.imageUrl || photoAssetToPath(member.photoAsset);
  return (
    <article className="mb-3 flex items-center gap-3 rounded-[14px] border border-black/10 bg-white p-3 shadow-[0_3px_10px_rgba(15,23,42,0.04)]">
      <div className="grid h-12 w-12 shrink-0 place-items-center overflow-hidden rounded-xl bg-[#E6EEF8] text-sm font-bold text-[#001E4E]">
        {imageUrl ? <img src={imageUrl} alt="" className="h-full w-full object-cover" /> : initials(member.name)}
      </div>
      <div className="min-w-0 flex-1">
        <h3 className="truncate text-sm font-semibold text-[#0F172A]">{member.name}</h3>
        <p className="truncate text-[13px] text-[#64748B]">
          {member.role} · {member.category} · #{member.sortOrder}
          {member.active ? "" : " · Inactive"}
        </p>
      </div>
      <button type="button" className="rounded-xl p-2 text-[#64748B] hover:bg-[#F1F4F8]" onClick={onEdit} aria-label={`Edit ${member.name}`}>
        <Pencil size={18} />
      </button>
      <button
        type="button"
        className="rounded-xl p-2 text-[#64748B] hover:bg-[#FEE2E2] hover:text-[#B91C1C]"
        onClick={onDelete}
        disabled={deleting}
        aria-label={`Delete ${member.name}`}
      >
        <Trash2 size={18} />
      </button>
    </article>
  );
}

function TeamEditorSheet({
  member,
  saving,
  onClose,
  onSave,
}: {
  member: PublicSiteTeamMember | null;
  saving: boolean;
  onClose: () => void;
  onSave: (draft: TeamDraft, imageFile?: File | null) => void;
}) {
  const [draft, setDraft] = useState<TeamDraft>(() => teamDraftFromMember(member));
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [userSearch, setUserSearch] = useState("");
  const [userResults, setUserResults] = useState<PublicSiteDirectoryUser[]>([]);
  const [userSearchLoading, setUserSearchLoading] = useState(false);
  const [userSearchMessage, setUserSearchMessage] = useState("");
  const [userPickerOpen, setUserPickerOpen] = useState(false);
  const [previewObjectUrl, setPreviewObjectUrl] = useState("");
  const previewUrl = previewObjectUrl || draft.imageUrl || photoAssetToPath(draft.photoAsset) || "";

  useEffect(() => {
    if (!imageFile) {
      setPreviewObjectUrl("");
      return undefined;
    }
    const url = URL.createObjectURL(imageFile);
    setPreviewObjectUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [imageFile]);

  useEffect(() => {
    const q = userSearch.trim();
    if (q.length < 2) {
      setUserResults([]);
      setUserSearchLoading(false);
      setUserSearchMessage("");
      return undefined;
    }

    let live = true;
    setUserSearchLoading(true);
    setUserSearchMessage("");
    const timer = window.setTimeout(() => {
      searchPublicSiteDirectoryUsers(q)
        .then((users) => {
          if (!live) return;
          setUserResults(users);
          setUserSearchMessage(users.length === 0 ? "No users found." : "");
        })
        .catch((error) => {
          if (!live) return;
          setUserResults([]);
          setUserSearchMessage(error instanceof Error ? error.message : "Could not search users.");
        })
        .finally(() => {
          if (live) setUserSearchLoading(false);
        });
    }, 400);

    return () => {
      live = false;
      window.clearTimeout(timer);
    };
  }, [userSearch]);

  function patch(next: Partial<TeamDraft>) {
    setDraft((current) => ({ ...current, ...next }));
  }

  return (
    <div className="fixed inset-0 z-40 flex justify-end bg-black/20" role="dialog" aria-modal="true" aria-label={member ? "Edit team profile" : "Add profile"}>
      <button type="button" aria-label="Close profile editor" className="absolute inset-0 cursor-default" onClick={onClose} disabled={saving} />
      <form
        className="relative flex h-full w-full max-w-[520px] flex-col bg-white shadow-2xl"
        onSubmit={(event) => {
          event.preventDefault();
          onSave(draft, imageFile);
        }}
      >
        <header className="flex items-start justify-between gap-3 px-5 pb-2 pt-4">
          <h2 className="text-xl font-bold text-[#0F172A]">{member ? "Edit" : "Add profile"}</h2>
          <button type="button" className="rounded-xl px-3 py-2 text-sm font-semibold text-[#64748B]" onClick={onClose} disabled={saving}>
            Cancel
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-5 pb-4">
          <div className="grid gap-3">
            <TextField label="Name" value={draft.name} onChange={(value) => patch({ name: value })} />
            <TextField label="Role / title" value={draft.role} onChange={(value) => patch({ role: value })} />
            <label className="grid gap-2 text-sm font-semibold text-[#334155]">
              Category
              <select
                value={draft.category}
                onChange={(event) => patch({ category: event.target.value === "leadership" ? "leadership" : "teacher" })}
                className="h-12 rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm outline-none focus:border-[#001E4E]"
              >
                <option value="leadership">Leadership</option>
                <option value="teacher">Teacher</option>
              </select>
            </label>
            <TextField label="City" value={draft.city} onChange={(value) => patch({ city: value })} />
            <TextField label="Education" value={draft.education} onChange={(value) => patch({ education: value })} />
            <TextField label="Bio" value={draft.bio} onChange={(value) => patch({ bio: value })} multiline />
            <TextField label="Why Alluwal" value={draft.whyAlluwal} onChange={(value) => patch({ whyAlluwal: value })} multiline />
            <TextField label="Languages (comma-separated)" value={draft.languages} onChange={(value) => patch({ languages: value })} />
            <TextField label="Sort order" value={draft.sortOrder} onChange={(value) => patch({ sortOrder: value })} type="number" />
            <TeamPhotoField
              label="Photo URL (optional)"
              value={draft.imageUrl}
              previewUrl={previewUrl}
              initialsText={initials(draft.name)}
              onChange={(value) => {
                setImageFile(null);
                patch({ imageUrl: value });
              }}
              onFile={(file) => setImageFile(file)}
            />

            <div className="rounded-[20px] border border-black/10 bg-[#F8FAFC] p-4">
              <p className="text-[13px] font-semibold text-[#0F172A]">Linked user (required)</p>
              {draft.linkedUserUid ? (
                <div className="mt-3 flex items-start gap-3 rounded-2xl border border-black/10 bg-white px-3 py-2">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-[#0F172A]">{draft.linkedUserDisplay || draft.linkedUserUid}</p>
                    <p className="mt-1 break-all font-mono text-[11px] text-[#64748B]">{draft.linkedUserUid}</p>
                  </div>
                  <button
                    type="button"
                    className="rounded-xl px-2 py-1 text-xs font-semibold text-[#64748B] hover:bg-[#F1F4F8]"
                    onClick={() => patch({ linkedUserUid: "", linkedUserDisplay: "" })}
                  >
                    Remove link
                  </button>
                </div>
              ) : (
                <p className="mt-2 text-sm leading-6 text-[#64748B]">No user linked yet. Search and select a staff account.</p>
              )}
              <button
                type="button"
                className="mt-3 inline-flex min-h-10 items-center justify-center rounded-xl bg-[#001E4E] px-4 text-sm font-semibold text-white"
                onClick={() => setUserPickerOpen((open) => !open)}
              >
                Search users...
              </button>
              {userPickerOpen ? (
                <div className="mt-3 rounded-2xl border border-black/10 bg-white p-3">
                  <label className="block text-sm font-semibold text-[#334155]">
                    Search by email or UID
                    <input
                      value={userSearch}
                      onChange={(event) => setUserSearch(event.target.value)}
                      placeholder="Type at least 2 characters"
                      className="mt-2 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm outline-none focus:border-[#001E4E]"
                    />
                  </label>
                  {userSearchLoading ? <div className="mt-3 h-1 overflow-hidden rounded-full bg-[#E2E8F0]"><div className="h-full w-1/2 animate-pulse rounded-full bg-[#001E4E]" /></div> : null}
                  {userSearchMessage ? <p className="mt-3 text-xs leading-5 text-[#64748B]">{userSearchMessage}</p> : null}
                  {userResults.length > 0 ? (
                    <div className="mt-3 max-h-52 overflow-y-auto rounded-2xl border border-black/10 bg-white">
                      {userResults.map((row) => (
                        <button
                          type="button"
                          key={row.uid || row.docId}
                          className="block w-full border-b border-black/5 px-3 py-2 text-left last:border-b-0 hover:bg-[#F1F4F8]"
                          onClick={() => {
                            patch({
                              linkedUserUid: row.uid || row.docId,
                              linkedUserDisplay: `${row.displayName}${row.userType ? ` · ${row.userType}` : ""}`,
                            });
                            setUserSearch("");
                            setUserResults([]);
                            setUserPickerOpen(false);
                          }}
                        >
                          <span className="block truncate text-sm font-semibold text-[#0F172A]">{row.displayName || row.email || row.uid}</span>
                          <span className="block truncate text-xs text-[#64748B]">{[row.email, row.userType].filter(Boolean).join(" · ")}</span>
                          <span className="mt-1 block truncate font-mono text-[11px] text-[#94A3B8]">{row.uid || row.docId}</span>
                        </button>
                      ))}
                    </div>
                  ) : null}
                  <input
                    value={draft.linkedUserUid}
                    onChange={(event) => patch({ linkedUserUid: event.target.value, linkedUserDisplay: "" })}
                    placeholder="Or paste Firebase user UID"
                    className="mt-3 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm outline-none focus:border-[#001E4E]"
                  />
                </div>
              ) : null}
            </div>
          </div>
        </div>

        <footer className="flex justify-end gap-2 border-t border-black/10 px-4 py-3">
          <button type="button" className="rounded-xl px-4 py-2 text-sm font-semibold text-[#64748B]" onClick={onClose} disabled={saving}>
            Cancel
          </button>
          <button type="submit" className="rounded-xl bg-[#001E4E] px-5 py-2 text-sm font-semibold text-white disabled:opacity-60" disabled={saving}>
            {saving ? "Saving..." : "Save"}
          </button>
        </footer>
      </form>
    </div>
  );
}

function TeamPhotoField({
  label,
  value,
  previewUrl,
  initialsText,
  onChange,
  onFile,
}: {
  label: string;
  value: string;
  previewUrl: string;
  initialsText: string;
  onChange: (value: string) => void;
  onFile: (file: File) => void;
}) {
  const [imageFailed, setImageFailed] = useState(false);
  const trimmedValue = value.trim();
  const showPreview = previewUrl.trim().length > 0 && !imageFailed;

  useEffect(() => {
    setImageFailed(false);
  }, [previewUrl]);

  return (
    <article className="rounded-[20px] border border-black/10 bg-white p-4 shadow-[0_3px_12px_rgba(15,23,42,0.04)]">
      <label className="block text-[15px] font-semibold text-[#0F172A]">
        {label}
        <input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="https://..."
          className="mt-3 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]"
        />
      </label>
      <div className="mt-3 grid min-h-[120px] max-h-[200px] place-items-center overflow-hidden rounded-2xl border border-black/10 bg-[#F1F4F8]">
        {showPreview ? (
          <img
            src={previewUrl}
            alt=""
            className="max-h-[200px] w-full object-contain"
            onError={() => setImageFailed(true)}
          />
        ) : trimmedValue.length > 0 ? (
          <div className="grid justify-items-center gap-2 p-4 text-center text-sm leading-6 text-[#94A3B8]">
            <ImageIcon size={24} />
            <span>Could not load image. Check the URL or network.</span>
          </div>
        ) : (
          <div className="grid justify-items-center gap-2 p-4 text-center text-sm leading-6 text-[#94A3B8]">
            <span className="grid h-12 w-12 place-items-center rounded-2xl bg-[#E6EEF8] text-sm font-black text-[#001E4E]">
              {initialsText}
            </span>
            <span>No image yet. Paste a URL or tap Upload.</span>
          </div>
        )}
      </div>
      <label className="mt-4 cms-secondary-button cursor-pointer">
        <UploadCloud size={18} />
        Upload photo
        <input
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={(event) => {
            const file = event.target.files?.[0];
            event.target.value = "";
            if (file) onFile(file);
          }}
        />
      </label>
    </article>
  );
}

function SocialTab({
  social,
  setSocial,
  saving,
  onSave,
}: {
  social: PublicSiteSocialDoc;
  setSocial: (social: PublicSiteSocialDoc) => void;
  saving: boolean;
  onSave: () => void;
}) {
  return (
    <div className="flex h-full flex-col">
      <div className="flex-1 overflow-y-auto">
        <p className="mb-4 text-sm leading-6 text-[#64748B]">
          Choose which icons appear in the blue header bar. Each network stays hidden until you turn it on and add a valid https link.
        </p>
        {(["instagram", "facebook", "tiktok"] as const).map((network) => (
          <SocialCard
            key={network}
            network={network}
            title={network === "tiktok" ? "TikTok" : capitalize(network)}
            enabled={social[network].enabled}
            url={social[network].url}
            onEnabled={(enabled) => setSocial({ ...social, [network]: { ...social[network], enabled } })}
            onUrl={(url) => setSocial({ ...social, [network]: { ...social[network], url } })}
          />
        ))}
      </div>
      <ActionBar>
        <button type="button" disabled={saving} onClick={onSave} className="cms-primary-button">
          <Save size={19} />
          {saving ? "Saving..." : "Save social links"}
        </button>
      </ActionBar>
    </div>
  );
}

function SocialCard({
  network,
  title,
  enabled,
  url,
  onEnabled,
  onUrl,
}: {
  network: "instagram" | "facebook" | "tiktok";
  title: string;
  enabled: boolean;
  url: string;
  onEnabled: (enabled: boolean) => void;
  onUrl: (url: string) => void;
}) {
  return (
    <article className="mb-3 rounded-[20px] border border-black/10 bg-white p-4 shadow-[0_3px_12px_rgba(15,23,42,0.04)]">
      <label className="flex items-center justify-between gap-4">
        <span className="flex min-w-0 items-center gap-3">
          <SocialGlyph network={network} />
          <span className="min-w-0">
            <span className="block text-base font-semibold text-[#0F172A]">{title}</span>
            <span className="mt-1 block text-xs text-[#64748B]">Show on website</span>
          </span>
        </span>
        <span className="relative inline-flex h-7 w-12 shrink-0 items-center">
          <input
            type="checkbox"
            checked={enabled}
            onChange={(event) => onEnabled(event.target.checked)}
            className="peer sr-only"
            aria-label={`${title} show on website`}
          />
          <span className="absolute inset-0 rounded-full bg-[#CBD5E1] transition peer-checked:bg-[#001E4E]" />
          <span className="absolute left-1 h-5 w-5 rounded-full bg-white shadow-sm transition peer-checked:translate-x-5" />
        </span>
      </label>
      <label className="mt-4 block text-sm font-semibold text-[#334155]">
        Link URL
        <input
          value={url}
          onChange={(event) => onUrl(event.target.value)}
          placeholder="https://..."
          className="mt-2 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]"
        />
      </label>
    </article>
  );
}

function SocialGlyph({ network }: { network: "instagram" | "facebook" | "tiktok" }) {
  const glyph = network === "instagram" ? "IG" : network === "facebook" ? "f" : "TT";
  return (
    <span
      aria-hidden="true"
      className="grid h-8 w-8 shrink-0 place-items-center rounded-xl bg-[#E6EEF8] text-[13px] font-black leading-none text-[#001E4E]"
    >
      {glyph}
    </span>
  );
}

function LandingTab({
  landing,
  setLanding,
  saving,
  onSave,
  onUpload,
  setMessage,
}: {
  landing: PublicSiteLandingDoc;
  setLanding: (landing: PublicSiteLandingDoc) => void;
  saving: boolean;
  onSave: () => void;
  onUpload: (slotId: string, file: File) => Promise<string>;
  setMessage: (message: string) => void;
}) {
  const [uploadingSlot, setUploadingSlot] = useState("");

  async function upload(slotId: string, file: File, onUrl: (value: string) => void) {
    setUploadingSlot(slotId);
    setMessage("");
    try {
      const url = await onUpload(slotId, file);
      if (!url) return;
      onUrl(url);
      setMessage("Image uploaded. Save landing hero to publish this URL.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "Could not upload image.");
    } finally {
      setUploadingSlot("");
    }
  }

  return (
    <div className="flex h-full flex-col">
      <div className="flex-1 overflow-y-auto">
        <p className="mb-4 text-sm leading-6 text-[#64748B]">
          Customize the landing page hero strip: background color (hex) and optional image URLs (https). Leave URLs empty to use the built-in photos. Prefer dark hero colors so headline text stays readable. On the web, some stock sites block hotlinking or CORS; use Upload to host images reliably on Firebase Storage.
        </p>
        <article className="rounded-[20px] border border-black/10 bg-white p-4 shadow-[0_3px_12px_rgba(15,23,42,0.04)]">
          <label className="block text-sm font-semibold text-[#334155]">
            Hero background color
            <span className="mt-2 flex items-center gap-3">
              <span className="relative grid h-12 w-12 shrink-0 place-items-center overflow-hidden rounded-xl border border-black/10">
                <span
                  aria-hidden="true"
                  className="absolute inset-0"
                  style={{ backgroundColor: landing.heroBackgroundColorHex || "#00484E" }}
                />
                <ImageIcon size={20} className="relative text-white" />
                <input
                  type="color"
                  aria-label="Pick hero background color"
                  value={normalizeHexColor(landing.heroBackgroundColorHex)}
                  onChange={(event) => setLanding({ ...landing, heroBackgroundColorHex: event.target.value.toUpperCase() })}
                  className="absolute inset-0 h-full w-full cursor-pointer opacity-0"
                />
              </span>
              <input
                value={landing.heroBackgroundColorHex}
                onChange={(event) => setLanding({ ...landing, heroBackgroundColorHex: event.target.value })}
                placeholder="#RRGGBB (example: #00484E)"
                className="h-12 min-w-0 flex-1 rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]"
              />
            </span>
          </label>
        </article>

        <div className="mt-3 grid gap-3 lg:grid-cols-3">
          <ImageUrlField
            label="Center hero image"
            value={landing.heroMainImageUrl}
            onChange={(value) => setLanding({ ...landing, heroMainImageUrl: value })}
            uploading={uploadingSlot === "main"}
            disabled={Boolean(uploadingSlot)}
            onUpload={(file) => upload("main", file, (value) => setLanding({ ...landing, heroMainImageUrl: value }))}
          />
          <ImageUrlField
            label="Left circle image"
            value={landing.heroLeftImageUrl}
            onChange={(value) => setLanding({ ...landing, heroLeftImageUrl: value })}
            uploading={uploadingSlot === "left"}
            disabled={Boolean(uploadingSlot)}
            onUpload={(file) => upload("left", file, (value) => setLanding({ ...landing, heroLeftImageUrl: value }))}
          />
          <ImageUrlField
            label="Right panel image"
            value={landing.heroRightImageUrl}
            onChange={(value) => setLanding({ ...landing, heroRightImageUrl: value })}
            uploading={uploadingSlot === "right"}
            disabled={Boolean(uploadingSlot)}
            onUpload={(file) => upload("right", file, (value) => setLanding({ ...landing, heroRightImageUrl: value }))}
          />
        </div>
      </div>
      <ActionBar>
        <button type="button" disabled={saving} onClick={onSave} className="cms-primary-button">
          <Save size={19} />
          {saving ? "Saving..." : "Save landing hero"}
        </button>
      </ActionBar>
    </div>
  );
}

function ImageUrlField({
  label,
  value,
  onChange,
  uploading,
  disabled,
  onUpload,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  uploading: boolean;
  disabled: boolean;
  onUpload: (file: File) => void;
}) {
  const [imageFailed, setImageFailed] = useState(false);
  const trimmedValue = value.trim();
  const showPreview = trimmedValue.length > 0 && !imageFailed;

  useEffect(() => {
    setImageFailed(false);
  }, [trimmedValue]);

  return (
    <article className="rounded-[20px] border border-black/10 bg-white p-4 shadow-[0_3px_12px_rgba(15,23,42,0.04)]">
      <label className="block text-sm font-semibold text-[#334155]">
        {label}
        <input
          value={value}
          onChange={(event) => onChange(event.target.value)}
          placeholder="https://..."
          className="mt-3 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]"
        />
      </label>
      <div className="mt-3 grid min-h-[120px] place-items-center overflow-hidden rounded-2xl border border-black/10 bg-[#F1F4F8]">
        {showPreview ? (
          <img
            src={trimmedValue}
            alt=""
            className="max-h-[200px] w-full object-contain"
            onError={() => setImageFailed(true)}
          />
        ) : (
          <div className="grid justify-items-center gap-2 p-4 text-center text-sm leading-6 text-[#94A3B8]">
            <ImageIcon size={24} />
            <span>No image yet. Paste a URL or tap Upload.</span>
          </div>
        )}
      </div>
      <label className={`mt-4 cms-secondary-button ${disabled ? "cursor-wait opacity-70" : "cursor-pointer"}`}>
        <UploadCloud size={18} />
        {uploading ? "Uploading..." : "Upload image"}
        <input
          type="file"
          accept="image/*"
          className="sr-only"
          disabled={disabled}
          onChange={(event) => {
            const file = event.target.files?.[0];
            event.target.value = "";
            if (file) onUpload(file);
          }}
        />
      </label>
    </article>
  );
}

function CmsInput({
  label,
  value,
  helper,
  integer = false,
  onChange,
}: {
  label: string;
  value?: number;
  helper?: string;
  integer?: boolean;
  onChange: (value: number | undefined) => void;
}) {
  return (
    <label className="block text-sm font-semibold text-[#334155]">
      {label}
      <input
        type="number"
        inputMode={integer ? "numeric" : "decimal"}
        step={integer ? "1" : "any"}
        value={value ?? ""}
        onChange={(event) => onChange(event.target.value === "" ? undefined : Number(event.target.value))}
        className="mt-2 h-12 w-full rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]"
      />
      {helper ? <span className="mt-1 block text-xs font-medium leading-5 text-[#94A3B8]">{helper}</span> : null}
    </label>
  );
}

function TextField({
  label,
  value,
  onChange,
  multiline = false,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  multiline?: boolean;
  type?: "text" | "number";
}) {
  const className = "rounded-2xl border border-black/10 bg-[#F1F4F8] px-3 text-sm text-[#0F172A] outline-none focus:border-[#001E4E]";
  return (
    <label className="grid gap-2 text-sm font-semibold text-[#334155]">
      {label}
      {multiline ? (
        <textarea value={value} onChange={(event) => onChange(event.target.value)} className={`${className} min-h-[92px] py-3`} />
      ) : (
        <input type={type} value={value} onChange={(event) => onChange(event.target.value)} className={`${className} h-12`} />
      )}
    </label>
  );
}

function ActionBar({ children }: { children: React.ReactNode }) {
  return (
    <div className="fixed inset-x-5 bottom-[88px] z-30 border-t border-black/15 bg-white py-3 shadow-[0_-8px_18px_rgba(15,23,42,0.08)] lg:static lg:inset-auto lg:z-auto lg:mt-auto lg:px-0">
      {children}
    </div>
  );
}

function LoadingCards() {
  return (
    <div className="space-y-3">
      {[0, 1, 2].map((item) => (
        <div key={item} className="h-[120px] animate-pulse rounded-[20px] bg-white" />
      ))}
    </div>
  );
}

async function loadTeamMembersForCms(publicMembers: PublicSiteTeamMember[]) {
  if (!auth.currentUser) return publicMembers;
  try {
    const snap = await getDocs(collection(db, "public_site_cms_team"));
    return snap.docs
      .map((row) => normalizeTeamMember(row.id, row.data()))
      .sort((a, b) => a.sortOrder - b.sortOrder);
  } catch {
    return publicMembers;
  }
}

async function uploadTeamImage(memberId: string, file: File) {
  const user = auth.currentUser;
  if (!user) throw new Error("Must be signed in");
  const safeName = file.name.replace(/[^\w.-]/g, "_");
  const storageRef = ref(storage, `public_site_assets/cms/${user.uid}/team/${memberId}_${Date.now()}_${safeName}`);
  const snapshot = await uploadBytes(storageRef, file, { contentType: file.type || "image/jpeg" });
  return getDownloadURL(snapshot.ref);
}

async function uploadLandingHeroImage(slotId: string, file: File) {
  const user = auth.currentUser;
  if (!user) throw new Error("Must be signed in");
  await syncPublicSiteAdminClaim();
  const safeName = file.name.replace(/[^\w.-]/g, "_");
  const storageRef = ref(storage, `public_site_assets/cms/${user.uid}/landing/${slotId}_${Date.now()}_${safeName}`);
  const snapshot = await uploadBytes(storageRef, file, { contentType: imageContentType(file) });
  return getDownloadURL(snapshot.ref);
}

async function syncPublicSiteAdminClaim() {
  const user = auth.currentUser;
  if (!user) return;
  try {
    const { httpsCallable } = await import("firebase/functions");
    const { functions } = await import("@/lib/firebase");
    await httpsCallable(functions, "syncPublicSiteAdminClaim")();
  } catch {
    // Storage rules also check the Firestore user record; keep upload attempt alive.
  }
  await user.getIdToken(true);
}

function imageContentType(file: File) {
  const lower = file.name.toLowerCase();
  if (lower.endsWith(".png")) return "image/png";
  if (lower.endsWith(".webp")) return "image/webp";
  if (lower.endsWith(".gif")) return "image/gif";
  if (lower.endsWith(".bmp")) return "image/bmp";
  return file.type || "image/jpeg";
}

function normalizeHexColor(value: string) {
  return /^#[0-9a-fA-F]{6}$/.test(value) ? value : "#00484E";
}

function normalizeTeamDraft(draft: TeamDraft): PublicSiteTeamMember {
  return {
    id: draft.id,
    name: draft.name.trim(),
    role: draft.role.trim(),
    city: draft.city.trim(),
    education: draft.education.trim(),
    bio: draft.bio.trim(),
    languages: draft.languages
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean),
    whyAlluwal: draft.whyAlluwal.trim(),
    imageUrl: draft.imageUrl.trim() || null,
    photoAsset: draft.photoAsset.trim() || null,
    linkedUserUid: draft.linkedUserUid.trim() || null,
    category: draft.category,
    sortOrder: Number.parseInt(draft.sortOrder, 10) || 0,
    active: draft.active,
  };
}

function teamDraftFromMember(member: PublicSiteTeamMember | null): TeamDraft {
  return {
    id: member?.id ?? doc(collection(db, "public_site_cms_team")).id,
    name: member?.name ?? "",
    role: member?.role ?? "",
    city: member?.city ?? "",
    education: member?.education ?? "",
    bio: member?.bio ?? "",
    whyAlluwal: member?.whyAlluwal ?? "",
    languages: member?.languages?.join(", ") ?? "",
    imageUrl: member?.imageUrl ?? "",
    photoAsset: member?.photoAsset ?? "",
    linkedUserUid: member?.linkedUserUid ?? "",
    linkedUserDisplay: member?.linkedUserUid ?? "",
    category: member?.category === "leadership" ? "leadership" : "teacher",
    sortOrder: String(member?.sortOrder ?? 0),
    active: member?.active ?? true,
  };
}

function normalizeTeamMember(id: string, data: Record<string, unknown>): PublicSiteTeamMember {
  return {
    id,
    name: String(data.name ?? ""),
    role: String(data.role ?? ""),
    city: String(data.city ?? ""),
    education: String(data.education ?? ""),
    bio: String(data.bio ?? ""),
    languages: Array.isArray(data.languages) ? data.languages.map(String) : [],
    whyAlluwal: String(data.whyAlluwal ?? ""),
    imageUrl: data.imageUrl ? String(data.imageUrl) : null,
    photoAsset: data.photoAsset ? String(data.photoAsset) : null,
    linkedUserUid: data.linkedUserUid ? String(data.linkedUserUid) : null,
    category: String(data.category ?? "teacher"),
    sortOrder: Number(data.sortOrder ?? 0),
    active: data.active !== false,
  };
}

function upsertTeamMember(rows: PublicSiteTeamMember[], member: PublicSiteTeamMember) {
  const next = rows.filter((item) => item.id !== member.id);
  next.push(member);
  return next.sort((a, b) => a.sortOrder - b.sortOrder);
}

function emptySocialDoc(): PublicSiteSocialDoc {
  return {
    instagram: { enabled: false, url: "" },
    facebook: { enabled: false, url: "" },
    tiktok: { enabled: false, url: "" },
  };
}

function cleanPricingPlans(plans: Record<string, PublicSitePlanPricing>) {
  return Object.fromEntries(
    Object.entries(plans).map(([key, plan]) => [
      key,
      Object.fromEntries(Object.entries(plan).filter(([, value]) => value !== undefined)),
    ]),
  );
}

function initials(name: string) {
  return name
    .replace(/@.*/, "")
    .split(/[\s._-]+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
}

function capitalize(value: string) {
  return `${value.slice(0, 1).toUpperCase()}${value.slice(1)}`;
}
