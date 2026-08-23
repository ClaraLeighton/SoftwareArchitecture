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
