# Partner summaries, as Crewlu Cloud gives them to each partner

What `partner_view` answers as `status` for CrewLu's nine example summaries
(`~/Dev/Duty/supabase/partner-status/examples/`): `<example>.A.json` for partner A
(`aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`) and `<example>.B.json` for partner B
(`bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb`).

They come from Crewlu Cloud's own trimming, `private.trim_status_for`, run in the local test
database of `~/Dev/Duty/supabase/tests` by `trim-examples.mjs` (partner links plan 4a, Task 2),
with keys sorted. When CrewLu's examples change, make them again the same way.

`CloudSummaryTests` reads them.
