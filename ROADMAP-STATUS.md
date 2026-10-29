# AMEO Marketplace — Roadmap status

Updated October 29, 2026 (evening). This is a working test release, not a completed public launch.

**Done** means implemented and checked. **Partial** identifies exactly what remains. **Deferred** means intentionally excluded now. **Not started** means no implementation is claimed.

| Phase | Original roadmap item | Status | What exists / what remains |
|---|---|---|---|
| 1 | Home | Done | Live categories, approved professionals, application entry; no fabricated testimonials. |
| 1 | How It Works | Done | Client and professional flows. |
| 1 | Become a Pro | Done | Application entry and review explanation. |
| 1 | About, FAQ, Contact | Done | Basic trust, testing FAQs, support email. |
| 1 | Legal | Done | Full Terms of Service, Privacy Policy, Professional Services Agreement, and Quotes/Bookings/Cancellation & Refunds policy published on the Legal page. Clear “payments not enabled” language retained for the test release. |
| 2 | Category pages | Not started | Category filters work; dedicated SEO pages remain. |
| 2 | City pages | Not started | City filters work; dedicated SEO pages remain. |
| 3 | Blog and resources | Not started | Guides, case studies, resource publishing remain. |
| 1 | Search results | Done | Search, service, city, delivery format, price, rating filters. |
| 1 | Pro profile | Done | Bio, service category, credentials, location, rate, completed-job reviews, quote/message entry. |
| 2 | Package detail pages | Not started | Fixed-price service packages remain. |
| 3 | Saved favorites | Not started | Shortlisting remains. |
| 1 | Quote request | Done | Client brief, professional scope and price, client acceptance/decline. |
| 1 | Checkout | Deferred | Stripe explicitly postponed by owner. No charges or fund-holding. |
| 2 | Instant booking | Partial | Quote-based time requests, pro confirmation, conflict rejection, cancellation work. Package-based instant booking/calendar remains. |
| 3 | Milestone payments | Not started | Requires payments first. |
| 1 | Sign up and log in | Partial | Email/password, verified-email enforcement, reset/update password implemented; Google disabled in Supabase and not wired in UI. SMTP delivery not end-to-end verified. |
| 1 | Client dashboard | Done | Projects, quote status, messaging, booking, completion, reviews. |
| 3 | Company profile and team seats | Not started | Multi-user company accounts remain. |
| 1 | Pro onboarding | Partial | Profile, service category, service area, rate, credentials, application and admin review work. Automated identity/credential verification and payout setup remain. |
| 1 | Pro dashboard | Partial | Assigned projects, quote responses, messaging, booking confirmation work. Earnings/payouts depend on Stripe. |
| 2 | Calendar sync | Not started | Google/Outlook availability sync remains. |
| 2 | Profile analytics | Not started | Views, leads, conversion reporting remain. |
| 3 | Paid tiers | Not started | Featured placement, subscriptions, verified tiers remain. |
| 1 | Messaging | Partial | Persisted, participant-only project chat with **live updates** (Supabase Realtime) and **attachment links**. Full file-upload storage + attachment column still optional; currently attachments are shared as URLs embedded in the message. |
| 1 | Reviews and ratings | Done | One client review per completed project; early/duplicate reviews blocked. |
| 2 | Notifications | Not started | Marketplace email/SMS/in-app alerts remain. Auth email is separate. |
| 2 | Video links on bookings | Not started | Meeting link integration remains. |
| 2 | Disputes | Not started | Reporting and resolution workflow remains. |
| 1 | Pro approval queue | Done | Approve/reject/suspend, edits return to review, audit trail. |
| 1 | Users and listings | Partial | User suspension/restoration and listing moderation work. Admin “Edit listing” UI added; full field update still needs a small `market_action` extension (or pro re-submission). Category/city lists remain code constants. |
| 2 | Payments and refunds | Deferred | Stripe deferred; no payment/refund processing. Refund policy text is published for future use. |
| 2 | Moderation and promos | Not started | Review moderation, featured listings, promo codes remain. Listing moderation already exists. |
| 3 | Marketplace analytics | Not started | Revenue, take rate, category reporting remain. |

## Additional implementation work

- Secure client/pro/admin roles enforced by the database; user-editable metadata cannot grant admin.
- Verified `craigasian@gmail.com` becomes admin when creating its marketplace profile. Owner registration and email verification are still a user step.
- Original CRM tables retained. No AMEO Dental changes; no aimadeeasyoc.com changes.
- Branding corrected to the existing AI Made Easy OC logo, navy/ocean blue/orange palette, Poppins/Open Sans.
- Test accounts, listing, projects, messages, booking, and review were removed after testing.
- Directory intentionally starts empty until real professionals are onboarded and approved.
- Public access authorized by owner after initial private deployment. Search indexing remains disabled during testing.
- **2026-10-29 evening update:** Legal documents finalized on the public Legal page. Messaging gained live Realtime subscription + attachment-link support. Admin gained an Edit listing entry point.

## Suggested next work

1. Owner creates/verifies account and completes display name; verify admin menu appears.
2. Confirm production email delivery/custom SMTP, then Google sign-in if desired.
3. Enable Realtime on `market_messages` in the Supabase dashboard (Publication → supabase_realtime) so live chat indicators stay green.
4. Optional: add an `attachment` text column + storage bucket, or keep URL-in-body approach.
5. Optional: extend `market_action` with an `admin_edit_listing` action so the new Edit UI can persist field changes without pro re-submission.
6. Onboard real professionals and approve their listings.
7. Add Stripe only when owner is ready; then Phase 2 growth features.
