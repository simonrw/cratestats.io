import pandas as pd


def downloads_per_category(database_url) -> str:
    return pd.read_sql(
        """
        SELECT
            categories.category,
            count(crates.id) as crate_count
        FROM crates
        JOIN crates_categories ON crates.id = crates_categories.crate_id
        JOIN categories ON crates_categories.category_id = categories.id
        GROUP BY categories.category
        ORDER BY crate_count DESC
        """,
        database_url,
    )


def downloads_per_dow(database_url) -> str:
    return pd.read_sql(
        """
    WITH daily_downloads (day, total_downloads) AS (
    SELECT
        date_trunc('day', date) as day,
        sum(downloads) as total_downloads
    FROM version_downloads
    GROUP BY day
    )
    SELECT
        extract('w' from day) as week,
        extract('dow' from day) as dow,
        total_downloads
    FROM daily_downloads
    ORDER BY day ASC
    """,
        database_url,
    )
