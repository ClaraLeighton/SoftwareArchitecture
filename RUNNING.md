# Running & Testing BookReviews

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

**What it shows:** A search interface that finds books by keywords in their **summary** field. Supports space-separated terms (all must match). Results are paginated (10 per page).

**How to test:**

| Action | Steps |
|---|---|
| Basic search | Type a word like `mountain` or `adventure` and click **Search**. Results appear with a count (e.g. "Found 5 results"). |
| Multi-term search | Type `mountain truth` (space-separated). Only books whose summary contains **both** words appear. |
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
