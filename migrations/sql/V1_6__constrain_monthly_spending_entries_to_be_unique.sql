DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_class c
        JOIN   pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relname = 'monthly_spending_unique'
        AND    n.nspname = 'finance'
    ) THEN
        CREATE UNIQUE INDEX monthly_spending_unique
        ON finance.monthly_spending (fk_month_id, fk_year_id, fk_category_id);
    END IF;
END
$$;

