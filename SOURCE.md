# Data Source: Steam + Discord

**Use of AI tools.** We used Claude (Anthropic) to help write this file. In the chat, we described our data source and told Claude which columns to keep in the dataset and what to call them, and asked it to write the Markdown file and check the grammar and vocabulary. We chose the data source, the games, the columns and the sampling rate ourselves, and we reviewed and edited the final text. The prompt we used:

> We are working on a course project that collects live data from Steam and Discord. Our approved data source uses four endpoints (Discord invite counts, the Steam store front page, Steam prices, and Steam player counts), and for the manual stage we track 5 games, identified by their Steam app IDs and Discord invite codes.
>
> Please go over the data we gave you, including the sample responses and the fields each endpoint returns. We will tell you in this chat which columns to keep in our dataset and what to call them (`timestamp`, `app_id`, `game_name`, `price_initial`, `price_final`, `discount_percent`, `featured_in`, `player_count`, `discord_members`, `discord_online`). Based on that, write a SOURCE.md file in Markdown with these sections: a table describing the data source; what we collect; the schema (columns, content and units); why we keep these columns and not others; a mapping from the source field names to our column names; and the expected size of the raw folder and the dataset after a semester of hourly collection.
>
> Then check the language: correct the grammar and vocabulary, and make the English clear and consistent, without changing our decisions.

---

**Research question:** when something happens to a game on Steam (a sale, a front-page feature, an update), does its Discord community wake up, and does that happen before or after players return?

---

## 1. Source overview

| | Discord community activity | Steam store front page | Steam prices | Steam player count |
|---|---|---|---|---|
| **Name** | Discord invite API | Steam Store `featuredcategories` | Steam Store `appdetails` | Steam Web API `GetNumberOfCurrentPlayers` |
| **URL** | `https://discord.com/api/v10/invites/{invite_code}?with_counts=true` | `https://store.steampowered.com/api/featuredcategories?cc=il` | `https://store.steampowered.com/api/appdetails?appids={ids}&cc=il&filters=price_overview` | `https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid={appid}` |
| **Data format** | JSON | JSON | JSON | JSON |
| **Key / username required** | No | No | No | No |
| **License / terms** | Discord Terms of Service and Developer Terms. `robots.txt` blocks `/api/` but explicitly allows `/api/v*/invite`. We read only public, aggregate counts (no messages, no user data). | Steam Subscriber Agreement. Undocumented endpoint used by Steam's own store; `robots.txt` does not block `/api/`. | Same as front page. | Steam Web API Terms of Use: up to 100,000 calls per day; we use far fewer. Public data only, no key. |
| **Collection frequency** | Every hour | Every hour | Every hour | Every hour |

**Tracked games:** the project will track **30 games**. The manual samples use the first 5 below; the remaining 25 will be added before we begin automated collection. Every game must be paid (so it has a price) and have an official, permanent Discord invite.

| Game | Steam app ID | Discord invite code |
|---|---|---|
| Phantom Blade Zero | 4115450 | `phantombladezero` |
| Cyberpunk 2077 | 1091500 | `cyberpunkgame` |
| Rust | 252490 | `rust` |
| Stardew Valley | 413150 | `stardewvalley` |
| Football Manager 27 | 4530370 | `footballmanager` |

All invite codes are official and permanent. The list mixes new releases (Phantom Blade Zero, Football Manager 27) with older games (Rust, Cyberpunk 2077, Stardew Valley), and expensive AAA games with a cheap indie game. The final 30 games will be a mix as well.

---

## 2. What we collect

Each sample is one JSON file, `raw/YYYY-MM-DD/HHMM.json`, holding the four responses under the keys `featured`, `prices`, `players` and `discord`:

- **Discord:** for each game's official server, the total number of members and the number of members online right now. The online count is a snapshot that no one archives, so it is the unique part of the dataset.
- **Steam front page:** the lists shown on the Israeli store's front page (top sellers, specials, new releases). We use it to tell whether one of our games is *visible* on the front page, which is not the same as whether it is discounted.
- **Steam prices:** the original price, current price and discount for each of our games, in NIS.
- **Steam player count:** how many people are playing each game right now.

---

## 3. Schema

The dataset (`dataset.csv`) has **one row per game per sample**.

| Column | Type | Content | Units |
|---|---|---|---|
| `timestamp` | datetime | Time of the sample, taken from the file path | `YYYY-MM-DD HH:MM`, UTC |
| `app_id` | integer | Steam app ID of the game | — |
| `game_name` | text | Name of the game | — |
| `price_initial` | decimal | Price before discount | NIS |
| `price_final` | decimal | Current price | NIS |
| `discount_percent` | integer | Current discount | percent (0–100) |
| `featured_in` | text | Front-page list(s) the game appears in, separated by `;` (`specials`, `top_sellers`, `new_releases`); empty if not featured | — |
| `player_count` | integer | Players in the game right now | players |
| `discord_members` | integer | Total members of the game's official Discord server | members (approximate) |
| `discord_online` | integer | Members of that server online on Discord right now | members (approximate) |

---

## 4. Why these columns

- **`timestamp` and `app_id`** identify each row; everything else is measured per game per hour.
- **`price_final` and `discount_percent`** tell us *when* a game is on sale and *how big* the sale is. `price_initial` lets us check the discount and notice permanent price changes.
- **`featured_in`** tells us whether the game is *visible* on the front page, so we can compare the effect of visibility with the effect of the discount size.
- **`player_count`** shows whether players come back, and when.
- **`discord_online`** is the main signal: is the community active? **`discord_members`** lets us normalize it (online as a share of members) and see whether sales bring new members.

**Fields we do not keep:**
- From the front page: images, trailers, platform flags, controller support and the full list of other games. We only need to know whether *our* games appear and in which list.
- From Discord: server icon, banner, description, feature flags and channel details. They don't change and don't add any information regarding what we want to check.
- From the price response: the formatted price strings (`final_formatted`), which are just a duplicate of the numeric fields.
- From the player-count response: the `result` status code, used only to check that the request succeeded.

---

## 5. Field mapping: source → schema

| Source | Source field | Schema column | Transformation |
|---|---|---|---|
| File path | `raw/YYYY-MM-DD/HHMM.json` | `timestamp` | Parse the date folder and file name |
| Our game list | app ID | `app_id` | — |
| Our game list | game name | `game_name` | — |
| `appdetails` | `price_overview.initial` | `price_initial` | Divide by 100 (agorot → NIS) |
| `appdetails` | `price_overview.final` | `price_final` | Divide by 100 (agorot → NIS) |
| `appdetails` | `price_overview.discount_percent` | `discount_percent` | — |
| `featuredcategories` | `specials.items[].id`, `top_sellers.items[].id`, `new_releases.items[].id` | `featured_in` | Names of the lists where the game's app ID appears, joined with `;` |
| `GetNumberOfCurrentPlayers` | `response.player_count` | `player_count` | — |
| Discord invite | `approximate_member_count` | `discord_members` | — |
| Discord invite | `approximate_presence_count` | `discord_online` | — |

---

## 6. Expected size

**30 games**, hourly collection for one semester, about **60 days → 1,440 samples**.

**`raw/` folder:**
- Front page: about 50 KB per sample.
- Discord: about 2.5 KB per server × 30 servers ≈ 75 KB.
- Prices and player counts: about 10 KB.
- **≈ 135 KB per sample × 1,440 samples ≈ 195 MB.**

**`dataset.csv`:**
- 30 games × 1,440 samples = **43,200 rows**, about 100 bytes each ≈ **4.3 MB**.

Both stay under the 500 MB limit. Most of the raw size comes from the Discord responses, which repeat static server details (icon, banner, description) in every sample.

---

## Limitations

- **Time zone of the first samples.** All file names use UTC, as the project contract requires. The first manual samples (17–18 November 2026) were named in Israel time (UTC+2) before we noticed this rule. Since `raw/` is append-only, they were not renamed; `normalise.sh` will convert their timestamps to UTC.
- **"Online" means online on Discord, not active in that server.** A member who is online and belongs to many servers is counted in all of them. We analyze changes over time, not the absolute number.
- **Undocumented store endpoints.** Steam could change `featuredcategories` or `appdetails` during the semester; we will check them regularly.
- **A tracked game may never be featured.** The Steam Winter Sale (late December to early January) is when almost every game is discounted, so it is the main natural experiment.
