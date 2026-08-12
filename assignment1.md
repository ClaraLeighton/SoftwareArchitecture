# Assignment 01: Book Review Web Application

## Description
For this assignment you will develop a basic book review web application.

The web application must accomplish the following requirements:
- **Manage Authors**: name, date of birth, country of origin, short description.
- **Manage Books**: name, summary, date of publication, number of sales.
- **Manage Reviews**: book, review, score from 1 to 5, number of up-votes.
- **Manage Sales by year**: book, year, sales.

## Views
The web application should have the following views:
- **CRUD**: Create, Read, Update, Delete for authors, books, reviews, sales, and any other model/relation you might need to add.
- **Authors Table**: A table that shows authors, number of published books, average score, and total sales. This table should have a sort and filter for each column.
- **Top Rated Books**: A table that shows the top 10 rated books of all time, with their highest-rated and lowest-rated review.
- **Top Selling Books**: A table that shows the top 50 selling books of all time, showing:
  - Their total sales for the book.
  - Total sales for the author.
  - If the book was in the top 5 selling books in the year of its publication.
- **Search**: A search window that lets me input text, and returns a paginated list of books whose summary contains any of the words in the search.

## Constraints
You will develop your web application under the following constraints:
### Web Frameworks
- Phoenix (Elixir)
### Database Engine
- MongoDB

## Deliverables

### 1. Code
- The code of your application.
- A way to populate your database with mock data (script, seeds, etc…).
  - **50 authors**
  - **300 books**
  - **Between 1 to 10 reviews per book**
  - **At least 5 years of sales per book**
  - The data can be procedurally generated, or obtained from:
    - [Open Library API](https://openlibrary.org/developers)
    - [Hardcover API](https://docs.hardcover.app/api/getting-started/)

### 2. Report
A short report in English that outlines the following points:
- A short description of the programming language, web framework, and database engine used.
- How familiar was your group with those technologies.
- How did you connect your web framework with your database engine? If you used a database abstraction layer, describe how it works.
- How much time did it take you, and what were the challenges you found while:
  - Connecting the web framework with the database engine.
  - Configure and start using the web framework.
  - Implement the CRUD for the different models.
  - Implement the different queries for the tables.
  - Implement the views for the tables.

### 3. Predictions Section
Include in your report a short section (you won't be graded on accuracy):
- Which decisions you made in this assignment (framework, database, data model, session handling, etc…) do you predict will be expensive to change later in the course?
- How much time did you lose (or save) because of the assigned framework/database vs. one you already knew?

> *Note: You will revisit these predictions at the end of the semester.*

### 4. Presentation
- 3 randomly selected groups will do a presentation in English of their assignment and report on the next class.
- The presenting groups will be notified alongside their assigned web framework and database engine.
- The presentation should be between **5 to 10 minutes** per group.

## AI Usage Policy
The use of generative AI is allowed for the **coded part** of the assignment. The **report must be written by the students**.