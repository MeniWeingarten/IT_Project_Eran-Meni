# SOURCE.md — Data Source Proposals

## Prompt used (AI assistance)

This file was written with the help of an AI tool (Claude), using the following prompt:

```text
Attached is the project document for my "IT Fundamentals" course. Read it,
especially the section on what makes a good data source (the six rules) and
the four pairing types.

Based on that document, create a file named SOURCE.md with two proposals for
data sources for my project. Write the entire file in English.

The two proposals:
1. Ben Gurion Airport flight delays and weather: the live flight board from
   data.gov.il, paired with METAR weather reports from aviationweather.gov for
   Ben Gurion and destination airports.
2. Do Steam sales wake up a game's community? For 20–30 games on Steam with
   an official Discord server: the number of community members online right
   now (Discord invite API), together with what the Israeli Steam store
   promotes (top sellers, specials, daily deal), each game's price and
   discount, and its current player count from the Steam Web API.

For each proposal, include:
- A short paragraph explaining what the data is and what we want to learn
  from it
- The content: what fields the data contains
- The exact URL(s) to request
- How often the source updates, and how often we plan to sample it
- The expected size of a single sample
- Whether a key, password or account is required
- One real data sample, taken from an actual call to the source

Check each proposal against the six rules in the document, and add a warnings
section for anything that doesn't fully meet them.

End the file with a ranking of the two proposals: which one we prefer and why.
```

All sources below were tested from Israel on 2026-11-08, with no account and no key. The samples are real responses from that day.

---

## Proposal 1 (preferred): Ben Gurion flight delays — the weather here or there?

### Summary
The Ben Gurion Airport flight board shows, for every flight, a scheduled time, an updated time and a status (on time, delayed, departed, landed, canceled). We will collect the board throughout the semester, together with the official weather reports for Ben Gurion **and for destination airports** (e.g., Athens, Larnaca, Frankfurt, London). The main question: **when a flight is late, is the cause the weather here, the weather at the destination, or neither?**

**Pairing type:** signal and context (the board is the signal, the weather is the context). The board itself also gives forecast vs. reality: the announced time vs. the final time.

**Research questions:**
- Do rain, strong wind or low visibility at Ben Gurion increase the average delay?
- Does destination weather predict delays better than Ben Gurion weather?
- When does the board "admit" a delay: hours in advance, or at the last minute?
- Which airlines and destinations are late most often, and at what times?
- At which hours and on which days are there the most cancellations?

### Content
Main fields in the flight board:

| Field | Meaning |
|---|---|
| `CHOPER`, `CHOPERD` | Airline code and name |
| `CHFLTN` | Flight number |
| `CHAORD` | Arrival (A) or departure (D) |
| `CHSTOL` | Scheduled time |
| `CHPTOL` | Updated time |
| `CHLOC1`, `CHLOC1T` | Destination/origin airport code and city |
| `CHLOCCT` | Destination/origin country |
| `CHRMINE` | Status (ON TIME, DELAYED, DEPARTED, LANDED, CANCELED, ...) |
| `CHTERM` | Terminal |

METAR reports include temperature, wind speed and gusts, visibility, and weather conditions (rain, fog, etc.).

### URLs
| Source | URL |
|---|---|
| Flight board (data.gov.il, Israel Airports Authority) | `https://data.gov.il/api/3/action/datastore_search?resource_id=e83f763b-b7d7-479e-b172-ae981ddc6de5&limit=5000` |
| Weather (METAR) | `https://aviationweather.gov/api/data/metar?ids=LLBG,LGAV,LCLK,EDDF,EGLL&format=json` |

### Update frequency
- **Flight board:** updates about every 15 minutes (stated in the dataset's description), and statuses change constantly.
- **METAR:** a new report every 30 minutes, and more often when the weather changes sharply.

**Planned sampling rate: every 15 minutes.**

### Expected size per sample
- **Full flight board:** about 770 KB per call (2,268 flights, from yesterday to 3 days ahead). That's too large to store in full, so **we will keep only flights scheduled between 3 hours ago and 12 hours ahead**: about 300 flights, about 110 KB per sample.
- **METAR for 5–10 airports:** about 5 KB per sample.
- **Total:** about 115 KB per sample.

Semester estimate: 96 samples a day × 70 days ≈ 6,700 samples ≈ 770 MB before compression, roughly 80–100 MB after gzip. If needed, we can sample every 30 minutes instead (about 390 MB even without compression).

### Key / password
**None required.** Both sources are public and can be downloaded with a single `curl` command.

### Data sample
**Flight board** (one record out of 2,268, sampled on 2026-11-08 at about 17:10 UTC):
```json
{
  "CHOPER": "A3",
  "CHOPERD": "AEGEAN  AIRLINES",
  "CHFLTN": "927",
  "CHAORD": "D",
  "CHSTOL": "2026-11-07T19:10:00",
  "CHPTOL": "2026-11-07T19:22:00",
  "CHLOC1": "ATH",
  "CHLOC1T": "ATHENS",
  "CHLOCCT": "GREECE",
  "CHTERM": 3,
  "CHRMINE": "DEPARTED"
}
```
A flight to Athens scheduled for 19:10 that left at 19:22: a 12-minute delay.

Status distribution on the board at that moment: 829 on time, 817 not final, 288 departed, 258 landed, 48 final, 24 canceled, 3 landing, 1 delayed.

**METAR for Ben Gurion** (17:00 UTC the same evening):
```json
{
  "reportTime": "2026-11-08T17:00:00.000Z",
  "temp": 19,
  "wspd": 9,
  "visib": "6+",
  "rawOb": "METAR LLBG 081650Z 02009KT 9999 FEW050 19/12 Q1021 NOSIG RMK SCT057"
}
```
That is: 19°C, wind 9 knots from the north-northeast, visibility over 10 km, a few clouds.

### Check against the six rules
1. **Lost week:** ✅ Flights drop off the board about a day and a half after their scheduled time, and the updated time and status are overwritten on every refresh. What the board showed at each moment is not saved anywhere. Weather reports are archived, but they serve only as context.
2. **Ten samples:** ✅ The board updates every 15 minutes and statuses change constantly.
3. **Command:** ✅ One `curl` command per source, no browser, no login, no payment.
4. **Permission:** ⚠️ See below.
5. **Size:** ✅ Under 500 MB with the time-window filter and compression.
6. **Interest:** ✅ A local, everyday topic with a question that has no obvious answer.

**Permission rule details:**
- **aviationweather.gov:** there is no robots.txt (it returns 404), so there are no restrictions. The official API page invites automated use, with a limit of 100 requests per minute, and asks clients to set a custom User-Agent. We will send one request every 15 minutes with a project User-Agent:
  ```bash
  curl -A "ben-gurion-delays-student-project" "https://aviationweather.gov/api/data/metar?ids=LLBG&format=json"
  ```
- **data.gov.il:** the dataset's license is "Other (Open)" and its publisher is the Israel Airports Authority. However, the site's robots.txt includes `Disallow: /api/`, and our URL is under `/api/`. We believe this is the portal's official, documented interface for programmatic access to open datasets, and that robots.txt mainly targets search-engine crawlers. We will sample only once every 15 minutes, matching the dataset's own update rate. We looked for an alternative outside `/api/`: the dataset's CSV download link redirects to a Google sign-in page, so it doesn't meet the command rule. **We would appreciate your approval to use the API.**

### Warnings
- The idea is close to idea #2 in the inspiration list (the board vs. aircraft positions). The difference: we pair the board with weather, especially **destination** weather, instead of aircraft positions.
- Israel's weather is rarely extreme, so the main finding may come from destination weather or from winter storms.
- Delays also happen for reasons unrelated to weather (operations, security, strikes). "No connection" is still a finding.

---

## Proposal 2: Do Steam sales wake up a game's community?

### Summary
Most games have an official Discord server, and Discord reports how many of its members are **online right now**. For 20–30 paid games that are on Steam and have an official Discord server, we will save every hour: how many community members are online (Discord), whether the game is promoted on the **Israeli Steam store's front page** and at what price and discount (Steam store), and how many people are playing it (Steam Web API). The question: **when something happens to a game (a sale, a front-page feature, an update), does its community wake up, and does that happen before or after players return?** Steam's Winter Sale usually runs from late December to early January, in the middle of the semester: a natural experiment in which almost every game is discounted at once.

**Pairing type:** signal and context. Discord activity is the signal that only we collect; Steam promotions, prices and player counts are the context that explains it.

**Research questions:**
- Do sales and front-page features raise Discord activity, and by how much?
- Does community activity rise before player counts do, at the same time, or only after?
- Which matters more: the size of the discount or the visibility on the front page?
- How does a game update compare with a sale in waking up the community?
- What is the normal daily and weekly rhythm of each community, and do online counts stay up after a sale ends?

### Content
- **Discord** (invite API): `guild.name`, `approximate_member_count` (total members), `approximate_presence_count` (members online right now).
- **Israeli store front page** (`featuredcategories`): lists named `top_sellers`, `specials`, `new_releases` and a daily deal. Each game has `id`, `name`, `discounted`, `discount_percent`, `original_price`, `final_price`, `currency` and `discount_expiration`.
- **Prices** (`appdetails`): `currency`, `initial` (original price in agorot), `final` (current price in agorot), `discount_percent`.
- **Player count** (Steam Web API): `player_count` (players right now).

Each Steam game is identified by a number (`appid`); for example, 252490 is Rust. Each Discord server is reached through its official, permanent invite code.

### URLs
| Source | URL |
|---|---|
| Discord community activity | `https://discord.com/api/v10/invites/{invite_code}?with_counts=true` |
| Israeli Steam store front page | `https://store.steampowered.com/api/featuredcategories?cc=il` |
| Steam prices | `https://store.steampowered.com/api/appdetails?appids={appid1},{appid2},...&cc=il&filters=price_overview` |
| Steam player count | `https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid={appid}` |

The price endpoint accepts several games in one call (tested with 5). The Discord and player-count endpoints need one call per game.

### Update frequency
- **Discord online count:** changes constantly through the day.
- **Store front page:** changes during the day as sales start and end; the daily deal changes every day.
- **Player count:** changes constantly. **Prices:** change when sales start and end.

**Planned sampling rate: every hour.**

### Expected size per sample
- **Discord:** about 2.5 KB per server × 30 servers ≈ 75 KB.
- **Store front page:** about 50 KB.
- **Prices and player counts:** about 10 KB.
- **Total:** about 135 KB per sample.

Semester estimate: 24 samples a day × 70 days ≈ 1,700 samples ≈ 230 MB, below 500 MB even without compression.

### Key / password
**None required.** All four endpoints responded without a key or login.

### Data sample
All samples were taken on 2026-11-08 at about 18:00–18:20 UTC.

**Discord** (the official Minecraft server):
```json
{"code": "minecraft", "guild": {"name": "MINECRAFT"},
 "approximate_member_count": 4233043, "approximate_presence_count": 630676}
```
4.2 million members, about 631,000 online at that moment.

**Israeli store front page** (first items of each list):

| List | Game | Discount | Final price |
|---|---|---|---|
| Top Sellers #1 | Call of Duty: Modern Warfare 4 | 0% | ₪299.00 |
| Top Sellers #5 | Football Manager 27 | 10% | ₪215.10 |
| Specials | Rust | 50% | ₪72.50 |
| Specials | R.E.P.O. | 35% | ₪24.04 |
| Daily Deal | Captain Hardcore | 40% | ₪89.97 |

**Player count** (Counter-Strike 2, appid 730):
```json
{"response":{"player_count":1099263,"result":1}}
```

**Prices** (five games in one call, Israeli store):
```json
{
  "1091500": {"success":true,"data":{"price_overview":{"currency":"ILS","initial":24900,"final":24900,"discount_percent":0,"final_formatted":"₪249.00"}}},
  "730":     {"success":true,"data":[]},
  "1245620": {"success":true,"data":{"price_overview":{"currency":"ILS","initial":24900,"final":24900,"discount_percent":0,"final_formatted":"₪249.00"}}},
  "413150":  {"success":true,"data":{"price_overview":{"currency":"ILS","initial":5595,"final":5595,"discount_percent":0,"final_formatted":"₪55.95"}}},
  "892970":  {"success":true,"data":{"price_overview":{"currency":"ILS","initial":10800,"final":10800,"discount_percent":0,"final_formatted":"₪108.00"}}}
}
```
Counter-Strike 2 (730) returns no price, because it is free-to-play.

### Check against the six rules
1. **Lost week:** ✅ The Discord online count is a pure snapshot: once the moment passes, it's gone, and to our knowledge no one records it for game servers. The hourly front page of the Israeli store is also not saved by Steam, which keeps only weekly charts. Steam player counts and prices *are* archived by third-party sites (SteamCharts, SteamDB), so they serve only as context, not as the unique part of the dataset.
2. **Ten samples:** ✅ Online counts, the front page and player counts all change between hourly samples.
3. **Command:** ✅ One `curl` command per request, no browser, no login, no payment.
4. **Permission:** ⚠️ See below.
5. **Size:** ✅ About 230 MB for the whole semester.
6. **Interest:** ✅ A cause-and-effect question with a natural experiment (the Winter Sale) in the middle of the semester.

**Permission rule details:**
- **discord.com:** robots.txt blocks `/api/` in general but explicitly allows `/api/v*/invite`, which is the path we use. We only read public, aggregate counts (no messages, no user data). We still need to read Discord's terms of service before submitting.
- **store.steampowered.com:** robots.txt does not block the `/api/` path. The `featuredcategories` and `appdetails` endpoints are used by Steam's own store but are not officially documented.
- **api.steampowered.com:** robots.txt contains `Disallow: /`, which blocks everything. However, this is Valve's official, documented Steam Web API. Its terms of use allow 100,000 calls per day; we would use well under 1,000. Those terms mainly concern API keys and private user data, while we only read public player counts.

### Warnings
- **"Online" means online in Discord, not active in that server.** A member who is online and belongs to many servers is counted in all of them. The absolute number is rough; changes over time are what we analyze.
- **Invite links must be permanent.** Many Discord invites expire. We will use each game's official, non-expiring invite and test each one before collection starts.
- **Choosing the games.** We need paid games (free-to-play games like Counter-Strike 2 have no price) that have an official Discord server, mixing big and small, old and new.
- **A tracked game may never be featured.** That's why the Winter Sale matters: almost every game is discounted.
- **Undocumented store endpoints.** Steam could change `featuredcategories` or `appdetails` during the semester. We will test them weekly.

---

## Ranking

1. **Proposal 1 — Ben Gurion flight delays and weather** (preferred): it clearly meets the lost-week rule, uses an official open-data source with a single permission question, and the data is simple to parse. The "here or there?" question is original and produces findings even if the answer is "no connection."
2. **Proposal 2 — Steam sales and Discord communities**: a strong cause-and-effect question with a natural experiment in the middle of the semester, and the Discord data is not archived anywhere. But it combines four endpoints, two of them undocumented, has more permission questions to settle, and depends on choosing games with permanent Discord invites.
