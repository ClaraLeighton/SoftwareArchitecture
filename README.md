# Book Review App — MongoDB Setup & Guide

Database for Assignment 01 (Book Review Web Application, Phoenix + MongoDB).

## Data model

Database `book_reviews` with 4 collections:

| Collection | Fields |
|---|---|
| `authors` | `_id`, `name`, `date_of_birth`, `country`, `bio` |
| `books` | `_id`, `title`, `summary`, `published_date`, `sales` (total), `author_id` |
| `reviews` | `_id`, `book_id`, `review`, `score` (1–5), `upvotes` |
| `sales_by_year` | `_id`, `book_id`, `year`, `sales` |

Relations: `books.author_id` → `authors._id`, `reviews.book_id` / `sales_by_year.book_id` → `books._id`.

Populated mock data (deterministic, seeded):

- 50 authors
- 300 books
- 1–10 reviews per book (1,600 total)
- 5–15 yearly sales rows per book, starting at its publication year (2,998 rows)
- `books.sales` always equals the sum of that book's `sales_by_year` rows

## 1. Prerequisites

- Docker + Docker Compose (nothing else is installed on the host; MongoDB runs in a container).

## 2. Start the database

```bash
docker compose up -d
```

MongoDB listens on `localhost:27017`. No authentication is configured (local dev only).

## 3. Populate the database

```bash
./mongo-seed/seed.sh
```

This drops and recreates the `book_reviews` database with the same mock data every time (seeded PRNG).

Expected output ends with:

```
authors        : 50
books          : 300
reviews        : 1600
sales_by_year  : 2998
reviews/book   : min=1 max=10 avg=5.3
years/book     : min=5 max=15
```

## 4. Interact with the database

### Open the shell (mongosh)

From the host (no mongosh needed locally — it ships inside the Mongo container):

```bash
docker compose exec mongodb mongosh mongodb://localhost:27017/book_reviews
```

You're now in an interactive JS shell against the `book_reviews` database.

### CRUD examples

```js
// READ
db.authors.find().limit(3)
db.books.find({ title: "Frozen Maze" })

// CREATE
db.authors.insertOne({ name: "New Writer", date_of_birth: new Date("1990-05-01"), country: "Uruguay", bio: "Debut novelist." })

// UPDATE
db.books.updateOne({ title: "Frozen Maze" }, { $inc: { sales: 1000 } })

// DELETE
db.authors.deleteOne({ name: "New Writer" })
```

### One-liners without entering the shell

```bash
docker compose exec -T mongodb mongosh --quiet mongodb://localhost:27017/book_reviews \
  --eval 'db.books.countDocuments()'
```

## 5. Queries used by the assignment views

### Authors table (books count, average score, total sales) — sortable/filterable

```js
db.authors.aggregate([
  { $lookup: { from: "books", localField: "_id", foreignField: "author_id", as: "bs" } },
  { $unwind: "$bs" },
  { $group: {
      _id: "$_id",
      name: { $first: "$name" },
      books: { $sum: 1 },
      totalSales: { $sum: "$bs.sales" },
      bookIds: { $push: "$bs._id" }
  } },
  { $lookup: { from: "reviews", localField: "bookIds", foreignField: "book_id", as: "rs" } },
  { $project: {
      _id: 0, name: 1, books: 1, totalSales: 1,
      avgScore: { $round: [{ $avg: "$rs.score" }, 2] }
  } },
  { $sort: { totalSales: -1 } }
])
```

Filter on any column by adding `{ $match: { name: /Torres/ } }` before `$sort`; sort by changing the `$sort` stage.

### Top rated books (top 10, with highest/lowest rated review)

```js
db.books.aggregate([
  { $lookup: { from: "reviews", localField: "_id", foreignField: "book_id", as: "rs" } },
  { $unwind: "$rs" },
  { $group: {
      _id: "$_id",
      title: { $first: "$title" },
      avg: { $avg: "$rs.score" },
      reviews: { $sum: 1 },
      highest: { $max: "$rs.score" },
      lowest: { $min: "$rs.score" }
  } },
  { $match: { reviews: { $gte: 3 } } }, // optional: drop 5-star-single-review outliers
  { $sort: { avg: -1, reviews: -1 } },
  { $limit: 10 }
])
```

### Top selling books (top 50, with book total + author total)

```js
db.books.aggregate([
  { $sort: { sales: -1 } },
  { $limit: 50 },
  { $group: { _id: null, books: { $push: "$$ROOT" } } },
  { $unwind: "$books" },
  { $lookup: { from: "books", localField: "books.author_id", foreignField: "author_id", as: "authBooks" } },
  { $project: {
      _id: 0,
      title: "$books.title",
      totalSales: "$books.sales",
      authorTotalSales: { $sum: "$authBooks.sales" }
  } },
  { $sort: { totalSales: -1 } }
])
```

### Top-5-in-publication-year flag (used by the Top Selling view)

```js
const top5ByYear = db.sales_by_year.aggregate([
  { $sort: { sales: -1 } },
  { $group: { _id: { year: "$year", book: "$book_id" } } },
  { $group: { _id: "$_id.year", top: { $push: "$_id.book" }, sales: { $sum: 1 } } },
  { $match: { sales: { $lte: 5 } } }
]).toArray().map(d => d._id);
// top5ByYear -> array of years; membership test per book = whether book_id
// appears in that year's top-5 list (see queries/top_selling helper below).
```

### Search (books whose summary contains any of the words)

```js
// terms from the search box
const terms = ["mountain", "truth", "journalist"].map(t => new RegExp(t, "i"));
db.books.aggregate([
  { $match: { summary: { $in: terms } } },
  { $sort: { title: 1 } },
  { $skip: 0 },          // pagination
  { $limit: 10 }
])
```

A `summary` text index also exists, so a ranked full-text search is available too:

```js
db.books.find({ $text: { $search: "mountain truth" } }, { score: { $meta: "textScore" } })
  .sort({ score: { $meta: "textScore" } })
  .limit(10)
```

## 6. Everyday commands

```bash
docker compose up -d          # start the DB
docker compose down           # stop the DB (data persists in the volume)
docker compose down -v        # stop and delete ALL data (fresh start next time)
./mongo-seed/seed.sh          # reset the DB to the seeded mock data
```

## 7. Connecting from the Phoenix app later

From an Elixir process (e.g. with `Mongo.Ecto` or the official `mongodb_driver`), the connection string is:

```
mongodb://localhost:27017/book_reviews
```

Container networking note: when the Phoenix app itself runs in Docker on the same Compose network, use the service name `mongodb` instead of `localhost`.
