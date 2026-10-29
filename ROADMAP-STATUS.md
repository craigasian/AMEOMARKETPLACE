# AMEO Marketplace — Roadmap status

Updated October 29, 2026. This is a working test release, not a completed public launch.

**Done** means implemented and checked. **Partial** identifies exactly what remains. **Deferred** means intentionally excluded now. **Not started** means no implementation is claimed.

| Phase | Original roadmap item | Status | What exists / what remains |
|---|---|---|---|
| 1 | Home | Done | Live categories, approved professionals, application entry; no fabricated testimonials. |
| 1 | How It Works | Done | Client and professional flows. |
| 1 | Become a Pro | Done | Application entry and review explanation. |
| 1 | About, FAQ, Contact | Done | Basic trust, testing FAQs, support email. |
| 1 | Legal | Partial | Preview operating/privacy notes only. Final Terms, Privacy, Pro Agreement, Refund Policy still needed. |
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
| 1 | Messaging | Partial | Persisted, participant-only project chat; manual refresh. Attachments and live updates remain. |
| 1 | Reviews and ratings | Done | One client review per completed project; early/duplicate reviews blocked. |
| 2 | Notifications | Not started | Marketplace email/SMS/in-app alerts remain. Auth email is separate. |
| 2 | Video links on bookings | Not started | Meeting link integration remains. |
| 2 | Disputes | Not started | Reporting and resolution workflow remains. |
| 1 | Pro approval queue | Done | Approve/reject/suspend, edits return to review, audit trail. |
| 1 | Users and listings | Partial | User suspension/restoration and listing moderation work. Admin editing and category/city management remain. |
| 2 | Payments and refunds | Deferred | Stripe deferred; no payment/refund processing. |
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

## Suggested next work

1. Owner creates/verifies account and completes display name; verify admin menu appears.
2. Confirm production email delivery/custom SMTP, then Google sign-in if desired.
3. Finalize legal documents before a real commercial launch.
4. Complete chat attachments/live updates and remaining admin controls.
5. Onboard real professionals and approve their listings.
6. Add Stripe only when owner is ready; then Phase 2 growth features.
