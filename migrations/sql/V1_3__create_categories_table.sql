CREATE TABLE IF NOT EXISTS finance.categories (
    id serial NOT NULL,
    name text NOT NULL
);

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM   pg_constraint
        WHERE  conname = 'categories_pkey'
    ) THEN
        ALTER TABLE finance.categories
        ADD CONSTRAINT categories_pkey PRIMARY KEY (id);
    END IF;
END
$$;

