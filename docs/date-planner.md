# Date planner

- UI: `lib/features/date_planner/`; shared state: `DatePlannerController`.
- Persistence and discovery: `DatePlannerService`; data: `DateInvitation`.
- `date_invitations` stores UTC time, venue, meeting address, dress style, message and response. Both active members can read; only the sender inserts, only the partner accepts/declines, and the sender cancels. Leaving a space removes access without signing out.
- The centre navigation button opens the gallery/camera chooser directly. Dates is the next tab to its right.
- `date-discovery` validates the signed-in user and current membership. `GEOAPIFY_API_KEY` is an Edge Function secret, never an app asset.
- Discovery gets a fresh permitted device position, reverse-geocodes the city, and searches four activity groups. 15 km searches use the centre; 50/100 km searches also sample four surrounding sectors. Results are deduplicated, ranked by distance/address completeness, and interleaved by activity and nearby/further-away bands. A 15-minute ephemeral cache reduces API usage; an uncached wider search uses 21 provider requests.
- Coverage depends on Geoapify/OpenStreetMap. Searches are bounded-radius suggestions, not exhaustive administrative-district scans. Scenic destinations are not verified driving routes, and opening hours/bookings are not guaranteed. Distances are straight-line estimates.
- No partner-location sharing is enabled by discovering places. The search uses only the requesting phone's permission.
- Tests: `tool/test_date_invitations.sql` rolls back all changes; `tool/test_date_discovery.py [radius]` creates/removes synthetic accounts and exercises the deployed endpoint without logging credentials. `test/date_planner_test.dart` covers centre capture action and narrow-screen invitations.
