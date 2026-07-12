const publicPrefixes = [
  "/about",
  "/programs",
  "/team",
  "/contact",
  "/enroll",
  "/teacher-application",
  "/leadership-application",
  "/privacy-policy",
];

export function isPublicMarketingPath(pathname: string) {
  if (pathname === "/") return true;
  return publicPrefixes.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}
