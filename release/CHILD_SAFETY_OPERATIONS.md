# Jigu child safety report handling

Public standard: https://sanjaynewar7.github.io/Jigu-/child-safety.html  
Contact: Sanjaya Rajbhandari, sanjaynewar007@gmail.com

The in-app form writes to `public.child_safety_reports` in Supabase. Users can submit but cannot read, edit, or delete reports. The developer must review this table in the Supabase dashboard regularly; there is currently no automatic email alert for new reports.

For each report, record the review and action taken, remove prohibited content or restrict accounts when appropriate, and preserve and report information to relevant authorities when applicable law requires. Do not download or forward suspected abusive images. For immediate danger, direct the reporter to local emergency services. Confirm the applicable legal reporting procedure before certifying the Play Console legal-compliance statement.
