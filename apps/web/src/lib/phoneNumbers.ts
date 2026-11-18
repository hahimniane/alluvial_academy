/**
 * Phone numbers typed on the admin Users page: a country picker plus the
 * national number, checked per country and stored in E.164 (`+224621123456`).
 *
 * The Flutter screen checks with libphonenumber metadata. The web has no such
 * package, so the countries the school works with carry their national
 * lengths (and, where they matter, the leading digits) from that metadata;
 * every other country gets the general rule Flutter shows: 4–15 digits.
 */

export type Country = {
  iso: string;
  name: string;
  /** Dialling code digits, no plus. */
  dial: string;
};

type Rule = {
  /** Allowed national lengths (without the trunk 0). */
  lengths: readonly number[];
  /** Optional pattern the national digits must match. */
  pattern?: RegExp;
  /** The leading 0 written inside the country is part of the number (Italy). */
  keepsLeadingZero?: boolean;
};

// iso|dial|name, one per country.
const COUNTRY_TABLE = `
AF|93|Afghanistan;AL|355|Albania;DZ|213|Algeria;AD|376|Andorra;AO|244|Angola;AG|1|Antigua and Barbuda;AR|54|Argentina;
AM|374|Armenia;AU|61|Australia;AT|43|Austria;AZ|994|Azerbaijan;BS|1|Bahamas;BH|973|Bahrain;BD|880|Bangladesh;BB|1|Barbados;
BY|375|Belarus;BE|32|Belgium;BZ|501|Belize;BJ|229|Benin;BT|975|Bhutan;BO|591|Bolivia;BA|387|Bosnia and Herzegovina;
BW|267|Botswana;BR|55|Brazil;BN|673|Brunei;BG|359|Bulgaria;BF|226|Burkina Faso;BI|257|Burundi;CV|238|Cabo Verde;
KH|855|Cambodia;CM|237|Cameroon;CA|1|Canada;CF|236|Central African Republic;TD|235|Chad;CL|56|Chile;CN|86|China;
CO|57|Colombia;KM|269|Comoros;CG|242|Congo;CD|243|Congo (DRC);CR|506|Costa Rica;CI|225|Côte d'Ivoire;HR|385|Croatia;
CU|53|Cuba;CY|357|Cyprus;CZ|420|Czechia;DK|45|Denmark;DJ|253|Djibouti;DM|1|Dominica;DO|1|Dominican Republic;EC|593|Ecuador;
EG|20|Egypt;SV|503|El Salvador;GQ|240|Equatorial Guinea;ER|291|Eritrea;EE|372|Estonia;SZ|268|Eswatini;ET|251|Ethiopia;
FJ|679|Fiji;FI|358|Finland;FR|33|France;GA|241|Gabon;GM|220|Gambia;GE|995|Georgia;DE|49|Germany;GH|233|Ghana;GR|30|Greece;
GD|1|Grenada;GT|502|Guatemala;GN|224|Guinea;GW|245|Guinea-Bissau;GY|592|Guyana;HT|509|Haiti;HN|504|Honduras;HK|852|Hong Kong;
HU|36|Hungary;IS|354|Iceland;IN|91|India;ID|62|Indonesia;IR|98|Iran;IQ|964|Iraq;IE|353|Ireland;IL|972|Israel;IT|39|Italy;
JM|1|Jamaica;JP|81|Japan;JO|962|Jordan;KZ|7|Kazakhstan;KE|254|Kenya;KW|965|Kuwait;KG|996|Kyrgyzstan;LA|856|Laos;LV|371|Latvia;
LB|961|Lebanon;LS|266|Lesotho;LR|231|Liberia;LY|218|Libya;LI|423|Liechtenstein;LT|370|Lithuania;LU|352|Luxembourg;
MG|261|Madagascar;MW|265|Malawi;MY|60|Malaysia;MV|960|Maldives;ML|223|Mali;MT|356|Malta;MR|222|Mauritania;MU|230|Mauritius;
MX|52|Mexico;MD|373|Moldova;MC|377|Monaco;MN|976|Mongolia;ME|382|Montenegro;MA|212|Morocco;MZ|258|Mozambique;MM|95|Myanmar;
NA|264|Namibia;NP|977|Nepal;NL|31|Netherlands;NZ|64|New Zealand;NI|505|Nicaragua;NE|227|Niger;NG|234|Nigeria;
MK|389|North Macedonia;NO|47|Norway;OM|968|Oman;PK|92|Pakistan;PS|970|Palestine;PA|507|Panama;PG|675|Papua New Guinea;
PY|595|Paraguay;PE|51|Peru;PH|63|Philippines;PL|48|Poland;PT|351|Portugal;PR|1|Puerto Rico;QA|974|Qatar;RO|40|Romania;
RU|7|Russia;RW|250|Rwanda;KN|1|Saint Kitts and Nevis;LC|1|Saint Lucia;VC|1|Saint Vincent and the Grenadines;SM|378|San Marino;
ST|239|São Tomé and Príncipe;SA|966|Saudi Arabia;SN|221|Senegal;RS|381|Serbia;SC|248|Seychelles;SL|232|Sierra Leone;
SG|65|Singapore;SK|421|Slovakia;SI|386|Slovenia;SO|252|Somalia;ZA|27|South Africa;KR|82|South Korea;SS|211|South Sudan;
ES|34|Spain;LK|94|Sri Lanka;SD|249|Sudan;SR|597|Suriname;SE|46|Sweden;CH|41|Switzerland;SY|963|Syria;TW|886|Taiwan;
TJ|992|Tajikistan;TZ|255|Tanzania;TH|66|Thailand;TL|670|Timor-Leste;TG|228|Togo;TT|1|Trinidad and Tobago;TN|216|Tunisia;
TR|90|Türkiye;TM|993|Turkmenistan;UG|256|Uganda;UA|380|Ukraine;AE|971|United Arab Emirates;GB|44|United Kingdom;
US|1|United States;UY|598|Uruguay;UZ|998|Uzbekistan;VE|58|Venezuela;VN|84|Vietnam;YE|967|Yemen;ZM|260|Zambia;ZW|263|Zimbabwe`;

export const COUNTRIES: readonly Country[] = COUNTRY_TABLE.split(";")
  .map((entry) => entry.trim())
  .filter(Boolean)
  .map((entry) => {
    const [iso, dial, name] = entry.split("|");
    return { iso, dial, name };
  });

/** Shown first in the picker: where the school's families and staff are. */
export const COMMON_COUNTRY_ISOS = ["US", "GN", "SL", "CA", "FR", "GB", "SN", "ML", "CI", "GM", "LR", "GW", "MR", "SA", "AE"] as const;

export const DEFAULT_COUNTRY_ISO = "US";

const NANP: Rule = { lengths: [10], pattern: /^[2-9]\d{2}[2-9]\d{6}$/ };

const RULES: Record<string, Rule> = {
  US: NANP,
  CA: NANP,
  PR: NANP,
  GN: { lengths: [9], pattern: /^(?:3\d|6\d)\d{7}$/ },
  SL: { lengths: [8] },
  SN: { lengths: [9], pattern: /^[37]\d{8}$/ },
  ML: { lengths: [8] },
  CI: { lengths: [10] },
  GM: { lengths: [7] },
  GW: { lengths: [7, 9] },
  LR: { lengths: [7, 8, 9] },
  MR: { lengths: [8] },
  NG: { lengths: [8, 10] },
  GH: { lengths: [9] },
  CM: { lengths: [9] },
  BF: { lengths: [8] },
  NE: { lengths: [8] },
  TG: { lengths: [8] },
  BJ: { lengths: [8, 10] },
  CD: { lengths: [9] },
  KE: { lengths: [9] },
  MA: { lengths: [9] },
  EG: { lengths: [8, 9, 10] },
  FR: { lengths: [9], pattern: /^[1-9]\d{8}$/ },
  GB: { lengths: [9, 10] },
  BE: { lengths: [8, 9] },
  NL: { lengths: [9] },
  ES: { lengths: [9] },
  PT: { lengths: [9] },
  CH: { lengths: [9] },
  IT: { lengths: [6, 7, 8, 9, 10, 11], keepsLeadingZero: true },
  DE: { lengths: [6, 7, 8, 9, 10, 11, 12, 13] },
  SA: { lengths: [8, 9] },
  AE: { lengths: [8, 9] },
  QA: { lengths: [8] },
  KW: { lengths: [8] },
  TR: { lengths: [10] },
};

const GENERAL: Rule = { lengths: [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15] };

export const digitsOf = (value: string): string => value.replace(/\D/g, "");

export const countryByIso = (iso: string): Country | undefined => COUNTRIES.find((c) => c.iso === iso.toUpperCase());

export const countryLabel = (c: Country) => `${c.name} +${c.dial}`;

/**
 * The national digits of what was typed, ready to follow the dialling code:
 * separators gone, the trunk 0 dropped (except where it belongs to the number),
 * and the dialling code dropped when it was typed or pasted in front.
 */
export function nationalDigits(iso: string, typed: string): string {
  const country = countryByIso(iso);
  const rule = RULES[iso.toUpperCase()] ?? GENERAL;
  const raw = typed.trim();
  let digits = digitsOf(raw);
  if (!country) return digits;
  const max = Math.max(...rule.lengths);
  if (raw.startsWith("+") || raw.startsWith("00")) {
    if (raw.startsWith("00")) digits = digits.slice(2);
    if (digits.startsWith(country.dial)) digits = digits.slice(country.dial.length);
  } else if (digits.length > max && digits.startsWith(country.dial)) {
    digits = digits.slice(country.dial.length);
  }
  if (!rule.keepsLeadingZero && digits.startsWith("0")) digits = digits.replace(/^0+/, "");
  return digits;
}

/** Empty is fine (the phone is optional); otherwise the number must suit the country. */
export function phoneProblem(iso: string, typed: string): string | null {
  if (digitsOf(typed) === "") return null;
  const country = countryByIso(iso);
  if (!country) return "Pick the phone's country.";
  const rule = RULES[country.iso] ?? GENERAL;
  const national = nationalDigits(country.iso, typed);
  const ok = rule.lengths.includes(national.length) && (!rule.pattern || rule.pattern.test(national));
  if (ok) return null;
  if (!RULES[country.iso]) return "Use 4–15 digits after the country code.";
  return `Not a valid ${country.name} number (+${country.dial}).`;
}

/** `+<dial><national>`, or "" when nothing was typed. Only call after phoneProblem() is null. */
export function toE164(iso: string, typed: string): string {
  if (digitsOf(typed) === "") return "";
  const country = countryByIso(iso);
  if (!country) return "";
  return `+${country.dial}${nationalDigits(country.iso, typed)}`;
}

/** `+224` for the picker's country. */
export const dialCodeOf = (iso: string): string => {
  const country = countryByIso(iso);
  return country ? `+${country.dial}` : "+1";
};

/**
 * Every E.164 form a stored phone could stand for, to compare a new number
 * with the people already here. Stored numbers come in many shapes: E.164,
 * `+1(555) 123-4567`, national digits beside a separate country code (with or
 * without its plus), `00` prefixes, a leading trunk 0.
 */
export function storedPhoneForms(phone: string, countryCode: string): string[] {
  const raw = phone.trim();
  const digits = digitsOf(raw);
  if (digits.length < 4) return [];
  const forms = new Set<string>();
  if (raw.startsWith("+")) forms.add(`+${digits}`);
  else if (raw.startsWith("00")) forms.add(`+${digits.slice(2)}`);
  else {
    const cc = digitsOf(countryCode);
    const national = digits.replace(/^0+/, "");
    if (cc) {
      forms.add(`+${cc}${national}`);
      if (cc === "39") forms.add(`+${cc}${digits}`);
      if (digits.startsWith(cc)) forms.add(`+${digits}`);
    } else {
      forms.add(`+${digits}`);
      // Flutter's form defaulted to +1 when no country was stored.
      if (national.length === 10) forms.add(`+1${national}`);
    }
  }
  return [...forms];
}
