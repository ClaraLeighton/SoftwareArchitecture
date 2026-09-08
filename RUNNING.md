# Running & Testing BookReviews

## Quick start (Docker only)

The whole system — Phoenix application and MongoDB database, each in its own container — starts with a single command:

```bash
docker compose up -d --build
```

Then open [http://localhost:4000](http://localhost:4000).

On the very first start (empty `mongodb_data` volume), MongoDB automatically runs `mongo-seed/seed.js` and loads the mock data: 50 authors, 300 books, reviews and yearly sales. The app container waits for the database healthcheck before booting.

Useful commands:

```bash
docker compose logs -f app        # follow application logs
docker compose down               # stop everything (data is kept)
docker compose down -v            # stop and wipe the database volume
./mongo-seed/seed.sh              # re-seed / regenerate mock data
```

No local Elixir, Erlang, Node.js or mise installation is required for this path; only Docker.

---

## Local development setup

### What needs to be installed

This project has three layers. You do not need to install Phoenix or MongoDB globally.

- **Docker Desktop** runs MongoDB 7 in the `book_reviews_mongodb` container. MongoDB is exposed on `localhost:27017`.
- **mise** selects the exact language versions declared by the project: Elixir `1.17.3` and Erlang/OTP `26.2.5.6`.
- **Mix** is Elixir's build tool. `mix deps.get` downloads Phoenix, LiveView, MongoDB Driver, Tailwind, esbuild, DaisyUI support and the other packages declared in `mix.exs`.
- **Node.js and npm** build the frontend assets. The only npm package declared by this project is DaisyUI `5.5.20` in `assets/package.json`.
- **Git** is only needed to clone or update the repository.

On macOS, install the missing system tools with Homebrew:

```bash
brew install mise
```

Docker Desktop must be installed and open before starting MongoDB. Node.js, npm, Docker and Homebrew are already available on the current machine; `mise` is the missing tool.

After installing mise, add its activation to zsh once:

```bash
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc
```

## First-time setup

Run every command from the repository root, the directory containing `mix.exs`:

```bash
cd /Users/claraleighton/Documents/202620/SoftwareArchitecture/Assignment1/SoftwareArchitecture

# Select and install Elixir 1.17.3 and Erlang/OTP 26.2.5.6
mise install

# Download and start MongoDB 7
docker compose up -d

# Download Elixir/Phoenix dependencies
mix deps.get

# Download DaisyUI and prepare Tailwind/esbuild
cd assets
npm install
cd ..

# Build the frontend assets
mix assets.build

# Load mock data: 50 authors, 300 books, reviews and yearly sales
./mongo-seed/seed.sh
```

If Mix asks to install Hex or Rebar, accept it. If it does not offer the prompt, run this once:

```bash
mix local.hex --force
mix local.rebar --force
mix deps.get
```

The seed script must run **after** `docker compose up -d`, because it executes `mongosh` inside the MongoDB container. It is safe to run again when you want to regenerate the mock database.

## Prerequisites

- Docker (for MongoDB)
- [mise](https://mise.jdx.dev) (manages Elixir/Erlang versions automatically)
- Git

## One-Time Setup

```bash
# 1. Install Elixir & Erlang via mise (first time only)
mise install

# 2. Start MongoDB
docker compose up -d

# 3. Seed the database (50 authors, 300 books, reviews, sales)
./mongo-seed/seed.sh

# 4. Install Elixir dependencies
mix deps.get

# 5. Install npm dependencies (daisyUI for Tailwind)
cd assets && npm install && cd ..
```

## Starting the Server

```bash
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000) in your browser.

---

## What to Test (Route by Route)

### Home Page — `/`

The landing page with links to every section. Verify all 7 cards are visible and clickable.

---

### Authors Table — `/authors`

**What it shows:** An aggregated table of all 50 authors with: Name, Country, number of Books, average review Score, and Total Sales across all their books. This data is computed server-side via a MongoDB aggregation pipeline (not raw fields).

**How to test:**

| Action | Steps |
|---|---|
| Sort by any column | Click any column header (Name, Country, Books, Avg Score, Total Sales). Click again to reverse sort direction. The arrow indicator (↑/↓) should toggle. |
| Filter by name | Type a partial author name (e.g. `John`) in the Name field and click **Filter**. Only matching authors appear. |
| Filter by country | Type a country (e.g. `United Kingdom`) and click **Filter**. |
| Combine filters | Fill in both Name and Country, then click **Filter**. Both filters apply simultaneously. |
| View author details | Click an author name to go to their Show page (`/authors/:id`). |
| Edit an author | Click **Edit** on any row, change fields, submit. You are redirected back to the table. |
| Delete an author | Click **Delete**, confirm the browser dialog. The author disappears from the table. |

---

### Create / Show / Edit / Delete — `/authors/new`, `/authors/:id`, `/authors/:id/edit`

Standard CRUD for authors. Create requires Name, Birth Date, Country, and Bio. Show displays all fields. Edit pre-fills the form.

---

### Books — `/books`

**What it shows:** A list of all 300 books with Title, Author, Published Date, Summary, and Sales.

**How to test:**

| Action | Steps |
|---|---|
| Browse books | Scroll through the full list of 300 books. |
| View book details | Click a book title to go to its Show page. |
| Create a new book | Click **New Book**, fill in Title, Summary, Published Date, select an Author, enter Sales. Submit. |
| Edit a book | Click **Edit** on any row, modify fields, submit. |
| Delete a book | Click **Delete**, confirm. The book is removed. |

---

### Top Rated Books — `/books/top-rated`

**What it shows:** The top 10 books ranked by average review score, but only books with **3 or more reviews**. Displays: rank, title, average score (with star visualization), review count, highest individual score, and lowest individual score.

**How to test:**

| What to verify |
|---|
| Exactly 10 books appear (or fewer if insufficient data). |
| The table is sorted by average score descending. |
| Each row shows star icons (★ filled, ☆ empty) reflecting the average. |
| The "Reviews" column shows a number >= 3. |
| Highest score >= Lowest score for every row. |

---

### Top Selling Books — `/books/top-selling`

**What it shows:** The top 50 books by total sales, enriched with: the author's combined sales across all their books, and a **"Top 5 in Year"** badge indicating whether this book was among the top 5 sellers in its publication year (computed via a separate `sales_by_year` aggregation).

**How to test:**

| What to verify |
|---|
| Up to 50 books appear, sorted by total sales descending. |
| Sales numbers are formatted with commas (e.g. `1,234,567`). |
| Some rows show a green **Yes** badge for "Top 5 in Year", others show a grey **No**. |
| Click any book title to navigate to its Show page. |

---

### Search — `/books/search`

**What it shows:** A search interface that finds books by keywords in their **summary** field. Supports space-separated terms (any term can match). Results are paginated (10 per page).

**How to test:**

| Action | Steps |
|---|---|
| Basic search | Type a word like `mountain` or `adventure` and click **Search**. Results appear with a count (e.g. "Found 5 results"). |
| Multi-term search | Type `mountain truth` (space-separated). Books whose summary contains either word appear. |
| Empty search | Click **Search** with the field empty. The page loads without results. |
| No results | Search for `xyznonexistent`. The message "No books found matching your search" appears. |
| Pagination | If your search returns many results (more than 10), page number links appear at the bottom. Click page 2, 3, etc. The active page is highlighted in indigo. |
| Click a result | Click any book title in the results to go to its Show page. |

---

### Reviews — `/reviews`

Standard CRUD. Lists all reviews with Book ID, Score (1-5), Reviewer, and Date. Create a review by selecting a book ID, entering a score, reviewer name, and text.

---

### Sales — `/sales`

Standard CRUD. Lists all sales entries with Book ID, Year, and Sales count. Create, edit, and delete as with other resources.

---

## Assignment 3 — Cache (Redis) & Search (OpenSearch)

Neither layer is required at runtime: the app reads `CACHE_ENABLED` /
`SEARCH_ENABLED` at boot. With a layer disabled the app keeps working — cache
reads become direct MongoDB reads, and the search window falls back to the
Assignment 1 database query (summary `LIKE`). One image, four configurations.

### The four Compose deployments

```bash
# 1) Application + Database
docker compose -f docker-compose.yml up -d --build

# 2) Application + Database + Cache
docker compose -f docker-compose.cache.yml up -d --build

# 3) Application + Database + Search Engine
docker compose -f docker-compose.search.yml up -d --build

# 4) Application + Database + Cache + Search Engine
docker compose -f docker-compose.full.yml up -d --build
```

Run one stack at a time (they share host ports). Open
[http://localhost:4000](http://localhost:4000).

### Environment toggles (local dev, without Docker)

```bash
# default: no cache, no search engine
mix phx.server

# cache only               # search only
CACHE_ENABLED=true \       SEARCH_ENABLED=true \
REDIS_URL=redis://localhost:6379 \          OPENSEARCH_URL=http://localhost:9200 \
mix phx.server \           mix phx.server

# full stack
CACHE_ENABLED=true REDIS_URL=redis://localhost:6379 \
SEARCH_ENABLED=true OPENSEARCH_URL=http://localhost:9200 \
mix phx.server
```

### What is cached / indexed, and how it is invalidated

Cached keys (`book_reviews:*` in Redis, 300 s TTL):
`book_avg_<id>` (book average score), `top_rated_10`, `top_selling_50`, and the
authors overview table (`authors_stats_*`). Invalidations follow the dependency
rules from the assignment:

- new/edited/deleted **review** → purge that book’s average, `top_rated_10`,
  `authors_stats_*` (and re-index the book);
- new/edited/deleted **sale** → purge `top_selling_50`, `authors_stats_*`;
- edited **book/author** → purge `authors_stats_*` (+ re-index the book).

In OpenSearch each book is one document (title + summary + concatenated review
texts); the index is rebuilt at app startup and kept in sync on every
book/review create/update/delete.

### Quickly check what's ON / OFF (any stack)

Every running instance exposes a small status endpoint. Just open it in the
browser:

```
http://localhost:4000/api/features
```

It returns JSON telling you exactly which layers are active in this instance:

```json
{"cache_backend":"Redis","cache_enabled":true,"search_backend":"OpenSearch","search_enabled":true}
```

- **Cache ON** → `cache_backend: "Redis"`, `cache_enabled: true`
- **Cache OFF** → `cache_backend: "Null"`, `cache_enabled: false`
- **Search ON** → `search_backend: "OpenSearch"`, `search_enabled: true`
- **Search OFF** → `search_backend: "Null"`, `search_enabled: false`

This is the single best first check when you're not sure which stack is running
or whether a layer is really active — no need to peek into Redis or OpenSearch.

### How to test each case (click-by-click)

> **Tip — which container to inspect.** Each compose file names its Redis cache
> differently, so use the matching container for your stack:
> - `docker-compose.cache.yml` → cache container is **`book_reviews_cache_cache`**
> - `docker-compose.full.yml` → cache container is **`book_reviews_cache_full`**
>
> And always `down` the previous stack before starting a different one (they
> share host ports). If you ever get a "network not found" error, run:
> `docker compose -f <file>.yml down` then start again.

#### Case A — Full stack (cache + search both working)

Start the full deployment:

```bash
docker compose -f docker-compose.full.yml up -d --build --remove-orphans
```

Then:

1. **Confirm both layers are ON.** Open `http://localhost:4000/api/features`
   → should show `"Redis"` and `"OpenSearch"`.
2. **Cache is being written.** Browse a few pages
   (`/books`, `/books/top-rated`, `/authors`), then run:
   ```bash
   docker exec book_reviews_cache_full redis-cli --scan --pattern 'book_reviews:*'
   ```
   ✅ You should see keys like `book_reviews:top_rated_10`,
   `book_reviews:authors_stats_*`, `book_reviews:book_avg_*`.
   (No keys = cache is off or the wrong container/stack is running.)
3. **Cache stays fresh after a review.** In the UI create a review (`/reviews/new`).
   Re-run the scan: `top_rated_10` and `authors_stats_*` should be **gone**
   (only `top_selling_50` remains) — the app purged the now-stale tables.
4. **Search finds review text (proves OpenSearch is really answering).** Go to
   `/books/search` and search for **`transformative`**. This word exists only
   inside review bodies (0 in titles/summaries), so a database-only search would
   return nothing:
   - ✅ Results ("Found 44 results") → OpenSearch is matching review text.
5. **Search follows edits.** Edit one of those books and change its summary.
   ~1 second later, search for the old summary word → 0 results; search for a
   new word in the new summary → it appears.

#### Case B — Turn the cache OFF (app + database only)

```bash
docker compose -f docker-compose.full.yml down
docker compose -f docker-compose.yml up -d --build
```

1. **Confirm cache is OFF.** `http://localhost:4000/api/features` →
   `"cache_backend":"Null"`, `"cache_enabled":false`.
2. **Nothing is cached.** Browse pages, then run:
   ```bash
   docker exec book_reviews_mongodb_full mongosh book_reviews  # irrelevant, cache gone
   docker exec book_reviews_cache_full redis-cli --scan --pattern 'book_reviews:*'
   ```
   The scan returns **nothing** — the app runs happily straight from MongoDB.
   (Ignore the "no such container" if `cache_full` isn't running in this stack —
   that's expected, there simply is no cache.)
3. **Search is OFF too** (this stack has no search engine either):
   `http://localhost:4000/api/features` → `"search_backend":"Null"`.
   - Search still works via the **database fallback**: searching `dragon`
     returns books (from summaries). But `transformative` → 0 results, because
     the DB fallback can't see review text.

#### Case C — Cache ON, Search OFF

```bash
docker compose -f docker-compose.yml down
docker compose -f docker-compose.cache.yml up -d --build
```

1. `http://localhost:4000/api/features` → `"cache_backend":"Redis"`,
   `"search_backend":"Null"`.
2. Cache keys appear after browsing (use container **`book_reviews_cache_cache`**):
   ```bash
   docker exec book_reviews_cache_cache redis-cli --scan --pattern 'book_reviews:*'
   ```
3. Search `transformative` → **0 results** (no engine), but a summary word still
   finds books (DB fallback). This stack has no OpenSearch running at all.

#### Case D — Search ON, Cache OFF

```bash
docker compose -f docker-compose.cache.yml down
docker compose -f docker-compose.search.yml up -d --build
```

1. `http://localhost:4000/api/features` → `"search_backend":"OpenSearch"`,
   `"cache_backend":"Null"`.
2. Search `transformative` → **results** (engine is answering).
3. The Redis scan containers won't exist (no cache in this stack) — expected.

#### Case E — Local dev toggles (no Docker)

```bash
# default: everything off
mix phx.server
# expected: /api/features → "Null" / "Null"

# cache + search, hitting the docker containers
CACHE_ENABLED=true REDIS_URL=redis://localhost:6379 \
SEARCH_ENABLED=true OPENSEARCH_URL=http://localhost:9200 \
mix phx.server
# expected: "Redis" / "OpenSearch"
```

### Common gotchas when testing

- **“Network not found” on `up`.** You switched stacks and left orphaned
  containers/network. Fix: `docker compose -f <active>.yml down` first, or add
  `--remove-orphans` to your `up`.
- **Shared ports.** All stacks map the same host ports (`4000`, `27017`). Only
  run one at a time, and use the correct cache container name (Case table above).
- **`transformative` returns nothing.** That's expected when search is OFF — it's
  the *signal* that search is off. Don't treat it as a bug.
- **A just-edited book isn't searchable for ~1 second.** OpenSearch flushes its
  index about once per second; wait 1 s before asserting the new value.

## Quick Smoke Test Checklist

1. `http://localhost:4000` — Home loads with 7 navigation cards
2. `http://localhost:4000/authors` — 50 authors in aggregated table, sort by Total Sales works
3. `http://localhost:4000/books` — 300 books listed
4. `http://localhost:4000/books/top-rated` — 10 books with stars and scores
5. `http://localhost:4000/books/top-selling` — 50 books with sales and Top 5 badges
6. `http://localhost:4000/books/search?q=mountain` — Search returns results with pagination
7. `http://localhost:4000/reviews` — Reviews listed
8. `http://localhost:4000/sales` — Sales listed
9. Create a new author via `/authors/new`, verify it appears in the table
10. Edit a book via `/books/:id/edit`, verify changes persist
11. Delete a review, verify it disappears from the list
