# Invoice naming and numbering decision

Date: 2026-08-06

## Decision

Securiace is not GST-registered today and predominantly sells prepaid hosting,
infrastructure, security, and management services. The approved WHMCS lifecycle
is therefore:

| Lifecycle | Client-facing document | Reference | Payment content |
| --- | --- | --- | --- |
| Outstanding, before due date | Proforma Invoice | `PI/<WHMCS invoice ID>` | Bank instructions and amount-bound UPI only for confirmed INR |
| Outstanding, after due date | Proforma Invoice with `OVERDUE` state | Same `PI/<WHMCS invoice ID>` | Same payment methods; red overdue treatment and days overdue |
| Paid | Invoice | WHMCS sequential `ST/{NUMBER}` | Receipt, transaction evidence, and authorization; no UPI or remittance instructions |
| International service client | Same lifecycle and numbering | Same series | No UPI unless the WHMCS model explicitly confirms INR |

“Commercial Invoice” is not the default title. Securiace currently sells
services rather than exporting physical goods through customs. If a foreign
client specifically requires commercial-invoice wording, it can be added as a
secondary subtitle or supplied as a controlled exception without changing the
WHMCS accounting identity.

While Securiace remains unregistered, final documents are titled `Invoice`, not
`Tax Invoice`; they must not show a Securiace GSTIN or collect an amount as GST.
Section 32 of the CGST Act prohibits a person who is not registered from
collecting tax under the Act. PAN and MSME/Udyam identifiers remain visible as
business-registration details and are not presented as GST credentials.

## Why the references differ

WHMCS keeps one immutable internal invoice record. While that record is a
proforma, the template exposes a readable `PI/<invoice ID>` reference. On
payment, WHMCS assigns its stored sequential `$invoicenum`, and the final PDF
retains the original `PI/<invoice ID>` as traceability metadata.

This avoids a custom proforma counter, database table, hook race, duplicate
number, or reconciliation split. A proforma is not the statutory tax invoice,
so its reference does not consume the final invoice sequence.

## Approved WHMCS settings

- Enable Proforma Invoicing: enabled.
- Sequential Paid Invoice Numbering: enabled.
- Sequential Invoice Number Format: `ST/{NUMBER}`.
- Next Paid Invoice Number: preserve the current value; never renumber existing
  documents and never reset the counter during this migration.
- Auto Reset Paid Numbering: `Never`.
- Set Invoice Date on Payment: enabled so the final invoice issue date matches
  the event that assigns its final number.
- Tax Support: remains disabled until Securiace obtains GST registration and its
  tax rules, rates, place-of-supply data, and export treatment are configured.

Changing the format affects only future paid numbers. Existing final invoice
numbers remain unchanged in WHMCS.

## GST number rule and format capacity

Rule 46(b) of the CGST Rules requires a registered supplier's tax-invoice serial
to be:

- consecutive;
- no more than 16 characters in total;
- in one or multiple series;
- made from letters, numerals, hyphen/dash, slash, or a combination of them;
- unique for the Indian financial year.

The approved `ST/{NUMBER}` format uses three fixed characters. It therefore
allows a numeric part of up to 13 digits before reaching the 16-character
ceiling. For example, `ST/2070` is 7 characters. A continuous sequence with no
reset remains consecutive and unique inside every financial year without an
April-specific automation hook.

An Indian-financial-year format such as `ST/26-27/000001` is also 15 characters
and can be compliant, but WHMCS only exposes calendar `{YEAR}`, `{MONTH}`,
`{DAY}`, and `{NUMBER}` tags. Producing an April-to-March prefix would require a
manual annual control or custom hook, adding failure modes without a legal need.

## GST-registration transition gate

Before enabling GST in WHMCS:

1. Confirm the GSTIN, registration state, legal name, address, and applicable
   e-invoicing threshold with the accountant.
2. Configure SAC/HSN, place of supply, CGST/SGST/IGST treatment, recipient GSTIN,
   reverse-charge flag, and export-of-services wording where applicable.
3. Confirm whether exports operate under LUT without IGST or with IGST payment.
4. Confirm every product using the Proforma-to-Paid lifecycle is genuinely
   prepaid. GST service invoices generally cannot be deferred until payment when
   the service has already been supplied; postpaid/manual work needs a final tax
   invoice based on the supply event.
5. Keep `ST/{NUMBER}` and its current next value unless the accountant directs a
   controlled new series. Do not rewrite historical numbers.
6. Re-test domestic B2B/B2C, inter-state, export, credit/debit-note, cancellation,
   refund, batch, email attachment, and PDF download paths.

At registration, the final titles become `Tax Invoice` for domestic taxable
supplies and `Tax Invoice — Export of Services` (or accountant-approved export
wording) for applicable exports. The pre-supply payment request remains a
Proforma Invoice.

## Primary sources

- CBIC CGST Act, including section 32 on unauthorised tax collection:
  <https://cbic-gst.gov.in/hindi/CGST-bill-e.html>
- CBIC CGST Rule 46 invoice particulars:
  <https://cbic-gst.gov.in/pdf/01072020_CGST-Rules-2017-Part-A-Rules.pdf>
- GST portal taxpayer welcome kit and mandatory invoice fields:
  <https://tutorial.gst.gov.in/downloads/news/welcome_kit_for_new_taxpyers.pdf>
- CBIC service invoice timing:
  <https://cbic-gst.gov.in/gst-invoice-rules.html>
- WHMCS Proforma Invoicing and sequential paid numbering:
  <https://docs.whmcs.com/9-0/billing-and-invoicing/invoicing-tutorials/enable-proforma-invoicing/>
- WHMCS supported invoice number tags:
  <https://docs.whmcs.com/9-0/billing-and-invoicing/invoice-configuration/>
- International Trade Administration commercial-invoice purpose:
  <https://www.trade.gov/commercial-invoice>

This is an implementation and operational-control decision, not tax or legal
advice. GST activation must be reviewed against Securiace's registration and
actual supply model.
