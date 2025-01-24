## 1. Dashboard Design & Implementation

1. **BI Tool Choice**  
   - **Tableau** was chosen for its rich visual capabilities and ease of sharing. Initially was going for looker and defining the models with LookerML but due to some blockers in terms of connecting to the semantic layer on a no non production instance.
   - The dashboards focus on **tickets**, **ratings**, and **root-cause** data, as modeled in BigQuery through the Bronze, Silver, and Gold layers.

2. **Key Metrics & Visualizations**  
   - **Average Score by Ticket**: Highlights how well each ticket was rated (auto vs. manual).  
   - **Reviewer Performance**: Tracks individual reviewer’s average scores and volume of reviews, as required to assess agent performance.  
   - **Category and Root Cause Breakdown**: Displays the frequency and severity of grammar, sentiment, or other categories—useful to identify training gaps.  
   - **Time Series of Scores**: Shows trends in ticket quality over weeks or months, helping leadership see improvements (or regressions) in customer service.

3. **Data Model Alignment**  
   - The **Gold** layer (mart) in BigQuery is the single source of truth for these metrics.  
   - Models in dbt unify raw rating tables (`autoqa_ratings_test.csv`, `manual_reviews_test.csv`, etc.) into consistent fact and dimension tables.
   - The rating score algorithm (e.g., dealing with N/A = 42 and converting it to a 0–100 scale) is applied in dbt transformations, ensuring a consistent metric definition in the dashboard.

4. **Actionability & User Experience**  
   - The dashboard design aims for **clarity** (intuitive charts, minimal clutter) and **actionable insights** (clear calls to drill into problem areas or top performers).  
   - Stakeholders can quickly see **which areas** need the most attention—whether that’s a specific agent’s grammar issues or a root cause repeating in certain tickets.

## 2. Dashboard Design Process Documentation

1. **Rationale for Each Metric**  
   - **Ticket Average Score**: Core KPI reflecting overall ticket handling quality.  
   - **Reviewers’ Average Score**: Helps assess consistency and identify training needs among QA staff.  
   - **Root Cause Frequency**: Offers actionable direction on the main drivers of negative feedback (e.g., grammar errors).
   - **Time Series**: Illustrates whether the team’s performance is improving or declining over time.

2. **Visualization Selection**  
   - **Bar Charts** for categorical comparisons (rating categories, root causes, top agents).  
   - **Line Charts** for time-based trends.  
   - **Scatter Plots** or **heat maps** to quickly see correlations or concentrations of specific root causes.

3. **Iterative Refinement**  
   - Collected feedback from stakeholders to ensure the dashboards resonate with actual needs (e.g., quickly identifying top improvement areas).  
   - Adjusted color schemes and labels for clarity and compliance with any brand guidelines.
