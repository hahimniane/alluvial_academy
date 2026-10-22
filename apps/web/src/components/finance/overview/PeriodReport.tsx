"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { money, money0 } from "@/lib/finance/model";
import { monthShort } from "@/lib/finance/months";
import { breakdownRows, isEstimate, marginPercent, otherCosts, rollups, sumMonths } from "@/lib/finance/overview";
import type { MonthSummary } from "@/lib/finance/summary";

/**
 * The printable report. It is not shown on screen: it sits directly under
 * <body> and the print stylesheet hides everything else, so "Report (PDF)"
 * prints (or saves as PDF) just this.
 */
const PRINT_CSS = `
.fin-report-print{display:none}
@media print{
  body>*:not(.fin-report-print){display:none!important}
  .fin-report-print{display:block;color:#000;background:#fff;font:12px/1.4 system-ui,-apple-system,"Segoe UI",sans-serif}
  .fin-report-print h1{font-size:20px;margin:0 0 2px}
  .fin-report-print h2{font-size:14px;margin:16px 0 6px;break-after:avoid}
  .fin-report-print p{margin:0 0 4px}
  .fin-report-print table{width:100%;border-collapse:collapse;break-inside:avoid}
  .fin-report-print th,.fin-report-print td{padding:4px 6px;border-bottom:1px solid #cbd5e1;text-align:right}
  .fin-report-print th:first-child,.fin-report-print td:first-child{text-align:left}
  .fin-report-print thead th{border-bottom:2px solid #475569}
  .fin-report-print tr.total td,.fin-report-print tr.total th{font-weight:700;border-top:2px solid #475569}
  .fin-report-print .muted{color:#475569}
  @page{margin:14mm}
}
`;

type Props = { title: string; rows: MonthSummary[]; generatedOn: string };

export function PeriodReport({ title, rows, generatedOn }: Props) {
  const [host, setHost] = useState<HTMLElement | null>(null);
  useEffect(() => {
    const el = document.createElement("div");
    el.className = "fin-report-print";
    document.body.appendChild(el);
    setHost(el);
    return () => {
      document.body.removeChild(el);
    };
  }, []);
  if (!host || rows.length === 0) return null;

  const n = rows.length;
  const t = sumMonths(rows);
  const parts = breakdownRows(rows);
  const groups = rollups(parts);
  const estimate = rows.some(isEstimate);
  const single = n === 1 ? rows[0] : null;

  return createPortal(
    <div>
      <style>{PRINT_CSS}</style>
      <h1>Alluwal Education Hub · Finance report</h1>
      <p>
        <strong>{title}</strong> <span className="muted">· prepared {generatedOn}</span>
      </p>
      {estimate ? <p className="muted">Figures marked estimate can still change.</p> : null}

      <h2>Summary</h2>
      <table>
        <tbody>
          <tr><td>Billed</td><td>{money(t.billed)}</td></tr>
          <tr><td>Collected</td><td>{money(t.collected)}</td></tr>
          <tr><td>Still owed</td><td>{money(t.owed)}</td></tr>
          <tr><td>Expenses</td><td>{money(t.expenses)}</td></tr>
          <tr className="total"><td>Profit{estimate ? " (estimate)" : ""}</td><td>{money(t.profit)}</td></tr>
          <tr><td>Margin</td><td>{marginPercent(t.profit, t.billed)}%</td></tr>
        </tbody>
      </table>

      {n > 1 ? (
        <>
          <h2>Month by month</h2>
          <table>
            <thead>
              <tr>
                <th>Month</th><th>Billed</th><th>Collected</th><th>Teacher pay</th><th>Administrator pay</th><th>Other costs</th><th>Expenses</th><th>Profit</th><th>Margin</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.month}>
                  <td>{monthShort(r.month)}{isEstimate(r) ? " (est.)" : ""}</td>
                  <td>{money0(r.billed)}</td><td>{money0(r.collected)}</td><td>{money0(r.teacher_pay)}</td>
                  <td>{money0(r.admin_pay)}</td><td>{money0(otherCosts(r))}</td><td>{money0(r.expenses)}</td>
                  <td>{money0(r.profit)}</td><td>{marginPercent(r.profit, r.billed)}%</td>
                </tr>
              ))}
              <tr className="total">
                <td>Total</td><td>{money0(t.billed)}</td><td>{money0(t.collected)}</td><td>{money0(t.teacher_pay)}</td>
                <td>{money0(t.admin_pay)}</td><td>{money0(t.otherCosts)}</td><td>{money0(t.expenses)}</td>
                <td>{money0(t.profit)}</td><td>{marginPercent(t.profit, t.billed)}%</td>
              </tr>
              <tr>
                <td>Average a month</td><td>{money0(t.billed / n)}</td><td>{money0(t.collected / n)}</td><td>{money0(t.teacher_pay / n)}</td>
                <td>{money0(t.admin_pay / n)}</td><td>{money0(t.otherCosts / n)}</td><td>{money0(t.expenses / n)}</td>
                <td>{money0(t.profit / n)}</td><td />
              </tr>
            </tbody>
          </table>
        </>
      ) : null}

      <h2>Where the money went</h2>
      <table>
        <tbody>
          {parts.map((p) => (
            <tr key={p.category}>
              <td>{p.label} <span className="muted">· {p.group}{p.estimate ? " · estimate" : ""}</span></td>
              <td>{money(p.amount)}</td>
            </tr>
          ))}
          {groups.map((g, i) => (
            <tr key={g.group} className={i === 0 ? "total" : undefined}>
              <td>{g.group}</td><td>{money0(g.amount)}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <h2>Other figures</h2>
      <table>
        <tbody>
          <tr><td>Penalties taken from teachers</td><td>{money(t.penalties)}</td></tr>
          <tr><td>Discounts given</td><td>{money(t.discounts)}</td></tr>
          <tr><td>Credit owed to families today</td><td>{money(rows[rows.length - 1].credit_open)}</td></tr>
        </tbody>
      </table>

      {single && single.teachers.length > 0 ? (
        <>
          <h2>Teacher pay</h2>
          <table>
            <thead>
              <tr><th>Teacher</th><th>Hours</th><th>Earned</th><th>Penalties</th><th>Pay</th><th>Status</th></tr>
            </thead>
            <tbody>
              {single.teachers.map((x) => (
                <tr key={x.uid}>
                  <td>{x.name}</td><td>{x.hours}</td><td>{money(x.gross)}</td><td>{x.penalties > 0 ? `−${money(x.penalties)}` : "—"}</td>
                  <td>{money(x.net)}</td><td>{x.final ? "Final" : "Estimate"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      ) : null}

      {single && single.admins.length > 0 ? (
        <>
          <h2>Administrator pay</h2>
          <table>
            <thead>
              <tr><th>Administrator</th><th>Fixed</th><th>Share</th><th>Total</th></tr>
            </thead>
            <tbody>
              {single.admins.map((a) => (
                <tr key={a.uid}>
                  <td>{a.name}{a.role_title ? ` · ${a.role_title}` : ""}{a.paused ? " · paused" : ""}</td>
                  <td>{money(a.fixed)}</td><td>{a.pct > 0 ? `${a.pct}% · ${money(a.share)}` : "—"}</td><td>{money(a.total)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      ) : null}
    </div>,
    host,
  );
}
