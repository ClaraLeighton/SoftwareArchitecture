# Assignment 3: Caching & Search
---

In the previous assignments, you built your application and containerized it. Now we will start improving its performance and scalability by adding a read-acceleration tier: a cache and a dedicated search engine.

---

## Concept Review

### Cache Overview
A cache stores the result of an expensive operation so that future requests for the same data can be served faster.

```
                  Only if content is not cached
               +---------------------------------+
               |                                 |
               v   --- Send Request --->         v
[ User ] <===========> [ Cache ] <-------------> [ Application ]
         <--- Return Content ---   <-- Return Content --
```

- **Trade-offs:** It trades memory and freshness for latency and load reduction.
- **Usage:** A cache is only useful if reads greatly outnumber writes for the cached data.
- **Freshness:** Every cached item is a copy that can become stale.

#### The Hard Problem: Invalidation
> *"There are only two hard things in Computer Science: cache invalidation and naming things."*  
> — **Phil Karlton**

When the underlying data changes, every copy of it living in the cache is now wrong. Deciding what to purge, and when, is the central difficulty of caching.

---

### Search Engine Overview
A dedicated search engine (OpenSearch, Elasticsearch, Lucene, etc.) builds an inverted index over your text so that full-text queries are fast and relevance-ranked.

- **Purpose:** Your relational/document database is not built for efficient free-text search.
- **Data Duplication:** The search index is a second copy of your data—it must be kept in sync.
- **Challenge:** Same fundamental problem as the cache: a copy that can drift from the source of truth.

---

## Assignment Details

- **Groups:** Same groups as previous assignments.
- **Application:** Same application as previous assignments.
- **Timeline:** Due in 2 weeks.

---

## Technical Requirements

### 1. Cache Implementation

You will modify your application to allow the usage of a cache (Redis / Memcached / etc.), but your application **must still be able to run without it**.

#### What to Cache
Cache the expensive, read-heavy results that are recomputed identically for almost every visitor:
- The **authors overview table** (per author: number of published books, average score, total sales).
- The **top 10 rated books** and **top 50 selling books** tables.
- A **book's average review score**, reused across all of the above.

#### Cache Misses & Invalidation Strategy
- **Cache Miss:** On a miss, the read transparently falls back to the database and populates the cache.
- **Cache Invalidation:** When the underlying data changes, the derived entries that depend on it must be purged:
  - **New/edited/deleted review:** Purge that book's average score, the top 10 rated books, and its author's overview row.
  - **New/edited/deleted sale:** Purge the top 50 selling books, and its author's total sales.
  - **Edited book or author:** Purge that author's overview row (book count, name).

---

### 2. Search Engine Implementation

You will modify your application to allow the usage of a text search engine (OpenSearch / Elasticsearch / Lucene / etc.), but your application **must still be able to run without it**.

#### What to Index
Index the free-text content of your data:
- **Each book:** Its name and summary.
- **Each review:** Its text.

#### Search Querying
The search window from Assignment 1 must now query the engine: it returns a paginated, relevance-ranked list of books matching the words—on title, summary, or their reviews—instead of a database `LIKE` on the summary.

#### Sync & Fallback Strategy
- **Synchronization:** When a book or review is added, deleted, or modified, the corresponding document in the index must also be updated.
- **Fallback:** If the engine is absent, search falls back to the database query from Assignment 1 (book summary only).

---

### 3. The "Runs Without It" Constraint

Notice that both features share a constraint: **the application must work with and without them**.

- **Architectural Design:** This forces you to keep the cache/search as an optional, swappable layer behind an interface, instead of hard-wiring it.
- **Layer Ownership:** Think about where this decision belongs in the architecture you documented—which layer/component owns it?
- **Implementation Tip:** A flag or environment variable your application checks at startup is usually enough to toggle each one.

---

## Deliverables

### 1. Docker Compose Files
You must implement multiple Docker Compose files that account for the following deployments:
1. Application + Database
2. Application + Database + Cache
3. Application + Database + Search Engine
4. Application + Database + Cache + Search Engine

---

### 2. Kubernetes Deployment
Carrying forward your Kubernetes deployment from Assignment 2, deploy the full configuration (**Application + Database + Cache + Search Engine**) to your local cluster (`minikube` / `k3d`):
- Add a `Deployment` and `Service` for the cache and for the search engine.
- *Note:* The Compose deployments remain the working default; only the full deployment is required on Kubernetes.

---

### 3. Correctness Test
For the full deployment (Database + Cache + Search Engine), demonstrate that your invalidation and sync logic is correct:
1. Read an item so it gets cached / indexed.
2. Modify it (and add/delete a couple) through the application.
3. Show that a subsequent read returns the updated value, and that search reflects the change.
4. Document any case where you found the cache or index returning stale data, and how you fixed it (or why it is acceptable).

