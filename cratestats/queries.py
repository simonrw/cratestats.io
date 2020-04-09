def downloads_per_category():
    return """
        SELECT
            categories.category,
            count(crates.id) as crate_count
        FROM crates
        JOIN crates_categories ON crates.id = crates_categories.crate_id
        JOIN categories ON crates_categories.category_id = categories.id
        GROUP BY categories.category
        ORDER BY crate_count DESC
        """
