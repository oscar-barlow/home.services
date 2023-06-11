CREATE TABLE IF NOT EXISTS finance.monthly_spending (
    id serial NOT NULL,
    amount numeric(8, 2) NOT NULL,
    fk_month_id integer NOT NULL,
    fk_year_id integer NOT NULL,
    fk_category_id integer NOT NULL
);

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'monthly_spending_pkey'
    ) THEN
        ALTER TABLE finance.monthly_spending
        ADD CONSTRAINT monthly_spending_pkey PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'fk_monthly_spending_month'
    ) THEN
        ALTER TABLE finance.monthly_spending
        ADD CONSTRAINT fk_monthly_spending_month FOREIGN KEY (fk_month_id) REFERENCES finance.month(id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'fk_monthly_spending_year'
    ) THEN
        ALTER TABLE finance.monthly_spending
        ADD CONSTRAINT fk_monthly_spending_year FOREIGN KEY (fk_year_id) REFERENCES finance.years(id);
    END IF;
    
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'fk_monthly_spending_category'
    ) THEN
        ALTER TABLE finance.monthly_spending
        ADD CONSTRAINT fk_monthly_spending_category FOREIGN KEY (fk_category_id) REFERENCES finance.categories(id);
    END IF;
END
$$;

